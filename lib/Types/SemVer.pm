package Types::SemVer;

use strict;
use warnings;

use SemVer qw();
use Type::Library 0.008 -base, -declare => qw( SemVer );
use Type::Utils -all;
use Types::Standard qw( Str ArrayRef );

class_type SemVer, { class => "SemVer" };

coerce SemVer,
  from Str,      via { SemVer->new( $_ ) },
  from ArrayRef, via { SemVer->new( join '.', @{$_} ) };

1;
