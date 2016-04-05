use Test::More tests => 3;
use App::Cmd::Tester;

use CPrAN;
use File::Temp;
use Path::Class;
use Cwd;

my $original = cwd;
my $dir = File::Temp->newdir();
my @args = ('--praat', $dir->dirname, 'init', '--nogit' );

my $result = test_app(CPrAN => \@args );

ok(-e dir($dir->dirname, 'plugin_cpran'), 'created plugin directory');
is($result->stderr, '', 'nothing sent to stderr');
is($result->error, undef, 'threw no exceptions');

END {
  chdir $original;
  print $dir->rmtree(0, 0) . "\n";
}
