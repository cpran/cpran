package CPrAN::Command::deps;
# ABSTRACT: list the dependencies of plugins

our $VERSION = '0.0412'; # VERSION

use Moose;
use Log::Any qw( $log );
# use Log::Any::Adapter 'Stderr';

with 'CPrAN::Role::Reads::WorkingPlugin';
with 'CPrAN::Role::Reads::STDIN';

extends qw( MooseX::App::Cmd::Command );

=head1 NAME

=encoding utf8

B<deps> - List the dependencies of CPrAN plugins

=head1 SYNOPSIS

cpran deps [options] [arguments]

=head1 DESCRIPTION

This command checks the dependencies of the specified plugins and returns them
in an ordered list, such as can be used in an installation schedule. While
the internally returned list contains all plugins in the dependency tree,
all but the topmost element are printed to STDOUT, so that the aggregated
list of I<dependencies> is what is printed.

The results of this command can be piped into e.g. C<cpran install> to prepare
things for the installation of the plugins passed as arguments.

=cut

=pod

Arguments to B<deps> must be at least one and optionally more plugin names.
Plugin names can be appended with a specific version number to request for
versioned queries, but this is not currently implemented. When it is, names
will likely be of the form C<name-1.0.0>.

If no arguments are passed, these can be read from STDIN. In this case, the
B<--yes> flag is set, since no user interaction is possible.

=cut

=head1 EXAMPLES

    # List the dependencies of a plugin
    cpran deps basicplugin
    # List the aggregated dependencies of multiple plugins
    cpran deps basicplugin complexplugin
    # Reinstall all dependencies for a plugin
    cpran deps plugin | cpran install --reinstall

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  # Make a list of CPrAN plugins from input, if they are not already

  my @plugins = map {
    require CPrAN::Plugin;
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { $self->app->new_plugin( $_ ) }
  } @{$args};

  # Get a source dependency tree for the plugins to be installed.
  @plugins = $self->get_dependencies( $opt, @plugins );

  # Sort dependency tree from fewer to more dependencies
  # Duplicates are automatically removed
  my ($sorted, $top) = $self->order_dependencies( @plugins );

  # Do not print the top nodes of the dependency tree if printing
  unless ($self->app->quiet) {
    print $_->name, "\n" foreach @{$sorted};
  }

  # But the return value includes all plugins, not just dependencies
  return (@{$sorted}, @{$top});
}

=head1 OPTIONS

=over

=back

=cut


=head1 METHODS

=over

=cut

=item get_dependencies

Query the desired plugins for dependencies.

Takes either the name of a single plugin, or a list of names, and returns
an array of hashes properly formatted for processing with order_dependencies()

=cut

sub get_dependencies {
  my ($self, $opt, @args) = @_;

  my @plugins = map {
    require CPrAN::Plugin;
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { $self->app->new_plugin( $_ ) }
  } @args;

  my @dependencies = ();
  foreach my $plugin (@plugins) {
    $log->trace("Working on", $plugin->name);

    my $deps = $plugin->_remote;
    $deps = $plugin->_local unless scalar keys %{$deps};
    $deps = $deps->{depends}->{plugins};

    if (defined $deps and ref $deps eq 'HASH') {
      my %raw = %{$deps};

      foreach my $key (keys %raw) {
        $plugin->{reqname} = [ keys %raw   ];
        $plugin->{reqver}  = [ values %raw ];
        push @dependencies, $plugin;
      }

      # Recursively query dependencies for all dependencies
      @dependencies = (
        @dependencies,
        $self->get_dependencies($opt, keys %raw)
      );
    }

    else {
      $plugin->{reqname} = [];
      $plugin->{reqver}  = [];
      push @dependencies, $plugin;
    }
  }

  return @dependencies;
}

=item order_dependencies

Order required packages, so that those that are depended upon come up first than
those that depend on them.

The argument is an array of hashes, each of which needs a "name" key that
identifies the item, and a "reqname" holding the reference to an array with
the names of the items that are required. See dependencies() for a method to
generate such an array.

Closely modeled after http://stackoverflow.com/a/12166653/807650

=cut

sub order_dependencies {
  use Graph 0.96 qw();

  my $self = shift;

  my %recs;
  my $graph = Graph->new;
  foreach my $rec (@_) {
    my ($name, $reqname) = @{$rec}{qw( name reqname )};

    $graph->add_vertex($name);
    foreach (@{$reqname}) {
      $graph->add_edge($_, $name);
    }

    $recs{$name} = $rec;
  }

  my (@sorted, @top);
  foreach ($graph->topological_sort) {
    delete $recs{$_}->{reqname};
    delete $recs{$_}->{reqver};

    if ($graph->out_degree($_)) {

      push @sorted, $recs{$_};
    }
    else {
      push @top, $recs{$_};
    }
  }

  return \@sorted, \@top;
}

=back

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2016 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPrAN|cpran>,
L<CPrAN::Plugin|plugin>,
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

__PACKAGE__->meta->make_immutable;
no Moose;

1;
