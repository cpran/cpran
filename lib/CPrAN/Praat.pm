package CPrAN::Praat;
# ABSTRACT: A Praat pseudo-class for CPrAN

# use uni::perl;

use Moose;
use Log::Any;
use Types::Path::Tiny qw( File Dir );
use Path::Tiny;
use CPrAN::Types;

require Carp;
use Try::Tiny;

=head1 NAME

=encoding utf8

B<CPrAN::Praat> - Praat pseudo-class for CPrAN

=head1 SYNOPSIS

my $praat = CPrAN::Praat->new();

# safely removes the locally installed copy of Praat
$praat->remove

# download the archive of the latest version of Praat
$praat->download

# respectively return the current or latest version of Praat for this platform
$praat->current
$praat->latest

=head1 DESCRIPTION

A pseudo-class to encapsulate CPrAN's handling of Praat itself.

=cut

has _barren => (
  is => 'rw',
  lazy => 1,
  default => 0,
);

# Set during first call to latest
has _package_name => (
  is => 'rw',
  init_arg => undef,
  lazy => 1,
  default => sub {
    $_[0]->latest;
    return $_[0]->_package_name;
  },
);

has _package_url => (
  is => 'rw',
  init_arg => undef,
  lazy => 1,
  default => sub {
    $_[0]->latest;
    return $_[0]->_package_url;
  },
);

has _releases_endpoint => (
  is => 'ro',
  lazy => 1,
  default => 'https://api.github.com/repos/praat/praat/releases',
);

has [qw( _os _ext _bit )] => (
  is => 'ro',
);

has pref_dir => (
  is => 'rw',
  isa => Dir,
  lazy => 1,
  coerce => 1,
  builder => '_build_pref_dir',
);

has releases => (
  is => 'ro',
  isa => 'ArrayRef[HashRef]',
  lazy => 1,
  builder => '_build_releases',
);

has bin => (
  is => 'ro',
  isa => File,
  lazy => 1,
  coerce => 1,
  default => sub {
    use File::Which;
    which('praat') || which('praat.exe') || which('Praat') || which('praatcon'));
  },
);

has current => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  isa => 'SemVer',
  builder => '_build_current'
);

has latest => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  coerce => 1,
  isa => SemVer,
  builder => '_build_remote',
);

has requested => (
  is => 'rw',
  isa => SemVer|Undef,
  coerce => 1,
);

has logger => (
  is => 'ro',
  default => sub { Log::Any->get_logger },
);

sub BUILDARGS {
  my $class = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  for ($^O) {
    if (/darwin/) {
      $args->{_os}  = "mac";
      $args->{_ext} = "\.dmg";
    }
    elsif (/MSWin32/) {
      $args->{_os}  = "win";
      $args->{_ext} = "\.zip";

      $ENV{PROCESSOR_ARCHITECTURE} //= '';
      $ENV{PROCESSOR_ARCHITEW6432} //= '';

      if (uc $ENV{PROCESSOR_ARCHITECTURE} =~ /(AMD64|IA64)/ or
          uc $ENV{PROCESSOR_ARCHITEW6432} =~ /(AMD64|IA64)/) {
        $args->{_bit} = 64;
      }
      else {
        $args->{_bit} = 32;
      }
    }
    else {
      $args->{_os}  = "linux";
      $args->{_ext} = "\.tar\.gz";
    }
  }

  unless (defined $args->{_bit}) {
    try {
      my $cmd = 'uname -a';
      open CMD, "$cmd 2>&1 |"
        or die ("Could not execute $cmd: $!");
      chomp(my $uname = <CMD>);
      if ($uname =~ /\bx86_64\b/) {
        $args->{_bit} = 64;
      }
      else {
        $args->{_bit} = 32;
      }
    }
    catch {
      warn "Could not determine system bitness. Defaulting to 32bit\n";
      $args->{_bit} = 32;
    };
  }

  return $args;
}

=head1 METHODS

=over

=cut

=item B<remove()>

Removes praat from disk

=cut

sub remove {
  my ($self, $opt) = @_;

  die 'Binary is undefined!' unless defined $self->bin;

  my $removed = $self->bin->remove
    or warn sprintf("Could not remove %s: %s\n", $self->bin, $!);

  return $removed;
}

=item B<download(VERSION)>

