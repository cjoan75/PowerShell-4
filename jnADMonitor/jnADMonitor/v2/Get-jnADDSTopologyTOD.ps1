param(
	 [Parameter(mandatory=$True)][Int32]$idx 
	, [string]$domain
	, [string]$server
	, [string]$admuser
	, [string]$admpwd
)

#
# .\Get-jnADDSTopologyTOD.ps1 -idx 1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *
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

# ADDSTopologyTOD Log
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
$eventname = "Get-jnADDSTopologyTOD"
$messages = "[`$jnADDSTopologyTOD] Start running..."
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

$jnADDSTopologyTODResult = Invoke-Command -Session $session -script {

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

function Test-jnADTopology {

	Write-Debug "Processing at: $($env:COMPUTERNAME) `n"
		
	$myresult = @()

	if (!(Get-Module ActiveDirectory -ea 0)) 
		{Import-Module ActiveDirectory}
	[array]$servers = Get-ADDomainController -Filter {Enabled -eq $True} | Sort Name

	$adsites = $servers | group site | sort Name
	$adsites | % {
		
		$hash = @{}
		$hash.Name = $_.Name
		$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

		# Forces the Knowledge Consistency Checker (KCC) on each targeted site to immediately recalculate the inbound replication topology.
		$buf_command = @(REPADMIN /kcc site:"$($_.Name)" | ? {$_ -ne $null -and $_ -ne ""})
	
		if ($buf_command -eq $null) {$hash.RecalculateADTopology = $null} 
		else {
			$hash.IsError = $False
			$buf_command | % {if (($_ -match "ERROR" -or $_ -match "FAIL") -and $_ -notmatch "NO ERROR") {$hash.IsError = $True} }
			$hash.RecalculateADTopology = $buf_command
		}

		if ($hash.Count -gt 0) {
			$myresult += @($hash)
			Write-Debug "`$hash ($($_.Name)): $($hash.gettype()): $($hash.count)"
			Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
		}

	} # End of ADSites.

	Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

	return $myresult

} # End of function

Test-jnADTopology

}

#Write-Host "`nResult:" $jnADDSTopologyTODResult.Count "--" -fore yellow
$jnADDSTopologyTODResult | group Name | sort Count
#$jnADDSTopologyTODResult | % {$_; "--`n"}

# to close powershell remoting session
if (Get-PSSession -InstanceId $session.InstanceId) {
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Host "`n[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
}
else {Write-Host "`n[PSSession] Session failed to close from $($session.ComputerName), InstanceId: $($session.InstanceId)." -ForegroundColor Red}

#[ADDSTopologyTOD_Insert]
function Insert-ADDSTopologyTOD {
param (
    [Parameter(Mandatory=$True)][AllowNull()][Array]$Data
	, [Parameter(Mandatory=$True)][Int32]$IDX
)


# ADDSTopologyTOD Result
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
		
	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

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
	
			if ($row.RecalculateADTopology.count -eq 0) {continue}
			else {
				foreach($RecalculateADTopology in $row.RecalculateADTopology) {$ResultScript += $RecalculateADTopology + "<br/>"}
			}
		}

		if ($ResultScript -ne $null -and $ResultScript -ne "") {
			$Message = "[`$jnADDSTopologyTOD] Completed Successfully."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $ResultScript
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		}
		else {
			$Message = "[`$jnADDSTopologyTOD] No Data returned from [`$ResultScript]."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		}

	}
	else {
		$Message = "[`$jnADDSTopologyTOD] No Data returned from PSSession."
		Write-host $Message
	
		Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $ResultScript
		Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
	}
}

Catch {

	$TODResult = "Y"
	$ResultScript = "[PSArgumentException]: $($Error[0])."
	Write-Host $ResultScript -Fore Red
	
	Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $ResultScript
	Insert-MonitoringTODTaskLogs -Messages $ResultScript -Type $Type -EventName $EventName
	
}

finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}

 }

}
Insert-ADDSTopologyTOD -Data $jnADDSTopologyTODResult -IDX $idx
if (gv jnADDSTopologyTODResult) {rv jnADDSTopologyTODResult}

