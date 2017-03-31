package CPrAN::Command::update;
# ABSTRACT: update local plugin list

use Moose;
use Log::Any qw( $log );

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';
with 'CPrAN::Role::Reads::STDIN';

require Carp;

has [qw(
  virtual print raw
)] => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
);

has '+virtual' => (
  lazy => 1,
  default => 0,
  documentation => 'do not write anything to disk',
);

has '+print' => (
  lazy => 1,
  default => 0,
  documentation => 'print the stream of updated descriptors to STDOUT',
);

has '+raw' => (
  lazy => 1,
  default => 0,
  documentation => 'compute a new list of plugins from scratch',
);

has _project => (
  is  => 'rw',
  isa => 'HashRef',
  lazy => 1,
  default => sub {
    $_[0]->app->api->projects( { search => 'plugin_cpran' } )->[0];
  },
);

has _list => (
  is  => 'rw',
  isa => 'HashRef',
  lazy => 1,
  default => sub {
    my $snippets = $_[0]->app->api->snippets($_[0]->_project->{id});
    (grep { $_->{file_name} eq 'cpran.list' } @{$snippets})[0];
  },
);

has _requested => (
  is  => 'ro',
  isa => 'HashRef',
  traits => ['Hash'],
  lazy => 1,
  default => sub { {} },
  handles => {
    request_plugin => 'set',
    get_requested  => 'kv',
  },
);

=head1 NAME

=encoding utf8

B<update> - Update the catalog of CPrAN plugins

=head1 SYNOPSIS

cpran update [options] [arguments]

=head1 DESCRIPTION

Updates the list of plugins known to CPrAN, and information about their latest
versions.

=cut

=pod

B<update> can take as argument a list of plugin names. If provided, only
information about those plugins will be retrieved. Otherwise, a complete list
will be downloaded. This second case is the recommended use.

=cut

=head1 EXAMPLES

    # Updates the entire catalog printing information as it goes
    cpran update -v
    # Update information about specific plugins
    cpran update oneplugin otherplugin

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { $self->app->new_plugin( $_ ) }
  } @{$args};

  $self->request_plugin($_->name, 1) foreach @plugins;

  my @updated = ($self->raw) ? $self->fetch_raw : $self->fetch_cache;

  unless ($self->app->quiet) {
    my $n = scalar @updated;

    use Lingua::EN::Inflexion;
    print inflect "Updated <#n:$n> <N:package>\n";
  }

  if ($self->print) {
    $_->print('remote') foreach @updated;
  }

  return @updated;
}

sub fetch_raw {
  my ($self) = @_;

  print 'Contacting remote repositories for latest data...', "\n"
    unless $self->app->quiet;

  my @updated;
  my @requested = keys %{$self->_requested};

  my @projects;
  if (scalar @requested) {
    @projects = map {
      @{$self->app->api->projects({
        search => 'plugin_' . $_,
      })};
    } @requested;
  }
  else {
    @projects = @{$self->app->api->projects({
      per_page => 100
    })};
  }

  foreach my $source (@projects) {
    unless ($source->{name} =~ /^plugin_/) {
      $log->debug('Not a plugin, ignoring', $source->{name});
      next;
    }

    unless ($source->{visibility_level} eq 20) {
      $log->debug('Not publicly visible, ignoring', $source->{name});
      next;
    }

    if (scalar @requested > 1 and !defined $self->_requested->{$source->{name}}) {
      $log->debug('Not in requested plugins, ignoring', $source->{name});
      next;
    }

    use Syntax::Keyword::Try;
    my $plugin;
    try {
      $plugin = $self->app->new_plugin( meta => $source );
    }
    catch {
      $log->debug('Could not initialise plugin', $source->{name});
      next;
    }

    if ($plugin->is_cpran) {
      $log->trace('Working on', $plugin->name)
        unless $self->app->quiet;

      $self->app->fetch_plugin($plugin);

      unless (defined $plugin->_remote) {
        $log->debug('Undefined remote for', $plugin->name, ', skipping');
        next;
      }

      push @updated, $plugin;

      unless ($self->virtual) {
        if (defined $plugin->_remote->{meta} and $plugin->_remote->{meta} ne '') {
          my $fh = $self->app->root->child( $plugin->name )->touchpath->openw;
          $fh->print( $plugin->_remote->{meta} );
        }
        else {
          $log->debug('Nothing to write for', $plugin->name);
        }
      }
    }
    else {
      $log->warn($plugin->name, 'is not a CPrAN plugin')
        unless $self->app->quiet;
    }
  }
  return @updated;
}

sub fetch_cache {
  my ($self) = @_;

  print 'Updating plugin data...', "\n"
    unless $self->app->quiet;

  my @meta = split /---/, $self->app->api->raw_snippet(
    $self->_project->{id}, $self->_list->{id}
  );


  my @updated;
  foreach (@meta) {
    next unless $_;

    require Encode;
    require YAML::XS;
    require CPrAN::Plugin;

    my $meta = "---" . $_;
    my $plugin = YAML::XS::Load(Encode::encode_utf8 $meta);

    next if scalar keys %{$self->_requested} >= 1 and
      !exists $self->_requested->{$plugin->{Plugin}};

    $log->debug('Working on', $plugin->{Plugin})
      if $self->app->debug;

    if ($self->virtual) {
      $plugin = $self->app->new_plugin( meta => $meta );
    }
    else {
      my $out = $self->app->root->child( $plugin->{Plugin} )->touchpath;

      my $fh = $out->openw_utf8;
      $fh->print( $meta );
      $fh->close;
      $plugin = $self->app->new_plugin( $plugin->{Plugin} );
    }

    push @updated, $plugin;
  }

  return @updated;
}

=head1 METHODS

=over

=cut

=back

=head1 OPTIONS

=over

=item B<--verbose>

Increase verbosity of output.

=back

=cut


=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2016 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::deps|deps>,
L<CPrAN::Command::init|init>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::upgrade|upgrade>

=cut

our $VERSION = '0.0404'; # VERSION

__PACKAGE__->meta->make_immutable;
no Moose;

1;
