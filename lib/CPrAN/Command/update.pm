package CPrAN::Command::update;
# ABSTRACT: update local plugin list

use Moose;
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';
with 'CPrAN::Role::Reads::STDIN';

require Carp;
require Path::Tiny;
use Try::Tiny;

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

has requested => (
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

  $self->app->logger->debug('Executing update');

  my @plugins = map {
    require CPrAN::Plugin;
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { CPrAN::Plugin->new( name => $_, cpran => $self->app ) }
  } @{$args};

  $self->request_plugin($_->name, 1) foreach @plugins;

  my @updated;
  if ($self->raw) {
    @updated = $self->fetch_raw;
  }
  else {
    @updated = $self->fetch_cache;
  }

  print 'Updated ', scalar @updated, ' packages', "\n" unless $self->app->quiet;

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
  my @requested = keys %{$self->requested};

  my @projects;
  if (scalar @requested) {
    @projects = map {
      @{$self->app->api->projects( { search => 'plugin_' . $_ } )};
    } @requested;
  }
  else {
    @projects = @{$self->app->api->projects};
  }

  foreach my $source (@projects) {

    unless ($source->{name} =~ /^plugin_/) {
      $self->app->logger->debug('Not a plugin, ignoring', $source->{name});
      next;
    }

    unless ($source->{visibility_level} eq 20) {
      $self->app->logger->debug('Not publicly visible, ignoring', $source->{name});
      next;
    }

    if (scalar @requested > 1 and !defined $self->requested->{$source->{name}}) {
      $self->app->logger->debug('Not in requested plugins, ignoring', $source->{name});
      next;
    }

    my $plugin = try {
      require CPrAN::Plugin;
      CPrAN::Plugin->new(
        meta => $source,
        cpran => $self->app,
      );
    }
    catch {
      $self->app->logger->debug('Could not initialise plugin ', $source->{name});
    };

    next unless defined $plugin;

    if ($plugin->is_cpran) {
      $self->app->logger->trace('Working on', $plugin->name)
        unless $self->app->quiet;

      $plugin->fetch;

      unless (defined $plugin->_remote) {
        $self->app->logger->debug('Undefined remote for', $plugin->name, ', skipping');
        next;
      }

      push @updated, $plugin;

      unless ($self->virtual) {
        if (defined $plugin->_remote->{meta} and $plugin->_remote->{meta} ne '') {
          my $fh = $self->app->root->child( $plugin->name )->touchpath->openw;
          $fh->print( $plugin->_remote->{meta} );
        }
        else {
          $self->app->logger->debug('Nothing to write for', $plugin->name);
        }
      }
    }
    else {
      $self->app->logger->warn($plugin->name, 'is not a CPrAN plugin')
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

    next if scalar keys %{$self->requested} >= 1 and
      !exists $self->requested->{$plugin->{Plugin}};

    $self->app->logger->debug('Working on', $plugin->{Plugin})
      if $self->app->debug;

    if ($self->virtual) {
      $plugin = CPrAN::Plugin->new(
        meta => $meta,
        cpran => $self->app
      );
    }
    else {
      my $out = $self->app->root->child( $plugin->{Plugin} )->touchpath;

      my $fh = $out->openw_utf8;
      $fh->print( $meta );
      $fh->close;
      $plugin = CPrAN::Plugin->new(
        name => $plugin->{Plugin},
        cpran => $self->app
      );
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

# VERSION

__PACKAGE__->meta->make_immutable;
no Moose;

1;
