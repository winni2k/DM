#!/usr/bin/perl -w

# ABSTRACT: This script is used by Job Arrays to check prerequisites and run its command arguments.

# PODNAME: sge_job_array.pl

# use -o to sepcify an offset on top of SGE_TASK_ID

use strict;
use Getopt::Std;

my %args;
getopt( 'c:t:p:o:', \%args );
my $commands_file =
  ( defined $args{c} && -e $args{c} )
  ? $args{c}
  : die "commands file needs to be defined";
my $targets_file =
  ( defined $args{t} && -e $args{t} )
  ? $args{t}
  : die "targets file needs to be defined";
my $prereqs_file =
  ( defined $args{p} && -e $args{p} )
  ? $args{p}
  : die "prereqs file needs to be defined";
my $offset = $args{o} || 0;

# open file handle for commands file
my $fhCOMMANDS;
my $fhTARGETS;
my $fhPREREQS;
open $fhCOMMANDS, '<', $commands_file
  or die " Couldn't open $commands_file: $! ";
open $fhTARGETS, '<', $targets_file or die "Couldn't open $targets_file: $!";
open $fhPREREQS, '<', $prereqs_file or die "Couldn't open $prereqs_file: $! ";

# seek to appropriate position given SGE_TASK_ID
my $command;
my $prereqs;
my $target;
for ( 1 .. ( $ENV{SGE_TASK_ID} + $offset ) ) {
    $command = <$fhCOMMANDS>;
    $prereqs = <$fhPREREQS>;
    $target  = <$fhTARGETS>;
}
chomp $command;
chomp $prereqs;
chomp $target;
close($fhCOMMANDS);
close($fhPREREQS);
close($fhTARGETS);

my $run_command = 0;

foreach my $prereq ( split( /\s+/, $prereqs ) ) {

    # run the command if the target does not exist
    unless ( -e $target ) {
        $run_command = 1;
        last;
    }

    # otherwise check each prereq whether it is older than target
    if ( ( stat($prereq) )[9] > ( stat($target) )[9] ) {
        $run_command = 1;
    }
}

if ($run_command) {
    system($command );
    my $exit_val = $? & 127;
    if ( $exit_val > 0 ) {
        unlink $target;
    }
    exit($exit_val);
}

exit(0);

__END__

=pod

=encoding UTF-8

=head1 NAME

sge_job_array.pl - This script is used by Job Arrays to check prerequisites and run its command arguments.

=head1 VERSION

version 0.013

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
