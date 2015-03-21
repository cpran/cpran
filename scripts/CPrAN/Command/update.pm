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

#   $self->usage_error("No arguments allowed") if @{$args};
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

  my $projects = $api->group('133578')->{projects};

  my $dir = dir( $CPrAN::ROOT );

  foreach my $plugin (@{$projects}) {
    print "Fetching $plugin->{name}... ";
#     if $opt->{verbose};

    my $descriptor = decode_base64(
      $api->file($plugin->{id}, {
        file_path => 'cpran.yaml',
        ref => 'master',
      })->{content}
    );
    eval { $descriptor = Load($descriptor) };
    if ($@) {
      print "error: $@\n";
#       if $opt->{verbose};
    } else {
      my $file = $dir->file(substr($plugin->{name}, 7) . ".yaml");
      my $fh = $file->openw();
      $fh->print($descriptor);
      print "done\n";
#       if $opt->{verbose};
    }
  }

}

1;
