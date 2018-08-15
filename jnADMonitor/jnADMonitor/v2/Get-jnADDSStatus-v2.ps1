param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Get-jnADDSStatus-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

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
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService ADDS -jnUTCMonitored $jnUTCMonitored

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
	Write-Host "[SQL] Servers Retrieved: $($servers.Count)."
}
else {
	$Message = "[SQL] No Servers Retrieved."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

	$jnADDSEventResult = Invoke-Command -Session $session -script {
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
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADDS"}}
					$begindate = (Get-Date).AddHours(-1*24)

					[array]$buf = Get-WinEvent -FilterHashTable @{ `
						ProviderName = `
							'Active Directory Web Services' `
							, 'Microsoft-Windows-Directory-Services-SAM' `
							, 'Microsoft-Windows-ActiveDirectory_DomainService' `
							, 'Microsoft-Windows-DirectoryServices-DSROLE-Server' `
							, 'Microsoft-Windows-DirectoryServices-LSADB' `
							, 'Microsoft-Windows-DirectoryServices-Deployment' `
							, 'Microsoft-Windows-GroupPolicy' `
							, 'DSReplicationProvider' `
							, 'DFS Replication' `
							, 'File Replication Service' `
							, 'Netlogon' `
							, 'LSA' `
							, 'LsaSrv' `
							; StartTime = $begindate `
							; Level = 1, 2, 3 } -ea 0 | 
						? { `
							$_.ID -ne 5722 -And $_.ID -ne 5723 -And $_.ID -ne 5805 -And $_.ID -ne 5719 `
							# 5805 ERROR: http://www.microsoft.com/technet/support/ee/transform.aspx?ProdName=Windows+Operating+System&ProdVer=5.0&EvtID=5805&EvtSrc=NetLogon&LCID=1033
							# 5719 ERROR: http://www.microsoft.com/technet/support/ee/transform.aspx?ProdName=Windows+Operating+System&ProdVer=5.0&EvtID=5719&EvtSrc=NetLogon&LCID=1033
							# 5807 WARNING: http://www.microsoft.com/technet/support/ee/transform.aspx?ProdName=Windows+Operating+System&ProdVer=5.0&EvtID=5807&EvtSrc=NetLogon&LCID=1033
							} |
						sort TimeCreated |
						select LogName, TimeCreated, Id, ProviderName, LevelDisplayName, Message, $jnComputerName, $jnUTCMonitored, $jnServiceFlag

					if ($buf.Count -gt 0) {
						Write-Debug "$($env:COMPUTERNAME): $($buf.GetType()), $($buf.count)."
						return $buf
					}

				}
                        
				if ($buf.Count -gt 0) {
					$myresult += @($buf)
					Write-Debug "`$buf ($($_.Name)): $($buf.gettype()): $($buf.count)"
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

	$jnADDSEventResult | group ComputerName | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-Event -Data $jnADDSEventResult
if (gv jnADDSEventResult) {rv jnADDSEventResult}

# Get services.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADDSServiceResult = Invoke-Command -Session $session -script {
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
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADDS"}}

					Import-Module ActiveDirectory
					$mydom = Get-ADDomain
					$mymode = $mydom.DomainMode.ToString()

					$svcs = @("NTDS", "netlogon", "kdc", "DFSR", "ntfrs", "ISMSERV", "W32Time")
    				$svcs += @("Lanmanserver", "Lanmanworkstation", "Dnscache", "Dhcp", "RpcSs")
					$svcs | % {
						[array]$buf01 = Get-Service $_ -ea 0 | % {
							if ($_.Status -eq "Running") {
								$jnIsError = @{Name="IsError"; Expression={$False}}
								$_ | select Status, Name, DisplayName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag, $jnIsError
							}
							else {
								if ($_.Name -eq "ntfrs" -AND $mymode -notmatch "2000" -AND $mymode -notmatch "2003") {
									$jnIsError = @{Name="IsError"; Expression={$False}}
									$_ | select Status, Name, DisplayName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag, $jnIsError
								}
								else {
									$jnIsError = @{Name="IsError"; Expression={$True}}
									$_ | select Status, Name, DisplayName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag, $jnIsError
								}
							}
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

	$jnADDSServiceResult | group ComputerName | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-Service -Data $jnADDSServiceResult
if (gv jnADDSServiceResult) {rv jnADDSServiceResult}

# Get performance data.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	$jnADDSPerformanceDataResult = Invoke-Command -Session $session -script {
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

				$cntrsets = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					# Base Counter Sets
					$CounterSets = @("processor", "Memory", "Process", "PhysicalDisk")
					# AD DS Counter Sets
					$CounterSets += @("ADWS", "DirectoryServices", "DFS Replication Connections", "FileReplicaConn", "Netlogon", "NTDS")
					# AD CS Counter Sets
					#$CounterSets += @("Certification Authority*")
					# DNS Server Counter Sets
					#$CounterSets += @("*DNS*")
					# DHCP Server Counter Sets
					#$CounterSets += @("*dhcp*server*")

					Get-Counter -ListSet $CounterSets -ea 0 | sort CounterSetName
				}

				[array]$cntrs = $cntrsets | select -expand Paths | 
					? { `
						$_ -match "LDAP" `
					-or $_ -match "Kerberos" `
					-or $_ -match "NTLM" `
					-or $_ -match "LSASS" `
					-or $_ -eq "\Memory\Available MBytes" `
					-or $_ -eq "\Network Interface(*)\Output Queue Length" `
					-or $_ -match "LDAP Client Sessions" `
					-or $_ -match "LDAP Searches/sec" `
					-or $_ -match "LDAP UDP Operations/sec" `
					-or $_ -match "LDAP Writes/sec" `
					} | 
					sort

				# In addition, to add counters with given PathsWithInstances.

				$cntrs += @("\PhysicalDisk(_Total)\Avg. Disk Queue Length")
				$cntrs += @("\Processor(_Total)\% Processor Time")

				$processname = @("_Total")
				$processname += @("lsass", "dfsrs", "ntfrs", "ismserv", "Microsoft.ActiveDirectory.WebServices")
				#$processname += @("certsrv")
				#$processname += @("dns")
				#$processname += @("dhcpserver")

				$counterobjects = @("% Processor Time", "Private Bytes", "Handle Count")
				$counterobjects | % {
					foreach ($ps in $processname) {
						$cntrs += @("\Process($($ps))\$($_)")
					}
				}

				# Sample: (Get-Counter "\PhysicalDisk(*)\Avg. Disk Queue Length").countersamples | select *
				[array]$buf = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME)}}
					$jnCookedValue = @{Name="Value"; Expression={[math]::Round($_.CookedValue, 2)}}
					$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADDS"}}

					[array]$buf = (Get-Counter $args[0] -ea 0).CounterSamples | 
						select TimeStamp, TimeStamp100NSec, $jnCookedValue, Path, InstanceName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag
					if ($buf.Count -gt 0) {
						Write-Debug "$($env:COMPUTERNAME): $($buf.GetType()), $($buf.count)."
						return $buf
					}
				} -ArgumentList (,$cntrs)

				if ($buf.Count -gt 0) {
					$myresult += @($buf)
					Write-Debug "`$buf ($($_.Name)): $($buf.gettype()): $($buf.count)"
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

	$jnADDSPerformanceDataResult | group ComputerName | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-Performance -Data $jnADDSPerformanceDataResult
if (gv jnADDSPerformanceDataResult -ea 0) {rv jnADDSPerformanceDataResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADDSReplicationResult = Invoke-Command -Session $session -script {
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
					Import-Module ActiveDirectory
					$mydc = Get-ADDomainController -Identity $env:ComputerName
					$hash.ComputerName = $mydc.Name
					$hash.OperatingSystem = $mydc.OperatingSystem
					if ($mydc.OperatingSystemServicePack -eq $null) 
						{$hash.OperatingSystemServicePack = "0"}
					else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
					$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
					$hash.IsRODC = $mydc.IsReadOnly
					$hash.OperationMasterRoles = $mydc.OperationMasterRoles
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

<#					
					# REPADMIN /SYNCALL: Synchronizes a specified domain controller with all replication partners.
					# SYNTAX: repadmin /SyncAll [/adehijpPsS] <Dest DSA> [<Naming Context>]
					# /d: ID servers by DN in messages (instead of GUID DNS)
					# NOTE: If <Naming Context> is omitted DsReplicaSyncAll defaults to the Configuration NC.
					$buf_command = @(REPADMIN /syncall /d /q $mydc.Name | ? {$_ -ne $null -and $_ -ne ""})

					# REPADMIN /SHOWREPL: 
					$buf_command = @(REPADMIN /showrepl $env:COMPUTERNAME | ? {$_ -ne $null -and $_ -ne ""})
#>

					# REPADMIN /REPLSUMMARY: Display the replication status for all domain controllers in the forest to Identify domain controllers that are failing inbound replication or outbound replication, and summarizes the results in a report.
					# NOTE: /bysrc /bydest: displays the /bysrc parameter table first and the /bydest parameter table next. 
					$buf_command = @(REPADMIN /REPLSUMMARY $env:COMPUTERNAME /BYSRC /BYDEST /sort:delta | ? {$_ -ne $null -and $_ -ne ""})

					$hash.IsError = $False
					if (gv buf_str -ea 0) {rv buf_str}
					for ($I = 4; $I -lt $buf_command.count -2; $I++) {
						$buf_str = $buf_command[$I].TrimStart(" ")
						$buf_str = $buf_str.SubString($buf_str.IndexOf(":")+4)
						$buf_str = $buf_str.TrimStart(" ")
						$buf_str = $buf_str.Substring(0, $buf_str.IndexOf("/")-1)
						[INT32]$a = $buf_str
						if ($a -gt 0) {$hash.IsError = $True}
						}

					$hash.repadmin = $buf_command
						
					if ($hash.Count -gt 0)
						{return $hash}

				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($hash.ComputerName)): $($hash.gettype()): $($hash.count)"
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

	$jnADDSReplicationResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADReplication {
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
CREATE TABLE [dbo].[$($TableName)](`
[ComputerName] [nvarchar](50) NOT NULL,`
[repadmin] [nvarchar](100) NOT NULL,`
[OperatingSystem] [nvarchar](100) NULL,`
[OperatingSystemServicePack] [nvarchar](100) NULL,`
[IsGlobalCatalog] [nvarchar](10) NOT NULL,`
[IsRODC] [nvarchar](10) NOT NULL,`
[OperationMasterRoles] [nvarchar](max) NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[IsError] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL `
) `
ELSE` 
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
			 @ComputerName nvarchar(50) `
			,@repadmin nvarchar(100) `
			,@OperatingSystem nvarchar(100) `
			,@OperatingSystemServicePack nvarchar(100) `
			,@IsGlobalCatalog nvarchar(10) `
			,@IsRODC nvarchar(10) `
			,@OperationMasterRoles nvarchar(max) `
			,@UTCMonitored datetime`
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   ( [ComputerName] `
			,[repadmin] `
			,[OperatingSystem] `
			,[OperatingSystemServicePack] `
			,[IsGlobalCatalog] `
			,[IsRODC] `
			,[OperationMasterRoles] `
			,[UTCMonitored] `
			,[IsError] `
		   ) `
		 VALUES`
		   ( @ComputerName`
			,@repadmin`
			,@OperatingSystem`
			,@OperatingSystemServicePack`
			,@IsGlobalCatalog`
			,@IsRODC`
			,@OperationMasterRoles`
			,@UTCMonitored`
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
		
				for($k = 0;$k -lt $data[$i].repadmin.count;$k++) {$repadmin += $data[$i].repadmin[$k] + "<br/>"}
	
				$ProbScrp = "RepAdmin: " + $repadmin
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADDS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DS04")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
	
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
				$cmd.ExecuteNonQuery() | out-Null

				$cmd.Connection.Close()
				$rowcount += 1
			}
		}

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}
	}

}

try {
	$ErrorActionPreference = "Stop"

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_ADDSReplication"
	$ProcName = "IF_$($company)_ADDSReplication"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
    
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {
		
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$OPRoles = $null
			$repadmin = $null
		
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
        
			if ($data[$i].repadmin.count -eq 0)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@repadmin", "Null")}
			else {
			for($k = 0;$k -lt $data[$i].repadmin.count;$k++) {$repadmin += $data[$i].repadmin[$k] + "<br/>"}
			$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@repadmin", $repadmin)}
        
			if ($data[$i].OperatingSystem -eq $null -or $Data[$i].OperatingSystem -eq "")
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "")
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}	
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if ($data[$i].IsGlobalCatalog -eq $null)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
        
			if ($data[$i].IsRODC -eq $null)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}

			if ($data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}	
			else
			{for($j = 0;$j -lt $data[$i].OperationMasterRoles.count; $j++) {$OPRoles +=  $data[$i].OperationMasterRoles[$j].ToString() + "<br/>"}	
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)}
				
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())
                               
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
               
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()

		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-ADReplication -Data $jnADDSReplicationResult
if (gv jnADDSReplicationResult -ea 0) {rv jnADDSReplicationResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADDSSysvolSharesResult = Invoke-Command -Session $session -script {
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
					Import-Module ActiveDirectory
					$mydc = Get-ADDomainController -Identity $env:ComputerName
					$hash.ComputerName = $mydc.Name
					$hash.OperatingSystem = $mydc.OperatingSystem
					if ($mydc.OperatingSystemServicePack -eq $null) 
						{$hash.OperatingSystemServicePack = "0"}
					else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
					$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
					$hash.IsRODC = $mydc.IsReadOnly
					$hash.OperationMasterRoles = $mydc.OperationMasterRoles
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

					# Checks that the file replication system (FRS) system volume (SYSVOL) is ready.
					# NOTE: VerifyReferences checks that certain system references are intact for the FRS and replication infrastructure.
					$buf_command = @(dcdiag /test:frssysvol /test:VerifyReferences | ? {$_-ne $null -and $_ -ne ""})
					$hash.IsError = $False
					$buf_command | % {if (($_ -match "ERROR" -or $_ -match "FAIL") -and $_ -notmatch "NO ERROR") {$hash.IsError = $True} }
					$hash.frssysvol = $buf_command

					if ($hash.Count -gt 0)
						{return $hash}

				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($hash.ComputerName)): $($hash.gettype()): $($hash.count)"
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

	$jnADDSSysvolSharesResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADDSSysvolShares {
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
[ComputerName] [nvarchar](50) NOT NULL,`
[frssysvol]	[nvarchar](max)	NOT NULL,`
[OperatingSystem] [nvarchar](100) NULL,`
[OperatingSystemServicePack] [nvarchar](100) NULL,`
[IsGlobalCatalog] [nvarchar](10) NOT NULL,`
[IsRODC] [nvarchar](10) NOT NULL,`
[OperationMasterRoles] [nvarchar](max) NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[IsError] [nvarchar](10)NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar] (20)NULL,`
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
				@ComputerName nvarchar(50) `
			,@frssysvol nvarchar(max) `
			,@OperatingSystem nvarchar(100) `
			,@OperatingSystemServicePack nvarchar(100) `
			,@IsGlobalCatalog nvarchar(10) `
			,@IsRODC nvarchar(10) `
			,@OperationMasterRoles nvarchar(max) `
			,@UTCMonitored datetime`
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
	`
	INSERT INTO [dbo].[$($TableName)] `
			( [ComputerName] `
			,[frssysvol] `
			,[OperatingSystem] `
			,[OperatingSystemServicePack] `
			,[IsGlobalCatalog] `
			,[IsRODC] `
			,[OperationMasterRoles] `
			,[UTCMonitored] `
			,[IsError] `
			) `
			VALUES`
			( @ComputerName`
			,@frssysvol`
			,@OperatingSystem`
			,@OperatingSystemServicePack`
			,@IsGlobalCatalog`
			,@IsRODC`
			,@OperationMasterRoles`
			,@UTCMonitored`
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
		
				for($j = 0;$j -lt $Data[$i].frssysvol.count;$j++) {$frssysvol += $Data[$i].frssysvol[$j] + "<br/>"}
			
				$ProbScrp = "frssysvol: " + $frssysvol
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADDS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DS05")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
	
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
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
	$TableName = "TB_$($company)_ADDSSysvolShares"
	$ProcName = "IF_$($company)_ADDSSysvolShares"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {
			
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
			$frssysvol = $null
			$OPRoles = $null

			if ($Data[$i].ComputerName -eq $null -or $Data[$i].ComputerName -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
		
			if ($Data[$i].frssysvol.count -eq 0)
			{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@frssysvol", "Null")}
			else {for($j = 0;$j -lt $Data[$i].frssysvol.count;$j++) {$frssysvol += $Data[$i].frssysvol[$j] + "<br/>"}
			$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@frssysvol", $frssysvol)}

			if ($Data[$i].OperatingSystem -eq $null -or $Data[$i].OperatingSystem -eq "")
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}	
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "")
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if ($data[$i].IsGlobalCatalog -eq $null)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
		
			if ($data[$i].IsRODC -eq $null)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}
			if ($data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
			for($k = 0;$k -lt $Data[$i].OperationMasterRoles.count;$k++) {$OPRoles += $Data[$i].OperationMasterRoles[$k].ToString() + "<br/>"}	
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)}
		
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())
                         
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
               
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			
		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-ADDSSysvolShares -Data $jnADDSSysvolSharesResult
if (gv jnADDSSysvolSharesResult -ea 0) {rv jnADDSSysvolSharesResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	$jnADDSTopologyAndIntersiteMessagingResult = Invoke-Command -Session $session -script {
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
					Import-Module ActiveDirectory
					$mydc = Get-ADDomainController -Identity $env:ComputerName
					$hash.ComputerName = $mydc.Name
					$hash.OperatingSystem = $mydc.OperatingSystem
					if ($mydc.OperatingSystemServicePack -eq $null) 
						{$hash.OperatingSystemServicePack = "0"}
					else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}

					$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
					$hash.IsRODC = $mydc.IsReadOnly
					$hash.OperationMasterRoles = $mydc.OperationMasterRoles

					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

					# Topology: Checks that the KCC has generated a fully connected topology for all domain controllers.
					# Intersite Messaging: Checks for failures that would prevent or temporarily hold up intersite replication and predicts how long it would take for the Knowledge Consistency Checker (KCC) to recover.
					$buf_command = @(dcdiag /test:Topology /test:Intersite | ? {$_-ne $null -and $_ -ne ""})
					$hash.IsError = $False
					$buf_command | % {if (($_ -match "ERROR" -or $_ -match "FAIL") -and $_ -notmatch "NO ERROR") {$hash.IsError = $True} }
					$hash.adtopology = $buf_command

					if ($hash.Count -gt 0)
						{return $hash}

				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($hash.ComputerName)): $($hash.gettype()): $($hash.count)"
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

	$jnADDSTopologyAndIntersiteMessagingResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADDSTopology {
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
[ComputerName] [nvarchar](50) NOT NULL,`
[adtopology] [nvarchar](max) NOT NULL,`
[OperatingSystem] [nvarchar](100) NOT NULL,`
[OperatingSystemServicePack] [nvarchar](100) NOT NULL,`
[IsGlobalCatalog] [nvarchar](10) NOT NULL,`
[IsRODC] [nvarchar](10) NOT NULL,`
[OperationMasterRoles] [nvarchar](max) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
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
			 @ComputerName nvarchar(50) `
			,@adtopology nvarchar(max) `
			,@OperatingSystem nvarchar(100) `
			,@OperatingSystemServicePack nvarchar(100) `
			,@IsGlobalCatalog nvarchar(10) `
			,@IsRODC nvarchar(10) `
			,@OperationMasterRoles nvarchar(max) `
			,@UTCMonitored datetime`
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   ( [ComputerName] `
	        ,[adtopology] `
			,[OperatingSystem] `
			,[OperatingSystemServicePack] `
			,[IsGlobalCatalog] `
			,[IsRODC] `
			,[OperationMasterRoles] `
			,[UTCMonitored] `
			,[IsError] `
		   ) `
		 VALUES`
		   ( @ComputerName`	
			,@adtopology`
			,@OperatingSystem`
			,@OperatingSystemServicePack`
			,@IsGlobalCatalog`
			,@IsRODC`
			,@OperationMasterRoles`
			,@UTCMonitored`
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
		
				for($j = 0;$j -lt $data[$i].adtopology.count;$j++) {$adtopology += $data[$i].adtopology[$j] + "<br/>"}	
		
				$ProbScrp = "ADTopology: " + $adtopology
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADDS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DS06")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
	
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
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
	$TableName = "TB_$($company)_ADDSTopology"
	$ProcName = "IF_$($company)_ADDSTopology"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
     
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$adtopology = $null
			$OperationMasterRoles = $null
		
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}

			if ($data[$i].adtopology.count -eq 0) {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@adtopology", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].adtopology.count;$j++) {$adtopology += $data[$i].adtopology[$j] + "<br/>"}
			$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@adtopology", $adtopology)}
		
			if ($Data[$i].OperatingSystem -eq $null -or $Data[$i].OperatingSystem -eq "")
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}	
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "")
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if ($data[$i].IsGlobalCatalog -eq $null)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
		
			if ($data[$i].IsRODC -eq $null)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}
		
			if ($data[$i].OperationMasterRoles.count -eq 0) {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].OperationMasterRoles.count;$j++) {
				$OperationMasterRoles += $data[$i].OperationMasterRoles[$j].ToString() + "<br/>"}
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OperationMasterRoles)}
		
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())
	    
			
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
                       
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			
		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-ADDSTopology -Data $jnADDSTopologyAndIntersiteMessagingResult
if (gv jnADDSTopologyAndIntersiteMessagingResult -ea 0) {rv jnADDSTopologyAndIntersiteMessagingResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADDSRepositoryResult = Invoke-Command -Session $session -script {
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
					Import-Module ActiveDirectory
					$mydc = Get-ADDomainController -Identity $env:ComputerName
					$hash.ComputerName = $mydc.Name
					$hash.OperatingSystem = $mydc.OperatingSystem
					if ($mydc.OperatingSystemServicePack -eq $null) 
						{$hash.OperatingSystemServicePack = "0"}
					else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
					$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
					$hash.IsRODC = $mydc.IsReadOnly
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

					$path = "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\NTDS\Parameters"
					$name = "DSA Database file"
					$hash.DataBasePath = gi $path | gp | select -expand $name
					$DBPath = $hash.DataBasePath
					$DBSize = Get-Item $DBPath | Select -expand Length
					$hash.DataBaseSize = ([math]::Round($DBSize/1gb, 2)).tostring() + "GB"
                   
					$DBDriveFreeSpace = gwmi Win32_LogicalDisk | ? {$_.DeviceID -eq $DBPath.SubString(0, 2)} | select -expand freespace
					$DBDriveFreeSpaceGB = [math]::Round($DBDriveFreeSpace / 1GB, 2)
					if ($DBDriveFreeSpaceGB -le 1) {$hash.IsError = $True} else {$hash.IsError = $False}
					$hash.DatabaseDriveFreeSpace = $DBDriveFreeSpaceGB.tostring() + "GB"

					$name = "Database log files path"
					$hash.LogFilePath = gi $path | gp | select -expand $name
					$LogPath = $hash.LogFilePath
					$LogPathSize = Get-ChildItem $LogPath -Exclude "ntds.dit" | Measure-Object -Property length -Sum | Select -expand Sum 
					$hash.LogFileSize = ([math]::Round($LogPathSize/1gb, 2)).tostring() + "GB"

					$path = "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Netlogon\Parameters"
					$name = "SysVol"
					$hash.SysvolPath = gi $path | gp | select -expand $name

					if ($hash.Count -gt 0) 
						{return $hash}

				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($hash.ComputerName)): $($hash.gettype()): $($hash.count)"
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

	$jnADDSRepositoryResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADDSRepository {
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
[ComputerName] [nvarchar](50) NOT NULL,`
[SysvolPath] [nvarchar](200) NOT NULL,`
[LogFileSize] [nvarchar](20) NOT NULL,`
[IsGlobalCatalog] [nvarchar](20) NULL,`
[DataBaseSize] [nvarchar](200) NOT NULL,`
[IsRODC] [nvarchar](20) NULL,`
[LogFilePath] [nvarchar](200) NOT NULL,`
[DataBasePath] [nvarchar](200) NOT NULL,`
[DatabaseDriveFreeSpace] [nvarchar](50) NOT NULL,`
[OperatingSystemServicePack] [nvarchar](50) NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[OperatingSystem] [nvarchar](200) NULL,`
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
				@ComputerName nvarchar(50) `
			,@SysvolPath nvarchar(200) `
			,@LogFileSize nvarchar(20) `
			,@IsGlobalCatalog nvarchar(20) `
			,@DataBaseSize nvarchar(200) `
			,@IsRODC nvarchar(20) `
			,@LogFilePath nvarchar(200) `
			,@DataBasePath nvarchar(200) `
			,@DatabaseDriveFreeSpace nvarchar(50) `
			,@OperatingSystemServicePack nvarchar(50) `
			,@UTCMonitored datetime`
			,@OperatingSystem nvarchar(200) `
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
	`
	INSERT INTO [dbo].[$($TableName)] `
			(  [ComputerName] `
				,[SysvolPath] `
				,[LogFileSize] `
				,[IsGlobalCatalog] `
				,[DataBaseSize] `
				,[IsRODC] `
				,[LogFilePath] `
				,[DataBasePath] `
				,[DatabaseDriveFreeSpace] `
				,[OperatingSystemServicePack] `
				,[UTCMonitored] `
				,[OperatingSystem] `
				,[IsError] `
			) `
			VALUES`
			( @ComputerName`
			,@SysvolPath`
			,@LogFileSize`
			,@IsGlobalCatalog`
			,@DataBaseSize`
			,@IsRODC`
			,@LogFilePath`
			,@DataBasePath`
			,@DatabaseDriveFreeSpace`
			,@OperatingSystemServicePack`
			,@UTCMonitored`
			,@OperatingSystem`
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
		
				$ProbScrp = "DatabaseDriveFreeSpace: " + $data[$i].DatabaseDriveFreeSpace
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADDS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DS07")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
	
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
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
	$TableName = "TB_$($company)_ADDSRepository"
	$ProcName = "IF_$($company)_ADDSRepository"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {
 
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
			
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
		
			if ($data[$i].SysvolPath -eq $null -or $data[$i].SysvolPath -eq "")
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@SysvolPath", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@SysvolPath", $data[$i].SysvolPath)}
		
			if ($data[$i].LogFileSize -eq $null -or $data[$i].LogFileSize -eq "")
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@LogFileSize", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@LogFileSize", $data[$i].LogFileSize)}

			if ($data[$i].IsGlobalCatalog -eq $null)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
		
			if ($data[$i].DataBaseSize -eq $null -or $data[$i].DataBaseSize -eq "")
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DataBaseSize", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DataBaseSize", $data[$i].DataBaseSize)}

			if ($data[$i].IsRODC -eq $null)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}

			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@LogFilePath", $data[$i].LogFilePath)
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@DataBasePath", $data[$i].DataBasePath)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseDriveFreeSpace", $data[$i].DatabaseDriveFreeSpace)
			
			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "")
				{$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
			
			$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			
			if ($data[$i].OperatingSystem -eq $null -or $data[$i].OperatingSystem -eq "")
				{$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
			
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
		       
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()

		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-ADDSRepository -Data $jnADDSRepositoryResult
if (gv jnADDSRepositoryResult -ea 0) {rv jnADDSRepositoryResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	$jnADDSAdvertisementResult = Invoke-Command -Session $session -script {
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
					Import-Module ActiveDirectory
					$mydc = Get-ADDomainController -Identity $env:ComputerName
					$hash.ComputerName = $mydc.Name
					$hash.OperatingSystem = $mydc.OperatingSystem
					if ($mydc.OperatingSystemServicePack -eq $null) 
						{$hash.OperatingSystemServicePack = "0"}
					else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
					$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
					$hash.IsRODC = $mydc.IsReadOnly
					$hash.OperationMasterRoles = $mydc.OperationMasterRoles
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

					# DC Advertisement: Checks whether each domain controller advertises itself in the roles that it should be capable of performing. This test fails if the Netlogon Service has stopped or failed to start.
					$buf_command = @(dcdiag /test:Advertising | ? {$_-ne $null -and $_ -ne ""})
					$hash.IsError = $False
					$buf_command | % {if (($_ -match "ERROR" -or $_ -match "FAIL") -and $_ -notmatch "NO ERROR") {$hash.IsError = $True} }
					$hash.dcdiag_advertising = $buf_command

					if ($hash.Count -gt 0)
						{return $hash}

				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($hash.ComputerName)): $($hash.gettype()): $($hash.count)"
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

	$jnADDSAdvertisementResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADDSAdvertisement {
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
[ComputerName] [nvarchar](50) NOT NULL,`
[IsGlobalCatalog] [nvarchar](10) NULL,`
[IsRODC] [nvarchar](10) NULL,`
[OperationMasterRoles] [nvarchar](max) NULL,`
[OperatingSystemServicePack] [nvarchar](30) NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[OperatingSystem] [nvarchar](50) NULL,`
[dcdiag_advertising] [nvarchar](max) NOT NULL,`
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
			 @ComputerName nvarchar(50) `
		    ,@IsGlobalCatalog nvarchar(10) `
			,@IsRODC nvarchar(10) `
			,@OperationMasterRoles nvarchar(max) `
			,@OperatingSystemServicePack nvarchar(30) `
			,@UTCMonitored datetime`
			,@OperatingSystem nvarchar(50) `
		    ,@dcdiag_advertising nvarchar(max) `
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
 `

	INSERT INTO [dbo].[$($TableName)] `
		   ( [ComputerName] ` 
		    ,[IsGlobalCatalog] ` 
			,[IsRODC] `
			,[OperationMasterRoles] `
			,[OperatingSystemServicePack] `
			,[UTCMonitored] `
			,[OperatingSystem] `
		    ,[dcdiag_advertising]
			,[IsError]
			) `
		 VALUES`
		   ( @ComputerName` 
		    ,@IsGlobalCatalog` 
			,@IsRODC`
			,@OperationMasterRoles`
			,@OperatingSystemServicePack`
			,@UTCMonitored`
			,@OperatingSystem`
		    ,@dcdiag_advertising`
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
	
	$insertproblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError -eq $true) {

				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertproblem
		
				for($j = 0;$j -lt $Data[$i].dcdiag_advertising.count; $j++) {$advertising += $Data[$i].dcdiag_advertising[$j] + "<br/>"}

				$ProbScrp = "dcdiag_advertising: " + $advertising
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADDS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DS08")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
	
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
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
	$TableName = "TB_$($company)_ADDSAdvertisement"
	$ProcName = "IF_$($company)_ADDSAdvertisement"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
    
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	Write-Debug "[SQL] Started to insert."

	if ($Data.count -gt 0) {

		for($i  =  0;$i -lt $data.count;$i++) {

			if ($Data.count -eq 0) {continue}
 
			$temp = $null
			$OPRoles = $null
	
			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
        
			if ($data[$i].IsGlobalCatalog -eq $null)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
        
			if ($data[$i].IsRODC -eq $null)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}
        
			If ($Data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
			for($k = 0;$k -lt $Data[$i].OperationMasterRoles.count; $k++) {
				$OPRoles +=  $Data[$i].OperationMasterRoles[$k].Tostring() + "<br/>"}	
			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)}
		
			if ($Data[$i].OperatingSystemServicePack -eq $null -or $Data[$i].OperatingSystemServicePack -eq "")
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $Data[$i].OperatingSystemServicePack)}

			$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $Data[$i].jnUTCMonitored)

			if ($Data[$i].OperatingSystem -eq $null -or $Data[$i].OperatingSystem -eq "")
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $Data[$i].OperatingSystem)}

			if ($Data[$i].dcdiag_advertising.count -eq 0)
				{$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@dcdiag_advertising", "Null")}
			else {
			for($j = 0;$j -lt $Data[$i].dcdiag_advertising.count; $j++) {   
			$advertising += $Data[$i].dcdiag_advertising[$j] + "<br/>"}
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@dcdiag_advertising", $advertising)}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $Data[$i].IsError.ToString())
                
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
       
			$cmd.ExecuteNonQuery() | out-Null
			$cmd.Connection.Close()

		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-ADDSAdvertisement -Data $jnADDSAdvertisementResult
if (gv jnADDSAdvertisementResult -ea 0) {rv jnADDSAdvertisementResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADDSW32TimeSyncResult = Invoke-Command -Session $session -script {
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
					Import-Module ActiveDirectory
					$mydc = Get-ADDomainController -Identity $env:ComputerName
					$hash.ComputerName = $mydc.Name
					$hash.OperatingSystem = $mydc.OperatingSystem
					if ($mydc.OperatingSystemServicePack -eq $null) 
						{$hash.OperatingSystemServicePack = "0"}
					else {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
					$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
					$hash.IsRODC = $mydc.IsReadOnly
					$hash.OperationMasterRoles = $mydc.OperationMasterRoles
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

					# w32tm /query: Display a computer's windows time service information.
					$timelastsynced = @(w32tm /query /status | select-string "Last Successful Sync Time: ", "Source: ")
					$buf_LastSuccessfulSyncedTime = $timelastsynced[0].tostring().TrimStart("Last Successful Sync Time: ")
					$buf_TimeSource = $timelastsynced[1].ToString().TrimStart("Source: ")

					if ($buf_LastSuccessfulSyncedTime -eq $null -or $buf_LastSuccessfulSyncedTime -eq "") {
						$hash.LastSuccessfulSyncedTime = $null
						$hash.TimeSource = $null
						$hash.IsError = $True
					} # End of If it has never synced the time successfully.
					else {
						$hash.LastSuccessfulSyncedTime = $buf_LastSuccessfulSyncedTime
						$hash.TimeSource = $buf_TimeSource
						$hash.IsError = $False
					} # End of If it has at least synced the time successfully.
			
					if ($hash.Count -gt 0) 
						{return $hash}

				}

				if ($hash.Count -gt 0) {
					$myresult += @($hash)
					Write-Debug "`$hash ($($hash.ComputerName)): $($hash.gettype()): $($hash.count)"
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

	$jnADDSW32TimeSyncResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADDSW32TimeSync {
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
[ComputerName] [nvarchar](50) NOT NULL,`
[LastSuccessfulSyncedTime] [nvarchar](50) NOT NULL,`
[TimeSource] [nvarchar](50) NOT NULL,`
[IsGlobalCatalog] [nvarchar](20) NOT NULL,`
[IsRODC] [nvarchar](20) NOT NULL,`
[OperationMasterRoles] [nvarchar](max) NOT NULL,`
[OperatingSystemServicePack] [nvarchar](50) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[OperatingSystem] [nvarchar](200) NOT NULL,`
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
			 @ComputerName nvarchar(50) `
			,@LastSuccessfulSyncedTime nvarchar(50) `
			,@TimeSource nvarchar(50) `
			,@IsGlobalCatalog nvarchar(20) `
			,@IsRODC nvarchar(20) `
			,@OperationMasterRoles nvarchar(max) `
			,@OperatingSystemServicePack nvarchar(50) `
			,@UTCMonitored datetime`
	        ,@OperatingSystem nvarchar(200) `
			,@IsError [nvarchar](10) `
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   (  [ComputerName],`
			  [LastSuccessfulSyncedTime],`
			  [TimeSource],`
			  [IsGlobalCatalog],`
			  [IsRODC],`
			  [OperationMasterRoles],`
			  [OperatingSystemServicePack],`
			  [UTCMonitored],`
		   	  [OperatingSystem],`
			  [IsError] `
		   ) `
		 VALUES`
		   ( @ComputerName`
			,@LastSuccessfulSyncedTime`
			,@TimeSource`
			,@IsGlobalCatalog`
			,@IsRODC`
			,@OperationMasterRoles`
			,@OperatingSystemServicePack`
			,@UTCMonitored`
	        ,@OperatingSystem`
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
	
	$insertproblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError -eq $true) {

				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertproblem
		
				$ProbScrp = "dcdiag_advertising: " + $data[$i].LastSuccessfulSyncedTime + "<br/>TimeSource: " + $data[$i].TimeSource
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADDS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "DS09")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
	
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
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
	$TableName = "TB_$($company)_ADDSW32TimeSync"
	$ProcName = "IF_$($company)_ADDSW32TimeSync"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {
 
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
			$OPRoles = $null
		
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "")
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}

			if ($data[$i].LastSuccessfulSyncedTime -eq $null -or $data[$i].LastSuccessfulSyncedTime -eq "")
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@LastSuccessfulSyncedTime", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@LastSuccessfulSyncedTime", $data[$i].LastSuccessfulSyncedTime)}
		
			if ($data[$i].TimeSource -eq $null -or $data[$i].TimeSource -eq "")
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@TimeSource", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@TimeSource", $data[$i].TimeSource)}
		
			if ($data[$i].IsGlobalCatalog -eq $null)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
        
			if ($data[$i].IsRODC -eq $null)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}

			if ($data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
				for($j = 0;$j -lt $data[$i].OperationMasterRoles.count;$j++) {
					$OPRoles += $Data[$i].OperationMasterRoles[$j].Tostring() + "<br/>"
				}
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)	
			}
	
			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "")				
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		
			if ($data[$i].OperatingSystem -eq $null -or $data[$i].OperatingSystem -eq "")
				{$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
		
			$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())

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
	       
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()

		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

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
Insert-ADDSW32TimeSync -Data $jnADDSW32TimeSyncResult
if (gv jnADDSW32TimeSyncResult -ea 0) {rv jnADDSW32TimeSyncResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService ADDS -jnUTCMonitored $jnUTCMonitored

