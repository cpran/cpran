package CPrAN;
# ABSTRACT: A package manager for Praat

use strict;
use warnings;

use Moose;
extends qw( MooseX::App::Cmd );

use CPrAN::Plugin;
use CPrAN::Praat;
use Carp;
use Encode qw( encode decode );
use Log::Any qw( $log );
use Praat::Version;
use Types::CPrAN qw( Praat );
use Types::Path::Tiny qw( Path );
use WWW::GitLab::v3;
use YAML::XS qw();
use Class::Load qw( try_load_class );

with 'MooseX::Getopt';

has protocol => (
  is => 'ro',
  init_arg => undef,
  default => sub { try_load_class('LWP::Protocol::https') ? 'https' : 'http' },
);

has root => (
  is  => 'rw',
  isa => Path,
  traits => [qw(Getopt)],
  documentation => 'CPrAN root',
  coerce => 1,
  lazy => 1,
  default => sub {
    $_[0]->praat->pref_dir->child('.cpran');
  },
);

has praat => (
  is  => 'rw',
  isa => Praat,
  traits => [qw(Getopt)],
  documentation => 'Praat binary',
  coerce => 1,
  lazy => 1,
  default => sub {
    CPrAN::Praat->new;
  },
);

has api => (
  is  => 'rw',
  isa => 'WWW::GitLab::v3',
  documentation => 'GitLab API connection',
  lazy => 1,
  default => sub {
    WWW::GitLab::v3->new(
      url   => $_[0]->url,
      token => $_[0]->token,
    );
  },
);

has token => (
  is  => 'rw',
  isa => 'Str',
  traits => [qw(Getopt)],
  documentation => 'GitLab API token',
  lazy => 1,
  default => '9zAWrV4B5XxJyp1ZcG3V',
);

has url => (
  is  => 'rw',
  isa => 'Str',
  traits => [qw(Getopt)],
  documentation => 'base URL for GitLab API',
  lazy => 1,
  default => sub { $_[0]->protocol . '://gitlab.com/api/v3/' },
);

has quiet => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  cmd_aliases   => 'q',
  documentation => 'quietly say no',
  lazy => 1,
  default => 0,
);

has debug => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  cmd_aliases   => 'q',
  documentation => 'print debug information',
  lazy => 1,
  default => 0,
);

has verbose => (
  is  => 'rw',
  isa => 'Int',
  traits => [qw(Getopt)],
  cmd_aliases => 'v',
  documentation => 'increase verbosity',
  lazy => 1,
  default => 0,
);

has yes => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  cmd_aliases => 'y',
  documentation => 'assume yes when prompted for confirmation',
  lazy => 1,
  default => 0,
);

has _pref_dir => (
  is  => 'rw',
  init_arg => 'pref_dir',
);

around execute_command => sub {
  my $orig = shift;
  my $self = shift;

  my ($cmd, $opt, $args) = @_;
  $log->trace("Executing", ref $cmd);

  # If running version, make sure version is fetched before-hand
  $self->praat->version
    if ref $cmd eq 'App::Cmd::Command::version';

  my @return = $self->$orig(@_);

  if (ref $cmd eq 'App::Cmd::Command::version') {
    if (defined $self->praat->version) {
      print sprintf "Using Praat version %s (%s)\n",
        $self->praat->version->praatify, $self->praat->bin;
    }
    else {
      print "Praat not found in PATH\n",
    }
  }

  return @return;
};

around BUILDARGS => sub {
  my $orig = shift;
  my $self = shift;

  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};
  $args = $self->$orig($args);

  my %deprecated = (
    'api-token' => 'token',
    'api-group' => 'group',
    'api-url'   => 'url',
    'cpran'     => 'root',
  );

  foreach (keys %deprecated) {
    if (defined $args->{$_}) {
      warn "The --$_ option is deprecated, use instead --$deprecated{$_}\n";

      $args->{$deprecated{$_}} = $args->{$_}
        unless defined $args->{$deprecated{$_}};
      delete $args->{$_};
    }
  }

  if (defined $args->{praat}) {
    warn "The behaviour of the --praat option has recently changed.\nPlease make sure it does what you think it does!\n";
  }

  return $args;
};

