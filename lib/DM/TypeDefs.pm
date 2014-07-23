package DM::TypeDefs;
$DM::TypeDefs::VERSION = '0.013'; # TRIAL
# ABSTRACT: Class that defines type definitions used by DM and its child classes.

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Carp;

enum 'engine_t', [qw/localhost multihost SGE LSF PBS/];

subtype 'DM::PositiveInt', as 'Int',
  where { $_ >= 0 },
  message { "The number you provided, $_, was not a positive number" };

subtype 'DM::PositiveNum', as 'Num',
  where { $_ >= 0 },
  message { "The number you provided, $_, was not a positive number" };

__END__

=pod

=encoding UTF-8

=head1 NAME

DM::TypeDefs - Class that defines type definitions used by DM and its child classes.

=head1 VERSION

version 0.013

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
