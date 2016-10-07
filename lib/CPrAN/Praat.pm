package CPrAN::Praat;
# ABSTRACT: A Praat pseudo-class for CPrAN

use strict;
use warnings;

use Moose;

use Carp;
use Try::Tiny;
binmode STDOUT, ':utf8';

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

# Set during first call to latest
has _package => (
  is => 'rw',
  init_arg => undef,
  lazy => 1,
  default => sub {
    my $self = shift;
    $self->latest;
    return $self->_package;
  },
);

has [qw( _os _ext _bit )] => (
  is => 'ro',
  init_arg => undef,
);

has [qw( _options )] => (
  is => 'ro',
);

has upstream => (
  is => 'ro',
  lazy => 1,
  default => 'http://www.fon.hum.uva.nl/praat/',
);

has pref_dir => (
  is => 'ro',
  isa => 'Path::Class::Dir',
  lazy => 1,
  default => sub {
    use Path::Class;

    for ($^O) {
      if (/darwin/) {
        return dir '', $ENV{HOME}, 'Library', 'Preferences', 'Praat Prefs';
      }
      elsif (/MSWin32/) {
        return dir '', $ENV{HOMEPATH}, 'Praat';
      }
      else {
        return dir '', $ENV{HOME}, '.praat-dir';
      }
    }
  }
);

has bin => (
  is => 'ro',
  isa => 'Path::Class::File',
  lazy => 1,
  default => sub {
    use Path::Class;
    use File::Which;
    file(which('praat')     ||
         which('praat.exe') ||
         which('Praat')     ||
         which('praatcon'));
  }
);

has current => (
  is => 'ro',
  lazy => 1,
  isa => 'SemVer',
  default => sub {
    my ($self) = @_;

    return undef unless defined $self->bin;

    use SemVer;
    use Capture::Tiny qw( capture );

    use File::Temp;
    my $script  = File::Temp->new(
      TEMPLATE => 'pscXXXXX',
      SUFFIX   => '.praat'
    );
    print $script "echo 'praatVersion\$'";
    my ($stdout, $stderr, @result) = $self->execute($script);
    chomp $stdout;

    use Path::Class;
    use Try::Tiny;

    try {
      SemVer->new($stdout);
    }
    catch {
      die "Could not get current version of Praat: $_\n";
    };
  },
);

has latest => (
  is => 'ro',
  lazy => 1,
  isa => 'SemVer',
  default => sub {
    my ($self) = @_;

    use HTML::Tree;
    use LWP::UserAgent;
    use SemVer;

    my $tree     = HTML::Tree->new;
    my $ua       = LWP::UserAgent->new;
    my $pkgregex = qr/^praat(?'version'[0-9]{4})_$self->{os}$self->{bit}$self->{ext}/;

    my $response = $ua->get(
      $self->upstream . 'download_' . $self->{_os} . '.html'
    );

    if ($response->is_success) {
      $tree->parse( $response->decoded_content );
      $tree->elementify;
      my $pkglink = $tree->look_down(
        '_tag', 'a',
        sub { $_[0]->as_text =~ /$pkgregex/; }
      );

      $self->package($pkglink->as_trimmed_text);

      if ($self->package =~ /$pkgregex/) {
        my $v = $+{version};
        $v =~ s/(\d)(\d{2})$/.$1.$2/;
        return SemVer->new($v);
      }
    }
    else {
      die $response->status_line;
    }
  },
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
      if (uc $ENV{PROCESSOR_ARCHITECTURE} =~ /(AMD64|IA64)/ and
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

sub BUILD {
  $_[0]->current;
}

=head1 METHODS

=over

=cut

=item B<remove()>

Removes praat from disk

=cut

sub remove {
  my ($self, $opt) = @_;

  use Path::Class;

  (defined $self->bin)
    or die sprintf("Could not find path to %s\n", $self->bin->basename);

  my $removed = $self->bin->remove
    or warn sprintf("Could not remove %s: %s\n", $self->bin, $!);

  return $removed;
}

=item B<release()>

List available releases of Praat

=cut

sub releases {
  my ($self, $opt) = @_;

  return @{$self->{releases}} if defined $self->{releases};

  use Path::Class;
  use JSON::Tiny q(decode_json);

  my @releases;

  my $ua = LWP::UserAgent->new();
  my ($next, $response);

  $next = 'https://api.github.com/repos/praat/praat/releases';
  do {
    $response = $ua->get($next);
    die $response->status_line unless $response->is_success;

    my $tags = decode_json $response->decoded_content;
    foreach my $tag (@{$tags}) {
      try { $tag->{semver} = SemVer->new($tag->{tag_name}) }
      finally {
        push @releases , $tag unless @_;
      };
    };

    ($next) = split /,/, $response->header('link');
    if ($next =~ /rel="next"/) {
      $next =~ s/.*<([^>]+)>.*/$1/;
    }
    else {
      $next = undef;
    }
  } until !defined $next;

  @releases = sort { $a->{semver} <=> $b->{semver} } @releases;
  $self->{releases} = \@releases;
  return @{$self->{releases}};
}

=item B<download(VERSION)>

Downloads a specific archived version of Praat, or the latest version.

=cut

sub download {
  my $self = shift;
  my $version = shift // $self->latest;

  my $opt = $self->_options;
  $opt->{quiet} = $opt->{quiet} // 0;

  use LWP::UserAgent;
  my $ua = LWP::UserAgent->new;
  $ua->show_progress( 1 - $opt->{quiet} );

  my $response = $ua->get( $self->upstream . $self->_package );
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

  use Capture::Tiny qw( capture );
  return capture {
    local $ENV{PATH} = '';
    system(
      $self->bin,
      '--pref-dir=' . $self->pref_dir,
      '--ansi',
      '--run',
      $script,
      @args
    );
  };
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
