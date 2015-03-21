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
  return ();
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("No options") if keys %{$opt};
  $self->usage_error("No arguments") if @{$args};
}

my $api = GitLab::API::v3->new(
  url   => 'https://gitlab.com/api/v3/',
  token => 'WMe3t_ANxd3yyTLyc7WA',
);

sub execute {
  my ($self, $opt, $args) = @_;

  use GitLab::API::v3;
  use YAML::XS;


  my $projects = $api->group('133578')->{projects};

  my $dir = dir("../.cpran");

  map {
    my $description = describe($_);
#     my $file = $dir->file($_->{name} . ".yaml");
#     my $fh = $file->openw();
#     $fh->print(Dump $description);
    print Dumper($description);
  } @{$projects};

}

1;
