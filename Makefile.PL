use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use version 0.77;

# create README files dynamically from POD
my $preop =
    'perldoc -uT $(VERSION_FROM) | tee $(DISTVNAME)/README.pod > README.pod;'
  . 'pod2text README.pod | tee $(DISTVNAME)/README > README;'
  . 'pod2html README.pod | tee $(DISTVNAME)/README.html > README.html';

WriteMakefile(
    NAME => 'DM',
    AUTHOR =>
q{Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>},
    VERSION_FROM  => 'lib/DM.pm',
    ABSTRACT_FROM => 'lib/DM.pm',
    ( qv($ExtUtils::MakeMaker::VERSION) >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'      => 0,
        'Test::Files'     => 0,
        'File::Temp'      => 0,
        'File::Basename'  => 0,
        'File::Compare'   => 0,
        'Term::ANSIColor' => 0,
    },
    EXE_FILES => [qw(scripts/sge_job_array.pl)],
    dist      => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', PREOP => $preop, },
    clean => { FILES => 'DM-*' },
);
