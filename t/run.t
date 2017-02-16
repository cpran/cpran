#!/usr/bin/env perl

use Test::Class::Moose::Load 't/lib/';
use Test::Class::Moose::Runner;
Test::Class::Moose::Runner->new(
  use_environment => 1,
  test_classes => \@ARGV,
)->runtests;
