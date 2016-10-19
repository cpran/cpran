package CPrAN::Command::install;
# ABSTRACT: install new plugins

use uni::perl;
use Moose;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';

use MooseX::Types::Path::Class;
use CPrAN::Types;

use Try::Tiny;

has test => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 1,
  documentation => 'request / disable tests',
);

has log => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 1,
  documentation => 'request / disable log of tests',
);

has force => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 0,
  documentation => 'ignore failing tests',
);

has reinstall => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  default => 0,
  documentation => 're-install requested plugins',
);

has git => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  lazy => 1,
  documentation => 'request / disable git support',
  default => 1,
);
around git => sub {
  use File::Which;

  my $orig = shift;
  my $self = shift;

  my $return = $self->$orig(@_);

  if ($return) {
    use File::Which;
    use Class::Load ':all';

    my $enable = 1;
    unless (which 'git') {
      warn "Could not find path to git binary\n";
      $enable = 0;
    }
    unless (try_load_class 'Git::Repository') {
      warn "Could not load Git::Repository\n";
      $enable = 0;
    }

    unless ($enable) {
      warn "Git is not enabled\n";
      $return = $self->$orig($enable);
    }
  }
  return $return;
};

has path => (
  is  => 'rw',
  isa => 'Path::Class::Dir',
  traits => [qw(Getopt)],
  documentation => 'specify path for Praat installation',
  coerce => 1,
  lazy => 1,
  default => sub {
    return $_[0]->app->praat->bin->parent if defined $_[0]->app->praat->bin;

    use Path::Class;
    if ($^O =~ /darwin/) {
      warn 'in mac';
      die "Praat installation not currently supported on MacOS\n";
      # Use hdiutil and cp?
      #     hdituil mount some.dmg
      #     cp -R "/Volumes/Praat/Praat.app" "/Applications" (as sudo)
      #     hdiutil umount "/Volumes/Praat"
    }
    elsif ($^O =~ /MSWin32/) {
      warn 'in win';
      return dir 'C:', 'Program Files', 'Praat';
    }
    else {
      warn 'in else';
      return dir '', 'usr', 'bin';
    }
  },
);
# around path => sub {
#   my ($orig, $self, $path) = @_;
#
#   if (defined $path) {
#     use File::Glob ':bsd_glob';
#     $path = bsd_glob $path if defined $path;
#
#     $self->$orig($path);
#   }
#   else {
#     $self->$orig;
#   }
# };

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

=cut

=pod

Arguments to B<install> must be at least one and optionally more plugin names.
Plugin names can be appended with a specific version number to request for
versioned installation, but this is not currently implemented. When it is, names
will likely be of the form C<name-1.0.0>.

As a special case, if the only argument to B<install> is the
keyword "praat", the client will install Praat itself.

=cut

=head1 EXAMPLES

    # Install some plugins
    cpran install myplugin someplugin
    # Install a specific version of a plugin (not implemented)
    cpran install someplugin-0.5.3
    # Re-install an installed plugin
    cpran install --force
    # Do not ask for confirmation
    cpran install --force -y

    # Special case: install Praat itself
    cpran install praat

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  use DDP;
  p $args;

  if (grep { /\bpraat\b/i } @{$args}) {
    if (scalar @{$args} > 1) {
      die "Praat must be the only argument for processing\n";
    }
    else {
      return $self->install_praat;
    }
  }

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { CPrAN::Plugin->new( name => $_, cpran => $self->app ) }
  } @{$args};

  my @schedule = $self->make_schedule(@plugins);

  # Output and user query modeled after apt's
  my @installed;
  if (@schedule) {
    unless ($self->app->quiet) {
      print "The following plugins will be INSTALLED:\n";
      print '  ', join(' ', map { $_->name } @schedule), "\n";
      print "Do you want to continue?";
    }
    if ($self->app->_yesno('y')) {
      try {
        foreach my $plugin (@schedule) {

          # Now that we know what plugins to install and in what order, we
          # install them

          if ($self->git) {
            try { $self->git_install( $plugin ) }
            catch {
              chomp;
              croak "Error: could not clone repository.\n$_\n";
            };
          }

          else {
            try { $self->raw_install( $plugin ) }
            catch {
              chomp;
              croak "Error: could not install.\n$_\n";
            };
          }

          $plugin->refresh;

          push @installed, $plugin if $self->run_tests($plugin);
        }
      }
      catch {
        warn "There were errors during installation: $_\n";
        exit 1;
      };
    }
    else {
      print "Abort.\n" unless $self->app->quiet;
    }
  }
  return @installed;
}

