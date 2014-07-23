package DM::Distributer;
$DM::Distributer::VERSION = '0.013'; # TRIAL
# ABSTRACT: DM::Distributer is a role whose purpose is to rewrite job commands such that they will run on an SGE or multiple hosts.

use Moose::Role;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use File::Basename;
use DM::DistributeEngine;
use DM::TypeDefs;
use DM::WrapCmd;

requires 'globalTmpDir';

# init args
has engineName =>
  ( is => 'rw', isa => 'engine_t', builder => '_build_engineName', lazy => 1 );
has memRequest => ( is => 'rw', isa => 'DM::PositiveNum' );
has DMWrapCmdScript => ( is => 'ro', isa => 'Str', default => 'DMWrapCmd.pl' );

# Cluster engine options
for my $name (qw/queue projectName/) {
    has $name => ( is => 'rw', isa => 'Maybe[Str]', default => '' );
}

# stderr and stdout are passed to output file by default.
# if errFile is defined, then stderr is passed to errFile
has outputFile =>
  ( is => 'rw', isa => 'Str', default => 'distributedmake.log' );
has errFile => ( is => 'rw', isa => 'Maybe[Str]', default => undef );

has rerunnable => ( is => 'rw', isa => 'Bool', default => 0 );
has extra      => ( is => 'rw', isa => 'Str',  default => q// );

# parallel environment
has PE => (
    is  => 'rw',
    isa => 'Maybe[HashRef[Str]]',
);
before PE => sub {
    my $self = shift;
    return unless @_;

    my $PE = shift;
    if ( defined $PE->{name} xor defined $PE->{range} ) {
        croak
          "both 'name' and 'range' need to specified when using the PE option";
    }
};
has job => ( is => 'rw', isa => 'DM::Job' );

# private variables
has _supportedEngines => (
    is       => 'ro',
    isa      => 'HashRef[DM::DistributeEngine]',
    builder  => '_build_supportedEngines',
    lazy     => 0,
    init_arg => undef,
);

has _cmdWrapper => (
    is       => 'ro',
    isa      => 'DM::WrapCmd',
    builder  => '_build_cmdWrapper',
    init_arg => undef,
    lazy     => 1
);

has hostsFile => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

sub jobName {
    my $self = shift;
    if (@_) {
        return $self->job->name(@_);
    }
    return $self->job->name;
}

sub _finalizeEngine {
    my $self = shift;

    if ( $self->engineName eq 'multihost' ) {
        $self->_cmdWrapper->finalize;
    }
}

sub _build_cmdWrapper {
    my $self = shift;
    croak
      "cmdWrapper usage is not implemented fully yet.  Need to add hosts file";
    return DM::WrapCmd->new(
        globalTmpDir    => $self->globalTmpDir,
        hostsFile       => $self->hostsFile,
        DMWrapCmdScript => $self->DMWrapCmdScript,
    );
}

sub _cmdPostfix {
    my $self = shift;

    return "| tee -a " . $self->outputFile if $self->engineName eq 'localhost';
}

sub _cmdPrefix {
    my $self = shift;

    my $cmdprefix = "";
    if ( $self->engineName eq 'SGE' ) {
        $cmdprefix = "qsub -sync y -cwd -V -b yes "
          . (
            defined $self->memRequest
            ? q/ -l h_vmem=/ . $self->memRequest . q/G/
            : q//
          )
          . " -o "
          . $self->outputFile
          . (
            defined $self->errFile ? " -j no -e " . $self->errFile : " -j yes" )
          . " -N "
          . $self->jobName;
        $cmdprefix .=
          ( defined( $self->projectName ) )
          ? " -P " . $self->projectName
          : "";
        $cmdprefix .= ( $self->rerunnable ) ? " -r yes" : " -r no";
        $cmdprefix .=
          defined( $self->queue )
          ? " -q " . $self->queue
          : "";
        $cmdprefix .=
          defined( $self->PE )
          ? " -pe " . $self->PE->{name} . q/ / . $self->PE->{range}
          : "";
        $cmdprefix .= $self->extra;
    }

    return $cmdprefix;
}


sub jobAsMake {
    my $self = shift;
    my $job  = $self->job;

    $job->commands(
        [
            @{ $self->_pre_commands },
            @{ $self->_mod_commands },
            @{ $self->_post_commands }
        ]
    );

    return
        $job->target . q/: /
      . join( " ",    @{ $job->prereqs } ) . "\n\t"
      . join( "\n\t", @{ $job->commands } ) . "\n\n";
}


sub _mod_commands {
    my $self = shift;

    my @modcmds;
    foreach my $cmd ( @{ $self->job->commands } ) {
        my $modcmd = $cmd;

        # protect single quotes if running on SGE
        # perhaps this could be an issue with one-liners
        #using double quotes? -- winni
        # TODO move this code into cmdWrapper
        # don't forget to change _finalizeEngine code as 
        # well when that happens
        if ( $self->engineName eq q/SGE/ ) {
            $modcmd =~ s/'/"'/g;
            $modcmd =~ s/'/'"/g;
            $modcmd =~ s/\$/\$\$/g;
        }

        # protect $ signs from make by turning them into $$
        elsif ( $self->engineName eq q/localhost/ ) {
            $modcmd =~ s/\$/\$\$/g;
        }
        elsif ( $self->engineName eq q/multihost/ ) {
            $modcmd = $self->_cmdWrapper->wrapCmd($modcmd);
        }
        else {
            confess "Programming error. Unexpected engineName: "
              . $self->engineName;
        }

        push( @modcmds,
            join( '  ', ( $self->_cmdPrefix, $modcmd, $self->_cmdPostfix ) ) );
    }

    return \@modcmds;
}

# Setup the post-commands (touching output files to make sure
# the timestamps don't get screwed up by clock skew between cluster nodes).
sub _post_commands {
    my $self = shift;
    my @postcmds;
    foreach my $target ( @{ $self->job->targets } ) {
        push( @postcmds, "\@touch -c $target" );
    }
    return \@postcmds;
}

# Setup the pre-commands (things like pre-making directories that will hold
# log files and output files)
sub _pre_commands {
    my $self = shift;
    my @precmds;
    my $logdir = dirname( $self->outputFile );
    if ( !-e $logdir ) {
        my $mklogdircmd = "\@test \"! -d $logdir\" && mkdir -p $logdir";
        push( @precmds, $mklogdircmd );
    }

    # Set up the directories for each target
    foreach my $target ( @{ $self->job->targets } ) {
        my $targetDir = dirname($target);

        my $mkdircmd = "\@test \"! -d $targetDir\" && mkdir -p $targetDir";
        push( @precmds, $mkdircmd );
    }
    return \@precmds;
}

sub _build_supportedEngines {
    my $self = shift;

    return {
        SGE => DM::DistributeEngine->new(
            isSupported => 1,
            binCmd      => q(which sge_qmaster 2>/dev/null),
            name        => 'SGE'
        ),
        multihost => DM::DistributeEngine->new(
            isSupported => 1,
            binCmd      => q//,
            name        => 'multihost'
        ),
        localhost => DM::DistributeEngine->new(
            isSupported => 1,
            binCmd      => q//,
            name        => 'localhost'
        ),
        LSF => DM::DistributeEngine->new(
            isSupported => 0,
            binCmd      => q(which bsub 2>/dev/null),
            name        => 'LSF'
        ),
        PBS => DM::DistributeEngine->new(
            isSupported => 0,
            binCmd      => q(which pbsdsh 2>/dev/null),
            name        => 'PBS'
        )
    };
}

around engineName => sub {
    my $orig = shift;
    my $self = shift;

    # make sure suggested engine is supported
    if (@_) {
        croak
          "[DM::DistributeEngines] Requested engine is not supported: $_[0]\n"
          unless $self->_supportedEngines->{ $_[0] }->isSupported;
        return $self->$orig(@_);
    }

    # make sure necessary parameters are set
    else {
        if ( $self->$orig !~ m/(localhost|multihost)/ ) {
            unless ( defined $self->PE || defined $self->queue ) {
                croak "cluster is not localhost or multihost\n\t"
                  . "either 'queue' or 'PE' or both need to be defined";
            }

        }

        # make sure global tempdir is defined if running not in localhost mode
        unless ( $self->$orig eq 'localhost' ) {
            croak
"[DM] need to define globalTmpDir if not running in localhost mode"
              unless defined $self->globalTmpDir;
        }

        return $self->$orig;
    }
};

sub _build_engineName {
    my $self = shift;

    # automagically initialize as installed cluster engine
    for my $engineKey ( sort keys %{ $self->_supportedEngines } ) {
        next if ( $engineKey eq 'localhost' || $engineKey eq 'multihost' );
        my $engine = $self->_supportedEngines->{$engineKey};
        my $bin    = $engine->bin;
        if ( defined $bin && -e $bin ) {
            if ( $engine->isSupported ) {
                return $engine->name;
            }
            else {
                carp
"[DM::DistributeEngines] Found unsupported cluster binary: $bin\n";
            }
        }
    }

    # otherwise use localhost
    return 'localhost';
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DM::Distributer - DM::Distributer is a role whose purpose is to rewrite job commands such that they will run on an SGE or multiple hosts.

=head1 VERSION

version 0.013

=head 2 jobAsMake()

This method returns a string that can be directly pasted into a make file to 
represent a single job.  Includes target, prereqs and commands.

=head 2 _mod_commands()

This method modifies the commands depending on the engine so that they are ready 
to be written to a make file.  Here is where commands are passed to the wrapCommand object
if the engine is not 'localhost'.

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
