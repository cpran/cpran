package CPrAN;

use App::Cmd::Setup -app;
use File::Path;
use Data::Dumper;
use Carp;

=encoding utf8

=head1 NAME

B<CPrAN> - A package manager for Praat

=head1 SYNOPSIS

    use CPrAN;
    CPrAN->run;

=cut

# ROOT and PRAAT hold the paths to the preferences directory and the CPrAN root
# respectively. Being in this enclosure, acces to them is limited to the
# accessors below.
# NOTE(jja) Should this be made into a class, and this into proper attributes?
{
  use Path::Class;
  use Config;
  my ($ROOT, $PRAAT);
  {
    my $user = getlogin || getpwuid($<) || "???";
    if ($Config{osname} eq 'darwin') {
      # Mac
      $PRAAT = dir('', 'Users', $user, 'Library', 'Preferences', 'Praat', 'Prefs')->stringify;
    }
    elsif ($Config{osname} eq 'MSWin32') {
      # Windows
      $PRAAT = dir('C:\\', 'Documents and Settings', $user, 'Praat')->stringify;
    }
    elsif ($Config{osname} eq 'cygwin') {
      # cygwin
      warn "Cygwin not tested. Treating as if GNU/Linux\n";
      $PRAAT = dir('', 'home', $user, '.praat-dir')->stringify;
    }
    else {
      # GNU/Linux
      $PRAAT = dir('', 'home', $user, '.praat-dir')->stringify;
    }
    $ROOT = dir($PRAAT, 'plugin_cpran', '.cpran')->stringify;
  }

  sub root  { return $ROOT   }
  sub praat { return $PRAAT  }

  sub set_root  { $ROOT  = shift }
  sub set_praat { $PRAAT = shift }
}

# TOKEN, APIURL and GROUP are API dependant values. Being in this enclosure,
# access is limited to the accessors below.
{
  my $TOKEN  = 'Myz-wxxGLnV_syejdkWx';
  my $APIURL = 'https://gitlab.com/api/v3/';
  my $GROUP  = '133578';

  sub api_token { return $TOKEN  }
  sub api_url   { return $APIURL }
  sub api_group { return $GROUP  }

  sub set_api_token { $TOKEN  = shift }
  sub set_api_url   { $APIURL = shift }
  sub set_api_group { $GROUP  = shift }
}

# By redefining this subroutine, we lightly modify the behaviour of the App::Cmd
# app. In this case, we process the global options, and pass _some_ of those to
# the invoked commands together with their local options.
sub execute_command {
  my ($self, $cmd, $opt, @args) = @_;

  set_globals($self, $cmd, $opt, @args);
  make_root();

  # A verbose level of 1 prints default messages to STDOUT. --quiet
  # sets verbosity to 0, amotting all output. Higher values of verbose
  # will increase verbosity.
  if (defined $self->global_options->{quiet}) {
    $opt->{verbose} = 0;
  }
  else {
    $opt->{verbose} = ++$self->global_options->{verbose};
  }

  $opt->{debug} = $self->global_options->{debug};

  $cmd->validate_args($opt, \@args);
  $cmd->execute($opt, \@args);
}

=head1 DESCRIPTION

B<CPrAN> is the parent class for an App::Cmd application to search, install,
remove and update Praat plugins.

As a App::Cmd application, use of this module is separated over a number of
different files. The main script invokes the root module and executes it, as in
the example given in the SYNOPSIS.

B<CPrAN> commands (inhabiting the B<CPrAN::Command> namespace) can call the
methods described below to perform general B<CPrAN>-related actions.

=head1 OPTIONS

=over

=item B<--praat>=PATH

The path to use as the preferences directory for Praat. See the FILES section
for information on the platform-dependant default values used.

=item B<--cpran>=PATH

The path to use as the CPrAN root directory. See the FILES section
for information on the platform-dependant default values used.

=item B<--api-token>=TOKEN

=item B<--api-group>=GROUP_ID

=item B<--api-url>=URL

These options set the credentials to talk to the GitLab API to obtain the
plugin archives and descriptors. As such, it is implementation-dependant, and is
currently tied to GitLab.

