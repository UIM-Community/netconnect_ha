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
        localrobot => $hashRef->{localRobot},use strict;
use warnings;
use lib "D:/apps/Nimsoft/perllib";
use lib "D:/apps/Nimsoft/Perl64/lib/Win32API";

use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;

use perluim::logger;
use perluim::main;
use perluim::utils;
use perluim::filemap;
use core::netconnect_ha;

my $probeName       = "netconnect_ha";
my $probeVersion    = "1.0";
my $time = time();
my ($Logger,$UIM,$Execution_Date);

# Create log file
$Logger = new perluim::logger({
    file => "$probeName.log",
    level => 6
});
$Logger->log(3,"$probeName started at $time!");

# Read configuration file 
my $CFG                 = Nimbus::CFG->new("$probeName.cfg");
my $Domain              = $CFG->{"setup"}->{"domain"};
my $OutputDirectory     = $CFG->{"setup"}->{"output_directory"} || "output";
my $OutputCache         = $CFG->{"setup"}->{"output_cache_time"} || 345600;
my $Login               = $CFG->{"setup"}->{"nim_login"};
my $Password            = $CFG->{"setup"}->{"nim_password"};

my $Netconnect_online   = $CFG->{"configuration"}->{"netconnect_online"} || "no";
my $SyncPath            = $CFG->{"configuration"}->{"sync_path"} || "storage";
my $Nim_ADDR            = $CFG->{"configuration"}->{"nim_addr"};

if(not defined $Nim_ADDR) {
    die("Please define configuration/nim_addr");
}

# Create framework
nimLogin("$Login","$Password") if defined($Password) && defined($Password);
$UIM            = new perluim::main("$Domain");
$Execution_Date = perluim::utils::getDate();
my $LogDirectory        = "$OutputDirectory/$Execution_Date";
$Logger->log(3,"$LogDirectory");

# Create and clean folders
perluim::utils::createDirectory($LogDirectory);
perluim::utils::createDirectory("$SyncPath");
$Logger->cleanDirectory("$OutputDirectory",$OutputCache); # Clean directory older than 4 days.

# Create local map (state).
my $localMap = new perluim::filemap('storage/state.cfg');

# Get remote robot!
sub getRemote {
    my ($LocalRobot) = @_; use strict;
use warnings;
use lib "D:/apps/Nimsoft/perllib";
use lib "D:/apps/Nimsoft/Perl64/lib/Win32API";

use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;

use perluim::logger;
use perluim::main;
use perluim::utils;
use perluim::filemap;
use core::netconnect_ha;

my $probeName       = "netconnect_ha";
my $probeVersion    = "1.0";
my $time = time();
my ($Logger,$UIM,$Execution_Date);

# Create log file
$Logger = new perluim::logger({
    file => "$probeName.log",
    level => 6
});
$Logger->log(3,"$probeName started at $time!");

# Read configuration file 
my $CFG                 = Nimbus::CFG->new("$probeName.cfg");
my $Domain              = $CFG->{"setup"}->{"domain"};
my $OutputDirectory     = $CFG->{"setup"}->{"output_directory"} || "output";
my $OutputCache         = $CFG->{"setup"}->{"output_cache_time"} || 345600;
my $Login               = $CFG->{"setup"}->{"nim_login"};
my $Password            = $CFG->{"setup"}->{"nim_password"};

my $Netconnect_online   = $CFG->{"configuration"}->{"netconnect_online"} || "no";
my $SyncPath            = $CFG->{"configuration"}->{"sync_path"} || "storage";
my $Nim_ADDR            = $CFG->{"configuration"}->{"nim_addr"};

if(not defined $Nim_ADDR) {
    die("Please define configuration/nim_addr");
}

# Create framework
nimLogin("$Login","$Password") if defined($Password) && defined($Password);
$UIM            = new perluim::main("$Domain");
$Execution_Date = perluim::utils::getDate();
my $LogDirectory        = "$OutputDirectory/$Execution_Date";
$Logger->log(3,"$LogDirectory");

# Create and clean folders
perluim::utils::createDirectory($LogDirectory);
perluim::utils::createDirectory("$SyncPath");
$Logger->cleanDirectory("$OutputDirectory",$OutputCache); # Clean directory older than 4 days.

# Create local map (state).
my $localMap = new perluim::filemap('storage/state.cfg');

# Get remote robot!
sub getRemote {
    my ($LocalRobot) = @_; 
    my ($RC,$RemoteRobot) = $UIM->getLocalRobot($Nim_ADDR);
    if($RC == NIME_OK) {
        return NIME_OK,$RemoteRobot;
    }
    return $RC,undef;
}

# Main method!
sub main {

    # Get local robot!
    my ($RC,$LocalRobot,$RemoteRobot);
    ($RC,$LocalRobot) = $UIM->getLocalRobot(); 
    if($RC == NIME_OK) {
        $Logger->log(6,"Sucessfully get local robot!");
        ($RC,$RemoteRobot) = getRemote($LocalRobot);
        my $HA_Manager = new core::netconnect_ha({
            localRobot => $LocalRobot,
            remoteRobot => $RemoteRobot,
            logger => $Logger,
            path => $SyncPath
        });

        # Intermediate netconnect checkup!
        if($Netconnect_online eq "yes" && $RC == NIME_OK) {
            $Logger->log(3,"Check remote net_connect");
            $RC = $HA_Manager->checkRemoteNetconnect();
            if($RC != NIME_OK) {
                $Logger->log(2,"Remote net_connect seem to be offline!");
            }
        }

        if( $RC == NIME_OK ) {
            
            $Logger->log(6,"Sucessfully get remote robot!");
            if($localMap->has("HA")) {
                my $A_RC = $HA_Manager->HA_Disabling();
                if($A_RC == NIME_OK) {
                    $localMap->delete("HA");
                    $Logger->log(6,"HA Has been disabled succesfully!");
                }
                else {
                    $Logger->log(1,"Failed to disabled HA");
                }
            }
            my $get_rc = $HA_Manager->getCFG();
            if(not $get_rc) {
                $Logger->log(2,"Failed to get CFG from local and remote robot!");
            }
        }
        else {
            $Logger->log(2,"Failed to get remote hub!");
            if(not $localMap->has("HA")) {
                my $A_RC = $HA_Manager->HA_Activation();
                if($A_RC) {
                    $Logger->log(6,"HA succesfully activated!");
                    $localMap->set("HA",{});
                }
                else {
                    $Logger->log(1,"Failed to active HA with RC => $A_RC");
                }
            }
            else {
                $Logger->log(2,"HA is already activated!");
            }
        }

    }
    else {
        $Logger->log(1,"Failed to get local robot!");
    }

    # Write local map to disk!
    $localMap->writeToDisk();

}
main();

# Close script!
$Logger->finalTime($time);
$Logger->copyTo($LogDirectory);
$Logger->close();
    my ($RC,$RemoteRobot) = $UIM->getLocalRobot($Nim_ADDR);
    if($RC == NIME_OK) {
        return NIME_OK,$RemoteRobot;
    }
    return $RC,undef;
}

