package AO::Chat::Group;

require 5.004;
use strict;
use warnings;

sub new
{
    my ( $proto, $chat, $id, $name, $flags ) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{NAME}  = $name;
    $self->{ID}    = $id;
    $self->{CHAT}  = $chat;
    $self->{FLAGS} = $flags;
    bless( $self, $class );
    #print "the store value is $self->{ID}\n";
    return $self;
}

sub id
{
    return $_[0]->{ID};
}
sub name
{
    return $_[0]->{NAME};
}

sub muted
{
    return ( $_[0]->{FLAGS} & 0x01000000 ) ? 1 : 0;
}

sub mute
{
    my ( $self, $mute ) = @_;
    if ($mute)
    {
        $self->{FLAGS} |= 0x01010000;
    }
    else
    {
        $self->{FLAGS} &= ~0x01010000;
    }
    $self->{CHAT}->send( new AO::Chat::Packet( 64, $self->{ID}, ($mute) ? 0x01010000 : 0, "" ) );
}

sub msg {
  my ($self, $msg, $blob)=@_;
  #if (! ref $blob || ! $blob->isa("AO::Chat::Blob")) {
  #  $blob = '';
  #} else {
  #  $blob = $blob->blob();
  #}
  $self->{CHAT}->send(new AO::Chat::Packet(65, $self->{ID}, $msg));
}

sub get_known_groups
{
    return (
        "~Playfield"
    );
}
1;
__END__

# Below is stub documentation for your module. You better edit it!

=head1 NAME

AO::Chat::Group - Methods dealing with message groups.

=head1 SYNOPSIS

  use AO::Chat;

  package MyCallback;

  use base qw(AO::Chat::Callback);

  sub groupmsg {
    my ($self,$player,$message,$blob)=@_;
    print "Group Message :: $message\n";
    $group->msg("Hi");
  }

=head1 DESCRIPTION

This object handles the message groups of AO. Methods here cover setting the
listening state of groups and sending messages to them.
The only way to create a group object is to be informed you joined it, which
happens through the AO::Chat::Callback::groupjoin function.

=head1 METHODS

=over 4

=item name()

Returns group's name.

=item msg("Message" [,$blob])

Sends a message to the group. The blob, if included, must be a valid blob.

=back

=head1 AUTHOR

Slicer, slicer@ethernalquest.org

=head1 SEE ALSO

AO::Chat, AO::Chat::Callback, AO::Chat::Player, AO::Chat::Blob, perl(1).

=cut
