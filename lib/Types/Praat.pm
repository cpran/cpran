package Types::Praat;

use strict;
use warnings;

use Praat::Version qw();
use Type::Library 0.008 -base, -declare => qw( Version );
use Type::Utils -all;
use Types::Standard qw( Str ArrayRef );

class_type Version, { class => "Praat::Version" };

coerce Version,
  from Str,      via { Praat::Version->new( $_ ) },
  from ArrayRef, via { Praat::Version->new( join '.', @{$_} ) };

# optionally add Getopt option type
eval { require MooseX::Getopt; };
if ( !$@ ) {
  MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $_, '=s', )
    for ( 'Praat::Version', Version, );
}

1;
