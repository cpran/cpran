# ABSTRACT: install new plugins
package CPrAN::Command::install;

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
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use GitLab::API::v3;

  my $api = GitLab::API::v3->new(
    url   => 'https://gitlab.com/api/v3/',
    token => $CPrAN::TOKEN,
  );
}

1;
