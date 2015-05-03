# ABSTRACT: list all available plugins
package CPrAN::Command::list;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

=encoding utf8

=head1 NAME

B<list> - List all known CPrAN plugins

=head1 SYNOPSIS

cpran list [options]

=head1 DESCRIPTION

List plugins available through the CPrAN catalog.

=cut

sub description {
  return "List plugins available through the CPrAN catalog";
}

=pod

B<list> will show a list of all plugins available to CPrAN.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;
}

=head1 EXAMPLES

    # Show all available plugins
    cpran list

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  my $app = CPrAN->new();
  my %params = %{$opt};
  $params{quiet} = 1;

  return $app->execute_command('CPrAN::Command::search', \%params, '.*');
}

sub opt_spec {
  return (
    # [ "name|n"        => "search in plugin name" ],
    # [ "description|d" => "search in description" ],
    # [ "installed|i"   => "only consider installed plugins" ],
  );
}

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
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,
L<CPrAN::Command::remove|remove>

=cut

1;
