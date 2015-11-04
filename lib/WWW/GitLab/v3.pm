package WWW::GitLab::v3;

use strict;
use warnings;

use Params::Validate qw(:all);
use Carp;

=head1 NAME

WWW::GitLab::v3 - A lightweight and complete GitLab API v3 interface.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::GitLab::v3;
    my $api = WWW::GitLab::v3->new(
      url   => $v3_api_url,
      token => $token,
    );
    my $branches = $api->branches( $project_id );

=head1 EXPORT

WWW::GitLab::v3 exports nothing.

=head1 DESCRIPTION

This module tries to provide the most lightweight interface to the GitLab API
possible.

The interface is modelled after GitLab::API::v3, and in most cases the two
modules should be interchangeable. The biggest difference is probably in the
parameter validation and the return value of some methods: while GitLab::API::v3
claims to closely follow the return values specified in the specs of the API, there are cases in which this is not strictly the case, and other cases in which
requests to the API do return values, even when the spec is vague.

When a request is sent to the GitLab API, WWW::GitLab::v3 captures the response
and attempts to read it as JSON (except when files or archives are requested).
When the serialization is successful, the serialized data is returned. When it
isn't (or when it is not applicable) the return value is whatever was received 
from the API.

All requests are done using LWP::UserAgent, and a failed request of any
kind will cause a call to C<croak>. You might want to try and catch these on
your own with C<Try::Tiny>.

Much of this documentation has been borrowed from that of GitLab::API::v3, but
changes have been made where differences exist (so prefer this one when dealing
with this module). For more detail, check the GitLab documentation.

=head2 LOGGING

This module's constructor accepts one optional C<debug> argument that prints the
request URL prior to the actual request being sent. This is all the logging
you'll get from this module.

=cut

=head1 REQUIRED ARGUMENTS

=head2 url

The URL to your v3 API endpoint. Typically this will be something like
C<http://git.example.com/api/v3>.

=head1 CREDENTIALS

The WWW::GitLab::v3 constructor expects some way to authenticate, and will
croak unless this is provided, or possible to obtain. The way this is
implemented is with a private token for the authenticated user, which gets
passed with the various requests to the API.

If this token is not passed to the constructor together with the API url, then
the constructor will expect a valid user email or login name, and their
password. Any of these combinations is accepted.

=head2 token

A GitLab API token.

=head2 login

A GitLab user login name, needed if no token is provided.

=head2 email

A GitLab user email, needed if no login is provided.

=head2 password

A GitLab user password, needed if no token is provided.

=head1 OPTIONAL ARGUMENTS

=head2 debug

A boolean to enable printing the request URLs before calling them. Off by 
default. If set, the requests will be printed to STDERR.

=cut

sub new {
  my $class = shift;
  my %self = validate( @_, {
    token    => { type => SCALAR, optional => 1 },
    email    => { type => SCALAR, optional => 1 },
    login    => { type => SCALAR, optional => 1 },
    password => { type => SCALAR, optional => 1 },
    url      => { type => SCALAR },
    debug    => { type => BOOLEAN, default => 0 },
    encoding => { type => SCALAR,  default => 'utf-8' },
  } );

  if (!defined $self{token}) {
    if (defined $self{password}) {
      my $session;
      my $api = WWW::GitLab::v3->new( { url => $self{url} } );
      if (defined $self{email}) {
        $session = $api->session({
          email    => $self{email},
          password => $self{password}
        });
      }
      elsif (defined $self{login}) {
        $session = $api->session({
          login    => $self{login},
          password => $self{password}
        });
      }
      else {
        croak "Need credentials to connect to API: provide token or login details";
      }
      $self{token} = $session->{private_token};
      # NOTE(jja) Should we keep the password saved?
      delete $self{password};
    }
    else {
      croak "Need credentials to connect to API: provide token or login details";
    }
  }
  bless \%self, $class;
}

=head1 USER METHODS

See L<http://doc.gitlab.com/ce/api/users.html>.

=head2 users

    my $users = $api->users(
      \%params,
    );

Sends a C<GET> request to C</users> and returns the decoded/deserialized response body. Possible parameters are:

=over 4

=item C<page>=NUMBER (optional)

=item C<per_page>=NUMBER (optional)

=item C<search>=EMAIL,USERNAME (optional)

=back

=cut

