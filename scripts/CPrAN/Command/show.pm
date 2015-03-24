# ABSTRACT: show specified plugin descriptor
package CPrAN::Command::show;

use CPrAN -command;

use strict;
use warnings;
use Carp;
# use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
    [ "installed|i" => "only consider installed plugins" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Must provide a plugin name") unless @{$args};
  foreach (@{$args}) {
    croak "Empty argument" unless $_;
  }

  CPrAN::set_global( $opt );
}

sub execute {
  my ($self, $opt, $args) = @_;

#   print Dumper($args);

  use Path::Class;
  use File::Slurp;

  # Get a hash of installed plugins (ie, plugins in the preferences directory)
  my %installed;
  $installed{$_} = 1 foreach (CPrAN::installed());

  # Get a hash of known plugins (ie, plugins in the CPrAN list)
  my %known;
  $known{$_} = 1 foreach (CPrAN::known());

  my $stream;
  my $file = '';
  foreach (@{$args}) {
    if ($opt->{installed}) {
      if (exists $installed{$_}) {
        $file = file( CPrAN::praat(), 'plugin_' . $_, 'cpran.yaml' );
      }
      else {
        croak "E: $_ is not installed";
      }
    }
    else {
      # TODO(jja) Why are we not using CPrAN::is_cpran() here?
      if (exists $known{$_}) {
        $file = file( CPrAN::root(), $_ );
      }
      else {
#         print Dumper($_);
        croak "E: $_ is not a CPrAN plugin";
      }
    }
    if ($file && -e $file->stringify) {
      my $content = read_file($file->stringify);
      my $s = $content;
      $stream .= $s;
      print decode('utf8', $s) unless $opt->{quiet};
    }
    else {
      warn "Cannot find $file->stringify\n" unless $opt->{quiet};
      return undef;
    }
  }
  return $stream;
}

1;
