param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Get-jnServers-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

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

function New-SQLConnection {
Param (
)
    if (Test-Path Variable:\conn) 
		{$conn.close()} 
	else 
		{$conn = new-object ('System.Data.SqlClient.SqlConnection')}

    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    $conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
} # End of function.

function Insert-MonitoringTaskLogs {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$jnUTCMonitored
	, [Parameter(Mandatory=$True)][ValidateSet("BEGIN", "END")][string]$TaskType
	, [Parameter(Mandatory=$True)][ValidateSet("SERVERS", "CONNECT", "ADDS", "ADCS", "DNS", "DHCP", "RADIUS", "HEALTH")][string]$ADService
	, [string]$TaskScript
)

try {
	$ErrorActionPreference = "Stop"

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"Text" 
	$cmd.Connection = New-SQLConnection

	if ($TaskScript -eq $null -or $TaskScript -eq "") 
		{$TaskScript = ""}
	$cmd.CommandText = " `
Insert into TB_MonitoringTaskLogs ([TaskDate], [TaskType], [Company], [ADService], [TaskScript])
values('$($jnUTCMonitored)', '$($TaskType)', '$($Domain)', '$($ADService)', '$($TaskScript)') `
"

	$cmd.ExecuteNonQuery() | out-Null
	Write-Host "`n[TaskLogs] $($ADService): $($TaskType). ($($TaskScript))`n"

	$cmd.Connection.Close()

}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv jnUTCMonitored) {rv jnUTCMonitored}
	if (gv TaskType) {rv TaskType}
	if (gv ADService) {rv ADService}
	if (gv TaskScript) {rv TaskScript}

}
} # End of function.

# Log the BEGIN time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService SERVERS -jnUTCMonitored $jnUTCMonitored

function Get-jnSQLData {
param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [String]$ServiceFlag
)

	# Query data
	$cmd = new-object "System.Data.SqlClient.SqlCommand"
	$cmd.CommandType = [System.Data.CommandType]"Text"

	if ($domain -eq $null -or $domain -eq "") 
		{$cmd.CommandText = "SELECT * FROM $($TableName)"}
	else {
		if ($ServiceFlag -eq $null -or $ServiceFlag -eq "") 
			{$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($Domain)'"}
		else 
			{$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($Domain)' and ServiceFlag = '$($ServiceFlag)'"}
	}

	$cmd.Connection = New-SQLConnection

	# Get data
	$dtdata = new-object "System.Data.DataTable"
	$rdr = $cmd.ExecuteReader()
	$dtdata.Load($rdr)

	$cmd.Connection.Close()

	return $dtdata
}

#$company = $domain.replace(".","_")
$TableName = "TB_SERVERS"
$ProcName = "IF_SERVERS"
[array]$servers = Get-jnSQLData -TableName $TableName

if ($servers.Count -gt 0) {
	Write-Host "[SQL] Servers Retrieved: $($servers.Count)."
}
else {
	$Message = "[SQL] No Servers Retrieved."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService SERVERS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

	break
}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService SERVERS -jnUTCMonitored $jnUTCMonitored


