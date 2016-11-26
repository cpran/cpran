package CPrAN::Role::Reads::WorkingPlugin;

use Moose::Role;

around execute => sub {
  my $orig = shift;
  my $self = shift;

  my ($opt, $args) = @_;

  require CPrAN::Plugin;
  require Path::Tiny;

  if (!scalar @{$args}) {
    # If no arguments are given, read a plugin from the current directory
    push @{$args}, $self->app->new_plugin(
      name => Path::Tiny->cwd->basename,
      root => Path::Tiny->cwd,
    );
  }

  return $self->$orig($opt, $args);
};

1;
