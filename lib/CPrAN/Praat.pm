package CPrAN::Praat;

use strict;
use warnings;

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

sub new {
  my ($class, $opt) = @_;

  my $self = {
    home    => 'http://www.fon.hum.uva.nl/praat/',
    options => $opt // {},
  };

  for ($^O) {
    if (/darwin/) {
      $self->{os}  = "mac";
      $self->{ext} = "\.dmg";
    }
    elsif (/MSWin32/) {
      $self->{os}  = "win";
      $self->{ext} = "\.zip";
      if (uc $ENV{PROCESSOR_ARCHITECTURE} =~ /(AMD64|IA64)/ and
          uc $ENV{PROCESSOR_ARCHITEW6432} =~ /(AMD64|IA64)/) {
        $self->{bit} = 64;
      }
      else {
        $self->{bit} = 32;
      }
    }
    else {
      $self->{os}  = "linux";
      $self->{ext} = "\.tar\.gz";
    }
  }

  use File::Which;
  $self->{bin} = which('praatcon') || which('praat') || which('Praat');
  unless (defined $self->{bin}) {
    die "Could not find path to Praat executable. Make sure Praat is available\n";
  }

  $self = bless($self, $class);

  use Path::Class;
  $self->{path} = which($self->{bin});
  if (defined $self->{path}) {
    my @parts = file($self->{path})->components;
    $self->{bin} = pop @parts;
    $self->{path} = dir(@parts)->stringify;
  }

  $self->current;

  if (!defined $self->{bit}) {
    try {
      my $cmd = 'uname -a';
      open CMD, "$cmd 2>&1 |"
        or die ("Could not execute $cmd: $!");
      chomp(my $uname = <CMD>);
      $self->{bit} = ($uname =~ /b\x86_64$/) ? 64 : 32;
    }
    catch {
      warn "Could not determine system bitness. Defaulting to 32bit\n";
      $self->{bit} = 32;
    };
  }

  return $self;

}

=head1 METHODS

=over

=cut

=item B<remove()>

Removes praat from disk

=cut

sub remove {
  my ($self) = @_;

  use Path::Class;

  die "Could not find path to $self->{bin}\n"
    unless defined $self->{path};

  my $full = file($self->{path}, $self->{bin})->stringify;

  my $removed = unlink($full)
    or die "Could not remove $full: $!\n";

  return $removed;
}

=item B<download(VERSION)>

Downloads a specific archived version of Praat, or the latest version.

=cut

sub download {
  my ($self, $version) = @_;

  $version = $version // $self->latest;
  my $opt = $self->{options};
  $opt->{quiet} = $opt->{quiet} // 0;

  use LWP::UserAgent;
  my $ua = LWP::UserAgent->new();
  $ua->show_progress( 1 - $opt->{quiet} );

  my $response = $ua->get( $self->{home} . $self->{package} );
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    die $response->status_line;
  }

}

=item B<current()>

Gets the current version of Praat

=cut

sub current {
  my ($self) = @_;

  return $self->{current} if defined $self->{current};

  die "Could not find path to $self->{bin}\n"
    unless defined $self->{path};

  try {
    my $tmpin  = File::Temp->new(TEMPLATE => 'pscXXXXX',  SUFFIX => '.praat' );
    my $tmpout = File::Temp->new(TEMPLATE => 'praat_versionXXXXX' );

    my $script = "praatVersion\$ > $tmpout";
    print $tmpin $script;

    use Path::Class;
    system($self->{bin}, $tmpin);
    $self->{current} = file($tmpout)->slurp;
  }
  catch {
    die "Could not get current version of Praat: $_\n";
  };

  return $self->{current};
}

=item B<latest()>

Gets the latest version of Praat

=cut

sub latest {
  my ($self) = @_;

  return $self->{latest} if defined $self->{latest};

  use HTML::Tree;
  use LWP::UserAgent;

  my $tree    = HTML::Tree->new();
  my $ua      = LWP::UserAgent->new;
  my $package = qr/^praat(?'version'[0-9]{4})_$self->{os}$self->{bit}$self->{ext}/;

  my $response = $ua->get( $self->{home} . "download_$self->{os}.html" );
  if ($response->is_success) {
    $tree->parse( $response->decoded_content );
    $tree->elementify;
    my $pkglink = $tree->look_down(
      '_tag', 'a',
      sub { $_[0]->as_text =~ /$package/; }
    );
    $self->{'package'} = $pkglink->as_trimmed_text;
    $self->{latest} = $+{version} if ($self->{package} =~ /$package/);

  }
  else {
    die $response->status_line;
  }

  return $self->{latest};
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

our $VERSION = '0.02007';

1;
