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
    [ "installed",     "only consider installed plugins" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $args->[0] = '.*' unless @{$args};
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use Text::Table;

  my $output = Text::Table->new(
    "Name", "Version", "Description"
  );

  my @files = dir( $CPrAN::ROOT )->children;

  map { append($output, $_) if ($_->basename =~ /$args->[0]/) } sort @files;
  print $output;
}

sub append {
  my ($table, $file) = @_;

  use YAML::XS;
  use File::Slurp;

  my $content = read_file($file->stringify);
  my $yaml = Load( $content );

  $table->add($yaml->{Plugin}, $yaml->{Version}, $yaml->{Description}->{Short});
  return $table;
}

1;
