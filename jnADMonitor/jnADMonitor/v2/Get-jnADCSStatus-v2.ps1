param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Get-jnADCSStatus-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

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
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService ADCS -jnUTCMonitored $jnUTCMonitored

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
[array]$servers = Get-jnSQLData -TableName $TableName -ServiceFlag 'ADCS'

if ($servers.Count -gt 0) {
	Write-Host "[SQL] Servers Retrieved: $($servers.Count)."
}
else {
	$Message = "[SQL] No Servers Retrieved."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

	$jnADCSEventResult = Invoke-Command -Session $session -script {
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
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADCS"}}
					$begindate = (Get-Date).AddHours(-1*24)

					[array]$buf = Get-WinEvent -FilterHashTable @{ `
						ProviderName = `
							'Microsoft-Windows-CertificationAuthority', `
							'Microsoft-Windows-CertificationAuthorityClient-CertCli', `
							'Microsoft-Windows-CertificationAuthority-EnterprisePolicy', `
							'Microsoft-Windows-CertPolEng' `
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

	$jnADCSEventResult | group ComputerName | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_EVENT"
	$ProcName = "IF_$($company)_EVENT"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
   
	#Sql Command definition
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 
	$rowcount = 0

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
			$rowcount += 1

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
if ($jnADCSEventResult.Count -gt 0)	{Insert-Event -Data $jnADCSEventResult}
if (gv jnADCSEventResult -ea 0) {rv jnADCSEventResult}

# Get services.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADCSServiceResult = Invoke-Command -Session $session -script {
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
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADCS"}}

    				$svcs = @("CertSvc")
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

	$jnADCSServiceResult | group computername | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_SERVICE"
	$ProcName = "IF_$($company)_SERVICE"

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
  
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0
	
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
			$rowcount +=  1
		}

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
Insert-Service -Data $jnADCSServiceResult
if (gv jnADCSServiceResult -ea 0) {rv jnADCSServiceResult}

# Get performance data.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	$jnADCSPerformanceDataResult = Invoke-Command -Session $session -script {
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
					$CounterSets += @("Certification Authority*")
					# DNS Server Counter Sets
					#$CounterSets += @("*DNS*")
					# DHCP Server Counter Sets
					#$CounterSets += @("*dhcp*server*")

					Get-Counter -ListSet $CounterSets -ea 0 | sort CounterSetName

				}

				[array]$cntrs = $cntrsets | select -expand Paths | 
					? { `
							$_ -eq "\Memory\Available MBytes" `
						-or $_ -eq "\PhysicalDisk(*)\Avg. Disk Queue Length" `
						-or $_ -eq "\Network Interface(*)\Output Queue Length" `
					} | 
					sort

				# In addition, to add counters with given PathsWithInstances.

				$cntrs += @("\PhysicalDisk(_Total)\Avg. Disk Queue Length")
				$cntrs += @("\Processor(_Total)\% Processor Time")

				$processname = @("_Total")
				#$processname += @("lsass", "dfsrs", "ntfrs", "ismserv", "Microsoft.ActiveDirectory.WebServices")
				$processname += @("certsrv")
				#$processname += @("dns")
				#$processname += @("dhcpserver")

				$counterobjects = @("% Processor Time", "Private Bytes", "Handle Count")
				$counterobjects | % {
					foreach ($ps in $processname) {
						$cntrs += @("\Process($($ps))\$($_)")
					}
				}

				$cntrs += @("\Certification Authority Connections(_Total)\Active connections")

				$processname = @("_Total")
				#$processname += @("Administrator", "DirectoryEmailReplication", "DomainController", "DomainControllerAuthentication", "LGECodeSigning", "LGElectronicsInc.HPPrinter", "LGElectronicsInc.User", "LGElectronicsInc.WebServer", "Machine", "OCSPResponseSigningLGE", "SubCA", "User", "WebServer")
				$counterobjects = @("Failed Requests/sec", "Issued Requests/sec", "Pending Requests/sec", "Requests/sec")
				$counterobjects | % {
					foreach ($ps in $processname) {
						$cntrs += @("\Certification Authority($($ps))\$($_)")
					}
				}

				# Sample: (Get-Counter "\PhysicalDisk(*)\Avg. Disk Queue Length").countersamples | select *
				[array]$buf = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME)}}
					$jnCookedValue = @{Name="Value"; Expression={[math]::Round($_.CookedValue, 2)}}
					$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADCS"}}

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

	$jnADCSPerformanceDataResult | group computername | sort Count

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_PERFORMANCE"
	$ProcName = "IF_$($company)_PERFORMANCE"

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 
	$rowcount = 0

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
			$rowcount +=  1
		}

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
Insert-Performance -Data $jnADCSPerformanceDataResult
if (gv jnADCSPerformanceDataResult -ea 0) {rv jnADCSPerformanceDataResult}

