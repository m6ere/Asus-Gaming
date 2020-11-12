package AO::Core::Bot;

#============================= Version information ============================#
use vars qw($VERSION $AUTOLOAD);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use Switch 'Perl6';    #used for switch/when statements
use AO::Chat::Constants;
use Data::Dumper;
use English;
use Carp;
use AO::Core::DB::SQLite;

sub new
{
    my $class = shift;
    my $this = bless {}, $class;
    $this->{log}      = shift;
    $this->{settings} = shift;

    #$this->log(Dumper($this->{settings}));
    return undef unless ( defined $this->validate() );
    foreach my $type ( TELL, TELL, GROUP_GUILD, GROUP_PRIVATE, GROUP_OTHER, SAY, SYSTEM, SAY_ANON )
    {
        $this->{subscribe}->{$type}->{commands} = {};
        $this->{subscribe}->{$type}->{any}      = [];
        $this->{subscribe}->{$type}->{items}    = [];
    }
    foreach my $type ( BUDDY_ONLINE, BUDDY_OFFLINE, RECENT_ONLINE, RECENT_OFFLINE, CONNECTED, DISCONNECTED, PG_INVITED, PG_KICKED, PG_JOINED, PG_LEFT, GROUP_JOINED, GROUP_LEFT, SHUTDOWN )
    {
        $this->{subscribe}->{$type}->{any} = [];
    }

    #initializing values that need to be defined
    $this->{sys_commands}      = qr(^.?(owner|settings|help|about));
    $this->{next_tell_offline} = 0;
    $this->{DB}                = AO::Core::DB::SQLite->new($this);
    return $this;
}

sub set_chat
{
    $_[0]->{CHAT} = $_[1];
}

sub chat
{
    return $_[0]->{CHAT};
}

sub offline
{
    my $this = shift;
    $this->{next_tell_offline} = 1;
}

sub subscribe
{
    my $this    = shift;
    my $plugin  = shift;
    my $type    = shift;
    my $command = shift;
    my $groups  = shift;
    if ( defined $command )
    {
        if ( $command =~ /$this->chat->{sys_commands}/ )
        {
            return undef;
        }
        unless ( defined $this->{subscribe}->{$type}->{commands}->{$command} )
        {
            $this->{subscribe}->{$type}->{commands}->{$command} = [];
        }
        unless ( defined $this->{rsubscribe}->{$command} )
        {
            $this->{rsubscribe}->{$command}->{$type} = [];
        }

        #store the foward lookup
        push @{ $this->{subscribe}->{$type}->{commands}->{$command} }, $plugin;

        #store the reverse lookup (required for help system)
        push @{ $this->{rsubscribe}->{$command}->{$type} }, $plugin;
    } else
    {
        unless ( defined $this->{subscribe}->{$type}->{any} )
        {
            $this->{subscribe}->{$type}->{any} = [];
        }
        push @{ $this->{subscribe}->{$type}->{any} }, $plugin;
    }
    return 1;
}

