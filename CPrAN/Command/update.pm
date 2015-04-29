# ABSTRACT: update local plugin list
package CPrAN::Command::update;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;

=encoding utf8

=head1 NAME

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

  use Path::Class;

  my $projects = list_projects($self, $opt, $args);

  my $dir = Path::Class::dir( CPrAN::root() );

  my $descriptors;
  foreach my $plugin (@{$projects}) {
    my $name = substr($plugin->{name}, 7);
    print "Fetching $name... " if $opt->{verbose};
    $descriptors .= fetch_descriptor($self, $opt, $plugin, $dir);
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

  my ($self, $opt, $plugin, $dir) = @_;

  my $api = GitLab::API::Tiny::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );
  my $file = $dir->file(substr($plugin->{name}, 7));

  my $commit_id = shift($api->commits( $plugin->{id} ))->{id};
  my $descriptor = $api->blob(
    $plugin->{id},
    $commit_id,
    { filepath => 'cpran.yaml' }
  );
  eval { YAML::XS::Load( $descriptor ) };
  if ($@) {
    print "error: skipping\n" if $opt->{verbose};
    print "$@" if ($opt->{verbose} > 1);
    $file->remove();

  } else {
    my $fh = $file->openw();
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
L<CPrAN::Command::show|show>,
L<CPrAN::Command::upgrade|upgrade>,
L<CPrAN::Command::remove|remove>

=cut

1;
