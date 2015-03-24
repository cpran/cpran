# ABSTRACT: install new plugins
package CPrAN::Command::install;

use CPrAN -command;

use strict;
use warnings;
# use diagnostics;
use Data::Dumper;
use Carp;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
    [ "yes|y"   => "do not ask for confirmation" ],
    [ "force|f" => "print debugging messages" ],
    [ "debug"   => "force installation of plugin" ],
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
  $args = strip_prefix($args);

  foreach (@{$args}) {
    my @parts = split /-/, $_;
    push @parts, '' unless /-\d+\.\d+\.\d+$/;
    my $version = pop @parts;
    my $name = join '-', @parts;
    $_ = {
      version => $version,
      name    => $name,
    };
  }

  CPrAN::set_global( $opt );
}

sub execute {
  my ($self, $opt, $args) = @_;

  # Get a hash of installed plugins (ie, plugins in the preferences directory)
  my %installed;
  $installed{$_} = 1 foreach (CPrAN::installed());

  # Get a hash of known plugins (ie, plugins in the CPrAN list)
  my %known;
  $known{$_} = 1 foreach (CPrAN::known());

  # Plugins that are already installed cannot be installed again (unless the
  # user orders a forced-reinstall).
  # @plugins will hold the names and versions of the plugins passed as arguments
  # that are
  #   a) valid CPrAN plugin names; and
  #   b) not already installed (unless the user forces re-installation); or
  #   c) newer than those installed (unless the user forces downgrade)
  my @plugins;
  foreach my $plugin (@{$args}) {
    # BUG(jja) What to do here?
    use Config;
    if ($plugin->{name} eq 'cpran' && $Config{osname} eq 'MSWin32') {
      croak "Cannot currently use CPrAN to install CPrAN in Windows\n";
    }

    # User requested an unversioned plugin, default to the newest on record
    if ($plugin->{version} eq '') {
      $plugin->{version} = CPrAN::get_latest_version( $plugin->{name} );
    }

    if (exists $known{$plugin->{name}}) {
      my $install = 0;

      if (exists $installed{$plugin->{name}}) {

        use YAML::XS;

        my ($cmd) = $self->app->prepare_command('show');
        my $descriptor = $self->app->execute_command(
          $cmd, { quiet => 1, installed => 1 }, $plugin->{name}
        );

        my $newer = 0;
        if ($descriptor) {
          my $yaml = Load($descriptor);
          my $local = $yaml->{Version};
          $newer = CPrAN::compare_version( $local, $plugin->{version} );
        }

        if ($newer) {
          # Plugin is installed, but we are upgrading
          $install = 1;
        }
        else {
          if ($opt->{force}) {
            # Plugin is installed, but user forced re-install or downgrade
            $install = 1;
          }
          else {
            warn "W: $plugin->{name} is already installed. Use --force to reinstall\n";
          }
        }
      }
      else {
        # Plugin is not installed
        $install = 1;
      }
      push @plugins, $plugin if $install;
    }
    else {
      warn "W: no known plugin named $plugin->{name}\n"
    }
  }

  # Get a source dependency tree for the plugins that are to be installed.
  # The dependencies() subroutine calls itself recursively to include the
  # dependencies of the dependencies, and so on.
  my @deps = CPrAN::dependencies( $opt, \@plugins );

  # The source tree is then ordered to get a schedule of plugin installation.
  # In the resulting list, plugins with no dependencies come first, and those
  # that depend on them come later.
  my @ordered = CPrAN::order_dependencies( @deps );

  # Scheduled plugins that are already installed need to be removed from the
  # schedule
  # TODO(jja) What does --force mean in this context?
  # TODO(jja) 
  my @schedule;
  foreach (@ordered) {
    push @schedule, $_
      unless (exists $installed{$_->{name}} && !$opt->{force});
  }

  # Output and user query modeled after apt's
  if (@schedule) {
    unless ($opt->{quiet}) {
      print "The following plugins will be INSTALLED:\n";
      print '  ', join(' ', map { $_->{name} } @schedule), "\n";
      print "Do you want to continue? [y/N] ";
    }
    if (CPrAN::yesno( $opt, 'n' )) {
      PLUGIN: foreach (@schedule) {

        # Now that we know what plugins to install and in what order, we get
        # them and install them
        print "Downloading archive for $_->{name}\n" unless ($opt->{quiet});
        my $archive = get_archive( $opt, $_->{name}, '' );

        print "Extracting... " unless ($opt->{quiet});
        install( $opt, $archive );

        print "done\n" unless ($opt->{quiet});

        if ($_->{name} eq 'cpran') {
          # CPrAN is installing itself!
          # HACK(jja) currently, a reinstall deletes the original directory
          # which in the case of CPrAN will likely destroy the CPrAN root.
          # If that's the case, we rebuild it.
          rebuild_list($opt) unless (-e CPrAN::root());
        }
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
    }
  }
}

sub rebuild_list {
  my $opt = shift;

  CPrAN::make_root();

  my $app = CPrAN->new();

  # We copy the current options, in case custom paths have been passed
  my %params = %{$opt};
  $params{verbose} = 0;

  print "Rebuilding plugin list... " unless ($opt->{quiet});
  $app->execute_command('CPrAN::Command::update', \%params, ());
  print "done\n" unless ($opt->{quiet});
}

sub get_archive {
  my ($opt, $name, $version) = @_;

  use GitLab::API::v3;

  my $api = GitLab::API::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  my $project = shift @{$api->projects({ search => 'plugin_' . $name })};
  my $tag;
  if ($version eq '') {
    my @tags = @{$api->tags($project->{id})};
    croak "No tags for $name" unless (@tags);
    $tag = shift @tags;
  }
  else {
    # TODO(jja) Enable installation of specific versions
    my $tags = $api->tags($project->{id});
#     print Dumper($tags);
    $tag = shift @{$tags};
  }

  my %params = ( sha => $tag->{commit}->{id} );
  # # HACK(jja) This should work, but the Perl GitLab API seems to currently be
  # # broken. See https://github.com/bluefeet/GitLab-API-v3/issues/5
  # my $archive = $api->archive(
  #   $project->{id},
  #   \%params
  # );

  # HACK(jja) This is a workaround while the Perl GitLab API is fixed
  use LWP::Simple;

  my $get_url = CPrAN::api_url() . '/projects/' . $project->{id} . '/repository/archive?private_token=' . CPrAN::api_token() . '&sha=' . $params{sha};
  # HACK(jja) Or maybe a zip file?
  # my $get_url = 'https://gitlab.com/cpran/plugin_' . $name . '/repository/archive.zip?ref=' . $tag->{name};

  use File::Temp;
  my $tmp = File::Temp->new(
    dir => '.',
    template => 'cpranXXXXX',
    suffix => '.tar.gz',
    unlink => 0,
  );

  getstore($get_url, $tmp->filename);

  return $tmp->filename;
}

sub install {
  my ($opt, $archive) = @_;

  use Archive::Tar;
  use Path::Class qw(file dir foreign_file foreign_dir);

  $archive = file($archive);

  my $retval = 1;

  # GitLab archives have a ".git" suffix in their directory names. We need to
  # remove that suffix and extract the archive into the new plugin directory.
  # So far, the best way to do so seems to be to iterate through the contents of
  # the archive and rename each one to remove the /.git$/.
  # We then construct a new target name and extract directly into that location,
  # avoiding moving files, which is tricky.
  my $next = Archive::Tar->iter( $archive->stringify, 1, { filter => qr/.*/ } );

  # TODO(jja) Improve handling of existing target directories
  # If we are forcing the re-install of a plugin, the previously existing
  # directory needs to be removed. Maybe this could be better handled? Because
  # if we are, say, reinstalling cpran itself, the .cpran root will be removed
  # Currently, the list is being manually recreated in the main loop.

  # We make a new root in the preferences directory, and remove it if it
  # already exists
  my $root = $next->()->full_path;
  $root = dir(CPrAN::praat(), $root);
  if (-e $root->stringify && $opt->{force}) {
    print "Removing $root\n";
    use File::Path qw(remove_tree);
    remove_tree( $root->stringify, { verbose => 1, safe => 0, error => \my $e } );
    if (@{$e}) {
      foreach (@{$e}) {
        my ($file, $message) = %{$_};
          if ($file eq '') {
          warn "General error: $message\n";
        }
        else {
          warn "Problem unlinking $file: $message\n";
        }
      }
    }
  }

  while (my $f = $next->()) {
    # $path is a Path::Class object for the current item in the archive
    my $path;
    if ($f->name =~ /\/$/) {
      $path = Path::Class::Dir->new_foreign('Unix', $f->name);
    }
    else {
      $path = Path::Class::File->new_foreign('Unix', $f->name);
    }

    # @components has all the items (directories and files) in the current name
    # so we strip the /.git$/ of the first one (ie, the root)
    my @components = $path->components();
    $components[0] =~ s/\.git$//;

    # We place the preferences directory at the beginning of the new path
    unshift @components, CPrAN::praat();

    # And make a new Path::Class object pointing to it
    my $final_path;
    if ($path->is_dir()) {
      $final_path = Path::Class::Dir->new( @components );
    }
    else {
      $final_path = Path::Class::File->new( @components );
    }

    # We use that new path to extract directly into it
    my $outcome = $f->extract( $final_path );
    unless ($outcome) {
      warn "Could not extract to $final_path";
      $retval = 0;
    }
  }
  $archive->remove();
}

sub strip_prefix {
  my $args = shift;

  my $prefix_warning = 0;
  foreach (@{$args}) {
    $prefix_warning = 1 if (/^plugin_/);
    s/^plugin_//;
  }
  warn "W: Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning);

  return $args;
}

1;
