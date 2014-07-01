#!perl
use strictures;
use warnings;
use Test::More tests => 11;
use File::Temp ();

BEGIN {
    use_ok('DM::TypeDefs')         || print "Bail out!\n";
    use_ok('DM::Job')              || print "Bail out!\n";
    use_ok('DM::JobArray')         || print "Bail out!\n";
    use_ok('DM::DistributeEngine') || print "Bail out!\n";
    use_ok('DM')                   || print "Bail out!\n";
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
my $tf = File::Temp->new();
my $ja = DM::JobArray->new(
    globalTmpDir => '/tmp',
    name         => 'test',
    target       => '/tmp/testJA',
    targetsFile  => $tf,
    prereqsFile  => $tf,
    commandsFile => $tf,
);
can_ok( $ja,
    qw/globalTmpDir name target commandsFile targetsFile prereqsFile/ );
isa_ok( $ja, 'DM::JobArray' );

# testing DistributedMake::base method loading
# testing DM::Distributer method loading
my $dm = DM->new( globalTmpDir => '/tmp' );

can_ok(
    $dm,
    qw/new addRule execute addJobArrayRule startJobArray endJobArray/,
    qw/engineName memRequest outputFile rerunnable extra PE job _supportedEngines jobAsMake/
);
isa_ok( $dm, 'DM' )
