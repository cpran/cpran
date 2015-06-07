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
  my ($self, $opt, $args) = @_;

  my @args = CPrAN::installed();
  $args = \@args unless @{$args};

  # Get a hash of installed plugins (ie, plugins in the preferences directory)
  my %installed;
  $installed{$_} = 1 foreach (CPrAN::installed());

  # Get a hash of known plugins (ie, plugins in the CPrAN list)
  my %known;
  $known{$_} = 1 foreach (CPrAN::known());

  # Plugins that are not installed cannot be upgraded.
  # @names will hold the names of the plugins passed as arguments that are
  #   a) valid CPrAN plugin names; and
  #   b) already installed
  #   c) not at the latest version
  my @names;
  foreach (@{$args}) {
    if (exists $installed{$_}) {
      if (exists $known{$_}) {

        my ($cmd) = $self->app->prepare_command('show');
        my $local = $self->app->execute_command(
          $cmd, { quiet => 1, installed => 1 }, $_
        );
        $local = Load($local);

        my $remote = $self->app->execute_command(
          $cmd, { quiet => 1 }, $_
        );
        $remote = Load($remote);

        use Data::Printer;

        if (CPrAN::compare_version( $remote->{Version}, $local->{Version} )) {
          push @names, $_;
        }
      }
      else { warn "W: no plugin named $_\n" }
    }
    else { warn "W: $_ is not installed\n" }
  }

  if (@names) {
    unless ($opt->{quiet}) {
      print "The following plugins will be UPGRADED:\n";
      print '  ', join(' ', map { $_ } @names), "\n";
      print "Do you want to continue? [y/N] ";
    }
    if (CPrAN::yesno( $opt, 'n' )) {
      foreach my $name (@names) {
        my $desc  = file(CPrAN::praat(), 'plugin_' . $name, 'cpran.yaml');

        my $content = read_file($desc->stringify);
        my $yaml = Load( $content );

        my $name = $yaml->{Plugin};
        my $local = $yaml->{Version};

        $desc = file(CPrAN::root(), $name);
        my $remote = '';
        if (-e $desc->stringify) {
          $content = read_file($desc->stringify);
          $yaml = Load( $content );
          $remote = $yaml->{Version};
        }

        my $app = CPrAN->new();

        # We copy the current options, in case custom paths have been passed
        my %params = %{$opt};
        $params{quiet} = 1;
        $params{yes}   = 1;

        if (CPrAN::compare_version( $local, $remote ) < 0) {
          print "Upgrading $name from v$local to v$remote... ";

          $app->execute_command('CPrAN::Command::remove',  \%params, $name);
          $app->execute_command('CPrAN::Command::install', \%params, $name);

          print "done\n";
        }
        else {
          print "$name is already at its latest version\n";
        }
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
    }
  }
  else {
    print "All plugins up to date.\n";
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
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,

=cut

1;
