package DistributedMake::base;
use version 0.77; our $VERSION = qv('0.0.5');

use 5.006;
use strict;
use warnings;
use File::Temp qw/tempdir/;
use File::Basename;

=head1 NAME

DistributedMake::base - A perl module for running pipelines

=head1 SYNOPSIS

todo

=head1 GOOD PRACTICE

Never make a directory a dependency. make creates directories as it needs them.
Never create rules that delete files. Delete files by hand instead. Chances are, You'll be sorry otherwise.

=cut

sub parseHostsString {
    my ($hoststring) = @_;

    if ( $hoststring !~ /\s+\+\s+/ ) {
        return undef;
    }

    my @hostobjs = split( /\s+\+\s+/, $hoststring );

    my @hosts;
    foreach my $hostobj (@hostobjs) {
        my ( $multiplier, $server ) = $hostobj =~ /(\d+)\*(\w+)/;
        for ( my $i = 0 ; $i < $multiplier ; $i++ ) {
            push( @hosts, $server );
        }
    }

    return \@hosts;
}

sub new {
    my ( $class, %args ) = @_;

    my %self = (

        # Almost make options
        'dryRun'       => 1,      # don't run anything, just dry run, duh
        'numJobs'      => undef,  # "" means max as many jobs as possible
                                  # Applicable to queue and non-queue situations
        'keepGoing'    => 0,
        'alwaysMake'   => 0,
        'debugging'    => 0,
        'ignoreErrors' => 0,
        'printDirectory' => 0,

        # Script options
        'unlink'            => 1,       # 0 = don't clean tmp file
        'passed_in_tmp_dir' => undef,
        'hosts'             => ""
        , # ugly hack to run in distribution across multiple hosts via passwordless ssh

        # Cluster engine options
        'queue'          => undef,
        'cluster_engine' => undef,    # values allowed are 'sge' and 'lsf'
        'outputFile' => 'distributedmake.log',
        'rerunnable' => 0,
        'memLimit'   => 2,                       # only half implemented in sge

        # LSF cluster engine specific options
        'mailTo'             => 'crd-lsf@broad.mit.edu',
        'wait'               => 1,
        'migrationThreshold' => undef,
        'extra'              => '',

        # SGE cluster specific options
        'project_share' => undef,

        # make options?
        'target' => 'all',

        # other attributes...
        %args,

        'targets'   => [],
        'hostindex' => 0,

        # Keep tmp qsub wrappers around until make is done
        'tmp_files_to_unlink' => [],

    );

    $self{'makefile'} = new File::Temp(
        TEMPLATE => "/tmp/DistributedMake_XXXXXX",
        SUFFIX   => ".makefile",
        UNLINK   => $self{'unlink'}
      ),
      $self{'hostarray'} = parseHostsString( $self{'hosts'} );
    $self{'projectName'} = basename( $self{'makefile'} );

    bless \%self, $class;

    return \%self;
}

