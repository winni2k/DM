package DM::Job;
$DM::Job::VERSION = '0.013'; # TRIAL
# ABSTRACT: This is the DM::Job class.  Not too exciting.  Defines everything a job needs to know about.


use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use File::Basename;
use Carp;

subtype 'DM::Job::ArrayRefOfStrs', as 'ArrayRef[Str]';

coerce 'DM::Job::ArrayRefOfStrs', from 'Str', via { [$_] };

has [ 'targets', 'prereqs', 'commands' ] =>
  ( is => 'rw', isa => 'DM::Job::ArrayRefOfStrs', required => 1, coerce => 1 );

has name => ( is => 'rw', isa => 'Str', builder => '_build_name', lazy => 1 );

sub _build_name {
    my $self = shift;

    my $name = "DM_job";

    my $firstcmd = $self->commands->[0];
    if ( $firstcmd =~ /java/ && $firstcmd =~ /-jar/ ) {
        ($name) = $firstcmd =~ /-jar\s+(\S+)\s+/;
    }
    else {
        $firstcmd =~ m/(\S+)/;
        $name = $1;
    }
    $name = basename($name);
    return $name;
}

sub target {
    my $self = shift;
    return $self->targets->[0];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DM::Job - This is the DM::Job class.  Not too exciting.  Defines everything a job needs to know about.

=head1 VERSION

version 0.013

=head1 SYNOPSIS

   use DM::Job;
   my $job = DM::Job->new(target=>'XYZ', prereqs=>[qw/X Y Z/], command => 'cat X Y Z');

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
