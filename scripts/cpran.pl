#!/usr/bin/perl

use warnings;
use diagnostics;
use strict;

use CPrAN::Client;

binmode STDOUT, ':utf8';
use 5.010;

my $cpran = CPrAN::Client->new(
  test => 'testitcle',
);

print "Found the following plugins:\n";
map { say $_->{name} } $cpran->plugins();