# Get service availability.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADCSServiceAvailabilityResult = Invoke-Command -Session $session -script {
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
					$OS = gwmi Win32_OperatingSystem
					$hash.OperatingSystem = $OS.Caption
					$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
					$hash.IsError = $False
						
<#
certutil -CAInfo name
========
CA name: dotnetsoft-DNPROD01-CA
CertUtil: -CAInfo command completed successfully.

certutil -CAInfo dns
========
DNS Name: DNPROD01.dotnetsoft.co.kr
CertUtil: -CAInfo command completed successfully.

certutil -CAInfo type
========
CA type: 0 -- Enterprise Root CA
	ENUM_ENTERPRISE_ROOTCA -- 0
CertUtil: -CAInfo command completed successfully.

certutil -ping
========
Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...
Server "dotnetsoft-DNPROD01-CA" ICertRequest2 interface is alive (0ms)
CertUtil: -ping command completed successfully.

certutil -pingadmin
========
Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...
Server ICertAdmin2 interface is alive
CertUtil: -pingadmin command completed successfully.

certutil -CAInfo crlstatus 0
========
CRL Publish Status[0]: 5
	CPF_BASE -- 1
	CPF_COMPLETE -- 4
CertUtil: -CAInfo command completed successfully.

certutil -CAInfo deltacrlstatus 0
========
Delta CRL Publish Status[0]: 6
	CPF_DELTA -- 2
	CPF_COMPLETE -- 4
CertUtil: -CAInfo command completed successfully.

