use Test::More tests => 6;
use App::Cmd::Tester;

use CPrAN;
use File::Temp;
use Path::Class;
use Cwd;

my $original = cwd;
my $dir;
if ($ENV{CPRAN_PRAAT_DIR}) {
  $dir = dir($ENV{CPRAN_PRAAT_DIR});
}
else {
  $dir = dir(File::Temp->newdir);
}

my $result = test_app(CPrAN => [ "--praat=$dir", 'init', '--nogit', '--notest' ]);

ok(-e dir($dir, 'plugin_cpran'), "created plugin directory");
is($result->stderr, '', 'nothing sent to stderr');
is($result->error, undef, 'threw no exceptions');

$result = test_app(CPrAN => [ "--praat=$dir", 'init', '--nogit', '--notest' ]);

is($result->stderr, '', 'nothing sent to stderr');
is($result->stdout,
  "CPrAN is already initialised. Nothing to do here!\n",
  'did nothing if it existed'
);
is($result->error, undef, 'threw no exceptions');

END {
  chdir $original;
  $dir->rmtree(0, 0) unless $ENV{CPRAN_PRAAT_DIR};
}
