# ABSTRACT: Check for newer versions of installed plugins
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
}

sub execute {
  my ($self, $opt, $args) = @_;
}

1;
