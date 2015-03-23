# ABSTRACT: delete an installed plugin from disk
package CPrAN::Command::remove;

use CPrAN -command;

use strict;
use warnings;
# use diagnostics;
use Data::Dumper;

sub opt_spec {
  return (
    [ "yes|y"    => "do not ask for confirmation" ],
    [ "all"      => "process non-CPrAN plugins as well" ],
    [ "debug"    => "print debugging messages" ],
    [ "verbose"  => "increase verbosity" ],
    [ "quiet"    => "produce no output" ],
    [ "cautious" => "be extra-careful while removing files" ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Missing arguments") unless @{$args};

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

  use Path::Class;

  my @installed = CPrAN::installed();

  my %installed;
  $installed{$_} = dir(CPrAN::praat(), 'plugin_' . $_) foreach (@installed);

  my @files;
  map {
    if (exists $installed{$_}) {
      my $plugin = $installed{$_};

      my $is_cpran = CPrAN::is_cpran($opt, $plugin);
      if ( $is_cpran || $opt->{all}) {
        warn "W: $_ is not a CPrAN plugin, but processing anyway.\n"
          unless $is_cpran;
        push @files, $plugin;
      }
      else {
        warn "W: $_ is not a CPrAN plugin. Use --all to process anyway.\n";
      }
    }
    else {
      warn "W: $_ is not installed; cannot remove.\n";
    }
  } @{$args};

  if (@files) {
    my @names;
    unless ($opt->{quiet}) {
      print "The following plugins will be REMOVED:\n";
      foreach (@files) {
        my $name = $_->basename;
        $name =~ s/^plugin_//;
        push @names, $name;
      };
      print '  ', join(' ', @names), "\n";
      print "Do you want to continue? [y/N] ";
    }
    if (CPrAN::yesno($opt, 'n')) {
      foreach (0..$#files) {
        print "Removing $names[$_]... " unless ($opt->{quiet});
        # TODO(jja) Improve error checking
        my $ret = $files[$_]->rmtree($opt->{verbose}, $opt->{cautious});
        if ($ret) {
          print "done\n" unless ($opt->{quiet});
        }
        else {
          print "error\n" unless ($opt->{quiet});
        }
      }
    }
    else {
      print "Abort.\n" unless ($opt->{quiet});
    }
  }
}

1;
