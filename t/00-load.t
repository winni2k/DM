#!perl

use Test::More tests => 5;

BEGIN {
    use_ok( 'DistributedMake::base' ) || print "Bail out!\n";
    use_ok( 'DistributedMake::StingArgs' ) || print "Bail out!\n";
    use_ok( 'DistributedMake::SGE' ) || print "Bail out!\n";
}


# testing DistributedMake::base method loading
my $dm = DistributedMake::base->new();

can_ok($dm, qw/new addRule execute/);
isa_ok($dm, 'DistributedMake::base')
