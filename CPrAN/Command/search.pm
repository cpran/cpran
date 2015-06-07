# ABSTRACT: search among available CPrAN plugins
package CPrAN::Command::search;

use CPrAN -command;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

=encoding utf8

=head1 NAME

B<search> - Search CPrAN plugins

=head1 SYNOPSIS

cpran search [options] [arguments]

=head1 DESCRIPTION

Searches both the local and remote catalogs of CPrAN plugins.

=cut

sub description {
  return "Perform searches among CPrAN plugins";
}

=pod

The argument to B<search> must be a single regular expression. Currently,
B<search> tries to match it on the plugni's name, and returns a list of all
those who do.

When executed directly, it will print information on the matched plugins,
including their name, version, and a short description. If searching the locally
installed plugins, both the local and the remote versions will be displayed.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Must provide a search term") unless @{$args};
}

=head1 EXAMPLES

    # Show all available plugins
    cpran search .*
    # Show installed plugins with the string "utils" in their name
    cpran search -i utils

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  use Path::Class;
  use Text::Table;

  my @names = CPrAN::installed();
  if ($opt->{installed}) {
    print "D: " . scalar @names . " installed plugins\n" if ($opt->{debug});
  }
  else {
    @names = @names, CPrAN::known();
    my %names;
    map { $names{$_} = 1 } @names;
    @names = keys %names;
    print "D: " . scalar @names . " known plugins\n" if $opt->{debug};
  }
  my $output = Text::Table->new(
    "Name", "Local", "Remote", "Description"
  );
  @names = sort { "\L$a" cmp "\L$b" } @names;

  my @found;
  map {
    if (/$args->[0]/) {
      $output->add(make_row($opt, $_));
      push @found, $_;
    }
  } @names;

  if (@found) { print $output }
  else { print "No matches found\n" }

  return @found;
}

=head1 OPTIONS

=over

=item B<--installed>

Search the local (installed) CPrAN catalog.

=item B<--debug>

Print debug messages.

=back

=cut

sub opt_spec {
  return (
    # [ "name|n"        => "search in plugin name" ],
    # [ "description|d" => "search in description" ],
    [ "installed|i"   => "only consider installed plugins" ],
  );
}

=head1 METHODS

=over

=cut

=item B<make_row()>

Generates the appropriate line for a single plugin specified by name. Takes the
name as an argument, and returns a list suitable to be plugged into a
Text::Table object.

The output depends on the current options: if B<--installed> is enabled, the
returned list will have both the local and the remote versions.

=cut

sub make_row {
  my ($opt, $name) = @_;

  use YAML::XS;
  use File::Slurp;

  my $plugin = dir(CPrAN::praat(), 'plugin_' . $name);
  if (CPrAN::is_cpran( $opt, $plugin )) {
    my $remote_file = file(CPrAN::root(), $name);
    my $local_file  = file( $plugin, 'cpran.yaml' );

    my $local_version  = '';
    my $remote_version = '';
    my $description    = '[No description]';

    if ( -e $local_file->stringify ) {
      my $content = read_file($local_file->stringify);
      my $yaml = Load( $content );

      $local_version = $yaml->{Version};
      $description   = $yaml->{Description}->{Short};
    }

    if ( -e $remote_file->stringify ) {
      my $content        = read_file($remote_file->stringify);
      my $yaml           = Load( $content );

      $remote_version = $yaml->{Version};
      $description   = $yaml->{Description}->{Short};
    }

    return ($name, $local_version, $remote_version, $description);
  }
  else {
    # Not a CPrAN plugin
    return ($name, '', '', '[Not a CPrAN plugin]');
  }
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>,
L<CPrAN::Command::remove|remove>

=cut

1;
