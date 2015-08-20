# ABSTRACT: update local plugin list
package CPrAN::Command::update;

use CPrAN -command;

use strict;
use warnings;

use Carp;
use Try::Tiny;
binmode STDOUT, ':utf8';

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

  my $projects;
  try {
    $projects = list_projects($self, $opt, $args);
  }
  catch {
    chomp;
    warn "Could not connect to the server: $_\n";
    exit 1;
  };

  use Sort::Naturally;
  use WWW::GitLab::v3;
  use CPrAN::Plugin;
  
  my @updated;
  foreach my $source (@{$projects}) {
    # Ignore projects that are not public
    next if $source->{visibility_level} < 20;

    if ($source->{name} =~ /^plugin_(\w+)$/) {

      my $api = WWW::GitLab::v3->new(
        url   => CPrAN::api_url(),
        token => CPrAN::api_token(),
      );

      my $tags = $api->tags( $source->{id} );
      my @releases = grep { $_->{name} =~ /^v?\d+\.\d+\.\d+/ } @{$tags};
      @releases = sort { ncmp($a->{name}, $b->{name}) } @releases;
      
      # Ignore projects with no tags
      next unless @releases;
      my $latest = pop @releases;
      
      print "Fetching $1...\n" if $opt->{verbose};
      fetch_descriptor($self, $opt, $api, $source, $latest);
      push @updated, CPrAN::Plugin->new($1);
    }
  }
  return \@updated;
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
# TODO(jja) The fetching probably belongs in CPrAN::Plugin
sub fetch_descriptor {
  use YAML::XS;
  use Path::Class;
  use Encode qw(encode decode);

  my ($self, $opt, $api, $project, $tag) = @_;

  my $name;
  if ($project->{name} =~ /^plugin_(\w+)$/) { $name = $1 }
  else { die "Project is not a plugin" }

  my $pid = $project->{id};
  my $commit = $tag->{commit}->{id};
  
  my $descriptor = encode('utf-8', $api->blob(
    $pid, $commit,
    { filepath => 'cpran.yaml' }
  ), Encode::FB_CROAK );

  eval { YAML::XS::Load( $descriptor ) };
  if ($@) {
    warn "Could not parse YAML descriptor" if $opt->{verbose};
    warn "$@" if ($opt->{debug});
  } else {
    
    my $target = file( CPrAN::root(), $name );
    my $fh = $target->openw();
    $fh->print($descriptor);
  }
  return $descriptor;
}

=item B<list_projects()>

Provided with a list of plugin search terms, it returns a list of serialised
plugin objects. If the provided list is empty, it returns all the plugins it
can find in the CPrAN group.

=cut

sub list_projects {
  use WWW::GitLab::v3;

  my ($self, $opt, $args) = @_;

  my $api = WWW::GitLab::v3->new(
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
    return $api->projects;
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
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::upgrade|upgrade>

=cut

1;
