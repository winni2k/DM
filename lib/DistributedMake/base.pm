package DistributedMake::base;
use version 0.77; our $VERSION = qv('0.1.001');

use 5.006;
use strict;
use warnings;
use File::Temp qw/tempdir/;
use File::Basename;

=head1 NAME

DistributedMake::base - A perl module for running pipelines

=head1 VERSION

0.1.001

=head1 SYNOPSIS

todo

=head1 GOOD PRACTICE

- Never make a directory a dependency. make creates directories as it needs them.
- Never create rules that delete files. Delete files by hand instead. Chances are, You'll be sorry otherwise.
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

        # other attributes...
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

    if    ( -e $sge_qmaster ) { $self{'cluster'} = 'SGE'; }
#    elsif ( -e $pbsdsh )      { $self{'cluster'} = 'PBS'; } not supported yet
    elsif ( -e $bsub )        { $self{'cluster'} = 'LSF'; }
    else                      { $self{'cluster'} = 'localhost'; }

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
        if ( $self->{cluster} eq q/SGE/ ) {
            $modcmd =~ s/'/"'/g;
            $modcmd =~ s/'/'"/g;
            $modcmd =~ s/\$/\$\$/g;
        }

        # protect $ signs from make by turning them into $$
        if ( $self->{cluster} eq q/localhost/ ) {
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

