package CPrAN::Plugin::Schema;

# Based on http://stackoverflow.com/a/22483146/807650

use Moose;
use MooseX::MarkAsMethods autoclean => 1;

# based on the DBIx::Class Schema base class
extends 'DBIx::Class::Schema';

# Load table modules
__PACKAGE__->load_namespaces;

__PACKAGE__->meta->make_immutable;

1;