sub users {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    page     => { type => SCALAR, optional => 1 },
    per_page => { type => SCALAR, optional => 1 },
    search   => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['users'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 user

    my $user = $api->user(
      $user_id,
    );

Sends a C<GET> request to C</users/:user_id> and returns the
decoded/deserialized response body.

=cut

sub user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['users', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_user

    $api->create_user(
      \%params,
    );

Sends a C<POST> request to C</users>. This method requires admin rights.
Possible parameters are:

=over 4

=item C<email> (required)

=item C<username> (required)

=item C<password> (required)

=item C<name> (required)

=item C<password> (optional)

=item C<skype> (optional)

=item C<linkedin> (optional)

=item C<twitter> (optional)

=item C<website_url> (optional)

=item C<projects_limit> (optional)

=item C<extern_uid> (optional)

=item C<provider> (optional)

=item C<bio> (optional)

=item C<admin>=TRUE,FALSE (optional)

=item C<can_create_groups>=TRUE,FALSE (optional)

=back

=cut

sub create_user {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    email             => { type => SCALAR },
    username          => { type => SCALAR },
    password          => { type => SCALAR },
    name              => { type => SCALAR },
    skype             => { type => SCALAR, optional => 1 },
    linkedin          => { type => SCALAR, optional => 1 },
    twitter           => { type => SCALAR, optional => 1 },
    website_url       => { type => SCALAR, optional => 1 },
    projects_limit    => { type => SCALAR, optional => 1 },
    extern_uid        => { type => SCALAR, optional => 1 },
    provider          => { type => SCALAR, optional => 1 },
    bio               => { type => SCALAR, optional => 1 },
    admin             => { type => SCALAR, optional => 1 },
    can_create_groups => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['users'], { private_token => $self->{token} });
  return $self->_serialize( $self->_post($url, $params) );
}

=head2 edit_user

    $api->edit_user(
      $user_id,
      \%params,
    );

Sends a C<PUT> request to C</users/:user_id>. This method requires admin rights.
Possible parameters are the same as those for C<create_user>, but all are
optional.

=cut

sub edit_user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    email             => { type => SCALAR, optional => 1 },
    username          => { type => SCALAR, optional => 1 },
    password          => { type => SCALAR, optional => 1 },
    name              => { type => SCALAR, optional => 1 },
    skype             => { type => SCALAR, optional => 1 },
    linkedin          => { type => SCALAR, optional => 1 },
    twitter           => { type => SCALAR, optional => 1 },
    website_url       => { type => SCALAR, optional => 1 },
    projects_limit    => { type => SCALAR, optional => 1 },
    extern_uid        => { type => SCALAR, optional => 1 },
    provider          => { type => SCALAR, optional => 1 },
    bio               => { type => SCALAR, optional => 1 },
    admin             => { type => SCALAR, optional => 1 },
    can_create_groups => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['users', $id], $params);
  return $self->_serialize( $self->_put($url) );
}

=head2 delete_user

    my $user = $api->delete_user(
      $user_id,
    );

Sends a C<DELETE> request to C</users/:user_id> and returns the serialised 
deleted user on success.

=cut

sub delete_user {
  my $self = shift;

  my ($id) = validate_pos( @_,
    { type => SCALAR },
  );

  my $url = $self->build_url( ['users', $id], {});
  return $self->_serialize( $self->_delete($url) );
}

=head2 current_user

    my $user = $api->current_user();

Sends a C<GET> request to C</user> and returns the decoded/deserialized response body.

=cut

sub current_user {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['user'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 current_user_ssh_keys

    my $keys = $api->current_user_ssh_keys();

Sends a C<GET> request to C</user/keys> and returns the decoded/deserialized response body.

=cut

sub current_user_ssh_keys {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['user', 'keys'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['users', $id, 'keys'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['user', 'keys', $id], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_current_user_ssh_key

    my $created_key = $api->create_current_user_ssh_key(
      \%params,
    );

Sends a C<POST> request to C</user/keys> and returns the decoded/deserialized response body. Possible parameters are:

=over 4

=item C<title> (required)

=item C<key> (required)

=back

=cut

sub create_current_user_ssh_key {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    title => { type => SCALAR },
    key   => { type => SCALAR },
  });

  my $url = $self->build_url( ['user', 'keys'], { private_token => $self->{token} });
  return $self->_serialize( $self->_post($url, $params) );
}

=head2 create_user_ssh_key

    $api->create_user_ssh_key(
      $user_id,
      \%params,
    );

Sends a C<POST> request to C</users/:user_id/keys>. This method requires admin 
rights. Possible parameters are the same as those for
C<create_current_user_ssh_key>.

=cut

sub create_user_ssh_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR},
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    title => { type => SCALAR },
    key   => { type => SCALAR },
  });

  my $url = $self->build_url( ['users', $id, 'keys'], $params);
  $self->_post($url);
}

=head2 delete_current_user_ssh_key

    my $deleted_key = $api->delete_current_user_ssh_key(
      $key_id,
    );

Sends a C<DELETE> request to C</user/keys/:key_id> and returns the decoded/deserialized response body. This mehod requires admin rights.

=cut

sub delete_current_user_ssh_key {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR},
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['user', 'keys', $id], $params);
  return $self->_serialize( $self->_delete($url) );
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['users', $uid, 'keys', $kid], $params);
  $self->_delete($url);
}

