package Praat;

use Moo;
use MooX::HandlesVia;
use MooX::late;

use Log::Any qw( $log );
use Types::Standard qw( HashRef Str Undef );
use Types::Path::Tiny qw( Path );
use Types::Praat qw( Version );

require Carp;

has pref_dir => (
  is => 'rw',
  isa => 'Path',
  lazy => 1,
  coerce => 1,
  builder => '_build_pref_dir',
);

has bin => (
  is => 'ro',
  isa => 'Path|Undef',
  lazy => 1,
  coerce => 1,
  default => sub {
    require File::Which;
    File::Which->import;
    which('praat') || which('praat.exe') || which('Praat') || which('praatcon');
  },
);

has version => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  isa => 'Version',
  coerce => 1,
  builder => '_build_version'
);

has plugins => (
  is => 'rw',
  isa => 'HashRef',
  handles_via => 'Hash',
  handles => {
    list_plugins => 'keys',
  },
  lazy => 1,
  builder => 'map_plugins',
);

sub run_script {
  my ($self, $script, @args) = @_;

  $log->trace('Executing Praat command');

  return undef unless defined $script;

  my @opts = (ref $args[-1] eq 'ARRAY') ? @{pop @args} : (
    '--pref-dir=' . $self->pref_dir,
    '--ansi',
    '--run'
  );

  $log->trace('  ', $self->bin, @opts, $script, @args)
    if $log->is_trace;

  use Capture::Tiny qw( capture );
  return capture {
    local $ENV{PATH} = '';
    system(
      $self->bin,
      @opts,
      $script,
      @args
    );
  };
}

sub _build_pref_dir {
  for ($^O) {
    if (/darwin/) {
      return join('/', $ENV{HOME}, 'Library', 'Preferences', 'Praat Prefs');
    }
    elsif (/MSWin32/) {
      return join('/', $ENV{HOMEPATH}, 'Praat');
    }
    else {
      return join('/', $ENV{HOME}, '.praat-dir');
    }
  }
}

sub _build_version {
  my ($self) = @_;

  $log->trace('Detecting current version of Praat');

  die 'Binary is undefined!' unless defined $self->bin;

  my ($buffer, $version);
  open my $fh, '<:raw', $self->bin;
  # Read binary into the buffer after any residual copied from the last chunk
  while( my $read = read $fh, $buffer, 4096, pos( $buffer ) || 0 ) {
    while( $buffer =~ m[([4-9]\.\d\.\d{2})]g ) {
      $version = $1;
      last;
    }

    ## Slide the unsearched remainer to the front of the buffer.
    no warnings qw( uninitialized );
    substr( $buffer, 0, pos( $buffer ) ) = substr $buffer, pos( $buffer );
  }
  close $fh;

  $log->trace('Version detection complete');

  return $version;
};

sub map_plugins {
  my ($self) = @_;

  my %h;
  foreach ($_[0]->pref_dir->children(qr/^plugin_/)) {
    my $name = $_->basename;
    $name =~ s/^plugin_//;

    require Praat::Plugin;
    $h{$name} = Praat::Plugin->new(
      name => $_->basename,
      root => $_,
    );
  }
  return \%h;
}

our $VERSION = '0.04'; # VERSION

1;
