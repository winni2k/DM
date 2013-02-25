package DistributedMake::base;
use version 0.77; our $VERSION = qv('0.1.005');

use 5.006;
use strict;
use warnings;
use File::Temp qw/tempdir tempfile/;
use File::Basename;

=head1 NAME

DistributedMake::base - A perl module for running pipelines

=head1 VERSION

0.1.005

=head1 SYNOPSIS

todo

=head1 GOOD PRACTICE

- Never make a directory a dependency. DistributedMake creates directories as it needs them.
- Never create rules that delete files. Delete files by hand instead. Chances are, Youwill be sorry otherwise.
- make runs in dryRun mode by default (this is for your own safety!).  Pass in 'dryRun => 0' to new() to run.

=cut

sub new {
    my ( $class, %args ) = @_;

    my %self = (

        # Make options
        'dryRun'  => 1, # show what will be run, but don't actually run anything
        'numJobs' => 1
        , # maximum number of jobs to run, or "" for maximum concurrency permitted by dependencies
          # Applicable to queue and non-queue situations
        'keepGoing'      => 0,
        'alwaysMake'     => 0,
        'debugging'      => 0,
        'ignoreErrors'   => 0,
        'printDirectory' => 0,
        'touch'          => 0,
        'unlink'         => 1,    # 0 = don't clean tmp file

        # Cluster engine options
        'queue'       => undef,
        'cluster'     => 'localhost',
        'memLimit'    => 4,                       # in gigabytes
        'rerunnable'  => 0,
        'name'        => undef,
        'projectName' => undef,
        'outputFile'  => 'distributedmake.log',
        'extra'       => '',

        # make options
        'tmpdir'  => '/tmp',
        'target'  => 'all',
        'targets' => [],

        # job array related information
        # check for undef to determine if job array has been
        # started but not ended
        'currentJobArrayObject' => undef,
        'globalTmpDir'          => undef,    # necessary for running job arrays

        ## other attributes...
        %args,
    );

    $self{'makefile'} = new File::Temp(
        TEMPLATE => "$self{'tmpdir'}/DistributedMake_XXXXXX",
        SUFFIX   => ".makefile",
        UNLINK   => $self{'unlink'}
    );

    chomp( my $sge_qmaster = qx(which sge_qmaster 2>/dev/null) );
    chomp( my $pbsdsh      = qx(which pbsdsh 2>/dev/null) );
    chomp( my $bsub        = qx(which bsub 2>/dev/null) );

    if ( defined $self{queue} && $self{queue} ne 'localhost' ) {
        if ( -e $sge_qmaster ) { $self{'cluster'} = 'SGE'; }

  #    elsif ( -e $pbsdsh )      { $self{'cluster'} = 'PBS'; } not supported yet
        elsif ( -e $bsub ) { $self{'cluster'} = 'LSF'; }
    }

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

    my %bja = (
        'cluster'     => $self->{'cluster'},
        'queue'       => $self->{'queue'},
        'memLimit'    => $self->{'memLimit'},
        'rerunnable'  => $self->{'rerunnable'},
        'name'        => $self->{'name'},
        'projectName' => $self->{'projectName'},
        'outputFile'  => $self->{'outputFile'},
        'extra'       => $self->{'extra'},
        %batchjoboverrides,
    );

# Setup the pre-commands (things like pre-making directories that will hold log files and output files)
    my @precmds;
    my $logdir = dirname( $bja{'outputFile'} );
    if ( !-e $logdir ) {
        my $mklogdircmd = "\@test \"! -d $logdir\" && mkdir -p $logdir";
        push( @precmds, $mklogdircmd );
    }

    foreach my $target (@targets) {
        my $rootdir = dirname($target);

        my $mkdircmd = "\@test \"! -d $rootdir\" && mkdir -p $rootdir";
        push( @precmds, $mkdircmd );
    }

# Setup the user's commands, taking care of imposing memory limits and adding in cluster prefix commands
    for ( my $i = 0 ; $i <= $#cmds ; $i++ ) {
        if (   $cmds[$i] =~ /^java /
            && $cmds[$i] =~ / -jar /
            && $cmds[$i] !~ / -Xmx/ )
        {
            $cmds[$i] =~ s/^java /java -Xmx$bja{'memLimit'}g /;
        }
    }

    if ( !defined( $bja{'name'} ) ) {
        my $firstcmd = $cmds[0];
        my $name     = "unknown";
        if ( $firstcmd =~ /java/ && $firstcmd =~ /-jar/ ) {
            ($name) = $firstcmd =~ /-jar\s+(.+?)\s+/;
        }
        else {
            $firstcmd =~ m/([A-Za-z0-9\.\_\-]+)/;
            $name = $1;
        }

        $bja{'name'} = &basename($name);
    }

    my $memRequest = 1.5 * $bja{'memLimit'};
    my $cmdprefix  = "";
    my $cmdpostfix = "";

    if ( defined( $bja{'queue'} ) && $bja{'queue'} ne 'localhost' ) {
        if ( $bja{'cluster'} eq 'SGE' ) {
            $cmdprefix =
"qsub -sync y -cwd -V -b yes -j y -l h_vmem=${memRequest}G -o $bja{'outputFile'} -N $bja{'name'}";
            $cmdprefix .=
              ( defined( $bja{'projectName'} ) )
              ? " -P $bja{'projectName'}"
              : "";
            $cmdprefix .= ( $bja{'rerunnable'} == 1 ) ? " -r yes" : " -r no";
            $cmdprefix .=
              ( defined( $bja{'queue'} ) && $bja{'queue'} ne 'cluster' )
              ? " -q $bja{'queue'}"
              : "";
            $cmdprefix .= $bja{'extra'};
        }
        elsif ( $bja{'cluster'} eq 'PBS' ) {

        }
        elsif ( $bja{'cluster'} eq 'LSF' ) {

#$cmdprefix = "bsub -q $bja{'queue'} -M $memCutoff -P $bja{'projectName'} -o $bja{'outputFile'} -u $bja{'mailTo'} -R \"rusage[mem=$integerMemRequest]\" $wait $rerunnable $migrationThreshold $bja{'extra'}";
        }
    }
    else {
        $cmdpostfix = "| tee -a $bja{'outputFile'}";
    }

    my @modcmds;

    foreach my $cmd (@cmds) {
        my $modcmd = $cmd;

        # protect single quotes if running on SGE
        # perhaps this could be an issue with one-liners
        #using double quotes? -- winni
        if ( $bja{cluster} eq q/SGE/ ) {
            $modcmd =~ s/'/"'/g;
            $modcmd =~ s/'/'"/g;
            $modcmd =~ s/\$/\$\$/g;
        }

        # protect $ signs from make by turning them into $$
        if ( $bja{cluster} eq q/localhost/ ) {
            $modcmd =~ s/\$/\$\$/g;
        }

        push( @modcmds, "$cmdprefix   $modcmd   $cmdpostfix" );
    }

# Setup the post-commands (touching output files to make sure the timestamps don't get screwed up by clock skew between cluster nodes).
    my @postcmds;
    foreach my $target (@targets) {
        push( @postcmds, "\@touch -c $target" );
    }

    # Emit the makefile commands
    print { $self->{'makefile'} } "$targets[0]: "
      . join( " ",    @dependencies ) . "\n\t"
      . join( "\n\t", @precmds ) . "\n\t"
      . join( "\n\t", @modcmds ) . "\n\t"
      . join( "\n\t", @postcmds ) . "\n\n";

    push( @{ $self->{'targets'} }, $targets[0] );
}

