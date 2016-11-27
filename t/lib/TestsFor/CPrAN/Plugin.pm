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
    foreach (qw( cpran version latest root is_cpran is_installed ));

  # Methods
  can_ok $test->class_name, $_
    foreach (qw( is_cpran is_latest refresh remove ));
}

sub test_constructor : Tests {
  my $test = shift;
  my $class = $test->class_name;
  can_ok $class, 'new';

  my $self;

  ok $self = $class->new( name => '' ),
    'constructor succeeds with empty name';

  isa_ok $self, $class;
  is $self->name, '', 'Name is empty';

  ok $self = $class->new( name => 'name' ),
    'constructor succeeds with hash';
  is $self->name, 'name', 'hash blessed to object';

  ok $self = $class->new({ name => 'name' }),
    'constructor succeeds with hashref';
  is $self->name, 'name', 'hashref blessed to object';

  ok $self = $class->new( 'name' ),
    'constructor succeeds with scalar';
  is $self->name, 'name', 'scalar set to name';
}

sub test_latest : Tests {
  my $test = shift;
  my $class = $test->class_name;

  my $self = $class->new( 'test' );

  is $self->is_latest, undef, 'is_latest undefined without remote';

  $self->_remote({ version => '1.0.0' });
  is $self->is_latest, 0, 'is_latest is false without local';

  $self->_local({ version => '0.1.0' });
  is $self->is_latest, 0, 'is_latest is false with lower version';

  $self->_local({ version => '1.0.0' });
  is $self->is_latest, 1, 'is_latest is true with equal versions';

  $self->_local({ version => '1.1.0' });
  is $self->is_latest, 1, 'is_latest is true with greater version';
}

sub test_remove : Tests {
  my $test = shift;
  my $class = $test->class_name;

  my $self = $class->new( 'test' );

  is $self->remove, undef, 'removed returns undefined with no root';

  $self->root('/not/a/real/path');
  is $self->remove, 0, 'removed returns false with missing root';

  use Path::Tiny;
  my $root = Path::Tiny->cwd->child('t', 'data', 'bad', 'plugin_' . $self->name);
  $root->mkpath;
  is $root->exists, 1, 'created root';

  $self->root($root);
  is  $self->remove, 1, 'removed returns true when deleting root';
  is !$root->exists, 1, 'removed deleted root';
  $root->remove;
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
