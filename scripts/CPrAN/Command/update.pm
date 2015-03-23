# ABSTRACT: update local plugin list
package CPrAN::Command::update;

use CPrAN -command;

use strict;
use warnings;
# use diagnostics;
use Data::Dumper;
use Path::Class;
use autodie;

sub opt_spec {
  return (
    [ "verbose|v+" => "increase verbosity" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  CPrAN::set_global( $opt );
}

sub execute {
  my ($self, $opt, $args) = @_;

  use GitLab::API::v3;
  use YAML::XS;
  use MIME::Base64;

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

1;
