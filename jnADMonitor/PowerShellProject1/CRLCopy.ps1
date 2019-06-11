#
# CRLCopy.ps1
#
# Title:     CRLCopy.ps1 
# Date:     4/28/2010 
# Author: Paul Fox (MCS) 
# Copyright Microsoft Corporation @2010 
# 
# Description:     This script writes a Certification Authority's Certificate Revocation List to HTTP based CRL Distribution Points via a UNC path. 
#               Performs the following steps: 
#                 1) Determines if the Active Directory Certificate Services are running on the system. In the case of a cluster make sure to set the $Cluster variable to '$TRUE' 
#                 2) Reads the CA's CRL from %windir%\system32\certsrv\certenroll (defined by $crl_master_path + $crl_name variables). I'll refer to this CRL as "Master CRL." 
#                 3) Checks the NextUpdate value of the Master CRL to make sure is has not expired. (Note that the Mono library adds hours to the NextUpdate and EffectiveDate values, control this time difference with the $creep variable) 
#                 4) Copy Master CRL to CDP UNC locations if Master CRL's ThisUpdate is greater than CDP CRLs' ThisUpdate 
#                 5) Compare the hash values of the CRLs to make sure the copy was successful. If they do not match override the $SMTP variable to send email alert message. 
#                 6) When Master CRL's ThisUpdate is greater than NextCRLPublish and NextUpdate we want to be alerted when the Master CRL is approaching end of life. Use the $threshold variable to define (in hours) how far from 
#                    NextUpdate you want to receive warnings that the CRLs are soon to expire.               
# 
# Output: 1) Run script initially as local administrator to register with the system's application eventlog 
#         2) Send SMTP message if $STMP = True. Set variable section containing SMTP settings for your environment 
#         3) To run this script with debug output set powershell $DebugPreference = "Continue" 
#         4) The 'results' function is used to write to the eventlog and send SMTP messages. Event levels are controlled in the variable section. For example a failed CRL copy you want to make sure the eventlog show "Error" ($EventHigh) 
#       
# Requirements: 1) Windows Powershell v2 included in the Windows Management Framework http://support.microsoft.com/kb/968929 
#                 2)Powershell Community Extensions for the Get-Hash commandlet http://pscx.codeplex.com 
#                 3) This powershell script uses a third party, open source .Net reference called 'Mono'    More information can be found at http://www.mono-project.com/Main_Page 
#                             Note: the Mono assembly Mono.Security.x509.x509CRL adds 4 hours to the .NextUpdate, .ThisUpdate and .IsCurrent function 
#                         4) Don't forget to set the powershell set-executionpolicy 
# 
# ToDos: Bind to an LDAP directory to retrieve CRL (e.g. ldap://fpkia.gsa.gov/CommonPolicy/CommonPolicy(1).crl) 
#        Use multidimensional arrays to store CDP HTTP and UNC addresses 
# 
# Debug: To run this script with debug output set powershell $DebugPreference = "Continue" 
# 
################################################ 
################################################ 
# 
# Function:     Results 
# Description:    Writes the $evt_string to the Application eventlog and sends 
#                SMTP message to recipients if $SMTP = [bool]$true 
# 
################################################ 
function results([string]$evt_string, [int]$level, [bool]$sendsmtp) 
{ 
	write-debug "******** Inside results function ********" 
	write-debug "SMTP = $sendsmtp" 
	write-debug "Evtstring = $evt_string" 
	write-debug "Level: $level" 
	############### 
	#if eventlog does not exist create it (must run script as local administrator once to create) 
	############### 
	if(![system.diagnostics.eventlog]::sourceExists($CRL_Evt_Source)) 
	{ 
		$evtlog = [system.diagnostics.eventlog]::CreateEventSource($CRL_Evt_Source,"Application") 
	}
	############### 
	# set eventlog object 
	############### 
	$evtlog = new-object system.diagnostics.eventlog("application",".") 
	$evtlog.source = $CRL_Evt_Source 
	############### 
	# write to eventlog 
	############### 
	$evtlog.writeEntry($evt_string, $level, $EventID) 
	if($sendsmtp) 
	{ 
		$SmtpClient = new-object system.net.mail.smtpClient 
		$SmtpClient.host = $SmtpServer 
		$Body = $evt_string 
		$SmtpClient.Send($from,$to,$title,$Body) 
	} 
} 
################################################ 
# 
# Main program 
# 
################################################ 
################################################ 
# 
# Add Mono .Net References 
# If running on an x64 system make sure the path is correct 
# 
################################################ 
Add-Type -Path "C:\Program Files (x86)\Mono-2.6.4\lib\mono\2.0\Mono.Security.dll" 
################################################ 
# 
# Variables 
# 
################################################ 
$crl_master_path = "c:\windows\system32\certsrv\certenroll\" 
$CRL_Name = "master.crl" 
$CDP1_UNC = "\\cdp1\cdp1\" 
$CDP2_UNC = "\\cdp2\cdp2\" 
$CDP1_HTTP = "http://keys1.your.domain/" 
$CDP2_HTTP = "http://keys2.your.domain/"
$SMTP = [bool]$false 
$SmtpServer = "your.mx.mail.server" 
$From = "crlcopy@your.domain" 
$To = "CAAdmins@your.domain" 
$Title = "CRL Copy Process Results" 
$CRL_Evt_Source = "CRL Copy Process" 
$EventID = "5000" 
$EventHigh = "1" 
$EventWarning = "2" 
$EventInformation = "4" 
$newline = [System.Environment]::NewLine 
$time = Get-Date 
$threshold = 1 
$creep = -4 
$Cluster =  [bool]$false 
################################################ 
# 
# Is certsrv running? Is it a clustered CA?
# If clustered it is not running don't send an SMTP message 
# 
################################################ 
$service = get-service "certsvc" 
if (!($service.Status -eq "Running")) 
{
	if($Cluster) 
	{ 
		$evt_string = "Active Directory Certificate Services is not running on this node of the cluster. Exiting program." 
		write-debug "ADCS is not running. This is a clustered node. Exiting" 
		results $evt_string $EventInformation $SMTP 
		exit 
	} 
	else 
	{ 
		$evt_string = "**** IMPORTANT **** IMPORTANT **** IMPORTANT ****" +  $newline + "Certsvc status is: " + $service.status + $newline 
		write-debug "ADCS is not running and not a clustered node. Not good." 
		results $evt_string $EventHigh $SMTP 
		exit 
	} 
} else {
	write-debug "Certsvc is running. Continue." 
} 
################################################ 
# 
# Pull CRLs from Master and HTTP CDP locations 
# Not going to bother with Active Directory since this 
# is probably a Windows Enterprise CA (todo) 
# 
################################################ 
$CRL_Master = [Mono.Security.X509.X509Crl]::CreateFromFile($crl_master_path + $CRL_Name) 
$web_client = New-Object System.Net.WebClient 
$CDP1_CRL = [Mono.Security.X509.X509Crl]$web_client.DownloadData($CDP1_HTTP + $CRL_Name) 
$CDP2_CRL = [Mono.Security.X509.X509Crl]$web_client.DownloadData($CDP2_HTTP + $CRL_Name) 
################################################ 
# 
# Debug section to give you the time/dates of the CRLs 
# 
################################################ 
if($debugpreference -eq "continue") 
{ 
	write-debug $newline 
	write-debug "Master CRL Values" 
	$debug_out = $CRL_Master.ThisUpdate.AddHours($creep) 
	write-debug "Master ThisUpdate $debug_out" 
	$debug_out = $CDP1_CRL.ThisUpdate.AddHours($creep) 
	write-debug "CDP1_CRL ThisUpdate: $debug_out" 
	$debug_out = $CDP2_CRL.ThisUpdate.AddHours($creep) 
	write-debug "CDP2_CRL ThisUpdate: $debug_out" 
	$debug_out = $CRL_Master.NextUpdate.AddHours($creep) 
	write-debug "Master NextUpdate: $debug_out" 
	$debug_out = $CDP1_CRL.NextUpdate.AddHours($creep) 
	write-debug "CDP1_CRL NextUpdate: $debug_out" 
	$debug_out = $CDP2_CRL.NextUpdate.AddHours($creep) 
	write-debug "CDP2_CRL NextUpdate: $debug_out" 
	write-debug $newline 
} 
################################################ 
# 
# Determine the status of the master CRL 
# Master and CDP CRLs have the same EffectiveDate (Mono = ThisUpdate)    
# 
################################################ 
if($CRL_Master.NextUpdate.AddHours($creep) -gt $time) 
{ 
	# This is healthy Master CRL 
	write-debug "Master CRL EffectiveDate: " 
	write-debug $CRL_Master.ThisUpdate.AddHours($creep) 
	write-debug "Time now is: " 
	write-debug $time 
	write-debug $newline 
} else { 
	# Everything has gone stale, not good. Alert. 
	write-debug "Master CRL has gone stale" 
	$evt_string = "**** IMPORTANT **** IMPORTANT **** IMPORTANT ****" + $newline + "Master CRL: " + $CRL_Name + " has an EffectiveDate of: " + $CRL_Master.ThisUpdate.AddHours($creep) + " and an NextUpdate of: " + $CRL_Master.NextUpdate.AddHours($creep) + $newline + "Certsvc status is: " + $service.status 
	results $evt_string $EventHigh $SMTP 
	exit 
} 
################################################ 
#    
# Determine what the status of the CDPs 
# Does the Master and the CDP CRLs match up? 
# 
################################################ 
if (($CRL_Master.ThisUpdate -eq $CDP1_CRL.ThisUpdate) -and ($CRL_Master.ThisUpdate -eq $CDP2_CRL.ThisUpdate)) 
{ 
	write-debug "All CRLs EffectiveDates match" 
	write-debug $CRL_Master.ThisUpdate 
    write-debug $CDP1_CRL.ThisUpdate 
    write-debug $CDP2_CRL.ThisUpdate 
    write-debug $newline 
}
################################################ 
# 
# New Master CRL, Update CDP CRLs if or or both are old 
# would be nice to use the 'CRL Number' 
# Compare the hash values of the Master CRL and CDP CRLs 
# after the copy command to make sure the copy completed 
# 
################################################ 
elseif (($CRL_Master.ThisUpdate -gt $CDP1_CRL.ThisUpdate) -or ($CRL_Master.ThisUpdate -gt $CDP2_CRL.ThisUpdate)) 
{ 
	# There is a new master CRL, copy to CDPs 
	write-debug "New master crl. Copy out to CDPs" 
	$source = Get-Item $crl_master_path$CRL_Name 
	Copy-Item $source $CDP1_UNC$CRL_Name 
	Copy-Item $source $CDP2_UNC$CRL_Name 
	# Compare the hash values of the master CRL to the CDP CRL 
	# If they do not equal alert via SMTP by setting the $SMTP boolian value to '$true' 
	$master_hash = get-hash $source 
	$cdp1_hash = get-hash $CDP1_UNC$CRL_Name 
	$cdp2_hash = get-hash $CDP2_UNC$CRL_Name 

	if(($master_hash.HashString -ne $cdp1_hash.HashString) -or ($master_hash.HashString -ne $cdp2_hash.HashString)) 
	{ 
		$evt_string = "CRL copy to CDP location failed:" +$newline +"Master CRL Hash: " +$master_hash.HashString +$newline + "CPD1  Hash:" +$cdp1_hash.HashString +$newline + "CDP2 Hash:" +$cdp2_hash.HashString +$newline 
		# Make sure the email alert goes out. Override the $SMTP variable 
		write-debug $newline 
		write-debug "CRLs copied to CDPs hash values do not match Master CRL Hash" 
		write-debug "Master CRL Hash value" 
		write-debug $master_hash.HashString 
		write-debug "CDP1 CRL Hash value" 
		write-debug $cdp1_hash.HashString 
		write-debug "CDP2 CRL Hash value" 
		write-debug $cdp2_hash.HashString 
		$SMTP = [bool]$true 
		results $evt_string $EventHigh $SMTP 
		exit 
	} else {
		$evt_string = "New Master CRL published to CDPs. " + $CRL_Name + " has an EffectiveDate of: " + $CRL_Master.ThisUpdate.AddHours($creep) + " and an NextUpdate of: " + $CRL_Master.NextUpdate.AddHours($creep) 
		results $evt_string $EventInformation $SMTP 
	} 
} else { 
    write-debug "logic bomb, can't determine where the Master CRL is in relationship to the CDP CRLs" 
    } 
