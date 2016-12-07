package CPrAN::Plugin;
# ABSTRACT: A representation of a Praat plugin

use Moose;

extends 'Praat::Plugin';

use Types::Praat qw( Version );
use Types::Path::Tiny qw( Path );
use Types::Standard qw( Bool Undef );

has cpran => (
  is => 'rw',
  isa => Path|Undef,
  coerce => 1,
);

has url => (
  is => 'rw',
);

has [qw( version latest requested )] => (
  is => 'rw',
  isa => Version|Undef,
  coerce => 1,
);

has '+latest' => (
  lazy => 1,
  default => sub { $_[0]->_remote->{version} },
);

has '+version' => (
  lazy => 1,
  default => sub { $_[0]->_local->{version} },
);

has '+requested' => (
  lazy => 1,
  default => sub { $_[0]->latest },
);

has [qw( _remote _local )] => (
  is => 'rw',
  isa => 'HashRef',
  lazy => 1,
  default => sub { {} },
);

has [qw( is_cpran )] => (
  is => 'rw',
  isa => 'Bool',
  lazy => 1,
  default => 0,
);

around BUILDARGS => sub {
  my $orig = shift;
  my $self = shift;

  my $args = $self->$orig(@_);

  if (defined $args->{meta}) {
    if (ref $args->{meta} eq 'HASH') {
      $args->{name} = $args->{meta}->{name};
      $args->{id}   = $args->{meta}->{id};
      $args->{url}  = $args->{meta}->{http_url_to_repo};
    }
    else {
      # Treat as an unserialised plugin descriptor
      my $meta = $self->_parse_meta($args->{meta});

      if (defined $meta) {
        $args->{name} = $meta->{plugin};
        $args->{_remote} = $meta;
      }
    }
    delete $args->{meta};
  }

  if ($args->{name} =~ /:/) {
    my ($n, $v) = split /:/, $args->{name};
    $args->{name} = $n;
    $args->{requested} = $v unless $v eq 'latest';
  }

  $args->{name} =~ s/^plugin_([\w\d]+)/$1/;

  return $args;
};

sub refresh {
  my ($self) = @_;

  if (defined $self->root) {
    my $local = $self->root->child('cpran.yaml');
    $self->_local( $self->parse_meta( $local->slurp )) if $local->exists;
  }
  $self->version($self->_local->{version}) if defined $self->_local;

  if (defined $self->cpran) {
    my $remote = $self->cpran->child( $self->name );
    $self->_remote( $self->parse_meta( $remote->slurp )) if $remote->exists;
  }
  $self->latest($self->_remote->{version}) if defined $self->_remote;

  return $self;
}

sub is_latest {
  my ($self) = @_;

  return undef unless scalar keys %{$self->_remote};
  return 0     unless scalar keys %{$self->_local};

  $self->refresh;
  return ($self->version >= $self->latest) ? 1 : 0;
}

sub remove {
  my $self = shift;
  my $opt = (@_) ? (@_ > 1) ? { @_ } : shift : {};

  return undef unless defined $self->root;
  return 0     unless         $self->root->exists;

  $self->root->remove_tree({
    verbose => $opt->{verbose},
    safe => 0,
    error => \my $e
  });

  if (@{$e}) {
    Carp::carp 'Could not completely remove ', $self->root, "\n"
      unless $self->cpran->quiet;

    foreach (@{$e}) {
      my ($file, $message) = %{$_};
        if ($file eq '') {
        warn "General error: $message\n";
      }
      else {
        warn "Problem unlinking $file: $message\n";
      }
    }
    return 0;
  }
  else {
    return 1;
  }
}

=item print(I<FIELD>)

Prints the contents of the plugin descriptors, either local or remote. These
must be asked for by name. Any other names are an error.

=cut

sub print {
  use Encode qw( decode );

  my ($self, $name) = @_;
  $name = '_' . $name;

  die "Not a valid field"
    unless $name =~ /^_(local|remote)$/;

  die "No descriptor found"
    unless defined $self->$name;

  print decode('utf8',
    $self->$name->{meta}
  );
}

sub parse_meta {
  my ($self, $meta) = @_;

  my $parsed = $self->_parse_meta($meta);

  $self->is_cpran(1) if $parsed;
  return $parsed;
}

sub _parse_meta {
  my ($class, $meta) = @_;

  require YAML::XS;
  require Encode;

  use Syntax::Keyword::Try;
  my $parsed;
  try {
    $parsed = YAML::XS::Load( Encode::encode_utf8( $meta ));
  }
  catch {
    if (!ref($class) and !$class->cpran->quiet) {
      Carp::carp 'Could not deserialise meta: ', $meta;
    }
  }

  return unless defined $parsed and ref $parsed eq 'HASH';

  _force_lc_hash($parsed);

  $parsed->{meta} = $meta;
  $parsed->{name} = $parsed->{plugin};

  if (ref $parsed->{version} ne 'Praat::Version') {
    try {
      require Praat::Version;
      $parsed->{version} = Praat::Version->new($parsed->{version})
    }
    catch {
      if (!ref($class) or !$class->cpran->quiet) {
        Carp::carp 'Not a valid version number: ', $parsed->{version};
      }
    }
  }

  return $parsed;
}

sub _force_lc_hash {
  my $hashref = shift;
  if (ref $hashref eq 'HASH') {
    foreach my $key (keys %{$hashref} ) {
      $hashref->{lc($key)} = $hashref->{$key};
      _force_lc_hash($hashref->{lc($key)}) if ref $hashref->{$key} eq 'HASH';
      delete($hashref->{$key}) unless $key eq lc($key);
    }
  }
}

# =back
#
# =head1 AUTHOR
#
# José Joaquín Atria <jjatria@gmail.com>
#
# =head1 LICENSE
#
# Copyright 2015-2016 José Joaquín Atria
#
# This module is free software; you may redistribute it and/or modify it under
# the same terms as Perl itself.
#
# =head1 SEE ALSO
#
# L<CPrAN|cpran>,
# L<CPrAN::Command::deps|deps>,
# L<CPrAN::Command::init|init>,
# L<CPrAN::Command::install|install>,
# L<CPrAN::Command::list|list>,
# L<CPrAN::Command::remove|remove>,
# L<CPrAN::Command::search|search>,
# L<CPrAN::Command::show|show>,
# L<CPrAN::Command::test|test>,
# L<CPrAN::Command::refresh|refresh>,
# L<CPrAN::Command::upgrade|upgrade>
#
# =cut
#
# # VERSION

1;
