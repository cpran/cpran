package Praat::Version;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;

extends 'SemVer';

has original => (
  is => 'rw',
);

sub BUILDARGS {
  my $self = shift;
  return {};
}

around new => sub {
  my ($orig, $self, $arg) = @_;

  my $original = $arg;
  if ($arg) {
    $arg =~ s/\.0+(?=\d)/./g;
    $arg =~ s/\+$//;
  }

  $self = $self->$orig($arg);
  $self->original($original);
  return $self;
};

sub praatify {
  my $v = sprintf '%d.%d.%02d', @{$_[0]->{version}};
     $v .= '-' . $_[0]->{extra} if $_[0]->{extra};
  return $v;
}

1;
