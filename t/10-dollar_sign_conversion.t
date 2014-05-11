#!perl
use Test::More tests => 2;
use Test::Files;
use File::Path qw(make_path remove_tree);
use DM;

my $test_dir = 't/10-dollar_sign_conversion.dir';
make_path($test_dir) unless -d $test_dir;

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );

my $dm = DM->new( dryRun => 0, engineName=>'localhost' );
$dm->addRule(
    $target1, "",
    'echo "hello world" > ' . $target1,
);
$dm->execute();

file_ok( $target1, "hello world\n", "Hello world got written" );

# cleanup
unlink $target1;

###
# check the protection of $ signs works correctly
my $target2         = init_testfile("$test_dir/target2");
my $target2_command = q/perl -e '$L = "hello world 2\n"; print $L'>/ . $target2;

$dm = DM->new( dryRun => 0, engineName=>'localhost' );
$dm->addRule( $target2, "", $target2_command );
$dm->execute();

file_ok( $target2, "hello world 2\n", "Hello world got written 2" );

# cleanup
unlink $target2;
unlink $test_dir . '/test.log';

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
