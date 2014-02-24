package DM::TypeDefs;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Carp;

enum 'engine_t', [qw/localhost multihost SGE LSF PBS/];

subtype 'DM::PositiveInt', as 'Int',
  where { $_ > 0 },
  message { "The number you provided, $_, was not a positive number" };

subtype 'DM::PositiveNum', as 'Num',
  where { $_ > 0 },
  message { "The number you provided, $_, was not a positive number" };
