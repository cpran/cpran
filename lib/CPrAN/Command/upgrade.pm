package CPrAN::Command::upgrade;
# ABSTRACT: upgrade plugins to their latest version

use Moose;
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';

require Carp;
use Try::Tiny;
use Capture::Tiny 'capture';
use File::Which;

has git => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  documentation => 'request / disable git support',
  default => 1,
);

has test => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 1,
  documentation => 'request / disable tests',
);

has log => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 1,
  documentation => 'request / disable log of tests',
);

has force => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 0,
  documentation => 'ignore failing tests',
);

=head1 NAME

=encoding utf8

B<upgrade> - Upgrades installed CPrAN plugins to their latest versions

=head1 SYNOPSIS

cpran upgrade [options] [arguments]

=head1 DESCRIPTION

Upgrades the specified CPrAN plugins to their latest known versions.

=cut

=pod

B<upgrade> can take as argument a list of plugin names. If provided, only
those plugins will be upgraded. Otherwise, all installed plugins will be checked
for updates and upgraded. This second case should be the recommended use, but it
is not currently implemented.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;

  # Git support is enabled if
  # 1. git is available
  # 2. Git::Repository is installed
  # 3. The user has not turned it off by setting --nogit
  if (!defined $opt->{git} or $opt->{git}) {
    try {
      $opt->{git} = which('git');
      die "Could not find path to git binary. Is git installed?\n"
        unless defined $opt->{git};
      require Git::Repository;
    }
    catch {
      $opt->{git} = 0;
      $self->app->logger->warn('Disabling git support');
      $self->app->logger->debug($_);
    }
  }
}

=head1 EXAMPLES

    # Upgrades all installed plugins
    cpran upgrade
    # Upgrade specific plugins
    cpran upgrade oneplugin otherplugin

=cut

# TODO(jja) Break execute into smaller chunks
sub execute {
  use CPrAN::Plugin;

  my ($self, $opt, $args) = @_;

  my $app;
  $app = CPrAN->new();
  $self->app->logger->debug('Executing upgrade');

  if (grep { /praat/i } @{$args}) {
    if (scalar @{$args} > 1) {
      die "Praat must be the only argument for processing\n";
    }
    else {
      $self->app->logger->debug('Processing Praat');
      $self->_praat($opt);
    }
  }

  unless (@{$args}) {
    my $cmd = CPrAN::Command::list->new({});
    my %params = %{$opt};
    $params{quiet} = 1;
    $params{installed} = 1;
    $args = [ $app->execute_command($cmd, \%params, ()) ];
  }

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') {
      $_;
    }
    else {
      try   { CPrAN::Plugin->new( $_ ) }
      catch {
        warn $_;
        Carp::croak "Aborting\n";
      };
    }
  } @{$args};

  $self->app->logger->debug(scalar @{$args}, ' plugins for processing: ',
    join(', ', map { $_->{name} } @plugins));

  # Plugins that are not installed cannot be upgraded.
  # @todo will hold the names of the plugins passed as arguments that are
  #   a) valid CPrAN plugin names; and
  #   b) already installed
  #   c) not at the latest version
  my @todo;
  foreach my $plugin (@plugins) {
    if ($plugin->is_installed) {
      if ($plugin->is_cpran) {
        if ($plugin->is_latest // 1) {
          print "$plugin->{name} is already at its latest version\n"
            if $opt->{verbose} > 1;
        }
        else {
          push @todo, $plugin;
        }
      }
      else {
        $self->app->logger->debug($plugin->{name}, ' is not a CPrAN plugin');
      }
    }
    else { warn "$plugin->{name} is not installed\n" }
  }
  $self->app->logger->debug(scalar @todo, ' plugins require upgrading: ',
    join(', ', map { $_->{name} } @todo));

  # Make sure plugins are upgraded in order
  if (scalar @todo) {
    use Array::Utils qw( intersect );
    my $cmd = CPrAN::Command::deps->new({});

    my %params = %{$opt};
    $params{quiet} = 1;

    my @deps = $app->execute_command($cmd, \%params, @todo);
    @todo = intersect(@todo, @deps);
  }

  if (@todo) {
    unless ($opt->{quiet}) {
      print "The following plugins will be UPGRADED:\n";
      print '  ', join(' ', map { $_->{name} } @todo), "\n";
      print "Do you want to continue?";
    }
    if (CPrAN::yesno( $opt )) {

      my %params;
      unless ($opt->{git}) {
        # We copy the current options, in case custom paths have been passed
        %params = %{$opt};
        $params{quiet} = 1;
        $params{yes}   = 1;
      }

      foreach my $plugin (@todo) {
        print 'Upgrading ', $plugin->{name}, ' from v',
          $plugin->{local}->{version}, ' to v',
          $plugin->{remote}->{version}, "...\n" unless $opt->{quiet};

        if ($opt->{git}) {
          try {
            require Git::Repository;
            my $repo;
            try {
              $repo = Git::Repository->new( work_tree => $plugin->root );
            }
            catch {
              $self->app->logger->warn('No git repository at ', $plugin->root);
              $self->app->logger->debug($_);
              exit 1;
            };

            my $head;
            try {
              $head = $repo->run('rev-parse', 'HEAD', { fatal => '!0' } );
            }
            catch {
              $self->app->logger->warn('Could not locate HEAD');
              $self->app->logger->debug($_);
            };

            try {
              $plugin->fetch unless defined $plugin->{url};
              $repo->run( 'pull', '--tags', $plugin->{url}, { fatal => '!0' } );
            }
            catch {
              die "Could not fetch from origin.\n",
                ($opt->{debug}) ? $_ : '';
            };

            my $latest = $plugin->latest;
            my @args = ( 'checkout', '--quiet', $latest->{commit}->{id} );
            push @args, '--force' if defined $opt->{force};

            try {
              my ($STDOUT, $STDERR) = capture {
                $repo->run(@args, { fatal => '!0' })
              }
            }
            catch {
              die "Unable to move HEAD. Do you have uncommited local changes? ",
                "Commit or stash them before upgrade to keep them, or discard them with --force.\n";
            };

            $plugin->update;
            my $success = 0;
            try { $success = $plugin->test }
            catch {
              chomp;
              warn "There were errors while testing:\n$_\n";
            };

            if (defined $success and !$success) {
              if ($opt->{force}) {
                $self->app->logger->warn('Tests failed, but continuing anyway because of --force')
                  unless $self->app->quiet;
              }
              else {
                unless ($opt->{quiet}) {
                  $self->app->logger->warn('Tests failed. Rolling back upgrade of ', $plugin->{name});
                  $self->app->logger->warn('Use --force to ignore this warning');
                }
                $repo->run('reset', '--hard', '--quiet', $head , { fatal => '!0' });

                $self->app->logger->warn('Did not upgrade ', $plugin->{name})
                  unless $self->app->quiet;
                exit 1;
              }
            }
            else {
              print "$plugin->{name} upgraded successfully.\n" unless $opt->{quiet};
            }
          }
          catch {
            $self->app->logger->warn($_);
            $self->app->logger->warn('Aborting');
            exit 1;
          }
        }
        else {
          $app->execute_command(CPrAN::Command::remove->new({}),  \%params, $plugin->{name});
          $app->execute_command(CPrAN::Command::install->new({}), \%params, $plugin->{name});
          print "$plugin->{name} upgraded successfully.\n" unless $opt->{quiet};
        }
      }
    }
    else {
      print "Abort\n" unless ($opt->{quiet});
      exit;
    }
  }
  else {
    print "All plugins up to date.\n" unless ($opt->{quiet});
    exit;
  }
}

