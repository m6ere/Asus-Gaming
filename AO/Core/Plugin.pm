package AO::Core::Plugin;

#This is the base Plugin Class To allow easier plugin programing
# AUTO - Automatically set by this base class, don't set this unless you know what you are doing
# Structure of $this
# {base}                    All basic Attributes of the Class
#           {name}              Display name of module
#           {plugin_name}       Automatic name of the Plugin (AUTO)
#           {version}           The version of your module
#============================= Version information ============================#
use vars qw($VERSION $AUTOLOAD);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];

#================================== Imports ===================================#
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use Switch 'Perl6';    #used for switch/when statements
use AO::Chat::Constants;

#================================= callbacks ==================================#
sub subscribe
{
    my $this = shift;
    my $type;
    my $command;
    if ( @_ == 2 )
    {
        $type    = shift;
        $command = shift;
    } elsif ( @_ == 1 )
    {
        $type    = shift;
        $command = undef;
    }
    $this->{bot}->subscribe( $this, $type, $command );
}

#============================== new for package ===============================#
sub new
{
    my $class = shift;
    my $this = bless {}, $class;
    $this->{base}->{name}        = "Blank Plugin";
    $this->{base}->{version}     = "BASE " . $VERSION;
    $this->{base}->{plugin_name} = $class;
    $this->{base}->{plugin_name} =~ s/.*:://;
    $this->{bot} = shift;    #Bot class for all functions
    return $this;
}

#=============================== Log Functions ================================#
sub log
{
    my $this   = shift;
    my $caller = scalar( caller() );
    return $this->bot->log( $caller, @_ );
}

#=============================== Get Functions ================================#
sub get_name
{
    my $this = shift;
    return $this->{base}->{name};
}

sub bot
{
    return $_[0]->{bot};
}

sub AUTOLOAD
{
    my $this = shift;
    $AUTOLOAD =~ s/.*:://;

    #currently we are very lazy with the get functions, they should be hardcoded,
    #but because they are subject to change i am useing a autofetcher
    given ($AUTOLOAD)
    {
        when (/^get_(.*)$/)
        {
            my ($parameter) = ( $AUTOLOAD =~ /^get_(.*)$/ );
            return $this->{base}->{$parameter} if ( defined $this->{base}->{$parameter} );
        }
        default
        {
            return undef;
        }
    }
    return undef;
}

1;
