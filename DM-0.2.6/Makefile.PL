
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Distributed Make: A perl module for running pipelines",
  "AUTHOR" => "Kiran V Garimella <kiran\@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar\@well.ox.ac.uk>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "DM",
  "EXE_FILES" => [
    "scripts/sge_job_array.pl",
    "scripts/SGESubmitClient.pl",
    "scripts/SGESubmitServer.pl",
    "scripts/SGESubmitTest.pl",
    "scripts/TestDRMAA.pl"
  ],
  "LICENSE" => "perl",
  "NAME" => "DM",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Data::Dumper" => 0,
    "Env" => 0,
    "File::Basename" => 0,
    "File::Path" => 0,
    "File::Temp" => 0,
    "Getopt::Std" => 0,
    "IO::Socket::INET" => 0,
    "autodie" => 0,
    "strict" => 0,
    "version" => "0.77",
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Compare" => 0,
    "Test::Files" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.2.6",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Dumper" => 0,
  "Env" => 0,
  "File::Basename" => 0,
  "File::Compare" => 0,
  "File::Path" => 0,
  "File::Temp" => 0,
  "Getopt::Std" => 0,
  "IO::Socket::INET" => 0,
  "Test::Files" => 0,
  "Test::More" => 0,
  "autodie" => 0,
  "strict" => 0,
  "version" => "0.77",
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



