#!perl

use Test::More tests => 12;

BEGIN {
    use_ok('DM::TypeDefs')          || print "Bail out!\n";
    use_ok('DM::Job')               || print "Bail out!\n";
    use_ok('DM::JobArray')          || print "Bail out!\n";
    use_ok('DM::DistributeEngine')  || print "Bail out!\n";
    use_ok('DM::Distributer') || print "Bail out!\n";
    use_ok('DM')                    || print "Bail out!\n";
}

# testing DM::Job method loading
my $job = DM::Job->new(
    targets  => ['testing1'],
    prereqs  => ['testing2'],
    commands => 'testing3'
);
can_ok( $job, qw/targets target prereqs commands/ );
isa_ok( $job, 'DM::Job' );

# testing DM::JobArray method loading
my $ja = DM::JobArray->new(
    globalTmpDir => '/tmp',
    name         => 'test',
    target       => '/tmp/testJA'
);
can_ok( $ja,
    qw/globalTmpDir name target commandsFile targetsFile prereqsFile/ );
isa_ok( $ja, 'DM::JobArray' );



# testing DistributedMake::base method loading
my $dm = DM->new( globalTmpDir => '/tmp' );

can_ok( $dm, qw/new addRule execute/ );
isa_ok( $dm, 'DM' )
