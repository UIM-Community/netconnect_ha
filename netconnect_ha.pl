use strict;
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
