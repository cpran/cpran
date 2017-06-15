package CPrAN::Praat;
# ABSTRACT: An CPrAN-enabled wrapper for Praat

our $VERSION = '0.0410'; # VERSION

use strict;
use warnings;

use Moose;
extends 'Praat';

use Carp;
use CPrAN::Plugin;
use Log::Any qw( $log );
use Types::Praat qw( Version );
use Types::Standard qw( Undef );
use URI;
use LWP::UserAgent;
use JSON::MaybeXS qw( decode_json );
use Class::Load qw( try_load_class );

has protocol => (
  is => 'ro',
  init_arg => undef,
  default => sub { try_load_class('LWP::Protocol::https') ? 'http' : 'https' },
);

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
  default => sub {
    $_[0]->protocol . '://api.github.com/repos/praat/praat/releases'
  },
);

has [qw( _os _ext _bit )] => (
  is => 'ro',
);

has ua => (
  is => 'ro',
  lazy => 1,
  default => sub {
    LWP::UserAgent->new;
  }
);

has _ext => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  default => sub {
    use English;
    return ($OSNAME =~ /darwin/)
      ? '.dmg'
      : ($OSNAME =~ /mswin32/)
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
      : ($OSNAME =~ /mswin32/)
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
    if ($OSNAME =~ /mswin32/) {
      $ENV{PROCESSOR_ARCHITECTURE} //= q{};
      $ENV{PROCESSOR_ARCHITEW6432} //= q{};

      return (
        $ENV{PROCESSOR_ARCHITECTURE} =~ /(?:amd64|ia64)/ or
        $ENV{PROCESSOR_ARCHITEW6432} =~ /(?:amd64|ia64)/
      ) ? 64 : 32;
    }
    else {
      use Syntax::Keyword::Try;
      try {
        my $cmd = 'uname -a';
        open CMD, "$cmd 2>&1 |"
          or die ("Could not execute $cmd: $!");
        chomp(my $line = <CMD>);
        return ($line =~ /\bx86_64\b/) ? 64 : 32;
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
    or carp sprintf("Could not remove %s: %s\n", $self->bin, $!);
  return $removed;
}

sub fetch {
  my ($self) = @_;

  $self->_package_name(undef);
  $self->_package_url(undef);

  my ($os, $bit, $ext) =
    map { quotemeta $_ } ($self->_os, $self->_bit, $self->_ext);

  my $barren = ($self->_barren) ? 'barren' : q{};
  my $pkgregex = qr/^praat(?'version'[0-9]{4})_${os}${bit}${barren}${ext}/;

  my @haystack;
  my $url;
  if ($self->requested) {
    $url = URI->new(
      $self->_releases_endpoint . '/tags/v' . $self->requested->praatify
    )
  }
  else {
    $url = URI->new( $self->_releases_endpoint . '/latest' )
  }

  $log->trace('GET', $url) if $log->is_trace;

  my $response = $self->ua->get( $url );
  if ($response->is_success) {
    @haystack = ( decode_json $response->decoded_content );
  }
  else {
    $log->warn($response->status_line);
    return undef;
  }

  my ($latest, $found);

  foreach (@haystack) {
    $latest = $_;
    ($found) = grep { $_->{name} =~ $pkgregex } @{$latest->{assets}};
    last if defined $found;
  }

  unless (defined $found) {
    $log->warnf(
      'Could not find %s Praat release for this system',
      ($self->requested // 'latest')
    );
    return undef;
  }

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

  $self->ua->show_progress( 1 - $opt->{quiet} );

  $log->trace('GET', $self->_package_url);

  my $response = $self->ua->get( $self->_package_url );
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

  my @releases;

  my ($next, $response);

  $next = $self->_releases_endpoint;

  # Fetch only first page of results, to avoid busting through request limit
  $log->trace('GET', $next);

  $response = $self->ua->get($next);
  unless ($response->is_success) {
    $log->warn($response->status_line);
    return [];
  }

  my $tags = decode_json $response->decoded_content;
  foreach my $tag (@{$tags}) {
    use Syntax::Keyword::Try;
    try {
      $tag->{semver} = Praat::Version->new($tag->{tag_name});
    }
    catch {
      $log->tracef(q{  Skipping '%s'}, ($tag->{tag_name} // q{}));
      next;
    }

    $log->tracef(q{  Pushing '%s'}, $tag->{tag_name});
    push @releases, $tag;
  };

  @releases = sort { $b->{semver} <=> $a->{semver} } @releases;

  return \@releases;
}

override map_plugins => sub {
  my ($self) = @_;

  return {
    map {
      my $name = $_->basename;
      $name =~ s/^plugin_//;

      $name => CPrAN::Plugin->new(
        name  => $_->basename,
        root  => $_,
        cpran => $self->pref_dir->child('.cpran'),
      )
    } $self->pref_dir->children(qr/^plugin_/)
  };
};

1;
