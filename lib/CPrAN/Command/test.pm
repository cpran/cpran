package CPrAN::Command::test;
# ABSTRACT: run tests for the given plugins

use Moose;
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';

use Carp;
use Try::Tiny;

has log => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'enable / disable test logs',
  cmd_aliases => 'l',
);

=head1 NAME

=encoding utf8

B<test> - Run tests for the specified plugin

=head1 SYNOPSIS

cpran test [options] plugin

=head1 DESCRIPTION

Run tests for the specified plugins. When called on its own it will simply
report the results of the test suites associated with the given plugins.
When called from within CPrAN (eg. as part of the installation process), it
will only report success if all tests for all given plugins were successful.

=cut

=head1 EXAMPLES

    # Run tests for the specified plugin
    cpran test plugin

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  use CPrAN::Plugin;

  my $outcome = 1;
  my @plugins = map {
    CPrAN::Plugin->new( name => $_, cpran => $self->app ) unless ref $_
  } @{$args};

  try {
    foreach my $plugin (@plugins) {
      my $result;
      $result = $plugin->test($opt);
      $outcome = $result if defined $result;
    }
  }
  catch {
    chomp;
    die "There were errors while testing:\n$_\n";
  };

  return $outcome;
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
L<CPrAN::Command::init|init>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
