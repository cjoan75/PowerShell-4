param(
	 [Parameter(mandatory=$True)][Int32]$idx 
	, [string]$domain
	, [string]$server
	, [string]$admuser
	, [string]$admpwd
)

#
# .\Get-jnADDSOrphanedSiteLinkTOD.ps1 -idx 21 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *
#

$server = $server
$domain = $domain
$serverfqdn = "$($server).$($domain)"
$userfqdn = "$($admuser)@$($domain)"
$pwd = ConvertTo-SecureString $admpwd -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userfqdn, $pwd

#################################
##### SQL Authentication ########
#################################
$SqlServerName = 'dxm'
$DataBaseName = 'ADSysMon'
$SQLUserName = 'sa'
$SQLUserPwd = 'P@ssw0rd'

#$DebugPreference = "Continue"
Write-Debug "CONNECTED TO $($serverfqdn) AS $($userfqdn).`n"

#[SQL Connection]
function New-SQLConnection {
Param (
)
    if (test-path variable:\conn) {
        $conn.close()
    } else {
        $conn = new-object ('System.Data.SqlClient.SqlConnection')
    }
    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    $conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
}

# ADDSOrphanedSiteLinkTOD Log
function Insert-MonitoringTODTaskLogs{
param (
    [Parameter(Mandatory=$True)][string]$Messages
	, [Parameter(Mandatory=$True)][string]$Type
	, [Parameter(Mandatory=$True)][string]$EventName
)
	
	$ProcName = "USP_INSERT_SYSTEM_LOG"

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 
	$cmd.Connection = New-SQLConnection
	$cmd.CommandText = $ProcName

	# Log the time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()

	$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@TYPE", $Type)
	$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@EVENT_NAME", $EventName)
	$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@MESSAGE", $Messages)
	$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CREATE_DATE", $jnUTCMonitored)
	$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@CREATER_ID", "PS")
	
	$cmd.Parameters.Clear()
               
    [void]$cmd.Parameters.Add($SQLParameter1)
	[void]$cmd.Parameters.Add($SQLParameter2)
	[void]$cmd.Parameters.Add($SQLParameter3)
	[void]$cmd.Parameters.Add($SQLParameter4)
	[void]$cmd.Parameters.Add($SQLParameter5)
		
	$cmd.ExecuteNonQuery() | out-Null
	$cmd.Connection.Close()
}

$type = "Info"
$eventname = "Get-jnADDSOrphanedSiteLinkTOD"
$messages = "[`$jnADDSOrphanedSiteLinkTOD] Start running..."
Insert-MonitoringTODTaskLogs -Type $type -EventName $eventname -Messages $messages 

