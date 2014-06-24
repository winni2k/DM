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
my $DMWrapCmd = "scripts/DMWrapCmd.pl";

plan( tests => 1 );

my $test_dir     = 'xt/author/59-DMWrapCmd.dir';
my $testDataFile = $test_dir . "/test1_dataFile.yaml";
my $testHostFile = $test_dir . '/hostsFile.yaml';
my @hosts        = ( { mandarin => 1 }, { fenghuang => 1 } );
YAML::Tiny::DumpFile( $testHostFile, @hosts );

###
# checking to make sure DMWrapCmd.pl runs ok
my $target1          = init_testfile( $test_dir . '/target1' );
my $cmd              = 'echo "hello world" > ' . $target1;

YAML::Tiny::DumpFile( $testDataFile, ($cmd) );

qx/$DMWrapCmd -h $testHostFile -t $test_dir -d $testDataFile -n 0/;
file_ok( $target1, "hello world\n" , "Hello world got written" );

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
