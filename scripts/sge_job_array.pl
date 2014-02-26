#!/usr/bin/perl -w
use strict;
use Getopt::Std;

# PODNAME: bobby_tables.pl

my %args;
getopt( 'ctp', \%args );
my $commands_file = defined $args{c}
  && -e $args{c} ? $args{c} : die "commands file needs to be defined";
my $targets_file = defined $args{t}
  && -e $args{t} ? $args{t} : die "targets file needs to be defined";
my $prereqs_file = defined $args{p}
  && -e $args{p} ? $args{p} : die "prereqs file needs to be defined";

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
for ( 1 .. $ENV{SGE_TASK_ID} ) {
    $command = <$fhCOMMANDS>;
    chomp $command;
    $prereqs = <$fhPREREQS>;
    chomp $prereqs;
    $target = <$fhTARGETS>;
    chomp $target;
}
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
