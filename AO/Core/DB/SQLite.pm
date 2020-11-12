package AO::Core::DB::SQLite;

#============================= Version information ============================#
use vars qw($VERSION $AUTOLOAD);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use POSIX qw(strftime);
use AO::Chat::Constants;
use DBI;
use Carp;

#== bot class
sub new
{
    my $class = shift;
    my $this = bless {}, $class;
    $this->{bot} = shift;
    $this->log( "NEW", "Creating databse interface type for SQLite" );
    my $args    = shift;
    my $botname = $this->{bot}->{settings}->{login}->{character};

    #verify we had the options we were looking for

    $this->{CONNECT_STRING} = "dbi:SQLite:dbname=pbot.db";
    $this->{DB}             = DBI->connect( $this->{CONNECT_STRING} );
    unless ( defined $this->{DB} )
    {
        $this->log( "NEW", "Fatal, There was a problem attempting to connect to the database, the error reported was $@" );
        return undef;
    }
    $this->log( "NEW", "Connected to db" );

    #compile all of the options from all thier sources
    #first all of the core options
    #retrieve the default bot options
    return $this;
}

sub get_options
{
    my $this    = shift;
    my $class   = shift || "";
    my $botname = $this->bot->name();
    my $options = $this->bot->get_defaults();

    #local $SIG{__WARN__}=sub{}; # supresses warnings from dbd
    if ( $class ne "global" )
    {
        my $global_opts = $this->{DB}->selectall_hashref( "select * from options", "NAME" );
        unless ( defined $global_opts )
        {
            $this->log( "NEW", "Warning, Could not locate global options" );
            $global_opts = $this->bot->get_defaults();
            $this->{DB}->do("create table options ( NAME varchar, VALUE varchar )");
        }
        foreach my $key ( keys %{$global_opts} )
        {
            $options->{$key} = $global_opts->{$key};
        }
    }
    if ( $class ne "private" )
    {
        my $bot_opts = $this->{DB}->selectall_hashref( "select * from options_$botname", "NAME" );
        unless ( defined $bot_opts )
        {
            $this->log( "NEW", "Warning, Could not locate Bot specific options" );
            $bot_opts = {};
            $this->{DB}->do("create table options_$botname ( NAME varchar, VALUE varchar )");
        }
        foreach my $key ( keys %{$bot_opts} )
        {
            $options->{$key} = $bot_opts->{$key};
        }
    }
    return $options;
}

sub bot
{
    return $_[0]->{bot};
}

sub log
{
    return shift->{bot}->log(@_);
}
1;