ERROR
==========
CertUtil: -CAInfo command FAILED: 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE)
CertUtil: The RPC server is unavailable.
#>
					# CERTUTIL -CAINFO CAName: Display CA Information: CA Name
					$buf_error = $False
					$buf = certutil -CAInfo name
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.CAName += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -match "CA Name") {$hash.CAName = $_.Substring($_.IndexOf("CA Name")+7+1+2)}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CAName: $($hash.CAName)"

					# CERTUTIL -CAINFO DNSName: Display CA Information: DNS Name
					$buf_error = $False
					$buf = certutil -CAInfo dns
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.DNSName += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -match "DNS Name") {$hash.DNSName = $_.Substring($_.IndexOf("Dns Name")+8+1+2)}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.DNSName: $($hash.DNSName)"

					# CERTUTIL -CAINFO CAType: Display CA Information: CA Type
					# ENUM_CATYPES enumeration, http://msdn.microsoft.com/en-us/library/windows/desktop/bb648652(v=vs.85).aspx
					$buf_error = $False
					$buf = certutil -CAInfo type
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.CAType += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {
							if ($_ -match "CA Type")
								{$hash.CAType = $_.Substring($_.IndexOf("CA type")+7+2)}
						}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CAType: $($hash.CAType)"

					# Attempt to contact the Active Directory Certificate Services Request interface
					$buf_error = $False
					$buf = certutil -ping
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.ping += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -notmatch "Certutil: ") {$hash.ping += @($_.TrimStart(" "))}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.ping: $($hash.ping)"

					# Attempt to contact the Active Directory Certificate Services Admin interface
					$buf_error = $False
					$buf = certutil -pingadmin
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.pingadmin += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -notmatch "Certutil: ") {$hash.pingadmin += @($_.TrimStart(" "))}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.pingadmin: $($hash.pingadmin)"

					# CRL Publish Status
					$buf_error = $False
					$buf = certutil -CAInfo crlstatus 0
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.CrlPublishStatus += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -notmatch "Certutil: ") {$hash.CrlPublishStatus += @($_.TrimStart(" "))}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CrlPublishStatus: $($hash.CrlPublishStatus)"

					# Delta CRL Publish Status
					$buf_error = $False
					$buf = certutil -CAInfo deltacrlstatus 0
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.DeltaCrlPublishStatus += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -notmatch "Certutil: ") {$hash.DeltaCrlPublishStatus += @($_.TrimStart(" "))}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.DeltaCrlPublishStatus: $($hash.DeltaCrlPublishStatus)"

					if ($hash.Count -gt 0) 
						{return $hash}

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

	$jnADCSServiceAvailabilityResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADCSServiceAvailability {
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
[OperatingSystem] [nvarchar](100) NULL,`
[OperatingSystemServicePack] [nvarchar](100) NULL,`
[CAName] [nvarchar](30) NOT NULL,`
[DNSName] [nvarchar](30) NOT NULL,`
[CAType] [nvarchar](200) NOT NULL,`
[PingAdmin] [nvarchar](200) NOT NULL,`
[Ping] [nvarchar](200) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[CrlPublishStatus] [nvarchar](MAX) NOT NULL,`
[DeltaCrlPublishStatus] [nvarchar](MAX) NOT NULL,`
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
			,@OperatingSystem nvarchar(100) `
			,@OperatingSystemServicePack nvarchar(100) `
			,@CAName nvarchar(30) `
			,@DNSName nvarchar(30) ` 
			,@CAType nvarchar(200) `
			,@PingAdmin nvarchar(200) `
			,@Ping nvarchar(200) `
			,@UTCMonitored datetime`	
			,@CrlPublishStatus nvarchar(MAX) `
			,@DeltaCrlPublishStatus nvarchar(MAX) `
			,@IsError nvarchar(10)        
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   (  [ComputerName],`
			  [OperatingSystem],`
			  [OperatingSystemServicePack],`
			  [CAName],`
			  [DNSName],`
			  [CAType],`
			  [PingAdmin],`
			  [Ping],`
			  [UTCMonitored],`
			  [CrlPublishStatus],`
			  [DeltaCrlPublishStatus],`
			  [IsError] `
		   ) `
		 VALUES`
		   (  @ComputerName,`
			  @OperatingSystem,`
			  @OperatingSystemServicePack,`
			  @CAName,`
			  @DNSName,`
			  @CAType,`
			  @PingAdmin,`
			  @Ping,`
			  @UTCMonitored,`
			  @CrlPublishStatus,`
			  @DeltaCrlPublishStatus,`
			  @IsError`
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
		
				for($k = 0;$k -lt $data[$i].PingAdmin.count;$k++) {$PingAdmin += $data[$i].PingAdmin[$k] + "<br/>"}
				for($j = 0;$j -lt $data[$i].Ping.count;$j++) {$Ping += $data[$i].Ping[$j] + "<br/>"}
				for($l = 0;$l -lt $data[$i].CrlPublishStatus.count;$l++) {$CrlPublishStatus += $data[$i].CrlPublishStatus[$l] + "<br/>"}
				for($m = 0;$m -lt $data[$i].DeltaCrlPublishStatus.count;$m++) {$DeltaCrlPublishStatus += $data[$i].DeltaCrlPublishStatus[$m] + "<br/>"}
		
				$ProbScrp = "CAName: " + $data[$i].CAName + "<br/>DNSName: " + $data[$i].DNSName + "<br/>CAType: " + $data[$i].CAType + "<br/>PingAdmin: " + $PingAdmin + "<br/>Ping: " + $Ping + "<br/>CrlPublishStatus: " + $CrlPublishStatus + "<br/>DeltaCrlPublishStatus: " + $DeltaCrlPublishStatus
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADCS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "CS04")
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
		} # End of for.

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}

	} # End of function.

}

