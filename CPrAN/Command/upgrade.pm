# ABSTRACT: upgrade installed plugin to its latest version
package CPrAN::Command::upgrade;

use CPrAN -command;

use strict;
use warnings;

use Carp;
use Try::Tiny;
use Capture::Tiny 'capture';
use File::Which;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<upgrade> - Upgrades installed CPrAN plugins to their latest versions

=head1 SYNOPSIS

cpran upgrade [options] [arguments]

=head1 DESCRIPTION

Upgrades the specified CPrAN plugins to their latest known versions.

=cut

sub description {
  return "Upgrade installed plugins to their latest versions";
}

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
      die "W: Could not find path to git binary. Is git installed?\n"
        unless defined which('git');
      require Git::Repository;
      $opt->{git} = 1;
    }
    catch {
      unless (defined $opt->{debug}) {
        warn "W: Disabling git support (use --debug to see why)\n";
      }
      else {
        warn "$_";
        warn "W: Disabling git support\n";
      }
      $opt->{git} = 0;
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

  $args = [ CPrAN::installed() ] unless (@{$args});
  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') {
      $_;
    }
    else {
      CPrAN::Plugin->new( $_ );
    }
  } @{$args};

  # Plugins that are not installed cannot be upgraded.
  # @todo will hold the names of the plugins passed as arguments that are
  #   a) valid CPrAN plugin names; and
  #   b) already installed
  #   c) not at the latest version
  my @todo;
  foreach my $plugin (@plugins) {
    if ($plugin->is_installed) {
      if ($plugin->is_cpran) {
        if ($plugin->is_latest) { 
          print "$plugin->{name} is already at its latest version\n" if ($opt->{verbose} > 1);
        }
        else {
          push @todo, $plugin;
        }
      }
      else { warn "W: $plugin->{name} is not a CPrAN plugin\n" if $opt->{debug} }
    }
    else { warn "W: $plugin->{name} is not installed\n" }
  }

  if (@todo) {
    unless ($opt->{quiet}) {
      print "The following plugins will be UPGRADED:\n";
      print '  ', join(' ', map { $_->{name} } @todo), "\n";
      print "Do you want to continue? [y/N] ";
    }
    if (CPrAN::yesno( $opt, 'n' )) {
      my $app;
      my %params;
      
      unless ($opt->{git}) {
        $app = CPrAN->new();

        # We copy the current options, in case custom paths have been passed
        %params = %{$opt};
        $params{quiet} = 1;
        $params{yes}   = 1;
      }
    
      foreach my $plugin (@todo) {
        print "Upgrading $plugin->{name} from v$plugin->{local}->{version} to v$plugin->{remote}->{version}...\n" unless $opt->{quiet};

        if ($opt->{git}) {
          try {
            require Git::Repository;
            my $repo;
            try {
              $repo = Git::Repository->new( work_tree => $plugin->root );
            }
            catch {
              die "No git repository at ", $plugin->root, "\n", ($opt->{debug}) ? $_ : '';
            };
            
            try {
              $repo->run( 'fetch', '--quiet', { fatal => '!0' } )
            }
            catch {
              die "Could not fetch from origin.\n", ($opt->{debug}) ? $_ : '';
            };
            
            my @tags = split /\n/, $repo->run( 'tag', { fatal => '!0' } );
            my @args = ( 'checkout', '--quiet', $tags[-1] );
            push @args, '--force' if defined $opt->{force};
            
            try {
              my ($STDOUT, $STDERR) = capture {
                $repo->run(@args, { fatal => '!0' })
              }
            }
            catch {
              die "Unable to move HEAD. Do you have uncommited local changes? Commit or stash them before upgrade to keep them, or use --force to discard them.\n";
            };
          }
          catch {
            warn "$_";
            die "Aborting\n";
          }
        }
        else {
          $app->execute_command(CPrAN::Command::remove->new({}),  \%params, $plugin->{name});
          $app->execute_command(CPrAN::Command::install->new({}), \%params, $plugin->{name});
        }
        print "Succesfully upgraded $plugin->{name}\n" unless $opt->{quiet};
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
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

=back

=cut

sub opt_spec {
  return (
    [ "git|g!"  => "request / disable git support" ],
    [ "force|F" => "disregard common problems"     ],
  );
}

=head1 METHODS

=over

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>

=cut

1;
