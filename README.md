# DM

DistributedMake - a perl library for pipelining with GNU make

## Authorship

The original author of this code is Kiran V Garimella.

The maintainer of this code is Warren W. Kretzschmar.

## Obtaining this code

A copy of this code can be found at https://github.com/wkretzsch/DM

## Installation

### Using dzilla

    dzil install

### Using GNU make

Download a *-CPAN release from the releases page on github (for
example v0.2.6-CPAN).
Enter the subdirectory with the version's name (for example
DM-0.2.6). Then follow standard CPAN procedures:

    perl Makefile.PL
    make
    make test
    make install

## Documentation

Documentation on how to use DM can be found inside the DM library 
under lib/DM.pm. On most systems it is possible to use perldoc to
display the documentation:

    perldoc lib/DM.pm

After installation the man page is available through:

    man DM

## Changes

0.2.6  Mon Dec 16 16:22:03 GMT 2013

Cluster engines that are not supported are now ignored with an
error if their binaries are found on the system.

0.2.5  Mon Dec 16 15:43:58 GMT 2013

Added return of exit status from execute().

0.2.1   Tue  5 Mar 2013 17:08:54 GMT

Fixed bug in dist.ini where files in the scripts directory were not
being treated as executable files. 

0.2     Tue  5 Mar 2013 13:09:43 GMT

Renamed DistributedMake::base to DM.
Added more documentation to prep DM for release into the wild.

0.1.4

Added support for SGE job arrrays.

0.0.8

First stable version.

## Bug Reports

Please report bugs on GitHub at https://github.com/wkretzsch/DM/issues
