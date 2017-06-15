package Types::CPrAN;
# ABSTRACT: CPrAN-specific types for Moose

our $VERSION = '0.0410'; # VERSION

use strict;
use warnings;

use MooseX::Types -declare => [qw( Praat )];

use MooseX::Types::Moose qw( Str HashRef );
use CPrAN::Praat;

use if MooseX::Types->VERSION >= 0.42, 'namespace::autoclean';

class_type('CPrAN::Praat');

subtype Praat, as 'CPrAN::Praat';

for my $type ( 'CPrAN::Praat', Praat ) {
  coerce $type,
    from Str,     via { CPrAN::Praat->new( bin => $_ ) },
    from HashRef, via { CPrAN::Praat->new( %{$_} ) };
}

# optionally add Getopt option type
eval { require MooseX::Getopt; };
if ( !$@ ) {
  MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $_, '=s', )
    for ( 'CPrAN::Praat', Praat, );
}

"It's a dirty job but someone's got to do it";
