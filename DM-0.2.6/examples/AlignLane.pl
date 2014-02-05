#!/usr/local/bin/perl -w

use strict;
use StingArgs;
use DM;
use File::Basename;

my %args = &getCommandArguments("FASTQ_END_1" => undef, "FASTQ_END_2" => undef, "REFERENCE" => undef, "BAM_OUT" => undef, "ID" => undef, "SM" => undef, "LB" => undef, "PL" => undef, "CN" => undef, "DRY_RUN" => 1, "NUM_JOBS" => "");

my $dm = new DM("dryRun" => $args{'DRY_RUN'}, "numJobs" => $args{'NUM_JOBS'});

(my $intermediateDir = &dirname($args{'BAM_OUT'}) . "/.intermediate/" . &basename($args{'BAM_OUT'})) =~ s/.bam$//;

my $sai1 = "$intermediateDir/end1.sai";
my $sai1Cmd = "bwa aln -t 2 -q 5 $args{'REFERENCE'} $args{'FASTQ_END_1'} > $sai1";
$dm->addRule($sai1, $args{'REFERENCE'}, $sai1Cmd);

my $sai2 = "$intermediateDir/end2.sai";
if (-e $args{'FASTQ_END_2'}) {
	my $sai2Cmd = "bwa aln -t 2 -q 5 $args{'REFERENCE'} $args{'FASTQ_END_2'} > $sai2";
	$dm->addRule($sai2, $args{'REFERENCE'}, $sai2Cmd);
}

my $sam = "$intermediateDir/aligned.sam";
my $rg = "\@RG\\tID:$args{'ID'}\\tSM:$args{'SM'}\\tLB:$args{'LB'}\\tPL:$args{'PL'}\\tCN:$args{'CN'}";

if (-e $args{'FASTQ_END_2'}) {
	my $samCmd = "bwa sampe -r \"$rg\" $args{'REFERENCE'} $sai1 $sai2 $args{'FASTQ_END_1'} $args{'FASTQ_END_2'} > $sam";
	$dm->addRule($sam, [$sai1, $sai2], $samCmd);
} else {
	my $samCmd = "bwa samse -r \"$rg\" $args{'REFERENCE'} $sai1 $args{'FASTQ_END_1'} > $sam";
	$dm->addRule($sam, $sai1, $samCmd);
}

my $cleaned = "$intermediateDir/aligned.cleaned.sam";
my $cleanedCmd = "java -jar ~/repositories/picard/dist/CleanSam.jar I=$sam O=$cleaned VALIDATION_STRINGENCY=LENIENT";
$dm->addRule($cleaned, $sam, $cleanedCmd);

my $sorted = $args{'BAM_OUT'};
my $sortedCmd = "java -jar ~/repositories/picard/dist/SortSam.jar I=$cleaned O=$sorted SO=coordinate VALIDATION_STRINGENCY=LENIENT";
$dm->addRule($sorted, $cleaned, $sortedCmd);

my $bai = "$args{'BAM_OUT'}.bai";
my $baiCmd = "samtools index $args{'BAM_OUT'}";
$dm->addRule($bai, $sorted, $baiCmd);

$dm->execute();
