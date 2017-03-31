package Praat::Plugin;

use Moo;
use Log::Any qw( $log );

use Types::Path::Tiny qw( Path );
use Types::Standard qw( Str Undef );

has name => (
  is => 'ro',
  isa => Str,
  required => 1,
);

has root => (
  is => 'rw',
  isa => Path|Undef,
  coerce => 1,
);

sub is_installed {
  return (defined $_[0]->root and $_[0]->root->exists) ? 1 : 0;
}

sub BUILDARGS {
  my $class = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};
  if (!ref $args) {
    $args = { name => $args };
  }

  if (defined $args->{name}) {
    $args->{name} =~ s/^plugin_([\w\d]+)/$1/;
  }

  return $args;
}

our $VERSION = '0.0406'; # VERSION

1;
