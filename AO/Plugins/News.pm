package AO::Plugins::News;

# Plugin: Example Plugin
#============================= Version information ============================#
use vars qw($VERSION);
$VERSION = '1';

#================================== Imports ===================================#
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use base qw(AO::Core::Plugin);
use AO::Chat::Constants;

#============================== new for package ==============================#

#everything you want to do when the bot starts up
sub init
{
    my $this = shift;
    $this->{base}->{name} = "Static news Command";
    $this->log( "INIT", "I was asked to initialize" );
    $this->subscribe( TELL,        "news" );
    $this->subscribe( GROUP_GUILD, "news" );
    return $this;
}

#anytime a message comes in this handler is called
sub message_handler
{
    my $this    = shift;
    my $type    = shift;                                                 #Message source Type
    my $person  = shift;                                                 #Person sending Message
    my $group   = shift;                                                 #Group message came from
    my $msg     = shift || "";
    my $command = shift;
    my $blob    = "<font color='#99FF66'>Static news applet</font>\n";
    $blob .= "\n16th June 18:00 - added a saftey catch to allow the bot to break out of a infinate loop in case a module bugs or the serer goes down.";
    $blob .= "\n17th June 19:40 - tweaked the way relayed messages are displayed.";
    $blob .= "\n19th June 23:30 - did somethign to the time command, give it a try!.";
    $blob .= "\n19th June 23:30 - did somethign to teh time command, give it a try!.";
    $this->bot->send_output( $type, $person, $group, $this->bot->make_blob( "Current News", $blob ) );
}

#anything else that comes in
# group_(invite/reject/join/leave)
# connect/disconnect
sub state_handler
{
    my $this = shift;
    my $type = shift;    #the type code for the message
}

1;
