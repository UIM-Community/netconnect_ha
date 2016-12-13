# SCRIPT VERSION 1.0

# Require librairies!
use strict;
use warnings;
use Data::Dumper;
use File::Copy;

# Nimsoft
use lib "D:/apps/Nimsoft/perllib";
use lib "D:/apps/Nimsoft/Perl64/lib/Win32API";
use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;

# librairies
use perluim::main;
use perluim::log;
use perluim::utils;

# ************************************************* #
# Console & Global vars
# ************************************************* #
my $Console = new perluim::log("netconnect_ha.log",6,0,"yes");
my $ScriptExecutionTime = time();
$Console->print("Execution start at ".localtime(),5);

sub breakApplication {
    $Console->print("Break Application (CTRL+C) !!!",0);
    $Console->close();
    exit(1);
}
$SIG{INT} = \&breakApplication;

# ************************************************* #
# Instanciating configuration file!
# ************************************************* #
$Console->print("Load configuration file started!",5);
my $CFG = Nimbus::CFG->new("netconnect_ha.cfg");
my $CFG_Login           = $CFG->{"setup"}->{"login"} || "administrator";
my $CFG_Password 	    = $CFG->{"setup"}->{"password"} || "nim76prox";
my $CFG_Audit           = $CFG->{"setup"}->{"audit"} || 0;
my $CFG_Domain 		    = $CFG->{"setup"}->{"domain"} || "NMS-PROD";
my $CFG_Loglevel        = $CFG->{"setup"}->{"loglevel"} || 3;
my $CFG_Ouput		    = $CFG->{"setup"}->{"output_directory"} || "output";
my $CFG_Cache		    = $CFG->{"setup"}->{"output_cache"} || 3;
$Console->print("Load configuration file ended",5);

$Console->print("Print script configuration : ",5);
foreach($CFG->getKeys($CFG->{"setup"})) {
    $Console->print("Configuration : $_ => $CFG->{setup}->{$_}");
}

# Set loglevel
$Console->setLevel($CFG_Loglevel);

# ************************************************* #
# Instanciating framework !
# ************************************************* #
# nimLogin to the hub (if not a probe!).
nimLogin($CFG_Login,$CFG_Password) if defined($CFG_Login) and defined($CFG_Password);

$Console->print("Instanciating perluim framework!",5);
my $SDK = new perluim::main($CFG_Domain);
$SDK->setLog($Console);
$Console->print("Create $CFG_Ouput directory.");
my $Execution_Date = perluim::utils::getDate();
$SDK->createDirectory("$CFG_Ouput/$Execution_Date");
$SDK->createDirectory("cfg_storage");
$Console->cleanDirectory("$CFG_Ouput",$CFG_Cache);

my %Netconnect_pool = ();

getConfiguration();
checkAvailability();
getNetconnect();
if($CFG_Audit == 0) {
    applyHA();
}

sub getConfiguration {
	foreach my $id (keys $CFG->{"ha"}) {
        $Console->print("$id");
		$Netconnect_pool{$id} = {
            id => $id,
            active => 1,
            primary => $CFG->{"ha"}->{"$id"}->{"primary"},
            primary_alive => 1,
            primary_cfg => 0,
            primary_file => undef,
            secondary => $CFG->{"ha"}->{"$id"}->{"secondary"},
            secondary_alive => 1,
            secondary_cfg => 0,
            secondary_file => undef,
            ha => 0
        };
	}
}

sub checkAvailability {
    foreach (values %Netconnect_pool) {
        $Console->print("Processing : $_->{primary} || $_->{secondary}");

        {
            my $PDS = pdsCreate();
            my ($RC,$NMS_RES) = nimNamedRequest("$_->{primary}/controller","get_info",$PDS,1);
            pdsDelete($PDS);

            $Console->print("Primary RC : $RC");
            if($RC != NIME_OK) {
                $_->{primary_alive} = 0;
            }
        }

        {
            my $PDS = pdsCreate();
            my ($RC,$NMS_RES) = nimNamedRequest("$_->{secondary}/controller","get_info",$PDS,1);
            pdsDelete($PDS);

            $Console->print("Secondary RC : $RC");
            if($RC != NIME_OK) {
                $_->{secondary_alive} = 0;
            }
        }

        if($_->{primary_alive} == 1 && $_->{secondary_alive} == 1) {
            $Console->print("Primary hub ($_->{primary}) and secondary hub ($_->{secondary}) are both up!",1);
            $_->{active} = 0;
        }
        elsif($_->{primary_alive} == 0 && $_->{secondary_alive} == 0) {
            $Console->print("Primary hub ($_->{primary}) and secondary hub ($_->{secondary}) are both down!",1);
            $_->{active} = 0;
        }

        # TODO : Confirm alive state with gethubs!

    }
}

