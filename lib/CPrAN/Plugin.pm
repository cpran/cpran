package CPrAN::Plugin;
# ABSTRACT: A representation of a Praat plugin

use Moose;
use uni::perl;

require Carp;
use Types::Path::Tiny qw( Path );
use Types::Praat qw( Version );

has [qw( name id url )] => (
  is => 'rw',
);

has [qw( version latest requested )] => (
  is => 'rw',
  isa => Version,
  coerce => 1,
);

has '+latest' => (
  lazy => 1,
  default => sub { $_[0]->_remote->{version} },
);

has '+version' => (
  lazy => 1,
  default => sub { $_[0]->_local->{version} },
);

has '+requested' => (
  lazy => 1,
  default => sub { $_[0]->latest },
);

has cpran => (
  is => 'ro',
  isa => 'CPrAN',
  weak_ref => 1,
  lazy => 1,
  default => sub {
    use CPrAN;
    return CPrAN->new;
  },
);

has root => (
  is => 'rw',
  isa => Path,
  coerce => 1,
);

has [qw( is_cpran is_installed )] => (
  is => 'rw',
);

has [qw( _remote _local )] => (
  is => 'rw',
);

use Try::Tiny;

=head1 NAME

=encoding utf8

B<CPrAN::Plugin> - Plugin class for CPrAN

=head1 SYNOPSIS

my $plugin = CPrAN::Plugin->new( $name );

$plugin->is_installed  ; checks for local copy
$plugin->is_cpran      ; checks for presence of descriptor
$plugin->refresh       ; refreshes object's internal state

=head1 DESCRIPTION

Objects of class C<CPrAN::Plugin> represent plugins / packages for Praat,
distributable via CPrAN, its package manager. The class can represent any Praat
plugins, regardless of whether they are on CPrAN or not.

=cut

sub BUILDARGS {
  my $class = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  if (defined $args->{meta}) {

    if (ref $args->{meta} eq 'HASH') {
      $args->{name} = $args->{meta}->{name};
      $args->{id}   = $args->{meta}->{id};
      $args->{url}  = $args->{meta}->{http_url_to_repo};
    }
    else {
      # Treat as an unserialised plugin descriptor
      my $meta = $class->_parse_meta($args->{meta});

      if (defined $meta) {
        $args->{name} = $meta->{plugin};
        $args->{_remote} = $meta;
      }
    }
    delete $args->{meta};
  }

  if ($args->{name} =~ /:/) {
    my ($n, $v) = split /:/, $args->{name};
    $args->{name} = $n;
    $args->{requested} = $v unless $v eq 'latest';
  }

  $args->{name} =~ s/^plugin_([\w\d]+)/$1/;

  return $args;
}

sub BUILD {
  $_[0]->refresh if defined $_[0]->cpran;
}

sub refresh {
  my ($self) = @_;

  # If root exists on disk then we assume it is a plugin,
  # and we know it is installed.
  $self->root( $self->cpran->praat->pref_dir->child( 'plugin_' . $self->name) )
    unless defined $self->root;
  $self->is_installed(1) if -e $self->root;

  # Initialise local and remote metadata
  unless (defined $self->_local) {
    my $meta = $self->root->child('cpran.yaml');
    $self->_local($self->parse_meta( scalar $meta->slurp )) if -e $meta;
  }

  unless (defined $self->_remote) {
    my $meta = $self->cpran->root->child( $self->name );
    $self->_remote($self->parse_meta( scalar $meta->slurp )) if -e $meta;
  }

  return $self;
}

=head1 METHODS

=over

=cut

=item fetch()

Fetches remote CPrAN data for the plugin.

=cut

sub fetch {
  my $self = shift;

  use YAML::XS;
  use Encode qw(encode decode);

  my ($id, $url, $latest, $remote);

  foreach (@{$self->cpran->api->projects(
      { search => 'plugin_' . $self->name }
    )}) {

    if ($_->{name} eq 'plugin_' . $self->name and
        $_->{visibility_level} >= 20) {

      $id  = $_->{id};
      $url = $_->{http_url_to_repo};
      last;
    }
  }

  unless (defined $id and defined $url) {
    Carp::carp $self->name, ' not found remotely'
      unless $self->cpran->quiet;
    return undef;
  }

  require Praat::Version;
  my $tags = $self->cpran->api->tags( $id );
  my @releases;
  foreach my $tag (@{$tags}) {
    try { $tag->{semver} = Praat::Version->new($tag->{name}) }
    catch { next };
    push @releases , $tag;
  };

  @releases = sort { $a->{semver} <=> $b->{semver} } @releases;

  # Ignore projects with no tags
  unless (scalar @releases) {
    Carp::carp 'No releases for ', $self->name
      unless $self->cpran->quiet;
    return undef;
  }

  $latest = $releases[-1]->{commit}->{id};
  $remote = encode('utf-8', $self->cpran->api->blob(
    $id, $latest, { filepath => 'cpran.yaml' }
  ), Encode::FB_CROAK );

  {
    my $check = try {
      YAML::XS::Load( $remote )
    }
    catch {};
    unless (defined $check) {
      Carp::carp 'Could not deserialise fetched remote for ', $self->name
        unless $self->cpran->quiet;
      return undef;
    }
  }

  $self->id($id);
  $self->url($url);
  $self->_remote($self->parse_meta($remote));

  return 1;
}

