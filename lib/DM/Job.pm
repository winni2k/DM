package DM::Job;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Carp;

subtype 'DM::Job::ArrayRefOfStrs', as 'ArrayRef[Str]';

coerce 'DM::Job::ArrayRefOfStrs', from 'Str', via { [$_] };

has [ 'targets', 'prereqs' ] =>
  ( is => 'ro', isa => 'DM::Job::ArrayRefOfStrs', required => 1, coerce => 1 );
has command => ( is => 'ro', isa => 'Str', required => 1 );

sub target {
    my $self = shift;
    return $self->targets->[0];
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

DM::Job

=head1 SYNOPSIS

   use DM::Job;
   my $job = DM::Job->new(target=>'XYZ', prereqs=>[qw/X Y Z/], command => 'cat X Y Z');

=head1 DESCRIPTION

This is the DM::Job class.  Not too exciting.  Defines everything a job needs to know about.


=head1 SEE ALSO

DM

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Warren Winfried Kretzschmar

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

