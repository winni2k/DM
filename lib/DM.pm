package DM;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

use 5.006;
use File::Temp qw/tempdir tempfile/;
use File::Basename;
use Carp;
use DM::JobArray;
use DM::Job;
use DM::Distributer;
use DM::TypeDefs;

=head1 NAME

DM - Distributed Make: A perl module for running pipelines

=head1 VERSION

0.2.8

=head1 CHANGES

See Changes file

=head1 SYNOPSIS

use DM 0.002001;

# create a DM object

my $dm = DM->new(
    dryRun => 0,
    numJobs => 5
)

# add rule with target, prerequisite, and command to use to update the target

$dm->addRule( 'targetFile', 'prerequisiteFile', 'touch targetFile' );

# add more rules ...

# executed the pipeline 

$dm->execute();

=head1 DESCRIPTION

DM is a perl module for running pipelines.  DM is based on GNU make.  Currently, DM supports running on a single computer or an SGE managed cluster.

=head1 GOOD PRACTICE

=over

=item * 

Never make a directory a dependency. DM creates directories as it needs them.

=item *

Never create rules that delete files. Delete files by hand instead. Chances are, You will be sorry otherwise.

=item *

make runs in dryRun mode by default (this is for your own safety!).  Pass in 'dryRun => 0' to new() to run.

=back

=head1 OPTIONS

Any of the following options can be passed in to a call to new() in order to change the defaults on how make is run by DM. The default value is listed behind the option name.

=head2 GNU make specific options

=over

=item dryRun 1

show what will be run, but don't actually run anything. Corresponds to -n option in GNU make.

=item numJobs 1

maximum number of jobs to run, or "" for maximum concurrency permitted by dependencies. Applicable to queue and non-queue situations. Corresponds to -j option in GNU make.

=item keepGoing 0

if any job returns a non-zero exit status, the default behaviour is not to submit any further jobs and wait for the others to finish.  If this option is true, then any jobs that do not depend on the failed job(s) will still be submitted. Corresponds to -k option in GNU make.

=item alwaysMake 0

Unconditionally make all targets. Corresponds to -B option in GNU make.

=item touch 0

If true, touch all targets such that make will think that all files have been made successfully. This is only partially supported, as touch will not create any prerequisite directories. Corresponds to -t option in GNU make. 

=item ignoreErrors 0

Corresponds to -i option in GNU make.

=back

=head2 SGE specific options

These options are passed to qsub for submitting jobs on an SGE cluster

=over

=item cluster undef

Type of cluster (localhost, SGE, PBS, LSF).  Is detected automagically by DM.

=item queue undef

Corresponds to -q.

=item projectName undef

Corresponds to -P.

=item PE { name => undef, range => undef }

Anonymous hash reference. Corresponds to -pe option

=item name

Corresponds to -N option.

=back

=head2 other options

=over

=item globalTmpDir undef

Directory for storing temporary files that can be accessed by every node on the cluster (usually not /tmp)

=item tmpdir /tmp

Directory for storing temporary files.

=back

=head1 GENERAL FUNCTIONS

=head2 new()

Returns a DM object.  Options (see the Options section) can be passed to new() as key value pairs.

=over

=item Required Arguments

none

=item Returns

DM object

=back

=cut

# Input Variables

### make related options
has dryRun => ( is => 'ro', isa => 'Bool', default => 1 );

# maximum number of jobs to run, or 0 for maximum concurrency
# permitted by dependencies
has numJobs => ( is => 'ro', isa => 'DM::PositiveInt', default => 1 );

# Applicable to queue and non-queue situations
for my $name (
    qw/keepGoing alwaysMake debugging ignoreErrors printDirectory touch/)
{
    has $name => ( is => 'ro', isa => 'Bool', default => 0 );
}

# 0 = don't clean tmp file
has unlinkTmp => ( is => 'ro', isa => 'Bool', default => 1 );

has _engine => (
    is       => 'ro',
    isa      => 'DM::Distributer',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_distributer',
);

# use engineArgs to override DM::Distributer arguments
has engineArgs =>
  ( is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} } );

sub _build_distributer {
    my $self = shift;
    my $dd   = DM::Distributer->new( %{ $self->engineArgs },
        globalTmpDir => $self->globalTmpDir );
    unless ( $dd->engineName eq 'localhost' ) {
        croak
          "[DM] need to define globalTmpDir if not running in localhost mode"
          unless defined $self->globalTmpDir;
    }
    return $dd;
}

has outputFile => ( is => 'rw', isa => 'Str' );

# in gigabytes
has memLimit => ( is => 'rw', isa => 'DM::PositiveNum', default => 4 );

# make options
has tmpdir  => ( is => 'ro', isa => 'Str',           default => '/tmp' );
has target  => ( is => 'ro', isa => 'Str',           default => 'all' );
has targets => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] } );

# job array related information
# check for undef to determine if job array has been
# started but not ended
has _currentJA => (
    is       => 'rw',
    isa      => 'Maybe[DM::JobArray]',
    init_arg => undef,
    default  => undef
);

