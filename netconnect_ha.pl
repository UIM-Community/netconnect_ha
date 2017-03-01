package core::netconnect_ha;

use strict;
use warnings;
use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;
use File::Copy;
use Data::Dumper;

sub new {
    my ($class,$hashRef) = @_;
    my $this = {
        localrobot => $hashRef->{localRobot},
        remoterobot => $hashRef->{remoteRobot},
        logger => $hashRef->{logger},
        storagePath => $hashRef->{path} || "storage"
    };
    return bless($this,ref($class) || $class);
}

sub getCFG {
    my ($self) = @_;

    $self->{logger}->log(3,"Get net_connect configuration from local and remote!");
    my $find_local  = 0;
    my $find_remote = 0;

    {
        my ($RC,@Probes) = $self->{localrobot}->local_probesArray();
        foreach my $probe (@Probes) {
            if($probe->{name} eq "net_connect") {
                $self->{logger}->log(3,"Local net_connect find! Get CFG...");
                my $RC_CFG = $probe->getCfg($self->{storagePath},"netconnect_local");
                if($RC_CFG == NIME_OK) {
                    copy("$self->{storagePath}/netconnect_local.cfg","$self->{storagePath}/netconnect_backup.cfg"); 
                    $find_local = 1;
                }
                last;
            }
        }
    }

    {
        my ($RC,@Probes) = $self->{remoterobot}->probesArray();
        foreach my $probe (@Probes) {
            if($probe->{name} eq "net_connect") {
                $self->{logger}->log(3,"Remote net_connect find! Get CFG...");
                my $RC_CFG = $probe->getCfg($self->{storagePath},"netconnect_remote");
                if($RC_CFG == NIME_OK) {
                    $find_remote = 1;
                }
                last;
            }
        }
    }

    if($find_local == 1 && $find_remote == 1) {
        return 1;
    }
    return 0;
}

sub hydrateCFG {
    my ($self,$up_file,$down_file) = @_;

    $self->{logger}->log(3,"Transfering profiles!");
    my $up_cfg      = cfgOpen("$self->{storagePath}/$up_file.cfg",0);
    my $down_cfg    = Nimbus::CFG->new("$self->{storagePath}/${down_file}.cfg");

    foreach my $profileName ( keys $down_cfg->{"profiles"} ) {
        my $path = "/profiles/$profileName/";
        $self->createSection($up_cfg,$path);
        
        foreach my $sectionName ( keys $down_cfg->{"profiles"}->{"$profileName"} ) {
            my $keyValue = $down_cfg->{"profiles"}->{"$profileName"}->{"$sectionName"};
            cfgKeyWrite($up_cfg,$path,"$sectionName","$keyValue");
        }
    }

    cfgSync($up_cfg);
    cfgClose($up_cfg);
}

sub createSection {
    my ($self,$CFG,$SECTION) = @_;
    cfgKeyWrite($CFG,$SECTION,"key","value");
    cfgKeyDelete($CFG,$SECTION,"key");
}

sub pushCFG {
    my ($self,$path) = @_;
    my $FH;
    unless (open ($FH,"$self->{storagePath}/$path")) {
        warn "Unable to open configuration file!\n";
        return NIME_ERROR;
    }

    my $CFG_Content = "";
    while (<$FH>) {
        $CFG_Content .= $_;
    }
    undef $FH;

    # Reconfigure NET_CONNECT !
    my $PDS = pdsCreate();
    pdsPut_PCH($PDS,"directory","probes/network/net_connect/");
    pdsPut_PCH($PDS,"file",'net_connect.cfg');
    pdsPut_PCH($PDS,"file_contents",$CFG_Content);
    $self->{logger}->log(3,"Push CFG to $self->{localrobot}->{name}");
    my ($RC) = nimRequest("$self->{localrobot}->{name}",48000,"text_file_put", $PDS,10);
    return $RC;
}

sub HA_Activation {
    my ($self) = @_; 
    my $backup_path = "$self->{storagePath}/netconnect_local.cfg";
    my $remote_path = "$self->{storagePath}/netconnect_remote.cfg";
    if(-e $backup_path && -e $remote_path) {
        $self->hydrateCFG("netconnect_local","netconnect_remote");
        $self->{logger}->log(3,"Push netconnect_local.cfg to netconnect!");
        my ($RC) = $self->pushCFG("netconnect_local.cfg");
        if($RC == NIME_OK) {
            return 1;
        }
    }
    return 0;
}

sub HA_Disabling {
    my ($self) = @_;
    my $backup_path = "$self->{storagePath}/netconnect_backup.cfg";
    my $local_path  = "$self->{storagePath}/netconnect_local.cfg";
    if(-e $backup_path) {
        $self->{logger}->log(3,"Push local cfg to the netconnect");
        my $RC = $self->pushCFG("netconnect_backup.cfg");
        return $RC;
    }
    $self->{logger}->log(2,"$backup_path doesn't exist!");
    return NIME_ERROR;
}

sub checkRemoteNetconnect {
    my ($self) = @_; 
    my $PDS = pdsCreate();
    my ($RC,@Probes) = $self->{remoterobot}->probesArray(); 
    if($RC == NIME_OK) {
        foreach my $probe (@Probes) {
            if($probe->{name} eq "net_connect") {
                if($probe->{active} == 1) {
                    return $RC;
                }
                return NIME_ERROR;
            }
        }
        return NIME_ERROR;
    }
    return $RC;
}

1;