=head1 SESSION METHODS

See L<http://doc.gitlab.com/ce/api/session.html>.

=head2 session

    my $authenticated_user = $api->session(
      \%params,
    );

Sends a C<POST> request to C</session> and returns the decoded/deserialized 
response body. Possible optional parameters are:

=over 4

=item I<login> (required)

=item I<email> (required if C<login> not provided)

=item I<password> (required)

=back

=cut

sub session {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );
  # TODO(jja) Figure out optional parameters
  confess "No password provided" unless defined $params->{password};
  confess "No email or login provided"
    unless defined($params->{email}) || defined($params->{login});

  my $url = $self->build_url( ['session'], {});
  return $self->_serialize( $self->_post($url, $params) );
}

=head1 PROJECT METHODS

See L<http://doc.gitlab.com/ce/api/projects.html>.

=head2 projects

    my $projects = $api->projects(
      \%params,
    );

Sends a C<GET> request to C</projects> and returns the decoded/deserialized response body. Possible optional parameters are:

=over 4

=item I<archived>=TRUE,FALSE

=item I<order_by>=C<id>, C<name>, C<path>, C<created_at>, C<updated_at>,
C<last_activity_at>

=item I<sort>=C<asc>,C<desc>

=item I<search>=C<asc>,C<desc>

=back

=cut

sub projects {
  my $self = shift;
  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 owned_projects

    my $projects = $api->owned_projects(
      \%params,
    );

Sends a C<GET> request to C</projects/owned> and returns the decoded/deserialized response body. Possible optional parameters are the same as for C<projects()>:

=cut

sub owned_projects {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  validate(@params, {
      archived => { type => SCALAR, optional => 1 },
      order_by => { type => SCALAR, optional => 1 },
      sort     => { type => SCALAR, optional => 1 },
      search   => { type => SCALAR, optional => 1 },
    }
  );

  my $url = $self->build_url( ['projects', 'owned'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 all_projects

    my $projects = $api->all_projects();

Sends a C<GET> request to C</projects/all> and returns the decoded/deserialized response body. Possible optional parameters are the same as for C<projects()>:

=cut

sub all_projects {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', 'all'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'events'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_project

    my $project = $api->create_project(
      \%params,
    );

Sends a C<POST> request to C</projects> and returns the decoded/deserialized response body. Possible parameters are:

=over 4

=item I<name> (required)

=item I<path> (optional)

=item I<namespace_id> (optional)

=item I<issues_enabled> (optional)

=item I<merge_requests_enabled> (optional)

=item I<wiki_enabled> (optional)

=item I<snippets_enabled> (optional)

=item I<public> (optional)

=item I<visibility_level> (optional)

=item I<import_url> (optional)

=back

=cut

sub create_project {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
      name                   => { type => SCALAR },
      path                   => { type => SCALAR, optional => 1 },
      namespace_id           => { type => SCALAR, optional => 1 },
      description            => { type => SCALAR, optional => 1 },
      issues_enabled         => { type => SCALAR, optional => 1 },
      merge_requests_enabled => { type => SCALAR, optional => 1 },
      wiki_enabled           => { type => SCALAR, optional => 1 },
      snippets_enabled       => { type => SCALAR, optional => 1 },
      public                 => { type => SCALAR, optional => 1 },
      visibility_level       => { type => SCALAR, optional => 1 },
      import_url             => { type => SCALAR, optional => 1 },
    }
  );

  my $url = $self->build_url( ['projects'], { private_token => $self->{token} });
  return $self->_serialize( $self->_post($url, $params) );
}

=head2 create_project_for_user

    $api->create_project_for_user(
      $user_id,
      \%params,
    );

Sends a C<POST> request to C</projects/user/:user_id>. This method requires admin 
rights. Possible parameters are the same as for C<create_project()>.

=cut

sub create_project_for_user {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
      name                   => { type => SCALAR },
      path                   => { type => SCALAR, optional => 1 },
      namespace_id           => { type => SCALAR, optional => 1 },
      description            => { type => SCALAR, optional => 1 },
      issues_enabled         => { type => SCALAR, optional => 1 },
      default_branch         => { type => SCALAR, optional => 1 },
      merge_requests_enabled => { type => SCALAR, optional => 1 },
      wiki_enabled           => { type => SCALAR, optional => 1 },
      snippets_enabled       => { type => SCALAR, optional => 1 },
      public                 => { type => SCALAR, optional => 1 },
      visibility_level       => { type => SCALAR, optional => 1 },
      import_url             => { type => SCALAR, optional => 1 },
    }
  );

  my $url = $self->build_url( ['projects', 'user', $id], $params);
  $self->_post($url);
}

=head2 edit_project

    my $edited_project = $api->edit_project(
      $project_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id> and returns the
decoded/deserialized response body. Possible parameters are the same as for
C<create_project()>, but all are optional.

=cut

sub edit_project {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
      name                   => { type => SCALAR, optional => 1 },
      path                   => { type => SCALAR, optional => 1 },
      namespace_id           => { type => SCALAR, optional => 1 },
      description            => { type => SCALAR, optional => 1 },
      default_branch         => { type => SCALAR, optional => 1 },
      issues_enabled         => { type => SCALAR, optional => 1 },
      merge_requests_enabled => { type => SCALAR, optional => 1 },
      wiki_enabled           => { type => SCALAR, optional => 1 },
      snippets_enabled       => { type => SCALAR, optional => 1 },
      public                 => { type => SCALAR, optional => 1 },
      visibility_level       => { type => SCALAR, optional => 1 },
      import_url             => { type => SCALAR, optional => 1 },
    }
  );

  my $url = $self->build_url( ['projects', $id], {});
  return $self->_serialize( $self->_put($url, $params) );
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', 'fork', $id], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id], $params);
  $self->_delete($url);
}