sub getCFG {
    my ($hub,$cfg_name) = @_;
    $Console->print("Get net_connect.cfg from $hub");

    my $PDS_args = pdsCreate();
    pdsPut_PCH ($PDS_args,"directory","probes/network/net_connect/");
    pdsPut_PCH ($PDS_args,"file","net_connect.cfg");
    pdsPut_INT ($PDS_args,"buffer_size",10000000);

    my ($RC, $ProbePDS_CFG) = nimNamedRequest("$hub/controller","text_file_get", $PDS_args,3);
    pdsDelete($PDS_args);

    if($RC == NIME_OK) {
        $Console->print("ok");
        my $CFG_Handler;
        unless(open($CFG_Handler,">>","cfg_storage/$cfg_name")) {
            return 0;
        }
        my @ARR_CFG_Config = Nimbus::PDS->new($ProbePDS_CFG)->asHash();
        print $CFG_Handler $ARR_CFG_Config[0]{'file_content'};
        close $CFG_Handler;

        return 1;
    }
    else {
        $Console->print("$RC");
    }
    return 0;
}

sub replace {
    my $txt = shift;
    $txt =~ s/\//_/g;
    return $txt;
}

sub getNetconnect {
    $Console->print("Get net_connect configuration files!");
    foreach (values %Netconnect_pool) {

        my $primary_cfg_name = replace($_->{primary});
        if($_->{primary_alive}) {
            my $RC_Primary = getCFG($_->{primary},$primary_cfg_name);
            if($RC_Primary == 1) {
                $_->{primary_file} = $primary_cfg_name;
                $_->{primary_cfg} = 1;
            }
            else {
                $Console->print("Unable to get cfg for $_->{primary}, Check for local file!",1);
                if( -e "cfg_storage/$primary_cfg_name") {
                    $_->{primary_file} = $primary_cfg_name;
                    $_->{primary_cfg} = 1;
                    $Console->print("successfully retrieve local file!");
                }
                else {
                    $Console->print("Failed to get localfile!",1);
                    $_->{primary_cfg} = 0;
                }
            }
        }
        else {
            $Console->print("$_->{primary} is not alive!, Check for local file!",1);
            if( -e "cfg_storage/$primary_cfg_name") {
                $_->{primary_file} = $primary_cfg_name;
                $_->{primary_cfg} = 1;
                $Console->print("successfully retrieve local file!");
            }
            else {
                $Console->print("Failed to get localfile!",1);
                $_->{primary_cfg} = 0;
            }
        }

        my $secondary_cfg_name = replace($_->{secondary});
        if($_->{secondary_alive}) {
            my $RC_Secondary = getCFG($_->{secondary},$secondary_cfg_name);
            if($RC_Secondary == 1) {
                $_->{secondary_file} = $secondary_cfg_name;
                $_->{secondary_cfg} = 1;
            }
            else {
                $Console->print("Unable to get cfg for $_->{secondary}, Check for local file!",1);
                if( -e "cfg_storage/$secondary_cfg_name") {
                    $_->{secondary_file} = $secondary_cfg_name;
                    $_->{secondary_cfg} = 1;
                    $Console->print("successfully retrieve local file!");
                }
                else {
                    $Console->print("Failed to get localfile!",1);
                    $_->{secondary_cfg} = 0;
                }
            }
        }
        else {
            $Console->print("$_->{secondary} is not alive!, Check for local file!",1);
            if( -e "cfg_storage/$secondary_cfg_name") {
                $_->{secondary_file} = $secondary_cfg_name;
                $_->{secondary_cfg} = 1;
                $Console->print("successfully retrieve local file!");
            }
            else {
                $Console->print("Failed to get localfile!",1);
                $_->{secondary_cfg} = 0;
            }
        }

        if($_->{primary_cfg} == 0 && $_->{secondary_cfg} == 0) {
            $Console->print("Unable to get CFG from these hubs, Stop HA processing!");
            $_->{active} = 0;
        }

    }
}

sub transferProfiles {
    my ($up_file,$down_file) = @_;

    $Console->print("Transfering configuration!");
    my $up_cfg = cfgOpen("cfg_storage/$up_file",0);
    my $down_cfg = Nimbus::CFG->new("cfg_storage/$down_file");
    foreach my $profileKey (keys $down_cfg->{"profiles"}) {
        my $path = "/profiles/$profileKey/";
        createSection($up_cfg,$path);
        foreach my $sectionKey (keys $down_cfg->{"profiles"}->{"$profileKey"}) {
            my $keyValue = $down_cfg->{"profiles"}->{"$profileKey"}->{"$sectionKey"};
            cfgKeyWrite($up_cfg,$path,"$sectionKey","$keyValue");
        }
    }

    cfgSync($up_cfg);
    cfgClose($up_cfg);
}

sub createSection {
    my ($CFG,$SECTION) = @_;
    cfgKeyWrite($CFG,$SECTION,"key","value");
    cfgKeyDelete($CFG,$SECTION,"key");
}

