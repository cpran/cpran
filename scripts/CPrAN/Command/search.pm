# ABSTRACT: Search plugins in CPrAN
package CPrAN::Command::search;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;

# No options
sub opt_Spec {
  return ();
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("No options") if keys %{$opt};
}

sub execute {
  my ($self, $opt, $args) = @_;

  use GitLab::API::v3;

  my $api = GitLab::API::v3->new(
    url   => 'https://gitlab.com/api/v3/',
    token => 'WMe3t_ANxd3yyTLyc7WA',
  );

  my $projects = $api->group('133578')->{projects};

  map { print $_->{name} . "\n" if $_->{name} =~ /$args->[0]/ } @{$projects};
}

1;