try {

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_ADCSServiceAvailability"
	$ProcName = "IF_$($company)_ADCSServiceAvailability"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {
 
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
	
			$PingAdmin, $PingAdmin, $CrlPublishStatus, $DeltaCrlPublishStatus = $null
	
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "") 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
       
			if ($data[$i].OperatingSystem -eq $null -or $data[$i].OperatingSystem -eq "") 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
		
			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "") 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if ($data[$i].CAName -eq $null -or $data[$i].CAName -eq "") 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", $data[$i].CAName)}
		
			if ($data[$i].DNSName -eq $null -or $data[$i].DNSName -eq "") 
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", $data[$i].DNSName)}
		
			if ($data[$i].CAType -eq $null -or $data[$i].CAType -eq "") 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", $data[$i].CAType)}	
		
			if ($data[$i].PingAdmin.count -eq 0) {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", "Null")}
			else {
			for($k = 0;$k -lt $data[$i].PingAdmin.count;$k++) {$PingAdmin += $data[$i].PingAdmin[$k] + "<br/>"}
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", $PingAdmin)}
		
			if ($data[$i].Ping.count -eq 0) {$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].Ping.count;$j++) {$Ping += $data[$i].Ping[$j] + "<br/>"}
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", $Ping)}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		
			if ($data[$i].CrlPublishStatus.count -eq 0) {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", "Null")}
			else {
				for($l = 0;$l -lt $data[$i].CrlPublishStatus.count;$l++) 
					{$CrlPublishStatus += $data[$i].CrlPublishStatus[$l] + "<br/>"}
				$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", $CrlPublishStatus)
			}
		
			if ($data[$i].DeltaCrlPublishStatus.count -eq 0) {$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", "Null")}
			else {
				for($m = 0;$m -lt $data[$i].DeltaCrlPublishStatus.count;$m++) 
					{$DeltaCrlPublishStatus += $data[$i].DeltaCrlPublishStatus[$m] + "<br/>"}
				$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", $DeltaCrlPublishStatus)
			}
		
			if ($data[$i].IsError.Tostring() -eq $null -or $data[$i].IsError.Tostring() -eq "") 
				{$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@IsError", "Null")}
			else {$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())}

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
		
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			$rowcount +=  1
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
Insert-ADCSServiceAvailability -Data $jnADCSServiceAvailabilityResult
if (gv jnADCSServiceAvailabilityResult -ea 0) {rv jnADCSServiceAvailabilityResult}

# Get Enrollment Policy Templates.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnADCSEnrollmentPolicyTemplatesResult = Invoke-Command -Session $session -script {
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
					$OS = gwmi Win32_OperatingSystem
					$hash.OperatingSystem = $OS.Caption
					$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()
					$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
					$hash.IsError = $False
						
					# CERTUTIL -CAINFO CAName: Display CA Information: CA Name
					$buf_error = $False
					$buf = certutil -CAInfo name
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.CAName += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -match "CA Name") {$hash.CAName = $_.Substring($_.IndexOf("CA Name")+7+1+2)}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CAName: $($hash.CAName)"

					# CERTUTIL -CAINFO DNSName: Display CA Information: DNS Name
					$buf_error = $False
					$buf = certutil -CAInfo dns
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.DNSName += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {if ($_ -match "DNS Name") {$hash.DNSName = $_.Substring($_.IndexOf("Dns Name")+8+1+2)}}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.DNSName: $($hash.DNSName)"

					# CERTUTIL -CAINFO CAType: Display CA Information: CA Type
					# ENUM_CATYPES enumeration, http://msdn.microsoft.com/en-us/library/windows/desktop/bb648652(v=vs.85).aspx
					$buf_error = $False
					$buf = certutil -CAInfo type
					$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
					if ($buf_error -eq $True) {
						$hash.IsError = $True
						$buf | % {$hash.CAType += $_.TrimStart(" ")}
					} # End of If it is null when the service not available.
					else {
						$buf | % {
							if ($_ -match "CA Type")
								{$hash.CAType = $_.Substring($_.IndexOf("CA type")+7+2)}
						}
					}
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CAType: $($hash.CAType)"

<#
Certutil –Template | ? {$_ -match "TemplatePropCommonName = "}

	TemplatePropCommonName = Administrator
	TemplatePropCommonName = ClientAuth
	TemplatePropCommonName = EFS
	TemplatePropCommonName = CAExchange
	TemplatePropCommonName = CEPEncryption
	TemplatePropCommonName = CodeSigning
	TemplatePropCommonName = Machine
	TemplatePropCommonName = CrossCA
	TemplatePropCommonName = DirectoryEmailReplication
	TemplatePropCommonName = DomainController
	TemplatePropCommonName = DomainControllerAuthentication
	TemplatePropCommonName = EFSRecovery
	TemplatePropCommonName = EnrollmentAgent
	TemplatePropCommonName = MachineEnrollmentAgent
	TemplatePropCommonName = EnrollmentAgentOffline
	TemplatePropCommonName = ExchangeUserSignature
	TemplatePropCommonName = ExchangeUser
	TemplatePropCommonName = IPSECIntermediateOnline
	TemplatePropCommonName = IPSECIntermediateOffline
	TemplatePropCommonName = KerberosAuthentication
	TemplatePropCommonName = KeyRecoveryAgent
	TemplatePropCommonName = OCSPResponseSigning
	TemplatePropCommonName = RASAndIASServer
	TemplatePropCommonName = CA
	TemplatePropCommonName = OfflineRouter
	TemplatePropCommonName = SmartcardLogon
	TemplatePropCommonName = SmartcardUser
	TemplatePropCommonName = SubCA
	TemplatePropCommonName = CTLSigning
	TemplatePropCommonName = User
	TemplatePropCommonName = UserSignature
	TemplatePropCommonName = WebServer
	TemplatePropCommonName = Workstation
	TemplatePropCommonName = ╗τ┐δ└┌(║╣╗τ║╗) - For Domain Users
	TemplatePropCommonName = ┐÷┼⌐╜║┼╫└╠╝╟└╬┴⌡(║╣╗τ║╗) - For Domain Computers
  
Error
==========
	Name: Active Directory Enrollment Policy
	Id: {3A2C7592-C315-4C72-A3ED-544B1E9E48D6}
	Url: ldap:
CertUtil: -Template command FAILED: 0x800704dc (WIN32: 1244 ERROR_NOT_AUTHENTICATED)
CertUtil: The operation being requested was not performed because the user has not been authenticated.
#>
					# CERTUTIL –TEMPLATE: Display Certificate Enrollment Policy templates.
					$buf = Certutil –Template | ? {$_ -match "TemplatePropCommonName = "}
					$buf01 = @()
					$buf | % {$buf01 += @($_.Substring($_.IndexOf("TemplatePropCommonName = ")+25))}
					$hash.CertEnrollPolicyTemplates = $buf01 | sort
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CertEnrollPolicyTemplates: $($hash.CertEnrollPolicyTemplates)"

					# CERTUTIL –CATEMPLATES: Display templates for CA.
					$hash.CATemplates = @(certutil -catemplates | % {$_.Substring(0, $_.IndexOf(":"))} | Sort)
					Write-Debug "`$buf_error: $($buf_error)"
					Write-Debug "`$hash.CATemplates: $($hash.CATemplates)"

					if ($hash.Count -gt 0) 
						{return $hash}

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

	$jnADCSEnrollmentPolicyTemplatesResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADCSEnrollmentPolicy {
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
[OperatingSystem] [nvarchar](100) NULL,`
[OperatingSystemServicePack] [nvarchar](100) NULL,`
[CAName] [nvarchar](30) NOT NULL,`
[DNSName] [nvarchar](30) NOT NULL,`
[CAType] [nvarchar](200) NOT NULL,`
[CertEnrollPolicyTemplates] [nvarchar](max) NOT NULL,`
[CATemplates] [nvarchar](max) NOT NULL,
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
			,@OperatingSystem nvarchar(100) `
			,@OperatingSystemServicePack nvarchar(100) `
			,@CAName nvarchar(30) `
			,@DNSName nvarchar(30) ` 
			,@CAType nvarchar(200) `
			,@CertEnrollPolicyTemplates nvarchar(max) `
			,@CATemplates nvarchar(max)
			,@UTCMonitored datetime`
			,@IsError nvarchar(10) `
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   (  [ComputerName],`
			  [OperatingSystem],`
			  [OperatingSystemServicePack],`
			  [CAName],`
			  [DNSName],`
			  [CAType],`
			  [CertEnrollPolicyTemplates],`
			  [CATemplates],`
			  [UTCMonitored],`
			  [IsError] `
		   ) `
		 VALUES`
		   (  @ComputerName,`
			  @OperatingSystem,`
			  @OperatingSystemServicePack,`
			  @CAName,`
			  @DNSName,`
			  @CAType,`
			  @CertEnrollPolicyTemplates,`
			  @CATemplates,`
			  @UTCMonitored,`
			  @IsError`
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
		
				for($j = 0;$j -lt $data[$i].CertEnrollPolicyTemplates.count;$j++) {$CertEnroll += $data[$i].CertEnrollPolicyTemplates[$j] + "<br/>"}
				for($l = 0;$l -lt $data[$i].CATemplates.count;$l++) {$CATemplate += $data[$i].CATemplates[$l] + "<br/>"}

				$ProbScrp = "CAName: " + $data[$i].CAName + "<br/>DNSName: " + $data[$i].DNSName + "<br/>CAType: " + $data[$i].CAType + "<br/>CertEnrollPolicyTemplates: " + $CertEnroll + "<br/>CATemplates: " + $CATemplates 
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADCS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "CS05")
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

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_ADCSEnrollmentPolicy"
	$ProcName = "IF_$($company)_ADCSEnrollmentPolicy"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
     
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$CertEnroll = $null
		
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "") 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
       
			if ($data[$i].OperatingSystem -eq $null -or $data[$i].OperatingSystem -eq "") 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "") 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if ($data[$i].CAName -eq $null -or $data[$i].CAName -eq "") 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", "Null")}		
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", $data[$i].CAName)}
		
			if ($data[$i].DNSName -eq $null -or $data[$i].DNSName -eq "") 
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", $data[$i].DNSName)}
		
			if ($data[$i].CAtype -eq $null -or $data[$i].CAtype -eq "") 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", $data[$i].CAtype)}
		
			if ($data[$i].CertEnrollPolicyTemplates.count -eq 0) {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@CertEnrollPolicyTemplates", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].CertEnrollPolicyTemplates.count;$j++) {
			$CertEnroll += $data[$i].CertEnrollPolicyTemplates[$j] + "<br/>"
			}
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@CertEnrollPolicyTemplates", $CertEnroll)}
		
			if ($data[$i].CATemplates.count -eq 0) {$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@CATemplates", "Null")}
			else {
			for($l = 0;$l -lt $data[$i].CATemplates.count;$l++) {
			$CATemplate += $data[$i].CATemplates[$l] + "<br/>"
			}
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@CATemplates", $CATemplate)}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		
			if ($data[$i].IsError.toString() -eq $null -or $data[$i].IsError.toString() -eq "") 
				{$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@IsError", "Null")}
			else {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.toString())}
        
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
			$rowcount += 1
		}

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
Insert-ADCSEnrollmentPolicy -Data $jnADCSEnrollmentPolicyTemplatesResult
if (gv jnADCSEnrollmentPolicyTemplatesResult -ea 0) {rv jnADCSEnrollmentPolicyTemplatesResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored

