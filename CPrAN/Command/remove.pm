# ABSTRACT: delete an installed plugin from disk
package CPrAN::Command::remove;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;

=encoding utf8

=head1 NAME

B<remove> - Remove installed CPrAN plugins

=head1 SYNOPSIS

cpran remove [options] [arguments]

=head1 DESCRIPTION

Deletes a CPrAN plugin that has been installed.

=cut

sub description {
  return "Delete an installed CPrAN plugin";
}

=pod

Arguments to B<remove> must be at least one and optionally more plugin names to
remove. For each named passed as argument, all contents of the directory named
"plugin_<name>" will be removed from disk.

=cut

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

=head1 EXAMPLES

    # Remove some plugins
    cpran remove oneplugin otherplugin
    # Do not ask for confirmation
    cpran remove -y oneplugin

=cut

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
        warn "W: $_ is not a CPrAN plugin. Use --force to process anyway.\n";
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

=head1 OPTIONS

=over

=item B<--yes, -y>

Assumes yes for all questions.

=item B<--force>

Tries to work around problems.

=item B<--debug>

Print debug messages.

=item B<--verbose>

=item B<--quiet>

=item B<--cautious>

=back

=cut

sub opt_spec {
  return (
    [ "yes|y"    => "do not ask for confirmation" ],
    [ "force"    => "attempt to work around errors" ],
    [ "debug"    => "print debugging messages" ],
    [ "verbose"  => "increase verbosity" ],
    [ "quiet"    => "produce no output" ],
    [ "cautious" => "be extra-careful while removing files" ],
  );
}

=head1 METHODS

=over

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

CPrAN, CPrAN::Command::install, CPrAN::Command::search,
CPrAN::Command::update, CPrAN::Command::upgrade, CPrAN::Command::show,

=cut

1;
