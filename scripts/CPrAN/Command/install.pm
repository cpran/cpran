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
    [ "debug",    "print debugging messages" ],
  );
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

  # Plugins that are already installed cannot be installed again (unless we
  # want to re-install them, which might be necessary in the future).
  # @names will hold the names of the plugins passed as arguments that are
  #   a) valid CPrAN plugin names; and
  #   b) not already installed
  my @names;
  foreach (@{$args}) {
    if (exists $installed{$_}) {
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
#   print Dumper(\@deps);

  # The source tree is then ordered to get a schedule of plugin installation.
  # In the resulting list, plugins with no dependencies come first, and those
  # that depend on them come later.
  my @ordered = order_dependencies(@deps);
#   print Dumper(\@ordered);

  # Scheduled plugins that are already installed need to be removed from the
  # schedule
  my @schedule;
  foreach (@ordered) {
    push @schedule, $_ unless (exists $installed{$_->{name}});
  }

  print "The following plugins will be INSTALLED:\n";
  print '  ', join(' ', map { $_->{name} } @schedule), "\n";
  print "Do you want to continue? [y/N] ";
  if (CPrAN::yesno($opt, 'n')) {
    foreach (@schedule) {
      use GitLab::API::v3;

      print "Downloading archive for $_->{name}\n";

      # Now that we know what plugins to install and in what order, we get them
      my $api = GitLab::API::v3->new(
        url   => 'https://gitlab.com/api/v3/',
        token => $CPrAN::TOKEN,
      );

      my $project = shift $api->projects({ search => 'plugin_' . $_->{name} });
      my $tag = shift $api->tags($project->{id});

      my %params = ( sha => $tag->{commit}->{id} );
  #     # BUG(jja) This should work, but the Perl GitLab API seems to currently be
  #     # broken. See https://github.com/bluefeet/GitLab-API-v3/issues/5
  #     my $archive = $api->archive(
  #       $project->{id},
  #       \%params
  #     );
  #     print Dumper(\%params);

      # BUG(jja) This is a workaround while the Perl GitLab API is fixed
      use LWP::Curl;
      use File::Temp;
      use Path::Class;
      use Archive::Extract;

      my $referer = '';
      my $get_url = 'http://gitlab.com/api/v3/projects/' . $project->{id} . '/repository/archive?private_token=' . $CPrAN::TOKEN . '&sha=' . $params{sha};
      my $lwpcurl = LWP::Curl->new();
      my $content = $lwpcurl->get($get_url, $referer);

      my $tmp = File::Temp->new(
        dir => '.',
        template => 'tempXXXXX',
        suffix => '.tar.gz',
      );
      my $archive = file($tmp->filename);
      my $fh = $archive->openw();
      $fh->print($content);
      print "D: Wrote to $archive\n" if $opt->{debug};
      my $ae = Archive::Extract->new( archive => $tmp->filename );
      my $ok = $ae->extract( to => $CPrAN::PRAAT )
        or die "Could not extract package: $ae->error";

      # GitLab archives have a ".git" suffix in their directory names
      # We need to remove that suffix
      use File::Copy;
      my $dir = dir( $CPrAN::PRAAT, 'plugin_' . $_->{name} );
      move($ae->extract_path, $dir);
    }
  }
  else {
    print "Abort.\n";
  }
}

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

      # HACK(jja) Only consider CPrAN dependencies
      my @deps;
      foreach my $dep (keys %{$yaml->{Depends}}) {
        if ($dep =~ /^cpran/) {
          $dep =~ s/^cpran\///;
          push @deps, $dep;
        }
      }

      # HACK(jja) We need to restore the stripped "cpran/" prefix
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

1;