################################################ 
# 
# Master CRL’s ThisUpdate time is in between the NextCRLPublish time and NextUpdate. 
# Note Mono does not have a method to read 'NextCRLPublish' 
# The CA Operator can define the '$threshold' at which that want to start receiving alerts 
# 
################################################ 
if (($CRL_Master.NextUpdate.AddHours($creep) -gt $time) -and ($CRL_Master.ThisUpdate.AddHours($creep) -lt $time)) 
{ 
	write-debug "checking threshold" 
	# Is the Master CRL NextUpdate within the defined alert threshold? 
	if($CRL_Master.NextUpdate.AddHours(-($threshold - $creep)) -lt $time) 
	{ 
		write-debug "***** WARNING ****** Master CRL NextUpdate has a life less than threshold." 
		write-debug $CRL_Master.NextUpdate.AddHours(-($threshold - $creep)) 
		$evt_string = "***** WARNING ****** Master CRL NextUpdate has a life less than threshold of: " + $threshold + " hour(s)" + $newline + "Master CRLs NextUpdate is: " + $CRL_Master.NextUpdate.AddHours($creep) + $newline +"Certsvc service is: " + $service.Status 
		results $evt_string $EventWarning $SMTP 
	} else { 
		write-debug "Within the Master CRLs NextCRLPublish and NextUpdate period. Within threshold period." 
		write-debug $CRL_Master.NextUpdate.AddHours(-($threshold - $creep)) 
		# Uncomment the following if you want notification on the CRLs 
		#$evt_string = "Within the Master CRLs NextCRLPublish and NextUpdate period. Alerts will be send at " + $threshold + " hour(s) before NextUpdate period is reached." 
		#results $evt_string $EventInformation $SMTP 
	} 
} else { 
    write-debug "logic bomb, can't determine where we are in the threshold" 
}
