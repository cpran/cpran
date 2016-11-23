package CPrAN::Command::create;
# ABSTRACT: create a new plugin using a template

use Moose;
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';

use MooseX::Types::Path::Class;
use CPrAN::Types;

require Carp;
use Path::Class;

has name => (
  is  => 'rw',
  isa => 'Str',
  documentation => 'name of plugin',
  init_arg => undef,
  lazy => 1,
  default => sub {
    use Data::Random::WordList;

    my $name;
    do {
      my $dict = file( file($INC{'Data/Random/WordList.pm'})->dir, 'dict' );
      my $wl = Data::Random::WordList->new( wordlist => $dict );
      $name = join '-', map { lc } $wl->get_words(2);
      $name =~ s/[^a-z0-9_-]//g;
    } until (! -e 'plugin_' . $name);
    return $name;
  },
);

has [qw(
  author url desc readme version email
)] => (
  is  => 'rw',
  traits => [qw(Getopt)],
);

has '+author' => (
  isa => 'Str',
  documentation => 'name of plugin\'s author',
  lazy => 1,
  default => 'A. N. Onymous',
);

has '+url' => (
  isa => 'Str',
  documentation => 'URL of plugin\'s homepage',
  lazy => 1,
  default => sub {
    'http://cpran.net/plugins/' . $_[0]->name;
  },
);

has '+desc' => (
  isa => 'Str',
  documentation => 'short description of plugin',
  lazy => 1,
  default => '~',
);

has '+readme' => (
  isa => 'Path::Class::File',
  documentation => 'path to a readme for the plugin',
  coerce => 1,
);

has '+version' => (
  isa => 'SemVer',
  documentation => 'starting version of the plugin',
  coerce => 1,
  lazy => 1,
  default => sub {
    SemVer->new('0.0.1');
  },
  trigger => sub {
    my ($self, $new, $old) = @_;
    my $v = try {
      SemVer->new( $new );
    }
    catch {
      warn "<$new> is not a valid version number. Ignoring\n";
      $self->version($old);
    };
  },
);

has '+email' => (
  isa => 'Str',
  documentation => 'email of plugin\'s author',
  lazy => 1,
  default => 'email@example.com',
  trigger => sub {
    my ($self, $new, $old) = @_;

    use Regexp::Common qw[Email::Address];

    if (defined $old and $new !~ /^$RE{Email}{Address}$/) {
      warn "<$new> is not a valid email address. Ignoring\n";
      $self->email($old);
      $new = "<$new>" if $new ne '' and $new !~ /^<.*>$/;
    }
  },
);

around BUILDARGS => sub {
  my $orig = shift;
  my $self = shift;
  my $args = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  $self->$orig($args);

  return $args;
};

=head1 NAME

=encoding utf8

B<create> - Create a new CPrAN-compliant Praat plugin

=head1 SYNOPSIS

cpran create [options]

=head1 DESCRIPTION

Running C<create> will generate a new plugin in the current directory.

=cut

=head1 EXAMPLES

    Create a blank plugin with the default values
    cpran create
    Create a blank plugin with specified values
    cpran create myplugin --author="A. N. Author"

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  $self->name($args->[0]) if defined $args->[0];

  print 'Creating plugin "', $self->name, '"...', "\n" unless $self->app->quiet;
  if (-e 'plugin_' . $self->name) {
    warn "There is already a plugin by that name! (in 'plugin_", $self->name, "')\n";
    exit 1;
  }

  my $template =CPrAN::Plugin->new(
    name => 'template',
    cpran => $self->app,
  );

  unless ($template->is_installed) {
    print 'Installing plugin template...', "\n"
      unless $self->app->quiet;

    $template = $self->app->run_command( update => 'template', {
      virtual => 1,
      quiet => 1,
      yes => 1,
    });

    $self->app->run_command( install => $template, {
      git => 0,
      test => 0,
      quiet => 1,
      yes => 1,
    });
  }

  print 'Copying template...', "\n" unless $self->app->quiet;

  use File::Copy::Recursive qw( dircopy );
  use Cwd;

  my $source = $template->root;
  my $target = dir( cwd, 'plugin_' . $self->name );

  dircopy $source, $target
    or die "Could not rename plugin: $!\n";

  my $plugin = CPrAN::Plugin->new(
    name  => $self->name,
    cpran => $self->app,
    root  => $target,
  );

  $self->write_readme     ($plugin);
  $self->write_descriptor ($plugin);
  $self->write_setup      ($plugin);

  print 'Plugin "', $plugin->name, '" succesfully created!', "\n";

  return $plugin->refresh;
}

sub write_setup {
  my ($self, $plugin) = @_;

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  $year += 1900;

  use Path::Class;

  my $setup = file($plugin->root, 'setup.praat')->slurp;

  my ($name, $author, $url) = ($plugin->name, $self->author, $self->url);

  $setup =~ s/<plugin>/$name/g;
  $setup =~ s/<author>/$author/g;
  $setup =~ s/<website>/$url/g;
  $setup =~ s/<year>/$year/g;

  my $fh = file($plugin->root, 'setup.praat')->openw;
  print $fh $setup;
}

sub write_readme {
  my ($self, $plugin) = @_;

  my $default = 1;

  if (-f $self->readme) {
    $default = 0;
  }
  else {
    $self->readme(file($plugin->root, 'readme.md'));
  }

  my $readme = $self->readme->slurp;

  if ($default) {
    my $name = $plugin->name;
    $readme =~ s/<plugin>/$name/g;

    my $ul = '=' x length($name);
    $readme =~ s/={8}/$ul/;
    $readme =~ s/\* `\S+`/None/;
    $readme =~ s/\* `\S+`//g;
  }

  my $fh = $self->readme->openw;
  print $fh $readme;
}

sub write_descriptor {
  my ($self, $plugin) = @_;

  use Text::Template 'fill_in_string';

  (my $template = <<'  END_DESCRIPTOR') =~ s/^ {4}//gm;
    ---
    Plugin: {$name}
    Homepage: {$url}
    Version: {$version}
    Maintainer: { $OUT = $author; $OUT .= (length($email)) ? " $email" : '' }
    Depends:
      praat: 5.0.0+
      Plugins: []
    Recommends:
    License: GPL3
    Readme: {$readme}
    Description:
      Short: {$desc}
      Long: ~
  END_DESCRIPTOR

  my $descriptor = fill_in_string( $template, HASH => {
    name => $plugin->name,
    url => $self->url,
    version => $self->version->stringify,
    author => $self->author,
    email => $self->email,
    readme => $self->readme,
    desc => $self->desc,
  });

  my $fh = file($plugin->root, 'cpran.yaml')->openw;
  print $fh $descriptor;
}

=head1 OPTIONS

=over

=item B<--author>

Specify the name of the plugin's author. Although the field is named "author",
it is more appropriate if this is the maintainer of the plugin.

=item B<--email>

The current contact email of the plugin's maintainer.

=item B<--url>

The URL of the plugin. This URL is for humans to read more about the plugin.
By default, it points to the plugins page on the CPrAN website.

=item B<--desc>

The short description of the plugin. This string will is used for the output
of commands like B<search> and B<list>.

=item B<--version>

The plugin's version. To comply with the CPrAN requirements, this should be a
string in the style of the semantic version proposal, with three release
numbers separated by periods.

It defaults to B<0.0.1>.

=item B<--readme>

The path to a file to use as the plugin's README. If not provided, a placeholder
readme file will be recycled from the "template" CPrAN plugin.

=back

=cut


=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2016 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::deps|deps>,
L<CPrAN::Command::init|init>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
