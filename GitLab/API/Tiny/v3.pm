package GitLab::API::Tiny::v3;

use strict;
use warnings;

use Params::Validate qw(:all);
use Carp;

=head1 NAME

GitLab::API::Tiny::v3 - A (tiny) and (eventually) complete GitLab API v3 client.

=head1 SYNOPSIS

    use GitLab::API::Tiny::v3;
    my $api = GitLab::API::Tiny::v3->new(
      url => $v3_api_url,
      token => $token,
    );
    my $branches = $api->branches( $project_id );

=head1 DESCRIPTION

This module tries to provide the most lightweight interface to the GitLab API
possible. A great deal of inspiration has been taken from GitLab::API::v3, as is
apparent from this module's name, so the interface should be the same in both.

All C<GET> requests are done using LWP::UserAgent, and a failed request of any
kind will cause a call to C<confess>. You might want to try and catch these on
your own with C<Try::Tiny>.

For more detail, check the GitLab documentation, or the documentation of GitLab::API::v3.

=head2 LOGGING

This module's constructor accepts one optional C<debug> argument that prints the
request URL prior to the actual request being sent. This is I<all> the logging
you'll get from this module.

=cut

=head1 REQUIRED ARGUMENTS

=head2 url

The URL to your v3 API endpoint. Typically this will be something
like C<http://git.example.com/api/v3>. It defaults to C<https://gitlab.com/api/v3/>. I guess that makes this an optional argument?

=head2 token

A GitLab API token.

=head1 OPTIONAL ARGUMENTS

=head2 debug

A boolean to enable printing the request URLs before calling them. Off by default.

=head2 encoding

Specify the encoding for the methods that require it. Defaults to C<utf-8>.

=cut

sub new {
  my $class = shift;
   bless { validate( @_, {
    token    => { type => SCALAR },
    url      => { type => SCALAR,  default => 'https://gitlab.com/api/v3/' },
    debug    => { type => BOOLEAN, default => 0 },
    encoding => { type => SCALAR,  default => 'utf-8' },
  } ) }, $class;
}

=head1 USER METHODS

See L<http://doc.gitlab.com/ce/api/users.html>.

=head2 users

    my $users = $api->users(
      \%params,
    );

Sends a C<GET> request to C</users> and returns the decoded/deserialized response body.

=cut

sub users {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 user

    $api->user(
      $user_id,
    );

Sends a C<GET> request to C</users/:user_id>.

=cut

sub user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_user

    $api->create_user(
      \%params,
    );

Sends a C<POST> request to C</users>.

=cut

sub create_user {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users'], $params);
  $self->_post($url);
}

=head2 edit_user

    $api->edit_user(
      $user_id,
      \%params,
    );

Sends a C<PUT> request to C</users/:user_id>.

=cut

sub edit_user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users', $id], $params);
  $self->_put($url);
}

=head2 delete_user

    my $user = $api->delete_user(
      $user_id,
    );

Sends a C<DELETE> request to C</users/:user_id> and returns the decoded/deserialized response body.

=cut

sub delete_user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users', $id], $params);
  $self->_delete($url);
}

=head2 current_user

    my $user = $api->current_user();

Sends a C<GET> request to C</user> and returns the decoded/deserialized response body.

=cut

sub current_user {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['user'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 current_user_ssh_keys

    my $keys = $api->current_user_ssh_keys();

Sends a C<GET> request to C</user/keys> and returns the decoded/deserialized response body.

=cut

sub current_user_ssh_keys {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['user', 'keys'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 user_ssh_keys

    my $keys = $api->user_ssh_keys(
      $user_id,
    );

Sends a C<GET> request to C</users/:user_id/keys> and returns the decoded/deserialized response body.

=cut

sub user_ssh_keys {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users', $id, 'keys'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 user_ssh_key

    my $key = $api->user_ssh_key(
      $key_id,
    );

Sends a C<GET> request to C</user/keys/:key_id> and returns the decoded/deserialized response body.

=cut

sub user_ssh_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['user', 'keys', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_current_user_ssh_key

    $api->create_current_user_ssh_key(
      \%params,
    );

Sends a C<POST> request to C</user/keys>.

=cut

sub create_current_user_ssh_key {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['user', 'keys'], $params);
  $self->_post($url);
}

=head2 create_user_ssh_key

    $api->create_user_ssh_key(
      $user_id,
      \%params,
    );

Sends a C<POST> request to C</users/:user_id/keys>.

=cut

sub create_user_ssh_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR},
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users', $id, 'keys'], $params);
  $self->_post($url);
}

=head2 delete_current_user_ssh_key

    $api->delete_current_user_ssh_key(
      $key_id,
    );

Sends a C<DELETE> request to C</user/keys/:key_id>.

=cut

sub delete_current_user_ssh_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR},
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['user', 'keys', $id], $params);
  $self->_delete($url);
}

