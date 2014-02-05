#!perl

use Test::More tests => 3;

BEGIN {
    use_ok( 'DM' ) || print "Bail out!\n";
}


# testing DistributedMake::base method loading
my $dm = DM->new();

can_ok($dm, qw/new addRule execute/);
isa_ok($dm, 'DM')