sub run_tests {
  my ($self, $plugin) = @_;

  my $success = 1 - $self->test;
  if ($self->test) {
    print 'Testing ', $plugin->name, "...\n"
      unless $self->app->quiet;

    $success = try {
      $plugin->test(
        log => $self->log,
      );
    }
    catch {
      chomp;
      warn "There were errors while testing:\n$_\n";
    };
  }

  if ($success) {
    print $plugin->name, ' installed successfully.', "\n"
      unless $self->app->quiet;
  }
  else {
    if ($self->force) {
      warn 'Tests failed, but continuing anyway because of --force', "\n"
        unless $self->app->quiet;
    }
    else {
      unless ($self->app->quiet) {
        warn 'Tests failed. Aborting installation of ', $plugin->name, ".\n";
        warn 'Use --force to ignore this warning', "\n";
      }

      $plugin->remove( safe => 0, verbose => 0 );

      print 'Did not install ', $plugin->name, ".\n"
        unless $self->app->quiet;
      die;
    }
  }
}

sub git_install {
  my ($self, $plugin) = @_;

  my $needs_pull = 1;

  unless ($plugin->is_installed) {
    print 'Contacting server...', "\n" unless $self->app->quiet;

    unless ($plugin->url) {
      print 'Querying repository URL...', "\n" unless $self->app->quiet;
      $plugin->fetch
    }

    print 'Cloning from ', $plugin->url, "\n" unless $self->app->quiet;
    Git::Repository->run( clone => $plugin->url, $plugin->root );
    $needs_pull = 0;
  }

  my $repo = Git::Repository->new( work_tree => $plugin->root );

  if ($needs_pull) {
    print 'Pulling recent changes from upstream', "\n"
      unless $self->app->quiet;
    $repo->run( checkout => 'master' );
    $repo->run( pull => 'origin', 'master' );
  }

  my $latest = 'v' . $plugin->latest->stringify;

  print "Checking out '$latest'\n" unless $self->app->quiet;

  $repo->run( 'checkout', '--quiet', $latest );
}