sub message_handler
{
    my $this = shift;

    #$this->log( "DEBUG", "Values are\n". Dumper([@_]) );
    my $type    = shift;
    my $person  = shift;
    my $group   = shift;
    my $message = shift;
    my %ignore;
    return undef unless ( defined $message );

    #first check if we are offline message
    if ( $this->{next_tell_offline} == 1 )
    {
        $this->{next_tell_offline} = 0;
        unless ( $this->{settings}->{allowoffline} == 1 )
        {
            $this->log( "IGNORE", "Ignoring offline tell" );
            return 1;
        }
    }
    my $prefix    = $this->{settings}->{core}->{prefix};
    my $prefixopt = $this->{settings}->{core}->{prefixopt}->{ $AO::Chat::Constants::DEBUG_NAMES{$type} };

    #check if we need to goto system commands first
    if ( $message =~ /$this->{sys_commands}/ )
    {
        if ( defined $prefixopt and not $message =~ /^\Q$prefix\E.*/ )
        {
            $message = $prefix . $message;
        }
        if ( $message =~ /^\Q$prefix\E.*/ )
        {
            $message = substr( $message, 1 );
            my $command;
            if ( $message =~ /\s/ )
            {
                ( $command, $message ) = ( $message =~ /^(\w+)\s+(.*)\Z/ );
            } else
            {
                $command = $message;
            }
            $this->log( "Message Handler", "System command $command Detected" );
            given ($command)
            {
                when "about"
                {
                    my $blob = "";
                    $blob .= "<FONT COLOR='#e6e64c'><B>pbot</B></FONT> version <FONT COLOR='#ffff66'>$VERSION</FONT> by <FONT COLOR='#aecf00'>Florence on Crom-EU</FONT>\n";
                    $blob .= "\n<FONT COLOR='#ffff66'>pbot</FONT> is Written in perl and can be run on any OS that has perl installed<BR>";
                    $blob .= "\nThis bot is running on <FONT COLOR='#e6ff00'>$OSNAME</FONT> with perl version <FONT COLOR='#e6ff00'>" . sprintf( '%vd', $PERL_VERSION ) . "</FONT>";
                    $blob .= "\nThe owner of this bot is <FONT COLOR='#e6ff00'>$this->{owner}</FONT>" if ( defined $this->{owner} );
                    $blob .= "\nyou may want the <a href='chatcmd:///tell <botname> " . $prefix . "help'>help system</a>";
                    $blob .= "\nmost reason update was a catch to allow the bot to restart if it stalls";
                    $this->send_output( $type, $person, $group, $this->make_blob( "about pbot", $blob ) );
                }
                when "help"
                {
                    my $blob = "";
                    $blob .= "<FONT COLOR='#aecf00'>Main Help Page</FONT>\n";
                    $blob .= "\nPlease note that the help system displays first the command, then the module that uses the command. The row below tells you what channel teh command will be responded ";
                    $blob .= "\n<font COLOR='#33CC33'>the bot will respond to commands in this colour</font>";
                    $blob .= "\n<font COLOR='#993300'>the bot will <b>not</b> respond to commands in this colour</font>\n";
                    my $help;

                    #building list, we should consider caching this information
                    #local $Data::Dumper::Maxdepth = 3;
                    #$this->log( "help", "DEBUG, dumping rsubscribe" . Dumper($this->{rsubscribe}) );
                    foreach my $command ( keys %{ $this->{rsubscribe} } )
                    {

                        foreach my $type ( keys %{ $this->{rsubscribe}->{$command} } )
                        {

                            local $Data::Dumper::Maxdepth = 2;

                            foreach my $plugin ( @{ $this->{rsubscribe}->{$command}->{$type} } )
                            {
                                $help->{$command}->{ $plugin->get_name() } = {
                                    AO::Chat::Constants::TELL        => 0,
                                    AO::Chat::Constants::GROUP_GUILD => 0,
                                    AO::Chat::Constants::GROUP_OTHER => 0,

                                    #AO::Chat::Constants::GROUP_PRIVATE => 0,
                                } unless ( defined $help->{$command}->{ $plugin->get_name() } );
                                $help->{$command}->{ $plugin->get_name() }->{$type} = 1;
                            }
                        }
                    }

                    #using list to populate help chart
                    foreach my $command ( sort keys %{$help} )
                    {
                        foreach my $plugin ( sort keys %{ $help->{$command} } )
                        {
                            $blob .= "\n<a href='chatcmd:///tell <botname> " . $prefix . "$command'>" . $prefix . "$command</a> - <FONT COLOR='#e6ff00'>$plugin</FONT>\n.           ";
                            foreach my $type ( sort keys %{ $help->{$command}->{$plugin} } )
                            {
                                if ( $help->{$command}->{$plugin}->{$type} == 1 )
                                {
                                    $blob .= " [<FONT COLOR='#33CC33'>";
                                } else
                                {
                                    $blob .= " [<FONT COLOR='#993300'>";
                                }
                                $blob .= $AO::Chat::Constants::DEBUG_NAMES{$type} . "</FONT>]";
                            }
                        }
                    }
                    $this->send_output( $type, $person, $group, $this->make_blob( "pbot help page", $blob ) );
                }
            }
        }
    } else
    {

        #dispatch to plugins that requested generic capture
        foreach my $plugin ( @{ $this->{subscribe}->{$type}->{any} } )
        {
            unless ( defined $ignore{$plugin} )
            {

                #$this->log( "Message Handler", "sending entire message to " . $plugin->get_plugin_name() );
                $plugin->message_handler( $type, $person, $group, $message );

                #$ignore{$plugin} = 1;
            }
        }

        #prefix command if it came in on a group that wanted it
        #$this->log( "COMMAND", "Detected Command $message" );
        if ( defined $prefixopt and not $message =~ /^\Q$prefix\E.*/ )
        {
            $message = $prefix . $message;
        }
        if ( $message =~ /^\Q$prefix\E.*/ )
        {
            $message = substr( $message, 1 );

            #message is clipped, now perform system commands
            my $command;
            if ( $message =~ /\s/ )
            {
                ( $command, $message ) = ( $message =~ /^(\w+)\s+(.*)\Z/ );
            } else
            {
                $command = $message;
                $message = undef;
            }
            $command = lc($command);
            if ( defined $this->{subscribe}->{$type}->{commands}->{$command} )
            {
                foreach my $plugin ( @{ $this->{subscribe}->{$type}->{commands}->{$command} } )
                {
                    unless ( defined $ignore{$plugin} )
                    {
                        $this->log( "Message Handler", "sending $command to " . $plugin->get_plugin_name() );
                        $plugin->message_handler( $type, $person, $group, $message, $command );
                    }
                }
            }
        }
    }
}

