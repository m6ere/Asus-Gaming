package AO::Plugins::Relay;

# Plugin: Example Plugin
#============================= Version information ============================#
use vars qw($VERSION);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];

#================================== Imports ===================================#
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use base qw(AO::Core::Plugin);
use AO::Chat::Constants;
use Switch 'Perl6';    #used for switch/when statements

#============================== new for package ==============================#

#everything you want to do when the bot starts up
sub init
{
    my $this = shift;
    $this->{base}->{name} = "Mafoo's Relay Module";
    $this->log( "INIT", "Subscribing to my events" );
    $this->subscribe( TELL, "relay" );
    $this->subscribe(CONNECTED);
    return $this;
}

#anytime a message comes in this handler is called
sub message_handler
{
    my $this    = shift;
    my $type    = shift;         #Message source Type
    my $person  = shift;         #Person sending Message
    my $group   = shift;         #Group message came from
    my $msg     = shift || "";
    my $command = shift;
    if ( $type == TELL )
    {

        #$this->bot->send_output(TELL, $person, undef, "Hello $person");
        if ( $command =~ /relay/ )
        {
            if ( lc($person) =~ /florence/ or lc($person) =~ /hastien/ )
            {
                $this->bot->send_output( GROUP_GUILD, undef, undef, "<font color='#448844'>[$person]:</font> $msg" );
            }
        }
    }
}

#anything else that comes in
# group_(invite/reject/join/leave)
# connect/disconnect
sub function_handler
{
    my $this = shift;
    my $type = shift;    #the type code for the message
    given ($type)
    {
        when CONNECTED
        {
        }
    }
}

1;
