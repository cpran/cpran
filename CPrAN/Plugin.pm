package CPrAN::Plugin;

use Path::Class;
use YAML::XS;

sub new {
  my ($class, $name) = @_;

  my $self = bless {
    name  => $name,
    cpran => 0,
  }, $class;

  my $root = dir(CPrAN::praat(), 'plugin_' . $name);
  if ( -e $root ) {
    $self->{root} = $root;
    $self->{installed} = 1;
  }

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

sub test {
  use Test::Harness;

  my ($self) = @_;

  # TODO(jja) Plugins should be testable even before installation
  #           That's the whole point!
  die "$self->{name} is not installed" unless ($self->is_installed);

  my $path = dir($self->{root}, 't');
  unless ( -e $path ) {
    warn "No tests for $self->{name}\n" if $opt->{verbose};
    return undef;
  }

  opendir (DIR, $path) or Carp::croak "$path: " . $!;

  my @tests;
  while (my $file = readdir(DIR)) {
    push @tests, file($path, $file) if ($file =~ /\.t$/);
  }
  @tests = sort @tests;

  # Run the tests
  my $praat;
  for ($^O) {
    if    (/darwin/)  { $praat = 'Praat'    } # Untested
    elsif (/MSWin32/) { $praat = 'praatcon' }
    else              { $praat = 'praat'    }
  }
  my $harness = TAP::Harness->new({
    failures  => 1,
    exec => [ $praat ],
  });
  my $aggregator = $harness->runtests(@tests);

  if ($aggregator->all_passed) { return 1 } else { return 0 }
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
