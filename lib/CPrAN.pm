package CPrAN;
# ABSTRACT: A package manager for Praat

use App::Cmd::Setup -app;
use Try::Tiny;
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
  use Path::Class 0.35;
  use Config;
  my ($CPRANROOT, $PRAATPREF);

  if (defined $ENV{CPRAN_PRAAT_DIR}) {
    $PRAATPREF = $ENV{CPRAN_PRAAT_DIR};
  }
  else {
    if ($Config{osname} eq 'darwin') {
      # Mac
      $PRAATPREF = dir('', $ENV{HOME}, 'Library', 'Preferences', 'Praat Prefs')->stringify;
    }
    elsif ($Config{osname} eq 'MSWin32') {
      # Windows
      $PRAATPREF = dir('', $ENV{HOMEPATH}, 'Praat')->stringify;
    }
    elsif ($Config{osname} eq 'cygwin') {
      # cygwin
      warn "Cygwin not tested. Treating as if GNU/Linux\n";
      $PRAATPREF = dir('', $ENV{HOME}, '.praat-dir')->stringify;
    }
    else {
      # GNU/Linux
      $PRAATPREF = dir('', $ENV{HOME}, '.praat-dir')->stringify;
    }
  }
  $CPRANROOT = $ENV{CPRAN_ROOT_NAME} // '.cpran';

  sub cpran_root  {
    shift;
    if (scalar @_) { $CPRANROOT = shift }
    else { return dir(praat_prefs({}), $CPRANROOT)->stringify }
  }

  sub praat_prefs {
    shift;
    if (scalar @_) { $PRAATPREF = shift }
    else { return $PRAATPREF }
  }
}

# TOKEN, APIURL and GROUP are API dependant values. Being in this enclosure,
# access is limited to the accessors below.
{
  my ($TOKEN, $APIURL, $GROUP);
  $TOKEN  = 'Myz-wxxGLnV_syejdkWx';
  # NOTE (jja) This does not seem to work. HTTPS requirement somehow propagates
  #            all the way to WWW::GitLab::v3->_get()
  try {
    require LWP::Protocol::https;
    $APIURL = 'https://gitlab.com/api/v3/';
  }
  catch {
    warn "Falling back to HTTP. Install LWP::Protocol::https for HTTPS\n";
    $APIURL = 'http://gitlab.com/api/v3/';
  };
  $GROUP  = '133578';

  sub api_token { shift; if (@_) { $TOKEN  = shift } else { return $TOKEN  } }
  sub api_url   { shift; if (@_) { $APIURL = shift } else { return $APIURL } }
  sub api_group { shift; if (@_) { $GROUP  = shift } else { return $GROUP  } }
}

sub run {
  my ($self) = @_;

  # We should probably use Class::Default.
  $self = $self->new unless ref $self;

  # Prepare the command we're going to run
  my @argv = $self->prepare_args();
  my ($cmd, $opt, @args) = $self->prepare_command(@argv);

  # If we are not running interactively, and the command's input argument
  # list is empty, read in arguments from STDIN. If any have been read, then
  # activate the --yes flag.
  unless (-t) {
    my $pre = scalar @args;
    unless ($pre) {
      while (<STDIN>) {
        chomp;
        push @args, $_;
      }
    }
    my $post = scalar @args;

    $opt->{yes} = 1 if $post > $pre;
  }

  # Remove duplicate arguments
  my %seen;
  @args = grep { ! $seen{$_}++ } @args;

  # Run the requested command
  $self->execute_command($cmd, $opt, @args);
}

# By redefining this subroutine, we lightly modify the behaviour of the App::Cmd
# app. In this case, we process the global options, and pass them to
# the invoked commands together with their local options.
sub execute_command {
  my ($self, $cmd, $opt, @args) = @_;

  $self->set_globals($cmd, $opt);
  $self->check_permissions($cmd, $opt) unless ($cmd =~ /(version|help)/);

  if ($opt->{debug}) {
    my @c = split(/::/, ref $cmd);
    warn "DEBUG: Running ", pop @c, "\n";
    warn "DEBUG: Options:\n";
    warn "DEBUG:   $_: $opt->{$_}\n" foreach keys %{$opt};
  }

  # A verbose level of 1 prints default messages to STDOUT. --quiet
  # sets verbosity to 0, omitting all output. Higher values of verbose
  # will increase verbosity.
  $opt->{$_} = $self->global_options->{$_} foreach keys %{$self->global_options};
  if (defined $opt->{quiet}) {
    $opt->{verbose} = 0;
  }
  else {
    $opt->{verbose} = ++$opt->{verbose};
  }

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
    [ "bin=s"       => "set path to the Praat binary" ],
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
  my ($self, $cmd, $opt) = @_;
  my $gopt = $self->global_options;

  $self->praat_prefs ($gopt->{praat})     if defined $gopt->{praat};
  $self->cpran_root        ($gopt->{cpran})     if defined $gopt->{cpran};

  $self->api_token   ($gopt->{api-token}) if defined $gopt->{'api-token'};
  $self->api_group   ($gopt->{api-group}) if defined $gopt->{'api-group'};
  $self->api_url     ($gopt->{api-url})   if defined $gopt->{'api-url'};
}

=item check_permissions()

CPrAN needs read and write access to the path set as root, and to Praat's
# preferences directory. This subroutine makes sure this is the case, or croaks.

=cut

# TODO(jja) If this is a fresh install, CPrAN root will not exist, so will not
# readable/writable. What needs to be checked is whether the root could be
# created.
sub check_permissions {
  my ($self, $cmd, $opt) = @_;

  if (-e $self->cpran_root) {
    croak "Cannot read from CPrAN root at " . $self->cpran_root
      unless (-r $self->cpran_root());
    croak "Cannot write to CPrAN root at " . $self->cpran_root
      unless (-w $self->cpran_root());
  }
  else {
    File::Path::make_path( $self->cpran_root )
      or carp "Could not make directory at " . $self->cpran_root;
  }

  croak "Cannot read from preferences directory at " . $self->praat_prefs
    unless (-r $self->praat_prefs);
  croak "Cannot write to preferences directory at " . $self->praat_prefs
    unless (-w $self->praat_prefs);
}

=item yesno()

Gets either a I<yes> or a I<no> answer from STDIN. As arguments, it first
receives a reference to the options hash, followed by the default answer (ie,
the answer that will be entered if the user simply presses enter).

    my $opt = ( yes => 1 );            # Will automatically say 'yes'
    print "Yes or no?";
    if (yesno( $opt )) { print "You said yes\n" }
    else { print "You said no\n" }

By default, responses matching /^y(es)?$/i are considered to be I<yes>
responses.

=cut

sub yesno {
  my ($opt, $default) = @_;

  $default = $default // 'y';
  $default = substr($default, 0, 1);

  if ($opt->{quiet} && !$opt->{yes}) {
    return 0;
  }

  if ($opt->{yes}) {
    print " yes\n" unless ($opt->{quiet});
    return 1;
  }

  my $prompt = " [y/n] ";
  $prompt =~ s/($default)/\U$1/;
  print $prompt unless $opt->{quiet};

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

Copyright 2015-2016 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::deps|deps>,
L<CPrAN::Command::init|init>,
L<CPrAN::Command::install|install>,
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
