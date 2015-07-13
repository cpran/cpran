package CPrAN::Plugin;

use Carp;
use Path::Class;
use YAML::XS;
binmode STDOUT, ':utf8';

sub new {
  my ($class, $name) = @_;

  croak "Already a reference" if ref $name;

  my $self = bless {
    name  => $name,
    cpran => 0,
  }, $class;

  $self->_init();

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

sub _init {
  my ($self) = @_;

  my $root = dir(CPrAN::praat(), 'plugin_' . $self->{name});

  if ( -e $root ) {
    $self->{root} = $root->stringify;
    $self->{installed} = 1;
  }

  $self->{'local'} = $self->_read(
    file($root, 'cpran.yaml')
  );
  $self->{'remote'} = $self->_read(
    file(CPrAN::root(), $self->{name})
  );
}

sub update {
  my ($self) = @_;
  $self->_init;
}

=item remote_id()

Fetches the GitLab id for the plugin

=cut

sub remote_id {
  my $self = shift;

  return undef unless defined $self->{remote};

  use GitLab::API::Tiny::v3;
  my $api = GitLab::API::Tiny::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  foreach (@{$api->projects( { search => 'plugin_' . $self->{name} } )}) {
    return $_->{id} if ($_->{name} eq 'plugin_' . $self->{name});
  }
  return undef;
}


# =item get_latest_version()
# 
# Gets the latest known version for a plugin specified by name.
# 
# =cut
# 
# sub get_latest_version {
#   my $name = shift;
# 
#   my $app = CPrAN->new();
#   my $descriptor = $app->execute_command(
#     'CPrAN::Command::show',
#     { quiet => 1 },
#     $name
#   );
#   return $descriptor->{version};
# }

# =item compare_version()
# 
# Compares two semantic version numbers that match /^\d+\.\d+\.\d$/. Returns 1 if
# the first is larger (=newer), -1 if the second is larger, and 0 if they are the
# same;
# 
# =cut

sub is_latest {
  my ($self) = @_;

  return undef unless (defined $self->{remote});
  return 0 if (!defined $self->{local});
  return 1 if ($self->{remote}->{version} == $self->{local}->{version});

  die "Incorrectly formatted version number: $a, $b"
    if ($self->{remote}->{version} !~ /^\d+\.\d+\.\d+$/ ||
        $self->{local}->{version}  !~ /^\d+\.\d+\.\d+$/);

  my @remote = split /\./, $self->{remote};
  my @local  = split /\./, $self->{local};

  if    ($remote[0] > $local[0]) { return 0 }
  elsif ($remote[0] < $local[0]) { return 1 }
  elsif ($remote[1] > $local[1]) { return 0 }
  elsif ($remote[1] < $local[1]) { return 1 }
  elsif ($remote[2] > $local[2]) { return 0 }
  elsif ($remote[2] < $local[2]) { return 1 }
  else { die "Unreachable condition reached. Inconceivable!" }
}

sub test {
  use Test::Harness;

  my ($self) = @_;

  # TODO(jja) Plugins should be testable even before installation
  #           Perhaps the best way to do this would be to install them and then
  #           remove them if tests were unsuccessful. The removal would be
  #           skipped with --force.
  #           To mark a plugin being tested we could create some temporary lock
  #           file (maybe a setup.praat that deletes its own plugin?), which is
  #           removed when all goes well.
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
