# ABSTRACT: install new plugins
package CPrAN::Command::install;

use CPrAN -command;

use strict;
use warnings;

use Carp;
use Try::Tiny;
use File::Which;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

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

  if (grep { /praat/i } @{$args}) {
    if (scalar @{$args} > 1) {
      die "Praat must be the only argument for processing\n";
    }
    else {
      $self->_praat($opt);
    }
  }
  
  # Users might be tempted to input the names of plugin as "plugin_name", but
  # this is not correct. The "plugin_" prefix is not part of the plugin's name,
  # but a (clumsy) way for Praat to recognize plugin directories.
  $args = strip_prefix($args, $opt);
  
  # Git support is enabled if
  # 1. git is available
  # 2. Git::Repository is installed
  # 3. The user has not turned it off by setting --nogit
  if (!defined $opt->{git} or $opt->{git}) {
    try {
      die "Could not find path to git binary. Is git installed?\n"
        unless defined which('git');
      require Git::Repository;
      $opt->{git} = 1;
    }
    catch {
      warn "Disabling git support", ($opt->{debug}) ? ": $_" : ".\n";
      $opt->{git} = 0;
    }
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

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') {
      $_;
    }
    else {
      CPrAN::Plugin->new( $_ );
    }
  } @{$args};

  # Plugins that are already installed cannot be installed again (unless the
  # user orders a reinstall).
  # @todo will hold the plugins passed as arguments that are
  #   a) valid CPrAN plugins; and
  #   b) not already installed (unless the user asks for re-installation)
  my @todo;
  foreach my $plugin (@plugins) {
    # BUG(jja) What to do here?
    use Config;
    if ($plugin->{name} eq 'cpran' && $Config{osname} eq 'MSWin32') {
      warn "Cannot currently use CPrAN to install CPrAN in Windows\n";
    }

    if (defined $plugin->{remote}) {
      my $install = 0;

      if ($plugin->is_installed) {
        if ($opt->{reinstall}) { $install = 1 }
        else {
          warn "$plugin->{name} is already installed. Use --reinstall to ignore this warning\n";
        }
      }
      else { $install = 1 }

      push @todo, $plugin if $install;
    }
    else {
      warn "$plugin->{name} is not in CPrAN database. Have you run update?\n"
    }
  }

  # Get a source dependency tree for the plugins that are to be installed.
  # The dependencies() subroutine calls itself recursively to include the
  # dependencies of the dependencies, and so on.
  my @deps = CPrAN::dependencies( $opt, \@todo );

  # The source tree is then ordered to get a schedule of plugin installation.
  # In the resulting list, plugins with no dependencies come first, and those
  # that depend on them come later.
  my @ordered = CPrAN::order_dependencies( @deps );

  # Scheduled plugins that are already installed are descheduled
  my @schedule = grep {
    my $plugin = $_;
    my $in_args = grep { /$plugin->{name}/ } @{$args};
    if (!$plugin->is_installed or ($opt->{reinstall} and $in_args)) { 1 }
    else { 0 }
  } map { CPrAN::Plugin->new( $_->{name} ) } @ordered;

  # Output and user query modeled after apt's
  if (@schedule) {
    unless ($opt->{quiet}) {
      print "The following plugins will be INSTALLED:\n";
      print '  ', join(' ', map { $_->{name} } @schedule), "\n";
      print "Do you want to continue?";
    }
    if (CPrAN::yesno( $opt )) {
      try {
        foreach my $plugin (@schedule) {

          # Now that we know what plugins to install and in what order, we
          # install them
          
          if ($opt->{git}) {
            try {
              use Sort::Naturally;
              unless ($plugin->is_installed) {
                Git::Repository->run( clone => $plugin->url, $plugin->root );
              }
              my $repo = Git::Repository->new( work_tree => $plugin->root );
              my @tags = $repo->run( 'tag' );
              @tags = sort { ncmp($a, $b) } @tags;
              my $latest = pop @tags;
              $repo->run( 'checkout', '--quiet', $latest );
              print "Note: checking out '$latest'\n" unless $opt->{quiet};
            }
            catch { die "Error: could not clone repository.\n$_\n" };
          }
          else {
            my $archive = get_archive( $opt, $plugin->{name}, '' );

            print "Extracting...\n" unless $opt->{quiet};
            install( $opt, $archive );
          }
          
          print "Testing $plugin->{name}...\n" unless $opt->{quiet};
          $plugin->update;

          my $success = 0;
          try {
            $success = $plugin->test;
          }
          catch {
            chomp;
            warn "There were errors while testing:\n$_\n";
          };
          
          unless ($success) {
            if ($opt->{force}) {
              warn "Tests failed, but continuing anyway because of --force\n" unless $opt->{quiet};
            }
            else {
              unless ($opt->{quiet}) {
                warn "Tests failed. Aborting installation of $plugin->{name}.\n";
                warn "Use --force to ignore this warning\n";
              }

              my $app = CPrAN->new();
              my %params = %{$opt};
              $params{yes} = 1;
              $params{force} = 1;
              $params{verbose} = 0;

              my $cmd = CPrAN::Command::remove->new({});
              $app->execute_command($cmd, \%params, $plugin->{name});
              
              print "Did not install $plugin->{name}.\n" unless $opt->{quiet};
              die;
            }
          }
          else {
            print "$plugin->{name} installed successfully.\n" unless $opt->{quiet};
          }

          if ($plugin->{name} eq 'cpran') {
            # CPrAN is installing itself!
            # HACK(jja) currently, a reinstall deletes the original directory
            # which in the case of CPrAN will likely destroy the CPrAN root.
            # If that's the case, we rebuild it.
            rebuild_list($self, $opt) unless (-e CPrAN::root());
          }
        }
      }
      catch {
        warn "There were errors during installation\n";
        exit 1;
      };
    }
    else {
      print "Abort.\n" unless $opt->{quiet};
    }
  }
}

