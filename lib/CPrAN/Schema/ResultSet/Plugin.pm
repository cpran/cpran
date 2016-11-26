package CloudCAST::Schema::ResultSet::Plugin;

use uni::perl;
use Moose;
use MooseX::MarkAsMethods autoclean => 1;

extends 'CloudCAST::Schema::ResultSet';

__PACKAGE__->meta->make_immutable;

1;
