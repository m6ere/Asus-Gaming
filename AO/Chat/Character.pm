package AO::Chat::Character;

require 5.004;
use strict;
use warnings;

sub new
{
    my ( $proto, %params ) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};
    unless ( defined( $self->{id} = $params{'id'} ) )
    {
        warn "Missing ID";
        return undef;
    }
    $self->{name}   = $params{'name'};
    $self->{level}  = $params{'level'};
    $self->{online} = $params{'online'};
    bless( $self, $class );
    return $self;
}

1;
