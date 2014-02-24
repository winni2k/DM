package DM::DistributeEngine;
use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use DM::TypeDefs;
use Carp;

has isSupported => ( is => 'ro', isa => 'Bool',     required => 1 );
has name        => ( is => 'ro', isa => 'engine_t', required => 1 );
has binCmd      => ( is => 'ro', isa => 'Str',      required => 1 );
has bin         => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    builder  => '_build_bin',
    lazy     => 1
);

sub _build_bin {
    my $self   = shift;
    my $binCmd = $self->binCmd;
    my $bin    = qx/$binCmd/;
    chomp $bin;
    return $bin;
}

__PACKAGE__->meta->make_immutable;
