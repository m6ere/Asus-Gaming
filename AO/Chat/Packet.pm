package AO::Chat::Packet;

require 5.004;
use strict;
use warnings;
use AO::Chat::Constants;
use Switch 'Perl6';
use Data::Dumper;

our %PACKETS = (
    'IN' => {
        0    => { "Name" => "Login Seed",               "Params" => "S" },
        5    => { "Name" => "Login Result OK",          "Params" => "" },
        6    => { "Name" => "Login Result Error",       "Params" => "S" },
        7    => { "Name" => "Login CharacterList",      "Params" => "isii" },
        10   => { "Name" => "Client Unknown",           "Params" => "I" },
        20   => { "Name" => "Client Name",              "Params" => "IBS" },
        21   => { "Name" => "Name Lookup Result",       "Params" => "IS" },
        30   => { "Name" => "Message Private",          "Params" => "ISD" },
        34   => { "Name" => "Message Vicinity",         "Params" => "ISD" },
        35   => { "Name" => "Message Anon Vicinity",    "Params" => "SSD" },
        36   => { "Name" => "Message System",           "Params" => "S" },
        37   => { "Name" => "Some Wierd ass message",  "Params" => "IIIS" },
        40   => { "Name" => "Buddy Online",              "Params" => "IBBIB" },
        41   => { "Name" => "Buddy Offline",            "Params" => "I" },
        50   => { "Name" => "Privategroup Invited",     "Params" => "I" },
        51   => { "Name" => "Privategroup Kicked",      "Params" => "I" },
        53   => { "Name" => "Privategroup Part",        "Params" => "I" },
        55   => { "Name" => "Privategroup Client Join", "Params" => "II" },
        56   => { "Name" => "Privategroup Client Part", "Params" => "II" },
        57   => { "Name" => "Privategroup Message",     "Params" => "IISD" },
        60   => { "Name" => "Group Join",               "Params" => "GSID" },
        61   => { "Name" => "Group Part",               "Params" => "G" },
        65   => { "Name" => "Group Message",            "Params" => "GISD" },
        100  => { "Name" => "Pong",                     "Params" => "D" },
        110  => { "Name" => "Forward",                  "Params" => "IM" },
        1100 => { "Name" => "Adm Mux Info",             "Params" => "iii" },
        120 => { "Name" => "Buddy Control",                   "Params" => "uSS" },
            },
    'OUT' => {
               2   => { "Name" => "Login Response GetCharacterList", "Params" => "ISS" },
               3   => { "Name" => "Login Select Character",          "Params" => "I" },
               21  => { "Name" => "Name Lookup",                     "Params" => "S" },
               30  => { "Name" => "Message Private",                 "Params" => "ISsx" },
               40  => { "Name" => "Buddy Add",                       "Params" => "ID" },
               41  => { "Name" => "Buddy Remove",                    "Params" => "I" },
               42  => { "Name" => "Onlinestatus Set",                "Params" => "I" },
               50  => { "Name" => "Privategroup Invite",             "Params" => "I" },
               51  => { "Name" => "Privategroup Kick",               "Params" => "I" },
               52  => { "Name" => "Privategroup Join",               "Params" => "I" },
               54  => { "Name" => "Privategroup Kickall",            "Params" => "" },
               57  => { "Name" => "Privategroup Message",            "Params" => "ISD" },
               58  => { "Name" => "Privategroup Refuse",             "Params" => "II" },
               64  => { "Name" => "Group Data Set",                  "Params" => "GID" },
               65  => { "Name" => "Group Message",                   "Params" => "GSD" },
               66  => { "Name" => "Group Clientmode Set",            "Params" => "GIIII" },
               70  => { "Name" => "Clientmode Get",                  "Params" => "IG" },
               71  => { "Name" => "Clientmode Set",                  "Params" => "IIII" },
               100 => { "Name" => "Ping",                            "Params" => "D" },
               120 => { "Name" => "Buddy Control",                   "Params" => "sSSI" },
             }
);

our %online_flags = (
                      0 => "Status Offline",
                      1 => "Status Online",
                      2 => "Status Away",
                      3 => "Status Extendedaway"
                    );

our %group_flags = (
                     0x00000001 => "CantIgnores",
                     0x00000002 => "CantSend",
                     0x00000004 => "InviteOnly",
                     0x00000008 => "NoForward",
                     0x00000010 => "Temp",
                     0x00010000 => "Ignored",
                     0x01000000 => "User IsMuted",
                     0x02000000 => "User IsLogging"
                   );

