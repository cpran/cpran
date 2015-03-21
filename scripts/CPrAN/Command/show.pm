# ABSTRACT: show specified plugin descriptor
package CPrAN::Command::show;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("One argument allowed") if (scalar @{$args} != 1);
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use File::Slurp;

  my $file = file( $CPrAN::ROOT, $args->[0] );
  my $content = read_file($file->stringify);
  print $content;
}

1;