=head2 execute()

This method is called after all rules have been defined in order to write the make file and execute it.  No mandatory options. Takes only overrides.

=cut

sub execute {
    my ( $self, %overrides ) = @_;

    # checking to make sure all started job arrays were ended.
    die "Need to end all started job arrays with endJobArray()"
      if defined $self->{currentJobArrayObject};

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
        'touch'          => $self->{'touch'},
        'target'         => $self->{'target'},
        'touchFiles'     => $self->{'touchFiles'},
        %overrides,
    );

    my $numjobs = $makeargs{'numJobs'};

    my $makecmd = "make"
      . ( $makeargs{'dryRun'}         ? " -n" : "" )
      . ( $makeargs{'keepGoing'}      ? " -k" : "" )
      . ( $makeargs{'alwaysMake'}     ? " -B" : "" )
      . ( $makeargs{'ignoreErrors'}   ? " -i" : "" )
      . ( $makeargs{'printDirectory'} ? " -w" : "" )
      . ( $makeargs{'touch'}          ? " -t" : "" )
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

=head1 Job Arrays

=head2 Workflow

First, initialize a job array with startJobArray().  Add rules to the job array with addJobArrayRule().  Last, call endJobArray() to signal that no more rules will be added to this particular job array. Multiple job arrays can be defined after each other in this manner. execute() can only be called if the most recently started job array has been completed with endJobArray.

On SGE, the job array will only be started once the prerequisites of all job array rules have been updated.  On other platforms, each job will start once its prerequisite has been updated.  However, on all platforms, the job array target will only be updated once all rules have completed successfully.

=head2 startJobArray()

daes nothing unless 'cluster' eq 'SGE'.
Requires 'target' and 'globalTmpDir' to be specified as input keys:
    startJobArray(target=>$mytarget, globalTmpDir=>$mytmpdir)

=cut

