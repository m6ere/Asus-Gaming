#! /usr/bin/perl -w
# This is the main executeable (or script)
#============================= Version information ============================#
use vars qw($VERSION $AUTOLOAD);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;

use File::Glob qw ( bsd_glob );
use File::Spec qw ( catdir );
use ExtUtils::testlib;
use AO::Chat;
use AO::Core::Logger;
use AO::Core::Bot;
use AO::Chat::Constants;
use AO::Core::Utils qw(load_modules);
use Data::Dumper;
use Parser::INI;
use Getopt::Long;

#define our internal functions
#theese ahould not be used by modules as they are for loading purposes only
sub load_modules($;$$);
sub do_load_modules($$$;$);

#define our global varibles
my %plugins;
my $chat;
my $options;

# Main program
# Connects to the server, then starts processing packets.
# If the stream should close, it will wait 5 minutes then
# automatically reconnect

package main;

#fetch the configurtion file
my %cmd_options = ( config => 'pbot.conf', );
GetOptions( \%cmd_options, "config|c=s" );
if ( $cmd_options{help} )
{
    print "pbot.pl version $VERSION\n";
    print "usage: switcher [-config <filename>] [-verbose <level>] [-nodeamon]\n";
    print "\t-config <filename>\t- Alternative configuration file\n";
    exit 0;
}
unless ( -r $cmd_options{config} )
{

    #there is no defualt configuration file we need to create one
    warn "No configuration file found, setting up default";
    $options = {
        login => {
                   username  => "",
                   password  => "",
                   server    => "",
                   character => ""
        },
        core => {
                  prefix          => "!",
                  announce_online => 1,
                  allowoffline    => 0,
                  prefixopt       => {}
          }

    };

    #okies defaults set now i really should start a wizard to ask them what would
    #they like to use, but instead i am going to be arragant and tell them to edit the file

    #commiting the Options to file
    die "failed to setup options because $@"
      unless (
               my $options_object = Parser::INI->new(
                                                      {
                                                        file_format => "pathed_ini",
                                                        file_name   => $cmd_options{config},
                                                        init        => 1
                                                      },
                                                      $options
               )
      );
} else
{
    die "failed to get options" unless ( my $options_object = Parser::INI->new( { file_format => "pathed_ini", file_name => $cmd_options{config} } ) );
    $options = $options_object->get_data();
}

#setup the logger and Bot
my $log = AO::Core::Logger->new();
die "Could not create logger class because $@" unless ( defined $log );
my $bot = AO::Core::Bot->new( $log, $options );
unless ( defined $bot )
{
    $log->log( "FATAL", "Could not create bot class because $@" );
    exit 1;
}

local $SIG{ALRM} = sub {
    $log->log( "SAFETY", "Saftey timeout, aborting connection to allow reconnect" );
    if ( defined $chat )
    {
        $chat->{SOCKET}->disconnect();
    }
    alarm 300;
};

#$bot->{character} = $character;
$log->log( "CORE", "INIT", "Loading Modules" );

#load all the plugins
foreach my $plugin ( load_modules( ".", "AO::Plugins" ) )
{
    $plugin = $plugin->new($bot);
    $plugins{ $plugin->get_plugin_name() } = $plugin;
    $log->log( "CORE", "INIT", "Plugin [" . $plugin->get_plugin_name() . "] Loaded" );
}

#init all the plugins (done as a seprate loop so a plugin can request if another one is present
#at a later date this will be redesigned to allow a plugin to request a dependancy is init() beforeitself
foreach my $plugin ( keys %plugins )
{
    $plugin = $plugins{$plugin};
    $plugin->init();
    $log->log( "CORE", "INIT", "Initialized [" . $plugin->get_plugin_name() . "] as [" . $plugin->get_name() . "]" );
    $bot->{PLUGINS}->{ $plugin->get_name() } = $plugin;
}

while (1)
{

    # And pass that instance to the Chat object.
    $log->log( "CORE", "INIT", "Creating Chat Class" );
    $bot->{STATE} = 0;
    $chat = AO::Chat->new( { Callback => $bot, Server => $bot->{settings}->{login}->{server} } );

    # Then connect, authenticate and login.

    $log->log( "CORE", "INIT", "Connecting..." );

    unless ( defined $chat )
    {
        $log->log( "CORE", "INIT", "Connection failed" );

        #        warn "Connection failed";
    } else
    {
        $log->log( "CORE", "INIT", "Connected" );
        my @chars = $chat->authenticate( $bot->{settings}->{login}->{username}, $bot->{settings}->{login}->{password} );
        if ( @chars && !defined $chars[0] )
        {
            warn "Wrong username or password";
        } else
        {
            $log->log( "CORE", "LOGIN", "Logging in..." );
            my $char;

            if ( $bot->{settings}->{login}->{character} )
            {
                foreach my $c (@chars)
                {
                    $bot->{security}->{groups}->{operators}->{$c} = 1;
                    if ( $$c{'name'} eq $bot->{settings}->{login}->{character} )
                    {
                        $char = $c;
                    }
                }
            } else
            {
                $char = $chars[0];
            }
            if ( !$char )
            {
                $log->log( "CORE", "LOGIN", "Character Not Found" );
            } elsif ( $$char{'online'} )
            {
                $log->log( "CORE", "LOGIN", "Chacter already logged on" );
            } elsif ( !$chat->login($char) )
            {
                $log->log( "CORE", "LOGIN", "Failed Login" );
            } else
            {

                $log->log( "CORE", "LOGIN", "Logged In" );
                $bot->{STATE} = CONNECTED_INIT;

                # Loop through packets as they arrive.
                $log->log( "CORE", "MAIN", "Looping..." );
                my $exit = 0;
                my $wibble;
                do
                {
                    alarm 300;
                } while ( $chat->packet() );
                $log->log( "CORE", "MAIN", "Stream disconnected" );
                $bot->state_handler(DISCONNECTED);
            }
        }
    }

    $log->log( "CORE", "INIT", "Sleeping 5 minutes..." );
    alarm 330;
    sleep(300);
}

#====================== Functions ============#

#thease will be moved to a lib when done