sub send_output
{
    my $this    = shift;
    my $type    = shift;
    my $person  = shift;
    my $group   = shift;
    my $message = shift;
    if ( length($message) > 10000 )
    {

        #message is to big to be handled by the server, attempting to split it up
        $this->log( "WARNING", "Message sent is larger than 10K(" . ( length($message) / 1024 ) . "Kb), Attempting to auto-split" );

        #mafoo's method, break up the message by double \n's then combine till we hit the 10#K, if that fails split on sinlge \n's
        #my @blobs;
        ##we need to extract all blobs
        #foreach my $blob ($message =~ /(.*)(<a href=\"text:\/\/.*\">.*<\/a>)(.*)/g)
        #{
        #
        #}
    }
    $person = $this->chat->player($person)->name() if ( defined $person );
    if ( $type & TELL )
    {
        $this->log( "OUT_TELL", $person . "->" . $message );
        $this->chat->player($person)->tell($message);
    }
    if ( $type & GROUP_GUILD )
    {
        $group = $this->chat->group( $this->chat->{ORG_ID} );
    } else
    {
        $group = $this->chat->group($group) if ( defined $group );
    }
    if ( $type & GROUP_GUILD )
    {
        $this->log( "OUT_GUILD", "->" . $message );
        $group->msg($message);
    }
    if ( $type & GROUP_OTHER )
    {
        $this->log( "OUT_GROUP", "[" . $group->name() . "]" . ">" . $message );
        $group->msg($message);
    }
    if ( $type & GROUP_PRIVATE )
    {
        $this->log( "OUT_PG_GROUP", "[" . $person . "]" . ">" . $message );
        $this->chat->player($person)->pgmsg($message);
    }
}

sub send_state
{
    my $this        = shift;
    my $type        = shift;
    my $destination = shift;
}

sub state_handler
{
    my $this   = shift;
    my $type   = shift;
    my @args   = @_;
    my $prefix = $this->{settings}->{core}->{prefix};

    #do the system specific stuff first
    if ( $type == CONNECTED_INIT )
    {

        #working out which group is the Guild Chat
        foreach my $group ( $this->chat->groups() )
        {
            $this->log( "INIT", "looking at group " . $group->name() . " id " . $group->id() );
            if ( $group->name() =~ /Guild/ )
            {
                $this->log( "INIT", "Identified Guild Group as Chat channel id " . $group->id() );
                $this->chat->{ORG_ID} = $group->id();
            } else
            {

                #$group->mute();
            }
        }
    }

    elsif ( $type == CONNECTED )
    {

        #working out which group is the Guild Chat
        foreach my $plugin ( keys %{ $this->{PLUGINS} } )
        {
            $this->{PLUGINS}->{$plugin}->function_handler(CONNECTED);
        }
        $this->log( "DEBUG", "Dumping settings\n" . Dumper( $this->{settings} ) );
        $this->log("pbot version $VERSION online");
        if ( $this->{settings}->{core}->{announce_online} == 1 )
        {
            my $blob = "<b>pbot</b> version $VERSION by Florence\n";
            $blob .= "\npbot is Written in perl and can be run on any OS that has perl installed\n";
            $blob .= "This bot is running on $OSNAME with perl version " . sprintf( '%vd', $PERL_VERSION ) . "\n";
            $blob .= "\nyou may want the <a href='chatcmd:///tell <botname> " . $prefix . "help'>help system</a>";
            $blob .= "\nor you may want the current <a href='chatcmd:///tell <botname> " . $prefix . "news'>news</a>";
            $this->send_output( GROUP_GUILD, undef, undef, "pbot now online " . $this->make_blob( "about pbot", $blob ) );
        }
    }

    foreach my $plugin ( @{ $this->{subscribe}->{$type}->{any} } )
    {
        $this->log( "State Handler", "sending State $AO::Chat::Constants::DEBUG_NAMES{$type} message to " . $plugin->get_plugin_name() );
        $plugin->state_handler( $type, @args );
    }
}

