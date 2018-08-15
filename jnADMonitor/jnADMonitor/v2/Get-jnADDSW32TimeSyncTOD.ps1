param(
	 [Parameter(mandatory=$True)][Int32]$idx 
	, [string]$domain
	, [string]$server
	, [string]$admuser
	, [string]$admpwd
)

#
# .\Get-jnADDSW32TimeSyncTOD.ps1 -idx 1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *
#
#################################
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

# ADDSW32TimeSyncTOD Log
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
$eventname = "Get-jnADDSW32TimeSyncTOD"
$messages = "[`$jnADDSW32TimeSyncTOD] Start running..."
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

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

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

# Log the START time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()

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
	{Write-Host "`n[PSSession] Established to $($session.ComputerName) with InstanceId, $($session.InstanceId)."}
else 
	{break}

# to connect to the Managed Server in the domain.

$jnADDSW32TimeSyncTODResult = Invoke-Command -Session $session -script {
param(
	[Parameter(Mandatory=$True)][array]$Servers
)

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

function Test-jnADDSW32TimeSync {
[CmdletBinding()]
param(
    [ValidateSet("Rediscover","Normal")][string]$Mode = 'Normal'
    , [Parameter(Mandatory=$True)][array]$Servers
)

    $myresult = @()

    $servers | % {
		
		Write-Debug "Processing at: $($_.ComputerName) `n"

		if (!(Get-Module ActiveDirectory -ea 0)) 
			{Import-Module ActiveDirectory}
		$mydc = Get-ADDomainController -Identity $_.ComputerName | Sort Name

		if (Test-Connection $mydc.Name -Count 1 -Quiet) {

			$hash = @{}
			$hash.ComputerName = $mydc.Name
			$hash.OperatingSystem = $mydc.OperatingSystem
			if ($mydc.OperatingSystemServicePack -eq $null) 
				{$hash.OperatingSystemServicePack = "0"}
			else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
			$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
			$hash.IsRODC = $mydc.IsReadOnly
			$hash.OperationMasterRoles = $mydc.OperationMasterRoles

			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

			if ($mydc.Name -eq $env:COMPUTERNAME) {

				If ($Mode -eq "Rediscover") { 
					# w32tm /resync: Tell a computer that it should resynchronize its clock as soon as possible, throwing out all accumulated error statistics. However, it does not guaranteed the synchronization result.
					# NOTE: /nowait - do not wait for the resync to occur;  return immediately. Otherwise, wait for the resync to complete before returning. 
					# NOTE: /rediscover - redetect the network configuration and rediscover network sources, then resynchronize.
					$buf = @(w32tm /resync /nowait /rediscover)
				}
				else {
					# w32tm /resync: Tell a computer that it should resynchronize its clock as soon as possible, throwing out all accumulated error statistics. However, it does not guaranteed the synchronization result.
					# NOTE: /nowait - do not wait for the resync to occur;  return immediately. Otherwise, wait for the resync to complete before returning. 
					# NOTE: /rediscover - redetect the network configuration and rediscover network sources, then resynchronize.
					$buf = @(w32tm /resync /nowait)
				} # End of If.

				if ($buf -eq $null) {$hash.ResyncW32Time = $null} 
				else {
					$hash.IsError = $False
					$buf | % {if (($_ -match "ERROR" -or $_ -match "FAIL") -and $_ -notmatch "NO ERROR") {$hash.IsError = $True} }
					$hash.ResyncW32Time = "[$($env:COMPUTERNAME)] " + $buf
				}

			} # End of If the managed server.
			else {

				$hash = Invoke-Command -ComputerName $mydc.Name -ScriptBlock {

					param ($hash, $Mode)
                    
					#$DebugPreference = "Continue"
					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					If ($Mode -eq "Rediscover") { 
						# w32tm /resync: Tell a computer that it should resynchronize its clock as soon as possible, throwing out all accumulated error statistics. However, it does not guaranteed the synchronization result.
						# NOTE: /nowait - do not wait for the resync to occur;  return immediately. Otherwise, wait for the resync to complete before returning. 
						# NOTE: /rediscover - redetect the network configuration and rediscover network sources, then resynchronize.
						$buf = @(w32tm /resync /nowait /rediscover)
					}
					else {
						# w32tm /resync: Tell a computer that it should resynchronize its clock as soon as possible, throwing out all accumulated error statistics. However, it does not guaranteed the synchronization result.
						# NOTE: /nowait - do not wait for the resync to occur;  return immediately. Otherwise, wait for the resync to complete before returning. 
						# NOTE: /rediscover - redetect the network configuration and rediscover network sources, then resynchronize.
						$buf = @(w32tm /resync /nowait)
					} # End of If.

					if ($buf-eq $null) {$hash.ResyncW32Time = $null}
					else {$hash.ResyncW32Time = "[$($env:COMPUTERNAME)] " + $buf}

					if ($hash.Count -gt 0) 
						{return $hash}

				} -ea 0 -ArgumentList $hash, $Mode

			} # End of If Not the managed server.

			if ($hash.Count -gt 0) {
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.Name)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # End of If the server is currently connected.

    } # end of Foreach.

    Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

    return $myresult

} # End of function

Test-jnADDSW32TimeSync -Mode Rediscover -Servers $servers

} -ArgumentList (, $servers)

#Write-Host "`nResult:" $jnADDSW32TimeSyncTODResult.Count "--" -fore yellow
$jnADDSW32TimeSyncTODResult | group Name | sort Count
#$jnADDSW32TimeSyncTODResult | % {$_; "--`n"}

# to close powershell remoting session
if (Get-PSSession -InstanceId $session.InstanceId) {
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Host "PSSession is closed: InstanceId: $($session.InstanceId).`n"
}
else {Write-Host "`n[PSSession] Session failed to close from $($session.ComputerName), InstanceId: $($session.InstanceId)." -ForegroundColor Red}

#[ADDSW32TimeSyncTOD]
function Insert-ADDSW32TimeSyncTOD {
param (
    [Parameter(Mandatory=$True)][AllowNull()][Array]$Data
	, [Parameter(Mandatory=$True)][Int32]$IDX
)

	
# ADDSW32TimeSyncTOD Result
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

			if ($row.ResyncW32Time.count -eq 0) {continue}
			else {
				foreach($ResyncW32Time in $row.ResyncW32Time) {$ResultScript += $ResyncW32Time + "<br/>"}
			}
		}

		if ($ResultScript -ne $null -and $ResultScript -ne "") {
			$Message = "[`$jnADDSW32TimeSyncTOD] Completed Successfully."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $ResultScript
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		
		}
		else {
			$Message = "[`$jnADDSW32TimeSyncTOD] No Data returned from [`$ResultScript]."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		}
	}
	else {
		$Message = "[`$jnADDSW32TimeSyncTOD] No Data returned from PSSession."
		Write-host $Message

		Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
	}
}

Catch {

	$TODResult = "Y"
	$Type = "Error" 
	$EventName = "Get-jnADDSW32TimeSyncTOD"
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
Insert-ADDSW32TimeSyncTOD -Data $jnADDSW32TimeSyncTODResult -IDX $idx
if (gv jnADDSW32TimeSyncTODResult) {rv jnADDSW32TimeSyncTODResult}