=head2 project_members

    my $members = $api->project_members(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/members> and returns the decoded/deserialized response body. Possible optional parameters are:

=over 4

=item C<query>

=back

=cut

sub project_members {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} },
  );

  my @params = %{$params};
  $params = validate( @params, {
    query => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['projects', $id, 'members'], $params);
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

  my ($pid, $uid) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'members', $uid], {});
  return $self->_serialize( $self->_get($url) );
}

=head2 add_project_member

    $api->add_project_member(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/members>. Possible parameters
are:

=over 4

=item C<user_id> (required)

=item C<access_level> (required)

=back

=cut

sub add_project_member {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate_pos( @params,
    user_id      => { type => SCALAR },
    access_level => { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'members'], $params);
  $self->_post($url);
}

=head2 edit_project_member

    $api->edit_project_member(
      $project_id,
      $user_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/members/:user_id>. Possible
parameters are the same as those for C<add_project_member>.

=cut

sub edit_project_member {
  my $self = shift;

  my ($pid, $uid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate_pos( @params,
    user_id      => { type => SCALAR },
    access_level => { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'members', $uid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'members', $uid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'hooks'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'hooks', $hid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_project_hook

    $api->create_project_hook(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/hooks>. Possible parameters
are:

=over 4

=item C<url> (required)

=item C<push_events> (optional)

=item C<issues_events> (optional)

=item C<merge_request_events> (optional)

=item C<tag_push_events> (optional)

=back

=cut

sub create_project_hook {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate( @params, {
    url                  => { type => SCALAR },
    push_events          => { type => SCALAR, optional => 1 },
    issues_events        => { type => SCALAR, optional => 1 },
    merge_request_events => { type => SCALAR, optional => 1 },
    tag_push_events      => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['projects', $id, 'hooks'], {});
  return $self->_serialize( $self->_post($url, $params) );
}

=head2 edit_project_hook

    $api->edit_project_hook(
      $project_id,
      $hook_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/hooks/:hook_id>. Possible
parameters are the same as those for C<create_project_hook>.

=cut

sub edit_project_hook {
  my $self = shift;

  my ($pid, $hid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate( @params, {
    url                  => { type => SCALAR },
    push_events          => { type => SCALAR, optional => 1 },
    issues_events        => { type => SCALAR, optional => 1 },
    merge_request_events => { type => SCALAR, optional => 1 },
    tag_push_events      => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['projects', $pid, 'hooks', $hid], {});
  return $self->_serialize( $self->_put($url, $params) );
}

=head2 delete_project_hook

    my $hook = $api->delete_project_hook(
      $project_id,
      $hook_id,
    );

Sends a C<DELETE> request to C</projects/:project_id/hooks/:hook_id> and returns the decoded/deserialized response body.

=cut

sub delete_project_hook {
  my $self = shift;

  my ($pid, $hid) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'hooks', $hid], {});
  return $self=>serialize( $self->_delete($url) );
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'fork', $fid], {});
  return $self->_serialize( $self->_post($url, $params) );
}

=head2 clear_project_fork

    $api->clear_project_fork(
      $project_id,
    );

Sends a C<DELETE> request to C</projects/:project_id/fork>.

=cut

sub clear_project_fork {
  my $self = shift;

  my ($id) = validate_pos( @_,
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'fork'], {});
  return $self->_serialize( $self->_delete($url) );
}

=head2 search_projects_by_name

    my $projects = $api->search_projects_by_name(
      $query,
      \%params,
    );

Sends a C<GET> request to C</projects/search/:query> and returns the
decoded/deserialized response body. Possible parameters are:

=over 4

=item C<query> (required)

=item C<per_page> (optional)

=item C<page> (optional)

=item C<order_by>=C<id>, C<name>, C<created_at>, C<last_activity_at> (optional)

=item C<sort>=C<asc>, C<desc> (optional)

=back

=cut

sub search_projects_by_name {
  my $self = shift;

  my ($query, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate( @params, {
    query    => { type => SCALAR },
    page     => { type => SCALAR, optional => 1 },
    per_page => { type => SCALAR, optional => 1 },
    order_by => { type => SCALAR, optional => 1 },
    sort     => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['projects', 'search', $query], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'snippets'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'snippets', $sid], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_snippet

    $api->create_snippet(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/snippets>. Returns the
created snippet, as serialized data. Possible parameters are:

=over 4

=item C<title> (required)

=item C<file_name> (required)

=item C<visibility_level> (required)

=item C<code> (required)

=back

Note that although the API spec specifies these parameters as optional, the
GitLab server will respond with a C<400 (Bad request)> error if any are missing.
The API spec doesn't even mention C<visibility_level> as a possibility.

=cut

sub create_snippet {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate( @params, {
    title            => { type => SCALAR },
    file_name        => { type => SCALAR },
    visibility_level => { type => SCALAR },
    code             => { type => SCALAR },
  });

  my $url = $self->build_url( ['projects', $id, 'snippets'], {});
  return $self->_serialize( $self->_post($url, $params) );
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'snippets', $sid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'snippets', $sid], $params);
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

  my ($pid, $sid) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'snippets', $sid, 'raw'], {});
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'tags'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'tags'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'tree'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 blob

    my $blob = $api->blob(
      $project_id,
      $commit_sha,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/blobs/:commit_sha>
and returns the decoded/deserialized response body. Only possible parameter is:

=over 4

=item C<filepath> (required)

=back

=cut

sub blob {
  my $self = shift;

  my ($id, $sha, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    filepath => { type => SCALAR },
  });

  my $url = $self->build_url( ['projects', $id, 'repository', 'blobs', $sha], $params);
  return $self->_get($url);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'raw_blobs', $sha], $params);
  return $self->_get($url);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'archive'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'compare'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'contributors'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head1 FILE METHODS

See L<http://doc.gitlab.com/ce/api/repository_files.html>.

=head2 file

    my $file = $api->file(
      $project_id,
      \%params,
    );

Sends a C<GET> request to C</projects/:project_id/repository/files> and returns the decoded/deserialized response body. Possible parameters are:

=over 4

=item C<file_path> (required)

=item C<ref> (required)

=back

=cut

sub file {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate(@params, {
    file_path => { type => SCALAR },
    ref       => { type => SCALAR },
  });

  my $url = $self->build_url( ['projects', $id, 'repository', 'files'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'files'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'files'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'files'], $params);
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
    { type => HASHREF, default => {}}
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'commits'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'commits', $sha], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'commits', $sha, 'diff'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 commit_comments

    my $comments = $api->commit_comments(
      $project_id,
      $commit_sha,
    );

Sends a C<GET> request to
C</projects/:project_id/repository/commits/:commit_sha/comments> and returns the 
decoded/deserialized response body.

=cut

sub commit_comments {
  my $self = shift;

  my ($id, $sha) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'commits', $sha, 'comments'], {});
  return $self->_serialize( $self->_get($url) );
}

=head2 add_commit_comment

    $api->add_commit_comment(
      $project_id,
      $commit_sha,
      \%params,
    );

Sends a C<POST> request to
C</projects/:project_id/repository/commits/:commit_sha/comments>. Possible
parameters are:

=over 4

=item C<note> (required)

=item C<path> (optional)

=item C<line> (optional)

=item C<line_type>=C<new>,C<old> (optional)

=back

=cut

sub add_commit_comment {
  my $self = shift;

  my ($pid, $cid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my @params = %{$params};
  $params = validate( @params, {
    note      => { type => SCALAR },
    path      => { type => SCALAR, optional => 1 },
    line      => { type => SCALAR, optional => 1 },
    line_type => { type => SCALAR, optional => 1 },
  });

  my $url = $self->build_url( ['projects', $pid, 'repository', 'commit', $cid, 'comments'], {});
  $self->_post($url, $params);
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

  my ($id) = validate_pos( @_,
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'branches'], {});
  return $self->_serialize( $self->_get($url) );
}

=head2 branch

    my $branch = $api->branch(
      $project_id,
      $branch_name,
    );

Sends a C<GET> request to
C</projects/:project_id/repository/branches/:branch_name> and returns the 
decoded/deserialized response body.

=cut

sub branch {
  my $self = shift;

  my ($id, $branch) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'branches', $branch], {});
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

  my ($pid, $branch) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'repository', 'branches', $branch, 'protect'], {});
  $self->_put($url, {});
}

