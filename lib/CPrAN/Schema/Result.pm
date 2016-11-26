package CPrAN::Schema::Result;

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
use MooseX::NonMoose;

extends 'DBIx::Class::Core';

# this is the right place to implement generic stuff

# DBIx::Class::Cookbook recommends loading components in a central place
__PACKAGE__->load_components(qw/
  InflateColumn::DateTime
  TimeStamp
  Core
/);

__PACKAGE__->meta->make_immutable;

1;
