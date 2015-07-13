# ABSTRACT: upgrade installed plugin to its latest version
package CPrAN::Command::upgrade;

use CPrAN -command;

use strict;
use warnings;

use Path::Class;
use File::Slurp;
use YAML::XS;
use Carp;

=head1 NAME

=encoding utf8

B<upgrade> - Upgrades installed CPrAN plugins to their latest versions

=head1 SYNOPSIS

cpran upgrade [options] [arguments]

=head1 DESCRIPTION

Upgrades the specified CPrAN plugins to their latest known versions.

=cut

sub description {
  return "Updates the catalog of CPrAN plugins";
}

=pod

B<upgrade> can take as argument a list of plugin names. If provided, only
those plugins will be upgraded. Otherwise, all installed plugins will be checked
for updates and upgraded. This second case should be the recommended use, but it
is not currently implemented.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;
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
      foreach my $plugin (@todo) {

        my $app = CPrAN->new();

        # We copy the current options, in case custom paths have been passed
        my %params = %{$opt};
        $params{quiet} = 1;
        $params{yes}   = 1;

        print "Upgrading $plugin->{name} from v$plugin->{local}->{version} to v$plugin->{remote}->{version}...\n";

        # NOTE(jja) Current upgrade process involves removal and then
        #           re-installation of appropriate plugin. This destroys local
        #           changes, which could be catastrophic if local version is,
        #           say, a git repository. Maybe this can be smarter?
        $app->execute_command('CPrAN::Command::remove',  \%params, $plugin->{name});
        $app->execute_command('CPrAN::Command::install', \%params, $plugin->{name});
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
    }
  }
  else {
    print "All plugins up to date.\n" unless ($opt->{quiet});
  }
}

=head1 OPTIONS

=over

=back

=cut

sub opt_spec {
  return (
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
