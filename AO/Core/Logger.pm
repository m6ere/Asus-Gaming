package AO::Core::Logger;

#============================= Version information ============================#
use vars qw($VERSION $AUTOLOAD);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];
use warnings FATAL => 'all', NONFATAL => 'syntax';
use strict;
use POSIX qw(strftime);

#== bot class
sub new
{
    my $class = shift;
    my $this = bless {}, $class;
    $this->log( "logger", "INIT", "Logger started" );
    return $this;
}

sub log
{
    my $this   = shift;
    my $module = scalar( caller() );
    my $part   = "UNKNOWN";
    my $msg    = "UNKNOWN";
    my @time   = localtime();
    my $time   = sprintf "%2s %2s %4s %02s:%02s:%02s", $time[3], $time[4] + 1, $time[5] + 1900, $time[2], $time[1], $time[0];
    if ( @_ == 1 )
    {
        $part = "UNKNOWN";
        $msg  = shift;
    } elsif ( @_ == 2 )
    {
        $part = shift;
        $msg  = shift;
    } else
    {
        $module = shift;
        $part   = shift;
        $msg    = shift;
    }
    printf '%s: %-12s %-20s "%s"' . "\n", $time, '"' . $module . '"', '"' . $part . '"', $msg;
    return 1;
}

sub DESTROY
{
    my $this = shift;
    $this->log( "logger", "DE-INIT", "Logger Stopped" );
    return 1;
}

1;
