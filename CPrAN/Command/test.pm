# ABSTRACT: run tests for the given plugin
package CPrAN::Command::test;

use CPrAN -command;

# Safely load required modules
BEGIN {
  my @use = (
    'use TAP::Harness',
    'use Path::Class',
    'use Carp',
  );
  my $missing = 0;
  foreach (@use) {
    eval $_;
    if ($@) {
      if ($@ =~ /Can't locate (\S+)/) {
        $missing = 1;
        warn "W: Module $1 is not installed\n";
      }
      else { die $@ }
    }
  }
  if ($missing) {
    warn "E: Unmet dependencies.";
    warn "Please install the missing modules before continuing.\n";
    exit 1;
  }
}

use strict;
use warnings;

binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<test> - Run tests for the specified plugin

=head1 SYNOPSIS

cpran test [options] plugin

=head1 DESCRIPTION

Run tests for the specified plugins. When called on its own it will simply
report the results of the test suites associated with the given plugins.
When called from within CPrAN (eg. as part of the installation process), it
will only report success if all tests for all given plugins were successful.

=cut

sub description {
  return "Run tests for a single plugin";
}


sub validate_args {
  my ($self, $opt, $args) = @_;
}

=head1 EXAMPLES

    # Run tests for the specified plugin
    cpran test plugin

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  my $all_passed = 1;
  foreach my $plugin (@{$args}) {
    # Make a list of tests
    my $test_dir = dir( CPrAN::praat(), 'plugin_' . $plugin, 't' );
    unless ( -e $test_dir ) {
      warn "No tests for $plugin. Skipping\n" if $opt->{verbose};
      next;
    }
    opendir (DIR, $test_dir) or Carp::croak "$test_dir: " . $!;
    my @tests;
    while (my $file = readdir(DIR)) {
      push @tests, file($test_dir, $file) if ($file =~ /\.t$/);
    }
    @tests = sort @tests;

    # Run the tests
    my $praat;
    for ($^O) {
      if    (/darwin/)  { $praat = 'Praat'    } # Untested
      elsif (/MSWin32/) { $praat = 'praatcon' }
      else              { $praat = 'praat'    }
    }
    my $harness = TAP::Harness->new({
      failures  => 1,
      exec => [ $praat ],
    });
    my $aggregator = $harness->runtests(@tests);

    $all_passed = 0 unless ($aggregator->all_passed);
  }
  return $all_passed;
}

sub opt_spec {
  return (
    # [ "name|n"        => "search in plugin name" ],
    # [ "description|d" => "search in description" ],
    # [ "installed|i"   => "only consider installed plugins" ],
  );
}

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>
L<CPrAN::Command::show|show>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,

=cut

1;
