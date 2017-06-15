package CPrAN::Command::remove;
# ABSTRACT: delete installed plugins from disk

# VERSION

use Moose;
use Log::Any qw( $log );

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';
with 'CPrAN::Role::Processes::Praat';
with 'CPrAN::Role::Reads::STDIN';

require Carp;

has force => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
  documentation => 'attempt to work around errors',
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

  my @plugins = map {
    if (ref $_ eq 'CPrAN::Plugin') { $_ }
    else { $self->app->new_plugin( $_ ) }
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
      my $n = scalar @todo;
      use Lingua::EN::Inflexion;

      print inflect("<#d:$n>The following <N:plugin> will be REMOVED:"), "\n";
      print '  ', join(' ', map { $_->name } @todo ), "\n";
      print "Do you want to continue?";
    }

    if ($self->app->_yesno('y')) {
      foreach my $plugin (@todo) {
        print 'Removing ', $plugin->name, '...', "\n"
          unless $self->app->quiet;

        $retval = $plugin->remove(
          verbose => $self->app->verbose,
        );
      }
    }
    else {
      print 'Abort.', "\n" unless $self->app->quiet;
    }

  }
  return $retval;
}

sub process_praat {
  my ($self, $opt) = @_;

  my $praat = $self->app->praat;

  unless (defined $praat->version) {
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

__PACKAGE__->meta->make_immutable;
no Moose;

1;
