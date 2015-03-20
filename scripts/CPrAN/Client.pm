package CPrAN::Client;

use strict;
use warnings;
use diagnostics;

use Params::Validate qw/:all/;
use GitLab::API::v3;
use Data::Dumper;

{

  my $cpran;

  sub new {
    my $class = shift;

    validate(
        @_, {
            test => { type => SCALAR | ARRAYREF },
            bar => { type => SCALAR, optional => 1},
        }
    );

    my $api = GitLab::API::v3->new(
      url   => 'https://gitlab.com/api/v3/',
      token => 'WMe3t_ANxd3yyTLyc7WA',
    );

    push @_, ('api', $api);
    $cpran = $api->group('133578');

    return bless { @_ }, $class;
  }

  sub plugins {
    my $self = shift;
    return @{$cpran->{projects}};
  }

}

1;
