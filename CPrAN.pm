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

# HACK(jja) Ideally, this block would get run automatically, after the App has
# been iniitalised, and after the options have been parsed, but before any
# commands get executed.
{
  use Path::Class;
  use Config;
  my ($ROOT, $PRAAT);
  {
    my $user = getlogin || getpwuid($<) || "???";
    if ($Config{osname} eq 'darwin') {
      # Mac
      $PRAAT = dir('', 'Users', $user, 'Library', 'Preferences', 'Praat', 'Prefs')->stringify;
      $ROOT  = dir($PRAAT, 'plugin_cpran', '.cpran')->stringify;
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
  my $TOKEN  = 'WMe3t_ANxd3yyTLyc7WA';
  my $APIURL = 'https://gitlab.com/api/v3/';
  my $GROUP  = '133578';

  sub root      { return $ROOT   }
  sub praat     { return $PRAAT  }
  sub api_token { return $TOKEN  }
  sub api_url   { return $APIURL }
  sub api_group { return $GROUP  }

  sub set_global {
    my $self = shift;
    my $opt = $self->{app}->{global_options};

    $ROOT   = $opt->{'cpran'}     if $opt->{'cpran'};
    $PRAAT  = $opt->{'praat'}     if $opt->{'praat'};
    $TOKEN  = $opt->{'api-token'} if $opt->{'api-token'};
    $APIURL = $opt->{'api-url'}   if $opt->{'api-url'};
    $GROUP  = $opt->{'api-group'} if $opt->{'api-group'};

    croak "E: Cannot read from CPrAN root at " . CPrAN::root()
      unless (-r CPrAN::root());
    croak "E: Cannot write to CPrAN root at " . CPrAN::root()
      unless (-w CPrAN::root());
    croak "E: Cannot read from preferences directory at " . CPrAN::praat()
      unless (-r CPrAN::praat());
    croak "E: Cannot write to preferences directory at " . CPrAN::praat()
      unless (-w CPrAN::praat());
  }
}

=head1 DESCRIPTION

B<CPrAN> is the parent class for an App::Cmd application to search, install,
remove and update Praat plugins.

As a App::Cmd application, use of this module is separated over a number of
different files. The main script invokes the root module and executes it, as in
the example given in the SYNOPSIS.

B<CPrAN> commands (inhabiting the B<CPrAN::Command> namespace) can call the
methods described below to perform general B<CPrAN>-related actions.

=cut

sub global_opt_spec {
  return (
    [ "praat=s"     => "set path to Praat preferences directory" ],
    [ "cpran=s"     => "set path to CPrAN root" ],
    [ "api-token=s" => "set private token for GitLab API access" ],
    [ "api-url=s"   => "set url of GitLab API" ],
    [ "api-group=s" => "set the id for the GitLab CPrAN group" ],
    [ "quiet"       => "quietly say no to everything" ],
  );
}

=head1 METHODS

=cut

=item make_root()

Makes the B<CPrAN> root directory.

=cut

sub make_root {
  File::Path::make_path( CPrAN::root() );
}
make_root();

=over

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

  use YAML::XS;
  use File::Slurp;

  return 0 unless is_plugin($opt, $arg);

  my @contents = $arg->children();

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
  use YAML::XS;

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
    my $yaml = YAML::XS::Load( $descriptor );
    if ($yaml->{Version} ne $plugin->{version}) {
      # Requested version is not the newest on record
      # We fetch that version's descriptor from server to check for that
      # version's dependencies
      $plugin_id = CPrAN::get_plugin_id( $plugin->{name} );

      use GitLab::API::v3;
      my $api = GitLab::API::v3->new(
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

      # # HACK(jja) This should work, but the Perl GitLab API seems to currently be
      # # broken. See https://github.com/bluefeet/GitLab-API-v3/issues/5
      # $descriptor = decode_base64(
      #   $api->file($plugin_id, {
      #     file_path => 'cpran.yaml',
      #     sha => $sha,
      #   })->{content}
      # );
      use LWP::Simple;
      my $get = 'https://gitlab.com/cpran/plugin_' . $plugin->{name} . '/raw/' . $sha . '/cpran.yaml';
      $descriptor = get($get);
    }

    # We are only interested in CPrAN dependencies
    if (exists $yaml->{Depends}->{Plugins}) {
      my %raw_deps = %{$yaml->{Depends}->{Plugins}};
      my @deps = keys %raw_deps;
      my @vers = map { $raw_deps{$_} } @deps;
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
    else {
      push @dependencies, {
        name => $yaml->{Plugin},
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

=item compare_versions()

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

  use YAML::XS;

  my $app = CPrAN->new();
  my $descriptor = $app->execute_command(
    'CPrAN::Command::show',
    { quiet => 1 },
    $name
  );
  my $yaml = Load($descriptor);
  return $yaml->{Version};
}

=item get_plugin_id()

Fetches the GitLab id for the project specified by name

=cut

sub get_plugin_id {
  my $name = shift;

  use GitLab::API::v3;
  my $api = GitLab::API::v3->new(
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

App::Cmd, YAML::XS, CPrAN::Command::remove, CPrAN::Command::search,
CPrAN::Command::update>, CPrAN::Command::upgrade, CPrAN::Command::show,
CPrAN::Command::install

=head1 VERSION

0.0.2

=cut

our $VERSION = '0.0.2';

1;
