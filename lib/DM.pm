package DM;
$DM::VERSION = '0.013'; # TRIAL
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

# ABSTRACT: Distributed Make: A perl module for running pipelines


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

# in gigabytes, limit on java jobs
has memLimit => ( is => 'rw', isa => 'DM::PositiveNum', default => 4 );

# make options
has tmpdir  => ( is => 'ro', isa => 'Str',           default => '/tmp' );
has target  => ( is => 'ro', isa => 'Str',           default => 'all' );
has targets => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] } );

has globalTmpDir => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

has _makefile => (
    is       => 'ro',
    isa      => 'File::Temp',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_makefile'
);

with 'DM::Distributer';

sub _build_makefile {
    my $self = shift;
    return File::Temp->new(
        TEMPLATE => $self->tmpdir . "/DM_XXXXXX",
        SUFFIX   => ".makefile",
        UNLINK   => $self->unlinkTmp
    );
}


sub addRule {
    my ( $self, $targetsref, $dependenciesref, $cmdsref, %batchjoboverrides ) =
      @_;

    my @jobArgs = (
        targets  => $targetsref,
        prereqs  => $dependenciesref,
        commands => $cmdsref
    );

    # allow overriding of job name
    if ( exists $batchjoboverrides{name} ) {
        push @jobArgs, ( name => $batchjoboverrides{name} );
        delete $batchjoboverrides{name};
    }
    $self->job( DM::Job->new(@jobArgs) );

    # Setup the user's commands, taking care of imposing memory limits and
    # adding in cluster prefix commands
    my @cmds = @{ $self->job->commands };
    for ( my $i = 0 ; $i <= $#cmds ; $i++ ) {
        if (   $cmds[$i] =~ /^java /
            && $cmds[$i] =~ / -jar /
            && $cmds[$i] !~ / -Xmx/ )
        {
            my $memLimit = $self->memLimit;
            $cmds[$i] =~ s/^java /java -Xmx${memLimit}g /;
        }
    }
    $self->job->commands( \@cmds );

    # setting batchjob overrides to self. Revert at end of sub
    my %origOverrides;
    for my $key ( sort keys %batchjoboverrides ) {
        $origOverrides{$key} = $self->$key;
        $self->$key( $batchjoboverrides{$key} );
    }

    # Emit the makefile commands
    print { $self->_makefile } $self->jobAsMake;

    push( @{ $self->targets }, $self->job->target );

    # undo temporary overrides
    for my $key ( sort keys %origOverrides ) {
        $self->$key( $origOverrides{$key} );
    }

    return $self->job;
}


sub execute {
    my ( $self, %overrides ) = @_;

    # checking to make sure all started job arrays were ended.
    die "Need to end all started job arrays with endJobArray()"
      if defined $self->_currentJA;

    print { $self->_makefile } "all: "
      . join( " ", @{ $self->{'targets'} } ) . "\n\n";
    print { $self->_makefile } ".DELETE_ON_ERROR:\n\n";

    # run all recipes in bash shell instead of sh
    print { $self->_makefile } "export SHELL=/bin/bash -o pipefail\n";

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
    $self->_finalizeEngine;
    print "$makecmd\n";
    system($makecmd);
    my $errCode = $? >> 8;
    print "$makecmd\n";

    return $errCode;
}


# job array related information
# check for undef to determine if job array has been
# started but not ended
has _currentJA => (
    is       => 'rw',
    isa      => 'Maybe[DM::JobArray]',
    init_arg => undef,
    default  => undef
);
has _currentJASGEJobNum => ( is => 'rw', isa => 'DM::PositiveNum', default => 0 );
has _pastJASGEJobNum    => ( is => 'rw', isa => 'DM::PositiveNum', default => 0 );

## initialize temp files to hold targets, commands and prereqs for job array
for my $name (qw(commands targets prereqs)) {
    my $builder = '_build_' . $name;
    has $name
      . "File" => (
        is      => 'ro',
        isa     => 'File::Temp',
        builder => '_build_' . $name,
        lazy    => 1
      );
}


