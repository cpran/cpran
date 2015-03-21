# ABSTRACT: List installed CPrAN plugins
package CPrAN::Command::list;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
    [ "debug", "prints why an entry is not in cpran" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use Text::Table;

  my @all_plugins = dir( $CPrAN::PRAAT )->children();
  my @cpran_plugins;
  map {
    push @cpran_plugins, $_ if (CPrAN::Command::list::is_cpran( $opt, $_) );
  } @all_plugins;

  my $output = Text::Table->new(
    "Name", "Version", "Description"
  );
  foreach (sort @cpran_plugins) {
    my $descriptor = read_file(file($_, 'cpran.yaml')->stringify);
    my $yaml;
    eval {
      $yaml = Load($descriptor);
    };
    if ($@) {
      print STDERR $_->basename, " has errors in descriptor\n" if $opt->{debug};
    }

    $output->add($yaml->{Plugin}, $yaml->{Version}, $yaml->{Description}->{Short});
  }
  print $output;
}

sub is_cpran {
  my ($opt, $arg) = @_;

  use YAML::XS;
  use File::Slurp;

  unless ($arg->is_dir) {
    print STDERR "D: ", $arg->basename, " is not a directory\n" if $opt->{debug};
    return 0;
  }
  unless ($arg->basename =~ /^plugin_/) {
    print STDERR $arg->basename, " is not a plugin\n" if $opt->{debug};
    return 0;
  }

  my @contents = $arg->children();

  my $descriptor = 0;
  map {
    $descriptor = 1 if $_->basename eq 'cpran.yaml';
  } @contents;
  unless ($descriptor) {
    print STDERR $arg->basename, " does not have a descriptor\n" if $opt->{debug};
    return 0;
  }

  return 1;
}

1;
