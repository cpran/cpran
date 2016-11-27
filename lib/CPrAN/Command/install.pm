package CPrAN::Command::install;
# ABSTRACT: install new plugins

use Moose;
use Log::Any qw( $log );

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';
with 'CPrAN::Role::Processes::Praat';
with 'CPrAN::Role::Reads::STDIN';

require Carp;
use Types::Path::Tiny qw( Dir );

# Until the library does this by default
MooseX::Getopt::OptionTypeMap->add_option_type_to_map( Dir, '=s', );

has [qw(
  test log force reinstall git barren
)] => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
);

has '+test' => (
  lazy => 1,
  default => 1,
  documentation => 'request / disable tests',
);

has '+log' => (
  lazy => 1,
  default => 1,
  documentation => 'request / disable log of tests',
);

has '+force' => (
  lazy => 1,
  default => 0,
  documentation => 'ignore failing tests',
);

has '+reinstall' => (
  lazy => 1,
  default => 0,
  documentation => 're-install requested plugins',
);

has '+barren' => (
  documentation => 'request a barren Praat binary',
  lazy => 1,
  default => 0,
);

has '+git' => (
  lazy => 1,
  documentation => 'request / disable git support',
  default => 1,
);
around git => sub {
  my $orig = shift;
  my $self = shift;

  my $return = $self->$orig(@_);

  if ($return) {
    require File::Which;
    require Class::Load;

    my $enable = 1;
    unless (File::Which::which('git')) {
      warn "Could not find path to git binary\n";
      $enable = 0;
    }
    unless (Class::Load::try_load_class 'Git::Repository') {
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
  isa => Dir,
  traits => [qw(Getopt)],
  documentation => 'specify path for Praat installation',
  coerce => 1,
  lazy => 1,
  default => sub {
    return $_[0]->app->praat->bin->parent if $_[0]->app->praat->bin->exists;

    require Path::Tiny;
    if ($^O =~ /darwin/) {
      $_[0]->app->logger->debug('Installing Praat binary to default Mac path');
      die "Praat installation not currently supported on MacOS\n";
      # Use hdiutil and cp?
      #     hdituil mount some.dmg
      #     cp -R "/Volumes/Praat/Praat.app" "/Applications" (as sudo)
      #     hdiutil umount "/Volumes/Praat"
    }
    elsif ($^O =~ /MSWin32/) {
      $_[0]->app->logger->debug('Installing Praat binary to default Windows path');
      return Path::Tiny::path('C:', 'Program Files', 'Praat');
    }
    else {
      $_[0]->app->logger->debug('Installing Praat binary to default path');
      return Path::Tiny::path('/', 'usr', 'bin');
    }
  },
);

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

  $log->debug('Executing install');

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { $self->app->new_plugin( $_ ) }
  } @{$args};

  my @schedule = $self->make_schedule(@plugins);

  # Output and user query modeled after apt's
  my @installed;
  if (@schedule) {
    unless ($self->app->quiet) {
      my $n = scalar @schedule;

      use Lingua::EN::Inflexion;

      print inflect("<#d:$n>The following <N:plugin> will be INSTALLED:"), "\n";
      print '  ', join(' ', map { $_->name } @schedule), "\n";
      print 'Do you want to continue?';
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
              die "Error: could not clone repository.\n$_\n";
            };
          }

          else {
            try { $self->raw_install( $plugin ) }
            catch {
              chomp;
              die "Error: could not install.\n$_\n";
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
      $plugin->test( log => $self->log );
    }
    catch {
      chomp;
      warn "There were errors while testing:\n$_\n";
    };
  }

  if ($success // 1) {
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
  my $repo;

  if ($plugin->is_installed) {
    $repo = Git::Repository->new( work_tree => $plugin->root );

    my %remotes = map { my ($a, $b) = split /\s/, $_; $a => $b }
      $repo->run( remote => '-v' );

    if (defined $remotes{cpran}) {
      die 'Cannot reinstall ', $plugin->name, ' using git: \'cpran\' remote is not HTTP'
        unless $remotes{cpran} =~ /^http/;
    }
    else {
      $plugin->fetch;
      $repo->run( remote => qw( add cpran ), $plugin->url );
    }
  }
  else {
    print 'Contacting server...', "\n" unless $self->app->quiet;

    unless ($plugin->url) {
      print 'Querying repository URL...', "\n" unless $self->app->quiet;
      $plugin->fetch
    }

    print 'Cloning from ', $plugin->url, "\n" unless $self->app->quiet;
    Git::Repository->run( clone => $plugin->url, $plugin->root );

    $repo = Git::Repository->new( work_tree => $plugin->root );
    $repo->run( remote => qw( rename origin cpran ) );
    $needs_pull = 0;
  }

  if ($needs_pull) {
    print 'Pulling recent changes from upstream', "\n"
      unless $self->app->quiet;

    $repo->run( checkout => 'master' );
    $repo->run( pull => qw( cpran master ) );
  }

  my $wanted = 'v' . $plugin->requested->stringify;

  print "Checking out '$wanted'\n" unless $self->app->quiet;

  $repo->run( checkout => '--quiet', $wanted );
}

sub raw_install {
  my ($self, $plugin) = @_;

  my $archive = $self->get_archive( $plugin );

  print "Extracting...\n"
    unless $self->app->quiet;

  require Archive::Tar;

  my $retval = 1;
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
    # $path is a Path::Tiny object for the current item in the archive
    my $path;

    require Path::Tiny;
    if ($f->name =~ /\/$/) {
      $path = Path::Tiny::path($f->name);
    }
    else {
      $path = Path::Tiny::path($f->prefix, $f->name);
    }

    # @components has all the items (directories and files) in the current name
    my @components = split qr{/}, $path->stringify;
    $components[0] = 'plugin_' . $plugin->name;

    # We place the preferences directory at the beginning of the new path
    unshift @components, $self->app->praat->pref_dir;

    # And make a new Path::Tiny object pointing to it
    my $final_path = Path::Tiny::path( @components );

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
    @ordered = $self->app->run_command( deps => @todo, { quiet => 1 } );
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

  use Try::Tiny;

  my $archive = try {
    my $project = shift @{$self->app->api->projects(
      { search => 'plugin_' . $plugin->name }
    )};

    # TODO(jja) Enable installation of specific versions
    my @tags = @{$self->app->api->tags($project->{id})};
    Carp::croak 'No tags for ', $plugin->name unless (@tags);

    my @releases;
    foreach my $tag (@tags) {
      require Praat::Version;
      try { $tag->{semver} = Praat::Version->new($tag->{name}) }
      catch { next };
      push @releases , $tag;
    };
    @releases = sort { $a->{semver} <=> $b->{semver} } @releases;

    my $tag = pop @releases;

    $self->app->api->archive(
      $project->{id},
      { sha => $tag->{commit}->{id} },
    );
  }
  catch {
    chomp;
    warn "Could not contact server:\n$_\nPlease check your connection and/or try again in a few minutes.\n";
    exit 1;
  };

  require Path::Tiny;
  # TODO(jja) Improve error checking. Does this work on Windows?
  my $file = Path::Tiny->tempfile(
    dir => '.',
    template => $plugin->name . '-XXXXX',
    suffix => '.zip',
    unlink => 0,
  );

  my $fh = $file->openw_raw;
  $fh->print($archive);
  return $file;
}

sub process_praat {
  my ($self, $requested) = @_;
  my $praat = $self->app->praat;
  $praat->requested($requested) if $requested;
  $praat->_barren($self->barren) if $self->barren;

  use Try::Tiny;
  try {
    if ($praat->bin->stringify) {
      unless ($self->reinstall) {
        warn "Praat is already installed. Use --reinstall to ignore this warning\n";
        exit 0;
      }
    }
    else {
      die 'Path does not exist: ', $self->path
        unless $self->path->exists;

      die 'Path is not a directory: ', $self->path
        unless $self->path->is_dir;
    }

    unless (-w $self->path) {
      die 'Cannot write to "', $self->path, '". Use --path to specify a different target', "\n";
    }

    # TODO(jja) Should we check for the target path to be in PATH?

    unless ($self->app->quiet) {
      print 'Querying server for latest version...', "\n";
      print 'Praat v', $praat->latest, ' will be INSTALLED in ', $self->path, "\n";
      print 'Do you want to continue?';
    }
    if ($self->app->_yesno('y')) {
      print 'Downloading package from ', $praat->_package_url, "...\n"
        unless $self->app->quiet;

      my $archive = $praat->download;

      require Path::Tiny;

      my $package = Path::Tiny->tempfile(
        template => 'praat' . $praat->latest . '-XXXXX',
        suffix => $praat->_ext,
      );

      my $extract = Path::Tiny->tempdir(
        template => 'praat-XXXXX',
      );

      print "Saving archive to ", $package->basename, "\n"
        unless $self->app->quiet;

      my $fh = $package->openw_raw;
      $fh->print($archive);

      print 'Extracting package to ', $self->path, "...\n"
        unless $self->app->quiet;

      # Extract archives
      require Archive::Extract;

      my $ae = Archive::Extract->new( archive => $package->canonpath );
      $ae->extract( to => $extract )
        or die "Could not extract package: $ae->error";

      my $file = Path::Tiny::path( $ae->extract_path, $ae->files->[0] );

      $file->copy( $self->path->child('praat') ) and $file->remove
        or die "Could not move file: $!\n";
    }
  }
  catch {
    chomp;
    warn "$_\n";
    die "Could not install Praat\n";
  };

  print "Praat succesfully installed\n"
    unless $self->app->quiet;
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

__PACKAGE__->meta->make_immutable;
no Moose;

1;
