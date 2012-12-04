#!/usr/bin/perl -w
use strict;
my %args;
getopt( 'ctp', \%args );
my $commands_file =
  defined $args{c}
  && -e $args{c} ? $args{c} : die "commands file needs to be defined";
my $targets_file =
  defined $args{t}
  && -e $args{t} ? $args{t} : die "targets file needs to be defined";
my $prereq =
  defined $args{p}
  && -e $args{p} ? $args{p} : die "prereq file needs to be defined";

# open file handle for commands file
open COMMANDS, "<$commands_file" or die "Couldn't open $commands_file: $!";
open TARGETS,  "<$targets_file"  or die "Couldn't open $targets_file: $!";

# seek to appropriate position given SGE_TASK_ID
my $command;
for ( 1 .. $ENV{SGE_TASK_ID} ) { $command = <COMMANDS> }
close(COMMANDS);
my $target;
for ( 1 .. $ENV{SGE_TASK_ID} ) { $target = <TARGETS> }
close(TARGETS);

system($command ) if (stat($prereq))[9] > (stat($target))[9];
