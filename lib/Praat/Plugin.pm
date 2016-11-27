package Praat::Plugin;

use Moo;
use Log::Any qw( $log );

require Carp;
use Types::Path::Tiny qw( Path );
use Types::Standard qw( Str Undef );
use Try::Tiny;

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
  return (defined $_[0]->root and $_[0]->root->exists);
}

sub BUILDARGS {
  my $class = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};
  $args = { name => $args } unless ref $args;

  $args->{name} =~ s/^plugin_([\w\d]+)/$1/ if defined $args->{name};

  return $args;
}

# VERSION

1;
