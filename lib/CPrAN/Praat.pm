package CPrAN::Praat;

use Moose;

extends 'Praat';

use Log::Any qw( $log );
use Types::Path::Tiny qw( File Dir );
use Types::SemVer qw( SemVer );
use Types::Standard qw( Undef );

use Path::Tiny;
use CPrAN::Types;

require Carp;
use Try::Tiny;

has releases => (
  is => 'ro',
  isa => 'ArrayRef[HashRef]',
  lazy => 1,
  builder => '_build_releases',
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

sub remove {
  my ($self, $opt) = @_;

  die 'Binary is undefined!' unless defined $self->bin;

  my $removed = $self->bin->remove
    or warn sprintf("Could not remove %s: %s\n", $self->bin, $!);

  return $removed;
}

sub download {
  my $self    = shift;
  my $opt     = (ref $_[-1] eq 'HASH') ? pop @_ : {};
  my $version = shift // $self->latest;

  $opt->{quiet} //= 0;

  use LWP::UserAgent;
  my $ua = LWP::UserAgent->new;
  $ua->show_progress( 1 - $opt->{quiet} );

  $log->trace('GET', $self->_package_url) if $log->is_trace;
  my $response = $ua->get( $self->_package_url );
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    die $response->status_line;
  }
}

sub _build_remote {
  my ($self) = @_;

  use URI;
  use JSON qw( decode_json );
  use LWP::UserAgent;

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

  $log->trace('GET', $url) if $log->is_trace;
  my $response = $ua->get( $url );
  if ($response->is_success) {
    @haystack = ( decode_json $response->decoded_content );
  }
  else {
    $log->warn($response->status_line);
    return undef;
  }

  my ($latest, $found);
  my $once = 0;

  foreach (@haystack) {
    $latest = $_;
    ($found) = grep { $_->{name} =~ $pkgregex } @{$latest->{assets}};

    unless (defined $found) {
      $log->info('Did not find suitable release in latest, looking back');
      @haystack = @{$self->releases} unless $once;
      $once = 1;
    }

    last if defined $found;
  }

  $log->warn('Could not find', ($self->requested // 'latest'), 'Praat release for this system')
    and return(undef) unless defined $found;

  $self->_package_name($found->{name});
  $self->_package_url($found->{browser_download_url});

  $self->requested($latest->{tag_name}) unless defined $self->requested;
  return $latest->{tag_name};
}

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
    $log->trace('GET', $next) if $log->is_trace;
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

# VERSION

1;
