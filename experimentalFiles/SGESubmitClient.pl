#!/usr/bin/perl
# SGESubmitClient.pl                   wkretzsch@gmail.com
#                                      20 Sep 2013

use warnings;
use strict;
$|=1;
use Data::Dumper;

use File::Path qw(make_path);
use File::Basename;
use Env qw(HOME);

use Getopt::Std;
my %args;
getopts( 'dp:', \%args );
my $DEBUG = $args{d} || 1;
my $port = $args{p} || 6351; # default port is 'W' * 'K'

use IO::Socket::INET;
 
# auto-flush on socket
$| = 1;
 
# create a connecting socket
my $socket = new IO::Socket::INET (
    PeerHost => 'localhost',
    PeerPort => $port,
    Proto => 'tcp',
);
die "cannot connect to the server $!\n" unless $socket;
message( "connected to the server");
 
# data to send to a server
my $req = join(' ', @ARGV);
my $size = $socket->send($req);
message("sent data of length $size");
 
# notify server that request has been sent
shutdown($socket, 1);
 
# receive a response of up to 1024 characters from server
my $response = "";
$response = <$socket>;
message("received response: $response");
 
$socket->close();

exit $response;


sub message{

    my $msg = shift;

    print "[$0-$$] $msg\n";
}


__END__

=head1 NAME

SGESubmitClient.pl

=head1 SYNOPSIS
   

=head1 DESCRIPTION

SGE Submission Client for use by DM

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
