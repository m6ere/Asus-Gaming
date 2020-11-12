package AO::Plugins::Example;

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
    $this->{base}->{name} = "My Magic Example Module";
    $this->log("INIT", "I was asked to initialize");
    $this->subscribe(TELL, "removebudd");
    $this->subscribe(TELL, "addbudd");
    $this->subscribe(TELL, "removeme");
    $this->subscribe(TELL, "addme");
    $this->subscribe(TELL, "pktest");
    $this->subscribe(TELL, "pg_inv");
    $this->subscribe(TELL, "pg_kick");
    $this->subscribe(PG_JOINED);
    $this->subscribe(CONNECTED);
    return $this;
}

#anytime a message comes in this handler is called
sub message_handler
{
    my $this   = shift;
    my $type   = shift;    #Message source Type
    my $person = shift;    #Person sending Message
    my $group  = shift;    #Group message came from
    my $msg = shift || "";
    my $command = shift;
    #$this->log("TESTING", "i recived $msg from $person on $type");
    if($type == TELL)
    {
        #$this->bot->send_output(TELL, $person, undef, "Hello $person");
        if($command =~ /echo/)
        {
            $this->bot->send_output(TELL, $person, undef, "Hello $person");
        }
        elsif($command =~/addme/)
        {
            $this->bot->send_output(TELL, $person, undef, "Hello $person i want to be your friend");
            $this->bot->player($person)->addbuddy();
        }
        elsif($command =~/pktest/)
        {
            my $header;
            my $inside = "";
            $msg = 256 unless($msg ne "");
            $msg = $msg / 64;
            my $filler;
            {
                my $temp = $this->bot->{CHAT}->{ME}->name();
                $filler = ("x" x (20-length($temp)))
            }
            for(my $c = 2; $c <= $msg; $c += 1)
            {
                $inside .= "<a href='chatcmd:\/\/\/tell " . $this->bot->{CHAT}->{ME}->name() . " !about $filler'>". sprintf("%6d", ($c * 64))."</a>\n";
            }
            $header = "Packet Test sending ". (64 + length($inside)) . "b   <a href='chatcmd:\/\/\/tell " . $this->bot->{CHAT}->{ME}->name() . " !about $filler'>filler</a>\n";
            $this->bot->send_output($type, $person, $group, $this->bot->make_blob("Packet Test", $header . $inside) );
        }
        elsif($command =~/removeme/)
        {
            $this->bot->send_output(TELL, $person, undef, "Hello $person i don't want to be your friend");
            $this->bot->player($person)->rembuddy();
        }
        elsif($command =~/removebudd/)
        {
            my ($player) = ($msg =~ /\w+\s(\w+)/);
            $this->bot->player($player)->rembuddy();
        }
        elsif($command =~/addbudd/)
        {
            my ($player) = ($msg =~ /\w+\s(\w+)/);
            $this->bot->player($player)->addbuddy();
        }
        elsif($command =~/pg_inv/)
        {
            $this->bot->player($person)->pginvite();
        }
        elsif($command =~/pg_kick/)
        {
            $this->bot->player($person)->pgkick();
        }
    }
    if($type == GROUP_GUILD && $msg =~ /about/)
    {
        $this->log("TESTING", "sending $person a response on group");
    }
}

#anything else that comes in
# group_(invite/reject/join/leave)
# connect/disconnect
sub state_handler
{
    my $this   = shift;
    my $type   = shift; #the type code for the message
    given ($type)
    {
        when PG_JOINED
        {
            my ($person, $group) = @_;
            $this->bot->send_output(GROUP_PRIVATE, $group, undef, "Hello " . $person);
        }
    }
}

1;
