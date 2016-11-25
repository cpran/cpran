package TestsFor::CPrAN::Plugin;

use Test::Class::Moose;
with 'Test::Class::Moose::Role::AutoUse';

use Try::Tiny;
use Plack::Runner;
use Plack::App::File;
use Test::TCP;

sub test_use : Tests {
  my $test = shift;
  use_ok $test->class_name;
}

sub test_attributes : Tests {
  my $test = shift;

  # Private
  can_ok $test->class_name, $_
    foreach (qw( _remote _local ));

  # Public
  can_ok $test->class_name, $_
    foreach (qw( cpran current latest root is_cpran is_installed ));
}

sub test_constructor : Tests {
  my $test = shift;
  my $class = $test->class_name;
  can_ok $class, 'new';
  ok my $self = $class->new,
    'constructor succeeds';

  isa_ok $self, $class;
}

# sub test_get : Tests {
#   my $test = shift;
#   my $class = $test->class_name;
#
#   # Note: this, like the implementation in Test::TCP,
#   # is vulnerable to race conditions
#   use Net::EmptyPort qw( empty_port );
#   my $host = '0.0.0.0';
#   my $port = empty_port();
#
#   test_tcp(
#     host => $host,
#     server => sub {
#       my $port = shift;
#       my $runner = Plack::Runner->new;
#       $runner->parse_options(
#         '--host'   => $host,
#         '--port'   => $port,
#         '--env'    => 'test',
#         '--server' => 'HTTP::Server::PSGI'
#       );
#       $runner->run(Plack::App::File->new->to_app);
#     },
#     client => sub {
#       my $port = shift;
#
#     },
#   );
# }

"All's well that ends well";