=head2 unprotect_branch

    $api->unprotect_branch(
      $project_id,
      $branch_name,
    );

Sends a C<PUT> request to
C</projects/:project_id/repository/branches/:branch_name/unprotect>.

=cut

sub unprotect_branch {
  my $self = shift;

  my ($pid, $branch) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'repository', 'branches', $branch, 'unprotect'], {});
  $self->_put($url, {});
}

=head2 create_branch

    my $branch = $api->create_branch(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/repository/branches> and
returns the decoded/deserialized response body.

=cut

sub create_branch {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'branches'], {});
  $self->_serialize( $self->_put($url, $params) );
}

=head2 delete_branch

    $api->delete_branch(
      $project_id,
      $branch_name,
    );

Sends a C<DELETE> request to
C</projects/:project_id/repository/branches/:branch_name>.

=cut

sub delete_branch {
  my $self = shift;

  my ($id, $branch) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'repository', 'branches', $branch], {});
  $self->_delete($url);
}

=head1 MERGE REQUEST METHODS

See L<http://doc.gitlab.com/ce/api/merge_requests.html>.

=head2 merge_requests

    my $merge_requests = $api->merge_requests(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/merge_requests> and returns the 
decoded/deserialized response body.

=cut

sub merge_requests {
  my $self = shift;

  my ($id) = validate_pos( @_,
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $id, 'merge_requests'], {});
  return $self->_serialize( $self->_get($url) );
}

