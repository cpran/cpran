#!/usr/bin/perl -w

BEGIN {
  eval 'use TAP::Harness';
  die "Need TAP::Harness to test" if $@;
}

my $directory = $ARGV[0];
opendir (DIR, $directory) or die $!;

my $harness = TAP::Harness->new({
  failures  => 1,
  exec => [ 'praat' ],
});

my @tests;
while (my $file = readdir(DIR)) {
  push @tests, $directory . "/" . $file if ($file =~ /\.t$/);
}

my $aggregator = $harness->runtests(@tests);
exit 1 unless ($aggregator->all_passed);
exit 0;
