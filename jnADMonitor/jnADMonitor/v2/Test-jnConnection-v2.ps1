param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Test-jnConnection-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

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

# to define SQL Connection.
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

} # End of function

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
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService CONNECT -jnUTCMonitored $jnUTCMonitored

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

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

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
	Insert-MonitoringTaskLogs -TaskType END -ADService CONNECT -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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
else {
	$Message = "[PSSession] No new PSSession established."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService CONNECT -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

	break
}

# to connect to the Managed Server in the domain.

[array]$jnConnectivityResult = Invoke-Command -Session $session -script {
param(
	[array]$servers
)

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

function Test-jnTcpPort {
param (
    [Parameter(Mandatory=$True)]
	[string]$HostName
	, [Parameter(Mandatory=$True)]
	[Int32]$Port
)

	$cls = New-object System.Net.Sockets.TcpClient
	$cls.Connect($HostName, $Port)
	
	return $cls.Connected

} # End of function

	$myresult = @()

	$servers = @($servers | Sort ComputerName -Unique)
	$servers | % {

		$hash = @{}
		$hash.ComputerName = $_.ComputerName
		$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
		$hash.jnServiceFlag = "CONNECT"

		if (Test-Connection $_.ComputerName -Count 1 -Quiet) 
			{$hash.CanPing = $True}
		else {$hash.CanPing = $False}

		if (Test-jnTcpPort -HostName $_.ComputerName -Port 135)
			{$hash.CanPort135 = $True}
		else {$hash.CanPort135 = $False}

		if ($hash.CanPing -eq $False -or $hash.CanPort135 -eq $False) 
			{$hash.IsError = $True}
		else {$hash.IsError = $False}

		if ($hash.Count -gt 0) {
			$myresult += @($hash)
			Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
			Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."

		}

	} # end of Foreach.

    Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

	return $myresult

} -ArgumentList (, $servers)

#Write-Host "`nResult:" $jnConnectivityResult.GetType() "--" -fore yellow
$jnConnectivityResult | group ComputerName | sort Count
#$jnConnectivityResult | % {$_; "--`n"}

function Insert-jnSqlData {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName
	, [Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
Function Create-jnSqlTableIfNotExist {
param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::Text
	$cmd.Connection = New-SQLConnection
        
	$cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)](	`
[ComputerName] [nvarchar](50) NOT NULL, `
[CanPing] [nvarchar](5) NOT NULL, `
[CanPort135] [nvarchar](5) NULL, `
[UTCMonitored] [datetime] NOT NULL, `
PRIMARY KEY (ComputerName, UTCMonitored) `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

} # End of function.

Function Create-jnSqlProcedureIfNotExist {
param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName 
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName
)
    
	$cmd = new-object "System.Data.SqlClient.SqlCommand"
	$cmd.CommandType = [System.Data.CommandType]::Text
	$cmd.Connection = New-SQLConnection
    
	$cmd.CommandText = " `
IF object_id('[dbo].[$($ProcName)]', 'p') IS NULL `
BEGIN`
	EXEC('`
	CREATE PROCEDURE [dbo].[$($ProcName)] `
			@ComputerName nvarchar(50) `
			,@CanPing nvarchar(5) `
			,@CanPort135 nvarchar(5) `
			,@UTCMonitored datetime`
	AS`
	BEGIN`
	`
	INSERT INTO [dbo].[$($TableName)] `
			( [ComputerName] `
			,[CanPing] `
			,[CanPort135] `
			,[UTCMonitored] `
			) `
			VALUES`
			( @ComputerName` 
			,@CanPing`
			,@CanPort135`
			,@UTCMonitored`
			) `
`
	END'`
	) `
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

} # End of function.

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
	$insertproblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {
		Write-Debug "[Problem Management] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError -eq $true) {

				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertproblem
		
				if ($data[$i].CanPing -eq $False -and $data[$i].CanPort135 -eq $False)
					{$ProbScrp = "Failed all connections to " + $data[$i].ComputerName + "."}
				else {
					if ($data[$i].CanPing -eq $False)
						{$ProbScrp = "Failed to ping " + $data[$i].ComputerName + "."}
					elseif ($data[$i].CanPort135 -eq $False)
						{$ProbScrp = "Failed to RPC ping " + $data[$i].ComputerName + "."}
				}

				$serviceitem = $null
				switch($Data[$i].jnServiceFlag) {
					"CONNECT" {$serviceitem = "CN01"; Break}
					Default {$serviceitem = $null }
				}

	
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", $Data[$i].jnServiceFlag)
				if ($serviceitem -eq $null)
					{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "Null")}
				else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", $serviceitem)}
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
		
			                       
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
				Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
				Write-Debug "CommandText: $($cmd.CommandText)."

				$cmd.ExecuteNonQuery() | out-Null
				$cmd.Connection.Close()
      
				$rowcount +=  1

			} # End of If it contains Critical or Error event, not Warning.

		} # End of For.

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}

	} # End of If it contains data.

}

	$rowcount = 0

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
    
	Write-Debug "[SQL] Started to insert."

try {
	$ErrorActionPreference = "Stop"

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)
			$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
	
			if ($data[$i].CanPing -eq $null)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CanPing", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CanPing", $data[$i].CanPing.Tostring())}

			if ($data[$i].CanPort135 -eq $null)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@CanPort135", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@CanPort135", $data[$i].CanPort135.Tostring())}

			$cmd.Parameters.Clear()
               
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter5)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter2)

			Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
			Write-Debug "CommandText: $($cmd.CommandText)."

			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			$rowcount +=  1

		} # End of for.

		if ($rowcount -gt 0) {Write-host "[SQL] Data inserted: $($rowcount)."}

	} # End of If data found.

}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}

} # End of Finally.

} # End of Function.

$company = $domain.replace(".","_")
$TableName = "TB_$($company)_CONNECTIVITY"
$ProcName = "IF_$($company)_CONNECTIVITY"

Insert-jnSqlData -Data $jnConnectivityResult -TableName $TableName -ProcName $ProcName

if (gv jnConnectivityResult -ea 0) {rv jnConnectivityResult}

# to close powershell remoting session
if (Get-PSSession -InstanceId $session.InstanceId) {
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Host "`n[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
}
else {Write-Host "`n[PSSession] Session failed to close from $($session.ComputerName), InstanceId: $($session.InstanceId)." -ForegroundColor Red}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService CONNECT -jnUTCMonitored $jnUTCMonitored


