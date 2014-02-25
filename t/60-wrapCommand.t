#!perl
use Test::More;
use File::Compare;
use File::Path qw(make_path remove_tree);
use DM;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}
plan( tests => 1 );

my $test_dir     = 't/60-wrapCommand.dir';
my $testHostFile = $test_dir . '/60-hostsFile.yaml';

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );

my $target1_expected = "$test_dir/target1.expected";
my $dm               = DM->new(
    dryRun       => 0,
    globalTmpDir => $test_dir,
    engineArgs   => { engineName => 'multihost', hostsFile => $testHostFile }
);
$dm->addRule(
    $target1, "",
    'echo "hello world" > ' . $target1,
    engineName => 'localhost'
);
$dm->execute();

ok( compare( $target1, $target1_expected ) == 0, "Hello world got written" );

# cleanup
unlink $target1;

unlink $test_dir . '/test.log';

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
