package Mojolicious::Plugin::SessionTags;

use Mojo::Base 'Mojolicious::Plugin';
use Carp;

our $VERSION = '0.06';

has session_key => 'st_tag';
has name => 'tag';
has place_values => sub { {} };

sub register {
	my ( $self, $app, $conf ) = @_;

	if ( $conf->{name} ) {
		$self->session_key( 'st_' . $conf->{name} );
		$self->name( $conf->{name} );
	}

	$self->place_values( $self->_set_place_values( $conf->{tags} ) );

	$app->helper(
		'sum_' . $self->name => sub {
			undef $_[0]->session->{ $self->session_key } if ( $_[1] // 1 ) == 0;
			$_[0]->session->{ $self->session_key } = $_[0]->session->{ $self->session_key } // 0;
		}
	);

	$app->helper(
		'has_' . $self->name => sub {
			my $tag = $self->_check_input_tag( $_[1] );
			my $sum_helper = 'sum_' . $self->name;
			$_[0]->$sum_helper & $self->place_values->{$tag} ? 1 : 0;
		}
	);

	$app->helper(
		'not_' . $self->name => sub {
			my $tag = $self->_check_input_tag( $_[1] );
			my $sum_helper = 'sum_' . $self->name;
			$_[0]->$sum_helper & $self->place_values->{$tag} ? 0 : 1;
		}
	);

	$app->helper(
		'add_' . $self->name => sub {
			my $tag = $self->_check_input_tag( $_[1] );
			my $sum_helper = 'sum_' . $self->name;
			my $session_value = $_[0]->$sum_helper;
			$_[0]->session->{ $self->session_key } = $session_value & $self->place_values->{$tag} ? $session_value : $session_value + $self->place_values->{$tag};
		}
	);

	$app->helper(
		'nix_' . $self->name => sub {
			my $tag = $self->_check_input_tag( $_[1] );
			my $sum_helper = 'sum_' . $self->name;
			my $session_value = $_[0]->$sum_helper;
			$_[0]->session->{ $self->session_key } = $session_value & $self->place_values->{$tag} ? $session_value - $self->place_values->{$tag} : $session_value;
		}
	);
}

sub _check_input_tag {
	croak 'No input provided for ' . __PACKAGE__ unless $_[1];
	return $_[1] if $_[0]->place_values->{$_[1]};
	croak '"' . $_[1] . '" is not a valid ' . $_[0]->name . ' for ' . __PACKAGE__;
}

sub _set_place_values {
	my $pv = 0.5;
	return { map { $_ => $pv *= 2 } @{$_[1]} };
}

1;
__END__

=encoding utf-8

=head1 NAME

Mojolicious::Plugin::SessionTags - Use small sized session tags to track conditional user details.

=head1 VERSION

0.06

=head1 SYNOPSIS

  # In the start up script: (using the default helper name suffix of "_tag")

  $app->plugin( 'session_tags' => { tags => [qw/ user writer admin tester /] });

  # In your controller:

  $c->add_tag( $_ ) for qw/ writer admin /;

  ... if $c->has_tag( 'admin' );  # Returns true
  ... if $c->has_tag( 'writer' ); # Returns true
  ... if $c->has_tag( 'user' );   # Returns false
  ... if $c->has_tag( 'tester' ); # Returns false

  ... if $c->not_tag( 'admin' );  # Returns false
  ... if $c->not_tag( 'tester' ); # Returns true

  $c->nix_tag( 'writer' );

  ... if $c->has_tag( 'writer' ); # Now returns false

  # In your templates:

  <nav>
    <ul>
      <li><a href="/">Home</a></li>
  %   if ( has_tag 'writer' ) {
      <li><a href="/writer">Writer</a></li>
  %   }
  %   if ( has_tag 'admin' ) {
      <li><a href="/admin">Admin</a></li>
  %   }
    </ul>
  </nav>

  # Using a custom name suffix of "_role" to give more meaning to the helper.
  $app->plugin( name => 'role', 'session_tags' => { tags => [qw/ user writer admin tester /] });

  $c->add_role( $_ ) for qw/ writer admin /;

  ... if $c->has_role( 'admin' );  # Returns true
  ... if $c->has_role( 'tester' ); # Returns false


  # Use numerous tags to cover many uses:

  $app->plugin( 'session_tags' => { tags => [qw/ user_role creator_role admin_role tester_role new_stage trial_stage member_stage limbo_stage survey1_done survey2_done survey3_done /] });

  # Or subclass the plugin to allow more meaningful helper tags:

  package MyApp::Plugin::SessionRoles;
  use Mojo::Base 'Mojolicious::Plugin::SessionTags';

  package MyApp::Plugin::SessionStages;
  use Mojo::Base 'Mojolicious::Plugin::SessionTags';

  package MyApp::Plugin::SessionDone;
  use Mojo::Base 'Mojolicious::Plugin::SessionTags';

  # And in start up:

  $app->plugin( 'MyApp::Plugin::SessionRoles' => { name => 'role', tags => [qw/ user creator admin tester /] });
  $app->plugin( 'MyApp::Plugin::SessionStages' => { name => 'stage', tags => [qw/ new trial member limbo /] });
  $app->plugin( 'MyApp::Plugin::SessionDone' => { name => 'done', tags => [qw/ survey1 survey2 survey3 /] });

  # In your controller:

  $c->add_role( $_ ) for qw/ user admin /;
  $c->add_stage( $_ ) for qw/ trial /;
  $c->add_done( $_ ) for qw/ survey1 survey2 /;

  ... if $c->has_role( 'admin' );  # Returns true
  ... if $c->has_stage( 'member' );  # Returns false
  ... if $c->has_done( 'survey1' );  # Returns true
  ... if $c->not_done( 'survey3' );  # Returns false

=head1 DESCRIPTION

Mojolicious::Plugin::SessionTags uses bit flags to store basic user information in minimal space. Mojolicious defaults to using signed cookies, and cookies have a size limit. Using the default session key with the value of 255, "st_role":255, is all that is needed (actually a bit more as it is Base64 encoded) to store eight conditional "true" values.

=head1 METHODS

=head2 register

  $app->plugin( 'session_tags' => { name => 'tag', tags => \@tags } );

Registers the plugin into the Mojolicious app.

=head1 CONFIGURATION

=head2 name (optional)

Used to create the session key (appended to "st_"). The default key is "st_tag." Also, will be used as helpers (appended to helper prefixes).

If two or more subclasses are used, then "name" needs to be used and unique.

=head2 tags

A list of the tags you want to assign.

=head1 HELPERS

All helpers default to ending with "_tag." If "name" is provided, then it will be used (ie. name => 'role', "_role").

=head2 sum_tag

=head2 sum_tag(0)

Returns the current session key value. If passed a 0, then the session key value is set to 0. Passing any other value does nothing.

=head2 add_tag( 'tag' )

Sets the bit flag for the tag.

=head2 nix_tag( 'tag' )

Removes the bit flag for the tag.

=head2 has_tag( 'tag' )

Returns 1 if the bit flag is set.

=head2 not_tag( 'tag' )

Returns 0 if the bit flag is not set.

=head1 CAUTION

If at any time, the order of the tags is changed (ie. tag deleted, sort order changed if coming from db) in the configuration, then be sure and change your session secret before restaring your app. Changing the secret will wipe out the users' sessions, so plan ahead.

And yes, this plugin can create a lot of top level helpers.

=head1 AUTHOR

Scott Kiehn E<lt>sk.keenlinks@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2016- Scott Kiehn

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
