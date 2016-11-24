package CPrAN::Role::Reads::WorkingPlugin;

use Moose::Role;

around execute => sub {
  my $orig = shift;
  my $self = shift;

  my ($opt, $args) = @_;

  use CPrAN::Plugin;
  require Path::Tiny;

  if (!scalar @{$args}) {
    # If no arguments are given, read a plugin from the current directory
    push @{$args}, CPrAN::Plugin->new(
      name => Path::Tiny->cwd->basename,
      root => Path::Tiny->cwd,
      cpran => $self->app,
    );
  }

  return $self->$orig($opt, $args);
};

1;
