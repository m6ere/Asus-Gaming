package AO::Plugins::Whois;

# Plugin: Whois Plugin
#============================= Version information ============================#
use vars qw($VERSION);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];

#================================== Imports ===================================#
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use base qw(AO::Core::Plugin);
use AO::Chat::Constants;
use Switch 'Perl6';    #used for switch/when statements
use Data::Dumper;

#============================== new for package ==============================#

#everything you want to do when the bot starts up
sub init
{
    my $this = shift;
    $this->{base}->{name} = "Player Identification Module";
    $this->log( "INIT", "Initializing subscribes" );
    $this->subscribe( TELL,        "whois" );    # subscibes to any tell
    $this->subscribe( GROUP_GUILD, "whois" );
    $this->subscribe(BUDDY_ONLINE);
    $this->subscribe(BUDDY_OFFLINE);
    $this->{LOOKUPS} = undef;
    return $this;
}

#anytime a message comes in this handler is called
sub message_handler
{
    my $this    = shift;
    my $type    = shift;                         #Message source Type
    my $person  = shift;                         #Person sending Message
    my $group   = shift;                         #Group message came from
    my $msg     = shift;
    my $command = shift;

    #$this->log("command is $command, message is $msg");
    given ($command)
    {
        when "whois"
        {
            $msg = ucfirst($msg);
            $this->log( "WHOIS", "Executing whois for $msg" );
            if ( defined $this->bot->player($msg) )
            {
                if ( $this->bot->player($msg)->{ID} == $this->bot->{CHAT}->{ME}->{ID} )
                {
                    $this->bot->send_output( $type, $person, $group, "<font color='#88aa11'>$msg</font> is a <font color='#337722'>level 100 Whore</font> who is <font color='#00FF00'>online</font> and 'Socializing' with Casilda" );
                } else
                {
                    push @{ $this->{LOOKUPS}->{$msg} }, { TYPE => $type, CALLER => $person, GROUP => $group };
                    $this->bot->player($msg)->rembuddy();
                    $this->bot->player($msg)->addbuddy();
                }
            } else
            {
                $this->bot->send_output( $type, $person, $group, "I cannot identify $msg sorry" );
            }
        }
    }
}

#anything else that comes in
# group_(invite/reject/join/leave/buddy)
# connect/disconnect
sub state_handler
{
    my $this = shift;
    my $type = shift;    #the type code for the message
    given ($type)
    {
        when BUDDY_ONLINE
        {
            my ( $name, $playerid, $online ) = @_;
            my $level;
            my $state;
            my $class;
            ( undef, undef, $level, $class, undef, $state ) = $this->bot->player($name)->whois;
            $this->log( "BUDDY_ONLINE", "Recived a Buddy online for $name" );
            if ( defined $this->{LOOKUPS}->{$name} )
            {

                foreach my $obj ( @{ $this->{LOOKUPS}->{$name} } )
                {
                    my $text;
                    if ( $state ne 0 )
                    {
                        if ( $online eq 1 )
                        {
                            $online = "<font color='#00FF00'>online</font> and in PF$state";
                        } else
                        {
                            $online = "<font color='#CC0000'>offline</font> and was last seen " . localtime($state);
                        }
                        $text = "<font color='#88aa11'>$name</font> is a level <font color='#337722'>$level " . $AO::Chat::Constants::CLASSES->{$class} . "</font> who is $online";
                    } else
                    {
                        if ( $online eq 1 )
                        {
                            $online = "online";
                        } else
                        {
                            $online = "offline";
                        }
                        $text = "<font color='#88aa11'>$name</font> is $online but i cannot deterim there information";
                    }
                    $this->bot->send_output( $obj->{TYPE}, $obj->{CALLER}, $obj->{GROUP}, $text );
                }
                $this->bot->player($name)->rembuddy;
                delete $this->{LOOKUPS}->{$name};
            }
        }
        when BUDDY_OFFLINE
        {
            my ( $name, $playerid ) = @_;
            $this->log( "BUDDY_OFFLINE", "Recived a Buddy offline for $name" );
            if ( defined $this->{LOOKUPS}->{$name} )
            {
                foreach my $obj ( @{ $this->{LOOKUPS}->{$name} } )
                {
                    $this->bot->send_output( $obj->{TYPE}, $obj->{CALLER}, $obj->{GROUP}, "Sorry Lookup for $name cannot be done while they are offline" );
                }
                $this->bot->player($name)->rembuddy;
                delete $this->{LOOKUPS}->{$name};
            }
        }
    }
}

1;