=head2 merge_request

    my $merge_request = $api->merge_request(
      $project_id,
      $merge_request_id,
    );

Sends a C<GET> request to 
C</projects/:project_id/merge_request/:merge_request_id> and returns the 
decoded/deserialized response body.

=cut

sub merge_request {
  my $self = shift;

  my ($pid, $mid) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'merge_request', $mid], {});
  return $self->_serialize( $self->_get($url) );
}

=head2 create_merge_request

    my $merge_request = $api->create_merge_request(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/merge_requests> and returns 
the decoded/deserialized response body.

=cut

sub create_merge_request {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'merge_requests'], $params);
  return $self->_serialize( $self->_post($url) );
}

=head2 edit_merge_request

    my $merge_request = $api->edit_merge_request(
      $project_id,
      $merge_request_id,
      \%params,
    );

Sends a C<PUT> request to 
C</projects/:project_id/merge_requests/:merge_request_id> and returns the 
decoded/deserialized response body.

=cut

sub edit_merge_request {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'merge_requests', $mid], {});
  return $self->_serialize( $self->_put($url, $params) );
}

=head2 accept_merge_request

    $api->accept_merge_request(
      $project_id,
      $merge_request_id,
      \%params,
    );

Sends a C<PUT> request to 
C</projects/:project_id/merge_requests/:merge_request_id/merge>.

=cut

sub accept_merge_request {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'merge_requests', $mid, 'merge'], {});
  $self->_put($url, $params);
}

=head2 add_merge_request_comment

    $api->add_merge_request_comment(
      $project_id,
      $merge_request_id,
      \%params,
    );

Sends a C<POST> request to 
C</projects/:project_id/merge_requests/:merge_request_id/comments>.

=cut

sub add_merge_request_comment {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'merge_requests', $mid, 'comments'], $params);
  $self->_post($url);
}

=head2 merge_request_comments

    my $comments = $api->merge_request_comments(
      $project_id,
      $merge_request_id,
    );

Sends a C<GET> request to
C</projects/:project_id/merge_requests/:merge_request_id/comments> and returns 
the decoded/deserialized response body.

=cut

sub merge_request_comments {
  my $self = shift;

  my ($pid, $mid) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, 'merge_request', $mid, 'comments'], {});
  return $self->_serialize( $self->_get($url) );
}

=head1 ISSUE METHODS

See L<http://doc.gitlab.com/ce/api/issues.html>.

=head2 all_issues

    my $issues = $api->all_issues(
      \%params,
    );

Sends a C<GET> request to C</issues> and returns the decoded/deserialized 
response body.

=cut

sub all_issues {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['issues'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'issues'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 issue

    my $issue = $api->issue(
      $project_id,
      $issue_id,
    );

Sends a C<GET> request to C</projects/:project_id/issues/:issue_id> and returns 
the decoded/deserialized response body.

=cut

sub issue {
  my $self = shift;

  my ($pid, $iid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'issues', $iid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'issues'], $params);
  return $self->_serialize( $self->_post($url) );
}

=head2 edit_issue

    my $issue = $api->edit_issue(
      $project_id,
      $issue_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/issues/:issue_id> and returns 
the decoded/deserialized response body.

=cut

sub edit_issue {
  my $self = shift;

  my ($pid, $iid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'issues', $iid], $params);
  return $self->_serialize( $self->_put($url) );
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'labels'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 create_label

    my $label = $api->create_label(
      $project_id,
      \%params,
    );

Sends a C<POST> request to C</projects/:project_id/labels> and returns the 
decoded/deserialized response body.

=cut

sub create_label {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'labels'], $params);
  return $self->_serialize( $self->_post($url) );
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'labels'], $params);
  $self->_delete($url);
}