=item B<--verbose>, B<--v>

Increase the verbosity of the output. This option can be called multiple times
to make the program even more talkative.

=item B<--quiet>, B<--q>

Opposed to B<--verbose>, this option I<suppresses> all output. If both options
are set simultaneously, this one takes precedence.

=item B<--debug>, B<--D>

Enables the output of debug information. Like B<--verbose>, this option can be
used multiple times to increase the number of debug messages that are printed.

=cut

sub global_opt_spec {
  return (
    [ "praat=s"     => "set path to Praat preferences directory" ],
    [ "cpran=s"     => "set path to CPrAN root" ],
    [ "api-token=s" => "set private token for GitLab API access" ],
    [ "api-url=s"   => "set url of GitLab API" ],
    [ "api-group=s" => "set the id for the GitLab CPrAN group" ],
    [ "verbose|v+"  => "increase verbosity" ],
    [ "quiet|q"     => "quietly say no to everything" ],
    [ "debug|D+"    => "print debug messages" ],
    [ "outfile|o=s" => "redirect output to file" ],
  );
}

=back

=head1 METHODS

=over

=cut

=item set_globals()

Processes global variables to change shared variables. This probably should be
re-worked to more closely match the way App::Cmd expects to be used.

=cut

sub set_globals {
  my ($self, $cmd, $opt, @args) = @_;
  my $gopt = $self->global_options;

  set_praat($gopt->{praat}) if (defined $gopt->{praat});
  set_root($gopt->{cpran}) if (defined $gopt->{cpran});

  set_api_token($gopt->{'api-token'}) if (defined $gopt->{'api-token'});
  set_api_group($gopt->{'api-group'}) if (defined $gopt->{'api-group'});
  set_api_url($gopt->{'api-url'}) if (defined $gopt->{'api-url'});

  check_permissions($self, $cmd, $opt, @args) unless ($cmd =~ /(version|help)/);
}

=item check_permissions()

CPrAN needs read and write access to the path set as root, and to Praat's
# preferences directory. This subroutine makes sure this is the case, or croaks.

=cut

# TODO(jja) If this is a fresh install, CPrAN root will not exist, so will not 
# readable/writable. What needs to be checked is whether the root could be
# created.
sub check_permissions {
  my ($self, $cmd, $opt, @args) = @_;

  if (-e CPrAN::root()) {
    croak "E: Cannot read from CPrAN root at " . CPrAN::root()
      unless (-r CPrAN::root());
    croak "E: Cannot write to CPrAN root at " . CPrAN::root()
      unless (-w CPrAN::root());
  }
  else {
    warn "W: CPrAN root not found.\nW: If this is a fresh install, try running cpran update\n" unless ($cmd =~ /update/);
  }
  croak "E: Cannot read from preferences directory at " . CPrAN::praat()
    unless (-r CPrAN::praat());
  croak "E: Cannot write to preferences directory at " . CPrAN::praat()
    unless (-w CPrAN::praat());
}

=item make_root()

Makes the B<CPrAN> root directory.

=cut

sub make_root {
  File::Path::make_path( CPrAN::root() ) unless (-e CPrAN::root());
}

=item is_cpran()

Takes an object of type Path::Class and checks whether it is a B<CPrAN> Praat
plugin. See I<is_plugin()> for the criteria they need to fulfill ot be a plugin.

In order to be considered a B<CPrAN> plugin, a valid plugin must additionally
have a I<plugin descriptor> written in valid YAML.

This method does not currently make any sanity checks on the structure of the
plugin descriptor (which should follow the example bundled in I<example.yaml>),
but future versions might.

=cut

