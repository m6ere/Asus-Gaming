package AO::Plugins::Stuff;

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
use DateTime;

#============================== new for package ==============================#

#everything you want to do when the bot starts up
sub init
{
    my $this = shift;
    $this->{base}->{name} = "Misc Commands Module";
    $this->log( "INIT", "I was asked to initialize" );

    #$this->subscribe(TELL); # subscibes to any tell
    $this->subscribe( TELL,        "time" );
    $this->subscribe( GROUP_GUILD, "time" );
    $this->subscribe( TELL,        "artisans" );
    $this->subscribe( GROUP_GUILD, "artisans" );
    $this->subscribe( TELL,        "timeadm" );
    $this->subscribe( TELL,        "announce" );
    $this->subscribe(CONNECTED);
    return $this;
}

#anytime a message comes in this handler is called
sub message_handler
{
    my $this    = shift;
    my $type    = shift;                                #Message source Type
    my $person  = shift;                                #Person sending Message
    my $group   = shift;                                #Group message came from
    my $msg     = shift;
    my $command = shift;
    my $botname = $this->bot->{CHAT}->{ME}->name();
    given ($command)
    {
        when "time"
        {
            my $blob = "<font color='#99FF66'>Time Chart v0.1</font>\n\n";
            my $dt   = DateTime->now();
            my $st = DateTime->new(
                                    year   => 1970,
                                    month  => 1,
                                    day    => 1,
                                    hour   => $dt->hour(),
                                    minute => $dt->min(),
                                    second => $dt->second()
            );
            $st = $st->epoch();
            $st = $st;
            $st = $st * 5;
            $st = $st - 550;
            $st = DateTime->from_epoch( epoch => $st );

            #perform any needed offset here
            $blob .= "<font color='#FFFFFF'>" . $dt->hms . "</font> Server Time (<font color='#FF99FF'>GMT</font>)\n";
            $blob .= "<font color='#FFFFFF'>" . $st->hms . "</font> Hyboria Time (<font color='#FF99FF'>HST</font>)\n";
            $this->bot->send_output( $type, $person, $group, "The Time is now " . $st->hms() . " " . $this->bot->make_blob( "Time List", $blob ) );
        }
        when "announce"
        {
            unless ( defined $msg )
            {
                $this->bot->send_output( $type, $person, $group, "You must specify a message you want to annouce (error code 1D10T)" );
            } else
            {
                my $text = "<font color='#CC9900'>Guild Annoucement from $person</font>\n";

                #$text .= "<font color='#CC0066'>#=~-~=#</font>\n";
                $msg =~ s/\\n/\n/g;
                $text .= "<font color='#FFCCCC'>$msg</font>";

                #$text .= "<font color='#CC0066'>#=~-~=#</font>";
                $this->bot->send_output( GROUP_GUILD, $person, $group, $text );
            }
        }
        when "timeadm"
        {
            my $blob = "<font color='#99FF66'>Time Administration Chart v0.1</font>\n";
            $blob .= "Sorry this command does nothing until DB backend is implimented\n";
            foreach my $TZ ( DateTime::TimeZone->all_names() )
            {
                $blob .= "\n$TZ";
            }
            $this->bot->send_output( TELL, $person, $group, $this->bot->make_blob( "Time Admin List", $blob ) );
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
