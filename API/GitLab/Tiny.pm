package API::GitLab::Tiny;

use strict;
use warnings;

use LWP::Simple;
use Data::Dumper;
use YAML::XS;
use MIME::Base64;
use URI;
use URI::QueryParam;

sub new {
  my $class = shift;
  my %args = @_;

  exists ($args{token}) or die;
  my $self = {};
  $self->{url}   = $args{api} // 'https://gitlab.com/api/v3/';
  $self->{token} = $args{token};
  bless $self, $class;
}

sub projects {
  my ($self, $params) = @_;
  my $url = URI->new($self->{url} . '/projects');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub tags {
  my ($self, $project_id, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/tags');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub tree {
  my ($self, $project_id, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/tree');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub blob {
  my ($self, $project_id, $sha, $params) = @_;
  exists $params->{filepath} or die "No filepath provided";

  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/blobs/' . $sha);
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return LWP::Simple::get($url);
}

sub raw_blob {
  my ($self, $project_id, $sha, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/raw_blobs/' . $sha);
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return LWP::Simple::get($url);
}

sub file {
  my ($self, $project_id, $params) = @_;
  exists $params->{'file_path'} or die "No file_path provided";
  exists $params->{'ref'} or die "No ref provided";

  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/files');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub commits {
  my ($self, $project_id, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/commits');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub commit {
  my ($self, $project_id, $params) = @_;
  exists $params->{'sha'} or die "No ref provided";

  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/commits/' . $params->{sha});
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub commit_diff {
  my ($self, $project_id, $sha, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/commits/' . $sha . '/diff');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub commit_comments {
  my ($self, $project_id, $sha, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/commits/' . $sha . '/comments');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url) );
}

sub archive {
  my ($self, $project_id, $params) = @_;
  my $url = URI->new($self->{url} . '/projects/' . $project_id . '/repository/archive');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return LWP::Simple::get($url);
}

sub groups {
  my ($self, $params) = @_;
  my $url = URI->new($self->{url} . '/groups');
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url));
}

sub group {
  my ($self, $group_id, $params) = @_;
  my $url = URI->new($self->{url} . '/groups/' . $group_id);
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});
  $url->query_param_append('private_token', $self->{token});
  return YAML::XS::Load( LWP::Simple::get($url));
}

1;