=item is_latest()

Compares the version on the locally installed copy of the plugin (if any) and
the one reported by the remote descriptor on record by the client (if any).

Returns true if installed version is the most recent the client knows about,
false if there is a newer version, and undefined if there is no remote version
to query.

=cut

sub is_latest {
  my ($self) = @_;

  return undef unless defined $self->_remote;
  return 0     unless defined $self->_local;

  return $self->version >= $self->latest;
}

=item test()

Runs tests for the plugin (if any). Returns the result of those tests.

=cut

sub test {
  use App::Prove;
  use File::Which;
  use CPrAN::Praat;

  my $self = shift;
  my $opt = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  $self->cpran->logger->debug('In CPrAN::Plugin::test');

  unless (defined $self->cpran->praat->version) {
    Carp::croak "Praat not installed; cannot test"
      unless $self->cpran->quiet;
  }

  return undef unless ($self->is_installed);

  $self->cpran->logger->debug('Plugin is installed');

  my $oldwd = Path::Tiny->cwd;
  chdir $self->root
    or die 'Could not change directory';

  unless ( -e 't' ) {
    $self->cpran->logger->debug('No tests for ', $self->name);
    return undef;
  }

  # Run the tests
  my $prove = App::Prove->new;
  my @args;

  my $version = $self->cpran->praat->version;
  $version =~ s/(\d+\.\d+)\.?(\d*)/$1$2/;
  if ($version >= 6 and $version < 6.003) {
    $self->cpran->logger->warn('Automated tests not supported for this version of Praat')
      unless $self->cpran->quiet;
    return undef;
  }
  elsif ($version >= 6.003) {
    push @args, ('--exec', $self->cpran->praat->bin . ' --ansi --run');
  }
  else {
    push @args, ('--exec', $self->cpran->praat->bin . ' --ansi');
  }

  if ($self->cpran->verbose) {
    push @args, '-v';
  }

  if ($opt->{log}) {
    try {
      require TAP::Harness::Archive;
      TAP::Harness::Archive->import;

      my $log = $self->root->child('.log');
      $log->remove_tree({ safe => 0 }) if $log->is_dir;
      $log->mkpath or die 'Could not create log directory';
      push @args, ('--archive', $log);
    }
    catch {
      Carp::carp 'Disabling logging. Is TAP::Harness::Archive installed?', "\n"
        unless $self->cpran->quiet;
    };
  }

  $prove->process_args( @args );
  my $results = $prove->run;

  chdir $oldwd
    or die "Could not change directory";

  if ($results) { return 1 } else { return 0 }
}

sub remove {
  my $self = shift;
  my $opt = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  $self->root->remove_tree({
    verbose => $opt->{verbose},
    safe => 0,
    error => \my $e
  });

  if (@{$e}) {
    Carp::carp 'Could not completely remove ', $self->root, "\n"
      unless $self->cpran->quiet;

    foreach (@{$e}) {
      my ($file, $message) = %{$_};
        if ($file eq '') {
        warn "General error: $message\n";
      }
      else {
        warn "Problem unlinking $file: $message\n";
      }
    }
    return 0;
  }
  else {
    return 1;
  }
}

=item print(I<FIELD>)

Prints the contents of the plugin descriptors, either local or remote. These
must be asked for by name. Any other names are an error.

=cut

sub print {
  use Encode qw( decode );

  my ($self, $name) = @_;
  $name = '_' . $name;

  die "Not a valid field"
    unless $name =~ /^_(local|remote)$/;

  die "No descriptor found"
    unless defined $self->$name;

  print decode('utf8',
    $self->$name->{meta}
  );
}

sub parse_meta {
  my ($self, $meta) = @_;

  my $parsed = $self->_parse_meta($meta);

  $self->is_cpran(1) if $parsed;
  return $parsed;
}

sub _parse_meta {
  my ($class, $meta) = @_;

  require YAML::XS;
  require Encode;
  require Praat::Version;

  my $parsed;
  try {
    $parsed = YAML::XS::Load( Encode::encode_utf8 $meta );
  }
  catch {
    Carp::carp 'Could not deserialise meta: ', $meta
      unless ref($class) or $class->cpran->quiet;
  };

  return undef unless defined $parsed and ref $parsed eq 'HASH';

  _force_lc_hash($parsed);

  $parsed->{meta} = $meta;
  $parsed->{name} = $parsed->{plugin};

  $parsed->{version} = try {
    Praat::Version->new($parsed->{version}) unless ref $parsed->{version} eq 'Praat::Version';
  }
  catch {
    Carp::carp 'Not a valid version number: ', $parsed->{version}
      unless ref($class) or $class->cpran->quiet;
  };

  return $parsed;
}

sub _force_lc_hash {
  my $hashref = shift;
  if (ref $hashref eq 'HASH') {
    foreach my $key (keys %{$hashref} ) {
      $hashref->{lc($key)} = $hashref->{$key};
      _force_lc_hash($hashref->{lc($key)}) if ref $hashref->{$key} eq 'HASH';
      delete($hashref->{$key}) unless $key eq lc($key);
    }
  }
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2016 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::deps|deps>,
L<CPrAN::Command::init|init>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::refresh|refresh>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
