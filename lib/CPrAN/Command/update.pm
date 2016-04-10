package CPrAN::Command::update;
# ABSTRACT: update local plugin list

use CPrAN -command;

use strict;
use warnings;

use Carp;
use Try::Tiny;
binmode STDOUT, ':utf8';

=head1 NAME

=encoding utf8

B<update> - Update the catalog of CPrAN plugins

=head1 SYNOPSIS

cpran update [options] [arguments]

=head1 DESCRIPTION

Updates the list of plugins known to CPrAN, and information about their latest
versions.

=cut

sub description {
  return "Updates the catalog of CPrAN plugins";
}

=pod

B<update> can take as argument a list of plugin names. If provided, only
information about those plugins will be retrieved. Otherwise, a complete list
will be downloaded. This second case is the recommended use.

=cut

sub validate_args {
  my ($self, $opt, $args) = @_;
}

=head1 EXAMPLES

    # Updates the entire catalog printing information as it goes
    cpran update -v
    # Update information about specific plugins
    cpran update oneplugin otherplugin

=cut

sub execute {
  my ($self, $opt, $args) = @_;

  warn "DEBUG: Running update\n" if $opt->{debug};

  use Sort::Naturally;
  use WWW::GitLab::v3;
  use CPrAN::Plugin;
  use Path::Class;
  use YAML::XS;
  use Encode qw( encode decode );

  my $api = WWW::GitLab::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  $opt->{verbose}-- if defined $opt->{print};

  # The package list lives as a snippet in the plugin_cpran project
  # To get it, we need the project and snippet ids
  my $pid = $api->projects( { search => 'plugin_cpran' } )->[0]->{id};
  my $snippets = $api->snippets($pid);
  my $sid;
  foreach (@{$snippets}) { $sid = $_->{id} if $_->{file_name} eq 'cpran.list' }

  my @updated;

  my %requested;
  $requested{$_} = 1 foreach @{$args};

  if (defined $opt->{raw}) {
    print "Contacting remote repositories for latest data...\n" if $opt->{verbose};

    my $projects;
    try {
      $projects = list_projects($self, $opt, $args);
    }
    catch {
      chomp;
      warn "Could not connect to the server: $_\n";
      exit 1;
    };

    foreach my $source (@{$projects}) {

      unless ((defined $source->{name} && $source->{name} =~ /^plugin_/)) {
        warn "Not a plugin, ignoring $source->{name}\n" if $opt->{debug};
        next;
      }
      unless ((defined $source->{visibility_level} && $source->{visibility_level} eq 20)) {
        warn "Not publicly visible, ignoring $source->{name}\n" if $opt->{debug};
        next;
      }
      if ((scalar @{$args} > 1) && !defined $requested{$source->{name}}) {
        warn "Not in requested plugins, ignoring $source->{name}\n" if $opt->{debug};
        next;
      }

      my $plugin;
      try {
        $plugin = CPrAN::Plugin->new( $source );
      }
      catch {
        warn "Could not initialise plugin \"$source->{name}\"" if $opt->{debug};
      };
      next unless defined $plugin;

      if ($plugin->is_cpran) {
        print "Working on $plugin->{name}...\n" if $opt->{verbose} > 1;

        next unless defined $plugin->{remote};
        push @updated, $plugin;

        unless (defined $opt->{virtual}) {
          if (defined $plugin->{remote}->{descriptor} && $plugin->{remote}->{descriptor} ne '') {
            my $out = file( CPrAN::root(), $plugin->{name} );
            my $fh = $out->openw();
            $fh->print( $plugin->{remote}->{descriptor} );
          }
          else {
            warn "Nothing to write for $plugin->{name}" if $opt->{debug};
          }
        }
      }
      else {
        warn "$source->{name} is not a CPrAN plugin\n";
      }
    }
  }
  else {
    print "Updating plugin data...\n" if $opt->{verbose};

    foreach (split /---/, $api->raw_snippet($pid, $sid)) {
      next unless $_;

      my $encoded = "---" . encode('utf-8', $_);
      my $plugin = Load(encode('utf-8', $encoded));
      if ((scalar @{$args} >= 1) && !defined $requested{$plugin->{Plugin}}) {
        warn "Skipping $plugin->{Plugin}\n";
        next;
      }

      warn "Working on $plugin->{Plugin}...\n" if $opt->{verbose} > 1;

      if (defined $opt->{virtual}) {
        $plugin = CPrAN::Plugin->new( $encoded );
      }
      else {
        my $out = file( CPrAN::root(), $plugin->{Plugin} );
        my $fh = $out->openw();
        $fh->print( $encoded );
        $fh->close;
        $plugin = CPrAN::Plugin->new( $plugin->{Plugin} );
      }

      push @updated, $plugin;
    }
  }
  print "Updated " . scalar @updated . " packages\n" if $opt->{verbose};

  if (defined $opt->{print}) {
    $_->print('remote') foreach (@updated);
  }

  return \@updated;
}

=head1 METHODS

=over

=cut

=item B<list_projects()>

Provided with a list of plugin search terms, it returns a list of serialised
plugin objects. If the provided list is empty, it returns all the plugins it
can find in the CPrAN group.

=cut

sub list_projects {
  use WWW::GitLab::v3;

  my ($self, $opt, $args) = @_;

  my $api = WWW::GitLab::v3->new(
    url   => CPrAN::api_url(),
    token => CPrAN::api_token(),
  );

  if (@{$args}) {
    my @projects = map {
      @{$api->projects( { search => 'plugin_' . $_ } )};
    } @{$args};
    return \@projects;
  }
  else {
    return $api->projects;
  }
}

=back

=head1 OPTIONS

=over

=item B<--verbose>

Increase verbosity of output.

=back

=cut

sub opt_spec {
  return (
    [ "virtual" => "do not write anything to disk" ],
    [ "print"   => "print the stream of updated descriptors to STDOUT" ],
    [ "raw"     => "compute a new list of plugins from scratch" ],
  );
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
L<CPrAN::Command::list|list>,
L<CPrAN::Command::remove|remove>,
L<CPrAN::Command::search|search>,
L<CPrAN::Command::show|show>,
L<CPrAN::Command::test|test>,
L<CPrAN::Command::upgrade|upgrade>

=cut

# VERSION

1;
