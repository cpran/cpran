package CPrAN::Command::list;
# ABSTRACT: list all available plugins

use Moose;
use Log::Any qw( $log );
use uni::perl;

extends qw( MooseX::App::Cmd::Command );

with 'MooseX::Getopt';
with 'CPrAN::Role::Processes::Praat';
with 'CPrAN::Role::Reads::STDIN';

require Carp;

has [qw(
  installed wrap
)] => (
  is  => 'rw',
  isa => 'Bool',
  traits => [qw(Getopt)],
);

has '+installed' => (
  documentation => 'search in installed plugins',
  cmd_aliases => 'i',
);

has '+wrap' => (
  documentation => 'wrap output table when printing',
  cmd_aliases => 'w',
  lazy => 1,
  default => 1,
);

sub execute {
  my ($self, $opt, $args) = @_;

  $log->debug('Executing list');

  return $self->app->run_command( search => '.*', {
    installed => $self->installed,
    wrap      => $self->wrap,
  });
}

sub process_praat {
  my ($self) = @_;

  use Syntax::Keyword::Try;
  try {
    foreach (@{$self->app->praat->releases}) {
      print $_->{semver}, "\n";
    }
  }
  catch {
    $log->warn($@);
    die 'Could not list Praat releases', "\n";
  }
}

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
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::update|update>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

__PACKAGE__->meta->make_immutable;
no Moose;

1;
