# ABSTRACT: delete an installed plugin from disk
package CPrAN::Command::remove;

use CPrAN -command;

use strict;
use warnings;

use Carp;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

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

  if (grep { /praat/i } @{$args}) {
    if (scalar @{$args} > 1) {
      die "Praat must be the only argument for processing\n";
    }
    else {
      use CPrAN::Praat;
      my $praat = CPrAN::Praat->new;
    
      unless (defined $praat->{path}) {
        warn "Praat is not installed. Use 'cpran install praat' to install it\n";
        exit 0;
      }
    
      unless ($opt->{quiet}) {
        print "Praat will be permanently REMOVED:\n";
        print "Do you want to continue? [y/N] ";
      }
      if (CPrAN::yesno( $opt, 'n' )) {
        try {
          $praat->remove;
        }
        catch {
          die "Could not remove Praat: $_\n"
        };
        print "Done.\n" unless $opt->{quiet};
      }
    }
  }

  my $prefix_warning = 0;
  foreach (0..$#{$args}) {
    if ($args->[$_] =~ /^plugin_/) {
      $prefix_warning = 1;
    }
    $args->[$_] =~ s/^plugin_//;
  }
  warn "W: Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning);
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
  use CPrAN::Plugin;

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') {
      $_;
    }
    else {
      CPrAN::Plugin->new( $_ );
    }
  } @{$args};

  my @todo;
  foreach my $plugin (@plugins) {
    if ($plugin->is_installed) {
      if ($plugin->is_cpran || $opt->{force}) {
        warn "W: $plugin->{name} is not a CPrAN plugin, but processing anyway.\n"
          unless $plugin->is_cpran;
        push @todo, $plugin;
      }
      else {
        warn "W: $plugin->{name} is not a CPrAN plugin. Use --force to process anyway.\n";
      }
    }
    else {
      warn "W: $plugin->{name} is not installed; cannot remove.\n";
    }
  }

  if (@todo) {
    my @names;
    unless ($opt->{quiet}) {
      print "The following plugins will be REMOVED:\n";
      print '  ', join(' ', map { $_->{name} } @todo ), "\n";
      print "Do you want to continue? [y/N] ";
    }
    if (CPrAN::yesno( $opt, 'n' )) {
      foreach my $plugin (@todo) {
        print "Removing $plugin->{name}...\n" unless ($opt->{quiet});

        # TODO(jja) Improve error checking
        my $ret = dir($plugin->root)->rmtree($opt->{verbose} - 1, $opt->{cautious});
        unless ($ret) {
          warn "Could not completely remove ", $plugin->root, "\n" unless ($opt->{quiet});
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

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

1;
