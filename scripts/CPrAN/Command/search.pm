# ABSTRACT: Search plugins in CPrAN
package CPrAN::Command::search;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;

# No options
sub opt_Spec {
  return (
    [ "name|n",        "search in plugin name" ],
    [ "description|d", "search in description" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("No options") if keys %{$opt};
}

sub execute {
  my ($self, $opt, $args) = @_;
}

1;
