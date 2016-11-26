package CPrAN::Schema::Result::Plugin;

use Moose;
use MooseX::MarkAsMethods autoclean => 1;

extends 'CPrAN::Schema::Result';

__PACKAGE__->table("plugin");

__PACKAGE__->add_columns(
  name => {
    data_type => "varchar",
    size => 100,
  },

  version => {
    data_type => "varchar",
    size => 255,
    is_nullable => 1,
  },

  homepage => {
    data_type => "varchar",
    size => 255,
  },

  maintainer => {
    data_type => "varchar",
    size => 255,
    is_nullable => 1,
  },

  version => {
    data_type => "varchar",
    size => 255,
    is_nullable => 1,
  },

  praat => {
    data_type => "varchar",
    size => 255,
    is_nullable => 1,
  },

);

__PACKAGE__->set_primary_key('name');

__PACKAGE__->has_many(
  'plugin_dependencies',
  'CloudCAST::Schema::Result::Application',
  'owner_id',
#   { cascade_delete => 1 },
);

__PACKAGE__->has_many(
  'application_users',
  'CloudCAST::Schema::Result::ApplicationUser',
  'user_id',
);

around [qw( first_name last_name )] => sub {
  my $orig = shift;
  my $self = shift;
  use Encode;
  return decode_utf8 $self->$orig(@_);
};

sub display_name {
  my ($self) = @_;
  if (defined $self->first_name and
      defined $self->last_name  and
      $self->first_name ne ''   and
      $self->last_name  ne ''
    ) {

    return join ' ', ($self->first_name, $self->last_name);
  }
  else {
    return $self->name;
  }
}

sub validate {
  my ($self, $password, $cost) = @_;

  use MIME::Base64;
  use Authen::Passphrase::BlowfishCrypt;

  my $ppr = Authen::Passphrase::BlowfishCrypt->new(
    salt => decode_base64($self->password_salt),
    cost => $cost // 8,
    passphrase => $password,
  );

  return $ppr->hash_base64 eq $self->password;
}

__PACKAGE__->add_unique_constraint([ qw/ name / ]);
__PACKAGE__->add_unique_constraint([ qw/ email_address / ]);

__PACKAGE__->meta->make_immutable;

1;