sub BUILD {
  my ($self) = @_;

  if (-e $self->root) {
    croak 'Cannot read from CPrAN root at ', $self->root->canonpath
      unless -r $self->root;

    croak 'Cannot write to CPrAN root at ', $self->root->canonpath
      unless -w $self->root;
  }
  else {
    $self->root->mkpath
      or warn 'Could not make directory at ', $self->root;
  }

  $self->praat->pref_dir($self->_pref_dir) if defined $self->_pref_dir;

  unless (-r $self->praat->pref_dir) {
    croak 'Cannot read from preferences directory at ',
      $self->praat->pref_dir->canonpath;
  }

  unless (-w $self->praat->pref_dir) {
    croak 'Cannot write to preferences directory at ',
      $self->praat->pref_dir->canonpath;
  }

  $log->debug("Initialised CPrAN instance");
}

=encoding utf8

=head1 NAME

B<CPrAN> - A package manager for Praat

=head1 SYNOPSIS

    use CPrAN;
    CPrAN->run;

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

=item B<--praat>=FILE

The path to use as binary for Praat. See the FILES section for information
on the platform-dependant default values used.

=item B<--pref-dir>=DIR

The path to use as the preferences directory for Praat. See the FILES section
for information on the platform-dependant default values used.

This option used to be called C<--praat>.

=item B<--root>=DIR

The path to use as the CPrAN root directory. See the FILES section
for information on the platform-dependant default values used.

This option used to be called C<--cpran>.

=item B<--token>=TOKEN

=item B<--group>=NUMBER

=item B<--url>=URL

These options set the credentials to talk to the GitLab API to obtain the
plugin archives and descriptors. As such, it is implementation-dependant, and is
currently tied to GitLab.

These options used to be called C<--api-XXX>, where XXX is their current name.

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
    [ 'praat=s'             => 'set path to the Praat binary' ],
    [ 'pref_dir|pref-dir=s' => 'set path to Praat preferences directory' ],
    [ 'root=s'              => 'set path to CPrAN root' ],
    [ 'token=s'             => 'set private token for GitLab API access' ],
    [ 'url=s'               => 'set url of GitLab API' ],
    [ 'group=s'             => 'set the id for the GitLab CPrAN group' ],
    [ 'verbose|v+'          => 'increase verbosity' ],
    [ 'quiet'               => 'quietly say no to everything' ],
    [ 'yes'                 => 'assume yes when prompted for confirmation' ],
    [ 'debug+'              => 'increase debug level' ],
  );
}

=item _yesno()

Gets either a I<yes> or a I<no> answer from STDIN. As arguments, it first
receives a reference to the options hash, followed by the default answer (ie,
the answer that will be entered if the user simply presses enter).

    $self->yes(1);            # Will automatically say 'yes'
    print "Yes or no?";
    if ($self->_yesno( $default )) { print "You said yes\n" }
    else { print "You said no\n" }

By default, responses matching /^y(es)?$/i are considered to be I<yes>
responses.

=cut

sub _yesno {
  my ($self, $default) = @_;

  $default = $default // 'y';
  $default = substr($default, 0, 1);

  return 0 if $self->quiet and !$self->yes;

  if ($self->yes) {
    print " yes\n" unless $self->quiet;
    return 1;
  }

  my $prompt = ' [y/n] ';
  $prompt =~ s/($default)/\U$1/;
  print $prompt unless $self->quiet;

  my $input;
  $input = <STDIN>;
  chomp $input;
  $input = $default if ($input eq q{});
  ($input =~ /^y(es)?$/i) ? return 1 : return 0;
}

sub run_command {
  my ($self, $command, @args) = @_;
  my $opt = (ref $args[-1] eq 'HASH') ? pop @args : {};

  my %bkp;
  foreach (qw( root praat api token quiet debug yes )) {
    if (defined $opt->{$_}) {
      $bkp{$_} = $self->$_;
      $self->$_($opt->{$_});
      delete $opt->{$_};
    }
  }

  local @ARGV = ( $command );
  my @argv = $self->prepare_args;
  my ($cmd) = $self->prepare_command(@argv);

  $cmd->$_($opt->{$_}) foreach keys %{$opt};
  my @retval = $self->execute_command($cmd, {}, @args);

  $self->$_($bkp{$_}) foreach keys %bkp;

  return @retval;
}