=head2 edit_label

    my $label = $api->edit_label(
      $project_id,
      \%params,
    );

Sends a C<PUT> request to C</projects/:project_id/labels> and returns the
decoded/deserialized response body.

=cut

sub edit_label {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'labels'], $params);
  return $self->_serialize( $self->_put($url) );
}

=head1 MILESTONE METHODS

See L<http://doc.gitlab.com/ce/api/milestones.html>.

=head2 milestones

    my $milestones = $api->milestones(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/milestones> and returns the
decoded/deserialized response body.

=cut

sub milestones {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'milestones'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 milestone

    my $milestone = $api->milestone(
      $project_id,
      $milestone_id,
    );

Sends a C<GET> request to C</projects/:project_id/milestones/:milestone_id> and
returns the decoded/deserialized response body.

=cut

sub milestone {
  my $self = shift;

  my ($pid, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'milestones', $mid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'milestones'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'milestones', $mid], $params);
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

Sends a C<GET> request to 
C</projects/:project_id/:note_type/:merge_request_id/notes> and returns the
decoded/deserialized response body.

=cut

sub notes {
  my $self = shift;

  my ($pid, $type, $mid, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, $type, $mid, 'notes'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 note

    my $note = $api->note(
      $project_id,
      $note_type,
      $merge_request_id,
      $note_id,
    );

Sends a C<GET> request to
C</projects/:project_id/:note_type/:merge_request_id/notes/:note_id>
and returns the decoded/deserialized response body.

=cut

sub note {
  my $self = shift;

  my ($pid, $type, $mid, $nid) = validate_pos( @_,
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
    { type => SCALAR },
  );

  my $url = $self->build_url( ['projects', $pid, $type, $mid, 'notes', $nid], {});
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, $type, $mid, 'notes'], $params);
  $self->_post($url);
}

=head1 DEPLOY KEY METHODS

See L<http://doc.gitlab.com/ce/api/deploy_keys.html>.

=head2 deploy_keys

    my $keys = $api->deploy_keys(
      $project_id,
    );

Sends a C<GET> request to C</projects/:project_id/keys> and returns the
decoded/deserialized response body.

=cut

sub deploy_keys {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'keys'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $pid, 'keys', $kid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'keys'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'keys'], $params);
  $self->_delete($url);
}

=head1 SYSTEM HOOK METHODS

See L<http://doc.gitlab.com/ce/api/system_hooks.html>.

=head2 hooks

    my $hooks = $api->hooks();

Sends a C<GET> request to C</hooks> and returns the decoded/deserialized
response body.

=cut

sub hooks {
  my $self = shift;

  my ($params) = validate_pos( @_,
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['hooks'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['hooks'], $params);
  $self->_post($url);
}

=head2 test_hook

    my $hook = $api->test_hook(
      $hook_id,
    );

Sends a C<GET> request to C</hooks/:hook_id> and returns the 
decoded/deserialized response body.

=cut

sub test_hook {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['hooks', $id], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['hooks', $id], $params);
  $self->_delete($url);
}

=head1 GROUP METHODS

See L<http://doc.gitlab.com/ce/api/groups.html>.

=head2 groups

    my $groups = $api->groups();

Sends a C<GET> request to C</groups> and returns the decoded/deserialized
response body.

=cut

sub groups {
  my $self = shift;

  my ($params) = validate_pos( @_, 
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups'], $params);
  return $self->_serialize( $self->_get($url) );
}

=head2 group

    my $group = $api->group(
      $group_id,
    );

Sends a C<GET> request to C</groups/:group_id> and returns the
decoded/deserialized response body.

=cut

sub group {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups', $id], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups', $gid, 'projects', $pid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups', $id], $params);
  $self->_delete($url);
}

=head2 group_members

    my $members = $api->group_members(
      $group_id,
    );

Sends a C<GET> request to C</groups/:group_id/members> and returns the
decoded/deserialized response body.

=cut

sub group_members {
  my $self = shift;

  my ($id, $params) = validate_pos( @_,
    { type => SCALAR },
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups', $id, 'members'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups', $id, 'members'], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['groups', $gid, 'members', $uid], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'services', $service], $params);
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
    { type => HASHREF, default => {} }
  );

  my $url = $self->build_url( ['projects', $id, 'services', $service], $params);
  $self->_delete($url);
}

=head1 PRIVATE SUBROUTINES