sub pushCFG {
    my ($path,$addr) = @_;
    my $FH;
    unless (open ($FH,"cfg_storage/$path")) {
        warn "Unable to open configuration file!\n";
        return 0;
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

    my ($RC) = nimNamedRequest("$addr", "text_file_put", $PDS);
    return ($RC == NIME_OK) ? 1 : 0;
}

sub applyHA {

    # Check HA file!
    $Console->print("Loading storage_ha.cfg");
    my $HA_CFG = Nimbus::CFG->new("storage_ha.cfg");
    if(defined($HA_CFG->{"ha"}) && scalar keys $HA_CFG->{"ha"} > 0) {
        foreach(keys $HA_CFG->{"ha"})  {
            $Console->print("Inserting ID => $_");
            $Netconnect_pool{"$_"}{ha} = 1;
            $Netconnect_pool{"$_"}{primary_ha_alive} = $HA_CFG->{"ha"}->{"$_"}->{"primary"};
            $Netconnect_pool{"$_"}{secondary_ha_alive} = $HA_CFG->{"ha"}->{"$_"}->{"secondary"};
        }
    }

    foreach my $Netvalue (values %Netconnect_pool) {

        # If high availability is up!
        if($Netvalue->{ha} == 1) {
            $Console->print("Apply HA backup for $Netvalue->{primary} and $Netvalue->{secondary}");

            if($Netvalue->{primary_alive} == 1 && $Netvalue->{secondary_alive} == 1) {
                $Console->print("Both robots are online!");

                my ($up_hub,$up_file);
                if($Netvalue->{primary_ha_alive} == 0) {
                    $up_hub     = $Netvalue->{secondary};
                    $up_file    = $Netvalue->{secondary_file};
                }
                elsif($Netvalue->{secondary_ha_alive} == 0) {
                    $up_hub     = $Netvalue->{primary};
                    $up_file    = $Netvalue->{primary_file};
                }

                my $RC = pushCFG("${up_file}_backup","$up_hub/controller");
                if($RC == 1) {
                    $Console->print("Push new net_connect configuration successfully!");
                    my $HA = cfgOpen("storage_ha.cfg",0);
                    cfgSectionDelete($HA,"/ha/$Netvalue->{id}/");
                    cfgSync($HA);
                    cfgClose($HA);
                    unlink "cfg_storage/${up_file}_backup" or warn "Unable to delete file!";
                }
                else {
                    $Console->print("Failed to push new net_connect profiles!",1);
                }

            }
            next;
        }

        # Exclude HA!
        if($Netvalue->{active} == 0) {
            $Console->print("Skip for $Netvalue->{primary} and $Netvalue->{secondary}");
            next;
        }

        my ($up_hub,$up_file);
        my ($down_hub,$down_file);
        if($Netvalue->{primary_alive} == 0) {
            $down_hub   = $Netvalue->{primary};
            $down_file  = $Netvalue->{primary_file};
            $up_hub     = $Netvalue->{secondary};
            $up_file    = $Netvalue->{secondary_file};
        }
        elsif($Netvalue->{secondary_alive} == 0) {
            $down_hub   = $Netvalue->{secondary};
            $down_file  = $Netvalue->{secondary_file};
            $up_hub     = $Netvalue->{primary};
            $up_file    = $Netvalue->{primary_file};
        }
        $Console->print("Entering into HA configuration for $up_hub!",2);
        $_->{ha} = 1;

        # Create a backup file for server up !
        copy("cfg_storage/$up_file","cfg_storage/${up_file}_backup");

        # Transfer down profiles into up profiles!
        transferProfiles($up_file,$down_file);

        my $RC = pushCFG("$up_file","$up_hub/controller");
        if($RC == 1) {
            $Console->print("Push new net_connect configuration successfully!");
            # Rewrite HA file!
            $Console->print("Rewrite HA file!");
            my $HA = cfgOpen("storage_ha.cfg",0);
            cfgSectionDelete($HA,"/ha/$Netvalue->{id}/");
            createSection($HA,"/ha/$Netvalue->{id}/");
            cfgKeyWrite($HA,"/ha/$Netvalue->{id}/","primary","$Netvalue->{primary_alive}");
            cfgKeyWrite($HA,"/ha/$Netvalue->{id}/","secondary","$Netvalue->{secondary_alive}");
            cfgSync($HA);
            cfgClose($HA);
        }
        else {
            $Console->print("Failed to push new net_connect profiles!",1);
        }

    }

}


$| = 1;
$Console->print("Waiting 5 secondes before closing the script!",4);
$SDK->doSleep(5);

# ************************************************* #
# End of the script!
# ************************************************* #
$Console->finalTime($ScriptExecutionTime);
$Console->copyTo("$CFG_Ouput/$Execution_Date");
$Console->close();
1;