sub new
{
    my ( $proto, $type, @params ) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless( $self, $class );
    unless ( defined( $self->{type} = $type ) )
    {
        warn "Missing type";
        return undef;
    }
    if ( $#params == -1 )
    {
        warn "Missing arguments";
        return undef;
    }
    if ( ref( $params[0] ) )
    {
        $self->{dir}   = "IN";
        $self->{param} = [];
        my $packinfo = ${ $PACKETS{'IN'} }{$type};
        if ( !$packinfo )
        {
            warn "Type $type not allowed incoming\n";
            return undef;
        }
        my $data = ${ $params[0] };

        #    $self->view($data);
        #print "Unpacking $type as $$packinfo{'Params'}";
        foreach my $param ( split( //, $$packinfo{'Params'} ) )
        {
            #print "$param";
            my $res;
            if ( $param eq "I" )
            {
                ( $res, $data ) = unpack( "Na*", $data );
            }
            elsif ( $param eq "S" )
            {
                ( $res, $data ) = unpack( "n/aa*", $data );
            }
            elsif ( $param eq "u" )
            {
                ( $res, $data ) = unpack( "na*", $data );
            }
            elsif ( $param eq "D" )
            {
                ( $res, $data ) = unpack( "n/aa*", $data );
            }
            elsif ( $param eq "B" )
            {
                $res = substr( $data, 0, 1 );
                $data = substr( $data, 1 );
                $res = ord($res);
            }
            elsif ( $param eq "G" )
            {
                ( $res, $data ) = unpack( "a5a*", $data );
                $res =~ s{(.)}{sprintf(q(%02X),ord($1))}ges;
                #$res = unpack( "q", $res);
                #my $number = "";
                #print "\nbefore decrypt " . str_to_hex($res) . "\n";
                #foreach my $char ( split( //, $res ) )
                #{
                #    print "\ndycrypting " . str_to_hex($char) . " as ". ord($char) . " as ". hex(ord($char)) . "\n";                   
                #    $number = hex( ord($char) ) . $number;
                #}
                #$res = $number;
                #print "after decrypt " . $res . "\n";
            }
            elsif ( $param eq "i" )
            {
                my $l;
                ( $l, $data ) = unpack( "na*", $data );
                my @res = unpack( "N" x $l, $data );
                $data = substr( $data, 4 * $l );
                $res = \@res;
            }
            elsif ( $param eq "s" )
            {
                my $l;
                ( $l, $data ) = unpack( "na*", $data );
                my @res;
                for ( my $i = 0; $i < $l; $i++ )
                {
                    my $sl;
                    ( $sl, $data ) = unpack( "n/aa*", $data );
                    push @res, $sl;
                }
                $res = \@res;
            }
            else
            {
                die "PANIC! Parameter type $param!\n";
            }
            push @{ $self->{param} }, $res;
        }
        #print "\n";
        #print "Values are\n".join("\n",@{ $self->{param} })."\n";
    }
    else
    {
        $self->{dir} = "OUT";
        my $packinfo = ${ $PACKETS{'OUT'} }{$type};
        if ( !$packinfo )
        {
            warn "Type $type not allowed outgoing\n";
            return undef;
        }
        my $param = $$packinfo{'Params'};
        #print "Packing type $type as $param\n";
        #print "Values are\n".join("\n",@params)."\n";
        #packing the number diff
        my $pos = -1;
        while(($pos = index($param, "G", $pos+1))>-1)
        {
            $params[$pos] =~ s{(..)}{chr(hex($1))}ges;
        }
        $param =~ s/I/N/g;
        $param =~ s/S/n\/a\*/g;
        $param =~ s/D/n\/a\*/g;
        $param =~ s/G/a5/g;
        $param =~ s/s/n/g;        
        $param =~ s/x/x/g;        
        my $data = pack( $param, @params );

        $self->{data} = $data;
    }
    #print "Created a packet of type $type going $self->{dir }\n";
    return $self;
}

sub view
{
    my $self = shift;
    my $data = shift;
    my $pc   = 0;
    my $ps   = "";

    my @array;
    for ( my $i = 0; $i < length($data); $i++ )
    {
        push @array, substr( $data, $i, 1 );
    }

    foreach my $x (@array)
    {
        my $v = ord($x);
        printf( "%02x ", $v );
        if ( ( $v < 127 ) && ( $v >= 32 ) )
        {
            $ps .= "$x";
        }
        else
        {
            $ps .= ".";
        }
        $pc++;
        if ( $pc == 0x10 )
        {
            print "$ps\n";
            $ps = "";
            $pc = 0;
        }
    }
    for ( ; $pc < 0x10; $pc++ )
    {
        print "   ";
    }
    print "$ps\n";
}

sub str_to_hex
{
    my $input = shift;
    $input=~s{(.)}{sprintf(q(%02X ),ord($1))}ges;
    return $input;
}
1;