The folowing subroutines are used by WWW::GitLab::v3 internally. Documentation
for these might disappear in the future, since nothing is expected to call these
other than WWW::GitLab::v3 itself.

=head2 build_url

    my $url = $api->build_url( \@members, \%params );

Generates a valid URI object from two arguments. The first is the reference to
an array of URI members, which will be passed to a URI constructor. The second
is a reference to a hash of values to be appended to the URI as parameters.

=cut

sub build_url {
  my $self = shift;

  my ($members, $params) = validate_pos( @_,
    { type => ARRAYREF },
    { type => HASHREF, default => {} },
  );

  use URI;
  use URI::QueryParam;

  $params->{private_token} = $self->{token};

  my $url = URI->new($self->{url});
  $url = URI->new_abs(join('/', @{$members}), $url);
  $url->query_param_append($_, $params->{$_}) foreach (keys %{$params});

  return $url;
}

=head2 _serialize

    my $yaml = $api->_serialize( $api->_get($url) );

Wrapper function to JSON::Tiny. The argument is safely passed to this module's
C<decode_json> function, and its result returned on success.

=cut

sub _serialize {
  my $self = shift;

  my ($content) = validate_pos( @_,
    { type => SCALAR }
  );

  use JSON::Tiny qw(decode_json);

  my $obj = undef;
  eval {
    local $JSON::Tiny::FALSE = 0;
    local $JSON::Tiny::TRUE = 1;
    $obj = decode_json( $content );
  };
  if (!defined $obj) {
    carp "Could not parse" if $self->{debug};
    return $content;
  }

  return $obj;
}

=head2 _get

    my $response = $api->_get( $url );

Performs a GET request on the provided URL using LWP::UserAgent. Returns the
response code on success.

=cut

# HACK(jja) These can be made smarter

sub _get {
  my $self = shift;

  my ($url) = validate_pos( @_,
    { type => SCALAR | SCALARREF }
  );

  print STDERR "GET " . $url . "\n" if $self->{debug};

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->get($url);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    croak $response->message;
  }
}

=head2 _delete

    my $response = $api->_delete( $url );

Performs a DELETE request on the provided URL using LWP::UserAgent. Returns the
response code on success.

=cut

sub _delete {
  my $self = shift;

  my ($url) = validate_pos( @_,
    { type => SCALAR | SCALARREF }
  );

  print STDERR "DELETE " . $url . "\n" if $self->{debug};

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->delete($url);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
    croak $response->message;
  }
}

=head2 _put

    my $response = $api->_put( $url, \%form );
    my $response = $api->_put( $url, \@form );

Performs a PUT request on the provided URL using LWP::UserAgent. The form
argument is passed as-is to HTTP::Request::Common.

Returns the response code on success.

=cut

sub _put {
  my $self = shift;

  my ($url, $form) = validate_pos( @_,
    { type => SCALAR | SCALARREF },
    { type => HASHREF | ARRAYREF } # What does HTTP::Request::Common accept?
  );

  print STDERR "PUT " . $url . "\n" if $self->{debug};
  if ($self->{debug} > 1) {
    use Data::Dumper;
    print Data::Dumper->Dump([ $form ], [ 'params' ]);
  }

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->put($url, $form);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
#     print Dumper($response);
    confess $response->message;
  }
}

=head2 _post

    my $response = $api->_post( $url, \%form );
    my $response = $api->_post( $url, \@form );

Performs a POST request on the provided URL using LWP::UserAgent. The form
argument is passed as-is to HTTP::Request::Common.

Returns the response code on success.

=cut

sub _post {
  my $self = shift;

  my ($url, $form) = validate_pos( @_,
    { type => SCALAR | SCALARREF },
    { type => HASHREF | ARRAYREF } # What does HTTP::Request::Common accept?
  );

  print STDERR "POST " . $url . "\n" if $self->{debug};
  if ($self->{debug} > 1) {
    use Data::Dumper;
    print Data::Dumper->Dump([ $form ], [ 'params' ]);
  }

  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new;

  my $response = $ua->post($url, $form);
  if ($response->is_success) {
    return $response->decoded_content;
  }
  else {
#     print Dumper($response);
    confess $response->message;
  }
}

1;

__END__

=head1 SEE ALSO

=over 4

=item L<GitLab::API::v3>, on which the interface is inspired

=item L<GitLab::API::v3>, another possibly defunct API implementation

=back

=head1 AUTHOR

Jose Joaquin Atria, C<< <jjatria at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to 
C<bug-www-gitlab-v3 at rt.cpan.org>, or through the web interface at 
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-GitLab-v3>. I will be
notified, and then you'll automatically be notified of progress on your bug as I
make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::GitLab::v3

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-GitLab-v3>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-GitLab-v3>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-GitLab-v3>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-GitLab-v3/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2015 J. Joaquin Atria.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of WWW::GitLab::v3
