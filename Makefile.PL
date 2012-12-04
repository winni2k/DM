use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use version 0.77;

# create README files dynamically from POD
my $preop =
    'perldoc -uT $(VERSION_FROM) | tee $(DISTVNAME)/README.pod > README.pod;'
  . 'pod2text README.pod | tee $(DISTVNAME)/README > README';

WriteMakefile(
    NAME          => 'DistributedMake::base',
    AUTHOR        => q{Kiran V Garimella <kiran@well.ox.ac.uk>},
    VERSION_FROM  => 'lib/DistributedMake/base.pm',
    ABSTRACT_FROM => 'lib/DistributedMake/base.pm',
    ( qv($ExtUtils::MakeMaker::VERSION) >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'      => 0,
        'File::Temp'      => 0,
        'File::Basename'  => 0,
        'Term::ANSIColor' => 0,
    },
    EXE_FILES => [qw(scripts/sge_job_array.pl)],
    dist      => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', PREOP => $preop, },
    clean => { FILES => 'DistributedMake-base-*' },
);
