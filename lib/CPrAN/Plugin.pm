package CPrAN::Plugin;

use strict;
use warnings;

use Try::Tiny;
use Carp;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<CPrAN::Plugin> - Plugin class for CPrAN

=head1 SYNOPSIS

my $plugin = CPrAN::Plugin->new( $name );

$plugin->is_installed  ; checks for local copy
$plugin->is_cpran      ; checks for presence of descriptor
$plugin->update        ; updates object's internal state

=head1 DESCRIPTION

Objects of class C<CPrAN::Plugin> represent plugins / packages for Praat,
distributable via CPrAN, its package manager. The class can represent any Praat
plugins, regardless of whether they are on CPrAN or not.

=cut

sub new {
  my ($class, $name) = @_;

  if (ref $name) {
    croak "Already a reference: " . ref $name;
  }

  my $self = bless {
    name  => $name,
    cpran => 0,
  }, $class;

  $self->_init();

  die "No local or remote plugin named \"$name\" is known. Maybe try update?\n"
    unless ($self->{cpran} || $self->{installed});

  return $self;
}

sub _init {
  use Path::Class;

  my ($self) = @_;

  my $root = dir(CPrAN::praat(), 'plugin_' . $self->{name});
  $self->{root} = $root->stringify;

  $self->{installed} = 1 if ( -e $root );

  my $local = file($self->{root}, 'cpran.yaml');
  if (-e $local) {
    $self->{'local'} = $self->_read( $local );
  }

  my $remote = file(CPrAN::root(), $self->{name});
  if (-e $remote) {
    $self->{'remote'} = $self->_read( $remote );
  }
  else {
    $self->fetch;
  }
}

=head1 METHODS

=over

=cut

=item B<is_cpran()>

Checks if plugin has a descriptor that CPrAN can use.

=cut

sub is_cpran { return $_[0]->{cpran} }

=item B<is_installed()>

Checks if the plugin is installed or not.

=cut

sub is_installed { return $_[0]->{installed} }

=item B<update()>

Updates the internal state of the plugin, to reflect any changes in disk that
took place after the object's creation.

=cut

sub update { $_[0]->_init }

=item B<root()>

Returns the plugin's root directory.

=cut

sub root { return $_[0]->{root} }

=item B<name()>

Returns the plugin's name.

=cut

sub name { return $_[0]->{name} }

=item B<url()>

Gets the plugin URL, pointing to the clonable git repository

=cut

sub url { return $_[0]->{url} }

=item id()

Fetches the CPrAN remote id for the plugin.

=cut

sub id { return $_[0]->{id} }

=item fetch()

Fetches remote CPrAN data for the plugin.

=cut

sub fetch {
  my $self = shift;

  use WWW::GitLab::v3;
  use Sort::Naturally;
  use YAML::XS;
  use Encode qw(encode decode);


  my $api = WWW::GitLab::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  my ($id, $url, $latest, $remote);
  foreach (@{$api->projects( { search => 'plugin_' . $self->{name} } )}) {
    if (($_->{name} eq 'plugin_' . $self->{name}) &&
        ($_->{visibility_level} >= 20)) {

      $id  = $_->{id};
      $url = $_->{http_url_to_repo};
      last;
    }
  }
  unless (defined $id && defined $url) {
    warn "No remote version of $self->{name}";
    return undef;
  }

  my $tags = $api->tags( $id );
  my @releases = grep { $_->{name} =~ /^v?\d+\.\d+\.\d+/ } @{$tags};
  @releases = sort { ncmp($a->{name}, $b->{name}) } @releases;

  # Ignore projects with no tags
  unless (@releases) {
    warn "No releases for $self->{name}";
    warn "  $_->{name}\n" foreach (@{$tags});
    return undef;
  }

  $latest = pop @releases;
  $latest = $latest->{commit}->{id};

  $remote = encode('utf-8', $api->blob(
    $id, $latest,
    { filepath => 'cpran.yaml' }
  ), Encode::FB_CROAK );

  try {
    YAML::XS::Load( $remote )
  }
  catch {
    warn "Improperly formed descriptor for $self->{name}";
    return undef;
  };

  $self->{id}     = $id;
  $self->{url}    = $url;
  $self->{remote} = $self->_read( $remote );
  $self->{latest} = $latest;
  $self->{cpran}  = 1;

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

  return undef unless (defined $self->{remote});
  return 0     unless (defined $self->{local});
  return 1 if ($self->{remote}->{version} eq $self->{local}->{version});

  die "Incorrectly formatted version number: $a, $b"
    if ($self->{remote}->{version} !~ /^\d+\.\d+\.\d+$/ ||
        $self->{local}->{version}  !~ /^\d+\.\d+\.\d+$/);

  my @remote = split /\./, $self->{remote}->{version};
  my @local  = split /\./, $self->{local}->{version};

  if    ($remote[0] > $local[0]) { return 0 }
  elsif ($remote[0] < $local[0]) { return 1 }
  elsif ($remote[1] > $local[1]) { return 0 }
  elsif ($remote[1] < $local[1]) { return 1 }
  elsif ($remote[2] > $local[2]) { return 0 }
  elsif ($remote[2] < $local[2]) { return 1 }
  else {
    warn "$self->{remote}->{version} <-> $self->{local}->{version}\n";
    die "Unreachable condition reached. Inconceivable!";
  }
}

