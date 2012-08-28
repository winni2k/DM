#!perl

use Test::More tests => 3;

BEGIN {
    use_ok( 'DistributedMake::base' ) || print "Bail out!\n";
    use_ok( 'DistributedMake::StingArgs' ) || print "Bail out!\n";
    use_ok( 'DistributedMake::SGE' ) || print "Bail out!\n";
}