has globalTmpDir => ( is => 'rw', isa => 'Maybe[Str]', default => undef );

has _makefile => (
    is       => 'ro',
    isa      => 'File::Temp',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_makefile'
);

sub _build_makefile {
    my $self = shift;
    return File::Temp->new(
        TEMPLATE => $self->tmpdir . "/DM_XXXXXX",
        SUFFIX   => ".makefile",
        UNLINK   => $self->unlinkTmp
    );
}

sub engineName {
    my $self = shift;
    return $self->_engine->engineName;
}

=head2 addRule()

This function creates a basic dependency between a prerequisite, target and command.  The prerequisite is a file that is required to exist in order to create the target file.  The command is used to create the target file from the prerequisite.

=over

=item Required Arguments

<string>  -  target file

<string or ref to array of strings>  -  prerequisite file(s)

<string>  -  command

=item Returns

none

=back

=cut

sub addRule {
    my ( $self, $targetsref, $dependenciesref, $cmdsref, %batchjoboverrides ) =
      @_;

    my $job = DM::Job->new(
        targets  => $targetsref,
        prereqs  => $dependenciesref,
        commands => $cmdsref
    );

    # Setup the user's commands, taking care of imposing memory limits and
    # adding in cluster prefix commands
    my @cmds = @{ $job->commands };
    for ( my $i = 0 ; $i <= $#cmds ; $i++ ) {
        if (   $cmds[$i] =~ /^java /
            && $cmds[$i] =~ / -jar /
            && $cmds[$i] !~ / -Xmx/ )
        {
            my $memLimit = $self->memLimit;
            $cmds[$i] =~ s/^java /java -Xmx${memLimit}g /;
        }
    }
    $job->commands( \@cmds );

    # hand job to distribute engine
    my $engine = $self->_engine;
    $engine->job($job);

    # setting batchjob overrides to engine object. Revert at end of sub
    my %origOverrides;
    for my $key ( sort keys %batchjoboverrides ) {
        $origOverrides{$key} = $engine->$key;
        $engine->$key( $batchjoboverrides{$key} );
    }

    # Emit the makefile commands
    print { $self->_makefile } $self->_engine->jobAsMake;

    push( @{ $self->targets }, $self->_engine->job->target );

    # undo temporary overrides
    for my $key ( sort keys %origOverrides ) {
        $engine->$key( $origOverrides{$key} );
    }

    return $self->_engine->job;
}

=head2 execute()

This method is called after all rules have been defined in order to write the make file and execute it.  No mandatory options. Takes only overrides.

=over

=item Required Arguments

none

=item Returns

exits status. 0 means no problems.

=back

=cut

sub execute {
    my ( $self, %overrides ) = @_;

    # checking to make sure all started job arrays were ended.
    die "Need to end all started job arrays with endJobArray()"
      if defined $self->_currentJA;

    print { $self->_makefile } "all: "
      . join( " ", @{ $self->{'targets'} } ) . "\n\n";
    print { $self->_makefile } ".DELETE_ON_ERROR:\n";

    my %makeargs = (
        dryRun         => $self->dryRun,
        numJobs        => $self->numJobs,
        keepGoing      => $self->keepGoing,
        alwaysMake     => $self->alwaysMake,
        debugging      => $self->debugging,
        ignoreErrors   => $self->ignoreErrors,
        printDirectory => $self->printDirectory,
        touch          => $self->touch,
        target         => $self->target,
        %overrides,
    );

    my $numjobs = $makeargs{'numJobs'};

    my $makecmd = "make"
      . ( $makeargs{dryRun}         ? " -n" : "" )
      . ( $makeargs{keepGoing}      ? " -k" : "" )
      . ( $makeargs{alwaysMake}     ? " -B" : "" )
      . ( $makeargs{ignoreErrors}   ? " -i" : "" )
      . ( $makeargs{printDirectory} ? " -w" : "" )
      . ( $makeargs{touch}          ? " -t" : "" )
      . (
        $makeargs{debugging} =~ /[abvijm]+/
        ? " --debug=$makeargs{debugging}"
        : ""
      )
      . (    $makeargs{debugging} =~ /\d+/
          && $makeargs{debugging} == 1 ? " -d" : "" )
      . " -j $numjobs" . " -f "
      . $self->_makefile->filename
      . " $makeargs{target}";

    $self->_makefile->flush;
    $self->_engine->finalize;
    print "$makecmd\n";
    system($makecmd);
    my $errCode = $? >> 8;
    print "$makecmd\n";

    return $errCode;
}

=head1 JOB ARRAY FUNCTIONS

=head2 Workflow

First, initialize a job array with startJobArray().  Add rules to the job array with addJobArrayRule().  Last, call endJobArray() to signal that no more rules will be added to this particular job array. Multiple job arrays can be defined after each other in this manner. execute() can only be called if the most recently started job array has been completed with endJobArray.

