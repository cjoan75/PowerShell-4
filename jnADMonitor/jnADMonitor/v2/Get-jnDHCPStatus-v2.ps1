param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Get-jnDHCPStatus-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

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
    if (Test-Path Variable:\conn) 
		{$conn.close()} 
	else 
		{$conn = new-object ('System.Data.SqlClient.SqlConnection')}

    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    $conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
}

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
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService DHCP -jnUTCMonitored $jnUTCMonitored

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
[array]$servers = Get-jnSQLData -TableName $TableName -ServiceFlag 'DHCP'

if ($servers.Count -gt 0) {
	Write-Host "[SQL] Servers Retrieved: $($servers.Count)."
}
else {
	$Message = "[SQL] No Servers Retrieved."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService DHCP -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

# Get events.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnDHCPEventResult = Invoke-Command -Session $session -script {
	param (
		[Parameter(Mandatory=$True)]$Credential
		, [Parameter(Mandatory=$True)][array]$servers
		, [Parameter(Mandatory=$True)][System.Management.Automation.ActionPreference]$myDebugPreference
	)

		$DebugPreference = $myDebugPreference
		$myresult = @()

		$servers | % {

			if (Test-Connection $_.ComputerName -Count 1 -Quiet) {

			try {
				$ErrorActionPreference = "Stop"

				# to create powershell remote session
				$session = New-PSSession -cn $_.ComputerName -credential $Credential
				Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

				[array]$buf = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName.SubString(0, $_.MachineName.IndexOf("."))}}
					$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"DHCP"}}
					$begindate = (Get-Date).AddHours(-1*24)

					[array]$buf = Get-WinEvent -FilterHashTable @{ `
						ProviderName = `
							'Microsoft-Windows-DHCP-Server' `
							; `
						StartTime = $begindate; `
						Level = 1, 2, 3 } -ea 0 | 
						sort TimeCreated |
						select LogName, TimeCreated, Id, ProviderName, LevelDisplayName, Message, $jnComputerName, $jnUTCMonitored, $jnServiceFlag

					if ($buf.Count -gt 0) {
						Write-Debug "$($env:COMPUTERNAME): $($buf.GetType()), $($buf.count)."
						return $buf
					}

				}

				if ($buf.Count -gt 0) {
					$myresult += @($buf)
					Write-Debug "`$buf ($($_.ComputerName)): $($buf.gettype()): $($buf.count)"
					Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)"
				}
			}
			Catch {
				$jnUTCMonitored = (Get-Date).ToUniversalTime()
				$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
				Write-Host $Message -fore red
			}
			Finally {
				$ErrorActionPreference = "Continue"
	
				# To free resources used by a script.

				# to close powershell remote session
				Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
				Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

			}

			} # End of If the server is currently connected.

		} # end of Foreach.

		Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

		return $myresult

	} -ArgumentList ($cred, $servers, $DebugPreference)

	$jnDHCPEventResult | group ComputerName | sort Count
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService DHCP -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-Event {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)

Function Create-jnSqlTableIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)
	    	  
    $cmd = new-object "System.Data.SqlClient.SqlCommand"
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
        
    $cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)](	`
[LogName] [nvarchar](30) NOT NULL,`
[TimeCreated] [datetime] NOT NULL,`
[Id] [nvarchar](30) NOT NULL,`
[ProviderName] [nvarchar](30) NOT NULL,`
[LevelDisplayName] [nvarchar](30) NOT NULL,`
[Message] [nvarchar](max) NOT NULL,`
[ComputerName] [nvarchar](50) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[ServiceFlag] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

Function Create-jnSqlProcedureIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName
)
	
    $cmd = new-object "System.Data.SqlClient.SqlCommand" 
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
    
    
    $cmd.CommandText = " `
IF object_id('[dbo].[$($ProcName)]', 'p') IS NULL
BEGIN
EXEC('
CREATE PROCEDURE [dbo].[$($ProcName)]
 @LogName nvarchar(30)
,@TimeCreated datetime
,@Id nvarchar(30)
,@ProviderName nvarchar(30)
,@LevelDisplayName nvarchar(30)
,@Message nvarchar(max)
,@ComputerName nvarchar(50)
,@UTCMonitored datetime
,@ServiceFlag nvarchar(10)

AS
BEGIN

INSERT INTO [dbo].[$($TableName)]
   ([LogName]
   ,[TimeCreated]
   ,[Id]
   ,[ProviderName]
   ,[LevelDisplayName]
   ,[Message]
   ,[ComputerName]
   ,[UTCMonitored]
   ,[ServiceFlag])
 VALUES
   (@LogName,
	@TimeCreated,
	@Id,
	@ProviderName,
	@LevelDisplayName,
    @Message,
    @ComputerName,
    @UTCMonitored,
    @ServiceFlag)

END'
)
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
	$insertproblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].LevelDisplayName -ne "warning") {
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertproblem
		
				$ProbScrp = $data[$i].LevelDisplayName.ToString() + "<br/>" + $data[$i].message
				$serviceitem = $null
				switch($Data[$i].jnServiceFlag) {
					"ADCS" {$serviceitem = "CS01"; Break}
					"ADDS" {$serviceitem = "DS01"; Break}
					"DNS" {$serviceitem = "DN01"; Break}
					"DHCP" {$serviceitem = "DH01"; Break}
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
			}
		}

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}
	}

}

