package API::GitLab::Tiny;

use strict;
use warnings;

use Params::Validate qw(:all);
use Carp;

sub new {
  my $class = shift;
   bless { validate( @_, {
    token    => { type => SCALAR },
    url      => { type => SCALAR,  default => 'https://gitlab.com/api/v3/' },
    debug    => { type => BOOLEAN, default => 0 },
    encoding => { type => SCALAR,  default => 'utf-8' },
  } ) }, $class;
}

sub projects {
  my $self = shift;
  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub tags {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tags'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub tree {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tree'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub blob {
  my $self = shift;

  my ($id, $sha, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  use Encode qw(encode decode);

  $self->_require(['filepath'], $params);

  my $url = $self->_build_url( ['projects', $id, 'repository', 'blobs', $sha], $params);
  return encode($self->{encoding}, $self->_get($url), Encode::FB_CROAK);
}

sub raw_blob {
  my $self = shift;

  my ($id, $sha, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  use Encode qw(encode decode);

  my $url = $self->_build_url( ['projects', $id, 'repository', 'raw_blobs', $sha], $params);
  return encode($self->{encoding}, $self->_get($url), Encode::FB_CROAK);
}

sub file {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  $self->_require(['file_path', 'ref'], $params);

  my $url = $self->_build_url( ['projects', $id, 'repository', 'files'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commits {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1}
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commit {
  my $self = shift;

  my ($id, $sha, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits', $sha], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commit_diff {
  my $self = shift;

  my ($id, $sha, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits', $sha, 'diff'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commit_comments {
  my $self = shift;

  my ($id, $sha, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits', $sha, 'comments'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub archive {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'archive'], $params);
  return $self->_get($url);
}

sub groups {
  my $self = shift;

  my ($params) = validate_pos( @_, 
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub group {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

sub _build_url {
  my $self = shift;

  my ($members, $params) = validate_pos( @_,
    { type => ARRAYREF },
    { type => HASHREF | UNDEF, optional => 1 }
  );

  use URI;
  use URI::QueryParam;

  $params->{private_token} = $self->{token};

  my $url = URI->new($self->{url});
  $url = URI->new_abs(join('/', @{$members}), $url);
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});

  print STDERR "GET " . $url . "\n" if $self->{debug};
  return $url;
}

sub _serialize {
  my $self = shift;

  my ($content) = validate_pos( @_,
    { type => SCALAR }
  );

  require YAML::XS;
  require Try::Tiny;

  my $obj;
  try {
    $obj = YAML::XS::Load( $content );
  }
  catch {
    confess "Could not parse: $_\n";
  }

  return $obj;
}

sub _get {
  my $self = shift;

  my ($url) = validate_pos( @_,
    { type => SCALAR | SCALARREF }
  );

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->get($url);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    confess $response->status_line;
  }
}

sub _require {
  my $self = shift;

  my ($need, $have) = validate_pos( @_,
    { type => ARRAYREF },
    { type => HASHREF }
  );

  foreach (@{$need}) {
    exists $have->{$_} or confess "No " . $_ . "provided";
  }
}

1;
