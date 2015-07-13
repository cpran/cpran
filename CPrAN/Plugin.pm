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

  $self->{'local'} = $self->_read(
    file($root, 'cpran.yaml')
  );
  $self->{'remote'} = $self->_read(
    file(CPrAN::root(), $name)
  );

  die "Plugin is uninstalled and unknown. Inconceivable"
    unless ($self->{cpran} || $self->{installed});

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

sub print {
  use Encode qw(encode decode);
  my ($self, $name) = @_;
  die "Not a valid field"
    unless $name =~ /^(local|remote)$/;

  die "No descriptor found"
    unless defined $self->{$name};

  use Data::Printer;
  print decode('utf8',
    file($self->{$name}->{descriptor})->slurp
  );
}

sub _read {
  my ($self, $file) = @_;
  if (-e $file) {
    my $yaml = Load( scalar $file->slurp );
    _force_lc_hash($yaml);
    $yaml->{name} = $yaml->{plugin};
    $yaml->{descriptor} = $file->stringify;
    $self->{cpran} = 1;
    return $yaml;
  }
  return undef;
}

sub _force_lc_hash {
  my $hashref = shift;
  foreach my $key (keys %{$hashref} ) {
    $hashref->{lc($key)} = $hashref->{$key};
    _force_lc_hash($hashref->{lc($key)}) if ref $hashref->{$key} eq 'HASH';
    delete($hashref->{$key}) unless $key eq lc($key);
  }
}

1;
