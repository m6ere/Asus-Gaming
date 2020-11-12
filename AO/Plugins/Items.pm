package AO::Plugins::Items;

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
use Data::Dumper;
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
    $this->{base}->{name} = "Items Lookup system";
    $this->log( "INIT", "Initializing Items Lookup System" );

    #$this->subscribe(TELL); # subscibes to any tell
    $this->subscribe(GROUP_GUILD);
    $this->subscribe(GROUP_OTHER);
    $this->subscribe(TELL);
    $this->subscribe( TELL, "items" );
    my $botname = "<botname>";

    #import all of the index stuff here
    #Build a index of files
    #$this->log("DEBUG", Dumper($this->{ITEMS}));
    $this->load();
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

    #$this->log("DEBUG", Dumper($this->{ITEMS}));
    if ( defined $command )
    {
        if ( defined $msg )
        {
            $msg = lc($msg);
            $this->log( "REQUEST", "$person wants anything with the word ($msg)" );
            if ( defined $this->{ITEMS}->{$msg} )
            {

                #they asked for a specific item so lets show it
                $this->bot->send_output( $type, $person, $group, "I found " . $this->{ITEMS}->{$msg} );
            } else
            {

                #time to start a search routine
                my $maxitems = 10;
                my @items    = sort keys %{ $this->{ITEMS} };
                my $text     = "Items containing $msg";
                while ( $maxitems > 0 and @items != 0 )
                {
                    my $item = shift @items;
                    if ( defined $item )
                    {
                        if ( $item =~ /$msg/ )
                        {
                            $text .= "\n" . $this->{ITEMS}->{$item};
                            $maxitems--;
                        }
                    }
                }
                if ( $maxitems == 0 )
                {
                    $text .= "\nMaximum Item Search Reached";
                }
                if ( $text eq "Items containing $msg" )
                {
                    $text = "Sorry no items containing $msg were found";
                }
                $this->bot->send_output( TELL, $person, $group, $text );
            }
        } else
        {
            my $blob = "This Command Searches for items with a word match";
            $this->bot->send_output( $type, $person, $group, $this->bot->make_blob( "Items Command", $blob ) );
        }
    } else
    {
        my $found = 0;

        #generic pass up so we need to look for items!
        foreach my $item ( split( /<\/a>/, $msg ) )
        {
            $item .= "</a>";
            $item =~ s/.*<a/<a/;
            if ( $item =~ /itemref:\/\// )
            {
                my ($name) = ( $item =~ /\[(.*)\]/ );
                chomp($item);
                $name = lc($name);
                $this->{ITEMS}->{$name} = $item;
                $this->log( "DEBUG", "Loaded $name as $this->{ITEMS}->{$name}" );
                $found++;
            }
        }
        if ( $found > 0 )
        {
            $this->store();
        }
    }
}

sub load
{
    my $this = shift;
    my $dh;
    my @files;
    opendir( $dh, "." . $DIV . "items" );
    if ( defined $dh )
    {
        @files = readdir($dh);
        closedir $dh;
        foreach my $file (@files)
        {
            if ( $file =~ /\A(.*)\.txt\Z/ )
            {
                my $fh;
                open( $fh, "." . $DIV . "items" . $DIV . $file );
                $file = lc($1);
                $this->log( "INIT", "Loading items from $file" );
                foreach my $line (<$fh>)
                {
                    my ($name) = ( $line =~ /\[(.*)\]/ );
                    chomp($line);
                    $name = lc($name);
                    $this->{ITEMS}->{$name} = $line;

                    #$this->log("DEBUG", "Loaded $name as $this->{ITEMS}->{$name}");
                }
                close($fh);
            }
        }
    } else
    {
        $this->{ITEMS} = undef;
    }
}

sub store
{
    my $this = shift;
    $this->load();
    my $fh;
    open( $fh, ">", "." . $DIV . "items" . $DIV . "capture.txt" );
    $this->log( "WRITE", "Commiting items to capture.txt" );
    foreach my $key ( sort keys %{ $this->{ITEMS} } )
    {

        #$this->log("DEBUG", "Saving $this->{ITEMS}->{$key}");
        print $fh $this->{ITEMS}->{$key} . "\n";
    }
    $this->log( "WRITE", "Finnished Commit" );
    close($fh);
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
