package DM::JobArray;
$DM::JobArray::VERSION = '0.013'; # TRIAL
# ABSTRACT: This is the DM::JobArray class.


use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use File::Temp qw/tempdir tempfile/;
use File::Basename;

# input variables
for my $name (qw/globalTmpDir name target/) {
    has $name => ( is => 'ro', isa => 'Str', required => 1 );
}

before globalTmpDir => sub {
    my $self = shift;
    if (@_) {
        my $gbt = shift;

        # make sure globalTmpDir is defined and exists
        croak
"DM::JobArray needs a global temporary directory to be specified with globalTmpDir and for that direcory to exist"
          unless -d $gbt;
    }
};

## initialize temp files to hold targets, commands and prereqs for job array
for my $name (qw(commands targets prereqs)) {
    has $name
      . "File" => (
        is       => 'ro',
        isa      => 'File::Temp',
        required => 1,
      );
}

# private variables
has _jobs => (
    is       => 'rw',
    isa      => 'ArrayRef[DM::Job]',
    init_arg => undef,
    default  => sub { [] }
);

# job overrides are in this hash
has extraArgs => ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

# output variables
sub flushFiles {
    my $self = shift;
    for my $name (qw(commands targets prereqs)) {
        my $cmd = $name . "File";
        $self->$cmd->flush;
    }
}

sub addSGEJob {
    my $self = shift;
    my $job  = shift;

    ### Add target, prereqs and command to respective files
    # TARGET
    print { $self->targetsFile } $job->target . "\n";

    # COMMAND
    # need to make sure target directory exists
    my @precmds;
    foreach my $target ( @{ $job->targets } ) {
        my $rootdir  = dirname($target);
        my $mkdircmd = "test \"! -d $rootdir\" && mkdir -p $rootdir";
        push( @precmds, $mkdircmd );
    }

    my @commands = @{ $job->commands };
    croak "[DM::JobArray] does not support multi-line commands in SGE mode"
      if @commands > 1;
    print { $self->commandsFile } join( q/ && /, ( @precmds, @commands ) )
      . "\n";

    # PREREQS - also add prereqs to job array prereqs file
    print { $self->prereqsFile } join( q/ /, @{ $job->prereqs } ) . "\n";

    $self->addJob($job);
}

# adds a job object to the list of jobs
sub addJob {
    my $self = shift;
    my $job  = shift;
    push @{ $self->_jobs }, $job;
}

# returns the first target of all jobs added so far
sub arrayTargets {
    my $self = shift;
    my @targets = map { $_->target } @{ $self->_jobs };
    return \@targets;
}

# returns all prerequisites of all jobs added so far
sub arrayPrereqs {
    my $self = shift;
    my @pre;
    map { push @pre, @{ $_->prereqs } } @{ $self->_jobs };
    return \@pre;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DM::JobArray - This is the DM::JobArray class.

=head1 VERSION

version 0.013

=head1 SYNOPSIS

   use DM::JobArray;
   my $ja = DM::JobArray->new(target=>'XYZ', globalTmpDir=>'/tmp', name => 'test');

   my $job = DM::Job->new(targets=>'XYZ1', prereqs=>[qw/X1 Y1 Z1/],command =>'cat X1 Y1 Z1 > XYZ1');

   
   # add a job that has already been added by DM::addRule (this needs to be refactored)
   $ja->addJob($job);

   # or add and sge job
   $ja->addSGEJob($job);

   # flush all temp files
   # this should really be done automatically somehow
   $ja->flushFiles;

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