sub is_cpran {
  my ($opt, $arg) = @_;

  croak "Argument is not a Path::Class object"
    unless (ref($arg) =~ /^Path::Class/);

  my $name = $arg->stringify;
  $name =~ s%.*plugin_(.*)/?$%$1%;
  return 1 if grep(/^$name$/, CPrAN::known());

  use YAML::XS;
  use File::Slurp;

  return 0 unless is_plugin($opt, $arg);

  eval { my @contents = $arg->children() };
  croak "Cannot read from directory" if $@;

  my $descriptor = 0;
  map {
    $descriptor = 1 if $_->basename eq 'cpran.yaml';
  } @contents;
  unless ($descriptor) {
    print STDERR "D: ", $arg->basename, " does not have a descriptor\n"
      if $opt->{debug};
    return 0;
  }

  return 1;
}

=item is_plugin()

Takes an object of type Path::Class and checks whether it is a Praat plugin. All
directories that reside under Praat's preferences directory, and whose name
begins with the I<plugin_> identifier are considered valid plugins.

    use Path::Class;
    is_plugin( file('foo', 'bar') );           # False
    is_plugin( dir('foo', 'bar') );            # False
    is_plugin( dir($prefdir, 'bar') );         # False
    is_plugin( dir($prefdir, 'plugin_bar') );  # True

=cut

sub is_plugin {
  my ($opt, $arg) = @_;

  croak "Argument is not a Path::Class object"
    unless (ref($arg) =~ /^Path::Class/);

  unless ($arg->is_dir) {
    print STDERR "D: ", $arg->basename, " is not a directory\n"
      if $opt->{debug};
    return 0;
  }

  unless ($arg->parent eq CPrAN::praat() ) {
    print STDERR "D: ", $arg->basename, " is not in " . CPrAN::praat() . "\n"
      if $opt->{debug};
    return 0;
  }

  unless ($arg->basename =~ /^plugin_/) {
    print STDERR "D: ", $arg->basename, " is not properly named\n"
      if $opt->{debug};
    return 0;
  }

  return 1;
}

=item installed()

Returns a list of all installed Praat plugins. See I<is_plugin()> for the
criteria they need to fulfill.

    my @installed = installed();
    print "$_\n" foreach (@installed);

=cut

sub installed {
  use Path::Class;

  my @all_files = dir( CPrAN::praat() )->children;

  my @installed;
  foreach (@all_files) {
    my $name = $_->basename;
    $name =~ s/^plugin_//;
    if (CPrAN::is_plugin( $opt, $_ )) {
      push @installed, $name;
    }
  }

  return @installed;
}

=item known()

Returns a list of all plugins known by B<CPrAN>. In practice, this is the list
of plugins whose descriptors have been saved by C<cpran update>

    my @known = known();
    print "$_\n" foreach (@known);

=cut

sub known {
  use Path::Class;

  return map {
    $_->basename;
  } dir( CPrAN::root() )->children;
}

=item dependencies()

Query the desired plugins for dependencies.

Takes either the name of a single plugin, or a list of names, and returns
an array of hashes properly formatted for processing with order_dependencies()

=cut

sub dependencies {
  my ($opt, $args) = @_;

  use Path::Class;
  use File::Slurp;

  my @dependencies;

  # If the argument is a scalar, convert it to a list with it as its single item
  $args = [ { name => $args, version => '' } ] if (!ref $args);

  foreach my $plugin (@{$args}) {

    if ($plugin->{version} eq '') {
      $plugin->{version} = CPrAN::get_latest_version( $plugin->{name} );
    }

    my $app = CPrAN->new();
    my $descriptor = $app->execute_command(
      'CPrAN::Command::show',
      { quiet => 1 },
      $plugin->{name}
    );
    if ($descriptor->{version} ne $plugin->{version}) {
      # Requested version is not the newest on record
      # We fetch that version's descriptor from server to check for that
      # version's dependencies
      $plugin_id = CPrAN::get_plugin_id( $plugin->{name} );

      use GitLab::API::Tiny::v3;
      my $api = GitLab::API::Tiny::v3->new(
        url   => CPrAN::api_url(),
        token => CPrAN::api_token(),
      );
      my $tags = $api->tags($plugin_id);
      my $sha;
      foreach (@{$tags}) {
        if ($_->{name} eq "v$plugin->{version}") {
          $sha = $_->{commit}->{id};
        }
      }
      croak "Could not find $plugin->{name} (v$plugin->{version})" unless $sha;

      $descriptor = decode_base64(
        $api->file($plugin_id, {
          file_path => 'cpran.yaml',
          sha => $sha,
        })->{content}
      );
      use YAML::XS;
      $descriptor = Load($descriptor);
    }

    # We are only interested in CPrAN dependencies
    if (exists $descriptor->{depends}->{plugins}) {
      my %raw_deps = %{$descriptor->{depends}->{plugins}};
      my @deps = keys %raw_deps;
      my @vers = map { $raw_deps{$_} } @deps;
      my %deps = (
        name     => $descriptor->{plugin},
        requires => \@deps,
        version  => \@vers,
      );

      push @dependencies, \%deps;
      # Recursively query dependencies for all dependencies
      foreach (@{$deps{requires}}) {
        @dependencies = (@dependencies, dependencies($opt, $_));
      }
    }
    else {
      push @dependencies, {
        name => $descriptor->{plugin},
        requires => [],
        version => [],
      };
    }
  }
  return @dependencies;
}

