use Test::More tests => 17;
use App::Cmd::Tester;

use CPrAN;
use File::Temp;
use Path::Class;
use Cwd;

my $original = cwd;
my $dir;
if ($ENV{CPRAN_PRAAT_DIR}) {
  $dir = $ENV{CPRAN_PRAAT_DIR};
}
else {
  $dir = File::Temp->newdir();
}

my $result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple' ]);

is($result->stderr, '', 'nothing sent to sderr');
is($result->error, undef, 'threw no exceptions');

my @lines = split /\n/, $result->stdout;
is(shift @lines,
  'No matches found',
  'no matches before update'
);

my $app = CPrAN->new();
my $cmd = CPrAN::Command::update->new({});
$app->execute_command($cmd, { quiet => 1 }, 'testsimple');

$result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple' ]);

is($result->stderr, '', 'nothing sent to sderr');
is($result->error, undef, 'threw no exceptions');

my @lines = split /\n/, $result->stdout;
like(shift @lines,
  qr/^Name\s+Local\s+Remote\s+Description\s*$/,
  'table has correct heading after update'
);

$result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple', '--quiet' ]);

is($result->stdout, '', 'nothing sent to sdout with --quiet');
is($result->stderr, '', 'nothing sent to sderr with --quiet');
is($result->error, undef, '--quiet threw no exceptions');

$result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple', '--installed' ]);

is($result->stderr, '', 'nothing sent to sderr with --installed');
is($result->error, undef, '--installed threw no exceptions');

$result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple', '-i' ]);

is($result->stderr, '', 'nothing sent to sderr with -i');
is($result->error, undef, '-i threw no exceptions');

$result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple', '--wrap' ]);

is($result->stderr, '', 'nothing sent to sderr with --wrap');
is($result->error, undef, '--wrap threw no exceptions');

$result = test_app(CPrAN => [ "--praat=$dir", 'search', 'testsimple', '--nowrap' ]);

is($result->stderr, '', 'nothing sent to sderr with --nowrap');
is($result->error, undef, '--nowrap threw no exceptions');

END {
  chdir $original;
  $dir->rmtree(0, 0) unless $ENV{CPRAN_PRAAT_DIR};
}
