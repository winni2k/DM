#!/usr/bin/perl -w

# ABSTRACT: This script is called by DM when running in multihost mode.


package DMWrapper;
$DMWrapper::VERSION = '0.013'; # TRIAL
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use YAML::Tiny;
use File::NFSLock;
use Carp;
use Net::OpenSSH;
use Sys::Hostname;

subtype 'DM::PositiveInt', as 'Int',
  where { $_ >= 0 },
  message { "The number you provided, $_, was not a positive number" };

has tag => ( is => 'ro', isa => 'Str', default => "[DMWRapCmd.pl]" );

# input variables
has dataFile  => ( is => 'ro', isa => 'Str', required => 1, init_arg => 'd' );
has tempDir   => ( is => 'ro', isa => 'Str', required => 1, init_arg => 't' );
has hostsFile => ( is => 'ro', isa => 'Str', required => 1, init_arg => 'h' );
has jobNum =>
  ( is => 'ro', isa => 'DM::PositiveInt', required => 1, init_arg => 'n' );

after tempDir => sub {
    my $self = shift;
    if (@_) {
        croak $self->tag . " Temp dir does not exist" unless -d $_[0];
    }
};
after dataFile => sub {
    my $self = shift;
    if (@_) {
        croak $self->tag . " Data file does not exist" unless -e $_[0];
    }
};

# class variables
has jobs => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    builder => '_build_jobs',
    lazy    => 1
);
has cmd => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_cmd',
    lazy    => 1
);
has lockObject => (
    is      => 'ro',
    isa     => 'File::NFSLock',
    builder => '_build_lockObject',
    lazy    => 1
);
has hostLockFiles => (
    is      => 'ro',
    isa     => 'ArrayRef[ArrayRef[Str]]',
    builder => '_build_hostLockFiles',
    lazy    => 1
);
has hosts => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    builder => '_build_hosts',
    lazy    => 1
);
has _chosenHost => ( is => 'rw', isa => 'Str', default => 'localhost' );

sub _build_hosts {
    my $self     = shift;
    my @hostRefs = YAML::Tiny::LoadFile( $self->hostsFile );
    my @hosts;
    for my $hostRef (@hostRefs) {
        my @keys = keys %{$hostRef};
        confess "HostRef has more than one key" if @keys > 1;
        for my $hostNum ( 0 .. ( $hostRef->{ $keys[0] } - 1 ) ) {
            push @hosts, $keys[0];
        }
    }
    return \@hosts;
}

sub _build_hostLockFiles {
    my $self    = shift;
    my $hosts   = $self->hosts;
    my $tempDir = $self->tempDir;

    my $hostNum  = 0;
    my $lastHost = $hosts->[0];
    my @hostLocks;
    for my $host ( @{$hosts} ) {
        $hostNum = 0 if $host ne $lastHost;
        push @hostLocks, [ $host, $tempDir . "/$host.lock$hostNum" ];
        ++$hostNum;
    }
    return \@hostLocks;
}

sub _build_jobs {
    my $self = shift;
    my @jobs = YAML::Tiny::LoadFile( $self->dataFile );

    croak $self->tag
      . " Input job number is larger than jobs in data file: "
      . $self->dataFile
      if $self->jobNum >= @jobs;
    return \@jobs;
}

sub _build_cmd {
    my $self = shift;
    return $self->jobs->[ $self->jobNum ];
}

sub _build_lockObject {
    my $self = shift;

    my $blocking_timeout = 3;
    my $hostLockFiles    = $self->hostLockFiles;
    while (1) {
        for my $hostLockFileRef ( @{$hostLockFiles} ) {
            my ( $host, $hostLockFile ) = @{$hostLockFileRef};
            my $lock = File::NFSLock->new(
                {
                    file      => $hostLockFile,
                    lock_type => 'NONBLOCKING',
                }
            );
            if ( defined $lock ) {
                $self->_chosenHost($host);
                return $lock;
            }
        }

        # wait at least blocking timeout plus a random amount of time
        sleep $blocking_timeout + rand($blocking_timeout);
    }
}

sub exitWithStatus {
    my $self = shift;
    my $code = shift;
    my $cmd  = $self->cmd;

    $cmd = '[DMWrapCmd.pl] Command: ' . $cmd;
    if ( $code == -1 ) {
        print STDERR "$cmd\nFailed to execute: $!\n";
        exit 1;
    }
    elsif ( $code & 127 ) {
        printf STDERR "$cmd\nChild died with signal %d, %s coredump\n",
          ( $code & 127 ), ( $code & 128 ) ? 'with' : 'without';
    }
    else {
        if ( $code >> 8 ) {
            printf STDERR "$cmd\nCommand exited with non-zero value %d\n",
              $code >> 8;
        }
    }
    exit $code >> 8;
}

sub runAndExitWithExitStatus {
    my $self = shift;
    my $cmd  = $self->cmd;

    my $lock = $self->lockObject;

    # document what we are running
    print STDOUT $self->tag." $cmd\n";

    # run locally
    if ( $self->_chosenHost eq hostname ) {
        system($cmd);

        $self->exitWithStatus($?);
    }

    # open run through ssh connection
    else {

        my $ssh = Net::OpenSSH->new( $self->_chosenHost );
        $ssh->error
          and croak "Couldn't establish SSH connection: " . $ssh->error;

        # change to current directory on remote host before execution
        $cmd = q/cd / . Cwd::getcwd() . q/ && / . $cmd;

        # run command on remote host
        my ( $output, $error ) = $ssh->capture2($cmd);
        $ssh->error
          and croak "Command didn't complete successfully: "
          . $ssh->error
          . "\nCommand: $cmd";
        print $output;
        print STDERR $error;
        $self->exitWithStatus($?);
    }
}

__PACKAGE__->meta->make_immutable;

use strict;
use warnings;
use Getopt::Std;
my %args;
getopts( 'n:d:h:t:', \%args );

my $dmw = DMWrapper->new(%args);

$dmw->runAndExitWithExitStatus();

__END__

=pod

=encoding UTF-8

=head1 NAME

DMWrapper - This script is called by DM when running in multihost mode.

=head1 VERSION

version 0.013

=head1 SYNOPSIS

# run the second command in the mycommands.yaml
DMWrapCmd -n 1 -d mycommands.yaml

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
