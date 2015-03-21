# ABSTRACT: install new plugins
package CPrAN::Command::install;

use CPrAN -command;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use Encode qw(encode decode);
binmode STDOUT, ':utf8';

sub opt_spec {
  return (
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->usage_error("Missing arguments") unless @{$args};

  my $prefix_warning = 0;
  foreach (0..$#{$args}) {
    if ($args->[$_] =~ /^plugin_/) {
      $prefix_warning = 1;
    }
    $args->[$_] =~ s/^plugin_//;
  }
  warn "W: Plugin names do not include the 'plugin_' prefix. Ignoring prefix.\n"
    if ($prefix_warning);
}

sub execute {
  my ($self, $opt, $args) = @_;

  my %installed;
  $installed{$_} = 1 foreach (CPrAN::installed());

  my @names;
  foreach (@{$args}) {
    if (exists $installed{$_}) {
      warn "W: $_ is already installed\n";
    }
    else {
      my %known;
      $known{$_} = 1 foreach (CPrAN::known());
      if (exists $known{$_}) {
        push @names, $_;
      }
      else {
        warn "W: no plugin named $_\n";
      }
    }
  }

  my @deps = dependencies($opt, \@names);
  print Dumper(\@deps);

  use GitLab::API::v3;

  my $api = GitLab::API::v3->new(
    url   => 'https://gitlab.com/api/v3/',
    token => $CPrAN::TOKEN,
  );
}

sub dependencies {
  my ($opt, $args) = @_;
  
  use Path::Class;
  use File::Slurp;
  use YAML::XS;
  
  my @dependencies;
  
  foreach (@{$args}) {
    my $file = file($CPrAN::ROOT, $_);
    my $descriptor = read_file($file->stringify);
    my $yaml = YAML::XS::Load( $descriptor );
    
    my %deps = (
      name     => $yaml->{Plugin},
      requires => $yaml->{Requires},
    );
    push @dependencies, \%deps;
    
  }
  
  return @dependencies;
}

1;
