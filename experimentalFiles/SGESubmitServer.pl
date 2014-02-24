#!/usr/bin/perl
# SGESubmitServer.pl                   wkretzsch@gmail.com
#                                      20 Sep 2013

use warnings;
use strict;
use Data::Dumper;

use File::Path qw(make_path);
use File::Basename;
use Env qw(HOME);
use IO::Socket::INET;

use Getopt::Std;
my %args;
getopts( 'd:tp:c:', \%args );
my $DEBUG = $args{d} || 1;
my $port = $args{p} || 6351; # default port is 'W' * 'K'
my $connections = $args{c} || SOMAXCONN;


# auto-flush on socket
$| = 1;

# creating a listening socket
my $socket = new IO::Socket::INET(
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => $connections,
    Reuse     => 1
);
die "cannot create socket $!\n" unless $socket;
message("$0 waiting for client connection on port $port");

while (1) {

    # waiting for a new client connection
    my $client_socket = $socket->accept();
    $socket->autoflush(1);

    # get information about a newly connected client
    my $client_address = $client_socket->peerhost();
    my $client_port    = $client_socket->peerport();
    message("connection from $client_address:$client_port");

    # read up to 1024 characters from the connected client
    my $data = "";
    $data = <$client_socket>;
    message("received data: $data");

    # write response data to the connected client
    $data = "0";
    $client_socket->send($data);

    # notify client that response has been sent
    shutdown( $client_socket, 1 );
}

$socket->close();

sub message{

    my $msg = shift;

    print "[$0-$$] $msg\n";
}

__END__

=head1 NAME

SGESubmitServer.pl

=head1 SYNOPSIS
   

=head1 DESCRIPTION
Stub documentation for SGESubmitServer.pl, 
created by template.el.

It looks like the author of this script was negligent
enough to leave the stub unedited.


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
