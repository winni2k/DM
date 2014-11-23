#!perl
use strictures;
use warnings;
use Test::More tests=>2;
use FindBin qw/$Bin/;

my $DMWrapCmd = "$Bin/../scripts/DMWrapCmd.pl 2>&1";
my $error = qx/$DMWrapCmd/;
like($error, qr/^Attribute \(dataFile\) is required at/, "DMWrapCmd.pl syntax OK");

my $sge_job_array = "$Bin/../scripts/sge_job_array.pl 2>&1";
$error = qx/$sge_job_array/;
like($error, qr/^commands file needs to be defined at/, "sge_job_array.pl syntax OK");

