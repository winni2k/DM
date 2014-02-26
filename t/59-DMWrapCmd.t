#!perl
use Test::More;
use Test::Files;
use File::Path qw(make_path remove_tree);
use DM;
use YAML::XS;
use FindBin qw/$Bin/;
my $DMWrapCmd = "scripts/DMWrapCmd.pl";

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}
plan( tests => 1 );

my $test_dir     = 't/59-DMWrapCmd.dir';
my $testDataFile = $test_dir . "/test1_dataFile.yaml";
my $testHostFile = $test_dir . '/hostsFile.yaml';
my @hosts        = ( { mandarin => 1 }, { fenghuang => 1 } );
YAML::XS::DumpFile( $testHostFile, @hosts );

###
# checking to make sure DMWrapCmd.pl runs ok
my $target1          = init_testfile( $test_dir . '/target1' );
my $cmd              = 'echo "hello world" > ' . $target1;

YAML::XS::DumpFile( $testDataFile, ($cmd) );

qx/$DMWrapCmd -h $testHostFile -t $test_dir -d $testDataFile -n 0/;
compare_ok( $target1, "hello world\n" , "Hello world got written" );

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