sub addRule {
    my ( $self, $targetsref, $dependenciesref, $cmdsref, %batchjoboverrides ) =
      @_;
    my @targets =
      ( ref($targetsref) eq 'ARRAY' ) ? @$targetsref : ($targetsref);
    my @dependencies =
      ( ref($dependenciesref) eq 'ARRAY' )
      ? @$dependenciesref
      : ($dependenciesref);
    my @cmds = ( ref($cmdsref) eq 'ARRAY' ) ? @$cmdsref : ($cmdsref);

    my @prepcmds;

    my $cmdprefix = "";
    if ( defined( $self->{'hostarray'} ) ) {
        $cmdprefix = "ssh ${$self->{'hostarray'}}[$self->{'hostindex'}] ";

        $self->{'hostindex'}++;
        if ( $self->{'hostindex'} == scalar( @{ $self->{'hostarray'} } ) - 1 ) {
            $self->{'hostindex'} = 0;
        }
    }
    elsif (
        (
               defined( $self->{'cluster_engine'} )
            && $self->{'cluster_engine'} eq 'lsf'
            && (
                exists( $batchjoboverrides{'queue'} )
                ? defined( $batchjoboverrides{'queue'} )
                && $batchjoboverrides{'queue'} ne ''
                : 1
            )
        )
        || (   exists( $batchjoboverrides{'queue'} )
            && defined( $batchjoboverrides{'queue'} )
            && $batchjoboverrides{'queue'} ne '' )
      )
    {
        my %bja = (
            'queue'              => $self->{'queue'},
            'memLimit'           => $self->{'memLimit'},
            'projectName'        => $self->{'projectName'},
            'outputFile'         => $self->{'outputFile'},
            'mailTo'             => $self->{'mailTo'},
            'wait'               => $self->{'wait'},
            'rerunnable'         => $self->{'rerunnable'},
            'migrationThreshold' => $self->{'migrationThreshold'},
            'extra'              => $self->{'extra'},
            'addToProjectName'   => q//,
            %batchjoboverrides,
        );

        $bja{'projectName'} .= $bja{'addToProjectName'};
        
        my $rerunnable = $bja{'rerunnable'} ? "-r" : "";
        my $migrationThreshold =
          $bja{'rerunnable'} && defined( $bja{'migrationThreshold'} )
          ? "-mig $bja{'migrationThreshold'}"
          : "";
        my $wait = $bja{'wait'} ? "-K" : "";

        my $logdir = dirname( $bja{'outputFile'} );
        if ( !-e $logdir ) {
            my $mklogdircmd = "\@test \"! -d $logdir\" && mkdir -p $logdir";
            push( @prepcmds, $mklogdircmd );
        }

        my $memRequest        = $bja{'memLimit'} * 1.5;
        my $integerMemRequest = int($memRequest);
        my $memCutoff         = $bja{'memLimit'} * 1024 * 1024 * 1.25;

# A quick check to make sure that java commands being dispatched to the farm are instructed to run under a default memory limit
        for ( my $i = 0 ; $i <= $#cmds ; $i++ ) {
            if (   $cmds[$i] =~ /^java /
                && $cmds[$i] =~ / -jar /
                && $cmds[$i] !~ / -Xmx/ )
            {
                $cmds[$i] =~ s/^java /java -Xmx$bja{'memLimit'}g /;
            }
        }

        $cmdprefix =
"bsub -q $bja{'queue'} -M $memCutoff -P $bja{'projectName'} -o $bja{'outputFile'} -u $bja{'mailTo'} -R \"rusage[mem=$integerMemRequest]\" $wait $rerunnable $migrationThreshold $bja{'extra'}    ";
    }
    elsif (
        (
               defined( $self->{'cluster_engine'} )
            && $self->{'cluster_engine'} eq 'sge'
            && (
                exists( $batchjoboverrides{'queue'} )
                ? defined( $batchjoboverrides{'queue'} )
                && $batchjoboverrides{'queue'} ne ''
                : 1
            )
        )
        || (   exists( $batchjoboverrides{'queue'} )
            && defined( $batchjoboverrides{'queue'} )
            && $batchjoboverrides{'queue'} ne '' )
      )
    {
        my %bja = (
            'queue'       => $self->{'queue'},
            'outputFile'  => $self->{'outputFile'},
            'projectName' => $self->{'projectName'},                  # optional
            'rerunnable'  => $self->{'rerunnable'} eq 0 ? 'n' : 'y',
            'memLimit' => $self->{'memLimit'},    # not currently implemented
            'project_share' => $self->{project_share},    # becomes -P option
            extra           => $self->{'extra'},
            'addToProjectName'   => q//,
            %batchjoboverrides,
        );

        $bja{'projectName'} .= $bja{'addToProjectName'};

        my $logdir = dirname( $bja{'outputFile'} );
        if ( !-e $logdir ) {
            my $mklogdircmd = "\@test \"! -d $logdir\" && mkdir -p $logdir";
            push( @prepcmds, $mklogdircmd );
        }

        my $memRequest        = $bja{'memLimit'} * 1.5;
        my $integerMemRequest = int($memRequest);
        my $memCutoff         = $bja{'memLimit'} * 1024 * 1024 * 1.25;

# A quick check to make sure that java commands being dispatched to the farm are instructed to run under a default memory limit
        for ( my $i = 0 ; $i <= $#cmds ; $i++ ) {
            if (   $cmds[$i] =~ /^java /
                && $cmds[$i] =~ / -jar /
                && $cmds[$i] !~ / -Xmx/ )
            {
                $cmds[$i] =~ s/^java /java -Xmx$bja{'memLimit'}g /;
            }
        }

        $cmdprefix = "qsub -V -q $bja{'queue'} -o $bja{'outputFile'} "
          . "-r $bja{'rerunnable'} -j y -sync y $bja{'extra'}";
        $cmdprefix .= " -N $bja{'projectName'}" if defined $bja{'projectName'};
        $cmdprefix .= " -P $bja{'project_share'}"
          if defined $bja{'project_share'};
        $cmdprefix .= q/    /;
    }

    my $rootdir = dirname( $targets[0] );
    if ( !-e $rootdir ) {
        my $mkdircmd = "\@test \"! -d $rootdir\" && mkdir -p $rootdir";
        push( @prepcmds, $mkdircmd );
    }

# We have to touch the final file just in case the time between different nodes on the farm are not synchronized.
    print { $self->{'makefile'} } "$targets[0]: "
      . join( " ",    @dependencies ) . "\n\t"
      . join( "\n\t", @prepcmds );

    # add the rest of the makefile. in most cases:
    unless ( defined( $self->{'cluster_engine'} )
        && $self->{'cluster_engine'} eq 'sge' )
    {
        print { $self->{'makefile'} } "\n\t$cmdprefix"
          . join( "\n\t$cmdprefix", @cmds );
    }

    # in the case of sge, we'll need to create wrapper scripts
    else {
        my $tmp_dir;
        if ( defined $self->{passed_in_tmp_dir} ) {
            $tmp_dir = $self->{passed_in_tmp_dir};
        }
        else {
            $tmp_dir =
              tempdir( TEMPLATE => 'qsub_commands_XXXXXX', CLEANUP => 1 );
        }
        my @cmdfiles;
        foreach my $cmd (@cmds) {
            my $rand_num = 0;
            while ( -e "$tmp_dir/qsub_command_$rand_num" ) {
                $rand_num = rand();
            }
            my $tmp_file = "$tmp_dir/qsub_command_$rand_num";
            open( my $tmp_fh, '>', "$tmp_file" );
            print $tmp_fh "#!$ENV{SHELL}\n$cmd\n";
            close($tmp_fh);
            push @cmdfiles, $tmp_file;

            # Keep tmp qsub wrappers around until make is done
            push @{ $self->{tmp_files_to_unlink} }, $tmp_dir;
        }
        print { $self->{'makefile'} } "\n\t$cmdprefix"
          . join( "\n\t$cmdprefix", @cmdfiles );
    }
    print { $self->{'makefile'} } "\n\ttouch -c $targets[0]\n\n\n";
    push( @{ $self->{'targets'} }, $targets[0] );
}

