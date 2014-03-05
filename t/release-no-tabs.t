
BEGIN {
  unless ($ENV{RELEASE_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for release candidate testing');
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::NoTabsTests 0.06

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/DM.pm',
    'lib/DM/DistributeEngine.pm',
    'lib/DM/Distributer.pm',
    'lib/DM/Job.pm',
    'lib/DM/JobArray.pm',
    'lib/DM/TypeDefs.pm',
    'lib/DM/WrapCmd.pm',
    'scripts/DMWrapCmd.pl',
    'scripts/sge_job_array.pl'
);

notabs_ok($_) foreach @files;
done_testing;
