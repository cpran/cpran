package CPrAN::Command::remove;
# ABSTRACT: delete installed plugins from disk

use Moose;
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';

require Carp;

has [qw(
  force cautious
)] => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
);

has '+force' => (
  documentation => 'attempt to work around errors',
  lazy => 1,
  default => undef,
);

has '+cautious' => (
  documentation => 'be extra-careful while removing files',
  lazy => 1,
  default => undef,
);

=head1 NAME

=encoding utf8

B<remove> - Remove installed CPrAN plugins

=head1 SYNOPSIS

cpran remove [options] [arguments]

=head1 DESCRIPTION

Deletes a CPrAN plugin that has been installed.

=cut

=pod

Arguments to B<remove> must be at least one and optionally more plugin names to
remove. For each named passed as argument, all contents of the directory named
"plugin_<name>" (and the directory itself) will be removed from disk.

=cut

=head1 EXAMPLES

    # Remove some plugins
    cpran remove oneplugin otherplugin
    # Do not ask for confirmation
    cpran remove -y oneplugin

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  if (scalar @{$args} == 1 and $args->[0] eq '-') {
    while (<STDIN>) {
      chomp;
      push @{$args}, $_;
    }
    shift @{$args};
  }

#   if (grep { /\bpraat\b/i } @{$args}) {
#     if (scalar @{$args} > 1) {
#       die "Praat must be the only argument for processing\n";
#     }
#     else {
#       return $self->_praat($opt);
#     }
#   }

  use Path::Class;
  use CPrAN::Plugin;

  my @plugins = map {
    CPrAN::Plugin->new( name => $_, cpran => $self->app ) unless ref $_;
  } @{$args};

  my @todo;
  foreach my $plugin (@plugins) {
    if ($plugin->is_installed) {
      if ($plugin->is_cpran || $self->force) {
        warn $plugin->name, ' is not a CPrAN plugin, but processing anyway.', "\n"
          if !$plugin->is_cpran and !$self->app->quiet;
        push @todo, $plugin;
      }
      else {
        warn $plugin->name, ' is not a CPrAN plugin. Use --force to process anyway.', "\n"
          unless $self->app->quiet;
      }
    }
    else {
      warn 'Plugin ', $plugin->name, ' is not installed; cannot remove', "\n"
        unless $self->app->quiet;
    }
  }

  my $retval = 1;
  if (@todo) {

    my @names;
    unless ($self->app->quiet) {
      print "The following plugins will be REMOVED:\n";
      print '  ', join(' ', map { $_->name } @todo ), "\n";
      print "Do you want to continue?";
    }

    if ($self->app->_yesno('y')) {
      foreach my $plugin (@todo) {
        print 'Removing ', $plugin->name, '...', "\n"
          unless $self->app->quiet;

        $retval = $plugin->remove(
          verbose => $self->app->verbose,
          safe => $self->cautious,
        );
      }
    }
    else {
      print 'Abort.', "\n" unless $self->app->quiet;
    }

  }
  return $retval;
}

sub _praat {
  my ($self, $opt) = @_;

  my $praat = $self->app->praat;

  unless (defined $praat->current) {
    warn "Praat is not installed. Use 'cpran install praat' to install it\n";
    return undef;
  }

  unless ($self->app->quiet) {
    print "Praat will be permanently REMOVED:\n";
    print "Do you want to continue?";
  }

  if ($self->_yesno('y')) {
    $praat->remove;

    print 'Done.', "\n" unless $self->app->quiet;
    return 1;
  }
  else {
    print 'Abort.', "\n" unless $self->app->quiet;
    return 0;
  }
}

=head1 OPTIONS

=over

=item B<--force>

Tries to work around problems.

=item B<--cautious>

=back

=cut

=head1 METHODS

=over

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
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
