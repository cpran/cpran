package CPrAN;

use App::Cmd::Setup -app;
use File::Path;
use Carp;

=encoding utf8

=head1 NAME

B<CPrAN> - A package manager for Praat

=head1 SYNOPSIS

    use CPrAN;
    CPrAN->run;

=cut

{
  use Path::Class;
  use Config;
  my $user = getlogin || getpwuid($<) || "???";
  my ($ROOT, $PRAAT);
  if ($Config{osname} eq 'darwin') {
    # Mac
#     print "$user\@mac\n";
    $PRAAT  = dir('', 'Users', $user, 'Library', 'Preferences', 'Praat', 'Prefs')->stringify;
    $ROOT   = dir($PRAAT, 'plugin_cpran', '.cpran')->stringify;
  }
  elsif ($Config{osname} eq 'MSWin32') {
    # Windows
#     print "$user\@windows\n";
    $PRAAT = dir('C:', 'Documents and Settings', $user, 'Praat')->stringify;
  }
  else {
    # Linux
#     print "$user\@linux\n";
    $PRAAT = dir('', 'home', $user, '.praat-dir')->stringify;
  }
  $ROOT = dir($PRAAT, 'plugin_cpran', '.cpran')->stringify;

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
  }
}

=head1 DESCRIPTION

B<CPrAN> is the parent class for an App::Cmd application to search, install, remove
and update Praat plugins.

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
  );
}

File::Path::make_path( CPrAN::root() );

=head1 METHODS

=cut

=over

=item is_cpran()

Takes an object of type Path::Class and checks whether it is a B<CPrAN> Praat
plugin. See I<is_plugin()> for the criteria they need to fulfill ot be a plugin.

In order to be considered a B<CPrAN> plugin, a valid plugin must additionally have
a I<plugin descriptor> written in valid YAML.

This method does not currently make any sanity checks on the structure of the
plugin descriptor (which should follow the example bundled in I<example.yaml>),
but future versions might.

=cut

sub is_cpran {
  my ($opt, $arg) = @_;

  croak "Argument is not a Path::Class object"
    unless (ref $arg eq 'Path::Class');

  use YAML::XS;
  use File::Slurp;

  return 0 unless is_plugin($opt, $arg);

  my @contents = $arg->children();

  my $descriptor = 0;
  map {
    $descriptor = 1 if $_->basename eq 'cpran.yaml';
  } @contents;
  unless ($descriptor) {
    print STDERR "D: ", $arg->basename, " does not have a descriptor\n" if $opt->{debug};
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
    print STDERR "D: ", $arg->basename, " is not a directory\n" if $opt->{debug};
    return 0;
  }

  unless ($arg->parent eq CPrAN::praat() ) {
    print STDERR "D: ", $arg->basename, " is not in " . CPrAN::praat() . "\n" if $opt->{debug};
    return 0;
  }

  unless ($arg->basename =~ /^plugin_/) {
    print STDERR "D: ", $arg->basename, " is not properly named\n" if $opt->{debug};
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

Returns a list of all plugins known by B<CPrAN>. In practice, this is the list of
plugins whose descriptors have been saved by C<cpran update>

    my @known = known();
    print "$_\n" foreach (@known);

=cut

sub known {
  use Path::Class;

  return map {
    $_->basename;
  } dir( CPrAN::root() )->children;
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

  if ($opt->{yes}) { print "yes\n"; return 1; }

  my $input;
  $input = <STDIN>;
  chomp $input;
  $input = $default if ($input eq "");
  ($input =~ /^y(es)?$/i) ? return 1 : return 0;
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

0.0.1

=cut

our $VERSION = '0.0.1';

1;
