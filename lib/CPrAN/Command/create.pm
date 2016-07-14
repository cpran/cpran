package CPrAN::Command::create;
# ABSTRACT: Create a new plugin from a template

use CPrAN -command;

use strict;
use warnings;

use Carp;
use Path::Class;
use Data::Random::WordList;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<create> - Create a new CPrAN-compliant Praat plugin

=head1 SYNOPSIS

cpran create [options]

=head1 DESCRIPTION

Running C<create> will generate a new plugin in the current directory.

=cut

sub description {
  return "Create a new CPrAN-compliant Praat plugin";
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $opt->{author}  = $opt->{author}  // 'A. N. Onymous';
  $opt->{desc}    = $opt->{desc}    // '~';

  use SemVer;
  use Try::Tiny;
  {
    my $v = '0.0.1';
    $opt->{version} = $opt->{version} // $v;
    try {
      $opt->{version} = SemVer->new($opt->{version});
      $opt->{version} = $opt->{version}->stringify;
    }
    catch {
      warn "<$opt->{version}> is not a valid version number. Ignoring\n";
      $opt->{version} = $v;
    };
  }

  if (defined $opt->{readme} and !-f $opt->{readme}) {
    warn "<$opt->{readme}> is not a plain file. Ignoring\n";
    $opt->{readme} = undef;
  }
  $opt->{readme}  = $opt->{readme}  // '';

  use Regexp::Common qw[Email::Address];

  if (defined $opt->{email} and $opt->{email} !~ /^$RE{Email}{Address}$/) {
    warn "<$opt->{email}> is not a valid email address. Ignoring\n";
    $opt->{email} = undef;
  }
  $opt->{email}   = $opt->{email}   // '';
  $opt->{email}   = "<$opt->{email}>"
    if $opt->{email} ne '' and $opt->{email} !~ /^<.*>$/;
}

=head1 EXAMPLES

    # Create a blank plugin with the default values
    cpran create
    # Create a blank plugin with specified values
    cpran create myplugin --author="A. N. Author"

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  my $name;
  if (scalar @{$args}) {
    $name = shift @{$args};
  }
  else {
    do {
      my $dict = file( file($INC{'Data/Random/WordList.pm'})->dir, 'dict' );
      my $wl = Data::Random::WordList->new( wordlist => $dict );
      $name = join '-', map { lc } $wl->get_words(2);
      $name =~ s/[^a-z0-9_-]//g;
    } until (! -e 'plugin_' . $name);
  }

  $opt->{url} = $opt->{url} // 'http://cpran.net/plugins/' . $name;

  print 'Creating plugin "', $name, '"...', "\n";
  if (-e 'plugin_' . $name) {
    warn "There is already a plugin by that name! (in 'plugin_$name')\n";
    exit 1;
  }

  use Cwd;

  my $app = CPrAN->new();
  my $here = cwd;
  $app->praat_prefs( $here );

  my %params;
  %params = %{$opt};
  $params{virtual} = 1;
  $params{quiet} = 1;

  print 'Finding template...', "\n";
  my $cmd = CPrAN::Command::update->new({});
  my @result = $app->execute_command($cmd, \%params, 'template');
  my $template = shift @result;


  %params = %{$opt};
  $params{git} = 0;
  $params{yes} = 1;
  $params{test} = 0;
  $params{quiet} = 1;

  print 'Making a local copy...', "\n";
  $cmd = CPrAN::Command::install->new({});
  $app->execute_command($cmd, \%params, $template);

  use File::Copy;
  my $src = dir($template->{root});
  my $tgt = dir($src->parent, 'plugin_' . $name);

  File::Copy::move $src, $tgt
    or die "Could not rename plugin: $!\n";

  my $plugin = CPrAN::Plugin->new( $name );
  $self->write_readme     ($opt, $plugin);
  $self->write_descriptor ($opt, $plugin);
  $self->write_setup      ($opt, $plugin);

  print 'Plugin "', $plugin->{name}, '" succesfully created!', "\n";

  return $plugin->_init;
}

sub write_setup {
  my ($self, $opt, $plugin) = @_;

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  $year += 1900;

  my $setup = file($plugin->root, 'setup.praat')->slurp;
  $setup =~ s/<plugin>/$plugin->{name}/g;
  $setup =~ s/<author>/$opt->{author}/g;
  $setup =~ s/<website>/$opt->{url}/g;
  $setup =~ s/<year>/$year/g;

  my $fh = file($plugin->root, 'setup.praat')->openw();
  print $fh $setup;
}

sub write_readme {
  my ($self, $opt, $plugin) = @_;

  my $default;
  if (-f $opt->{readme}) {
    $opt->{readme} = file($opt->{readme});
    $default = 0;
  }
  else {
    $opt->{readme} = file($plugin->root, 'readme.md');
    $default = 1;
  }

  my $readme = $opt->{readme}->slurp;

  if ($default) {
    $readme =~ s/<plugin>/$plugin->{name}/g;

    my $ul = '=' x length($plugin->{name});
    $readme =~ s/========/$ul/;
    $readme =~ s/\* `\S+`/None/;
    $readme =~ s/\* `\S+`//g;
  }

  my $fh = file($plugin->root, $opt->{readme}->basename)->openw();
  print $fh $readme;
}

sub write_descriptor {
  my ($self, $opt, $plugin) = @_;

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

  $opt->{name} = $plugin->{name};
  my $descriptor = fill_in_string( $template, HASH => $opt );

  my $fh = file($plugin->root, 'cpran.yaml')->openw();
  print $fh $descriptor;

  $plugin->_init;
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

sub opt_spec {
  return (
    [ "author=s"  => "name of plugin's author" ],
    [ "email=s"   => "email of plugin's author" ],
    [ "url=s"     => "URL of plugin's homepage" ],
    [ "desc=s"    => "short description of the plugin" ],
    [ "version=s" => "starting version of the plugin" ],
    [ "readme=s"  => "path to a readme file" ],
  );
}

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
