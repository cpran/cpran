# ABSTRACT: show specified plugin descriptor
package CPrAN::Command::show;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<show> - Shows details of CPrAN plugins

=head1 SYNOPSIS

cpran show [options] [arguments]

=head1 DESCRIPTION

Shows the descriptor of specified plugins. Depending on the options used, it can
be used to display information about the latest available version, or the
currently installed version.

=cut

sub description {
  return "Show details for specified CPrAN plugins";
}

=pod

Arguments to B<search> must be at least one and optionally more plugin names
whose descriptors will be displayed.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Must provide a plugin name") unless @{$args};
  foreach (@{$args}) {
    croak "Empty argument" unless $_;
  }
}

=head1 EXAMPLES

    # Show details of a plugin
    cpran show oneplugin
    # Show the descriptors of many installed plugins
    cpran show -i oneplugin anotherplugin

=cut

# TODO(jja) Break execute into smaller chunks
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

=head1 OPTIONS

=over

=item B<--installed>

Show the descriptor of installed CPrAN plugins.

=back

=cut

sub opt_spec {
  return (
    [ "installed|i" => "only consider installed plugins" ],
  );
}

=head1 METHODS

=over

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,
L<CPrAN::Command::remove|remove>

=cut

1;
