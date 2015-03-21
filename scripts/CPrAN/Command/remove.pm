# ABSTRACT: Delete an installed plugin from disk
package CPrAN::Command::remove;

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
}

sub execute {
  my ($self, $opt, $args) = @_;
}

1;
