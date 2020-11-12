package AO::Chat::Player;

require 5.004;
use strict;
use warnings;

sub new
{
    my ( $proto, $chat, $id, $name ) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};
    if ( !$id || $id == 0 || $id == 0xFFFFFFFF )
    {
        return undef;
    }
    $self->{NAME}   = $name;
    $self->{ID}     = $id;
    $self->{CHAT}   = $chat;
    $self->{LEVEL}  = 0;
    $self->{CLASS}  = 0;
    $self->{ONLINE} = -1;
    $self->{STATE}  = 0;
    bless( $self, $class );
    return $self;
}

sub name
{
    return $_[0]->{NAME};
}

sub whois
{
    my $self = shift;
    if(@_ > 0)
    {
        $self->{ONLINE} = shift;
        $self->{LEVEL}  = shift;
        $self->{STATE}  = shift;
        $self->{CLASS}  = shift;
    } else {
        return ($self->{ID}, $self->{NAME}, $self->{LEVEL}, $self->{CLASS}, $self->{ONLINE}, $self->{STATE});
    }
}

sub tell {
  my ($self, $message)=@_;
  $self->{CHAT}->queue(new AO::Chat::Packet( 30, $self->{ID},$message, 1));
}

sub pginvite
{
    my ($self) = @_;
    $self->{CHAT}->send( new AO::Chat::Packet( 50, $self->{ID} ) );
}

sub pgkick
{
    my ($self) = @_;
    $self->{CHAT}->send( new AO::Chat::Packet( 51, $self->{ID} ) );
}

sub pgjoin
{
    my ($self) = @_;
    $self->{CHAT}->send( new AO::Chat::Packet( 52, $self->{ID} ) );
}

sub pgmsg
{
    my ( $self, $msg) = @_;
    $self->{CHAT}->send( new AO::Chat::Packet( 57, $self->{ID}, $msg, '' ) );
}

sub addbuddy
{
    my ( $self) = @_;
    $self->{CHAT}->log("BUDDY_ADD->" . $self->{NAME});
    $self->{CHAT}->send( new AO::Chat::Packet( 120, 2, "addbuddy", $self->{NAME}, 17) );
}

sub rembuddy
{
    my ( $self) = @_;
    $self->{CHAT}->log("BUDDY_REM->" . $self->{NAME});
    $self->{CHAT}->send( new AO::Chat::Packet( 120, 2, "rembuddy", $self->{NAME}, 17) );
}

1;

__END__

# Below is stub documentation for your module. You better edit it!

=head1 NAME

AO::Chat::Player - Methods dealing with AO players.

=head1 SYNOPSIS

  use AO::Chat;

  package MyCallback;

  use base qw(AO::Chat::Callback);

  sub tell {
    my ($self,$player,$message,$blob)=@_;
    print "Private Message :: $message\n";
    $player->tell("Hi");
  }

=head1 DESCRIPTION

This is the interface that deals with other players in the AO universe.
Methods here cover sending messages and the administration of buddies and
private chat groups.
You will never create a player object on your own, you will either use
AO::Chat::player() or pick it up from a passed parameter in the callback
functions.

=head1 METHODS

=over 4

=item name()

Returns player's name.

=item tell("Message")

Sends a /tell to the player.
Please note that the server limits the ammount of /tells that can be sent in
a given time period, so no tells are sent immediately; they are queued on
the AO::Chat object. The AO::Chat::packet() function handles dequeuing in a
timely manner.

=item addbuddy($list)

Adds this player to your buddy list. If $list is 1, the player will be added as a
permanent buddy, otherwise it will be just a '?' buddy.

=item rembuddy()

Removed this player from your buddy list.

=item pginvite()

Invites this player to your private chat group.

=item pgkick()

Kicks this player from your private chat group.

=item pgjoin()

Join the private chat group of this player.

=item pgmsg("Message")

Sends a message to the private chat group of this player. The player can
of course be yourself (See AO::Chat::me()).

=back

=head1 AUTHOR

Slicer, slicer@ethernalquest.org

=head1 SEE ALSO

AO::Chat, AO::Chat::Callback, AO::Chat::Group, AO::Chat::Blob, perl(1).

=cut
