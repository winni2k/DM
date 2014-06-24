#!perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}

use Test::More;
use Test::Files;
use File::Path qw(make_path remove_tree);
use DM;
use YAML::Tiny;
use FindBin qw/$Bin/;
use Sys::Hostname;

my $numTests = 5;
plan( tests => $numTests );

my $test_dir = 'xt/author/60-wrapCommand.dir';
make_path($test_dir) unless -d $test_dir;

my $testHostFile = $test_dir . '/hostsFile.yaml';
my @hosts = ( { fenghuang => 4 } );
YAML::Tiny::DumpFile( $testHostFile, @hosts );

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );
my $dm      = DM->new(
    dryRun          => 0,
    numJobs         => $numTests,
    globalTmpDir    => $test_dir,
    engineName      => 'multihost',
    hostsFile       => $testHostFile,
    DMWrapCmdScript => "$Bin/../scripts/DMWrapCmd.pl",
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
    "fenghuang.stats.ox.ac.uk\n", "fenghuang.stats.ox.ac.uk\n",
    "fenghuang.stats.ox.ac.uk\n",
);
for my $targetNum ( 0 .. $#targets ) {
    $dm->addRule(
        $targets[$targetNum], "",
        'hostname >' . $targets[$targetNum],
        engineName => 'multihost'
    );
}

# checking if localhost override works
my $target5 = init_testfile( $test_dir . '/target5' );
$dm->addRule(
    $target5, "",
    'hostname > ' . $target5,
    engineName => 'localhost'
);

$dm->execute();

file_ok( $target1, "hello world\n", "Hello world got written" );

for my $idx ( 0 .. $#targets ) {
    file_ok( $targets[$idx], $expected[$idx],
        "Target $targets[$idx] ran on correct host" );
}

file_ok( $target5, hostname . "\n", "localhost engine override works" );

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