sub startJobArray {
    my ( $self, %overrides ) = @_;

    die "startJobArray was called before endJobArray"
      if defined $self->{currentJobArrayObject};

    my %args = (
        commandsFile => undef,
        targetsFile  => undef,
        prereqsFile  => undef,
        target       => undef,
        globalTmpDir => undef,
        %overrides,
    );

    die "startJobArray needs a target to be specified"
      unless defined $args{target};

    # pull object tmp dir if none was passed in
    $args{globalTmpDir} =
      defined $args{globalTmpDir} ? $args{globalTmpDir} : $self->{globalTmpDir};

    # make sure globalTmpDir is defined and exists
    die
"startJobArray needs a global temporary directory to be specified with globalTmpDir and for that direcory to exist"
      unless defined $args{globalTmpDir} && -d $args{globalTmpDir};

    my $jobArrayObject = {
        fileHandles => {},
        files       => {},

        # final target to touch when all job array rules completed successfully
        target => $args{target},

        # lists of all targets and prereqs of all rules added to job array
        arrayTargets => [],
        arrayPrereqs => [],
    };

    ## initialize files to hold targets, commands and prereqs for job array
    # open file handles
    for my $name (qw(commands targets prereqs)) {
        (
            $jobArrayObject->{fileHandles}->{$name},
            $jobArrayObject->{files}->{$name}
          )
          = tempfile(
            $name . '_XXXX',
            DIR    => $args{globalTmpDir},
            UNLINK => 1
          );
    }

    # save new object
    $self->{currentJobArrayObject} = $jobArrayObject;
    return $jobArrayObject;
}

=head2 addJobArrayRule()

 This structure is designed to work with SGE's job array functionality.  Any rules added to a jobArray structure will be treated as simple add rules when running on localhost, LSF or PBS, but will be executed as a jobArray on SGE.

takes three inputs: target, prereqs, command as such:
  addJobArrayRule(target=>$mytarget, prereqs=>\@myprereqs, command=>$mycommand);

prereqs may also be a scalar

=cut

sub addJobArrayRule {
    my $self = shift;

    # get input
    my %args = @_;

    # check to make sure startJobArray() has been run
    die "need to run startJobArray() first"
      unless defined $self->{currentJobArrayObject};

    # check required args.
    foreach my $arg (qw/target prereqs command/) {
        die "need to define $arg" unless defined $args{$arg};
    }

    # keep track of all rule targets
    my $target =
      ref( $args{target} ) eq 'ARRAY' ? $args{target}->[0] : $args{target};
    push @{ $self->{currentJobArrayObject}->{arrayTargets} }, $target;

    # keep track of all rule prereqs
    my @prereqs = (
        ref( $args{prereqs} ) eq 'ARRAY'
        ? @{ $args{prereqs} }
        : $args{prereqs}
    );
    push @{ $self->{currentJobArrayObject}->{arrayPrereqs} }, @prereqs;

    # just use addRule unless we are in an SGE cluster
    unless ( $self->{cluster} eq 'SGE'
        || ( defined $args{cluster} && $args{cluster} eq 'SGE' ) )
    {
        $self->addRule( $args{target}, $args{prereqs}, $args{command}, %args );
    }
    else {

        ### Add target, prereqs and command to respective files
        # TARGET
        print { $self->{currentJobArrayObject}->{fileHandles}->{targets} }
          $target . "\n";

        # COMMAND
        print { $self->{currentJobArrayObject}->{fileHandles}->{commands} }
          $args{command} . "\n";

        # PREREQS - also add prereqs to job array prereqs file
        print { $self->{currentJobArrayObject}->{fileHandles}->{prereqs} }
          join( q/ /, @prereqs ) . "\n";
    }
}

=head2 endJobArray()

Adds the rule that kicks off the job array. 
Returns the target of the job array.

see startJobArray() for further description.

=cut

sub endJobArray {

    my $self = shift;

    # close all file handles
    map { close( $self->{currentJobArrayObject}->{fileHandles}->{$_} ) }
      keys %{ $self->{currentJobArrayObject}->{fileHandles} };

    # add job array rule
    #  makes sure target is touched when everything ran through successfully
    my $target = $self->{currentJobArrayObject}->{target};
    if ( $self->{cluster} eq 'SGE' ) {
        $self->addRule(
            $self->{currentJobArrayObject}->{target},
            $self->{currentJobArrayObject}->{arrayPrereqs},
            'sge_job_array.pl  -t '
              . $self->{currentJobArrayObject}->{files}->{targets} . ' -p '
              . $self->{currentJobArrayObject}->{files}->{prereqs} . ' -c '
              . $self->{currentJobArrayObject}->{files}->{commands}
              . " && touch $target"
        );
    }
    else {
        $self->addRule(
            $self->{currentJobArrayObject}->{target},
            $self->{currentJobArrayObject}->{arrayTargets},
            "touch $target"
        );

    }

    $self->{currentJobArrayObject} = undef;
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

## Please see file perltidy.ERR
