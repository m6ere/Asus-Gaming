package AO::Chat;

require 5.004;
use vars qw($VERSION $AUTOLOAD);
$VERSION = 'SVN.' . (qw$Revision: 1 $)[1];
use strict;
use warnings;
use IO::Socket::INET;
use AO::Chat::Packet;
use AO::Chat::Character;
use AO::Chat::Player;
use AO::Chat::Group;
use AO::Chat::Constants;
use Carp qw(cluck confess);
use Data::Dumper;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use AO::Chat ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [qw()] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.08';

our $MathClass   = 'Math::BigInt';
our $MathLibrary = 'Math::BigInt';
my $mathok = 0;

eval {
    require Crypt::Random;
    import Crypt::Random;
};

eval {
    require Math::BigInt;
    local $SIG{__WARN__}=sub{}; # supresses warnings as it makes people panic somethign is wrong
    import Math::BigInt lib => 'Pari,GMP';
    my $mathtest = new $MathClass(0);
    my $cfg      = $mathtest->config;
    if ( ( $$cfg{'lib'} eq 'Math::BigInt::GMP' ) || ( $$cfg{'lib'} eq 'Math::BigInt::Pari' ) )
    {
        $mathok = 1;
    }
    $MathLibrary = $$cfg{'lib'};
};

if ( !$mathok )
{
    eval {
        require Math::Pari;
        import Math::Pari;
        $MathClass   = 'Math::Pari';
        $MathLibrary = 'Math::Pari';
        $mathok      = 1;
    };
}

if ( !$mathok )
{
    eval {
        require Math::BigInt;
        import Math::BigInt;
        $mathok = 1;
        #no longer necesary to warn people, computers are so powerful now this is no longer a issue
        #warn 'Failed to find either of Math::BigInt::GMP, Math::BigInt::Pari or Math::Pari, calculating the authentication will take a long time';
    };
}

if ( !$mathok )
{
    die "Couldn't load ANY math libraries, not even Math::BigInt";
}

our @colors = ( [ 24, 'Red', 0xFF0000 ], [ 9, 'Pink', 0xFF009C ], [ 31, 'Violet', 0xFF00FF ], [ 8, 'Lime', 0x08F708 ], [ 19, 'AtazGreen', 0x00DE42 ], [ 6, 'Forest', 0x00A552 ], [ 7, 'Ocean', 0x63E78C ], [ 20, 'Leaf', 0x63AD63 ], [ 14, 'TakrelBlue', 0x0000FF ], [ 4, 'Sky', 0x00FFFF ], [ 1, 'Blue', 0x3EDAF9 ], [ 27, 'Purply', 0x8CB5FF ], [ 22, 'Teal', 0x9CD6DE ], [ 16, 'Yellow', 0xFFFF00 ], [ 5, 'Yellowish', 0xFFFF42 ], [ 18, 'Yellowy', 0xDEDE42 ], [ 29, 'LightTan', 0xFFE7A5 ], [ 17, 'Tan', 0xCEAD42 ], [ 3, 'Ivory', 0xFFFFCE ], [ 10, 'Camo', 0x9C9C21 ], [ 11, 'DurxBlack', 0x000000 ], [ 15, 'White', 0xFFFFFF ], [ 25, 'Grey', 0xDEDED6 ] );

# Preloaded methods go here.

