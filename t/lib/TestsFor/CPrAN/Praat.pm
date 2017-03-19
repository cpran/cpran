package TestsFor::CPrAN::Praat;

use Test::Class::Moose;
with 'Test::Class::Moose::Role::AutoUse';

use Path::Tiny;
use Try::Tiny;
use Plack::Runner;
use Plack::App::File;
use Test::TCP;

sub test_use : Tests {
  my $test = shift;
  use_ok $test->class_name;
}

sub test_attributes : Tests {
  my $test = shift;

  # Private
  can_ok $test->class_name, $_
    foreach (qw( _barren _releases_endpoint _package_name _package_url _os _bit _ext ));

  # Public
  can_ok $test->class_name, $_
    foreach (qw( bin pref_dir version latest requested fetch ));
}

sub test_constructor : Tests {
  my $test = shift;
  my $class = $test->class_name;
  can_ok $class, 'new';
  ok my $self = $class->new,
    'constructor succeeds';
  isa_ok $self, $class;

  use Path::Class;
  ok $class->new({ bin => file('/usr/bin/praat') }),
    'constructor takes hashref';

  ok $class->new(  bin => file('/usr/bin/praat')  ),
    'constructor takes hash';

  SKIP: {
    skip 'Development tests - only for author testing', 5 unless defined $ENV{AUTHOR_TEST};

    {
      local $^O = 'darwin';
      my $self = $class->new;

      like $self->pref_dir->stringify, qr/Praat\ Prefs/,
        'default pref_dir in MacOS is in Library';
    }

    {
      local $^O = 'MSWin32';
      local $ENV{HOMEPATH} = 'C:\User\User';
      local $ENV{PROCESSOR_ARCHITECTURE} = undef;
      local $ENV{PROCESSOR_ARCHITEW6432} = undef;

      my $self = $class->new;
      like $self->pref_dir->stringify, qr/C:\\User\\User/,
        'default pref_dir in Windows is in HOMEPATH';
      is $self->_bit, 32,
        'default to 32-bit system in Windows without environment variables';

      local $ENV{PROCESSOR_ARCHITECTURE} = 'x86';
      $self = $class->new;

      is $self->_bit, 32,
        'detect 32-bit system in Windows using PROCESSOR_ARCHITECTURE';

      local $ENV{PROCESSOR_ARCHITECTURE} = 'AMD64';

      $self = $class->new;

      is $self->_bit, 64,
        'detect 64-bit system in Windows using PROCESSOR_ARCHITECTURE';

      local $ENV{PROCESSOR_ARCHITECTURE} = 'x86';
      local $ENV{PROCESSOR_ARCHITEW6432} = 'AMD64';

      $self = $class->new;

      is $self->_bit, 64,
        'detect 64-bit system in Windows using PROCESSOR_ARCHITEW6432';
    }

    {
      local $^O = 'something_else';
      my $self = $class->new;

      like $self->pref_dir->stringify, qr%/home.*\.praat-dir%,
        'default to UNIX and put pref_dir in home';
    }
  };
}

sub test_coercions : Tests {
  my $test = shift;
  my $class = $test->class_name;
  can_ok $class, 'new';
  ok my $self = $class->new,
    'constructor succeeds';
  isa_ok $self, $class;

  ok $self = $class->new( bin => '/usr/bin/praat' ),
    'bin takes Str';
  isa_ok $self->bin, 'Path::Tiny', 'bin';

  ok $self = $class->new( pref_dir => '/home/user/.praat-dir'),
    'pref_dir takes Str';
  isa_ok $self->pref_dir, 'Path::Tiny', 'pref_dir';
}

