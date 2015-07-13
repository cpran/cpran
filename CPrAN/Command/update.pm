# ABSTRACT: update local plugin list
package CPrAN::Command::update;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;

=head1 NAME

=encoding utf8

B<update> - Update the catalog of CPrAN plugins

=head1 SYNOPSIS

cpran update [options] [arguments]

=head1 DESCRIPTION

Updates the list of plugins known to CPrAN, and information about their latest
versions.

=cut

sub description {
  return "Updates the catalog of CPrAN plugins";
}

=pod

B<update> can take as argument a list of plugin names. If provided, only
information about those plugins will be retrieved. Otherwise, a complete list
will be downloaded. This second case is the recommended use.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;
}

=head1 EXAMPLES

    # Updates the entire catalog printing information as it goes
    cpran update -v
    # Update information about specific plugins
    cpran update oneplugin otherplugin

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  my $projects = list_projects($self, $opt, $args);

  my $descriptors;
  foreach my $source (@{$projects}) {
    if ($source->{name} =~ /^plugin_(\w+)$/) {
      print "Fetching $1... " if $opt->{verbose};
      $descriptors .= fetch_descriptor($self, $opt, $source);
    }
  }
  return $descriptors;
}

=head1 METHODS

=over

=cut

=item B<fetch_descriptor()>

Fetches the descriptor of a plugin and writes it into an appropriately named
file in the specified directory.

Returns the serialised downloaded descriptor.

=cut

# TODO(jja) This subroutine fetches _and_ writes. It should be broken apart.
sub fetch_descriptor {
  use GitLab::API::Tiny::v3;
  use YAML::XS;
  use Path::Class;

  my ($self, $opt, $source) = @_;

  my $api = GitLab::API::Tiny::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  my $commit = shift @{$api->commits( $source->{id} )};

  my $descriptor = $api->blob(
    $source->{id},
    $commit->{id},
    { filepath => 'cpran.yaml' }
  );

  eval { YAML::XS::Load( $descriptor ) };
  if ($@) {
    warn "E: Could not parse YAML descriptor" if $opt->{verbose};
    warn "$@" if ($opt->{verbose} > 1);
  } else {
    my $target = file( CPrAN::root(), $source->{name} );
    my $fh = $target->openw();
    $fh->print($descriptor);
    print "done\n" if $opt->{verbose};
  }
  return $descriptor;
}

=item B<list_projects()>

Provided with a list of plugin search terms, it returns a list of serialised
plugin objects. If the provided list is empty, it returns all the plugins it
can find in the CPrAN group.

=cut

sub list_projects {
  use GitLab::API::Tiny::v3;

  my ($self, $opt, $args) = @_;

  my $api = GitLab::API::Tiny::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  if (@{$args}) {
    my @projects = map {
      @{$api->projects( { search => 'plugin_' . $_ } )};
    } @{$args};
    return \@projects;
  }
  else {
    return $api->group( CPrAN::api_group() )->{projects};
  }
}

=back

=head1 OPTIONS

=over

=item B<--verbose>

Increase verbosity of output.

=back

=cut

sub opt_spec {
  return (
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
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::upgrade|upgrade>,

=cut

1;
