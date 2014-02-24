package DM::Distributer;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use DM::DistributeEngine;
use Carp;
use DM::TypeDefs;

# init args
has engineName =>
  ( is => 'rw', isa => 'engine_t', builder => '_build_engineName', lazy => 1 );
has memRequest => ( is => 'rw', isa => 'DM::PositiveNum' );

# Cluster engine options
for my $name (qw/queue projectName/) {
    has $name => ( is => 'rw', isa => 'Str', default => '' );
}

sub jobName{
    my $self = shift;
    if(@_){
        return $self->job->name(@_);
    }
    return $self->job->name;
}

has outputFile =>
  ( is => 'rw', isa => 'Str', default => 'distributedmake.log' );
has rerunnable => ( is => 'rw', isa => 'Bool', default => 0 );
has extra      => ( is => 'rw', isa => 'Str',  default => q// );

# parallel environment
has PE => (
    is  => 'rw',
    isa => 'HashRef[Str]',
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
    lazy     => 1,
    init_arg => undef,
);


sub cmdPostfix {
    my $self = shift;

    return "| tee -a " . $self->outputFile if $self->engineName eq 'localhost';
}

sub cmdPrefix {
    my $self = shift;

    my $cmdprefix = "";
    if ( $self->engineName eq 'SGE' ) {
        $cmdprefix = "qsub -sync y -cwd -V -b yes -j y"
          . (
            defined $self->memRequest
            ? q/ -l h_vmem=/ . $self->memRequest . q/G/
            : q//
          )
          . " -o "
          . $self->outputFile . " -N "
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

sub jobAsTxt {
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
      . join( " ", @{ $job->prereqs } ) . "\n\t"
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
        if ( $self->engineName eq q/SGE/ ) {
            $modcmd =~ s/'/"'/g;
            $modcmd =~ s/'/'"/g;
            $modcmd =~ s/\$/\$\$/g;
        }

        # protect $ signs from make by turning them into $$
        if ( $self->engineName eq q/localhost/ ) {
            $modcmd =~ s/\$/\$\$/g;
        }

        push( @modcmds,
            join( '  ', ( $self->cmdPrefix, $modcmd, $self->cmdPostfix ) ) );
    }

    return \@modcmds;
}

# Setup the post-commands (touching output files to make sure
# the timestamps don't get screwed up by clock skew between cluster nodes).
sub _post_commands {
    my $self = shift;
    my @postcmds;
    foreach my $target ( @{ $self->job->targets } ) {
        push( @postcmds, "\@touch -c $target" )
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

__PACKAGE__->meta->make_immutable;

1;