sub hexToBigInt($)
{
    my ($v) = @_;
    my $r   = new $MathClass(0);
    my $one = new $MathClass(1);
    foreach my $char ( split( //, $v ) )
    {
        $r = $r << new $MathClass(4);
        my $part = int( hex $char );
        $r = $r + ( $part * $one );
    }
    return $r;
}

sub bigIntToHex($)
{
    my ($v) = @_;
    my $val = $v;
    my $r   = '';
    while ( $val > 0 )
    {
        my $idx = ( $val % 16 );
        $r = sprintf( '%x', $idx ) . $r;
        $val = new $MathClass( $val >> new $MathClass(4) );
    }
    return $r;
}

# I originally used Math::Pari's lift() function to do this, but my testers
# had problems getting Math::Pari to compile :(
# So.. This new exp_mod has been
# shamelessly ripped from http://www.xs4all.nl/~johnpc/Talks/Anon-Electronics/

sub mod_exp
{
    my ( $i, $j, $n ) = @_;

    if ( $MathLibrary eq 'Math::Pari' )
    {
        my $m = Math::Pari::Mod( $i, $n );
        return Math::Pari::lift( $m**$j );
    }
    elsif ( ( $MathLibrary eq 'Math::BigInt::GMP' ) || ( $MathLibrary eq 'Math::BigInt::Pari' ) )
    {
        return $i->bmodpow( $j, $n );
    }

    my $result = $i - $i + 1;    # 1, but in the same type as $i
    return $result unless $j;

    my $pow2 = $i;

    while (1)
    {
        if ( $j % 2 )
        {
            $result = ( $pow2 * $result ) % $n;
            return $result unless --$j;
        }
        $j /= 2;
        $pow2 = ( $pow2 * $pow2 ) % $n;
    }
}

sub randoctet($)
{
    my ($length) = @_;

    my $s;

    eval { $s = Crypt::Random::makerandom_octet( Length => $length, Strength => 0 ); };
    if ($@)
    {
        for ( my $i = 0; $i < $length; $i++ )
        {
            $s .= pack( 'C', rand(0x100) );
        }
    }
    return $s;
}

sub permute(\@\@)
{
    my ( $key, $source ) = @_;
    if ( ( $#{$key} != 1 ) || ( $#{$source} != 3 ) )
    {
        confess 'Wrong keylength or sourcelength';
    }

    use integer;

    my $i1 = $$key[0];
    my $j1 = $$key[1];
    my $k  = 0;
    my $i2 = 0x9e3779b9;
    for ( my $j2 = 32; $j2-- > 0; )
    {
        $k  += $i2;
        $i1 += ( ( $j1 << 4 ) + $$source[0] ) ^ ( $j1 + $k ) ^ ( ( $j1 >> 5 & 0x07ffffff ) + $$source[1] );
        $j1 += ( ( $i1 << 4 ) + $$source[2] ) ^ ( $i1 + $k ) ^ ( ( $i1 >> 5 & 0x07ffffff ) + $$source[3] );
    }
    $$key[0] = $i1;
    $$key[1] = $j1;
}

sub encrypt($$)
{
    my ( $key, $text ) = @_;
    if ( length($key) != 32 )
    {
        confess "Key isn''t 32 characters";
    }
    if ( ( length($text) % 8 ) != 0 )
    {
        confess "Text isn't 8-byte aligned";
    }
    my @key;
    for ( my $i = 0; $i < 4; $i++ )
    {
        $key[$i] = unpack( 'V', pack( 'N', hex substr( $key, 8 * $i, 8 ) ) );
    }

    my $length = length($text);
    my @input = unpack( 'V*', $text );

    my @prev;
    $prev[0] = 0;
    $prev[1] = 0;

    my $crypted = '';

    for ( my $i = 0; $i < ( $length / 4 ); $i += 2 )
    {
        my @now;
        $now[0] = $input[$i];
        $now[1] = $input[ $i + 1 ];
        $now[0] ^= $prev[0];
        $now[1] ^= $prev[1];
        permute( @now, @key );
        $prev[0] = $now[0];
        $prev[1] = $now[1];
        $crypted .= sprintf( '%08x%08x', unpack( 'V', pack( 'N', $now[0] ) ), unpack( 'V', pack( 'N', $now[1] ) ) );
    }
    return $crypted;
}

sub genLoginKey($$$)
{
    my ( $servkey, $uname, $pw ) = @_;

    my $n        = hexToBigInt('eca2e8c85d863dcdc26a429a71a9815ad052f6139669dd659f98ae159d313d13c6bf2838e10a69b6478b64a24bd054ba8248e8fa778703b418408249440b2c1edd28853e240d8a7e49540b76d120d3b1ad2878b1b99490eb4a2a5e84caa8a91cecbdb1aa7c816e8be343246f80c637abc653b893fd91686cf8d32d6cfe5f2a6f');
    my $othermod = hexToBigInt('9c32cc23d559ca90fc31be72df817d0e124769e809f936bc14360ff4bed758f260a0d596584eacbbc2b88bdd410416163e11dbf62173393fbc0c6fefb2d855f1a03dec8e9f105bbad91b3437d8eb73fe2f44159597aa4053cf788d2f9d7012fb8d7c4ce3876f7d6cd5d0c31754f4cd96166708641958de54a6def5657b9f2e92');
    my $modulus  = hexToBigInt('5');

    my $clientkey = unpack( 'H32', randoctet(16) );

    my $clikey = hexToBigInt($clientkey);

    my $crypted_key = mod_exp( $modulus, $clikey, $n );

    my $secret = $uname . '|' . $servkey . '|' . $pw;
    my $cryptkey = unpack( 'A32', pack( 'A*', bigIntToHex( mod_exp( $othermod, $clikey, $n ) ) ) );

    my $tocrypt = pack( 'a8N/a*', randoctet(8), $secret );

    my $len = length($tocrypt);
    my $left = 8 - ( $len % 8 );
    if ( $left != 8 )
    {
        $tocrypt .= ' ' x $left;
    }

    my $crypted = encrypt( $cryptkey, $tocrypt );

    return bigIntToHex($crypted_key) . '-' . $crypted;
}

sub group
{
    my ( $self, $lookup ) = @_;
    return ${ $self->{GID} }{$lookup};
}

sub player
{
    my ( $self, $lookup ) = @_;
    if ( ref $lookup && $lookup->isa('AO::Chat::Player') )
    {
        return $lookup;
    }
    my $val = ${ $self->{ID} }{$lookup};
    if ( defined $val )
    {
        return $val;
    }
    if ( !$lookup )
    {
        cluck('Missing $lookup!');
    }
    if ( ${ $self->{NID} }{$lookup} )
    {
        if ( ( time - ${ $self->{NID} }{$lookup} ) > 5 )
        {
            ${ $self->{NID} }{$lookup} = undef;
        }
        else
        {
            return undef;
        }
    }
    if ( ( $lookup =~ /^[0-9]+$/ ) || $self->{STATE} ne 'OK' )
    {
        return undef;
    }
    #$self->log( "LOOKUP", "player lookup requested for $lookup" );
    $self->send( new AO::Chat::Packet( 21, $lookup ) );
    my $p;
    do
    {
        $p = $self->packet();
    } while ( $p && !${ $self->{ID} }{$lookup} && !${ $self->{NID} }{$lookup} );
    #$self->{CB}->log( "LOOKUP", "lookup found as " . Dumper(${ $self->{ID} }{$lookup}));
    return ${ $self->{ID} }{$lookup};
}

sub kickall
{
    my ($self) = @_;
    $self->send( new AO::Chat::Packet(54) );
}

sub setafk
{
    my ( $self, $afk ) = @_;
    $self->send( new AO::Chat::Packet( 42, ( $afk ? 2 : 1 ) ) );
}

sub ping
{
    my ($self) = @_;
    my $time = time;
    $self->send( new AO::Chat::Packet( 100, $time ) );
    $self->{LASTPING} = $time;
    push @{ $self->{PINGQUEUE} }, $time;
}

sub packet
{
    my $self = shift;
    my $rin  = '';
    vec( $rin, fileno( $self->{SOCKET} ), 1 ) = 1;
    my $nfound = 0;
    do
    {
        if ( $self->{STATE} eq 'OK' && ( $self->lastping() > 60 ) )
        {
            $self->ping();
        }

        my $timeout = 15;

        while ( ( $self->queuelength > 0 ) && ( time - ${ $self->{TELLTIME} }[0] >= 12 ) )
        {
            my $packet = shift @{ $self->{TELLQUEUE} };
            $self->send($packet);
            shift @{ $self->{TELLTIME} };
            push @{ $self->{TELLTIME} }, time;
        }
        if ( $self->queuelength > 0 )
        {
            $timeout = 12 - ( time - ${ $self->{TELLTIME} }[0] );
        }

        my $rout = $rin;
        my $eout = $rin;
        my $timeleft;
        ( $nfound, $timeleft ) = select( $rout, undef, $eout, $timeout );
        if ( !$nfound )
        {
            $self->ping();
        }
    } while ( !$nfound && ( time - $self->{LASTMSG} ) < 120 );

    if ( ( time - $self->{LASTMSG} ) >= 120 )
    {
        cluck 'Timeout';
        $self->{SOCKET}->shutdown(2);
        return undef;
    }

    $self->{LASTMSG} = time;

    #orginal read routines could not cope with data being split over avalibile reads
    #(i.e. data being split over multiple packets that had not arrived yet)
    # Thease revised routines will now keep reading till it gets what it wants
    #and only barf at a decode problem or stream disconnect

    #Header Read routine
    my $packet_size = 4;
    my $packet_buffer;
    my $packet_read;
    my $data_buffer = "";
    my $type        = 0;
    do
    {

        #read what i want from the socket
        $packet_read = $self->{SOCKET}->sysread( $packet_buffer, $packet_size );
        unless ( defined $packet_read )
        {

            #There was a problem on the socket, we need a clean disconnect
            cluck "Stream Error -- $!";
            return undef;
        }
        else
        {

            #data was read from the socket
            #(reading 0 is fine, it just means packet has not arrived yet)
            #we should consider a break out on a 0 because there is insuffciant
            #data and we want to return to the select loop to allow outgoing while we are waiting
            $data_buffer .= $packet_buffer;
            $packet_size = $packet_size - $packet_read;
        }
    } until ( $packet_size == 0 );
    ( $type, $packet_size ) = unpack( 'nn', $data_buffer );
    $data_buffer = "";
    do
    {

        #read what i want from the socket
        $packet_read = $self->{SOCKET}->sysread( $packet_buffer, $packet_size );
        unless ( defined $packet_read )
        {

            #There was a problem on the socket, we need a clean disconnect
            cluck "Stream Error -- $!";
            return undef;
        }
        else
        {

            #data was read from the socket
            #(reading 0 is fine, it just means packet has not arrived yet)
            #we should consider a break out on a 0 because there is insuffciant
            #data and we want to return to the select loop to allow outgoing while we are waiting
            $data_buffer .= $packet_buffer;
            $packet_size = $packet_size - $packet_read;
        }
    } until ( $packet_size == 0 );
    #$self->{CB}->log("CORE", "RAW", str_to_hex($data_buffer));
    my $p = new AO::Chat::Packet( $type, \$data_buffer );

    my @args = @{ $p->{param} };
    #{
    #    my $temp = "Hex Arguments are";
    #    foreach my $arg (@args)
    #    {
    #        $temp .= "\n" . str_to_hex($arg);
    #    }
    #    $self->{CB}->log("CORE", "conv", $temp);
    #}
    #$self->{CB}->log("CORE", "DECODE", "Packet is a Type $type and $packet_size bytes");
    #$self->{CB}->log("CORE", "DECODE", "Packet coded is " . $PACKETS{IN}->{$type}->{Params});
    #{
    #    my $temp = "Str Arguments are";
    #    foreach my $arg (@args)
    #    {
    #        $temp .= "\n" . $arg;
    #    }
    #    $self->{CB}->log("CORE", "conv", $temp);
    #}
    #see if we are init or connected
    if ($self->{CB}->{STATE} == CONNECTED_INIT && $self->{LAST_PACKET_TYPE} == 60)
    {
        $self->{CB}->{STATE} = CONNECTED_GROUPS;
    }
    if ( $type == 0 )
    {
        $self->{SERVERSEED} = $args[0];
    }
    elsif ( ( $type == 20 ) || ( $type == 21 ) )
    {
        my ( $id, $namer, $name ) = @args;
        $name = $namer unless(defined $name);
        #print "name resolve type $type in for $id who is $name!\n";
        my $player = new AO::Chat::Player( $self, $id, $name );
        if ( !$player )
        {
            ${ $self->{NID} }{$name} = time;
        }
        else
        {
            ${ $self->{ID} }{$id}   = $player;
            ${ $self->{ID} }{$name} = $player;
            if ( $id == $self->{ME}->{ID} )
            {
                $self->{ME} = $player;
            }
        }
    }
    elsif ( $type == 60 )
    {
        my ( $gid, $name, $flags ) = @args;
        my $group = new AO::Chat::Group( $self, $gid, $name, $flags );
        ${ $self->{GID} }{$gid}  = $group;
        ${ $self->{GID} }{$name} = $group;
    }
    elsif ( $type == 100 )
    {
        my ($time) = @args;
        shift @{ $self->{PINGQUEUE} };
        $self->{LAG} = time - $time;
    }

    if ( defined( $self->{SUB} ) )
    {
        $self->{SUB}( $type, @args );
    }
    if ( defined( $self->{CB} ) )
    {
        if ( $type == 30 )
        {
            my ( $playerid, $msg, $blob ) = @args;
            unless($playerid eq $self->{ME}->{ID})
            {
                $self->log( "INC_TELL", $self->player($playerid)->name() . "->" . $msg );
                $self->{CB}->message_handler( TELL, $self->player($playerid)->name(), undef, $msg );
            }
        }
        elsif ( $type == 34 )
        {
            my ( $playerid, $msg, $blob ) = @args;
            unless($playerid eq $self->{ME}->{ID})
            {
                $self->log( "INC_SAY", $self->player($playerid)->name() . "->" . $msg );
                $self->{CB}->message_handler( SAY, $self->player($playerid)->name(), undef, $msg );
            }
        }
        elsif ( $type == 35 )
        {
            my ( undef, $msg, $blob ) = @args;
            $self->log( "INC_ANON", $msg );
            $self->{CB}->message_handler( SAY_ANON, undef, undef, $msg );
        }
        elsif ( $type == 36 )
        {
            my ($msg) = @args;
            $self->log( "SYSTEM", $msg );
            $self->{CB}->message_handler( SYSTEM, undef, undef, $msg );
        }
        elsif ( $type == 37 )
        {

            # this one needs work
            $self->log( "INC_OFFLINE", "Next tell message was Sent while you were offline (" . $self->{CB}->player($args[0])->name() . ")" );
            #$self->{CB}->offline();
        }
        elsif ( $type == 40 )
        {
            my ( $playerid, $online, $level, $state, $class ) = @args;
            #$self->log("DEBUG", "online[".ord($online) . "] listed[" . ord($listed). "]");
            my $name = $self->player($playerid)->name();
            unless(@args == 2)
            {
                $self->player($playerid)->whois($online, $level, $state, $class);
                $self->log( "DEBUG", "Class is $class" );
                $self->log( "BUDDY_ONLINE", "$name is $level " . $AO::Chat::Constants::CLASSES->{$class} . " and is in PF $state" );
                $self->{CB}->state_handler( BUDDY_ONLINE, $name, @args);
            }else{
                $self->log( "BUDDY_ONLINE", "$name" );
                $self->{CB}->state_handler( BUDDY_ONLINE, $name);
            }
            #print "name resolve type $type in for $id who is $name!\n";
        }
        elsif ( $type == 41 )
        {
            my ( $playerid ) = @args;
            my $name = $self->player($playerid)->name();
            $self->log( "BUDDY_OFFLINE", "$name is offline" );
            $self->{CB}->state_handler( BUDDY_OFFLINE, $name, @args);
        }
        elsif ( $type == 50 )
        {
            my ($privplayerid) = @args;
            $self->log( "PG_INVITED", $self->player($privplayerid)->name() . " is inviting you to thier group" );
            $self->{CB}->state_handler( PG_INVITED, $self->player($privplayerid)->name() );
        }
        elsif ( $type == 51 )
        {
            my ($privplayerid) = @args;
            $self->log( "PG_KICKED", "You were kicked from " . $self->player($privplayerid)->name() . "'s group" );
            $self->{CB}->state_handler( PG_KICKED, $self->player($privplayerid)->name() );
        }
        elsif ( $type == 53 )
        {
            my ($privplayerid) = @args;
            $self->log( "PG_LEFT", "You left " . $self->player($privplayerid)->name() . "'s group" );
            $self->{CB}->state_handler( PG_LEFT, $self->player($privplayerid)->name() );
        }
        elsif ( $type == 55 )
        {
            my ( $privplayerid, $playerid ) = @args;
            my $player = $self->player($playerid)->name();
            my $pg_group = $self->player($privplayerid)->name();
            $self->log( "PG_JOINED", $player . " joined " . $pg_group . "'s group" );
            $self->{CB}->state_handler( PG_JOINED, $player, $pg_group );
        }
        elsif ( $type == 56 )
        {
            my ( $privplayerid, $playerid ) = @args;
            $self->log( "PG_LEFT", $self->player($playerid)->name() . " left " . $self->player($privplayerid)->name() . "'s group" );
            $self->{CB}->state_handler( PG_LEFT, $self->player($privplayerid)->name(), $self->player($playerid)->name() );
        }
        elsif ( $type == 57 )
        {
            my ( $privplayerid, $playerid, $msg, $blob ) = @args;
            $self->log( "INC_PGROUP[" . $self->player($privplayerid)->name() . "]", $self->player($playerid)->name() . "->" . $msg );
            $self->{CB}->message_handler( GROUP_OTHER, $self->player($playerid)->name(), $self->player($privplayerid)->name(), $msg );
        }
        elsif ( $type == 60 )
        {
            my ($groupid) = @args;
            $self->log( "GROUP_JOINED", "You joined " . $self->group($groupid)->name() . "'s group" );
            $self->{CB}->state_handler( GROUP_JOINED, $self->group($groupid)->name() );
        }
        elsif ( $type == 61 )
        {
            my ($groupid) = @args;
            $self->log( "GROUP_LEFT", "You left " . $self->group($groupid)->name() . "'s group" );
            $self->{CB}->state_handler( GROUP_LEFT, $self->group($groupid)->name() );
        }
        elsif ( $type == 65 )
        {
            #$self->log( "INC_GROUP_RAW", join( ", ", @args ) );
            my ( $groupid, $playerid, $msg, $blob ) = @args;
            unless($playerid eq $self->{ME}->{ID})
            {
                if ( defined $self->{ORG_ID} && $groupid eq $self->{ORG_ID})
                {
                    $self->log( "INC_GUILD", $self->player($playerid)->name() . "->" . $msg );
                    $self->{CB}->message_handler( GROUP_GUILD, $self->player($playerid)->name(), undef, $msg );
                } else {
                    #internally blocking other groups for now
                    #$self->log( "INC_GROUP[" . $self->group($groupid)->name() . "]", $self->player($playerid)->name() . "->" . $msg );
                    $self->{CB}->message_handler( GROUP_OTHER, $self->group($groupid)->name(), $self->player($playerid)->name(), $msg );
                }
            }
        }
        elsif ( $type == 100 )
        {
            $self->{CB}->lag( $self->{LAG} );
        }
        elsif ( $type == 0 || $type == 5 || $type == 6 || $type == 7 || $type == 20 || $type == 21 )
        {

            # Internal packets for login and character ID lookups
        }
        else
        {
            warn "Unhandled packet type $type in AO::Chat::packet(), please contact the author";
            print Dumper(@args);
        }
        $self->{LAST_PACKET_TYPE} = $type;
        if ($self->{CB}->{STATE} == CONNECTED_GROUPS && $type != 60)
        {
            $self->{CB}->{STATE} = CONNECTED;
            $self->log( "INIT", "Running Core Init" );
            $self->{CB}->state_handler(CONNECTED_INIT);
            $self->log( "INIT", "Running Plugin Init" );
            $self->{CB}->state_handler(CONNECTED);
        }
        return $p;
    }
}

sub lag
{
    my ($self) = @_;
    my $a = $self->{LAG};
    if ( $#{ $self->{PINGQUEUE} } != -1 )
    {
        my $b = time - ${ $self->{PINGQUEUE} }[0];
        if ( $b > $a )
        {
            return $b;
        }
    }
    return $a;
}

sub lastping
{
    my ($self) = @_;
    return time - $self->{LASTPING};
}

sub me
{
    my ($self) = @_;
    return $self->{ME};
}

sub groups
{
    my ($self) = @_;
    my %grp;
    foreach my $grp ( values %{ $self->{GID} } )
    {
        $grp{ $grp->{ID} } = $grp;
    }
    return ( values %grp );
}

sub send
{
    my ( $self, $packet ) = @_;
    if ( !$packet->isa('AO::Chat::Packet') || ( $$packet{'dir'} ne 'OUT' ) )
    {
        cluck "Can't send nonpackets";
        return undef;
    }
    use bytes;
    my $data = pack( 'nn/a*', $packet->{type}, $packet->{data} );
    my $written = $self->{SOCKET}->syswrite( $data, length($data) );
    return $packet;
}

sub queue
{
    my ( $self, $packet ) = @_;
    push @{ $self->{TELLQUEUE} }, $packet;
}

sub queuelength
{
    my ($self) = @_;
    return $#{ $self->{TELLQUEUE} } + 1;
}

sub new
{
    my $proto = shift;
    my $params = shift;
    #%params = ( 'Server' => '213.244.186.133', 'Port' => '7001', %params );
    my $class = ref($proto) || $proto;
    my $self = {};
    #local $Data::Dumper::Maxdepth = 3;
    #print Dumper($params);
    my $ref = $AO::Chat::Constants::SERVERS->{ucfirst($params->{'Server'})};
    $self->{SERVER}     = $ref->{ip};
    $self->{PORT}       = $ref->{port};
    #print Dumper($ref);
    #print Dumper($self);
    $self->{SUB}        = $params->{'Sub'};
    $self->{CB}         = $params->{'Callback'};
    $self->{CB}->{CHAT} = $self;
    $self->{SOCKET}     = new IO::Socket::INET( PeerAddr => $self->{SERVER}, PeerPort => $self->{PORT}, Proto => 'tcp' ) or return undef;
    $self->{ID}         = {};
    $self->{GID}        = {};
    $self->{LAG}        = 3600;
    $self->{LASTPING}   = 0;
    $self->{PINGQUEUE}  = [];
    $self->{TELLTIME}   = [ 0, 0, 0 ];
    $self->{TELLQUEUE}  = [];
    $self->{STATE}      = 'Connect';
    $self->{LASTMSG}    = time;
    $self->{INIT}       = 0;
    bless( $self, $class );
    my $p = $self->packet();

    if ( $$p{'type'} != 0 )
    {
        cluck 'GreetPacket not 0';
        return undef;
    }
    $self->{STATE} = 'Auth';
    return $self;
}

sub authenticate
{
    my ( $self, $uname, $pw ) = @_;
    if ( !defined($uname) || !defined($pw) )
    {
        cluck 'Missing username or password';
        return undef;
    }
    if ( $self->{STATE} ne 'Auth' )
    {
        cluck 'Not expecting authentication';
        return undef;
    }
    my $p = new AO::Chat::Packet( 2, 0, $uname, genLoginKey( $self->{SERVERSEED}, $uname, $pw ) );
    $self->send($p);
    $self->{LASTMSG} = time;
    my $rp = $self->packet();
    if ( $$rp{'type'} == 7 )
    {
        my @params = @{ $rp->{param} };
        my @chars;
        for ( my $i = 0; $i <= $#{ $params[0] }; $i++ )
        {
            my $c = new AO::Chat::Character( 'id' => ${ $params[0] }[$i], 'name' => ${ $params[1] }[$i], 'level' => ${ $params[2] }[$i], 'online' => ${ $params[3] }[$i] );
            push @chars, $c;
        }
        $self->{STATE} = 'Login';
        return @chars;
    }
    else
    {
        return undef;
    }
}

sub login
{
    my ( $self, $char ) = @_;
    if ( $self->{STATE} ne 'Login' )
    {
        cluck 'Not expecting a login';
        return undef;
    }
    if ( !$char->isa('AO::Chat::Character') )
    {
        cluck "Can't logon noncharacters";
        return undef;
    }
    my $p = new AO::Chat::Packet( 3, $$char{'id'} );
    $self->send($p);
    my $rp = $self->packet();
    if ( $$rp{'type'} != 5 )
    {
        return undef;
    }
    $self->{STATE} = 'OK';
    $self->{ME} = new AO::Chat::Player( $self, $$char{'id'}, $$char{'name'} );
    return 1;
}

sub log
{
    my $this = shift;
    $this->{CB}->log( @_ );
}
sub DESTROY
{
    #nothing to do for now
}

sub AUTOLOAD
{
    my $this = shift;
    $AUTOLOAD =~ s/.*:://;
    warn "Unknown function $AUTOLOAD";
    $this->log( "UNKNOWN", "Unknown function $AUTOLOAD" );
    return undef;
}

sub str_to_hex
{
    my $input = shift;
    $input=~s{(.)}{sprintf(q(%02X ),ord($1))}ges;
    return $input;
}

1;
