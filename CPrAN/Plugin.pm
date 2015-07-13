package CPrAN::Plugin;

use Carp;
use Path::Class;
use YAML::XS;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<CPrAN::Plugin> - Plugin class for CPrAN

=head1 SYNOPSIS

my $plugin = CPrAN::Plugin->new( $name );

$plugin->is_installed  ; checks for local copy
$plugin->is_cpran      ; checks for presence of descriptor
$plugin->update        ; updates object's internal state

=head1 DESCRIPTION

Objects of class C<CPrAN::Plugin> represent plugins / packages for Praat,
distributable via CPrAN, its package manager. The class can represent any Praat
plugins, regardless of whether they are on CPrAN or not.

=cut

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

=head1 METHODS

=over

=cut

=item B<is_cpran()>

Checks if plugin has a descriptor that CPrAN can use.

=cut

sub is_cpran {
  my ($self) = @_;
  return $self->{cpran};
}

=item B<is_installed()>

Checks if the plugin is installed or not.

=cut

sub is_installed {
  my ($self) = @_;
  return $self->{installed};
}

=item B<update()>

Updates the internal state of the plugin, to reflect any changes in disk that
took place after the object's creation.

=cut

sub update {
  my ($self) = @_;
  $self->_init;
}

=item remote_id()

Fetches the CPrAN remote id for the plugin.

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

=item is_latest()

Compares the version on the locally installed copy of the plugin (if any) and
the one reported by the remote descriptor on record by the client (if any).

Returns true if installed version is the most recent the client knows about,
false if there is a newer version, and undefined if there is no remote version
to query.

=cut

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

=item test()

Runs tests for the plugin (if any). Returns the result of those tests.

=cut

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

=item print(I<FIELD>)

Prints the contents of the plugin descriptors, either local or remote. These
must be asked for by name. Any other names are an error.

=cut

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

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,

=cut

1;
