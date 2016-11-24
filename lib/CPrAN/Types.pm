package CPrAN::Types;
# ABSTRACT: CPrAN-specific types for Moose

use strict;
use warnings;

use MooseX::Types
  -declare => [qw( Praat Version )];

use MooseX::Types::Moose qw( Str HashRef );
use if MooseX::Types->VERSION >= 0.42, 'namespace::autoclean';

class_type('CPrAN::Praat');
class_type('SemVer');

subtype Praat, as 'CPrAN::Praat';
subtype Version, as 'SemVer';

for my $type ( 'CPrAN::Praat', Praat ) {
  coerce $type,
    from Str,     via { CPrAN::Praat->new( bin => $_ ) },
    from HashRef, via { CPrAN::Praat->new( %{$_} ) };
}

for my $type ( 'SemVer', Version ) {
  coerce $type,
    from Str,      via { SemVer->new( $_ ) };
}

# optionally add Getopt option type
eval { require MooseX::Getopt; };
if ( !$@ ) {
  MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $_, '=s', )
    for ( 'CPrAN::Praat', 'SemVer', Praat, Version, );
}

"It's a dirty job but someone's got to do it";
