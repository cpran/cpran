#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More tests => 6;

BEGIN {
  use_ok('CPrAN');
  use_ok('CPrAN::Plugin');
  use_ok('CPrAN::Praat');
}

can_ok('CPrAN', (
  'set_globals',
  'check_permissions',
  'make_root',
  'installed',
  'known',
  'dependencies',
  'order_dependencies',
  'yesno',
));

can_ok('CPrAN::Plugin', (
  'new',
  '_init',
  'is_cpran',
  'is_installed',
  'update',
  'root',
  'name',
  'id',
  'url',
  'is_latest',
  'test',
  'fetch',
  'print',
  '_read',
  '_force_lc_hash',
));

can_ok('CPrAN::Praat', (
  'new',
  'remove',
  'download',
  'current',
  'latest',
));
