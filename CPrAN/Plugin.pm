package CPrAN::Plugin;

use Path::Class;
use Data::Printer;
use YAML::XS;

sub new {
  my ($class, $name) = @_;

  my $self = bless {
    name  => $name,
    cpran => 0,
  }, $class;

  my $root = dir(CPrAN::praat(), 'plugin_' . $name);
  $self->{installed} = 1 if ( -e $root );

  my $local = file(CPrAN::praat(), 'plugin_' . $name, 'cpran.yaml');
  if (-e $local) {
    my $yaml = Load( scalar $local->slurp );
    $yaml->{descriptor} = $local->stringify;
    $self->{'local'} = $yaml;
    $self->{cpran} = 1;
  }

  my $remote = file(CPrAN::root(), $name);
  if (-e $remote) {
    my $yaml = Load( scalar $remote->slurp );
    $yaml->{descriptor} = $remote->stringify;
    $self->{'remote'} = $yaml;
    $self->{cpran} = 1;
  }

  return $self;
}

sub is_cpran {
  my ($self) = @_;
  return $self->{cpran};
}

sub is_installed {
  my ($self) = @_;
  return $self->{installed};
}

1;
