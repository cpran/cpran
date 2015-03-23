# ABSTRACT: install new plugins
package CPrAN::Command::install;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Carp;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
    [ "yes|y", "do not ask for confirmation" ],
    [ "force|f", "print debugging messages" ],
    [ "quiet",    "produce no output" ],
    [ "debug", "force installation of plugin" ],
  );
}

sub description {
  return "Install new CPrAN plugins";
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Missing arguments") unless @{$args};

  # Users might be tempted to input the names of plugin as "plugin_name", but
  # this is not correct. The "plugin_" prefix is not part of the plugin's name,
  # but a (clumsy) way for Praat to recognize plugin directories.
  my $prefix_warning = 0;
  foreach (0..$#{$args}) {
    if ($args->[$_] =~ /^plugin_/) {
      $prefix_warning = 1;
    }
    $args->[$_] =~ s/^plugin_//;
  }
  warn "W: Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning);

  CPrAN::set_global( $opt );
}

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
  # @names will hold the names of the plugins passed as arguments that are
  #   a) valid CPrAN plugin names; and
  #   b) not already installed (unless the user forces reinstallation)
  my @names;
  foreach (@{$args}) {
    if (exists $installed{$_} && !$opt->{force}) {
      warn "W: $_ is already installed\n";
    }
    else {
      # HACK(jja) We add the 'cpran/' prefix to distinguish CPrAN requirements
      if (exists $known{$_}) { push @names, 'cpran/' . $_ }
      else { warn "W: no plugin named $_\n" }
    }
  }

  # Get a source dependency tree for the plugins that are to be installed.
  # The dependencies() subroutine calls itself recursively to include the
  # dependencies of the dependencies, and so on.
  my @deps = CPrAN::dependencies($opt, \@names);

  # The source tree is then ordered to get a schedule of plugin installation.
  # In the resulting list, plugins with no dependencies come first, and those
  # that depend on them come later.
  my @ordered = CPrAN::order_dependencies(@deps);

  # Scheduled plugins that are already installed need to be removed from the
  # schedule
  # TODO(jja) What does --force mean in this context?
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
    if (CPrAN::yesno($opt, 'n')) {
      foreach (@schedule) {

        # Now that we know what plugins to install and in what order, we get
        # them and install them
        print "Downloading archive for $_->{name}\n" unless ($opt->{quiet});
        my $gzip = get_archive( $opt, $_->{name}, '' );

        print "Extracting... " unless ($opt->{quiet});
        install( $opt, $gzip );

        print "done\n" unless ($opt->{quiet});
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
    }
  }
}

sub get_archive {
  my ($opt, $name, $version) = @_;

  use GitLab::API::v3;

  my $api = GitLab::API::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  my $project = shift @{$api->projects({ search => 'plugin_' . $name })};
  my $tag;
  if ($version eq '') {
    my @tags = @{$api->tags($project->{id})};
    croak "No tags for $name" unless (@tags);
    $tag = shift ;
  }
  else {
    # TODO(jja) Enable installation of specific versions
    my $tags = $api->tags($project->{id});
    print Dumper($tags);
    $tag = shift @{$tags};
  }

  my %params = ( sha => $tag->{commit}->{id} );
#   # HACK(jja) This should work, but the Perl GitLab API seems to currently be
#   # broken. See https://github.com/bluefeet/GitLab-API-v3/issues/5
#   my $archive = $api->archive(
#     $project->{id},
#     \%params
#   );

  # HACK(jja) This is a workaround while the Perl GitLab API is fixed
  use LWP::Curl;

  my $referer = '';
  my $get_url = CPrAN::api_url() . '/projects/' . $project->{id} . '/repository/archive?private_token=' . CPrAN::api_token() . '&sha=' . $params{sha};
  my $lwpcurl = LWP::Curl->new();
  return $lwpcurl->get($get_url, $referer);
}

sub install {
  my ($opt, $gzip) = @_;

  use Archive::Extract;
  use File::Temp;
  use Path::Class;

  my $tmp = File::Temp->new(
    dir => '.',
    template => 'cpranXXXXX',
    suffix => '.tar.gz',
  );
  my $archive = file($tmp->filename);
  my $fh = $archive->openw();
  $fh->print($gzip);
  print "D: Wrote to $archive\n" if $opt->{debug};

  my $ae = Archive::Extract->new( archive => $tmp->filename );

  my $ok = $ae->extract( to => CPrAN::praat() )
    or die "Could not extract package: $ae->error";

  # GitLab archives have a ".git" suffix in their directory names
  # We need to remove that suffix
  my $final_path = $ae->extract_path;
  $final_path =~ s/\.git$//;

  # TODO(jja) If we are forcing the re-install of a plugin, the previously
  # existing directory needs to be removed. Maybe this could be better handled?
  if (-e $final_path && $opt->{force}) {
    use File::Path qw(remove_tree);
    remove_tree($final_path);
  }

  # Rename directory
  use File::Copy;
  move($ae->extract_path, $final_path)
    or croak "Move failed: $!";
}

1;
