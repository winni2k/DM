our $VERSION = '0.001';
$VERSION = eval $VERSION;

#print STDERR "DMWrapCmd.pl -- $VERSION\nBy\twkretzsch@gmail.com\n\n";

=head1 NAME

DMWrapCmd.pl

=head1 SYNOPSIS

# run the second command in the mycommands.yaml
DMWrapCmd -n 1 -d mycommands.yaml

=cut

use YAML::XS;
use Carp;
use Getopt::Std;
my %args;
getopts( 'n:d:h:', \%args );

croak "[DMWrapCmd.pl] Need to specify data file with -h" unless -d $args{d};
my $jobNum = $args{n}
  || croak "[DMWrapCmd.pl] Need to specify job number to run with -n";

my @jobs = LoadFile( $args{d} );

croak
  "[DMWrapCmd.pl] Input job number is larger than jobs in data file: $args{d}"
  if $jobNum >= @jobs;

my $cmd = $jobs[$jobNum];

runAndExitWithExitStatus($cmd);

sub exitWithExitStatus {
    my $cmd = shift;

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

