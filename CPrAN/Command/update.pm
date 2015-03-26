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

  CPrAN::set_global( $opt );
}

=head1 EXAMPLES

    # Updates the entire catalog printing information as it goes
    cpran update -v
    # Update information about specific plugins
    cpran update oneplugin otherplugin

=cut

# TODO(jja) Break execute into smaller chunks
sub execute {
  my ($self, $opt, $args) = @_;

  use GitLab::API::v3;
  use YAML::XS;
  use MIME::Base64;
  use Path::Class;

  my $api = GitLab::API::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  my $projects;
  if (@{$args}) {
    my @p;
    foreach (@{$args}) {
      my $p = $api->projects( { search => 'plugin_' . $_ } );
      push @p, @{$p};
    }
    $projects = \@p;
  }
  else {
    $projects = $api->group( CPrAN::api_group() )->{projects};
  }

  my $dir = Path::Class::dir( CPrAN::root() );

  my $descriptors;
  foreach my $plugin (@{$projects}) {
    my $name = substr($plugin->{name}, 7);
    my $file = $dir->file($name);

    print "Fetching $name... " if $opt->{verbose};

    my $descriptor = decode_base64(
      $api->file($plugin->{id}, {
        file_path => 'cpran.yaml',
        ref => 'master',
      })->{content}
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
      $descriptors .= $descriptor;
    }
  }
  return $descriptors;
}

=head1 OPTIONS

=over

=item B<--verbose>

Increase verbosity of output.

=back

=cut

sub opt_spec {
  return (
    [ "verbose|v+" => "increase verbosity" ],
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

CPrAN, CPrAN::Command::install, CPrAN::Command::search,
CPrAN::Command::show, CPrAN::Command::upgrade, CPrAN::Command::remove,

=cut

1;
