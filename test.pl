#/user/bin/perl -w

use 5.006;

# use GitLab::API::v3;
use Data::Printer;
use WWW::GitLab::v3;
use Data::Dumper;
use Carp;
use Try::Tiny;
# # 

use LWP::UserAgent;
my $ua = LWP::UserAgent->new();

# p($ua->put('https://gitlab.com/api/v3/projects/257052?gt1z8bF5EaczUQvKB7qy', {
#   name => 'a name',
#   description => 'a new description',
#   path => 'a new description',
# }));

my %params = (
#Cpran
  token => 'Myz-wxxGLnV_syejdkWx',
#   token => 'dUd7RJGFSxQCmevkVMPs',
#   url   => 'http://git.idele.org:8181/api/v3/',
#   token => 'gt1z8bF5EaczUQvKB7qy',
#   token => 'WMe3t_ANxd3yyTLyc7WA',
  url   => 'https://gitlab.com/api/v3/',
  debug => 2,
);
# # 
my $api = WWW::GitLab::v3->new(%params);

p(my $project = $api->projects({search => 'plugin_twopass'})->[0]);
p(my $tree = $api->tree($project->{id}));
p(my $commit = $api->commits($project->{id})->[0]);
p(my $blob = $api->blob($project->{id}, $commit->{id}, { filepath => 'readme.md' }));

p(my $tags = $api->tags($project->{id}));


# my %test_key_params = (
# #   title => 'testkey',
# #   key => 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCweYn9KVvGww6DZfyLdhXDIknHkXw0itZQlwXrItAHJpH2S/XsJRZInHfjwP2J00xkyiMzzS0Cke0djx0LXaDCFOkhX2n3n94RWGZl9D+M8eYs0l4lKbvHcGRZTgNdIykWBx5NjHCCBUlUbH1oFLJ1hbuqtJFgQiz7bTCQ9U961n6BUa5GpCmgmTQL7CMyqytAiAP6OwNxUf0EgJcXUnxsLY3sGsVx+CgIDaa7/+AfckDFiAs/ykxHPdsiNKCP4F9gdkzkjf8HPA6yP6YgszezuotNoPMG4dwrZ7jH+vKbI9wiyk4RMEOJNcLu6ZJStpMHPCa3wgkcO2WxUEAidhTr test@key',
# # );
# # my $key = $api->create_current_user_ssh_key(\%test_key_params);
# # p($key);
# # my $id = $key->{id};
# # $key = undef;
# # eval { $key = $api->create_current_user_ssh_key(\%test_key_params) };
# # print "Failed\n" unless defined $key;
# # $key = $api->delete_current_user_ssh_key($id);
# # p($key);
# 
# my $text = <<'EOF';
# Some verbatim text
# ==================
# 
# Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
# incididunt ut labore et dolore magna aliqua. Ut enim:
# 
# * ad minim veniam.
# 
# * quis nostrud exercitation.
# 
# * ullamco laboris nisi ut aliquip ex ea commodo consequat.
# 
# Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
# fugiat nulla pariatur. 
# 
#     #!/usr/bin/perl -w
#     map { print } @INC;
# 
# Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia
# deserunt mollit anim id est laborum.
# EOF
# 
# my $project = $api->project('257052');
# # # p($project);
# # $api->edit_project('257052', {
# #   name                   => $project->{name},
# #   path                   => $project->{path},
# #   description            => $project->{description},
# #   default_branch         => 'master',
# #   issues_enabled         => $project->{issues_enabled},
# #   merge_requests_enabled => $project->{merge_requests_enabled},
# #   wiki_enabled           => $project->{wiki_enabled},
# #   snippets_enabled       => 1,
# #   public                 => $project->{public},
# #   visibility_level       => $project->{visibility_level},
# # });
# # # print Dumper($api->project('257052'));
# p($api->create_snippet($project->{id}, {
#   title => 'test',
#   file_name => 'snippet.md',
#   visibility_level => 0,
#   code => $text,
# }));
# 
# $ua->post('http://requestb.in/1mocszk1',
# {
#   name                   => $project->{name},
#   path                   => $project->{path},
#   description            => $project->{description},
#   default_branch         => 'master',
#   issues_enabled         => $project->{issues_enabled},
#   merge_requests_enabled => $project->{merge_requests_enabled},
#   wiki_enabled           => $project->{wiki_enabled},
#   snippets_enabled       => 1,
#   public                 => $project->{public},
#   visibility_level       => $project->{visibility_level},
# });
# # 
# print Dumper($api->project_members('257052'));

# try {
#   croak "I croaked";
# }
# catch {
#   print STDERR "Did not croak!\n";
# };
# print "End\n";

# print "$_ => $INC{$_}\n" foreach (keys %INC);

  
# 
#  'new',                              tested

#  'users',                            tested
#  'user',                             tested
#  'create_user',                              admin
#  'edit_user',                                admin
#  'delete_user',                              admin
#  'current_user',                     tested
#  'current_user_ssh_keys',            tested
#  'user_ssh_keys',                            admin
#  'user_ssh_key',                     tested
#  'create_current_user_ssh_key',      tested
#  'create_user_ssh_key',              tested
#  'delete_current_user_ssh_key',      tested
#  'delete_user_ssh_key',              tested

#  'session',                          tested

#  'projects',                         tested
#  'owned_projects',                   tested
#  'all_projects',                            admin
#  'project',                          tested
#  'project_events',
#  'create_project',                   tested
#  'create_project_for_user',
#  'edit_project',
#  'fork_project',
#  'delete_project',
#  'project_members',                  tested
#  'project_member',                   tested
#  'add_project_member',               
#  'edit_project_member',
#  'remove_project_member',
#  'project_hooks',
#  'project_hook',
#  'create_project_hook',
#  'edit_project_hook',
#  'delete_project_hook',
#  'set_project_fork',
#  'clear_project_fork',
#  'search_projects_by_name',

#  'snippets',
#  'snippet',
#  'create_snippet',
#  'edit_snippet',
#  'delete_snippet',
#  'raw_snippet',

#  'tags',
#  'create_tag',
#  'tree',
#  'blob',
#  'raw_blob',
#  'archive',
#  'compare',
#  'contributors',

#  'file',
#  'create_file',
#  'edit_file',
#  'delete_file',

#  'commits',
#  'commit',
#  'commit_diff',
#  'commit_comments',
#  'add_commit_comment',

#  'branches',
#  'branch',
#  'protect_branch',
#  'unprotect_branch',
#  'create_branch',
#  'delete_branch',

#  'merge_requests',
#  'merge_request',
#  'create_merge_request',
#  'edit_merge_request',
#  'accept_merge_request',
#  'add_merge_request_comment',
#  'merge_request_comments',

#  'all_issues',
#  'issues',
#  'issue',
#  'create_issue',
#  'edit_issue',

#  'labels',
#  'create_label',
#  'delete_label',
#  'edit_label',

#  'milestones',
#  'milestone',
#  'create_milestone',
#  'edit_milestone',

#  'notes',
#  'note',
#  'create_note',

#  'deploy_keys',
#  'deploy_key',
#  'create_deploy_key',
#  'delete_deploy_key',

#  'hooks',
#  'create_hook',
#  'test_hook',
#  'delete_hook',

#  'groups',
#  'group',
#  'create_group',
#  'transfer_project',
#  'delete_group',
#  'group_members',
#  'add_group_member',
#  'remove_group_member',

#  'edit_project_service',
#  'delete_project_service'
