# ABSTRACT: show specified plugin descriptor
package CPrAN::Command::show;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
# use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Must provide a plugin name") unless @{$args};

  CPrAN::set_global( $opt );
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use File::Slurp;

  foreach (@{$args}) {
    my $file = file( CPrAN::root(), $_ );
    my $content = read_file($file->stringify);
    print decode('utf8', $content);
  }
}

1;
