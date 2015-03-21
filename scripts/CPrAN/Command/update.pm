# ABSTRACT: Update local CPrAN list
package CPrAN::Command::update;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Path::Class;
use autodie;

# No options
sub opt_Spec {
  return (
    [ "verbose|v", "increase verbosity" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("No arguments allowed") if @{$args};
}

my $api = GitLab::API::v3->new(
  url   => 'https://gitlab.com/api/v3/',
  token => 'WMe3t_ANxd3yyTLyc7WA',
);

sub execute {
  my ($self, $opt, $args) = @_;

  use GitLab::API::v3;
  use YAML::XS;
  use MIME::Base64;
  use File::Path;

  my $projects = $api->group('133578')->{projects};

  my $dir = dir( $CPrAN::ROOT );

  foreach my $plugin (@{$projects}) {
    my $name = substr($plugin->{name}, 7);
    my $file = $dir->file($name . '.yaml');

    print "Fetching $name... ";
#     if $opt->{verbose};

    my $descriptor = decode_base64(
      $api->file($plugin->{id}, {
        file_path => 'cpran.yaml',
        ref => 'master',
      })->{content}
    );
    eval { YAML::XS::Load( $descriptor ) };
    if ($@) {
      print "error: skipping\n";
#       if $opt->{verbose};
      $file->remove();

    } else {
      my $fh = $file->openw();
      $fh->print($descriptor);
      print "done\n";
#       if $opt->{verbose};
    }
  }

}

1;
