# ABSTRACT: install new plugins
package CPrAN::Command::install;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

=encoding utf8

=head1 NAME

B<install> - Install new CPrAN plugins

=head1 SYNOPSIS

cpran install [options] [arguments]

=head1 DESCRIPTION

Equivalent in spirit to apt-get install, this command checks the dependencies
of the specified plugins, schedules the installation of plugins needed or
requested, downloads them from the server, tests them, and finally installs
them.

Currently, no testing is done, and installation works sometimes in Windows.

=cut

sub description {
  return "Install new CPrAN plugins";
}

=pod

Arguments to B<install> must be at least one and optionally more plugin names.
Plugin names can be appended with a specific version number to request for
versioned installation, but this is not currently implemented. When it is, names
will likely be of the form C<name-1.0.0>.

=cut

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
}

=head1 EXAMPLES

    # Install some plugins
    cpran install myplugin someplugin
    # Install a specific version of a plugin (not implemented)
    cpran install someplugin-0.5.3
    # Re-install an installed plugin
    cpran install --force
    # Do not ask for confirmation
    cpran install --force -y

=cut

# TODO(jja) Break execute into smaller subroutines.
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
      warn "Cannot currently use CPrAN to install CPrAN in Windows\n";
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
  # See https://gitlab.com/cpran/plugin_cpran/issues/3
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
        my $archive = get_archive( $opt, $_->{name}, '' );

        print "Extracting... " unless ($opt->{quiet});
        install( $opt, $archive );

        print "done\n" unless ($opt->{quiet});

        if ($_->{name} eq 'cpran') {
          # CPrAN is installing itself!
          # HACK(jja) currently, a reinstall deletes the original directory
          # which in the case of CPrAN will likely destroy the CPrAN root.
          # If that's the case, we rebuild it.
          rebuild_list($self, $opt) unless (-e CPrAN::root());
        }
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
    }
  }
}

=head1 OPTIONS

=over

=item B<--yes, -y>

Assumes yes for all questions.

=item B<--force>

Tries to work around problems. For example, if an installed plugin is requested
for installation, it re-installs it instead of refusing. When tests are enabled,
B<--force> should allow for installation regardless of test outcomes.

=item B<--debug>

Print debug messages.

=back

=cut

sub opt_spec {
  return (
    [ "yes|y"   => "do not ask for confirmation" ],
    [ "force" => "print debugging messages" ],
  );
}

=head1 METHODS

=over

=cut

=item B<rebuild_list()>

Rebuild the plugin list. This method is just a wrapper around B<update>, used
for re-creating the list when CPrAN is used to install itself.

=cut

sub rebuild_list {
  my ($self, $opt) = @_;

  CPrAN::make_root();

  # We copy the current options, in case custom paths have been passed
  my %params = %{$opt};
  $params{verbose} = 0;

  print "Rebuilding plugin list... " unless ($opt->{quiet});
  my ($cmd) = $self->app->prepare_command('update');
  $self->app->execute_command( $cmd, \%params, () );
  print "done\n" unless ($opt->{quiet});
}

=item B<get_archive()>

Downloads a plugin's tarball from the server. Returns the name of the tarball on
disk.

=cut

# TODO(jja) More testing on Windows: Non-blocking sockets?
sub get_archive {
  my ($opt, $name, $version) = @_;

  use WWW::GitLab::v3;

  my $api = WWW::GitLab::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  print "Downloading archive for $name " unless ($opt->{quiet});

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
    $tag = shift @{$tags};
  }

  my %params = ( sha => $tag->{commit}->{id} );
  my $archive = $api->archive(
    $project->{id},
    \%params
  );

  # TODO(jja) Improve error checking. Does this work on Windows?
  use File::Temp;
  my $tmp = File::Temp->new(
    dir => '.',
    template => $name . '-XXXXX',
    suffix => '.zip',
    unlink => 0,
  );

  my $fh = Path::Class::file( $tmp->filename )->openw();
  $fh->print($archive);
  return $tmp->filename;
}

=item B<install()>

Extract the downloaded tarball.

=cut

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
  my $root = $next->();
  unless ($root) {
    warn "Something went wrong\n";
    print Dumper($next);
    exit;
  }
  $root = $root->full_path;
  $root = dir(CPrAN::praat(), $root);
  if (-e $root->stringify && $opt->{force}) {
    print "Removing $root\n";
    use File::Path qw(remove_tree);
    remove_tree( $root->stringify, { verbose => $opt->{verbose} - 1, safe => 0, error => \my $e } );
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
  return $retval;
}

=item B<strip_prefix()>

Praat uses a rather clumsy method to identify plugins: it looks for directories
in the preferences directory whose name begins with the strnig "plugin_".
However, this is conceptually I<not> part of the name.

Since user's might be tempted to include it in the name of the plugin, we remove
it, and issue a warning to slowly teach them to Do The Right Thing™

The method takes the reference to a list of plugin names, and returns a
reference to the same list, without the prefix.

=cut

sub strip_prefix {
  my $args = shift;

  my $prefix_warning = 0;
  foreach (@{$args}) {
    $prefix_warning = 1 if (/^plugin_/);
    s/^plugin_//;
  };
  warn "W: Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning);

  return $args;
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,
L<CPrAN::Command::remove|remove>

=cut

1;