sub fetch_plugin {
  my ($self, $plugin) = @_;

  croak 'Cannot fetch an undefined plugin' unless defined $plugin;

  $plugin->cpran( $self->root )
    unless defined $plugin->cpran;

  $plugin->root( $self->praat->pref_dir->child( 'plugin_' . $plugin->name) )
    unless defined $plugin->root;

  my ($id, $url, $latest, $remote);

  foreach (@{$self->api->projects(
      { search => 'plugin_' . $plugin->name }
    )}) {

    if ($_->{name} eq 'plugin_' . $plugin->name and
        $_->{visibility_level} >= 20) {

      $id  = $_->{id};
      $url = $_->{http_url_to_repo};
      last;
    }
  }

  unless (defined $id and defined $url) {
    carp $plugin->name, ' not found remotely'
      unless $self->quiet;
    return undef;
  }

  my $tags = $self->api->tags( $id );
  my @releases;

  use Syntax::Keyword::Try;
  foreach my $tag (@{$tags}) {
    try {
      $tag->{semver} = Praat::Version->new($tag->{name}) }
    catch {
      $log->warn($@);
      next;
    }
    push @releases, $tag;
  };
  @releases = sort { $b->{semver} <=> $a->{semver} } @releases;

  # Ignore projects with no tags
  unless (scalar @releases) {
    carp 'No releases for ', $plugin->name
      unless $self->quiet;
    return undef;
  }

  $latest = $releases[0]->{commit}->{id};
  $remote = encode('utf-8', $self->api->blob(
    $id, $latest, { filepath => 'cpran.yaml' }
  ), Encode::FB_CROAK );

  try {
    YAML::XS::Load( $remote );
  }
  catch {
    carp 'Could not deserialise fetched remote for ', $plugin->name
      unless $self->quiet;
    return;
  }

  $plugin->url($url);
  $plugin->_remote($plugin->parse_meta($remote));
  $plugin->latest($plugin->_remote->{version});

  return 1;
}

sub test_plugin {
  my $self = shift;
  my $plugin = shift;
  my $opt = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  croak 'Cannot test an undefined plugin' unless defined $plugin;

  $plugin->cpran( $self->root )
    unless defined $plugin->cpran;

  $plugin->root( $self->praat->pref_dir->child( 'plugin_' . $plugin->name) )
    unless defined $plugin->root;

  $log->debug('Testing', $plugin->name);

  unless (defined $self->praat->version) {
    $log->warn('Praat is not installed; cannot test')
      unless $self->quiet;
    return undef;
  }

  return undef unless ($plugin->is_installed);

  my $oldwd = Path::Tiny->cwd;
  chdir $plugin->root
    or die 'Could not change directory';

  if (!$plugin->root->child('t')->exists) {
    $log->debug('No tests for', $plugin->name);
    return undef;
  }

  # Run the tests
  require App::Prove;
  my $prove = App::Prove->new;
  my @args;

  my $version = $self->praat->version;
  $version =~ s/(\d+\.\d+)\.?(\d*)/$1$2/;
  if ($version >= 6 and $version < 6.003) {
    $log->warn('Automated tests not supported for this version of Praat')
      unless $self->quiet;
    return undef;
  }
  elsif ($version >= 6.003) {
    push @args, ('--exec', $self->praat->bin . ' --ansi --run');
  }
  else {
    push @args, ('--exec', $self->praat->bin . ' --ansi');
  }

  if ($self->verbose) {
    push @args, '-v';
  }

  if ($opt->{log}) {
    use Syntax::Keyword::Try;
    try {
      require TAP::Harness::Archive;
      TAP::Harness::Archive->import;

      my $logdir = $self->root->child('.log');
      $logdir->remove_tree({ safe => 0 }) if $logdir->is_dir;
      $logdir->mkpath or die 'Could not create log directory';
      push @args, ('--archive', $logdir->canonpath);
    }
    catch {
      carp 'Disabling logging. Is TAP::Harness::Archive installed?', "\n"
        unless $self->quiet;
    }
  }

  $prove->process_args( @args );
  my $results = $prove->run;

  chdir $oldwd
    or die 'Could not change directory';

  return ($results) ? 1 : 0;
}

sub new_plugin {
  my $self = shift;
  my $arg = (@_) ? (@_ > 1) ? { @_ } : shift : {};
  $arg = { name => $arg } unless ref $arg;

  $arg->{cpran} //= $self->root;
  $arg->{root}  //= $self->praat->pref_dir->child(
    'plugin_' . ($arg->{name} // q{})
  );

  my $plugin = CPrAN::Plugin->new($arg);

  return $plugin->refresh;
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2017 José Joaquín Atria

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
