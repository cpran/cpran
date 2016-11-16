package CPrAN::Command::show;
# ABSTRACT: show information about plugins

use Moose;
use uni::perl;

with 'MooseX::Getopt';

extends qw( MooseX::App::Cmd::Command );

require Carp;

has installed => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in installed plugins',
  cmd_aliases => 'i',
);

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


=pod

Arguments to B<search> must be at least one and optionally more plugin names
whose descriptors will be displayed.

=cut

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

  my @plugins = map {
    CPrAN::Plugin->new( name => $_, cpran => $self->app ) unless ref $_;
  } @{$args};

  my @stream;
  foreach my $plugin (@plugins) {
    if (!defined $self->installed or $self->installed) {
      if ($plugin->is_installed) {
        push @stream, $plugin->_local;
        $plugin->print('local') unless ($self->app->quiet);
      }
      else {
        Carp::croak "$plugin->name is not installed";
      }
    }
    else {
      if ($plugin->is_cpran) {
        push @stream, $plugin->_remote;
        $plugin->print('remote') unless ($self->app->quiet);
      }
      else {
        Carp::croak "$plugin->name is not a CPrAN plugin";
      }
    }
  }

  return @stream;
}

=head1 OPTIONS

=over

=item B<--installed>

Show the descriptor of installed CPrAN plugins.

=back

=cut


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

# VERSION

1;