sub make_chatcommand
{
    my ( $this, $link, $title ) = @_;
    return '<a href=\'chatcmd:///' . $link . '\'>' . $title . '</a>';
}

sub make_item
{
    my ( $this, $lowid, $highid, $ql, $name ) = @_;
    return "<a href=\"itemref://" . $lowid . "/" . $highid . "/" . $ql . "\">" . $name . "</a>";
}

sub get_settings_page
{
    my $this = shift;

}

sub lag
{
    my $this = shift;
    my $lag  = shift;
    if ( $lag > 1 )
    {
        $this->log( "LAG", "Chat module reported $lag seconds of lag" );
    }
}

sub make_blob
{
    my $this    = shift;
    my $title   = shift;
    my $content = shift;
    my $botname = $this->chat->{ME}->name();
    $content =~ s/<botname>/$botname/g;
    $content =~ s/<pre>/$this->{settings}->{prefix}/g;

    #$content =~ s/\"/&quot;/g;
    return "<a href=\"text://" . $content . "\">" . $title . "</a>";
}

sub player
{

    #carp "argument 1 is undefined!" unless defined($_[1]);
    #$_[0]->log( "LOOKUP", "player lookup requested for $_[1]" );
    return $_[0]->chat->player( $_[1] );
}

sub log
{
    my $this   = shift;
    my $caller = scalar( caller() );
    my $sub    = "NO-ID";
    my $msg    = "Blank Message";
    if ( @_ == 1 )
    {
        $msg = shift;
    } elsif ( @_ == 2 )
    {
        ( $sub, $msg ) = @_;
    } elsif ( @_ == 3 )
    {
        ( $caller, $sub, $msg ) = @_;
    }
    $caller =~ s/AO::Core::Bot/CORE/;
    $caller =~ s/AO::Chat/CHAT/;
    $caller =~ s/AO::Chat::DB::/DB-/;
    $caller =~ s/AO::Plugins::/PL-/;
    $caller =~ s/AO::Core::DB::/DB-/;
    return $this->{log}->log( $caller, $sub, $msg );
}

#>this section sets the default options
#
# Any new varibles invented that can be configured should be defaulted here
# this should be the same for every module for anything configurable

sub get_defaults
{
    my $self = shift;
    return {
             prefix          => "!",
             announce_online => 1,
             prefixopt       => TELL,
             auto_owner      => 1,
    };
}

sub name
{
    return $_[0]->{settings}->{login}->{character};
}

sub validate
{
    my $self = shift;

    #check for required fileds
    foreach my $option ( 'username', 'password', 'server', 'character' )
    {
        unless ( exists $self->{settings}->{login}->{$option} )
        {
            $@ = "Validation of options failed for AO::Bot, missing required option under the login section for $option";
            return undef;
        }
    }

    #check that all fields pass validation
    foreach my $key ( keys %{ $self->{settings}->{login} } )
    {

        if ( $key =~ /\A(username|password|server|character)\z/ )
        {
            if ( $self->{settings}->{login}->{$key} =~ /\A\w+\z/ )
            {
            } else
            {
                if ( $self->{settings}->{login}->{$key} eq "" )
                {
                    $@ = "Validation of options failed for AO::Bot, $key must be a word";
                } else
                {
                    $@ = "Validation of options failed for AO::Bot, $key must be a word $self->{settings}->{login}->{$key}";
                }
                return undef;
            }
        } else
        {
            $@ = "Validation of options failed for AO::Bot, unrecognized option $key";
            return undef;
        }

        #}
    }

    #defaults
    #indicate the options have been parsed ok
    return 1;
}
1;
