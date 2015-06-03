# DM

DistributedMake - a perl library for pipelining with GNU make

## Authorship

The original author of this code is Kiran V Garimella.

The maintainer of this code is Warren W. Kretzschmar.

## Obtaining this code

A copy of this code can be found at https://github.com/wkretzsch/DM

## Synopsis

This code will echo 100 numbers in parallel, and then echo another 100 numbers in parallel after a five second sleep.

    #!/usr/bin/env perl -w
    use strict;
    use DM;
    my @args = (dryRun => 0, numJobs=>100, engineName => 'localhost');
    my $dm = DM->new(@args);    
    
    for my $val (1..100){
        $dm->addRule("hello_world_$val", "", "echo $val; sleep 5; echo ".($val + 100)."; touch hello_world_$val");
    }
    $dm->execute();
    
To run on an SGE cluster, this code can be rewritten in the following way:
    
    #!/usr/bin/env perl -w
    use strict;
    use DM;
    my @args = (dryRun => 0, numJobs=>100, globalTmpDir => .);
    my $dm = DM->new(@args);
    
    $dm->startJobArray(target => 'hw.flag');
    for my $val (1..100){
        $dm->addJobArrayRule("hello_world_$val", "", "echo $val; sleep 5; echo ".($val + 100)."; touch hello_world_$val");
    }
    $dm->endJobArray();
    $dm->execute();
    
This runs all the jobs as part of a job array.  Running as a job array is only necessary if the recipe to run contains special bash characters that signify the end of an expression (for example: ; | & && ||).

## Installation

### Using dzilla

    dzil install

### Using GNU make

#### For DM version > 0.2.6

For the later releases, simply download one of the *-TRIAL releases from
the releases page on github (for example v0.016-TRIAL), enter that
directory and follow standard CPAN procedure:

    perl Makefile.PL
    make
    make test
    make install

#### For DM version <= 0.2.6

For releases before and including 0.2.6, download a *-CPAN release
from the releases page on github (for example v0.2.6-CPAN). 
Enter the subdirectory with the version's name (for example
DM-0.2.6). Then follow standard CPAN procedure (see above)

#### Most up-to-date developer builds

The branch `build/devel` contains a snapshot of every build created so far.
Standard CPAN procedures can be used on these builds as well.  Travis CI 
testing results for these builds can be found at https://travis-ci.org/wkretzsch/DM.

## Documentation

Documentation on how to use DM can be found inside the DM library 
under lib/DM.pm. On most systems it is possible to use perldoc to
display the documentation:

    perldoc lib/DM.pm

After installation the man page is available through:

    man DM
    
A copy of the documentation can also be found at https://github.com/wkretzsch/DM/wiki/Documentation


## Changes

0.015  --  2015-02-04 15:13:26+00:00 Europe/London (TRIAL RELEASE)  

        Turned off built-in rules when calling make (seriously, who actually uses SCCS anymore?)

0.014  --  2014-11-23 12:47:13+00:00 Europe/London (TRIAL RELEASE)

        Made /bin/bash the default shell to run recipes under.
        Fixed bug in SGE job array dispatch where dispatcher would not
        move farther down the list of commands after the first job
        array had been dispatched. 
        Moved version numbering to three digit decimal format (according to DAGOLDEN)
        Fixed bug where PE option did not work
        Fixed bug with jobArrays where tempfiles were being deleted too soon.
        Fixed some bugs introduced by previous work for usage with SGE
        DM::Distributer::projectName and queue may now be undef as well

0.2.12  -- 2014-03-04 18:05:13+00:00 Europe/London (TRIAL RELEASE)

        Made DM::Distributer a role instead of a class.
        DM::Distributer variables can now be set directly through
        calls to DM objects.

0.2.11 -- 2014-02-26 23:29:21+00:00 Europe/London (TRIAL RELEASE)

        Rearranged dzil release process.  This is a test to see if
        everything works as expected. 

0.2.10 -- 2014-02-26 17:35:52+00:00 Europe/London (TRIAL RELEASE)

        Trying to get the dzil build just right so that builds can
        be seen on the build and release branches          

0.2.9  --  Wed Feb 26 15:48:11 GMT 2014

        Trying to get dist zilla to get through all the author tests

0.2.7  -- Mon Feb 17 22:34:14 GMT 2014

        Added option to turn of post command touching of targets
        using the postCmdTouch batch job override

0.2.6 -- Mon Dec 16 16:22:03 GMT 2013

        Cluster engines that are not supported are now ignored with an
        error if their binaries are found on the system.

0.2.5 -- Mon Dec 16 15:43:58 GMT 2013

        Added return of exit status from execute().

0.2.1  -- Tue  5 Mar 2013 17:08:54 GMT

        Fixed bug in dist.ini where files in the scripts directory were not
        being treated as executable files. 

0.2   --  Tue  5 Mar 2013 13:09:43 GMT

        Renamed DistributedMake::base to DM.
        Added more documentation to prep DM for release into the wild.

0.1.4

        Added support for SGE job arrrays.

0.0.8

        First stable version.

## Bug Reports

Please report bugs on GitHub at https://github.com/wkretzsch/DM/issues
