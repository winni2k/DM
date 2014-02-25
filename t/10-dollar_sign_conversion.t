#!perl
use Test::More tests => 2;
use File::Compare;
use DM;

my $test_dir = 't/10-dollar_sign_conversion.dir';

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );

my $target1_expected = "$test_dir/target1.expected";
my $dm = DM->new( dryRun => 0);
$dm->addRule( $target1, "", 'echo "hello world" > ' . $target1, engineName=>'localhost' );
$dm->execute();

ok( compare( $target1, $target1_expected ) == 0, "Hello world got written" );

# cleanup
unlink $target1;

###
# check the protection of $ signs works correctly
my $target2 = init_testfile("$test_dir/target2");
my $target2_expected = "$target2.expected";
my $target2_command  = q/perl -e '$L = "hello world 2\n"; print $L'>/.$target2;

$dm = DM->new( dryRun => 0 );
$dm->addRule( $target2, "", $target2_command , engineName=>'localhost');
$dm->execute();

ok( compare( $target2, $target2_expected ) == 0, "Hello world got written 2" );

# cleanup
unlink $target2;
unlink $test_dir.'/test.log';

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
