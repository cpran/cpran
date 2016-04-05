use Test::More tests => 3;
use App::Cmd::Tester;

use CPrAN;

my $result = test_app(CPrAN => [qw( --version )]);

like($result->stdout, qr/\w+ \(CPrAN\) version [\d\.]+ \([^)]+\)\n/, 'printed what we expected');

is($result->stderr, '', 'nothing sent to sderr');

is($result->error, undef, 'threw no exceptions');
