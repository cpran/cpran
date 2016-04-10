package CPrAN::Command::install;
# ABSTRACT: install new plugins

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

  unless (@{$args}) {
    if (-t) {
      $self->usage_error("Missing arguments");
    }
    else {
      exit;
    }
  }

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
      $opt->{git} = which('git');
      die "Could not find path to git binary. Is git installed?\n"
        unless defined $opt->{git};
      require Git::Repository;
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

  warn "DEBUG: Running install\n" if $opt->{debug};

  my $app = CPrAN->new();

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { CPrAN::Plugin->new( $_ ) }
  } @{$args};

  # Plugins that are already installed cannot be installed again (unless the
  # user orders a reinstall).
  # @todo will hold the plugins passed as arguments that are
  #   a) valid CPrAN plugins; and
  #   b) not already installed (unless the user asks for re-installation)
  my @todo;
  foreach my $plugin (@plugins) {

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

  my @ordered;
  if (scalar @todo) {
    my $cmd = CPrAN::Command::deps->new({});

    my %params = %{$opt};
    $params{quiet} = 1;

    @ordered = $app->execute_command($cmd, \%params, @todo);
  }

  # Scheduled plugins that are already installed are descheduled
  my @schedule = grep {
    my $plugin = $_;
    my $in_args = grep { /$plugin->{name}/ } @{$args};
    if (!$plugin->is_installed or ($opt->{reinstall} and $in_args)) { 1 }
    else { 0 }
  } @ordered;

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
                print "Contacting server...\n" unless $opt->{quiet};
                unless ($plugin->url) {
                  print "Querying repository URL...\n" unless $opt->{quiet};
                  $plugin->fetch
                }
                print "Cloning from ", $plugin->url, "\n";
                Git::Repository->run( clone => $plugin->url, $plugin->root );
              }

              my $repo = Git::Repository->new( work_tree => $plugin->root );
              my @tags = $repo->run( 'tag' );
              @tags = sort { ncmp($a, $b) } @tags;
              my $latest = pop @tags;
              print "Checking out '$latest'\n" unless $opt->{quiet};
              $repo->run( 'checkout', '--quiet', $latest );
            }
            catch {
              chomp;
              croak "Error: could not clone repository.\n$_\n";
            };
          }
          else {
            my $archive = $self->get_archive( $opt, $plugin->{name}, '' );

            print "Extracting...\n" unless $opt->{quiet};
            $self->install( $opt, $plugin, $archive );
          }

          print "Testing $plugin->{name}...\n" unless $opt->{quiet};
          $plugin->update;

          my $success;
          if (!defined $opt->{test} or $opt->{test}) {
            $success = 0;
            try {
              $success = $plugin->test;
            }
            catch {
              chomp;
              warn "There were errors while testing:\n$_\n";
            };
          }
          else {
            $success = 1;
          }

          if (defined $success and !$success) {
            if ($opt->{force}) {
              warn "Tests failed, but continuing anyway because of --force\n" unless $opt->{quiet};
            }
            else {
              unless ($opt->{quiet}) {
                warn "Tests failed. Aborting installation of $plugin->{name}.\n";
                warn "Use --force to ignore this warning\n";
              }

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
        }
      }
      catch {
        warn "There were errors during installation: $_\n";
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
    [ "test|T!"     => "request / disable tests"             ],
    [ "force|F"     => "ignore failing tests"                ],
    [ "reinstall|r" => "re-install requested plugins"        ],
    [ "git|g!"      => "request / disable git support"       ],
    [ "path=s"      => "specify path for Praat installation" ],
  );
}

=head1 METHODS

=over

=cut

=item B<get_archive()>

Downloads a plugin's tarball from the server. Returns the name of the tarball on
disk.

=cut

# TODO(jja) More testing on Windows: Non-blocking sockets?
sub get_archive {
  my ($self, $opt, $name, $version) = @_;

  use WWW::GitLab::v3;
  use Sort::Naturally;

  my $api = WWW::GitLab::v3->new(
    url   => $opt->{api_url}   // CPrAN::api_url({}),
    token => $opt->{api_token} // CPrAN::api_token({}),
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
  my ($self, $opt, $plugin, $archive) = @_;

  use Archive::Tar;
  use Path::Class qw(file dir foreign_file foreign_dir);

  $archive = file($archive);

  my $retval = 1;

  # TODO(jja) Improve handling of existing target directories
  # If we are forcing the re-install of a plugin, the previously existing
  # directory needs to be removed. Maybe this could be better handled? Because
  # if we are, say, reinstalling cpran itself, the .cpran root will be removed
  # Currently, the list is being manually recreated in the main loop.

  my $root = $plugin->{root};
  if (-e $plugin->{root} && $opt->{force}) {
    print "Removing $plugin->{root}\n" unless $opt->{quiet};
    use File::Path qw(remove_tree);
    remove_tree( $plugin->{root}, { verbose => $opt->{verbose} - 1, safe => 0, error => \my $e } );
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
    my @components = $path->components();
    $components[0] = 'plugin_' . $plugin->{name};

    # We place the preferences directory at the beginning of the new path
    unshift @components, $opt->{praat} // CPrAN::praat({});

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
      my $bin = file($praat->{path}, $praat->{bin});

      use File::Copy;
      File::Copy::move $file, $bin
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
