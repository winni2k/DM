package DM::WrapCmd;
$DM::WrapCmd::VERSION = '0.013'; # TRIAL
# ABSTRACT: Module to wrap commands with DMWrapCmdScript for execution in "multihost" mode.

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use YAML::Tiny;
use DM::TypeDefs;
use File::Tempdir;
use Carp;

has tempdir => (
    is      => 'ro',
    isa     => 'File::Tempdir',
    builder => '_build_tempdir',
    lazy    => 1
);
has dataFile =>
  ( is => 'ro', isa => 'File::Temp', builder => '_build_dataFile', lazy => 1 );

has hostsFile       => ( is => 'ro', isa => 'Str', required => 1 );
has DMWrapCmdScript => ( is => 'ro', isa => 'Str', required => 1 );

# validate hosts file
after hostsFile => sub {
    my $self = shift;
    if (@_) {
        my $hosts = YAML::Tiny::LoadFile( $_[0] );
        croak "Hosts file $_[0] does not contain any hosts"
          unless keys %{$hosts};
    }

};

has globalTmpDir => ( is => 'ro', isa => 'Str', required => 1 );
has _cmdCounter =>
  ( is => 'rw', isa => 'DM::PositiveNum', default => 0, init_arg => undef );
has _cmds => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

sub finalize {
    my $self = shift;
    $self->dataFile->flush;
    YAML::Tiny::DumpFile( $self->dataFile->filename, @{ $self->_cmds } );
}

sub _build_tempdir {
    my $self = shift;
    return File::Tempdir->new(
        template => 'DMWrapCmd_XXXXXX',
        DIR      => $self->globalTmpDir
    );
}

sub _build_dataFile {
    my $self = shift;
    File::Temp->new(
        TEMPLATE => 'wrapCmd_data_yaml_XXXXXX',
        DIR      => $self->tempdir->name,
        UNLINK   => 1
    );
}

sub wrapCmd {
    my $self = shift;
    my $cmd  = shift;
    push @{ $self->_cmds }, $cmd;

    my $cmdCounter = $self->_cmdCounter;
    my $retCmd     = $self->DMWrapCmdScript . q/ -n / . $cmdCounter;
    $self->_cmdCounter( ++$cmdCounter );

    $retCmd .= q/ -d / . $self->dataFile->filename;
    $retCmd .= q/ -h / . $self->hostsFile;
    $retCmd .= q/ -t / . $self->globalTmpDir;
    return $retCmd;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DM::WrapCmd - Module to wrap commands with DMWrapCmdScript for execution in "multihost" mode.

=head1 VERSION

version 0.013

=head1 AUTHOR

Kiran V Garimella <kiran@well.ox.ac.uk> and Warren W. Kretzschmar <warren.kretzschmar@well.ox.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kiran V Garimella and Warren Kretzschmar.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
