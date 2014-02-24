package DM::WrapCmd;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use YAML::XS;
use DM::TypeDefs;

has dataFile =>
  ( is => 'ro', isa => 'File::Temp', builder => '_build_dataFile', lazy => 1 );
has hostsFile =>
  ( is => 'ro', isa => 'File::Temp', builder => '_build_hostsFile', lazy => 1 );
has hosts =>
  ( is => 'ro', isa => 'HashRef[DM::PositiveNum]', default => sub { {} } );

has globalTmpDir => ( is => 'ro', isa => 'Str', required => 1 );
has _cmdCounter =>
  ( is => 'rw', isa => 'DM::PositiveNum', default => 0, init_arg => undef );

sub finalize{
    my $self = shift;
    $self->dataFile->flush;
    $self->hostsFile->flush;
}

sub _build_hostsFile {
    my $self = shift;
    File::Temp->new(
        TEMPLATE => 'wrapCmd_hosts_XXXXXX.yaml',
        DIR      => $self->globalTmpDir,
        UNLINK   => 1
    );
}

sub _build_dataFile {
    my $self = shift;
    File::Temp->new(
        TEMPLATE => 'wrapCmd_data_XXXXXX.yaml',
        DIR      => $self->globalTmpDir,
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

    $retCmd .= ' -h ' . $self->hostsFile->filename if keys %{ $self->hosts };
    return $retCmd;
}

__PACKAGE__->meta->make_immutable;
1;
