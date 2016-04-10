package CPrAN::Command::create;
# ABSTRACT: Create a new plugin from a template

use CPrAN -command;

use strict;
use warnings;

use Carp;
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
}

=head1 EXAMPLES

    # Create a blank plugin with the default values
    cpran create
    # Create a blank plugin with specified values
    cpran create --name="myplugin" --author="A. N. Author"

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;

  my $name;
  if (scalar @{$args}) {
    $name = shift @{$args};
  }
  else {
    do {
      my $dict = file( file($INC{'Data/Random/WordList.pm'})->dir, 'dict' );
      my $wl = Data::Random::WordList->new( wordlist => $dict );
      $name = join '-', map { lc } $wl->get_words(2);
    } until (! -e 'plugin_' . $name);
  }

  print 'Creating plugin "', $name, '"...', "\n";
  if (-e 'plugin_' . $name) {
    warn "There is already a plugin by that name! (in 'plugin_$name')\n";
    exit 1;
  }

  use Cwd;
  my $app = CPrAN->new();
  my $here = cwd;
  $app->praat( $here );

  my %params;
  %params = %{$opt};
  $params{virtual} = 1;
  $params{quiet} = 1;

  print 'Finding template...', "\n";
  my $cmd = CPrAN::Command::update->new({});
  my $template = shift @{$app->execute_command($cmd, \%params, 'template')};

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

  print 'Plugin "', $name, '" succesfully created!', "\n";

}

sub opt_spec {
  return (
    [ "name"   => "specify the name of the plugin" ],
    [ "author" => "specify the author of the plugin" ],
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
