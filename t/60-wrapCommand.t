#!perl
use Test::More;
use Test::Files;
use File::Path qw(make_path remove_tree);
use DM;
use YAML::XS;
use FindBin qw/$Bin/;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}
my $numTests = 4
plan( tests => $numTests );

my $test_dir = 't/60-wrapCommand.dir';
make_path($test_dir) unless -d $test_dir;

my $testHostFile = $test_dir . '/hostsFile.yaml';
my @hosts = ( { mandarin => 1 }, { fenghuang => 1 }, );
YAML::XS::DumpFile( $testHostFile, @hosts );

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );
my $dm      = DM->new(
    dryRun       => 0,
    numJobs      => $numTests,
    globalTmpDir => $test_dir,
    engineArgs   => {
        engineName      => 'multihost',
        hostsFile       => $testHostFile,
        DMWrapCmdScript => "$Bin/../scripts/DMWrapCmd.pl",
    }
);
$dm->addRule(
    $target1, "",
    'echo "hello world" > ' . $target1,
    engineName => 'localhost'
);

###
# cheking to make sure DM runs on expected hosts
my @targets = map { init_testfile( $test_dir . "/target$_" ) } 2 .. 4;
my @expected = (
    "mandarin.stats.ox.ac.uk\n", "fenghuang.stats.ox.ac.uk\n",
    "mandarin.stats.ox.ac.uk\n"
);
for my $targetNum ( 0 .. $#targets ) {
    $dm->addRule(
        $targets[$targetNum], "",
        'hostname >' . $targets[$targetNum],
        engineName => 'multihost'
    );
}
$dm->execute();

file_ok( $target1, "hello world\n", "Hello world got written" );

for my $idx ( 0 .. $#targets ) {
    file_ok( $targets[$idx], $expected[$idx],
        "Target $targets[$idx] ran on correct host" );
}

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
