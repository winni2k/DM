#!/usr/bin/perl
# TestDRMAA.pl                   wkretzsch@gmail.com
#                                20 Sep 2013

use warnings;
use strict;
$|=1;
use Data::Dumper;

use File::Path qw(make_path);
use File::Basename;
use Env qw(HOME);

use Getopt::Std;
my %args;
getopts( 'drj:', \%args );
my $DEBUG = $args{d} || 1;



__END__

=head1 NAME

TestDRMAA.pl

=head1 SYNOPSIS
   

=head1 DESCRIPTION

Script to test DRMAA perl implementation on an SGE head node

=head1 AUTHOR

Warren Winfried Kretzschmar, E<lt>wkretzsch@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Warren Winfried Kretzschmar

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