sub raw_install {
  my ($self, $plugin) = @_;

  my $archive = $self->get_archive( $plugin, '' );

  print "Extracting...\n"
    unless $self->app->quiet;

  use Archive::Tar;
  use Path::Class qw( file dir foreign_file foreign_dir );

  my $retval = 1;

  # TODO(jja) Improve handling of existing target directories
  # If we are forcing the re-install of a plugin, the previously existing
  # directory needs to be removed. Maybe this could be better handled? Because
  # if we are, say, reinstalling cpran itself, the .cpran root will be removed
  # Currently, the list is being manually recreated in the main loop.

  if (-e $plugin->root and $self->force) {
    print 'Removing ', $plugin->root, ' (because you used --force)', "\n"
      unless $self->app->quiet;

    $plugin->remove( safe => 0, verbose => 0 )
      or die 'Could not remove existing plugin automatically. Aborting.', "\n";
  }

  # To make it possible to extract directly into the final location, we iterate
  # through the contents of the archive and construct a new target name
  my $next = Archive::Tar->iter( $archive->stringify, 1, { filter => qr/.*/ } );
  while (my $f = $next->()) {
    # $path is a Path::Class object for the current item in the archive
    my $path;
    if ($f->name =~ /\/$/) {
      $path = Path::Class::Dir->new_foreign('Unix', $f->name);
    }
    else {
      $path = Path::Class::File->new_foreign('Unix', $f->prefix, $f->name);
    }

    # @components has all the items (directories and files) in the current name
    my @components = $path->components;
    $components[0] = 'plugin_' . $plugin->name;

    # We place the preferences directory at the beginning of the new path
    unshift @components, $self->app->praat->pref_dir;

    # And make a new Path::Class object pointing to it
    my $final_path;
    if ($path->is_dir) {
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

  $archive->remove;
  return $retval;
}

sub make_schedule {
  my ($self, @plugins) = @_;

  # Plugins that are already installed cannot be installed again (unless the
  # user orders a reinstall).
  # @todo will hold the plugins passed as arguments that are
  #   a) valid CPrAN plugins; and
  #   b) not already installed (unless the user asks for re-installation)
  my @todo;
  foreach (@plugins) {
    if (defined $_->_remote) {
      my $install = 1 - ($_->is_installed // 0);

      unless ($install) {
        if ($self->reinstall) {
          $install = 1;
        }
        else {
          warn $_->name, ' is already installed. Use --reinstall to ignore this warning', "\n";
        }
      }

      push @todo, $_ if $install;
    }
    else {
      warn $_->name, ' is not in CPrAN database. Have you run update?', "\n"
    }
  }

  my @ordered;
  if (scalar @todo) {
    local @ARGV = qw( deps );
    my $quiet = $self->app->quiet;
    my @argv = $self->app->prepare_args;
    my ($cmd, $opt, @args) = $self->app->prepare_command(@argv);

    $self->app->quiet(1);

    @ordered = $self->app->execute_command($cmd, $opt, @todo);
    $self->app->quiet($quiet);
  }

  # Scheduled plugins that are already installed are descheduled
  return grep {
    my $name = $_->name;
    my $in_args = grep { $_->name =~ /$name/ } @plugins;
    (!$_->is_installed or ($self->reinstall and $in_args)) ? 1 : 0;
  } @ordered;
}

=head1 OPTIONS

=over

=item B<--test>, B<-T>
=item B<--notest>

These options control execution of the automated tests in each plugin. The
B<--test> option is enabled by default, and will cause these tests to be run.
This can be disabled with the B<--notest> option, which will make the client
skip tests altogether.

This is different from B<--force> in that B<--force> will still run the tests,
but will disregard those that fail.

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

=back

=cut

=head1 METHODS

=over

=cut

=item B<get_archive()>

Downloads a plugin's tarball from the server. Returns the name of the tarball on
disk.

=cut

# TODO(jja) More testing on Windows: Non-blocking sockets?
sub get_archive {
  my ($self, $plugin, $version) = @_;

  print 'Downloading archive for ', $plugin->name, "\n"
    unless $self->app->quiet;

  my $archive;
  try {
    my $project = shift @{$self->app->api->projects(
      { search => 'plugin_' . $plugin->name }
    )};

    # TODO(jja) Enable installation of specific versions
    my @tags = @{$self->app->api->tags($project->{id})};
    croak 'No tags for ', $plugin->name unless (@tags);

    my @releases;
    foreach my $tag (@tags) {
      try { $tag->{semver} = SemVer->new($tag->{name}) }
      catch { next };
      push @releases , $tag;
    };
    my $tag = pop @releases;

    $archive = $self->app->api->archive(
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
    template => $plugin->name . '-XXXXX',
    suffix => '.zip',
    unlink => 0,
  );

  my $file = Path::Class::file( $tmp->filename );
  my $fh = $file->openw;
  binmode($fh);
  $fh->print($archive);
  return $file;
}

sub install_praat {
  use Path::Class;

  my ($self) = @_;

  use DDP;

  try {
#     $self->app->praat->latest;

    if (defined $self->app->praat->bin) {
      unless ($self->reinstall) {
        warn "Praat is already installed. Use --reinstall to ignore this warning\n";
        exit 0;
      }
    }
    else {
      die 'Path does not exist: ', $self->path
        unless $self->path->resolve;

      die 'Path is not a directory: ', $self->path
        unless $self->path->is_dir;
    }

    p $self->path;

    unless (-w $self->path) {
      die 'Cannot write to ', $self->path, ".\n";
    }

    # TODO(jja) Should we check for the target path to be in PATH?

#     print "Querying server for latest version...\n" unless $opt->{quiet};
#     unless ($opt->{quiet}) {
#       print "Praat v", $praat->latest, " will be INSTALLED in $praat->{path}\n";
#       print "Do you want to continue?";
#     }
#     if (CPrAN::yesno( $opt )) {
#
#       print "Downloading package from ", $praat->{home}, $praat->{package}, "...\n"
#         unless $opt->{quiet};
#
#       my $archive = $praat->download;
#
#       use File::Temp;
#       my $package = File::Temp->new(
#         template => 'praat' . $praat->latest . '-XXXXX',
#         suffix => $praat->{ext},
#       );
#
#       my $extract = File::Temp->newdir(
#         template => 'praat-XXXXX',
#       );
#
#       print "Saving archive to ", $package->filename, "\n"
#         unless $opt->{quiet};
#
#       use Path::Class;
#       my $fh = Path::Class::file( $package->filename )->openw();
#       binmode($fh);
#       $fh->print($archive);
#
#       print "Extracting package to $praat->{path}...\n"
#         unless $opt->{quiet};
#
#       # Extract archives
#       use Archive::Extract;
#
#       my $ae = Archive::Extract->new( archive => $package->filename );
#       $ae->extract( to => $extract )
#         or die "Could not extract package: $ae->error";
#
#       use Path::Class;
#       my $file = file($ae->extract_path, $ae->files->[0]);
#
#       use File::Copy;
#       File::Copy::move $file, $praat->{path}
#         or die "Could not move file: $!\n";
#     }
  }
  catch {
    chomp;
    warn "$_\n";
    die "Could not install Praat\n";
  };
#   print "Praat succesfully installed\n"
#     unless $opt->{quiet};
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2016 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::deps|deps>,
L<CPrAN::Command::init|init>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