=head2 delete_user_ssh_key

    $api->delete_user_ssh_key(
      $user_id,
      $key_id,
    );

Sends a C<DELETE> request to C</users/:user_id/keys/:key_id>.

=cut

sub delete_user_ssh_key {
  my $self = shift;

  my ($uid, $kid, $params) = validate_pos( @_,
    { type => SCALAR},
    { type => SCALAR},
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['users', $uid, 'keys', $kid], $params);
  $self->_delete($url);
}

=head1 SESSION METHODS

See L<http://doc.gitlab.com/ce/api/session.html>.

=head2 session

    $api->session(
      \%params,
    );

Sends a C<POST> request to C</session>.

=cut

sub session {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['session'], $params);
  $self->_post($url);
}

=head1 PROJECT METHODS

See L<http://doc.gitlab.com/ce/api/projects.html>.

=head2 projects

    my $projects = $api->projects(
      \%params,
    );

Sends a C<GET> request to C</projects> and returns the decoded/deserialized response body.

=cut

sub projects {
  my $self = shift;
  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 owned_projects

    my $projects = $api->owned_projects();

Sends a C<GET> request to C</projects/owned> and returns the decoded/deserialized response body.

=cut

sub owned_projects {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', 'owned'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 all_projects

    my $projects = $api->all_projects();

Sends a C<GET> request to C</projects/all> and returns the decoded/deserialized response body.

=cut

sub all_projects {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', 'all'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 project

    my $project = $api->project(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id> and returns the decoded/deserialized response body.

=cut

sub project {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 project_events

    my $events = $api->project_events(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/events> and returns the decoded/deserialized response body.

=cut

sub project_events {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'events'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_project

    my $project = $api->create_project(
      \%params,
    );

Sends a C<POST> request to C</projects> and returns the decoded/deserialized response body.

=cut

sub create_project {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects'], $params);
  $self->_post($url);
}

=head2 create_project_for_user

    $api->create_project_for_user(
      $user_id,
      \%params,
    );

Sends a C<POST> request to C</projects/user/:user_id>.

=cut

sub create_project_for_user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', 'user', $id], $params);
  $self->_post($url);
}

=head2 fork_project

    $api->fork_project(
      $project_id,
    );

Sends a C<POST> request to C</pojects/fork/:project_id>.

=cut

sub fork_project {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', 'fork', $id], $params);
  $self->_post($url);
}

=head2 delete_project

    $api->delete_project(
      $project_id,
    );

Sends a C<DELETE> request to C</projects/:project_id>.

=cut

sub delete_project {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id], $params);
  $self->_delete($url);
}

=head2 project_members

    my $members = $api->project_members(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/members> and returns the decoded/deserialized response body.

=cut

sub project_members {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'members'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 project_member

    my $member = $api->project_member(
      $project_id,
      $user_id,
    );

Sends a C<GET> request to C</project/:project_id/members/:user_id> and returns the decoded/deserialized response body.

=cut

sub project_member {
  my $self = shift;

  my ($pid, $uid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'members', $uid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 add_project_member

    $api->add_project_member(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/members>.

=cut

sub add_project_member {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'members'], $params);
  $self->_post($url);
}

=head2 edit_project_member

    $api->edit_project_member(
      $project_id,
      $user_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/members/:user_id>.

=cut

sub edit_project_member {
  my $self = shift;

  my ($pid, $uid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'members', $uid], $params);
  $self->_put($url);
}

=head2 remove_project_member

    $api->remove_project_member(
      $project_id,
      $user_id,
    );

Sends a C<DELETE> request to C</projects/:project_id/members/:user_id>.

=cut

sub remove_project_member {
  my $self = shift;

  my ($pid, $uid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'members', $uid], $params);
  $self->_delete($url);
}

=head2 project_hooks

    my $hooks = $api->project_hooks(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/hooks> and returns the decoded/deserialized response body.

=cut

sub project_hooks {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'hooks'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 project_hook

    my $hook = $api->project_hook(
      $project_id,
      $hook_id,
    );

Sends a C<GET> request to C</project/:project_id/hooks/:hook_id> and returns the decoded/deserialized response body.

=cut

sub project_hook {
  my $self = shift;

  my ($pid, $hid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'hooks', $hid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_project_hook

    $api->create_project_hook(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/hooks>.

=cut

sub create_project_hook {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'hooks'], $params);
  $self->_post($url);
}

=head2 edit_project_hook

    $api->edit_project_hook(
      $project_id,
      $hook_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/hooks/:hook_id>.

=cut

sub edit_project_hook {
  my $self = shift;

  my ($pid, $hid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'hooks', $hid], $params);
  $self->_put($url);
}

# =head2 delete_project_hook
# 
#     my $hook = $api->delete_project_hook(
#       $project_id,
#       $hook_id,
#     );
# 
# Sends a C<DELETE> request to C</projects/:project_id/hooks/:hook_id> and returns the decoded/deserialized response body.
# 
# =cut

sub delete_project_hook {
  my $self = shift;

  my ($pid, $hid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'hooks', $hid], $params);
  $self->_delete($url);
}

=head2 set_project_fork

    $api->set_project_fork(
      $project_id,
      $forked_from_id,
    );

Sends a C<POST> request to C</projects/:project_id/fork/:forked_from_id>.

=cut

sub set_project_fork {
  my $self = shift;

  my ($pid, $fid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'fork', $fid], $params);
  $self->_post($url);
}

=head2 clear_project_fork

    $api->clear_project_fork(
      $project_id,
    );

Sends a C<DELETE> request to C</projects/:project_id/fork>.

=cut

sub clear_project_fork {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'fork'], $params);
  $self->_delete($url);
}

=head2 search_projects_by_name

    my $projects = $api->search_projects_by_name(
      $query,
      \%params,
    );

Sends a C<GET> request to C</projects/search/:query> and returns the decoded/deserialized response body.

=cut

sub search_projects_by_name {
  my $self = shift;

  my ($query, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', 'search', $query], $params);
  return $self->_serialize( $self->_get($url) );
}

=head1 SNIPPET METHODS

See L<http://doc.gitlab.com/ce/api/project_snippets.html>.

=head2 snippets

    my $snippets = $api->snippets(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/snippets> and returns the decoded/deserialized response body.

=cut

sub snippets {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'snippets'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 snippet

    my $snippet = $api->snippet(
      $project_id,
      $snippet_id,
    );

Sends a C<GET> request to C</projects/:project_id/snippets/:snippet_id> and returns the decoded/deserialized response body.

=cut

sub snippet {
  my $self = shift;

  my ($pid, $sid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'snippets', $sid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_snippet

    $api->create_snippet(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/snippets>.

=cut

sub create_snippet {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'snippets'], $params);
  $self->_post($url);
}

=head2 edit_snippet

    $api->edit_snippet(
      $project_id,
      $snippet_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/snippets/:snippet_id>.

=cut

sub edit_snippet {
  my $self = shift;

  my ($pid, $sid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'snippets', $sid], $params);
  $self->_put($url);
}

=head2 delete_snippet

    $api->delete_snippet(
      $project_id,
      $snippet_id,
    );

Sends a C<DELETE> request to C</projects/:project_id/snippets/:snippet_id>.

=cut

sub delete_snippet {
  my $self = shift;

  my ($pid, $sid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'snippets', $sid], $params);
  $self->_delete($url);
}

=head2 raw_snippet

    my $content = $api->raw_snippet(
      $project_id,
      $snippet_id,
    );

Sends a C<GET> request to C</projects/:project_id/snippets/:snippet_id/raw> and returns the decoded/deserialized response body.

=cut

sub raw_snippet {
  my $self = shift;

  my ($pid, $sid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'snippets', $sid, 'raw'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head1 REPOSITORY METHODS

See L<http://doc.gitlab.com/ce/api/repositories.html>.

=head2 tags

    my $tags = $api->tags(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/repository/tags> and returns the decoded/deserialized response body.

=cut

sub tags {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tags'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_tag

    $api->create_tag(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/repository/tags>.

=cut

sub create_tag {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tags'], $params);
  $self->_post($url);
}

=head2 tree

    my $tree = $api->tree(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/tree> and returns the decoded/deserialized response body.

=cut

sub tree {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'tree'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 blob

    my $blob = $api->blob(
      $project_id,
      $ref,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/blobs/:ref> and returns the decoded/deserialized response body.

=cut

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

=head2 raw_blob

    my $raw_blob = $api->raw_blob(
      $project_id,
      $blob_sha,
    );

Sends a C<GET> request to C</projects/:project_id/repository/raw_blobs/:blob_sha> and returns the decoded/deserialized response body.

=cut

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

=head2 archive

    my $archive = $api->archive(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/archive> and returns the decoded/deserialized response body.

=cut

sub archive {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'archive'], $params);
  return $self->_get($url);
}

=head2 compare

    my $comparison = $api->compare(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/compare> and returns the decoded/deserialized response body.

=cut

sub compare {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'compare'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 contributors

    my $contributors = $api->contributors(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/repository/contributors> and returns the decoded/deserialized response body.

=cut

sub contributors {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'contributors'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head1 FILE METHODS

See L<http://doc.gitlab.com/ce/api/repository_files.html>.

=head2 file

    my $file = $api->file(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/files> and returns the decoded/deserialized response body.

=cut

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

=head2 create_file

    $api->create_file(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/repository/files>.

=cut

sub create_file {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'files'], $params);
  $self->_post($url);
}

=head2 edit_file

    $api->edit_file(
      $project_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/repository/files>.

=cut

sub edit_file {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'files'], $params);
  $self->_put($url);
}

=head2 delete_file

    $api->delete_file(
      $project_id,
      \%params,
    );

Sends a C<DELETE> request to C</projects/:project_id/repository/files>.

=cut

sub delete_file {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'files'], $params);
  $self->_delete($url);
}

=head1 COMMIT METHODS

See L<http://doc.gitlab.com/ce/api/commits.html>.

=head2 commits

    my $commits = $api->commits(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/commits> and returns the decoded/deserialized response body.

=cut

sub commits {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1}
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'commits'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 commit

    my $commit = $api->commit(
      $project_id,
      $commit_sha,
    );

Sends a C<GET> request to C</projects/:project_id/repository/commits/:commit_sha> and returns the decoded/deserialized response body.

=cut

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

=head2 commit_diff

    my $diff = $api->commit_diff(
      $project_id,
      $commit_sha,
    );

Sends a C<GET> request to C</projects/:project_id/repository/commits/:commit_sha/diff> and returns the decoded/deserialized response body.

=cut

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

=head2 commit_comments

    my $comments = $api->commit_comments(
      $project_id,
      $commit_sha,
    );

Sends a C<GET> request to C</projects/:project_id/repository/commits/:commit_sha/comments> and returns the decoded/deserialized response body.

=cut

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

=head2 add_commit_comment

    $api->add_commit_comment(
      $project_id,
      $commit_sha,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/repository/commits/:commit_sha/comments>.

=cut

sub add_commit_comment {
  my $self = shift;

  my ($pid, $cid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'repository', 'commit', $cid, 'comments'], $params);
  $self->_post($url);
}

=head1 BRANCH METHODS

See L<http://doc.gitlab.com/ce/api/branches.html>.

=head2 branches

    my $branches = $api->branches(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/repository/branches> and returns the decoded/deserialized response body.

=cut

sub branches {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'branches'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 branch

    my $branch = $api->branch(
      $project_id,
      $branch_name,
    );

Sends a C<GET> request to C</projects/:project_id/repository/branches/:branch_name> and returns the decoded/deserialized response body.

=cut

sub branch {
  my $self = shift;

  my ($id, $branch, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'branches', $branch], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 protect_branch

    $api->protect_branch(
      $project_id,
      $branch_name,
    );

Sends a C<PUT> request to C</projects/:project_id/repository/branches/:branch_name/protect>.

=cut

sub protect_branch {
  my $self = shift;

  my ($pid, $branch, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'repository', 'branches', $branch, 'protect'], $params);
  $self->_put($url);
}

=head2 unprotect_branch

    $api->unprotect_branch(
      $project_id,
      $branch_name,
    );

Sends a C<PUT> request to C</projects/:project_id/repository/branches/:branch_name/unprotect>.

=cut

sub unprotect_branch {
  my $self = shift;

  my ($pid, $branch, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'repository', 'branches', $branch, 'unprotect'], $params);
  $self->_put($url);
}

=head2 create_branch

    my $branch = $api->create_branch(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/repository/branches> and returns the decoded/deserialized response body.

=cut

sub create_branch {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'branches'], $params);
  $self->_put($url);
}

=head2 delete_branch

    $api->delete_branch(
      $project_id,
      $branch_name,
    );

Sends a C<DELETE> request to C</projects/:project_id/repository/branches/:branch_name>.

=cut

sub delete_branch {
  my $self = shift;

  my ($id, $branch, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'repository', 'branches', $branch], $params);
  $self->_delete($url);
}

=head1 MERGE REQUEST METHODS

See L<http://doc.gitlab.com/ce/api/merge_requests.html>.

=head2 merge_requests

    my $merge_requests = $api->merge_requests(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/merge_requests> and returns the decoded/deserialized response body.

=cut

sub merge_requests {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'merge_requests'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 merge_request

    my $merge_request = $api->merge_request(
      $project_id,
      $merge_request_id,
    );

Sends a C<GET> request to C</projects/:project_id/merge_request/:merge_request_id> and returns the decoded/deserialized response body.

=cut

sub merge_request {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'merge_request', $mid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_merge_request

    my $merge_request = $api->create_merge_request(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/merge_requests> and returns the decoded/deserialized response body.

=cut

sub create_merge_request {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'merge_requests'], $params);
  $self->_post($url);
}

=head2 edit_merge_request

    my $merge_request = $api->edit_merge_request(
      $project_id,
      $merge_request_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/merge_requests/:merge_request_id> and returns the decoded/deserialized response body.

=cut

sub edit_merge_request {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'merge_requests', $mid], $params);
  $self->_put($url);
}

=head2 accept_merge_request

    $api->accept_merge_request(
      $project_id,
      $merge_request_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/merge_requests/:merge_request_id/merge>.

=cut

sub accept_merge_request {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'merge_requests', $mid, 'merge'], $params);
  $self->_put($url);
}

=head2 add_merge_request_comment

    $api->add_merge_request_comment(
      $project_id,
      $merge_request_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/merge_requests/:merge_request_id/comments>.

=cut

sub add_merge_request_comment {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'merge_requests', $mid, 'comments'], $params);
  $self->_post($url);
}

=head2 merge_request_comments

    my $comments = $api->merge_request_comments(
      $project_id,
      $merge_request_id,
    );

Sends a C<GET> request to C</projects/:project_id/merge_requests/:merge_request_id/comments> and returns the decoded/deserialized response body.

=cut

sub merge_request_comments {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'merge_request', $mid, 'comments'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head1 ISSUE METHODS

See L<http://doc.gitlab.com/ce/api/issues.html>.

=head2 all_issues

    my $issues = $api->all_issues(
      \%params,
    );

Sends a C<GET> request to C</issues> and returns the decoded/deserialized response body.

=cut

sub all_issues {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['issues'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 issues

    my $issues = $api->issues(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/issues> and returns the decoded/deserialized response body.

=cut

sub issues {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'issues'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 issue

    my $issue = $api->issue(
      $project_id,
      $issue_id,
    );

Sends a C<GET> request to C</projects/:project_id/issues/:issue_id> and returns the decoded/deserialized response body.

=cut

sub issue {
  my $self = shift;

  my ($pid, $iid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'issues', $iid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_issue

    my $issue = $api->create_issue(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/issues> and returns the decoded/deserialized response body.

=cut

sub create_issue {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'issues'], $params);
  $self->_post($url);
}

=head2 edit_issue

    my $issue = $api->edit_issue(
      $project_id,
      $issue_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/issues/:issue_id> and returns the decoded/deserialized response body.

=cut

sub edit_issue {
  my $self = shift;

  my ($pid, $iid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'issues', $iid], $params);
  $self->_put($url);
}

=head1 LABEL METHODS

See L<http://doc.gitlab.com/ce/api/labels.html>.

=head2 labels

    my $labels = $api->labels(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/labels> and returns the decoded/deserialized response body.

=cut

sub labels {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'labels'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_label

    my $label = $api->create_label(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/labels> and returns the decoded/deserialized response body.

=cut

sub create_label {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'labels'], $params);
  $self->_post($url);
}

=head2 delete_label

    $api->delete_label(
      $project_id,
      \%params,
    );

Sends a C<DELETE> request to C</projects/:project_id/labels>.

=cut

sub delete_label {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'labels'], $params);
  $self->_delete($url);
}

=head2 edit_label

    my $label = $api->edit_label(
      $project_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/labels> and returns the decoded/deserialized response body.

=cut

sub edit_label {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'labels'], $params);
  $self->_put($url);
}

=head1 MILESTONE METHODS

See L<http://doc.gitlab.com/ce/api/milestones.html>.

=head2 milestones

    my $milestones = $api->milestones(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/milestones> and returns the decoded/deserialized response body.

=cut

sub milestones {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'milestones'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 milestone

    my $milestone = $api->milestone(
      $project_id,
      $milestone_id,
    );

Sends a C<GET> request to C</projects/:project_id/milestones/:milestone_id> and returns the decoded/deserialized response body.

=cut

sub milestone {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'milestones', $mid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_milestone

    $api->create_milestone(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/milestones>.

=cut

sub create_milestone {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'milestones'], $params);
  $self->_post($url);
}

=head2 edit_milestone

    $api->edit_milestone(
      $project_id,
      $milestone_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/milestones/:milestone_id>.

=cut

sub edit_milestone {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'milestones', $mid], $params);
  $self->_put($url);
}

=head1 NOTE METHODS

See L<http://doc.gitlab.com/ce/api/notes.html>.

=head2 notes

    my $notes = $api->notes(
      $project_id,
      $note_type,
      $merge_request_id,
    );

Sends a C<GET> request to C</projects/:project_id/:note_type/:merge_request_id/notes> and returns the decoded/deserialized response body.

=cut

sub notes {
  my $self = shift;

  my ($pid, $type, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, $type, $mid, 'notes'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 note

    my $note = $api->note(
      $project_id,
      $note_type,
      $merge_request_id,
      $note_id,
    );

Sends a C<GET> request to C</projects/:project_id/:note_type/:merge_request_id/notes/:note_id> and returns the decoded/deserialized response body.

=cut

sub note {
  my $self = shift;

  my ($pid, $type, $mid, $nid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, $type, $mid, 'notes', $nid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_note

    $api->create_note(
      $project_id,
      $note_type,
      $merge_request_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/:note_type/:merge_request_id/notes>.

=cut

sub create_note {
  my $self = shift;

  my ($pid, $type, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, $type, $mid, 'notes'], $params);
  $self->_post($url);
}

=head1 DEPLOY KEY METHODS

See L<http://doc.gitlab.com/ce/api/deploy_keys.html>.

=head2 deploy_keys

    my $keys = $api->deploy_keys(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/keys> and returns the decoded/deserialized response body.

=cut

sub deploy_keys {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'keys'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 deploy_key

    my $key = $api->deploy_key(
      $project_id,
      $key_id,
    );

Sends a C<GET> request to C</projects/:project_id/keys/:key_id> and returns the decoded/deserialized response body.

=cut

sub deploy_key {
  my $self = shift;

  my ($pid, $kid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $pid, 'keys', $kid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_deploy_key

    $api->create_deploy_key(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/keys>.

=cut

sub create_deploy_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'keys'], $params);
  $self->_post($url);
}

=head2 delete_deploy_key

    $api->delete_deploy_key(
      $project_id,
      $key_id,
    );

Sends a C<DELETE> request to C</projects/:project_id/keys/:key_id>.

=cut

sub delete_deploy_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'keys'], $params);
  $self->_delete($url);
}

=head1 SYSTEM HOOK METHODS

See L<http://doc.gitlab.com/ce/api/system_hooks.html>.

=head2 hooks

    my $hooks = $api->hooks();

Sends a C<GET> request to C</hooks> and returns the decoded/deserialized response body.

=cut

sub hooks {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['hooks'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_hook

    $api->create_hook(
      \%params,
    );

Sends a C<POST> request to C</hooks>.

=cut

sub create_hook {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['hooks'], $params);
  $self->_post($url);
}

=head2 test_hook

    my $hook = $api->test_hook(
      $hook_id,
    );

Sends a C<GET> request to C</hooks/:hook_id> and returns the decoded/deserialized response body.

=cut

sub test_hook {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['hooks', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 delete_hook

    $api->delete_hook(
      $hook_id,
    );

Sends a C<DELETE> request to C</hooks/:hook_id>.

=cut

sub delete_hook {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['hooks', $id], $params);
  $self->_delete($url);
}

=head1 GROUP METHODS

See L<http://doc.gitlab.com/ce/api/groups.html>.

=head2 groups

    my $groups = $api->groups();

Sends a C<GET> request to C</groups> and returns the decoded/deserialized response body.

=cut

sub groups {
  my $self = shift;

  my ($params) = validate_pos( @_, 
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 group

    my $group = $api->group(
      $group_id,
    );

Sends a C<GET> request to C</groups/:group_id> and returns the decoded/deserialized response body.

=cut

sub group {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_group

    $api->create_group(
      \%params,
    );

Sends a C<POST> request to C</groups>.

=cut

sub create_group {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups'], $params);
  $self->_post($url);
}

=head2 transfer_project

    $api->transfer_project(
      $group_id,
      $project_id,
    );

Sends a C<POST> request to C</groups/:group_id/projects/:project_id>.

=cut

sub transfer_project {
  my $self = shift;

  my ($gid, $pid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $gid, 'projects', $pid], $params);
  $self->_post($url);
}

=head2 delete_group

    $api->delete_group(
      $group_id,
    );

Sends a C<DELETE> request to C</groups/:group_id>.

=cut

sub delete_group {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $id], $params);
  $self->_delete($url);
}

=head2 group_members

    my $members = $api->group_members(
      $group_id,
    );

Sends a C<GET> request to C</groups/:group_id/members> and returns the decoded/deserialized response body.

=cut

sub group_members {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $id, 'members'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 add_group_member

    $api->add_group_member(
      $group_id,
      \%params,
    );

Sends a C<POST> request to C</groups/:group_id/members>.

=cut

sub add_group_member {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $id, 'members'], $params);
  $self->_post($url);
}

=head2 remove_group_member

    $api->remove_group_member(
      $group_id,
      $user_id,
    );

Sends a C<DELETE> request to C</groups/:group_id/members/:user_id>.

=cut

sub remove_group_member {
  my $self = shift;

  my ($gid, $uid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['groups', $gid, 'members', $uid], $params);
  $self->_delete($url);
}

=head1 SERVICE METHODS

See L<http://doc.gitlab.com/ce/api/services.html>.

=head2 edit_project_service

    $api->edit_project_service(
      $project_id,
      $service_name,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/services/:service_name>.

=cut

sub edit_project_service {
  my $self = shift;

  my ($id, $service, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'services', $service], $params);
  $self->_put($url);
}

=head2 delete_project_service

    $api->delete_project_service(
      $project_id,
      $service_name,
    );

Sends a C<DELETE> request to C</projects/:project_id/services/:service_name>.

=cut

sub delete_project_service {
  my $self = shift;

  my ($id, $service, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, optional => 1 }
  );

  my $url = $self->_build_url( ['projects', $id, 'services', $service], $params);
  $self->_delete($url);
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

  my $obj;
  eval {
    $obj = YAML::XS::Load( $content );
  };
  confess "Could not parse" if $@;

  return $obj;
}

# HACK(jja) These can be made smarter

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
    croak $response->status_line;
  }
}

sub _delete {
  my $self = shift;

  my ($url) = validate_pos( @_,
    { type => SCALAR | SCALARREF }
  );

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->delete($url);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    confess $response->status_line;
  }
}

sub _put {
  my $self = shift;

  my ($url, $form) = validate_pos( @_,
    { type => SCALAR | SCALARREF },
    { type => HASHREF | ARRAYREF } # Does HTTP::Request::Common accept anything else?
  );

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->put($url, $form);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    confess $response->status_line;
  }
}

sub _post {
  my $self = shift;

  my ($url, $form) = validate_pos( @_,
    { type => SCALAR | SCALARREF },
    { type => HASHREF | ARRAYREF } # Does HTTP::Request::Common accept anything else?
  );

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->post($url, $form);
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

__END__

=head1 SEE ALSO

L<GitLab::API::v3>

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
