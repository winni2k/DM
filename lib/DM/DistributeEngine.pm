package DM::DistributeEngine;
$DM::DistributeEngine::VERSION = '0.013'; # TRIAL
# ABSTRACT: Class to hold the information associated with an engine.

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

__END__

=pod

=encoding UTF-8

=head1 NAME

DM::DistributeEngine - Class to hold the information associated with an engine.

=head1 VERSION

version 0.013

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