=item order_dependencies()

Order required packages, so that those that are depended upon come up first than
those that depend on them.

The argument is an array of hashes, each of which needs a "name" key that
identifies the item, and a "requires" holding the reference to an array with
the names of the items that are required. See dependencies() for a method to
generate such an array.

Closely modeled after http://stackoverflow.com/a/12166653/807650

=cut

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

=item yesno()

Gets either a I<yes> or a I<no> answer from STDIN. As arguments, it first
receives a reference to the options hash, followed by the default answer (ie,
the answer that will be entered if the user simply presses enter).

    my $opt = ( yes => 1 );            # Will automatically say 'yes'
    print "Yes or no? [y/N] ";
    if (yesno($opt, 'n')) { print "You said yes\n" }
    else { print "You said no\n" }

By default, responses matching /^y(es)?$/i are considered to be I<yes>
responses.

=cut

sub yesno {
  my ($opt, $default) = @_;

  if ($opt->{quiet} && !$opt->{yes}) {
    return 0;
  }

  if ($opt->{yes}) {
    print "yes\n" unless ($opt->{quiet});
    return 1;
  }

  my $input;
  $input = <STDIN>;
  chomp $input;
  $input = $default if ($input eq "");
  ($input =~ /^y(es)?$/i) ? return 1 : return 0;
}

=item compare_version()

Compares two semantic version numbers that match /^\d+\.\d+\.\d$/. Returns 1 if
the first is larger (=newer), -1 if the second is larger, and 0 if they are the
same;

=cut

sub compare_version {
  my ($a, $b) = @_;

  croak "Incorrectly formatted version number: $a, $b"
    if ($a !~ /^\d+\.\d+\.\d+$/ || $b !~ /^\d+\.\d+\.\d+$/);

  return 0 if ($a eq $b);

  my @a = split /\./, $a;
  my @b = split /\./, $b;

  if    ($a[0] > $b[0]) { return  1 }
  elsif ($a[0] < $b[0]) { return -1 }
  elsif ($a[1] > $b[1]) { return  1 }
  elsif ($a[1] < $b[1]) { return -1 }
  elsif ($a[2] > $b[2]) { return  1 }
  elsif ($a[2] < $b[2]) { return -1 }
  else { croak "What happened?" }
}

=item get_latest_version()

Gets the latest known version for a plugin specified by name.

=cut

sub get_latest_version {
  my $name = shift;

  my $app = CPrAN->new();
  my $descriptor = $app->execute_command(
    'CPrAN::Command::show',
    { quiet => 1 },
    $name
  );
  return $descriptor->{version};
}

=item get_plugin_id()

Fetches the GitLab id for the project specified by name

=cut

sub get_plugin_id {
  my $name = shift;

  use GitLab::API::Tiny::v3;
  my $api = GitLab::API::Tiny::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  my $project = $api->projects( { search => 'plugin_' . $name } );

  foreach (@{$project}) {
    return $_->{id} if ($_->{name} eq 'plugin_' . $name);
  }
  return '';
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,

=cut

our $VERSION = '0.1.3';

1;
