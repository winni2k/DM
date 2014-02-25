package DM::WrapCmd;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use YAML::XS;
use DM::TypeDefs;
use File::Tempdir;
use Carp;

has tempDir => (
    is      => 'ro',
    isa     => 'File::TempDir',
    builder => '_build_tempDir',
    lazy    => 1
);
has dataFile =>
  ( is => 'ro', isa => 'File::Temp', builder => '_build_dataFile', lazy => 1 );

has hostsFile => ( is => 'ro', isa => 'Str', required => 1 );

# validate hosts file
after hostsFile => sub {
    my $self  = shift;
    my %hosts = %{ LoadFile( $_[0] ) };
    croak "Hosts file $_[0] does not contain any hosts" unless keys %hosts;
};

has globalTmpDir => ( is => 'ro', isa => 'Str', required => 1 );
has _cmdCounter =>
  ( is => 'rw', isa => 'DM::PositiveNum', default => 0, init_arg => undef );

sub finalize {
    my $self = shift;
    $self->dataFile->flush;
    $self->hostsFile->flush;
}

sub _build_tempDir {
    my $self = shift;
    return File::Tempdir->new(
        template => 'DMWrapCmd_XXXXXX',
        DIR      => $self->globalTmpDir
    );
}

sub _build_dataFile {
    my $self = shift;
    File::Temp->new(
        TEMPLATE => 'wrapCmd_data_XXXXXX.yaml',
        DIR      => $self->tempDir,
        UNLINK   => 1
    );
}

sub wrapCmd {
    my $self = shift;
    my $cmd  = shift;
    print { $self->dataFile } Dump($cmd);
    my $cmdCounter = $self->_cmdCounter;
    my $retCmd =
      q/DMWrapCmd.pl -n / . $cmdCounter . q/ -d / . $self->dataFile->filename;
    $self->_cmdCounter( ++$cmdCounter );

    $retCmd .= ' -h ' . $self->hostsFile if keys %{ $self->hosts };
    return $retCmd;
}

__PACKAGE__->meta->make_immutable;
1;