=item test()

Runs tests for the plugin (if any). Returns the result of those tests.

=cut

sub test {
  use App::Prove;
  use Path::Class;
  use File::Which;
  use CPrAN::Praat;

  my ($self, $opt) = @_;
  $opt = $opt // {};

  # Find the Praat executable
  # In Windows, this will normally be "praatcon" (case-insensitive)
  # In Linux, this is (normally) "praat" (case-sensitive)
  # In Mac, this will normally be "Praat" (case-insensitive), but could
  # be case sensitive in some systems.
  # For versions >=6.0 praatcon no longer exists in Windows, and "praat" should
  # be used.
  # For more obscure cases, an option to specify the path to Praat is needed.
  my $praat = CPrAN::Praat->new;

  die "$self->{name} is not installed" unless ($self->is_installed);

  use Cwd;
  my $oldwd = getcwd;
  chdir $self->{root}
    or die "Could not change directory";

  unless ( -e 't' ) {
    warn "No tests for $self->{name}\n";
    return undef;
  }

  # Run the tests
  my $prove = App::Prove->new;
  my @args;


  my $version = $praat->{current};
  $version =~ s/(\d+\.\d+)\.?(\d*)/$1$2/;
  if ($version >= 6 and $version < 6.003) {
    warn "Automated tests not supported for this version of Praat\n";
    return undef;
  }
  elsif ($version >= 6.003) {
    push @args, ('--exec', "$praat->{bin} --ansi --run");
  }
  else {
    push @args, ('--exec', "$praat->{bin} --ansi");
  }

  if ($opt->{log}) {
    try {
      require TAP::Harness::Archive;
      TAP::Harness::Archive->import;

      my $log = dir($self->{root}, '.log');
      unless ( -e $log ) {
        mkdir $log
          or die "Could not create log directory";
      }
      else {
        while (my $file = $log->next) {
          next unless -f $file;
          $file->remove or die "Could not remove $file";
        }
      }
      push @args, ('--archive', $log);
    }
    catch {
      warn "Disabling logging. Install TAP::Harness::Archive to enable it\n";
    };
  }

  $prove->process_args( @args );
  my $results = $prove->run;

  chdir $oldwd
    or die "Could not change directory";

  if ($results) { return 1 } else { return 0 }
}

=item print(I<FIELD>)

Prints the contents of the plugin descriptors, either local or remote. These
must be asked for by name. Any other names are an error.

=cut

sub print {
  use Encode qw( decode );
  use Path::Class;

  my ($self, $name) = @_;
  die "Not a valid field"
    unless $name =~ /^(local|remote)$/;

  die "No descriptor found"
    unless defined $self->{$name};

  print decode('utf8',
    file($self->{$name}->{descriptor})->slurp
  );
}

sub _read {
  use YAML::XS;
  use Path::Class;
  use Data::Printer;

  my ($self, $in) = @_;
  my $yaml;

  try {
    if (ref $in eq 'Path::Class::file') {
      croak unless -e $in;
      $in = scalar $in->slurp;
    }
    $yaml = YAML::XS::Load( $in );
  }
  catch {
    warn "Could not deserialise descriptor";
    return undef;
  };

  # When does this happen?
  return undef unless (ref $yaml eq 'HASH');

  _force_lc_hash($yaml);
  $yaml->{name} = $yaml->{plugin};
  $self->{cpran} = 1;
  return $yaml;
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

Copyright 2015 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,

=cut

1;