sub execute {
    my ( $self, %overrides ) = @_;

    print { $self->{'makefile'} } "all: "
      . join( " ", @{ $self->{'targets'} } ) . "\n\n";
    print { $self->{'makefile'} } ".DELETE_ON_ERROR:\n";

    my %makeargs = (
        'dryRun'         => $self->{'dryRun'},
        'numJobs'        => $self->{'numJobs'},
        'keepGoing'      => $self->{'keepGoing'},
        'alwaysMake'     => $self->{'alwaysMake'},
        'debugging'      => $self->{'debugging'},
        'ignoreErrors'   => $self->{'ignoreErrors'},
        'printDirectory' => $self->{'printDirectory'},
        'target'         => $self->{'target'},
        %overrides,
    );

    my $numjobs = $makeargs{'numJobs'};
    if ( !defined($numjobs) ) {
        if ( defined( $self->{'hostarray'} )
            && scalar( $self->{'hostarray'} ) > 0 )
        {
            $numjobs = scalar( @{ $self->{'hostarray'} } );
        }
        else {
            $numjobs = 1;
        }
    }

    my $makecmd = "make"
      . ( $makeargs{'dryRun'}         ? " -n" : "" )
      . ( $makeargs{'keepGoing'}      ? " -k" : "" )
      . ( $makeargs{'alwaysMake'}     ? " -B" : "" )
      . ( $makeargs{'ignoreErrors'}   ? " -i" : "" )
      . ( $makeargs{'printDirectory'} ? " -w" : "" )
      . (
        $makeargs{'debugging'} =~ /[abvijm]+/
        ? " --debug=$makeargs{'debugging'}"
        : ""
      )
      . (    $makeargs{'debugging'} =~ /\d+/
          && $makeargs{'debugging'} == 1 ? " -d" : "" )
      . " -j $numjobs" . " -f "
      . $self->{'makefile'}->filename
      . " $makeargs{'target'}";

    print "$makecmd\n";
    system($makecmd);
    print "$makecmd\n";
}

=head1 AUTHOR

Kiran V Garimella, C<< <kiran at well.ox.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-distributedmake-base at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DistributedMake-base>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DistributedMake::base


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DistributedMake-base>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DistributedMake-base>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DistributedMake-base>

=item * Search CPAN

L<http://search.cpan.org/dist/DistributedMake-base/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Kiran V Garimella.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of DistributedMake::base