try {
	$ErrorActionPreference = "Stop"

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_EVENT"
	$ProcName = "IF_$($company)_EVENT"

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
   
	#Sql Command definition
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

				#Connect to Sql Server        
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $ProcName
		
				if ($data[$i].LogName -eq $null -or $data[$i].LogName -eq "") 
					{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@LogName", "Null")}
				else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@LogName", $data[$i].LogName)}

				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeCreated", $data[$i].TimeCreated)
	
				if ($data[$i].Id -eq $null -or $data[$i].Id -eq "") 
					{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Id", "Null")}
				else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Id", $data[$i].Id)}
				if ($data[$i].ProviderName -eq $null -or $data[$i].ProviderName -eq "") 
					{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ProviderName", "Null")}
				else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ProviderName", $data[$i].ProviderName)}
				if ($data[$i].LevelDisplayName.ToString() -eq $null -or $data[$i].LevelDisplayName.ToString() -eq "") 
					{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", "Null")}
				else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", ($data[$i].LevelDisplayName).ToString())}
				if ($data[$i].Message -eq $null -or $data[$i].Message -eq "") 
					{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", "Null")}
				else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", $data[$i].Message)}
				if ($data[$i].ComputerName -eq $null -or  $data[$i].ComputerName -eq "") 
					{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
				else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
	
				$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)

				if ($data[$i].jnServiceFlag -eq $null -or $data[$i].jnServiceFlag -eq "") 
					{$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", "Null")}
				else {$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", $data[$i].jnServiceFlag)}
        
				$cmd.Parameters.Clear()
        
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
				[void]$cmd.Parameters.Add($SQLParameter7)
				[void]$cmd.Parameters.Add($SQLParameter8)
				[void]$cmd.Parameters.Add($SQLParameter9)
       
				$cmd.ExecuteNonQuery() | out-null

				$cmd.Connection.Close()

			} # End of for.

	} # End of If it contains data.
	else {
		Write-host "[SQL] No Data returned from PSSession."
	} # End of If it doesn't contain data.

}
  
Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}
}
  
}
if ($jnDHCPEventResult.Count -gt 0)	{Insert-Event -Data $jnDHCPEventResult}
if (gv jnDHCPEventResult -ea 0) {rv jnDHCPEventResult}

# Get services.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnDHCPServiceResult = Invoke-Command -Session $session -script {
	param (
		[Parameter(Mandatory=$True)]$Credential
		, [Parameter(Mandatory=$True)][array]$servers
		, [Parameter(Mandatory=$True)][System.Management.Automation.ActionPreference]$myDebugPreference
	)

		$DebugPreference = $myDebugPreference
		$myresult = @()

		$servers | % {

			if (Test-Connection $_.ComputerName -Count 1 -Quiet) {

			try {
				$ErrorActionPreference = "Stop"

				# to create powershell remote session
				$session = New-PSSession -cn $_.ComputerName -credential $Credential
				Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

				[array]$buf = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME)}}
					$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"DHCP"}}

					$svcs = @("dhcpserver")
					$svcs | % {
						[array]$buf01 = Get-Service $_ -ea 0 | % {
							if ($_.Status -ne "Running") 
								{$jnIsError = @{Name="IsError"; Expression={$True}}; $_ | select Status, Name, DisplayName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag, $jnIsError }
							else {$jnIsError = @{Name="IsError"; Expression={$False}}; $_ | select Status, Name, DisplayName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag, $jnIsError }
						}

						if ($buf01.Count -gt 0) {
							$buf += $buf01
							Write-Debug "$($env:COMPUTERNAME): $($buf01.GetType()), $($buf01.Count)."
						} 

					} # End of services.

					if ($buf.Count -gt 0) {
						Write-Debug "$($env:COMPUTERNAME): $($buf.GetType()), $($buf.count)."
						return $buf
					}

				}

				if ($buf.Count -gt 0) {
					$myresult += @($buf)
					Write-Debug "`$buf ($($_.ComputerName)): $($buf.gettype()): $($buf.count)"
					Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)"
				}

			}
			Catch {
				$jnUTCMonitored = (Get-Date).ToUniversalTime()
				$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
				Write-Host $Message -fore red
			}
			Finally {
				$ErrorActionPreference = "Continue"
	
				# To free resources used by a script.

				# to close powershell remote session
				Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
				Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
			}

			} # End of If the server is currently connected.

		} # end of Foreach.

		Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

		return $myresult

	} -ArgumentList ($cred, $servers, $DebugPreference)

	$jnDHCPServiceResult | group computername | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService DHCP -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-Service {
param (
    [Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
Function Create-jnSqlTableIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::Text
	$cmd.Connection = New-SQLConnection
        
	$cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)](	`
[ServiceStatus] [nvarchar](30) NOT NULL,`
[Name] [nvarchar](30) NOT NULL,`
[DisplayName] [nvarchar](50) NOT NULL,`
[ComputerName] [nvarchar](50) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[ServiceFlag] [nvarchar](10) NOT NULL,`
[IsError] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

Function Create-jnSqlProcedureIfNotExist {
param (
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
			@ServiceStatus nvarchar(30) `
			,@Name nvarchar(30) `
			,@DisplayName nvarchar(50) `
			,@ComputerName nvarchar(50) `
			,@UTCMonitored datetime`
			,@ServiceFlag nvarchar(10) `
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
	`
	INSERT INTO [dbo].[$($TableName)] `
			( [ServiceStatus] `
			,[Name] ` 
			,[DisplayName] `
			,[ComputerName] `
			,[UTCMonitored] `
			,[ServiceFlag] `
			,[IsError] `
			) `
			VALUES`
			( @ServiceStatus` 
			,@Name` 
			,@DisplayName`
			,@ComputerName`
			,@UTCMonitored`
			,@ServiceFlag`
			,@IsError`
			) `
`
	END'`
	) `
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][AllowNull()][array]$Data
)

	$ProcName = "IF_ProblemManagement"	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError -eq $true) {
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $ProcName
		
				# .Status property returned [Int32].
				$ProbScrp = $data[$i].Status.ToString() + "<br/>" + $data[$i].Name + "<br/>" + $data[$i].DisplayName
				$serviceitem = $null

				switch($Data[$i].jnServiceFlag) {
					"ADCS" {$serviceitem = "CS02"; Break}
					"ADDS" {$serviceitem = "DS02"; Break}
					"DNS" {$serviceitem = "DN02"; Break}
					"DHCP" {$serviceitem = "DH02"; Break}
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
			}
		}

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}
	}

}

try {
	$ErrorActionPreference = "Stop"

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_SERVICE"
	$ProcName = "IF_$($company)_SERVICE"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
  
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			if ($data[$i].Status.ToString() -eq $null -or $data[$i].Status.ToString() -eq "") 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ServiceStatus", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ServiceStatus", $data[$i].Status.ToString())}
			if ($data[$i].Name -eq $null -or $data[$i].Name -eq "") 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Name", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Name", $data[$i].Name)}
			if ($data[$i].DisplayName -eq $null -or $data[$i].DisplayName -eq "") 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@DisplayName", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@DisplayName", $data[$i].DisplayName)}
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "") 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
			if ($data[$i].jnServiceFlag -eq $null -or $data[$i].jnServiceFlag -eq "") 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", $data[$i].jnServiceFlag)}
			if ($data[$i].IsError.ToString() -eq $null -or $data[$i].IsError.ToString() -eq "") 
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@IsError", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())}
        
			$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
	         
			$cmd.Parameters.Clear()
               
			[void]$cmd.Parameters.Add($SQLParameter1)
			[void]$cmd.Parameters.Add($SQLParameter2)
			[void]$cmd.Parameters.Add($SQLParameter3)
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter5)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter7)
        
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()

		} # End of for.

	} # End of If it contains data.
	else {
		Write-host "[SQL] No Data returned from PSSession."
	} # End of If it doesn't contain data.


}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}
}
}
if ($jnDHCPServiceResult.Count -gt 0) {Insert-Service -Data $jnDHCPServiceResult}
if (gv jnDHCPServiceResult -ea 0) {rv jnDHCPServiceResult}

# Get performance data.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	$jnDHCPPerformanceDataResult = Invoke-Command -Session $session -script {
	param (
		[Parameter(Mandatory=$True)]$Credential
		, [Parameter(Mandatory=$True)][array]$servers
		, [Parameter(Mandatory=$True)][System.Management.Automation.ActionPreference]$myDebugPreference
	)

		$DebugPreference = $myDebugPreference
		$myresult = @()

		$servers | % {

			if (Test-Connection $_.ComputerName -Count 1 -Quiet) {

			try {
				$ErrorActionPreference = "Stop"

				# to create powershell remote session
				$session = New-PSSession -cn $_.ComputerName -credential $Credential
				Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

				[array]$cntrsets = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					# Base Counter Sets
					$CounterSets = @("processor", "Memory", "Process", "PhysicalDisk")
					# AD DS Counter Sets
					#$CounterSets += @("ADWS", "DirectoryServices", "DFS Replication Connections", "FileReplicaConn", "Netlogon", "NTDS")
					# AD CS Counter Sets
					#$CounterSets += @("Certification Authority*")
					# DNS Server Counter Sets
					#$CounterSets += @("*DNS*")
					# DHCP Server Counter Sets
					$CounterSets += @("dhcp server*")
 
					Get-Counter -ListSet $CounterSets -ea 0 | sort CounterSetName
				}
            
				[array]$cntrs = $cntrsets | select -expand Paths | 
					? { `
						$_ -eq "\Memory\Available MBytes" `
					-or $_ -eq "\Network Interface(*)\Output Queue Length" `
					} | 
					sort

				# In addition, to add counters with given PathsWithInstances.

				$cntrs += @("\PhysicalDisk(_Total)\Avg. Disk Queue Length")
				$cntrs += @("\Processor(_Total)\% Processor Time")

				$processname = @("_Total")
				#$processname += @("lsass", "dfsrs", "ntfrs", "ismserv", "Microsoft.ActiveDirectory.WebServices")
				#$processname += @("certsrv")
				#$processname += @("dns")
				$processname += @("svchost")

				$counterobjects = @("% Processor Time", "Private Bytes", "Handle Count")
				$counterobjects | % {
					foreach ($ps in $processname) {
						$cntrs += @("\Process($($ps))\$($_)")
					}
				}

				# Based on, Monitoring DHCP Server Performance,
				# http://technet.microsoft.com/en-us/library/dd145323(v=ws.10).aspx
				$cntrs += @("\DHCP server\packets received/sec”)
				$cntrs += @("\DHCP server\Duplicates Dropped/sec”)
				$cntrs += @("\DHCP server\Packets Expired/sec”)
				$cntrs += @("\DHCP server\Milliseconds per packet (Avg.)”)
				$cntrs += @("\DHCP Server\Active Queue Length”)
				$cntrs += @("\DHCP Server\Conflict Check Queue Length”)
				$cntrs += @("\DHCP Server\Discovers/sec”)
				$cntrs += @("\DHCP Server\Offers/sec”)
				$cntrs += @("\DHCP Server\Requests/sec”)
				$cntrs += @("\DHCP Server\Acks/sec”)
				$cntrs += @("\DHCP Server\Informs/sec”)
				$cntrs += @("\DHCP Server\Releases/sec”)
				$cntrs += @("\DHCP server\Nacks/sec”)
				$cntrs += @("\DHCP server\Declines/sec”)

				# Sample: (Get-Counter "\PhysicalDisk(*)\Avg. Disk Queue Length").countersamples | select *
				[array]$buf = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME)}}
					$jnCookedValue = @{Name="Value"; Expression={[math]::Round($_.CookedValue, 2)}}
					$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"DHCP"}}

					[array]$buf = (Get-Counter $args[0] -ea 0).CounterSamples | 
						select TimeStamp, TimeStamp100NSec, $jnCookedValue, Path, InstanceName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag
					if ($buf.Count -gt 0) {
						Write-Debug "$($env:COMPUTERNAME): $($buf.GetType()), $($buf.count)."
						return $buf
					}
				} -ea 0 -ArgumentList (,$cntrs)

				if ($buf.Count -gt 0) {
					$myresult += @($buf)
					Write-Debug "`$buf ($($_.ComputerName)): $($buf.gettype()): $($buf.count)"
					Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)"
				}

			}
			Catch {
				$jnUTCMonitored = (Get-Date).ToUniversalTime()
				$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
				Write-Host $Message -fore red
			}
			Finally {
				$ErrorActionPreference = "Continue"
	
				# To free resources used by a script.

				# to close powershell remote session
				Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
				Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
			}

			} # End of If the server is currently connected.

		} # end of Foreach.

		Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

		return $myresult

	} -ArgumentList ($cred, $servers, $DebugPreference)

	$jnDHCPPerformanceDataResult | group computername | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService DHCP -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-Performance {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)

Function Create-jnSqlTableIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)
    
    $cmd = new-object "System.Data.SqlClient.SqlCommand" 
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
        
    $cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)](	`
[TimeStamp] [datetime] NOT NULL,`
[TimeStamp100NSec] [nvarchar](18) NOT NULL,`
[Value] [float] NOT NULL,`
[Path] [nvarchar](100) NOT NULL,`
[InstanceName] [nvarchar](100) NULL,`
[ComputerName] [nvarchar](50) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[ServiceFlag] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

Function Create-jnSqlProcedureIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName 
)

    $cmd = new-object "System.Data.SqlClient.SqlCommand"
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
    
    $cmd.CommandText = "IF object_id('[dbo].[$($ProcName)]', 'p') IS NULL `
