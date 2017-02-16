package CPrAN::Command::init;
# ABSTRACT: initialise a CPrAN installation

use Moose;
use Log::Any qw( $log );

extends qw( MooseX::App::Cmd::Command );

require Carp;

has [qw(
  git test log reinstall force
)] => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
);

has '+git' => (
  lazy => 1,
  documentation => 'request / disable git support',
  default => 1,
);

has '+test' => (
  lazy => 1,
  default => 1,
  documentation => 'request / disable tests',
);

has '+log' => (
  lazy => 1,
  default => 1,
  documentation => 'request / disable log of tests',
);

has '+reinstall' => (
  lazy => 1,
  default => 0,
  documentation => 're-install requested plugins',
);

has '+force' => (
  lazy => 1,
  default => 0,
  documentation => 'ignore failing tests',
);

=head1 NAME

=encoding utf8

B<init> - Initialise a CPrAN installation

=head1 SYNOPSIS

cpran init [options]

=head1 DESCRIPTION

The [cpran plugin][] serves as a bridge between the actions of the
[CPrAN client][cprandoc] and Praat. Te plugin on its own does very little, but
it can be used by other plpugins to e.g. populate a single menu with their
exposed commands, instead of cluttering the Praat menu.

In the future, modifying its list of dependencies (currently empty) will
also make it possible to flag certain plugins as "core", and make them available
in all CPrAN installations.

This command installs the [cpran plugin][] on an otherwise empty system.

=cut

=head1 EXAMPLES

    # Initialise CPrAN
    cpran init

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  if (!$self->reinstall and -e $self->app->praat->pref_dir->child('plugin_cpran')) {
    print 'CPrAN is already initialised. Nothing to do here!', "\n"
      unless $self->app->quiet;
    return;
  }

  print 'Initialising CPrAN bridge...', "\n"
    unless $self->app->quiet;

  my ($cpran) = $self->app->run_command( update => 'cpran', {
    quiet => 1,
  });

  my @plugins = $self->app->run_command( deps => $cpran, {
    quiet => 1,
  });
  pop @plugins;

  $self->app->run_command( update => @plugins, {
    quiet => 1,
  });

  $self->app->run_command( install => @plugins, $cpran, {
    quiet => 1,
    yes => 1,
    map { $_ => $self->$_ } qw( git test force reinstall )
  });

  if ($cpran->is_installed) {
    print 'CPrAN is initialised!', "\n",
          'You should now run \'cpran update\' to refresh the plugin directory', "\n"
      unless $self->app->quiet;
    return 1;
  }
  else {
    print 'Could not initialise CPrAN', "\n"
      unless $self->app->quiet;
    return 0;
  }
}

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
L<CPrAN::Command::install|install>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

our $VERSION = '0.04'; # VERSION

__PACKAGE__->meta->make_immutable;
no Moose;

1;
