package CPrAN::Command::search;
# ABSTRACT: search among available CPrAN plugins

use Moose;
use uni::perl;

with 'MooseX::Getopt';

extends qw( MooseX::App::Cmd::Command );

require Carp;
use Try::Tiny;

has installed => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in installed plugins',
  cmd_aliases => 'i',
);

has wrap => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'wrap output table when printing',
  lazy => 1,
  default => 1,
  cmd_aliases => 'w',
);

has in_name => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in name of plugin',
  cmd_aliases => 'N',
);

has in_description => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in description of plugin',
  cmd_aliases => 'D',
  default => 1,
);

has in_short => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in short description of plugin',
  cmd_aliases => 'S',
  default => 1,
);

has in_long => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in long description of plugin',
  cmd_aliases => 'L',
  default => 1,
);

has in_author => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'search in name of plugin\'s author',
  cmd_aliases => 'A',
);

has invert => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'perform a negative search',
  cmd_aliases => 'x',
);

=encoding utf8

=head1 NAME

B<search> - Search CPrAN plugins

=head1 SYNOPSIS

cpran search [options] [arguments]

=head1 DESCRIPTION

Searches both the local and remote catalogs of CPrAN plugins.

=cut

=pod

The argument to B<search> must be a series of regular expression patterns. The
patterns are matched sequentially, such that the second pattern is only tried
on the matches of the first pattern, and so on. Results show the entries that
matched all provided patterns.

By default, the patterns are checked against the plugin name, description (both
short and long, if provided) and the author's name, although these fields can
be turned on or off for finer control.

When executed directly, it will print information on the matched plugins,
including their name, local and remote versions, and a short description.

=cut

=head1 EXAMPLES

    # Show all available plugins
    cpran search .*
    # Show installed plugins with the string "utils" in their name
    cpran search -i utils

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  $self->app->logger->debug('Executing search');

  use CPrAN::Plugin;
  use Text::FormatTable;

  my %names;
  if (defined $self->installed) {
    if ($self->installed) {
      # User specified installed
      $names{$_} = 1 foreach $self->list_installed;
    }
    else {
      # User specified not installed
      $names{$_} = 1 foreach $self->list_known;
      delete $names{$_} foreach $self->list_installed;
    }
  }
  else {
    # User did not specify
    $names{$_} = 1 foreach $self->list_known;
    $names{$_} = 1 foreach $self->list_installed;
  }

  my @found = grep {
    my $plugin = $_;
    my $match = 0;
    $match = $self->_match($plugin, $_) foreach @{$args};
    $match = 1 - $match if $self->invert;
    $match;
  } sort {
    "\L$a->{name}" cmp "\L$b->{name}"
  } map {
    CPrAN::Plugin->new( name => $_, cpran => $self->app )
  } keys %names;

  unless ($self->app->quiet) {
    $self->{output} = Text::FormatTable->new('l l l l');
    $self->{output}->head(
      "Name", "Local", "Remote", "Description"
    );

    $self->_add_output_row($_) foreach @found;

    if (@found) {
      use Term::ReadKey;
      my ($wchar) = try {
        GetTerminalSize();
      }
      catch {
        warn "DEBUG: Unable to get terminal size: $_\n"
          if $self->debug;
        80;
      };
      print $self->{output}->render($self->wrap ? $wchar : 1000);
    }
    else { print "No matches found\n" }
  }

  return @found;
}

=head1 OPTIONS

=over

=item B<--name>, B<-n>

Perform search on plugin names. Default is to include names and descriptions.

=item B<--description>, B<-d>

Perform search on plugin descriptions, both short and long. Default is to
include names and descriptions.

=item B<--installed>, B<-i>

Search the local (installed) CPrAN catalog.

=item B<--nowrap>

Disables the line wrapping for the results table. This option is off by default.

=item B<--debug>, B<-D>

Print debug messages.

=back

=cut

# sub opt_spec {
#   return (
#     [ "name|n"        => "search in plugin name" ],
#     [ "description|d" => "search in plugin description" ],
#     [ "installed|i"   => "search on installed plugins" ],
#     [ "wrap!"         => "enable / disable line wrap for result table" ],
#   );
# }

=head1 METHODS

=over

=cut


=item list_installed()

Returns a list of all installed Praat plugins. See I<is_plugin()> for the
criteria they need to fulfill.

    my @installed = list_installed();
    print "$_\n" foreach (@installed);

=cut

sub list_installed {
  my ($self) = @_;

  return map {
    $1 if $_->basename =~ /^plugin_([\w\d_-]+)/;
  } grep {
    ($_->is_dir && $_->basename =~ /^plugin_[\w\d_-]+/)
  } $self->app->praat->pref_dir->children;
}

=item list_known()

Returns a list of all plugins known by B<CPrAN>. In practice, this is the list
of plugins whose descriptors have been saved by C<cpran update>

    my @known = list_known();
    print "$_\n" foreach (@known);

=cut

sub list_known {
  return map  { $_->basename }
         grep { $_->basename !~ /^\./ }
         $_[0]->app->root->children;
}

=item B<_match()>

Performs the search agains the specified fields of the plugin.

=cut

sub _match {
  my ($self, $plugin, $search) = @_;

  if (!defined $self->in_name or $self->in_name) {
    return 1 if ($plugin->name =~ /$search/i);
  }

  if (!defined $self->in_author or $self->in_author) {
    return 1 if defined $plugin->_remote
      and $plugin->_remote->{maintainer} =~ /$search/i;

    return 1 if defined $plugin->_local
      and $plugin->_local->{maintainer} =~ /$search/i;
  }

  if ($plugin->is_cpran) {
    if ($self->in_description) {
      if (defined $plugin->_remote) {
        return 1 if $self->in_short
          and $plugin->_remote->{description}->{short}  =~ /$search/i;

        return 1 if $self->in_long
          and $plugin->_remote->{description}->{long} =~ /$search/i;
      }

      if (defined $plugin->_local) {
        return 1 if $self->in_short
          and $plugin->_local->{description}->{short}  =~ /$search/i;

        return 1 if $self->in_long
          and $plugin->_local->{description}->{long} =~ /$search/i;
      }
    }
  }

  return 0;
}


=item B<_add_output_row()>

Generates and adds a line for the output table. This subroutine internally calls
C<_make_output_row()> and attaches it to the table.

=cut

sub _add_output_row {
  my ($self, $opt, $plugin) = @_;
  Carp::carp "No output table found" unless defined $self->{output};
  my @row = $self->_make_output_row($opt, $plugin);
  $self->{output}->row(@row);
}

=item B<_make_output_row()>

Generates the appropriate line for a single plugin specified by name. Takes the
name as an argument, and returns a list suitable to be plugged into a
Text::Table object.

The output depends on the current options: if B<--installed> is enabled, the
returned list will have both the local and the remote versions.

=cut

sub _make_output_row {
  my ($self, $plugin) = @_;

  use YAML::XS;

  my $description;
  my $local = my $remote = '';

  if ($plugin->is_cpran) {
    if ($plugin->is_installed) {
      $local = $plugin->_local->{version};
      $description = $plugin->_local->{description}->{short};
    }
    if (defined $plugin->_remote) {
      $remote = $plugin->_remote->{version};
      $description = $plugin->_remote->{description}->{short};
    }
  }
  else {
    $description = '[Not a CPrAN plugin]';
  }

  return ($plugin->{name}, $local, $remote, $description);
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015-2016 José Joaquín Atria

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
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
