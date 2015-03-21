package CPrAN;

use App::Cmd::Setup -app;
use File::Path;

our $ROOT = "../.cpran";
File::Path::make_path( $ROOT );

1;
