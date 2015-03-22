# ABSTRACT: install new plugins
package CPrAN::Command::install;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
    [ "yes|y", "do not ask for confirmation" ],
    [ "force|f", "print debugging messages" ],
    [ "debug", "force installation of plugin" ],
  );
}

sub description {
  return "Install new CPrAN plugins";
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Missing arguments") unless @{$args};

  # Users might be tempted to input the names of plugin as "plugin_name", but
  # this is not correct. The "plugin_" prefix is not part of the plugin's name,
  # but a (clumsy) way for Praat to recognize plugin directories.
  my $prefix_warning = 0;
  foreach (0..$#{$args}) {
    if ($args->[$_] =~ /^plugin_/) {
      $prefix_warning = 1;
    }
    $args->[$_] =~ s/^plugin_//;
  }
  warn "W: Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning);
}

sub execute {
  my ($self, $opt, $args) = @_;

  # Get a hash of installed plugins (ie, plugins in the preferences directory)
  my %installed;
  $installed{$_} = 1 foreach (CPrAN::installed());

  # Plugins that are already installed cannot be installed again (unless the
  # user orders a forced-reinstall).
  # @names will hold the names of the plugins passed as arguments that are
  #   a) valid CPrAN plugin names; and
  #   b) not already installed (unless the user forces reinstallation)
  my @names;
  foreach (@{$args}) {
    if (exists $installed{$_} && !$opt->{force}) {
      warn "W: $_ is already installed\n";
    }
    else {
      my %known;
      $known{$_} = 1 foreach (CPrAN::known());
      if (exists $known{$_}) {
        push @names, 'cpran/' . $_;
      }
      else {
        warn "W: no plugin named $_\n";
      }
    }
  }

  # Get a source dependency tree for the plugins that are to be installed.
  # The dependencies() subroutine calls itself recursively to include the
  # dependencies of the dependencies, and so on.
  my @deps = dependencies($opt, \@names);

  # The source tree is then ordered to get a schedule of plugin installation.
  # In the resulting list, plugins with no dependencies come first, and those
  # that depend on them come later.
  my @ordered = order_dependencies(@deps);

  # Scheduled plugins that are already installed need to be removed from the
  # schedule
  # TODO(jja) What does --force mean in this context?
  my @schedule;
  foreach (@ordered) {
    push @schedule, $_ unless (exists $installed{$_->{name}});
  }

  # Output and user query modeled after apt's
  if (@schedule) {
    print "The following plugins will be INSTALLED:\n";
    print '  ', join(' ', map { $_->{name} } @schedule), "\n";
    print "Do you want to continue? [y/N] ";
    if (CPrAN::yesno($opt, 'n')) {
      foreach (@schedule) {

        # Now that we know what plugins to install and in what order, we get
        # them and install them
        print "Downloading archive for $_->{name}\n";
        my $gzip = get_archive( $opt, $_->{name}, '' );

        print "Extracting... ";
        install( $opt, $gzip );

        print "done\n";
      }
    }
    else {
      print "Abort.\n";
    }
  }
}

# Query the desired plugins for dependencies
# Takes either the name of a single plugin, or a list of names, and returns
# an array of hashes properly formatted for processing with order_dependencies()
sub dependencies {
  my ($opt, $args) = @_;

  use Path::Class;
  use File::Slurp;
  use YAML::XS;

  my @dependencies;

  # If the argument is a scalar, convert it to a list with it as its single item
  $args = [ $args ] if (!ref $args);

  foreach my $plugin (@{$args}) {

      # HACK(jja) Delete a possible "cpran/" prefix
      $plugin =~ s/^cpran\///;

      my $file = file($CPrAN::ROOT, $plugin);
      my $descriptor = read_file($file->stringify);
      my $yaml = YAML::XS::Load( $descriptor );

      # HACK(jja) Only consider CPrAN dependencies and delete the "cpran/"
      # prefix in the dependency list
      my @deps;
      foreach my $dep (keys %{$yaml->{Depends}}) {
        if ($dep =~ /^cpran/) {
          $dep =~ s/^cpran\///;
          push @deps, $dep;
        }
      }

      # HACK(jja) We need to restore the stripped "cpran/" prefix so we can
      # recognize them later
      my @vers = map {
        $yaml->{Depends}->{'cpran/' . $_};
      } @deps;

      my %deps = (
        name     => $yaml->{Plugin},
        requires => \@deps,
        version  => \@vers,
      );

      push @dependencies, \%deps;
      # Recursively query dependencies for all dependencies
      foreach (@{$deps{requires}}) {
        @dependencies = (@dependencies, dependencies($opt, $_));
      }
  }
  return @dependencies;
}

# Order required packages, so that those that are depended up come up first than
# those that depend on them
# The argument is an array of hashes, each of which needs a "name" key that
# identifies the item, and a "requires" holding the reference to an array with
# the names of the items that are required.
# Closely modeled after http://stackoverflow.com/a/12166653/807650
sub order_dependencies {
  use Graph qw();

   my %recs;
   my $graph = Graph->new();
   foreach my $rec (@_) {
      my ($name, $requires) = @{$rec}{qw( name requires )};

      $graph->add_vertex($name);
      foreach (@{$requires}) {
        $graph->add_edge($_, $name);
      }

      $recs{$name} = $rec;
   }

   return map $recs{$_}, $graph->topological_sort();
}

sub get_archive {
  my ($opt, $name, $version) = @_;

  use GitLab::API::v3;

  my $api = GitLab::API::v3->new(
    url   => 'https://gitlab.com/api/v3/',
    token => $CPrAN::TOKEN,
  );

  my $project = shift $api->projects({ search => 'plugin_' . $name });
  my $tag;
  if ($version eq '') {
    $tag = shift $api->tags($project->{id});
  }
  else {
    my $tags = $api->tags($project->{id});
    print Dumper($tags);
    $tag = shift @{$tags};
  }

  my %params = ( sha => $tag->{commit}->{id} );
#   # HACK(jja) This should work, but the Perl GitLab API seems to currently be
#   # broken. See https://github.com/bluefeet/GitLab-API-v3/issues/5
#   my $archive = $api->archive(
#     $project->{id},
#     \%params
#   );

  # HACK(jja) This is a workaround while the Perl GitLab API is fixed
  use LWP::Curl;

  my $referer = '';
  my $get_url = 'http://gitlab.com/api/v3/projects/' . $project->{id} . '/repository/archive?private_token=' . $CPrAN::TOKEN . '&sha=' . $params{sha};
  my $lwpcurl = LWP::Curl->new();
  return $lwpcurl->get($get_url, $referer);
}

sub install {
  my ($opt, $gzip) = @_;

  use Archive::Extract;
  use File::Temp;
  use Path::Class;

  my $tmp = File::Temp->new(
    dir => '.',
    template => 'cpranXXXXX',
    suffix => '.tar.gz',
  );
  my $archive = file($tmp->filename);
  my $fh = $archive->openw();
  $fh->print($gzip);
  print "D: Wrote to $archive\n" if $opt->{debug};

  my $ae = Archive::Extract->new( archive => $tmp->filename );

  my $ok = $ae->extract( to => $CPrAN::PRAAT )
    or die "Could not extract package: $ae->error";

  # GitLab archives have a ".git" suffix in their directory names
  # We need to remove that suffix
  use File::Copy;
  my $final_path = $ae->extract_path;
  $final_path =~ s/\.git$//;
#   my $dir = dir( $CPrAN::PRAAT, $path );
  move($ae->extract_path, $final_path);
}

1;