# Main method!
sub main {

    # Get local robot!
    my ($RC,$LocalRobot,$RemoteRobot);
    ($RC,$LocalRobot) = $UIM->getLocalRobot(); 
    if($RC == NIME_OK) {
        $Logger->log(6,"Sucessfully get local robot!");
        ($RC,$RemoteRobot) = getRemote($LocalRobot);
        my $HA_Manager = new core::netconnect_ha({
            localRobot => $LocalRobot,
            remoteRobot => $RemoteRobot,
            logger => $Logger,
            path => $SyncPath
        });

        # Intermediate netconnect checkup!
        if($Netconnect_online eq "yes" && $RC == NIME_OK) {
            $Logger->log(3,"Check remote net_connect");
            $RC = $HA_Manager->checkRemoteNetconnect();
            if($RC != NIME_OK) {
                $Logger->log(2,"Remote net_connect seem to be offline!");
            }
        }

        if( $RC == NIME_OK ) {
            
            $Logger->log(6,"Sucessfully get remote robot!");
            if($localMap->has("HA")) {
                my $A_RC = $HA_Manager->HA_Disabling();
                if($A_RC == NIME_OK) {
                    $localMap->delete("HA");
                    $Logger->log(6,"HA Has been disabled succesfully!");
                }
                else {
                    $Logger->log(1,"Failed to disabled HA");
                }
            }
            my $get_rc = $HA_Manager->getCFG();
            if(not $get_rc) {
                $Logger->log(2,"Failed to get CFG from local and remote robot!");
            }
        }
        else {
            $Logger->log(2,"Failed to get remote hub!");
            if(not $localMap->has("HA")) {
                my $A_RC = $HA_Manager->HA_Activation();
                if($A_RC) {
                    $Logger->log(6,"HA succesfully activated!");
                    $localMap->set("HA",{});
                }
                else {
                    $Logger->log(1,"Failed to active HA with RC => $A_RC");
                }
            }
            else {
                $Logger->log(2,"HA is already activated!");
            }
        }

    }
    else {
        $Logger->log(1,"Failed to get local robot!");
    }

    # Write local map to disk!
    $localMap->writeToDisk();

}
main();

# Close script!
$Logger->finalTime($time);
$Logger->copyTo($LogDirectory);
$Logger->close();
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
