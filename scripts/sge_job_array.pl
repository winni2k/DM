#!/usr/bin/perl -w
use strict;
my %args;
getopt( 'ctp', \%args );
my $commands_file = defined $args{c}
  && -e $args{c} ? $args{c} : die "commands file needs to be defined";
my $targets_file = defined $args{t}
  && -e $args{t} ? $args{t} : die "targets file needs to be defined";
my $prereqs_file = defined $args{p}
  && -e $args{p} ? $args{p} : die "prereqs file needs to be defined";

# open file handle for commands file
open COMMANDS, "<$commands_file" or die "Couldn't open $commands_file: $!";
open TARGETS,  "<$targets_file"  or die "Couldn't open $targets_file: $!";
open PREREQS,  "<$prereqs_file"  or die "Couldn't open $prereqs_file: $!";

# seek to appropriate position given SGE_TASK_ID
my $command;
my $prereqs;
my $target;
for ( 1 .. $ENV{SGE_TASK_ID} ) {
    $command = <COMMANDS>;
    $prereqs = <PREREQS>;
    $target  = <TARGETS>;
}
close(COMMANDS);
close(PREREQS);
close(TARGETS);

foreach my $prereq ( split( /\s+/, $prereqs ) ) {
    if ( ( stat($prereq) )[9] > ( stat($target) )[9] ) {
        system($command );
        exit( $? & 127 );
    }
}