=head1 OPTIONS

=over

=item B<--git>, B<-g>
=item B<--nogit>

By default, B<upgrade> will try to use B<git> to bring plugins up to date. For
this to work, B<upgrade> needs to be able to find git in the local system, the
B<Git::Repository> module for perl needs to be installed, and the existing
version of the plugin needs to be a git repository.

If these requirements are met and git support is enabled, the upgrade will be
done using git, moving the HEAD to the latest version. This will fail if
there are uncommited local changes. Make sure this command is run with a clean
work environment, or use B<--force> to discard changes.

If this is undesirable (even though the conditions are met), this behaviour can
be disabled with the B<--nogit> option. Be advised that B<this will destroy any
git repositories in the plugin directory>.

=item B<--force>, B<-F>

Attempts to aggresively work around problems. Use at your own risk.

=item B<--test>, B<-T>
=item B<--notest>

These options control execution of the automated tests in each plugin. The
B<--test> option is enabled by default, and will cause these tests to be run.
This can be disabled with the B<--notest> option, which will make the client
skip tests altogether.

This is different from B<--force> in that B<--force> will still run the tests,
but will disregard those that fail.

=back

=cut

=head1 METHODS

=over

=cut

sub _praat {
  my ($self, $opt) = @_;

  try {
    my $praat = $self->{app}->praat;
    die "Could not find " . ( $opt->{bin} // 'praat' )
      unless defined $praat->current;

    print "Querying server for latest version...\n"
      unless $opt->{quiet};

    if ($praat->latest > $praat->current) {
      unless ($opt->{quiet}) {
        print "Praat will be UPGRADED from ", $praat->current, " to ", $praat->latest, "\n";
        print "Do you want to continue?";
      }

      if (CPrAN::yesno( $opt )) {
        my $app = CPrAN->new;
        my %params = %{$opt};
        $params{yes} = $params{reinstall} = 1;
        # TODO(jja) Better verbosity controls
        $params{quiet} = 2; # Silence everything _but_ the download progress bar
        $app->execute_command(CPrAN::Command::install->new({}), \%params, 'praat');
      }
    }
    else {
      print "Praat is already at its latest version (", $praat->current, ")\n";
      exit 0;
    }
  }
  catch {
    chomp;
    $self->app->logger->warn($_);
    $self->app->logger->warn('Could not upgrade Praat');
    exit 1;
  };
  exit 0;
}

=back

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
L<CPrAN::Command::update|update>

=cut

# VERSION

1;
