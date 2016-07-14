package CPrAN::Command::show;
# ABSTRACT: show specified plugin descriptor

use CPrAN -command;

use strict;
use warnings;

use Carp;
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

sub execute {
  my ($self, $opt, $args) = @_;

  use CPrAN::Plugin;
  use YAML::XS;

  my @stream;
  foreach my $name (@{$args}) {
    my $plugin = CPrAN::Plugin->new( $name );
    if ($opt->{installed}) {
      if ($plugin->is_installed) {
        push @stream, $plugin->{'local'};
        $plugin->print('local') unless ($opt->{quiet});
      }
      else {
        croak "$name is not installed";
      }
    }
    else {
      if ($plugin->is_cpran) {
        push @stream, $plugin->{'remote'};
        $plugin->print('remote') unless ($opt->{quiet});
      }
      else {
        croak "$name is not a CPrAN plugin";
      }
    }
  }

  return \@stream;
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

=cut

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2016 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
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
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

our $VERSION = '0.0304'; # VERSION

1;
