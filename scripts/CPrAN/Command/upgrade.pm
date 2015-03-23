# ABSTRACT: upgrade installed plugin to its latest version
package CPrAN::Command::upgrade;

use CPrAN -command;

use strict;
use warnings;
# use diagnostics;
use Data::Dumper;

sub opt_spec {
  return (
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  # TODO(jja) If no arguments are provided, all plugins are updated. If names
  # are provided, only update those that are specified.

  CPrAN::set_global( $self );
}

sub execute {
  my ($self, $opt, $args) = @_;

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
  my @names;
  foreach (@{$args}) {
    if (exists $installed{$_}) {
      if (exists $known{$_}) { push @names, $_ }
      else { warn "W: no plugin named $_\n" }
    }
    else { warn "W: $_ is not installed\n" }
  }

  use Path::Class;
  use File::Slurp;
  use YAML::XS;

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

      $app->execute_command('CPrAN::Command::remove', \%params, $name);
      $app->execute_command('CPrAN::Command::install', \%params, $name);

      print "done\n";
    }
    else {
      print "$name is already at its latest version\n";
    }
  }
}

1;