sub test_get : Tests {
  my $test = shift;
  my $class = $test->class_name;

  # Note: this, like the implementation in Test::TCP,
  # is vulnerable to race conditions
  use Net::EmptyPort qw( empty_port );
  my $host = '0.0.0.0';
  my $port = empty_port();

  test_tcp(
    host => $host,
    server => sub {
      my $port = shift;
      my $runner = Plack::Runner->new;
      $runner->parse_options(
        '--host'   => $host,
        '--port'   => $port,
        '--env'    => 'test',
        '--server' => 'HTTP::Server::PSGI'
      );
      $runner->run(Plack::App::File->new->to_app);
    },
    client => sub {
      my $port = shift;

      my $self = $class->new(
        _releases_endpoint => "http://$host:$port/t/data/good/releases",
      );

      # Force OS conditions for download testing
      $self->{_os}  = 'linux';
      $self->{_bit} = '32';
      $self->{_ext} = '.tar.gz';

      ok $self->latest, 'latest returns true when connected';
      isa_ok $self->latest, 'Praat::Version', 'latest version';
      is $self->latest->praatify, '4.2.03', 'latest parsed version correctly';
      like $self->_package_url, qr%fake\.example\.com%, 'parsed package url from latest';

      $self->_package_url("http://$host:$port/t/data/good/releases/file.txt");

      use Capture::Tiny qw( capture );
      my ($stdout, $stderr, $retval) = capture {
        $self->download;
      };

      is $retval, "Huzzah!\n", 'download retrieves content of package';
      like $stderr, qr/GET http.*OK/, 'download prints information to STDERR';

      ($stdout, $stderr, $retval) = capture {
        $self->download({ quiet => 1 });
      };
      is $stderr, '', 'download accepts options and can be made quiet';

      $self->requested('0.0.01');
      $self->fetch;
      like $self->_package_url, qr/0001/, 'retrieve a specific version';

      $self->_package_url("http://$host:$port/not/a/real/file.txt");
      ($stdout, $stderr, $retval) = try {
        capture {
          $self->download({ quiet => 1 });
        };
      }
      catch { ('', '', $_) };
      like $retval, qr/404 Not Found/, 'download dies when file not found';

      $self = $class->new(
        _releases_endpoint => "http://$host:$port/t/data/good/releases/all",
      );

      ok $self->releases, 'releases returns true';
      is scalar @{$self->releases}, 4, 'found only 4 releases in test data';
      is( (scalar grep { ref $_->{semver} eq 'Praat::Version' } @{$self->releases}), 4,
        'all found releases have version objects');

      $self = $class->new(
        _releases_endpoint => "http://$host:$port/t/data/bad/not_found.json",
      );
      # Force OS conditions for download testing
      $self->{_os}  = 'linux';
      $self->{_bit} = '32';
      $self->{_ext} = '.tar.gz';

      is $self->latest, undef, 'latest is undefined when endpoint not found';

      is scalar(@{$self->releases}), 0, 'releases is undefined when endpoint not found';
    },
  );
}

sub test_execute : Tests {
  my $test = shift;
  my $class = $test->class_name;

  use FindBin;
  my $self = $class->new(
    bin => "$FindBin::Bin/data/good/version",
  );

  ok $self->version, 'version returns true when connected';
  isa_ok $self->version, 'SemVer', 'current version';
  is $self->version->stringify, '5.3.51', 'version parsed version correctly';

  $self = $class->new(
    bin => "$FindBin::Bin/data/good/echo",
    pref_dir => "$FindBin::Bin/data/good",
  );

  is $self->version, undef, 'version undefined when unable to get version';

  my ($stdout, $stderr, $retval) = $self->run_script(qw( 1 2 3 ), []);
  chomp $stdout;

  ok defined $retval, 'execute returns a list of three';
  is $stdout, '1 2 3', 'pass arguments without options';

  ($stdout, $stderr, $retval) = $self->run_script(qw( 1 2 3 ));
  chomp $stdout;

  like $stdout, qr/--pref-dir=.*ansi.*run/,
    'default options include ansi run and pref dir';

  is $self->run_script(), undef, 'not passing a script returns undef';

  ($stdout, $stderr, $retval) = $self->run_script('script', [qw( --run )] );
  chomp $stdout;

  is $stdout, '--run script', 'can specify options';

  $self = $class->new;
  $self->{bin} = undef;
  is $self->version, undef, 'version undefined when binary is undefined';
}

sub test_remove : Tests {
  my $test = shift;
  my $class = $test->class_name;

  my $tmp = Path::Tiny->tempfile(
    dir => '.',
    template => 'deleteme_XXXXX',
  );

  my $self = $class->new(
    bin => $tmp->basename,
  );

  SKIP: {
    skip 'Could not create temporary bin file', 3 unless $tmp->exists;

    ok  $self->remove, 'remove returns true when bin exists';
    ok !$tmp->exists,  'bin was deleted';
    ok !$self->remove, 'remove returns false when binary does not exist';
  };

  {
    local $ENV{PATH} = '';
    ok my $self = $class->new, 'constructor works when binary is undef';

    $self->{bin} = undef;
    ok( (
      try { $self->remove; 0 }
      catch { 1 }
    ), 'remove dies when binary is undefined');
  }
}

"All's well that ends well";