Downloads a specific archived version of Praat, or the latest version.

=cut

sub download {
  my $self    = shift;
  my $opt     = (ref $_[-1] eq 'HASH') ? pop @_ : {};
  my $version = shift // $self->latest;

  $opt->{quiet} //= 0;

  use LWP::UserAgent;
  my $ua = LWP::UserAgent->new;
  $ua->show_progress( 1 - $opt->{quiet} );

  $self->logger->trace('GET', $self->_package_url) if $self->logger->is_trace;
  my $response = $ua->get( $self->_package_url );
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    die $response->status_line;
  }
}

=item B<execute(SCRIPT)>

Reads instructions from file and executes them with Praat.

=cut

sub execute {
  my ($self, $script, @args) = @_;

  $self->logger->trace('Executing Praat command');

  return undef unless defined $script;

  my @opts = (ref $args[-1] eq 'ARRAY') ? @{pop @args} : (
    '--pref-dir=' . $self->pref_dir,
    '--ansi',
    '--run'
  );

  $self->logger->trace('  ', $self->bin, @opts, $script, @args)
    if $self->logger->is_trace;

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

sub _build_remote {
  my ($self, $requested) = @_;

  use URI;
  use JSON qw( decode_json );
  use LWP::UserAgent;
  use SemVer;

  my $ua = LWP::UserAgent->new;

  my ($os, $bit, $ext) = ($self->_os, $self->_bit, $self->_ext);
  my $barren = $self->_barren ? 'barren' : '';
  my $pkgregex = qr/^praat(?'version'[0-9]{4})_${os}${bit}${barren}${ext}/;

  my @haystack;
  my $url;
  if ($self->requested) {
    $url = URI->new( $self->_releases_endpoint . '/tags/v' . $self->requested->stringify )
  }
  else {
    $url = URI->new( $self->_releases_endpoint . '/latest' )
  }

  $self->logger->trace('GET', $url) if $self->logger->is_trace;
  my $response = $ua->get( $url );
  if ($response->is_success) {
    @haystack = ( decode_json $response->decoded_content );
  }
  else {
    Carp::croak $response->status_line;
  }

  my ($latest, $found);
  my $once = 0;

  foreach (@haystack) {
    $latest = $_;
    ($found) = grep { $_->{name} =~ $pkgregex } @{$latest->{assets}};

    unless (defined $found) {
      $self->logger->info('Did not find suitable release in latest, looking back');
      @haystack = @{$self->releases} unless $once;
      $once = 1;
    }

    last if defined $found;
  }

  die 'Could not find ', ($self->requested // 'latest'), ' Praat release for this system', "\n"
    unless defined $found;

  $self->_package_name($found->{name});
  $self->_package_url($found->{browser_download_url});

  return SemVer->new( $latest->{tag_name} );
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

sub _build_current {
  my ($self) = @_;

  $self->logger->trace('Detecting current version of Praat');

  die 'Binary is undefined!' unless defined $self->bin;
  use SemVer;

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

  $self->logger->trace('Version detection complete');

  try {
    SemVer->new($version);
  }
  catch {
    die "Could not get current version of Praat: $_\n";
  };
};

sub _build_releases {
  my ($self) = @_;

  $self->logger->trace('Finding Praat releases');

  use JSON qw( decode_json );

  my @releases;

  my $ua = LWP::UserAgent->new();
  my ($next, $response);

  $next = $self->_releases_endpoint;
  # Repeat block is commented out to prevent
  # busting through the API request limit
  # do {
    $self->logger->trace('GET', $next) if $self->logger->is_trace;
    $response = $ua->get($next);
    die $response->status_line unless $response->is_success;

    my $tags = decode_json $response->decoded_content;
    foreach my $tag (@{$tags}) {
      try { $tag->{semver} = SemVer->new($tag->{tag_name}) }
      finally {
        push @releases , $tag unless @_;
      };
    };

  # ($next) = split /,/, $response->header('link') if $response->header('link');
  # if ($next =~ /rel="next"/) {
  #   $next =~ s/.*<([^>]+)>.*/$1/;
  # }
  # else {
  #   $next = undef;
  # }
  # } until !defined $next;

  @releases = sort { $b->{semver} <=> $a->{semver} } @releases;

  return \@releases;
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2016 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::deps|deps>,
L<CPrAN::Command::init|init>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