BEGIN`
	EXEC('`
	CREATE PROCEDURE [dbo].[$($ProcName)] `
			 @TimeStamp datetime`
		    ,@TimeStamp100NSec nvarchar(18) `
			,@Value float `
			,@Path nvarchar(100) `
			,@InstanceName nvarchar(100) `
	        ,@ComputerName nvarchar(50) `
	        ,@UTCMonitored datetime`
			,@ServiceFlag nvarchar(10) `
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   ( [TimeStamp] ` 
		    ,[TimeStamp100NSec] ` 
			,[Value] `
			,[Path] `
			,[InstanceName] `
		    ,[ComputerName] `
	        ,[UTCMonitored] `
			,[ServiceFlag] `
		   ) `
		 VALUES`
		   ( @TimeStamp` 
		    ,@TimeStamp100NSec` 
			,@Value`
			,@Path`
	        ,@InstanceName`
	        ,@ComputerName` 
			,@UTCMonitored`
			,@ServiceFlag`
		   ) `
`
	END'`
	) `
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

try {
	$ErrorActionPreference = "Stop"

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_PERFORMANCE"
	$ProcName = "IF_$($company)_PERFORMANCE"

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
		
			if ($Data[$i].TimeStamp -eq $null -or $Data[$i].TimeStamp -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp", $Data[$i].TimeStamp)}
		
			if ($Data[$i].TimeStamp100NSec.tostring() -eq $null -or $Data[$i].TimeStamp100NSec.tostring() -eq "")
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp100NSec", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp100NSec", $Data[$i].TimeStamp100NSec.tostring())}
		 
			if ($Data[$i].Value -eq $null)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Value", -1)}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Value", $Data[$i].Value)}
		
			if ($Data[$i].Path -eq $null -or $Data[$i].Path -eq "")
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@Path", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@Path", $Data[$i].Path)}
		
			if ($Data[$i].InstanceName -eq $null -or $Data[$i].InstanceName -eq "")
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@InstanceName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@InstanceName", $Data[$i].InstanceName)}
		
			if ($Data[$i].ComputerName -eq $null -or $Data[$i].ComputerName -eq "")
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)}
		
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $Data[$i].jnUTCMonitored)
		
			if ($Data[$i].jnServiceFlag -eq $null -or $Data[$i].jnServiceFlag -eq "")
				{$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", "Null")}
			else {$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", $Data[$i].jnServiceFlag)}
        
		                       
			$cmd.Parameters.Clear()
               
			[void]$cmd.Parameters.Add($SQLParameter1)
			[void]$cmd.Parameters.Add($SQLParameter2)
			[void]$cmd.Parameters.Add($SQLParameter3)
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter5)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter7)
			[void]$cmd.Parameters.Add($SQLParameter8)
        
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()

		} # End of for.

	} # End of If it contains data.
	else {
		Write-host "[SQL] No Data returned from PSSession."
	} # End of If it doesn't contain data.

}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($jnDHCPPerformanceDataResult.Count -gt 0) {Insert-Performance -Data $jnDHCPPerformanceDataResult}
if (gv jnDHCPPerformanceDataResult -ea 0) {rv jnDHCPPerformanceDataResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnDHCPServiceAvailabilityResult = Invoke-Command -Session $session -script {
	param (
		[Parameter(Mandatory=$True)]$Credential
		, [Parameter(Mandatory=$True)][array]$servers
		, [Parameter(Mandatory=$True)][System.Management.Automation.ActionPreference]$myDebugPreference
	)

		$DebugPreference = $myDebugPreference
		$myresult = @()

		$servers | % {
		
			if (Test-Connection $_.ComputerName -Count 1 -Quiet) {

			try {
				$ErrorActionPreference = "Stop"

				# to create powershell remote session
				$session = New-PSSession -cn $_.ComputerName -credential $Credential
				Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

				$hash = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$hash = @{}
					$hash.ComputerName = $env:COMPUTERNAME
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

					$OS = gwmi Win32_OperatingSystem
					$hash.OperatingSystem = $OS.Caption
					$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()

					# Displays status information for the specified DHCP server.
					$hash.serverstatus = @(netsh dhcp server show serverstatus | 
						? {$_ -ne $null -and $_ -ne ""} | 
						% {if ($_ -notlike "Server Status:*") {$_.SubString($_.IndexOf("Server Attrib"))}})
				
					# Displays information about server database configuration for the specified DHCP server.
					netsh dhcp server show dbproperties | 
						? {$_ -ne $null -and $_ -ne ""} | 
						% { `
						if ($_ -match "DatabaseName") {$hash.DatabaseName = $_.SubString($_.IndexOf("= ")+2)}
						elseif ($_ -match "DatabasePath") {$hash.DatabasePath = $_.SubString($_.IndexOf("= ")+2)}
						elseif ($_ -match "DatabaseBackupPath") {$hash.DatabaseBackupPath = $_.SubString($_.IndexOf("= ")+2)}
						elseif ($_ -match "DatabaseBackupInterval") {$hash.DatabaseBackupInterval = $_.SubString($_.IndexOf("= ")+2)}
						elseif ($_ -match "DatabaseLoggingFlag") {$hash.DatabaseLoggingFlag = $_.SubString($_.IndexOf("= ")+2)}
						elseif ($_ -match "DatabaseRestoreFlag") {$hash.DatabaseRestoreFlag = $_.SubString($_.IndexOf("= ")+2)}
						elseif ($_ -match "DatabaseCleanupInterval") {$hash.DatabaseCleanupInterval = $_.SubString($_.IndexOf("= ")+2)}
						}

					# Displays the current version of the Server.
					$serverversion = netsh dhcp server show version | ? {$_ -ne $null -and $_ -ne ""}
					$hash.version = $serverversion.Substring($serverversion.IndexOf(" is ")+4).TrimEnd(".")

					if ($hash.Count -gt 0)
						{return $hash}

				}

				if ($hash -ne $null) {
					if (($hash.Values -match "ERROR" -or $hash.Values -match "FAIL") -and $hash.Values -notmatch "NO ERROR") 
						{$hash.IsError = $True} 
					else {$hash.IsError = $False}
				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
					Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
				}

			}
			Catch {
				$jnUTCMonitored = (Get-Date).ToUniversalTime()
				$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
				Write-Host $Message -fore red
			}
			Finally {
				$ErrorActionPreference = "Continue"
	
				# To free resources used by a script.

				# to close powershell remote session
				Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
				Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
			}

			} # End of If the server is currently connected.

		} # end of Foreach.

		Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

		return $myresult

	} -ArgumentList ($cred, $servers, $DebugPreference)

	$jnDHCPServiceAvailabilityResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService DHCP -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-DHCPServiceAvailability {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)

