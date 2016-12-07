package CPrAN::Praat;

use Moose;
use Log::Any qw( $log );

extends 'Praat';

use Types::Praat qw( Version );
use Types::Standard qw( Undef );

require Carp;

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
  isa => Version|Undef,
  builder => 'fetch',
);

has requested => (
  is => 'rw',
  isa => Version|Undef,
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
    my $self = shift;
    $self->latest;
    return $self->_package_name;
  },
);

has _package_url => (
  is => 'rw',
  init_arg => undef,
  lazy => 1,
  default => sub {
    my $self = shift;
    $self->latest;
    return $self->_package_url;
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

has _ext => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  default => sub {
    use English;
    return ($OSNAME =~ /darwin/xmsi)
      ? '.dmg'
      : ($OSNAME =~ /mswin32/xmsi)
        ? '.zip'
        : '.tar.gz';
  },
);

has _os => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  default => sub {
    use English;
    return ($OSNAME =~ /darwin/)
      ? 'mac'
      : ($OSNAME =~ /mswin32/xmsi)
        ? 'win'
        : 'linux';
  },
);

has _bit => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  default => sub {
    use English;
    if ($OSNAME =~ /mswin32/xmsi) {
      $ENV{PROCESSOR_ARCHITECTURE} //= q{};
      $ENV{PROCESSOR_ARCHITEW6432} //= q{};

      return (
        $ENV{PROCESSOR_ARCHITECTURE} =~ /(amd64|ia64)/xmsi or
        $ENV{PROCESSOR_ARCHITEW6432} =~ /(amd64|ia64)/xmsi
      ) ? 64 : 32;
    }
    else {
      use Syntax::Keyword::Try;
      try {
        my $cmd = 'uname -a';
        open CMD, "$cmd 2>&1 |"
          or die ("Could not execute $cmd: $!");
        chomp(my $line = <CMD>);
        return ($line =~ /\bx86_64\b/xmsi) ? 64 : 32;
      }
      catch {
        $log->warn('Defaulting to 32 bit');
        return 32;
      }
    }
  },
);

sub BUILDARGS {
  my $class = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};
  return $args;
}

sub remove {
  my ($self) = @_;
  my $removed = $self->bin->remove
    or warn sprintf("Could not remove %s: %s\n", $self->bin, $!);
  return $removed;
}

sub fetch {
  my ($self) = @_;

  use URI;
  use JSON qw( decode_json );
  use LWP::UserAgent;

  $self->_package_name(undef);
  $self->_package_url(undef);
  my $ua = LWP::UserAgent->new;

  my ($os, $bit, $ext) = map { quotemeta $_ } ($self->_os, $self->_bit, $self->_ext);
  my $barren = $self->_barren ? 'barren' : '';
  my $pkgregex = qr/^praat(?'version'[0-9]{4})_${os}${bit}${barren}${ext}/;

  my @haystack;
  my $url;
  if ($self->requested) {
    $url = URI->new( $self->_releases_endpoint . '/tags/v' . $self->requested->praatify )
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

sub _build_releases {
  my ($self) = @_;

  $log->trace('Finding Praat releases');

  use JSON qw( decode_json );

  my @releases;

  my $ua = LWP::UserAgent->new();
  my ($next, $response);

  $next = $self->_releases_endpoint;
  # Fetch only first page of results, to avoid busting through request limit
  $log->trace('GET', $next) if $log->is_trace;
  $response = $ua->get($next);
  unless ($response->is_success) {
    $log->warn($response->status_line);
    return [];
  }

  my $tags = decode_json $response->decoded_content;
  foreach my $tag (@{$tags}) {
    use Syntax::Keyword::Try;
    try { $tag->{semver} = Praat::Version->new($tag->{tag_name}) }
    finally {
      push @releases , $tag unless @_;
    }
  };

  @releases = sort { $b->{semver} <=> $a->{semver} } @releases;

  return \@releases;
}

override map_plugins => sub {
  my ($self) = @_;

  my %h;
  foreach ($_[0]->pref_dir->children(qr/^plugin_/)) {
    my $name = $_->basename;
    $name =~ s/^plugin_//;

    require CPrAN::Plugin;
    $h{$name} = CPrAN::Plugin->new(
      name  => $_->basename,
      root  => $_,
      cpran => $self->pref_dir->child('.cpran'),
    );
  }
  return \%h;
};

# VERSION

1;
