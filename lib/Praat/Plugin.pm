package Praat::Plugin;

use Moo;
use Log::Any qw( $log );

require Carp;
use Types::Path::Tiny qw( Dir );
use Types::Standard qw( Str Bool );
use Try::Tiny;

has name => (
  is => 'ro',
  isa => Str,
);

has praat => (
  is => 'ro',
  lazy => 1,
  default => sub {
    require Praat;
    Praat->new;
  },
);

has root => (
  is => 'ro',
  isa => Dir,
  lazy => 1,
  default => sub { $_[0]->praat->pref_dir->child('plugin_' . $_[0]->name) },
);

has is_installed => (
  is => 'rw',
  isa => Bool,
  lazy => 1,
  default => sub { $_[0]->root->is_dir },
);

sub BUILDARGS {
  my $class = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  $args->{name} =~ s/^plugin_([\w\d]+)/$1/;

  return $args;
}

# VERSION

1;
