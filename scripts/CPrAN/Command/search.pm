# ABSTRACT: Search among available CPrAN plugins
package CPrAN::Command::search;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
    [ "name|n",        "search in plugin name" ],
    [ "description|d", "search in description" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $args->[0] = '.*' unless @{$args};
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;

  my @files = dir( $CPrAN::ROOT )->children;

  map { display($_) if ($_->basename =~ /$args->[0]/) } @files;
}

sub display {
  my $file = shift;

  use YAML::XS;
  use File::Slurp;

  my $content = read_file($file->stringify);
  my $yaml = Load( $content );
#   print Dumper($yaml);
  print $yaml->{Plugin} . ' - ' . $yaml->{Description}->{Short} . "\n";
}

1;
