our $VERSION = '0.001';
$VERSION = eval $VERSION;

#print STDERR "DMWrapCmd.pl -- $VERSION\nBy\twkretzsch@gmail.com\n\n";

=head1 NAME

DMWrapCmd.pl

=head1 SYNOPSIS

# run the second command in the mycommands.yaml
DMWrapCmd -n 1 -d mycommands.yaml

=cut

package DMWrapper;
use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use YAML::XS;
use File::NFSLock;
use Carp;

has tag => ( is => 'ro', isa => 'Str', default => "[DMWRapCmd.pl]" );

# input variables
has dataFile => ( is => 'ro', isa => 'Str', required => 1, init_arg => 'd' );
has tempDir => ( is => 'ro', isa => 'Str', required =>, init_arg => 't' );
has hostsFile => ( is => 'ro', isa => 'Str', required => 1, init_arg => 'h' );
has jobNum =>
  ( is => 'ro', isa = 'DM::PositiveInt', required =>, init_arg => 'n' );

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
    isa     => 'ArrayRef[HashRef]',
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
    isa     => 'ArrayRef[Str]',
    builder => '_build_hostLockFiles',
    lazy    => 1
);
has hosts => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    builder => '_build_hosts',
    lazy    => 1
);

sub _build_hosts {
    my $self  = shift;
    my $hosts = LoadFile( $self->hostsFile );
    my @hosts;
    for my $host ( sort keys %{$hosts} ) {
        for my $hostNum ( 0 .. ( $hosts->{$host} - 1 ) ) {
            push @hosts, $host;
        }
    }
    return \@hosts;
}

sub _build_hostLockFiles {
    my $self  = shift;
    my $hosts = $self->hosts;
    my $tempDir  = $self->tempDir;

    my $hostNum  = 0;
    my $lastHost = $hosts->[0];
    my @hostLocks;
    for my $host ( @{$hosts} ) {
        $hostNum = 0 if $host ne $lastHost;
        push @hostLocks, $tempDir . "/$host.lock$hostNum";
        ++$hostNum;
    }
    return \@hostLocks;
}

sub _build_jobs {
    my $self = shift;
    my $jobs = LoadFile( $self->dataFile );

    croak $self->tag
      . " Input job number is larger than jobs in data file: "
      . $self->dataFile
      if $self->jobNum >= @{$jobs};
    return $jobs;
}

sub _build_cmd {
    my $self = shift;
    return $self->jobs->[ $self->jobNum ];
}

sub _build_lockObject {
    my $self = shift;

    my $blocking_timeout = 5;
    my $hostLockFiles    = $self->hostLockFiles;
    while (1) {
        for my $hostLockFile ( @{$hostLockFiles} ) {
            my $lock = File::NFSLock->new(
                {
                    file             => $hostLockFile,
                    lock_type        => 'BLOCKING',
                    blocking_timeout => $blocking_timeout,
                }
            );
            if ( defined $lock ) {
                return $lock;
            }
        }
    }
}

sub exitWithExitStatus {
    my $self = shift;
    my $cmd  = $self->cmd;

    my $lock = $self->lockObject;
    system($cmd );
    $cmd = '[DMWrapCmd.pl] Command: ' . $cmd;
    if ( $? == -1 ) {
        print STDERR "$cmd\nFailed to execute: $!\n";
        exit 1;
    }
    elsif ( $? & 127 ) {
        printf STDERR "$cmd\nChild died with signal %d, %s coredump\n",
          ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
    }
    else {
        if ( $? >> 8 ) {
            printf STDERR "$cmd\nCommand exited with non-zero value %d\n",
              $? >> 8;
        }
    }
    exit $? >> 8;
}

__PACKAGE__->meta->make_immutable;

use strict;
use warnings;
use Getopt::Std;
my %args;
getopts( 'n:d:h:t:', \%args );

my $dmw = DMWrapper->new(%args);

$dmw->runAndExitWithExitStatus();
