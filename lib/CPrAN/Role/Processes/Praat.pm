package CPrAN::Role::Processes::Praat;

use Moose::Role;

# Consume before CPrAN::Role::Reads::STDIN if
# Praat should be also read from STDIN

requires 'process_praat';

around execute => sub {
  my $orig = shift;
  my $self = shift;

  my ($opt, $args) = @_;

  if (scalar @{$args} eq 1 and $args->[0] =~ /\bpraat\b/i) {
    my ($n, $v) = split /:/, $args->[0];
    return $self->process_praat($v);
  }

  return $self->$orig($opt, $args);
};

1;
