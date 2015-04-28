package API::GitLab::Tiny;

use strict;
use warnings;

# use Params::Validate;
use Data::Dumper;
use Carp;

sub new {
  my $class = shift;
  my %args = @_;

  exists ($args{token}) or die;
  my $self = {};
  $self->{url}      = $args{url} // 'https://gitlab.com/api/v3/';
  $self->{token}    = $args{token};
  $self->{debug}    = $args{debug} // 0;
  $self->{encoding} = $args{encoding} // 'utf-8';
  bless $self, $class;
}

sub projects {
  my ($self, $params) = @_;

  my $url = $self->_build_url( ['projects'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub tags {
  my ($self, $id, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tags'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub tree {
  my ($self, $id, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tree'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub blob {
  use Encode qw(encode decode);
  my ($self, $id, $sha, $params) = @_;
  $self->_require(['filepath'], $params);

  my $url = $self->_build_url( ['projects', $id, 'repository', 'blobs', $sha], $params);
  return encode($self->{encoding}, $self->_get($url), Encode::FB_CROAK);
}

sub raw_blob {
  use Encode qw(encode decode);
  my ($self, $id, $sha, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'raw_blobs', $sha], $params);
  return encode($self->{encoding}, $self->_get($url), Encode::FB_CROAK);
}

sub file {
  my ($self, $id, $params) = @_;
  $self->_require(['file_path', 'ref'], $params);

  my $url = $self->_build_url( ['projects', $id, 'repository', 'files'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commits {
  my ($self, $id, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commit {
  my ($self, $id, $sha, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits', $sha], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commit_diff {
  my ($self, $id, $sha, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits', $sha, 'diff'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub commit_comments {
  my ($self, $id, $sha, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits', $sha, 'comments'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub archive {
  my ($self, $id, $params) = @_;

  my $url = $self->_build_url( ['projects', $id, 'repository', 'archive'], $params);
  return $self->_get($url);
}

sub groups {
  my ($self, $params) = @_;

  my $url = $self->_build_url( ['groups'], $params);
  return $self->_serialize( $self->_get($url) );
}

sub group {
  my ($self, $id, $params) = @_;

  my $url = $self->_build_url( ['groups', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

sub _build_url {
  use URI;
  use URI::QueryParam;

  my ($self, $members, $params) = @_;

  $params->{private_token} = $self->{token};

  my $url = URI->new($self->{url});
  $url = URI->new_abs(join('/', @{$members}), $url);
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});

  print STDERR "GET " . $url . "\n" if $self->{debug};
  return $url;
}

sub _serialize {
  require YAML::XS;

  my ($self, $content) = @_;
  my $obj;
  eval {
    $obj = YAML::XS::Load( $content );
  };
  if ($@) {
    croak "Could not parse: $@\n";
  }

  return $obj;
}

sub _get {
  require LWP::UserAgent;
  my ($self, $url) = @_;

  my $ua = LWP::UserAgent->new;

  my $response = $ua->get($url);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    croak $response->status_line;
  }
}

sub _require {
  my ($self, $need, $have) = @_;
  foreach (@{$need}) {
    exists $have->{$_} or croak "No " . $_ . "provided";
  }
}

1;
