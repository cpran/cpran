# ABSTRACT: Initialise a CPrAN installation
package CPrAN::Command::init;

use CPrAN -command;

use strict;
use warnings;

use Carp;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<init> - Initialise a CPrAN installation

=head1 SYNOPSIS

cpran init [options]

=head1 DESCRIPTION

Perform the initial setup for CPrAN, to install it as a Praat plugin.

=cut

sub description {
  return "Perform the initial setup for CPrAN, to install it as a Praat plugin";
}

=pod

B<init> will install CPrAN as a Praat plugin.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;
}

=head1 EXAMPLES

    # Initialise CPrAN
    cpran init

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  my $app = CPrAN->new();
  my %params;

  %params = %{$opt};
  $params{virtual} = 1;

  my $cmd;

  $cmd = CPrAN::Command::update->new({});
  my $cpran = $app->execute_command($cmd, \%params, 'cpran');
  $cpran = pop @{$cpran};

  %params = %{$opt};
  $params{yes} = 1;

  $cmd = CPrAN::Command::install->new({});
  $app->execute_command($cmd, \%params, $cpran);
}

sub opt_spec {
  return (
#     [ "installed|i"   => "search on installed plugins" ],
#     [ "wrap!"         => "enable / disable line wrap for result table" ],
  );
}

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

1;
