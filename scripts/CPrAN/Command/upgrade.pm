# ABSTRACT: upgrade installed plugin to its latest version
package CPrAN::Command::upgrade;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;

sub opt_spec {
  return (
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  # TODO(jja) If no arguments are provided, all plugins are updated. If names
  # are provided, only update those that are specified.

  CPrAN::set_global( $opt );
}

sub execute {
  my ($self, $opt, $args) = @_;
}

1;
