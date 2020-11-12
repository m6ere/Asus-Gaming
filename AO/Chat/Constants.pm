package AO::Chat::Constants;
#provides contants to allow modules to talk
#AO::Chat modules to exchange message types without needing to know the underlying number

require 5.008;
require Exporter;
use warnings;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION %EXPORT_TAGS );

our ( @ISA, %EXPORT_TAGS, @EXPORT_OK, $AUTOLOAD, %DEBUG_NAMES, $CLASSES) = ();
my $constants;
my $more_constants;
my $classes;
our $SERVERS;
$VERSION = 'SVN.' . (qw$Revision: 0 $)[1];
@ISA = qw( Exporter );
@EXPORT_OK = ();

BEGIN
{
    $constants = {
                      TELL                    => 1,
                      GROUP_GUILD             => 2,
                      GROUP_PRIVATE           => 4,
                      GROUP_OTHER             => 8,
                      SAY                     => 16,
                      SYSTEM                  => 32,
                      SAY_ANON                => 155,
                      GROUP_SHARED            => 6,
                      BUDDY_OFFLINE           => 128,
                      BUDDY_ONLINE            => 129,
                      RECENT_ONLINE           => 130,
                      RECENT_OFFLINE          => 131,
                      CONNECTED               => 132,
                      DISCONNECTED            => 133,
                      PG_INVITED              => 140,
                      PG_KICKED               => 141,
                      PG_JOINED               => 142,
                      PG_LEFT                 => 143,
                      GROUP_JOINED            => 150,
                      GROUP_LEFT              => 151,
                      SHUTDOWN                => 152,
                      CONNECTED_INIT          => 153,
                      CONNECTED_GROUPS        => 154
                    };
    $more_constants = {
                      true                    => 1,
                      false                   => 0,
                      TRUE                    => 1,
                      FALSE                   => 0,
                    };
    $classes = {
                        "Conqueror" => 22,
                        "Dark Templar" => 31,
                        "Guardian" => 20,
                        "Bear Shaman" => 29,
                        "Priest of Mitra" => 24,
                        "Scoin of Set" => 26,
                        "Tempest of Set" => 28,
                        "Assassin" => 34,
                        "Barbarian" => 18,
                        "Ranger" => 39,
                        "Demonologist" => 44,
                        "Herald of Xotli" => 43,
                        "Lich" => 42,
                        "Necromancer" => 41,
                };
    $SERVERS = { 
    #European Servers 
        "Aries"         => { ip => "213.244.186.136",   port => "7011" }, 
        "Asgard"        => { ip => "213.244.186.136",   port => "7012" }, 
        "Asura"         => { ip => "213.244.186.136",   port => "7010" }, 
        "Aquilonia"     => { ip => "213.244.186.135",   port => "7008" }, 
        "Battlescar"    => { ip => "213.244.186.141",   port => "7023" }, 
        "Bori"          => { ip => "213.244.186.134",   port => "7004" }, 
        "Crom"          => { ip => "213.244.186.133",   port => "7001" }, 
        "Dagon"         => { ip => "213.244.186.133",   port => "7002" }, 
        "Ferox"         => { ip => "213.244.186.137",   port => "7014" }, 
        "Fury"          => { ip => "213.244.186.134",   port => "7005" }, 
        "Hyrkania"      => { ip => "213.244.186.141",   port => "7022" }, 
        "Ibis"          => { ip => "213.244.186.138",   port => "7018" }, 
        "Ishtar"        => { ip => "213.244.186.137",   port => "7013" }, 
        "Mitra"         => { ip => "213.244.186.135",   port => "7009" }, 
        "Soulstorm"     => { ip => "213.244.186.141",   port => "7024" }, 
        "Strix"         => { ip => "213.244.186.137",   port => "7014" }, 
        "Stygia"        => { ip => "213.244.186.137",   port => "7015" }, 
        "Titus"         => { ip => "216.244.186.139",   port => "7019" }, 
        "Wildsoul"      => { ip => "213.244.186.134",   port => "7006" }, 
        "Ymir"          => { ip => "213.244.186.133",   port => "7003" }, 
         
    #American Servers 
        "Bane"          => { ip => "208.82.194.8",      port => "7010" }, 
        "Bloodspire"    => { ip => "208.82.194.8",      port => "7012" }, 
        "Cimmeria"      => { ip => "208.82.194.9",      port => "7015" }, 
        "Deathwhisper"  => { ip => "208.82.194.8",      port => "7011" }, 
        "Dagoth"        => { ip => "208.82.194.5",      port => "7002" }, 
        "Dereketo"      => { ip => "208.82.194.6",      port => "7005" }, 
        "Doomsayer"     => { ip => "208.82.194.9",      port => "7013" }, 
        "Gwahlur"       => { ip => "208.82.194.7",      port => "7008" }, 
        "Omm"           => { ip => "208.82.194.6",      port => "7004" }, 
        "Thog"          => { ip => "208.82.194.6",      port => "7006" }, 
        "Tyranny"       => { ip => "208.82.194.7",      port => "7009" }, 
        "Set"           => { ip => "208.82.194.5",      port => "7001" }, 
        "Shadowblade"   => { ip => "208.82.194.12",     port => "7023" }, 
        "Wicanna"       => { ip => "208.82.194.7",      port => "7007" }, 
        "Zug"           => { ip => "208.82.194.5",      port => "7002" }, 
    }; 
}
use constant $constants;
@EXPORT = keys %{$constants}, keys %{$more_constants};
foreach my $key (keys %{$constants})
{
    if (defined $DEBUG_NAMES{$constants->{$key}})
    {
        $DEBUG_NAMES{$constants->{$key}} .= "," . $key;
    }else{
        $DEBUG_NAMES{$constants->{$key}} = $key;
    }
}
foreach my $key (keys %{$classes})
{
    my $class = $classes->{$key};
    $CLASSES->{$key} = $class;
    $CLASSES->{$class} = $key;
}

#------------------------------- END OF FUNCTIONS -------------------

# Auto EXPORT_OK
foreach my $et ( keys %EXPORT_TAGS )
{
    Exporter::export_ok_tags($et);
}

1;
