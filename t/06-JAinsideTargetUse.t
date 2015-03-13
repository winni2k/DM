#!perl
use Test::More tests => 3;
use Test::Files;
use Test::Exception;
use File::Path qw(make_path remove_tree);
use DM;

my $test_dir = 't/05-check_multitargets.dir';
make_path($test_dir) unless -d $test_dir;

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );
my $flag    = init_testfile("$target1.flag");
my $target2 = init_testfile( $test_dir . '/target2' );

my $dm =
  DM->new( dryRun => 0, engineName => 'localhost', globalTmpDir => $test_dir );

$dm->addRule( $target2, $target1, 'echo "hello world" > ' . $target2, );
$dm->startJobArray( target => $flag );
throws_ok(
    sub {
        $dm->ajar( $target1, "", 'echo "hello world" > ' . $target1, );
    },
    qr/Job array Target already used as prerequisite before \[($target1)\]/,
    "job array target erroneously used as prerequisite in other rule"
);

my $dm =
  DM->new( dryRun => 0, engineName => 'localhost', globalTmpDir => $test_dir );
$dm->sja( target => $flag );
$dm->ajar( $target1, "", 'echo "hello world" > ' . $target1, );
$dm->eja;

# try to use target that was defined inside job array
$dm->addRule( $target2, $target1, 'echo "hello world2" > ' . $target2, );

#ok( !exists $dm->targets->{$target1}, "target1 is not added to targets" );
$dm->execute;

file_ok( $target1, "hello world\n",  "Hello world got written" );
file_ok( $target2, "hello world2\n", "Hello world2 got written" );

# cleanup
unlink $target1;
unlink $target2;
unlink $flag;

unlink $test_dir . '/test.log';

sub init_testfile {

    my $file = shift;
    if ( -e $file ) {
        unlink $file;
    }
    return $file;
}