sub startJobArray {
    my ( $self, %overrides ) = @_;

    die "startJobArray was called before endJobArray"
      if defined $self->_currentJA;

    my %args = (
        target => undef,
        name   => 'DMJobArray',
        %overrides,
    );

    my %extraArgs = %args;
    delete $extraArgs{target};
    delete $extraArgs{name};

    croak "Need to define globalTmpDir through DM constructor"
      unless defined $self->globalTmpDir;

    # definition of jobArrayObject
    # globalTmpDir cannot be overridden, too many headaches otherwise
    my $jobArrayObject = DM::JobArray->new(
        globalTmpDir => $self->globalTmpDir,
        name         => $args{name},
        target       => $args{target},
        targetsFile  => $self->targetsFile,
        prereqsFile  => $self->prereqsFile,
        commandsFile => $self->commandsFile,
        extraArgs    => \%extraArgs,
    );

    # save new object
    $self->_currentJA($jobArrayObject);
    $self->_currentJASGEJobNum(0);

    return $jobArrayObject;
}


sub addJobArrayRule {
    my $self = shift;
    my %jobArgs;

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

        croak "please specify extra engine args at job array start"
          if keys %args;
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
        $self->_currentJASGEJobNum( $self->_currentJASGEJobNum + 1 );
    }
}


sub endJobArray {

    my $self = shift;

    # close all file handles
    #    $self->{currentJobArrayObject}->closeFileHandles;

    # determine how many tasks to kick off in job array
    my $arrayTasks = @{ $self->_currentJA->arrayTargets };

    # change engineParameters stored in extraArgs
    my %extraArgs = %{ $self->_currentJA->extraArgs };

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
              . $self->_currentJA->commandsFile . ' -o '
              . $self->_pastJASGEJobNum
              . " && touch $target",
            jobName => $self->_currentJA->name,
            %extraArgs
        );
        $self->_pastJASGEJobNum($self->_pastJASGEJobNum + $self->_currentJASGEJobNum);
    }
    else {
        $self->addRule(
            $self->_currentJA->target, $self->_currentJA->arrayTargets,
            "touch $target",
            jobName => $self->_currentJA->name,
            %extraArgs
        );

    }

    $self->_currentJA->flushFiles;
    $self->_currentJA(undef);

}

# routines to build the temporary command, target and prereq files
sub _build_commands {
    my $self = shift;
    return File::Temp->new(
        TEMPLATE => 'commands' . '_XXXXXX',
        DIR      => $self->globalTmpDir,
        UNLINK   => 1
    );

}

sub _build_targets {
    my $self = shift;
    return File::Temp->new(
        TEMPLATE => 'targets' . '_XXXXXX',
        DIR      => $self->globalTmpDir,
        UNLINK   => 1
    );

}

sub _build_prereqs {
    my $self = shift;
    return File::Temp->new(
        TEMPLATE => 'prereqs' . '_XXXXXX',
        DIR      => $self->globalTmpDir,
        UNLINK   => 1
    );

}


1;    # End of DM

__END__

=pod

=encoding UTF-8

=head1 NAME

DM - Distributed Make: A perl module for running pipelines

=head1 VERSION

version 0.013

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

=head2 execute()

This method is called after all rules have been defined in order to write the make file and execute it.  No mandatory options. Takes only overrides.

=over

=item Required Arguments

none

=item Returns

exits status. 0 means no problems.

=back

=head1 JOB ARRAY FUNCTIONS

=head2 Workflow

First, initialize a job array with startJobArray().  Add rules to the job array with addJobArrayRule().  Last, call endJobArray() to signal that no more rules will be added to this particular job array. Multiple job arrays can be defined after each other in this manner. execute() can only be called if the most recently started job array has been completed with endJobArray.

On SGE, the job array will only be started once the prerequisites of all job array rules have been updated.  On other platforms, each job will start once its prerequisite has been updated.  However, on all platforms, the job array target will only be updated once all rules of that job array have completed successfully.  

Only the target specified in startJobArray() should be used as a prerequisite for other rules.  The targets specified through addJobArrayRule() should never be used as prerequisites for other rules.

=head2 startJobArray()

daes nothing unless 'cluster' eq 'SGE'.
Requires 'target' to be specified as key value pairs:
    startJobArray(target=>$mytarget)

Add in overrides at this point.  They will be applied at endJobArray().

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

=head2 endJobArray()

Adds the rule that kicks off the job array. See Workflow for further description.

=head3 Requried Arguments

none

=head3 Returns

The target of the job array

=head1 BUGS

Please report any bugs or feature requests to C<bug-dm at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DM>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
