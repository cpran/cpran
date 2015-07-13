# ABSTRACT: search among available CPrAN plugins
package CPrAN::Command::search;

use CPrAN -command;

use strict;
use warnings;

use Carp;

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

  # Search by default in all fields
  # If any fields are specified, then search in those
  if (!(defined $opt->{name} || defined $opt->{description})) {
    $opt->{name} = 1;
    $opt->{description} = 1;
  }
}

=head1 EXAMPLES

    # Show all available plugins
    cpran search .*
    # Show installed plugins with the string "utils" in their name
    cpran search -i utils

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  use CPrAN::Plugin;
  use Text::Table;

  my @plugins;
  my @names = CPrAN::installed();
  if (defined $opt->{installed}) {
    print "D: " . scalar @names . " installed plugins\n" if ($opt->{debug});
  }
  else {
    @names = (@names, CPrAN::known());
    my %names;
    $names{$_} = 1 foreach @names;
    @plugins = map { CPrAN::Plugin->new($_) } keys %names;
    print "D: " . scalar @plugins . " known plugins\n" if $opt->{debug};
  }

  $self->{output} = Text::Table->new(
    "Name", "Local", "Remote", "Description"
  );
  @plugins = sort { "\L$a->{name}" cmp "\L$b->{name}" } @plugins;

  my $list;
  $list->{$_->{name}} = $_ foreach @plugins;
  foreach my $query (@{$args}) {
    foreach my $name (keys %{$list}) {
      unless ($self->_match($opt, $list->{$name}, $query)) {
        delete $list->{$name};
      }
    }
  };

  my @found = map {
    $self->_add_output_row($opt, $list->{$_});
    $list->{$_}
  } sort keys %{$list};

  if ($opt->{verbose}) {
    if (@found) { print $self->{output} }
    else { print "No matches found\n" }
  }

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
    [ "name|n"        => "search in plugin name" ],
    [ "description|d" => "search in description" ],
    [ "installed|i"   => "only consider installed plugins" ],
  );
}

=head1 METHODS

=over

=cut

=item B<_match()>

Performs the search agains the specified fields of the plugin.

=cut

sub _match {
  my ($self, $opt, $plugin, $search) = @_;

  if (defined $opt->{name}) {
    return 1 if ($plugin->{name} =~ /$search/i);
  }

  if (defined $opt->{description} && $plugin->{cpran}) {
    if (defined $plugin->{'remote'}) {
      return 1 if ($plugin->{'remote'}->{description}->{long} =~ /$search/i);
      return 1 if ($plugin->{'remote'}->{description}->{short} =~ /$search/i);
    }
    if (defined $plugin->{'local'}) {
      return 1 if ($plugin->{'local'}->{description}->{long} =~ /$search/i);
      return 1 if ($plugin->{'local'}->{description}->{short} =~ /$search/i);
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
  carp "No output table found" unless defined $self->{output};
  my @row = $self->_make_output_row($opt, $plugin);
  $self->{output}->add(@row);
}

=item B<_make_output_row()>

Generates the appropriate line for a single plugin specified by name. Takes the
name as an argument, and returns a list suitable to be plugged into a
Text::Table object.

The output depends on the current options: if B<--installed> is enabled, the
returned list will have both the local and the remote versions.

=cut

sub _make_output_row {
  my ($self, $opt, $plugin) = @_;

  use YAML::XS;
  use File::Slurp;

  my $description;
  my $local = my $remote = '';

  if ($plugin->is_cpran) {
    if ($plugin->is_installed) {
      $local = $plugin->{'local'}->{version};
      $description = $plugin->{'local'}->{description}->{short};
    }
    if (defined $plugin->{remote}) {
      $remote = $plugin->{'remote'}->{version};
      $description = $plugin->{'remote'}->{description}->{short};
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

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
L<CPrAN::Command::install|install>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

1;