On SGE, the job array will only be started once the prerequisites of all job array rules have been updated.  On other platforms, each job will start once its prerequisite has been updated.  However, on all platforms, the job array target will only be updated once all rules of that job array have completed successfully.  

Only the target specified in startJobArray() should be used as a prerequisite for other rules.  The targets specified through addJobArrayRule() should never be used as prerequisites for other rules.

=head2 startJobArray()

daes nothing unless 'cluster' eq 'SGE'.
Requires 'target' and 'globalTmpDir' to be specified as key value pairs:
    startJobArray(target=>$mytarget, globalTmpDir=>$mytmpdir)

=cut

sub startJobArray {
    my ( $self, %overrides ) = @_;

    die "startJobArray was called before endJobArray"
      if defined $self->_currentJA;

    my %args = (
        target       => undef,
        globalTmpDir => $self->globalTmpDir,
        name         => 'DM::JobArray',
        %overrides,
    );

    # definition of jobArrayObject
    my $jobArrayObject = DM::JobArray->new(
        globalTmpDir => $args{globalTmpDir},
        name         => $args{name},
        target       => $args{target}
    );

    # save new object
    $self->_currentJA($jobArrayObject);
    return $jobArrayObject;
}

=head2 addJobArrayRule()

This structure is designed to work with SGE's job array functionality.  Any rules added to a jobArray structure will be treated as simple add rules when running on localhost, LSF or PBS, but will be executed as a jobArray on SGE.

=head3 Required Arguments

takes three inputs: target, prereqs, command as key value pairs:

addJobArrayRule( 
    target  => $mytarget, 
    prereqs => \@myprereqs, 
    command => $mycommand 
);

or as a list
addJobArrayRule( 
    $mytarget, 
    \@myprereqs, 
    $mycommand 
);
prereqs may also be a scalar (string).  

The target is only for internal updating by the job array.  The target may not be used as a prerequisite for another rule.  Use the job array target instead.

=head3 Returns

none

=cut

sub addJobArrayRule {
    my $self = shift;
    my %jobArgs;
    my %origArgs;

    # check to make sure startJobArray() has been run
    die "need to run startJobArray() first"
      unless defined $self->_currentJA;

    # allow three arg input
    if ( @_ == 3 ) {
        for my $arg (qw/target prereqs command/) {
            $jobArgs{$arg} = shift;
        }
    }

    # otherwise check required args.
    else {
        my %args = @_;
        foreach my $arg (qw/target prereqs command/) {
            croak "need to define $arg" unless defined $args{$arg};
            $jobArgs{$arg} = delete $args{$arg};
        }

        # set engine args
        for my $arg ( sort keys %args ) {
            $origArgs{$arg} = $self->_engine->$arg;
            $self->_engine->$arg( $args{$arg} );
        }
    }

    # parse job args by creating a job object
    my $job = DM::Job->new(
        targets  => $jobArgs{target},
        prereqs  => $jobArgs{prereqs},
        commands => $jobArgs{command}
    );

    # just use addRule unless we are in an SGE cluster
    unless ( $self->engineName eq 'SGE' ) {
        $self->_currentJA->addJob(
            $self->addRule( $job->targets, $job->prereqs, $job->commands ) );
    }
    else {
        $self->_currentJA->addSGEJob($job);
    }

    # return engine args back to original state
    for my $arg ( sort keys %origArgs ) {
        $self->_engine->$arg( $origArgs{$arg} );
    }
}

=head2 endJobArray()

Adds the rule that kicks off the job array. See Workflow for further description.

=head3 Requried Arguments

none

=head3 Returns

The target of the job array

=cut

sub endJobArray {

    my $self = shift;

    # close all file handles
    #    $self->{currentJobArrayObject}->closeFileHandles;

    # determine how many tasks to kick off in job array
    my $arrayTasks = @{ $self->_currentJA->arrayTargets };

    # add job array rule
    #  makes sure target is touched when everything ran through successfully
    my $target = $self->_currentJA->target;
    if ( $self->engineName eq 'SGE' ) {
        $self->addRule(
            $self->_currentJA->target,
            $self->_currentJA->arrayPrereqs,
            " -t 1-$arrayTasks:1  sge_job_array.pl  -t "
              . $self->_currentJA->targetsFile . ' -p '
              . $self->_currentJA->prereqsFile . ' -c '
              . $self->_currentJA->commandsFile
              . " && touch $target",
            jobName => $self->_currentJA->name
        );
    }
    else {
        $self->addRule(
            $self->_currentJA->target, $self->_currentJA->arrayTargets,
            "touch $target", jobName => $self->_currentJA->name
        );

    }

    $self->_currentJA->flushFiles;
    $self->_currentJA(undef);
}

=head1 AUTHORS

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dm at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DM>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DM


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DM>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DM>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DM>

=item * Search CPAN

L<http://search.cpan.org/dist/DM/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Kiran V Garimella.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of DM

