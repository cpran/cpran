package CPrAN::Command::init;
# ABSTRACT: initialise a CPrAN installation

use Moose;
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

use Carp;
use Path::Class;

has git => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  documentation => 'request / disable git support',
  default => 1,
);

has test => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 1,
  documentation => 'request / disable tests',
);

has log => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 1,
  documentation => 'request / disable log of tests',
);

has force => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
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

  my $praatdir = $opt->{praat} // CPrAN::praat_prefs($opt);
  if (-e dir($praatdir, 'plugin_cpran')) {
    print "CPrAN is already initialised. Nothing to do here!\n" unless $opt->{quiet};
    return;
  }

  my $app = CPrAN->new();
  my %params;

  %params = %{$opt};
  $params{virtual} = 1;
  $params{verbose} = 0;

  my $cmd;
  $cmd = CPrAN::Command::update->new({});
  my @cpran = $app->execute_command($cmd, \%params, 'cpran');

  %params = %{$opt};
  $params{yes} = 1;
  $params{test} = $opt->{test} // 1;
  $params{git} = $opt->{git} // 1;

  $cmd = CPrAN::Command::install->new({});
  $app->execute_command($cmd, \%params, pop @cpran);
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

# VERSION

1;
