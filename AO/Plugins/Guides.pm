package AO::Plugins::Guides;

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
my $OS = '';
my $DIV;

unless ($OS)
{
    unless ( $OS = $^O )
    {
        require Config;
        $OS = $Config::Config{'osname'};
    }
}

if ( $OS =~ /Win/i )
{
    $OS  = 'WINDOWS';
    $DIV = "\\";
} elsif ( $OS =~ /vms/i )
{
    $OS  = 'VMS';
    $DIV = "//";
} elsif ( $OS =~ /^MacOS$/i )
{
    $OS  = 'MACINTOSH';
    $DIV = "//";
} elsif ( $OS =~ /os2/i )
{
    $OS  = 'OS2';
    $DIV = "//";
} else
{
    $OS  = 'UNIX';
    $DIV = "//";
}

#print "The OS is: ", $OS;

#============================== new for package ==============================#

#everything you want to do when the bot starts up
sub init
{
    my $this = shift;
    $this->{base}->{name} = "Sekhura's magic stuff module";
    $this->log( "INIT", "I was asked to initialize" );

    #$this->subscribe(TELL); # subscibes to any tell
    $this->subscribe( GROUP_GUILD, "guides" );
    $this->subscribe( TELL,        "guides" );
    $this->subscribe( TELL,        "guidesadm" );

    #import all of the index stuff here
    #Build a index of files
    $this->{botname} = $this->bot->{settings}->{login}->{character};
    $this->{prefix}  = $this->bot->{settings}->{core}->{prefix};
    $this->load();
    return $this;
}

#anytime a message comes in this handler is called
sub message_handler
{
    my $this    = shift;
    my $type    = shift;              #Message source Type
    my $person  = shift;              #Person sending Message
    my $group   = shift;              #Group message came from
    my $msg     = shift;
    my $command = shift;
    my $botname = $this->{botname};
    my $prefix  = $this->{prefix};
    given ($command)
    {
        when "guides"
        {
            if ( defined $msg )
            {
                $this->log( "REQUEST", "$person requested the page ($msg)" );
                if ( defined $this->{GUIDES}->{$msg} )
                {
                    my $blob = $this->{GUIDES}->{$msg}->{content};
                    $blob =~ s/<botname>/$botname/g;
                    $this->bot->send_output( $type, $person, $group, $this->bot->make_blob( $this->{GUIDES}->{$msg}->{name}, $blob ) );
                } else
                {
                    $this->bot->send_output( $type, $person, $group, "Sorry i don't have a guide named $msg" );
                }
            } else
            {
                $this->log( "REQUEST", "$person requested the main menu" );
                my $blob = $this->{MENU};
                $blob =~ s/<botname>/$botname/g;
                $this->bot->send_output( $type, $person, $group, $this->bot->make_blob( "Guides Menu", $blob ) );
            }
        }
        when "guideadm"
        {
            $this->log( "REQUEST", "$person requested the guides system to reload" );
            $this->load();
            $this->message_handler( $type, $person, $group, "", "guides" );
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

sub load
{
    my $this = shift;
    my $dh;
    my @files;
    my $botname = $this->{botname};
    my $prefix  = $this->{prefix};
    opendir( $dh, "." . $DIV . "Guides" );
    if ( defined $dh )
    {
        @files = readdir($dh);
        closedir $dh;
        foreach my $file (@files)
        {
            if ( $file =~ /\A(.*)\.txt\Z/ )
            {
                my $fh;
                open( $fh, "." . $DIV . "Guides" . $DIV . $file );
                $file = lc($1);
                $this->{GUIDES}->{$file}->{name} = readline($fh);
                chomp( $this->{GUIDES}->{$file}->{name} );
                $this->log( "INIT", "Loading Guide $file as " . $this->{GUIDES}->{$file}->{name} );
                local $/;
                $this->{GUIDES}->{$file}->{content} = $this->{GUIDES}->{$file}->{name} . "\n" . <$fh>;
                my $regex = "<a href='chatcmd:\/\/\/tell $botname " . $prefix . "guides ";
                $this->{GUIDES}->{$file}->{content} =~ s/<a guidelink='/$regex/g;
                $this->{GUIDES}->{$file}->{content} =~ s/<c=/<font color=/g;
                $this->{GUIDES}->{$file}->{content} =~ s/<\/c>/<\/font>/g;
                $this->{GUIDES}->{$file}->{name}    =~ s/<\/*font.*>//g;
                close($fh);
            }
        }
        my $mainmenu = "Guides Module Main Menu\n";
        $mainmenu .= "\nPlease note when you click one of thease links this page will <b>NOT</b> change you need to click the link that $botname is telling you in your chat window\n";
        my $last_key = "";
        foreach my $key ( sort keys %{ $this->{GUIDES} } )
        {
            my @tabs = split( / /, $key );
            my $tabs = @tabs - 1;
            $mainmenu .= "\n." . ( "\t" x $tabs ) . "<a href='chatcmd:\/\/\/tell $botname " . $prefix . "guides $key'>$this->{GUIDES}->{$key}->{name}</a>";
        }
        $this->{MENU} = $mainmenu;
    } else
    {
        $this->{GUIDES} = undef;
    }
}

1;
