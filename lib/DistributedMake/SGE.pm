package DistributedMake::SGE;
use version 0.77; our $VERSION = qv('0.0.2');

use strict;
use 5.008008;    # use perl version 5.8.8 or later
use Carp;

use Exporter q/import/;
our @EXPORT_OK = qw/run_qsub delete_file_in_options find_active_jids wait_on_jids concat_generic/;

=head1 SYNOPSIS

    my $wrapper_location = "$dir/$run_name/qsub_wrapper.sh";
    my $qsub_options     = ' -V ' . $job_array_qsub_options;
    my $wrapper          = <<END_QSUB;
#!/bin/sh

#\$ -S /bin/sh
#\$ -N $run_name
WD="$WD"
mkdir \$WD
cd \$WD
STDOUT="\$WD/stdout_$sim_program_name.\$SGE_TASK_ID"
STDERR="\$WD/stderr_$sim_program_name.\$SGE_TASK_ID"
date > \$STDOUT
$sim_program 2>\$STDERR $params >$wrapper_1_output
date >> \$STDOUT
END_QSUB

	my $jid = run_qsub ( 
		wrapper => $wrapper, 
		wrapper_location => $wrapper_location, 
		qsub_options => $qsub_options 
	); 
	# submits $wrapper with $qsub_options qsub_options
	
	wait_on_jids(2, $jid); # waits on $jid and checks every 2 seconds

=cut

sub run_qsub {

    my %options = @_;
    my $wrapper = $options{wrapper}
      || die "Need to pass in the wrapper as 'wrapper => \$wrapper'";
    my $wrapper_location = $options{wrapper_location}
      || die
"Need to pass in the wrapper location as 'wrapper_location => \$wrapper_location'";
    my $qsub_options = $options{qsub_options};
    my $keep_stdout  = $options{keep_stdout};
    my $keep_stderr  = $options{keep_stderr};

    if ( defined $qsub_options ) {
        unless ($keep_stderr) {
            delete_file_in_options( $qsub_options, q(-e) );
        }
        unless ($keep_stdout) {
            delete_file_in_options( $qsub_options, q(-o) );
        }
    }

    my $fh_QSUB;
    unless ( open $fh_QSUB, "> $wrapper_location" ) {
        die "unable to write to $wrapper_location";
    }

    print $fh_QSUB $wrapper;
    close $fh_QSUB;

    unless ( defined $qsub_options ) { $qsub_options = q( ) }

    my $return = `qsub $qsub_options $wrapper_location`;
    my @return = split( /[ \.]/, $return );

    my $jid;
    foreach my $word ( 0 .. $#return ) {
        if ( $return[$word] =~ /job/ ) {
            $jid = $return[ $word + 1 ];
            last;
        }
    }

    return $jid;
}

sub delete_file_in_options {

    my ( $parameters, $option ) = @_;
    my @parameters = split( /\s+/, $parameters );

    my $word_to_delete = 0;
    foreach my $word (@parameters) {
        if ($word_to_delete) {
            if ( -f $word ) { unlink($word); }
            last;
        }
        if ( $word eq "$option" ) { $word_to_delete = 1; }
    }

}

sub find_active_jids {

    my @jids = @_;

    my @active_jids;

    my @qstat = `qstat`;
    foreach my $jid (@jids) {
        if ( grep { /($jid)/ } @qstat ) {
            push @active_jids, $jid;
        }
    }
    return @active_jids;
}

sub wait_on_jids {

    my ( $sleep, @active_jids ) = @_;

    while (@active_jids) {
        print "\nWaiting for active jids:\n";
        foreach my $jid (@active_jids) {
            print "\t$jid\n";
        }
        sleep($sleep);
        @active_jids = find_active_jids(@active_jids);
    }

}

sub concat_generic {

    croak "need three inputs" if @_ != 3;
    my ( $target, $ra_files, $compressor ) = @_;

    if ( $compressor !~ /gzip|none/ ) {
        croak "Compressor must be set to 'gzip' or 'none'";
    }

    my $gzip = $compressor eq 'gzip';
    my $open;

    my @files = @{$ra_files};

    my $fh_OUT;
    if   ($gzip) { $open = "| gzip -c > $target"; }
    else         { $open = " > $target"; }
    open $fh_OUT, "$open"
      or croak "Could not open file $target $!";

    my $file_counter = 1;
    foreach my $file (@files) {
        my $fh_IN;
        if   ($gzip) { $open = "gunzip -c < $file |"; }
        else         { $open = " < $file"; }
        open $fh_IN, "$open"
          or croak "Could not open file $file $!";

        my $line_counter = 1;
      LINE: while (<$fh_IN>) {
            if ( $file_counter > 1 && $line_counter == 1 ) {
                next LINE;
            }
            print $fh_OUT $_;
        }
        continue {
            $line_counter++;
        }
        close $fh_IN;
    }
    continue {
        $file_counter++;
    }
    close $fh_OUT

}
