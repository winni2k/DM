#!perl
use Test::More tests => 3;
use File::Compare;
use DistributedMake::base 0.001003;

my $test_dir = 't/50-job_array_testing.t.tmp';

my $dm = DistributedMake::base->new(
    "dryRun"   => 1,
    "numJobs"  => 1,
    outputFile => "$test_dir/output.log",
);

my @prereqs = ( "$test_dir/prereq1", "$test_dir/prereq2", "$test_dir/prereq3" );
system( "touch " . join( ' ', @prereqs ) );

my @targets = ( "$test_dir/target1", "$test_dir/target2" );

my $jobArrayObject = $dm->startJobArray(
    globalTmpDir => $test_dir,
    target       => "$test_dir/target_array.flag"
);
$dm->addJobArrayRule(
    target  => $targets[0],
    prereqs => $prereqs[0],
    command => "echo 'hi world 1' > $targets[0]"
);
$dm->addJobArrayRule(
    target  => $targets[2],
    prereqs => \@prereqs[ 1 .. 2 ],
    command => "echo 'hi world 2' > $targets[1]"
);
$dm->endJobArray();

ok(
    compare(
        $jobArrayObject->{files}->{targets}, "$test_dir/targets.expected"
      ) == 0,
    "targets file was created correctly"
);
ok(
    compare(
        $jobArrayObject->{files}->{prereqs}, "$test_dir/prereqs.expected"
      ) == 0,
    "prereqs file was created correctly"
);
ok(
    compare( $jobArrayObject->{files}->{commands},
        "$test_dir/commands.expected" ) == 0,
    "commands file was created correctly"
);
