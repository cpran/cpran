package CPrAN;

use App::Cmd::Setup -app;
use File::Path;
# use Getopt::Long;

our $ROOT  = "../.cpran";
our $PRAAT = "../..";
our $TOKEN = 'WMe3t_ANxd3yyTLyc7WA';
our $VERSION = '0.0.1';

# GetOptions (
#   'praat=s' => \$PRAAT,
#   'cpran=s' => \$ROOT,
#   'token=s' => \$TOKEN,
# );

File::Path::make_path( $ROOT );

sub is_cpran {
  my ($opt, $arg) = @_;

  use YAML::XS;
  use File::Slurp;

  return 0 unless is_plugin($opt, $arg);

  my @contents = $arg->children();

  my $descriptor = 0;
  map {
    $descriptor = 1 if $_->basename eq 'cpran.yaml';
  } @contents;
  unless ($descriptor) {
    print STDERR "D: ", $arg->basename, " does not have a descriptor\n" if $opt->{debug};
    return 0;
  }

  return 1;
}

sub is_plugin {
  my ($opt, $arg) = @_;

  unless ($arg->is_dir) {
    print STDERR "D: ", $arg->basename, " is not a directory\n" if $opt->{debug};
    return 0;
  }

  if ($arg->basename =~ /^plugin_/) {
    return 1;
  }
  else {
    print STDERR "D: ", $arg->basename, " is not a plugin\n" if $opt->{debug};
    return 0;
  }
}

sub installed {
  use Path::Class;

  my @all_files = dir( $CPrAN::PRAAT )->children;

  my @installed;
  foreach (@all_files) {
    my $name = $_->basename;
    $name =~ s/^plugin_//;
    if (CPrAN::is_plugin( $opt, $_ )) {
      push @installed, $name;
    }
  }

  return @installed;
}

sub known {
  use Path::Class;

  return map {
    $_->basename;
  } dir( $CPrAN::ROOT )->children;
}

sub yesno {
  my ($opt, $default) = @_;

  if ($opt->{yes}) { print "yes\n"; return 1; }

  my $input;
  $input = <STDIN>;
  chomp $input;
  $input = $default if ($input eq "");
  ($input =~ /^y(es)?$/i) ? return 1 : return 0;
}

1;
