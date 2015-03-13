#!perl
use Test::More tests => 2;
use Test::Files;
use Test::Exception;
use File::Path qw(make_path remove_tree);
use DM;

my $test_dir = 't/05-check_multitargets.dir';
make_path($test_dir) unless -d $test_dir;

###
# checking to make sure DM can write to files
my $target1 = init_testfile( $test_dir . '/target1' );

my $dm = DM->new( dryRun => 0, engineName => 'localhost' );
$dm->addRule( $target1, "", 'echo "hello world" > ' . $target1, );

# try to redefine target
throws_ok(
    sub {
        $dm->addRule( $target1, "", 'echo "hello world" > ' . $target1, ),;
    },
    qr/Target defined twice \[($target1)\]/,
    "double target definition throws ok"
);

$dm->execute;

#file_ok( $target1, "hello world\n", "Hello world got written" );

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
