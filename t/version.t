use Test::More tests => 4;
use App::Cmd::Tester;

use CPrAN;

my $result;

$result = test_app(CPrAN => [qw( --version )]);

my @stdout = split /\n/, $result->stdout;
like($stdout[0],
  qr/\w+ \(CPrAN\) version [\d\.]+ \([^)]+\)/,
  'print client version'
);

like($stdout[1],
  qr/^(Using Praat|Praat not found)/,
  'print Praat version'
);

is($result->stderr, '', 'nothing sent to sderr');

is($result->error, undef, 'threw no exceptions');