=head1 OPTIONS

=over

=item B<--yes, -y>

Assume yes for all questions.

=item B<--force>, B<-F>

Ignore the result of tests.

=item B<--reinstall>, B<-r>

By default, an installed plugin will be ignored with a warning. If this option
is enabled, all requested plugins will be marked for installation, even if
already installed.

=item B<--git>, B<-g>
=item B<--nogit>

By default, B<install> will try to use B<git> to download and manage new
plugins. For this to work, B<install> needs to be able to find the git in the
local system, and the B<Git::Repository> module for perl needs to be installed.

If both these requirements are met, git support will be enabled making it
possible to request specific versions. The resulting plugin directories will be
working git repositories as well.

If this is undesirable (and the conditions are met), this can be disabled with
the B<--nogit> option.

=item B<--debug>, B<-D>

Print debug messages.

=back

=cut

sub opt_spec {
  return (
    [ "yes|y"       => "assume yes for all questions"        ],
    [ "force|F"     => "ignore failing tests"                ],
    [ "reinstall|r" => "re-install requested plugins"        ],
    [ "git|g!"      => "request / disable git support"       ],
    [ "path=s"      => "specify path for Praat installation" ],
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

  print "Rebuilding plugin list...\n" unless ($opt->{quiet});
  my ($cmd) = $self->app->prepare_command('update');
  $self->app->execute_command( $cmd, \%params, () );
}

=item B<get_archive()>

Downloads a plugin's tarball from the server. Returns the name of the tarball on
disk.

=cut

# TODO(jja) More testing on Windows: Non-blocking sockets?
sub get_archive {
  my ($opt, $name, $version) = @_;

  use WWW::GitLab::v3;
  use Sort::Naturally;

  my $api = WWW::GitLab::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  print "Downloading archive for $name\n" unless $opt->{quiet};

  my $archive;
  try {
    my $project = shift @{$api->projects({ search => 'plugin_' . $name })};
    my $tag;
    # TODO(jja) Enable installation of specific versions
    my @tags = @{$api->tags($project->{id})};
    croak "No tags for $name" unless (@tags);
    @tags = sort { ncmp($a->{name}, $b->{name}) } @tags;
    $tag = pop @tags;

    $archive = $api->archive(
      $project->{id},
      { sha => $tag->{commit}->{id} },
    );
  }
  catch {
    chomp;
    warn "Could not contact server:\n$_\nPlease check your connection and/or try again in a few minutes.\n";
    exit 1;
  };

  # TODO(jja) Improve error checking. Does this work on Windows?
  use File::Temp;
  my $tmp = File::Temp->new(
    dir => '.',
    template => $name . '-XXXXX',
    suffix => '.zip',
    unlink => 0,
  );

  my $fh = Path::Class::file( $tmp->filename )->openw();
  binmode($fh);
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
    try {
      use Data::Dumper;
      print Dumper($next);
    } catch {};
    warn "Please contact the author at jjatria\@gmail.com\n";
    exit 1;
  }
  $root = $root->full_path;
  $root = dir(CPrAN::praat(), $root);
  if (-e $root->stringify && $opt->{force}) {
    print "Removing $root\n" unless $opt->{quiet};
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
  my ($args, $opt) = @_;

  my $prefix_warning = 0;
  foreach (@{$args}) {
    $prefix_warning = 1 if (/^plugin_/);
    s/^plugin_//;
  };
  warn "Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning and !$opt->{quiet});

  return $args;
}

sub _praat {
  use CPrAN::Praat;
  use Path::Class;
  
  my ($self, $opt) = @_;
  
  try {
    my $praat = CPrAN::Praat->new($opt);
    $praat->latest;
    
    if (defined $praat->{path}) {
      unless (defined $opt->{reinstall}) {
        warn "Praat is already installed. Use --reinstall to ignore this warning\n";
        exit 0;
      }
    }
    elsif (defined $opt->{path}) {
      die "Path does not exist"
        unless -e $opt->{path};
        
      die "Path is not a directory"
        unless -d $opt->{path};
      
      $praat->{path} = $opt->{path};
    }
    else {
      # TODO(jja) Default paths. Where is best?
      if ($^O =~ /darwin/) {
        warn "** MacOS is a jungle! Completely uncharted territory! **\n";
        # Use hdiutil and cp?
        #     hdituil mount some.dmg
        #     cp -R "/Volumes/Praat/Praat.app" "/Applications" (as sudo)
        #     hdiutil umount "/Volumes/Praat"
      }
      elsif ($^O =~ /MSWin32/) {
        # Untested
        $praat->{path} = dir('C:', 'Program Files', 'Praat')->stringify;
        warn "Got $praat->{path}. Is this correct?\n";
      }
      else {
        $praat->{path} = dir('', 'usr', 'bin')->stringify;
      }
    }
    unless (-w $praat->{path}) {
      die "Cannot write to $praat->{path}.\n";
    }
    
    # TODO(jja) Should we check for the target path to be in PATH?
    
    print "Querying server for latest version...\n" unless $opt->{quiet};
    unless ($opt->{quiet}) {
      print "Praat v", $praat->latest, " will be INSTALLED in $praat->{path}\n";
      print "Do you want to continue?";
    }
    if (CPrAN::yesno( $opt )) {
      
      print "Downloading package from ", $praat->{home}, $praat->{package}, "...\n"
        if defined $opt->{quiet} && $opt->{quiet} == 1;
        
      my $archive = $praat->download;
        
      use File::Temp;
      my $package = File::Temp->new(
        template => 'praat' . $praat->latest . '-XXXXX',
        suffix => $praat->{ext},
      );

      my $extract = File::Temp->newdir(
        template => 'praat-XXXXX',
      );

      print "Saving archive to ", $package->filename, "\n" if $opt->{quiet} == 1;
      use Path::Class;
      my $fh = Path::Class::file( $package->filename )->openw();
      binmode($fh);
      $fh->print($archive);

      print "Extracting package to $praat->{path}...\n" if $opt->{quiet} == 1;

      # Extract archives
      use Archive::Extract;
      
      my $ae = Archive::Extract->new( archive => $package->filename );
      $ae->extract( to => $extract )
        or die "Could not extract package: $ae->error";
      
      use Path::Class;
      my $file = file($ae->extract_path, $ae->files->[0]);
      File::Copy::move $file, file($praat->{path}, $praat->{bin})
        or die "Could not move file: $!\n";
    }
  }
  catch {
    die "Could not install Praat", ($opt->{debug}) ? ": $_" : ".\n";
  };
  print "Praat succesfully installed\n" unless $opt->{quiet};
  exit 0;
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
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

1;
