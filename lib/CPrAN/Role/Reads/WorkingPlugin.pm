package CPrAN::Role::Reads::WorkingPlugin;

use Moose::Role;

around execute => sub {
  my $orig = shift;
  my $self = shift;

  my ($opt, $args) = @_;

  use CPrAN::Plugin;
  use Cwd;
  use Path::Class;

  if (!scalar @{$args}) {
    # If no arguments are given, read a plugin from the current directory
    push @{$args}, CPrAN::Plugin->new(
      name => dir(cwd)->basename,
      root => dir(cwd),
      cpran => $self->app,
    );
  }

  return $self->$orig($opt, $args);
};

1;
