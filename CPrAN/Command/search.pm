# ABSTRACT: search among available CPrAN plugins
package CPrAN::Command::search;

use CPrAN -command;

use strict;
use warnings;
# use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
#     [ "name|n"        => "search in plugin name" ],
#     [ "description|d" => "search in description" ],
    [ "installed|i"   => "only consider installed plugins" ],
    [ "debug"         => "show debug messages" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Must provide a search term") unless @{$args};

  CPrAN::set_global( $self );
}

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use Text::Table;

  my $output;
  my @names;
  if ($opt->{installed}) {
    $output = Text::Table->new(
      "Name", "Local", "Remote", "Description"
    );

    @names = CPrAN::installed();
    print "D: " . scalar @names . " installed plugins\n" if $opt->{debug};
  }
  else {
    $output = Text::Table->new(
      "Name", "Version", "Description"
    );
    @names = CPrAN::known();
    print "D: " . scalar @names . " known plugins\n" if $opt->{debug};
  }
  @names = sort { "\L$a" cmp "\L$b" } @names;

  my @found;
  map {
    if (/$args->[0]/) {
      $output->add(make_row($opt, $_));
      push @found, $_;
    }
  } @names;

  if (@found) { print $output }
  else { print "No matches found\n" }

  return @found;
}

sub make_row {
  my ($opt, $name) = @_;

  use YAML::XS;
  use File::Slurp;

  my $yaml;
  my $content;
  my $remote_file = file(CPrAN::root(), $name);
  if ($opt->{installed}) {
    my $plugin = dir(CPrAN::praat(), 'plugin_' . $name);

    if (CPrAN::is_cpran( $opt, $plugin )) {
      my $local_file  = file( $plugin, 'cpran.yaml' );

      $content = read_file($local_file->stringify);
      $yaml = Load( $content );

      my $name          = $yaml->{Plugin};
      my $local_version = $yaml->{Version};
      my $description   = $yaml->{Description}->{Short};

      my $remote_version = '';
      if (-e $remote_file->stringify) {
        $content        = read_file($remote_file->stringify);
        $yaml           = Load( $content );
        $remote_version = $yaml->{Version};
      }

      return ($name, $local_version, $remote_version, $description);
    }
    else {
      # Not a CPrAN plugin
      return ($name, '', '', '[Not a CPrAN plugin]');
    }
  }
  else {
    $content = read_file($remote_file->stringify);
    $yaml = Load( $content );

    my $name = $yaml->{Plugin};
    my $remote_version = $yaml->{Version};
    my $description = $yaml->{Description}->{Short};

    return ($name, $remote_version, $description);
  }
}

1;