function Get-jnSQLData {
param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [String]$ServiceFlag
)

	# Query data
	$cmd = new-object "System.Data.SqlClient.SqlCommand"
	$cmd.CommandType = [System.Data.CommandType]"Text"
	$cmd.Connection = New-SQLConnection

	if ($domain -eq $null -or $domain -eq "") 
		{$cmd.CommandText = "SELECT * FROM $($TableName)"}
	else {
		if ($ServiceFlag -eq $null -or $ServiceFlag -eq "") 
			{$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($Domain)'"}
		else 
			{$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($Domain)' and ServiceFlag = '$($ServiceFlag)'"}
	}

#	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
#	Write-Debug "CommandText: $($cmd.CommandText)."

	# Get data
	$dtdata = new-object "System.Data.DataTable"
	$rdr = $cmd.ExecuteReader()
	$dtdata.Load($rdr)

	$cmd.Connection.Close()

	return $dtdata

} # End of function

#$company = $domain.replace(".","_")
$TableName = "TB_SERVERS"
$ProcName = "IF_SERVERS"
[array]$servers = Get-jnSQLData -TableName $TableName -ServiceFlag 'ADDS'

if ($servers.Count -gt 0) {
	Write-Host "`n[SQL] Servers Retrieved: $($servers.Count)."
}
else {
    Write-Host "`n[SQL] No Servers Retrieved.`n" -fore yellow
	break
}

# Add host to TrustedHosts to the local client to use NTLM.
if ($domain -ne $env:USERDNSDOMAIN ) {
    if (!(Get-jnTrustedHosts -Value "*.$($domain)"))
	{ 
		if (!(Get-jnTrustedHosts -Value $serverfqdn))
			{Add-jnTrustedHosts -Value $serverfqdn}
	}
}

# to create powershell remoting session
if ($session = New-PSSession -cn $serverfqdn -credential $cred)
	{Write-Host "`n[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."}
else 
	{break}

# to connect to the Managed Server in the domain.

[array]$jnADDSOrphanedSiteLinkTODResult = Invoke-Command -Session $session -script {

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

function Get-jnADOrphanedSiteLink {

	$myresult = @()

	Write-Debug "Processing at: $($env:COMPUTERNAME) `n"
		
	if (!(Get-Module ActiveDirectory -ea 0)) 
		{Import-Module ActiveDirectory}

	$buf = @(DSQUERY * "cn=IP,cn=inter-site transports,CN=Sites,cn=configuration,$((Get-ADDomain).DistinguishedName)" -attr cn sitelist -l)	

	for ($I = 0; $I -lt $buf.count; $I++) {

		if ($buf[$I] -match "cn: IP") {
			continue
		} # End of If the folder name returned, "cn: IP"
		else {
			if ($buf[$I] -match "cn: ") {

				for ($J = 1; $J -le 2; $J++) {
					if ($buf[$I+$J] -match "sitelist: ") {
						if ($buf[$I+$J+1] -match "sitelist: ") {
							Write-Host ("Well associated in: " + $buf[$I].ToString().TrimStart("cn: "))
							continue
						} # End of If at least two sites are associated.
						else {
							$buf_OrphanedSiteLink = $buf[$I].ToString().TrimStart("cn: ")
							$buf_OrphanedSiteLinkSite = $buf[$I+1].ToString().TrimStart("sitelist: ")
						} # End of If only one site is associated.
					} # End of If at least one site is associated.
					else {
						$buf_OrphanedSiteLink = $buf[$I].ToString().TrimStart("cn: ")
						$buf_OrphanedSiteLinkSite = $null
					} # End of If no site is associated.

				} # End of For.

				$hash = @{}
				$hash.DnsDomainName = (Get-ADDomain).DnsRoot
				$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

				if ($buf_OrphanedSiteLink -ne $null) {
					$hash.OrphanedSiteLink = $buf_OrphanedSiteLink
					$hash.OrphanedSiteLinkSite = $buf_OrphanedSiteLinkSite
					$hash.IsError = $True

					if ($hash.Count -gt 0) {
						$myresult += @($hash)
						Write-Debug "`$hash ($($_.Name)): $($hash.gettype()): $($hash.count)"
						Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
					}

				} # End of If Orphaned Site Link is found.
				else {
					$hash.IsError = $False
					
				} # End of If Orphaned Site Link is NOT found.

			} # End of if data gets returned.

		} # End of if real data gets returned.

		Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

		return $myresult

	} # End of For.

} # End of function

Get-jnADOrphanedSiteLink

}

#Write-Host "`nResult:" $jnADDSOrphanedSiteLinkTODResult.Count "--" -fore yellow
$jnADDSOrphanedSiteLinkTODResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
#$jnADDSOrphanedSiteLinkTODResult | % {$_; "--`n"}

# to close powershell remoting session
if (Get-PSSession -InstanceId $session.InstanceId) {
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Host "`n[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
}
else {Write-Host "`n[PSSession] Session failed to close from $($session.ComputerName), InstanceId: $($session.InstanceId)." -ForegroundColor Red}

#[ADDSOrphanedSiteLinkTODResult]
function Insert-ADDSOrphanedSiteLinkTOD {
param (
    [Parameter(Mandatory=$True)][AllowNull()][Array]$Data
	, [Parameter(Mandatory=$True)][Int32]$IDX
)

# ADDSOrphanedSiteLinkTOD Result
function Insert-TODResult{
param (
    [Parameter(mandatory=$True)][Int32]$IDX
	, [Parameter(mandatory=$True)][string]$TODResult
	, [Parameter(mandatory=$True)][string]$ResultScript
)
	$ProcName = "USP_UPDATE_TEST_ON_DEMAND_COMPLETED"
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure"	
	$cmd.Connection = New-SQLConnection
    $cmd.CommandText = $ProcName

	$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@IDX", $IDX)
    $SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TOD_Result", $TODResult)
	$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@TOD_ResultScript", $ResultScript)
                               
    $cmd.Parameters.Clear()
               
    [void]$cmd.Parameters.Add($SQLParameter1)
    [void]$cmd.Parameters.Add($SQLParameter2)
	[void]$cmd.Parameters.Add($SQLParameter3)
                       
    $cmd.ExecuteNonQuery() | out-Null
    $cmd.Connection.Close()
}

try {
	$ErrorActionPreference = "Stop"

	$TODResult = "Y"
	$Type = "Info"
	
	if ($Data.Count -gt 0) {
		foreach($row in $Data) {
			if ($row.count -eq 0) {continue}

			$OrphanedSiteLink, $OrphanedSiteLinkSite, $ResultScript = $null

			if ($row.OrphanedSiteLink.count -eq 0 -and $row.OrphanedSiteLinkSite.count -eq 0)
				{continue}
			else {
				foreach($OrphanedSiteLink in $row.OrphanedSiteLink) {$ResultScript1 += $OrphanedSiteLink + "<br/>"}
				foreach($OrphanedSiteLinkSite in $row.OrphanedSiteLinkSite) {$ResultScript2 += $OrphanedSiteLinkSite + "<br/>"}
				$ResultScript = "OrphanedSiteLink: " + $ResultScript1 + "OrphanedSiteLinkSite: " + $ResultScript2
			}

		} # End of foreach.

		if ($ResultScript -ne $null -and $ResultScript -ne "") {
			$Message = "[`$jnADDSOrphanedSiteLinkTODResult] Completed Successfully."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $ResultScript
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		
		}
		else {
			$Message = "[`$jnADDSOrphanedSiteLinkTODResult] No Data returned from [`$ResultScript]."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		
		}

	} # End of If it contains data.
	else {
		$Message = "[`$jnADDSOrphanedSiteLinkTODResult] No Data returned from PSSession."
		Write-host $Message

		Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
		
	} # End of If it doesn't contain data.

}

Catch {

	$TODResult = "Y"
	$Type = "Error" 
	$EventName = "Get-jnADDSOrphanedSiteLinkTOD"
	$Message = "[EXCEPTION] $($Error[0]).`n"

	Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
	Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName

	Write-Host $Message -Fore Red
}

finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}
}
}
Insert-ADDSOrphanedSiteLinkTOD -Data $jnADDSOrphanedSiteLinkTODResult -IDX $idx
if (gv jnADDSOrphanedSiteLinkTODResult) {rv jnADDSOrphanedSiteLinkTODResult}



