#!/usr/bin/perl
# SGESubmitTest.pl                   wkretzsch@gmail.com
#                                    20 Sep 2013

use warnings;
use strict;
$| = 1;
use Data::Dumper;

use File::Path qw(make_path);
use File::Basename;
use Env qw(HOME);

use Getopt::Std;
use autodie;
my %args;
getopts( 'drj:', \%args );
my $DEBUG = $args{d} || 1;
my $pid = 0;
if( $pid = fork){
    print "started server\n"
}
else{
    system("perl SGESubmitServer.pl");
    exit(0);
}

for ( 1 .. 10 ) {
    system("perl SGESubmitClient.pl -- $_ sends its love &");
}

sleep 20;

__END__

=head1 NAME

SGESubmitTest.pl

=head1 SYNOPSIS
   

=head1 DESCRIPTION

tests SGESubmitServer.pl and client interaction

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