Function Create-jnSqlTableIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)
	    
    $cmd = new-object "System.Data.SqlClient.SqlCommand" 
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
        
    $cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)](	`
[ComputerName] [nvarchar](50)	NOT NULL,`
[OperatingSystem] [nvarchar](100)	NULL,`
[OperatingSystemServicePack] [nvarchar](100) NULL,`
[serverstatus] [nvarchar](300) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL `,
[DatabaseName] [nvarchar](100) NULL,`
[DatabasePath] [nvarchar] (100)	NULL,`
[DatabaseBackupPath] [nvarchar](100) NULL,`
[DatabaseBackupInterval] [nvarchar](20) NULL,`
[DatabaseLoggingFlag] [nvarchar](20) NULL,`
[DatabaseRestoreFlag] [nvarchar](20) NULL,`
[DatabaseCleanupInterval] [nvarchar](20) NULL,`
[IsError] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

Function Create-jnSqlProcedureIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName 
)
    
    $cmd = new-object "System.Data.SqlClient.SqlCommand" 
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
    
    
    $cmd.CommandText = "IF object_id('[dbo].[$($ProcName)]', 'p') IS NULL `
BEGIN`
	EXEC('`
	CREATE PROCEDURE [dbo].[$($ProcName)] `
			    @ComputerName nvarchar(50),` 
			 	@OperatingSystem nvarchar(100),`
				@OperatingSystemServicePack nvarchar(100),`
				@serverstatus nvarchar(300),`
				@UTCMonitored datetime,`
				@DatabaseName nvarchar(100),`
				@DatabasePath nvarchar(100),`
				@DatabaseBackupPath nvarchar(100),`
				@DatabaseBackupInterval nvarchar(20),`
				@DatabaseLoggingFlag nvarchar(20),`
				@DatabaseRestoreFlag nvarchar(20),`
				@DatabaseCleanupInterval nvarchar(20),`
				@IsError nvarchar(10) `
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   ([ComputerName],` 
			[OperatingSystem],`
			[OperatingSystemServicePack],`
			[serverstatus],`
			[UTCMonitored],
			[DatabaseName],`
			[DatabasePath],`
			[DatabaseBackupPath],`
			[DatabaseBackupInterval],`
			[DatabaseLoggingFlag],`
			[DatabaseRestoreFlag],`
			[DatabaseCleanupInterval],`
			[IsError]) `
		 VALUES`
			   (@ComputerName,` 
				@OperatingSystem,`
				@OperatingSystemServicePack,`
				@serverstatus,`
				@UTCMonitored,`
				@DatabaseName,`
				@DatabasePath,`
				@DatabaseBackupPath,`
				@DatabaseBackupInterval,`
				@DatabaseLoggingFlag,`
				@DatabaseRestoreFlag,`
				@DatabaseCleanupInterval,`
				@IsError) `
	END'`
	) `
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
	$insertProblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError -eq $true) {

				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertProblem
		
				for($j = 0;$j -lt $data[$i].serverstatus.count;$j++) {$serverstatus += $data[$i].serverstatus[$j] + "<br/>"}

				$ProbScrp = "DHCP Server Status: " + $serverstatus
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "DHCP")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DH04")
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
			}
		}

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}
	}

}

try {
	$ErrorActionPreference = "Stop"

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_DHCPServiceAvailability"
	$ProcName = "IF_$($company)_DHCPServiceAvailability"

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
    
	#Sql Command definition
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}
			#Connect to Sql Server        
			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$serverstatus = $null
		
			$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)
        
			if ($data[$i].OperatingSystem -eq $null -or $data[$i].OperatingSystem -eq "")
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "")
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
        
			if ($Data[$i].serverstatus.count -eq 0)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@serverstatus", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].serverstatus.count;$j++) {$serverstatus += $data[$i].serverstatus[$J] + "<br/>"}
			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@serverstatus", $serverstatus)}

			$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			if ($data[$i].DatabaseName -eq $null -or $data[$i].DatabaseName -eq "")
			{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseName", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseName", $data[$i].DatabaseName)}
			if ($data[$i].DatabasePath -eq $null -or $data[$i].DatabasePath -eq "")
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@DatabasePath", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@DatabasePath", $data[$i].DatabasePath)}
			if ($data[$i].DatabaseBackupPath -eq $null -or $data[$i].DatabaseBackupPath -eq "")
				{$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupPath", "Null")}
			else {$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupPath", $data[$i].DatabaseBackupPath)}
			if ($data[$i].DatabaseBackupInterval -eq $null -or $data[$i].DatabaseBackupInterval -eq "")
				{$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupInterval", "Null")}
			else {$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupInterval", $data[$i].DatabaseBackupInterval)}
			if ($data[$i].DatabaseLoggingFlag -eq $null -or $data[$i].DatabaseLoggingFlag -eq "")
				{$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseLoggingFlag", "Null")}
			else {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseLoggingFlag", $data[$i].DatabaseLoggingFlag)}
			if ($data[$i].DatabaseRestoreFlag -eq $null -or $data[$i].DatabaseRestoreFlag -eq "")
				{$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseRestoreFlag", "Null")}
			else {$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseRestoreFlag", $data[$i].DatabaseRestoreFlag)}
			if ($data[$i].DatabaseCleanupInterval -eq $null -or $data[$i].DatabaseCleanupInterval -eq "")
				{$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseCleanupInterval", "Null")}
			else {$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseCleanupInterval", $data[$i].DatabaseCleanupInterval)}
			$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())

			$cmd.Parameters.Clear()
        
			[void]$cmd.Parameters.Add($SQLParameter1)
			[void]$cmd.Parameters.Add($SQLParameter2)
			[void]$cmd.Parameters.Add($SQLParameter3)
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter5)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter7)
			[void]$cmd.Parameters.Add($SQLParameter8)
			[void]$cmd.Parameters.Add($SQLParameter9)
			[void]$cmd.Parameters.Add($SQLParameter10)
			[void]$cmd.Parameters.Add($SQLParameter11)
			[void]$cmd.Parameters.Add($SQLParameter12)
			[void]$cmd.Parameters.Add($SQLParameter13)
        
			$cmd.ExecuteNonQuery() | out-null

			$cmd.Connection.Close()

		} # End of for.

	} # End of If it contains data.
	else {
		Write-host "[SQL] No Data returned from PSSession."
	} # End of If it doesn't contain data.


} 

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}
}
}
if ($jnDHCPServiceAvailabilityResult.Count -gt 0) {Insert-DHCPServiceAvailability -Data $jnDHCPServiceAvailabilityResult}
if (gv jnDHCPServiceAvailabilityResult -ea 0) {rv jnDHCPServiceAvailabilityResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService DHCP -jnUTCMonitored $jnUTCMonitored

