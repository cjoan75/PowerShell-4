param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ManagedServerFQDN
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$userPrincipalName
)

# .\Get-jnADDSStatus-v3.ps1 -ManagedServerFQDN "LGEADPMSE6Q.LGE.NET" -userPrincipalName "monitor_admin@LGE.NET"

$ServiceFlag = "ADDS"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:USERPROFILE\Documents\ADMON\v3\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: The credential file NOT found: $($FilePath)"

	Insert-MonitoringTaskLogs -TaskType BEGIN -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
	throw $Message; exit;
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"

$TB_Servers = "TB_SERVERS2"
[array]$Servers = Get-SQLData -TableName $TB_Servers -ServiceFlag $ServiceFlag -Domain $DomainName
if ($Servers)
{
	Write-Host "Servers Retrieved: $($Servers.Count)"
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: No servers returned."

	Insert-MonitoringTaskLogs -TaskType BEGIN -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
	throw $Message; exit;
}

# Log the BEGIN time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType BEGIN -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName

# Get events.

try {
	# Generates a string for Where-object in order to exclude these event ids.
	# Initialize the variable like this, to not write additional Invoke-Command script block.
	$EventIdExclusionString = "`$_.ID -ne 0" 
	$TableName_EventID = "TB_EVENTID"
    $myEventIDResult = Get-SQLData -TableName $TableName_EventID -ServiceFlag $ServiceFlag -GetEventID | Sort ID
	if ($myEventIDResult)
	{
		$Id = $myEventIDResult.ID
		for ($j=0; $j -lt $Id.count; $j++)
		{
			if ($j -eq 0)
			{
				$EventIdExclusionString = "`$_.ID -ne " + $Id["$j"]
			} else {
				$EventIdExclusionString += " -AND `$_.ID -ne " + $Id["$j"]
			}
		}
	}
    Write-Debug -Message "Event IDs to exclude: $($EventIdExclusionString)"


	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		
		param ($Credential, $Servers, $myDebugPreference, $EventIdExclusionString, $ServiceFlag)

		$DebugPreference = $myDebugPreference

		workflow GetADDSEventResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
				, [string]$EventIdExclusionString
				, [string]$ServiceFlag
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference
						$EventIdExclusionString = $using:EventIdExclusionString
						$ServiceFlag = $using:ServiceFlag

						try {

							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -credential $Credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							[array]$buf = Invoke-Command -Session $session -script {
								param ($EventIdExclusionString, $ServiceFlag)

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={$ServiceFlag}}
								$begindate = (Get-Date).AddHours(-1*1)

								# For debug purpose, you can look up the log that saved at the workflow target computers.
								# invoke-command -cn $Servers.ComputerName -Credential $credential -Authentication Kerberos -script {type "$env:temp\$($env:computername)_admon.log"}
								$Message = "[$($jnUTCMonitored)] EventIDExclusionString: $($EventIdExclusionString)"
								if ($PSVersionTable.PSVersion.Major -ge 3)
								{
									$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
								} else {
									$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
								}

								$command = "Get-WinEvent -FilterHashTable @{ProviderName = 'Active Directory Web Services', 'Microsoft-Windows-Directory-Services-SAM', 'Microsoft-Windows-ActiveDirectory_DomainService', 'Microsoft-Windows-DirectoryServices-DSROLE-Server', 'Microsoft-Windows-DirectoryServices-LSADB', 'Microsoft-Windows-DirectoryServices-Deployment', 'Microsoft-Windows-GroupPolicy', 'DSReplicationProvider', 'DFS Replication', 'File Replication Service', 'Netlogon', 'LSA', 'LsaSrv'; StartTime = `$begindate; Level = 1, 2, 3 } -ea 0 | ? { $EventIdExclusionString } | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf = invoke-expression $command

								# ADDED: Audits AD Group membership changes
								$command = "Get-WinEvent -FilterHashtable @{LogName = 'Security'; StartTime = `$begindate; ID = 4756, 4757, 4732, 4733, 4728, 4729} -ea 0 | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf += invoke-expression $command
								
								$buf = $buf | sort TimeCreated
								if ($buf)
								{
									Write-Debug -Message "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}

							} -ArgumentList ($EventIdExclusionString, $ServiceFlag)
                        
							if ($buf)
							{
								Write-Debug -Message "returned: $($buf.Count), $($session.ComputerName)"
								return $buf
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
						
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}
					}
				}
			}
		}

		$myResult = GetADDSEventResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference -EventIdExclusionString $EventIdExclusionString -ServiceFlag $ServiceFlag

		# Unlike Level, LevelDisplayName can be null on Windows Server 2008 or earlier versions.
		foreach ($buf in ($myResult | ? LevelDisplayName -eq $null))
		{
			switch ($buf.Level)
			{
				0 {$buf.LevelDisplayName = "Information"}
				1 {$buf.LevelDisplayName = "Critical"}
				2 {$buf.LevelDisplayName = "Error"}
				3 {$buf.LevelDisplayName = "Warning"}
				Default {$LevelDisplayName = $null}
			}
		}
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference, $EventIdExclusionString, $ServiceFlag)
	$myResult | group ComputerName | sort Count
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}

}

function Insert-Event {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ProviderName] [nvarchar](100) NOT NULL,`
[LevelDisplayName] [nvarchar](30) NOT NULL,`
[Message] [nvarchar](max) NOT NULL,`
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
,@ProviderName nvarchar(100)
,@LevelDisplayName nvarchar(30)
,@Message nvarchar(max)
,@computername nvarchar(100)
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
	
	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].LevelDisplayName -ne "Warning")
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				if ($data[$i].LevelDisplayName -eq "Information")
				{
					# Adds AD Group Membership changes
					$description = $data[$i].Message.Split("`n")[0].Trim()
					$userName = (($data[$i].Message.Split("`n"))[10].Split(":"))[1].Trim()
					$groupName = (($data[$i].Message.Split("`n"))[14].Split(":"))[1].Trim()
					$ProbScrp = "EventID($($data[$i].ID)); GroupName: $($groupName), Member: $($userName), Desc: $($description)"
				} else {
					$ProbScrp = "EventID($($data[$i].ID)); $($data[$i].LevelDisplayName); $($data[$i].message)"
				}

				$serviceitem = $null
				switch($Data[$i].jnServiceFlag)
				{
					"ADCS" {$serviceitem = "CS01"; Break}
					"ADDS" {$serviceitem = "DS01"; Break}
					"DNS" {$serviceitem = "DN01"; Break}
					"DHCP" {$serviceitem = "DH01"; Break}
					Default {$serviceitem = $null }
				}

	
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", $Data[$i].jnServiceFlag)
				if (! $serviceitem)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_EVENT"
	$ProcName = "IF_$($company)_EVENT"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
   
	#Sql Command definition
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $data.count;$i++)
		{

			if ($Data[$i].count -eq 0) {continue}

			#Connect to Sql Server        
			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
		
			if (! $data[$i].LogName) 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@LogName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@LogName", $data[$i].LogName)}

			$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeCreated", $data[$i].TimeCreated)
	
			if (! $data[$i].Id) 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Id", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Id", $data[$i].Id)}
			if (! $data[$i].ProviderName) 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ProviderName", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ProviderName", $data[$i].ProviderName)}
			
			if (! ($data[$i].LevelDisplayName)) 
			{
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", "Null")
			} else {
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", ($data[$i].LevelDisplayName).ToString())
			}
			
			if (! $data[$i].Message) 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", $data[$i].Message)}
			if (! $data[$i].ComputerName)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
	
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)

			if (! $data[$i].jnServiceFlag) 
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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}
  
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

Finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}
}
  
}
if ($myResult) {Insert-Event -Data $myResult}

# Get services.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSServiceResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							[array]$buf = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME) + "." + ($env:USERDNSDOMAIN)}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADDS"}}
								
								$svcs = @("NTDS", "netlogon", "kdc", "DFSR", "ntfrs", "ISMSERV", "W32Time")
    							#$svcs += @("Lanmanserver", "Lanmanworkstation", "Dnscache", "Dhcp", "RpcSs")
								
								$buf = @()
								foreach ($svc in $svcs)
								{
									$jnIsError = @{Name="IsError"; Expression={$False}}
									$obj = Get-Service $svc | select Status, Name, DisplayName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag, $jnIsError
									if ($obj.Status -ne "Running")
									{
										$obj.IsError = $True;
									}

									# Determines it's error if ntfrs is not running in Windows Server 2008 R2 or its earlier versions.
									# https://docs.microsoft.com/en-us/windows/desktop/VSS/backing-up-and-restoring-an-frs-replicated-sysvol-folder
									if ($svc -eq "ntfrs")
									{
										$path = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\DFSR\Parameters\SysVols\Migrating Sysvols\";
										if (Test-Path registry::$path)
										{
											$localState = (gi registry::$path | gp)."Local State"
											if ($localState -eq 3)
											{
												$obj.IsError = $False;
											}
										}
									}
									$buf += $obj
								}
								if ($buf)
								{
									Write-Debug -Message "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}

							}

							if ($buf)
							{
								Write-Debug -Message "returned: $($buf.Count), $($session.ComputerName)"
								return $buf
							}
						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}
					}
				}
			}
		}

		$myResult = GetADDSServiceResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult
		
	} -ArgumentList ($credential, $Servers, $DebugPreference)
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-Service {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			,@computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)

	$procName = "IF_ProblemManagement"	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $ProcName
		
				# .Status property returned [Int32].
				$ProbScrp = "Service: $($ServiceFlag): $($data[$i].Status); $($data[$i].Name); $($data[$i].DisplayName)"

				$serviceitem = $null
				switch($Data[$i].jnServiceFlag)
				{
					"ADCS" {$serviceitem = "CS02"; Break}
					"ADDS" {$serviceitem = "DS02"; Break}
					"DNS" {$serviceitem = "DN02"; Break}
					"DHCP" {$serviceitem = "DH02"; Break}
					Default {$serviceitem = $null }
				}

	
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", $Data[$i].jnServiceFlag)
				if (! $serviceitem)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_SERVICE"
	$ProcName = "IF_$($company)_SERVICE"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
  
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			if (! $data[$i].Status) 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ServiceStatus", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ServiceStatus", $data[$i].Status.ToString())}
			if (! $data[$i].Name) 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Name", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Name", $data[$i].Name)}
			if (! $data[$i].DisplayName) 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@DisplayName", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@DisplayName", $data[$i].DisplayName)}
			if (! $data[$i].ComputerName) 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
			if (! $data[$i].jnServiceFlag) 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", $data[$i].jnServiceFlag)}
			
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());
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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}
}

}
if ($myResult) {Insert-Service -Data $myResult}

# Get performance data.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSPerformanceDataResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$cntrsets = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

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

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME) + "." + ($env:USERDNSDOMAIN)}}
								$jnCookedValue = @{Name="Value"; Expression={[math]::Round($_.CookedValue, 2)}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADDS"}}

								[array]$buf = (Get-Counter $args[0] -ea 0).CounterSamples | 
									select TimeStamp, TimeStamp100NSec, $jnCookedValue, Path, InstanceName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag
								if ($buf)
								{
									Write-Debug -Message "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}
							} -ArgumentList (,$cntrs)

							if ($buf)
							{
								Write-Debug -Message "returned: $($buf.Count), $($session.ComputerName)"
								return $buf
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSPerformanceDataResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-Performance {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
	        ,@computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_PERFORMANCE"
	$ProcName = "IF_$($company)_PERFORMANCE"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
		
			if (! $Data[$i].TimeStamp)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp", $Data[$i].TimeStamp)}
		
			if (! $Data[$i].TimeStamp100NSec)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp100NSec", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeStamp100NSec", $Data[$i].TimeStamp100NSec.tostring())}
		 
			if (! $Data[$i].Value)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Value", -1)}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Value", $Data[$i].Value)}
		
			if (! $Data[$i].Path)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@Path", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@Path", $Data[$i].Path)}
		
			if (! $Data[$i].InstanceName)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@InstanceName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@InstanceName", $Data[$i].InstanceName)}
		
			if (! $Data[$i].ComputerName)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)}
		
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $Data[$i].jnUTCMonitored)
		
			if (! $Data[$i].jnServiceFlag)
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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($myResult) {Insert-Performance -Data $myResult}

# Get ADDS Replication status.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSReplicationResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {
						
								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
								$mydc = Get-ADDomainController
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (Get-WmiObject Win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack} else {(Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
								$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
								$hash.IsRODC = $mydc.IsReadOnly
								$hash.OperationMasterRoles = $mydc.OperationMasterRoles
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()


								# REPADMIN /REPLSUMMARY: Display the replication status for all domain controllers in the forest to Identify domain controllers that are failing inbound replication or outbound replication, and summarizes the results in a report.
								# NOTE: /bysrc /bydest: displays the /bysrc parameter table first and the /bydest parameter table next. 
								$buf_command = @(REPADMIN /REPLSUMMARY $env:COMPUTERNAME /BYSRC /BYDEST /sort:delta | ? {$_})

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

							if ($hash.Count -gt 0)
							{
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSReplicationResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-ADReplication {
param (
	[Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
[repadmin] [nvarchar](300) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			 @computername nvarchar(100) `
			,@repadmin nvarchar(300) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)

	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				for($k = 3;$k -lt $data[$i].repadmin.count;$k++) {$repadmin += $data[$i].repadmin[$k] + "<br/>"}
	
				$ProbScrp = "AD Replication: " + $repadmin
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADDSReplication"
	$ProcName = "IF_$($company)_ADDSReplication"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
    
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
		
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$OPRoles = $null
			$repadmin = $null
		
			if (! $data[$i].ComputerName)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
        
			if ($data[$i].repadmin.count -eq 0)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@repadmin", "Null")}
			else {
				for($k = 0;$k -lt $data[$i].repadmin.count;$k++) {$repadmin += $data[$i].repadmin[$k] + "<br/>"}
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@repadmin", $repadmin)
			}
        
			if (! $data[$i].OperatingSystem)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if (! $data[$i].OperatingSystemServicePack)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}	
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if (! $data[$i].IsGlobalCatalog)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
        
			if (! $data[$i].IsRODC)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}

			if ($data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}	
			else
			{for($j = 0;$j -lt $data[$i].OperationMasterRoles.count; $j++) {$OPRoles +=  $data[$i].OperationMasterRoles[$j].ToString() + "<br/>"}	
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)}
				
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());
                               
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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($myResult) {Insert-ADReplication -Data $myResult}

# Get Sysvol Shares status.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSSysvolSharesResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {
						
								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
								$mydc = Get-ADDomainController
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (get-wmiobject win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack} else {(Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
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

							if ($hash.Count -gt 0)
							{
								return $hash
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSSysvolSharesResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-ADDSSysvolShares {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
				@computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
		
	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				for($j = 0;$j -lt $Data[$i].frssysvol.count;$j++) {$frssysvol += $Data[$i].frssysvol[$j] + "<br/>"}
			
				$ProbScrp = "SYSVOL share: " + $frssysvol
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADDSSysvolShares"
	$ProcName = "IF_$($company)_ADDSSysvolShares"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
			$frssysvol = $null
			$OPRoles = $null

			if (! $Data[$i].ComputerName)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
		
			if ($Data[$i].frssysvol.count -eq 0)
			{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@frssysvol", "Null")}
			else {for($j = 0;$j -lt $Data[$i].frssysvol.count;$j++) {$frssysvol += $Data[$i].frssysvol[$j] + "<br/>"}
			$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@frssysvol", $frssysvol)}

			if (! $Data[$i].OperatingSystem)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}	
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if (! $data[$i].OperatingSystemServicePack)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if (! $data[$i].IsGlobalCatalog)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
		
			if (! $data[$i].IsRODC)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}
			if ($data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
			for($k = 0;$k -lt $Data[$i].OperationMasterRoles.count;$k++) {$OPRoles += $Data[$i].OperationMasterRoles[$k].ToString() + "<br/>"}	
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)}
		
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());
                         
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
			
		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($myResult) {Insert-ADDSSysvolShares -Data $myResult}

# Get AD Topology status.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSTopologyResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
								$mydc = Get-ADDomainController
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (get-wmiobject win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack} else {(Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
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

							if ($hash.Count -gt 0)
							{
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSTopologyResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-ADDSTopology {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			 @computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
	
	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				for($j = 0;$j -lt $data[$i].adtopology.count;$j++) {$adtopology += $data[$i].adtopology[$j] + "<br/>"}	
		
				$ProbScrp = "ADDS Topology: " + $adtopology
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADDSTopology"
	$ProcName = "IF_$($company)_ADDSTopology"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
     
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$adtopology = $null
			$OperationMasterRoles = $null
		
			if (! $data[$i].ComputerName)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}

			if ($data[$i].adtopology.count -eq 0) {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@adtopology", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].adtopology.count;$j++) {$adtopology += $data[$i].adtopology[$j] + "<br/>"}
			$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@adtopology", $adtopology)}
		
			if (! $Data[$i].OperatingSystem)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}	
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if (! $data[$i].OperatingSystemServicePack)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if (! $data[$i].IsGlobalCatalog)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
		
			if (! $data[$i].IsRODC)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}
		
			if ($data[$i].OperationMasterRoles.count -eq 0) {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].OperationMasterRoles.count;$j++) {
				$OperationMasterRoles += $data[$i].OperationMasterRoles[$j].ToString() + "<br/>"}
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OperationMasterRoles)}
		
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());
	    
			
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
			
		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($myResult) {Insert-ADDSTopology -Data $myResult}

# Get AD Repository status.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSRepositoryResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
								$mydc = Get-ADDomainController
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (get-wmiobject win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack} else {(Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
								$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
								$hash.IsRODC = $mydc.IsReadOnly
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

								$path = "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\NTDS\Parameters"
								$name = "DSA Database file"
								$hash.DataBasePath = gi $path | gp | select -expand $name
								$DBPath = $hash.DataBasePath
								$DBSize = Get-Item $DBPath | Select -expand Length
								$hash.DataBaseSize = ([math]::Round($DBSize/1gb, 2)).tostring() + "GB"
                   
								$DBDriveFreeSpace = Get-WmiObject Win32_LogicalDisk | ? {$_.DeviceID -eq $DBPath.SubString(0, 2)} | select -expand freespace
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
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSRepositoryResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-ADDSRepository {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
				@computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
	
	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				$ProbScrp = "ADDatabaseDriveFreeSpace: " + $data[$i].DatabaseDriveFreeSpace
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}
	
try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADDSRepository"
	$ProcName = "IF_$($company)_ADDSRepository"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
 
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
			
			if (! $data[$i].ComputerName)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
		
			if (! $data[$i].SysvolPath)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@SysvolPath", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@SysvolPath", $data[$i].SysvolPath)}
		
			if (! $data[$i].LogFileSize)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@LogFileSize", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@LogFileSize", $data[$i].LogFileSize)}

			if (! $data[$i].IsGlobalCatalog)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
		
			if (! $data[$i].DataBaseSize)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DataBaseSize", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DataBaseSize", $data[$i].DataBaseSize)}

			if (! $data[$i].IsRODC)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}

			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@LogFilePath", $data[$i].LogFilePath)
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@DataBasePath", $data[$i].DataBasePath)
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseDriveFreeSpace", $data[$i].DatabaseDriveFreeSpace)
			
			if (! $data[$i].OperatingSystemServicePack)
				{$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
			
			$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			
			if (! $data[$i].OperatingSystem)
				{$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
			
			$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());

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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

Finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
} 
if ($myResult) {Insert-ADDSRepository -Data $myResult}

# Get DC Advertisement status.

try {

	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSAdvertisementResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
								$mydc = Get-ADDomainController
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (get-wmiobject win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack} else {(Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
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

							if ($hash.Count -gt 0)
							{
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSAdvertisementResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-ADDSAdvertisement {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			 @computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
	
	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				for($j = 0;$j -lt $Data[$i].dcdiag_advertising.count; $j++) {$advertising += $Data[$i].dcdiag_advertising[$j] + "<br/>"}

				$ProbScrp = "ADDS Advertisement: " + $advertising
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADDSAdvertisement"
	$ProcName = "IF_$($company)_ADDSAdvertisement"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
    
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0) {

		for($i  =  0;$i -lt $data.count;$i++)
		{

			if ($Data.count -eq 0) {continue}
 
			$temp = $null
			$OPRoles = $null
	
			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			if (! $data[$i].ComputerName)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
        
			if (! $data[$i].IsGlobalCatalog)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
        
			if (! $data[$i].IsRODC)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@IsRODC", $data[$i].IsRODC.ToString())}
        
			If ($Data[$i].OperationMasterRoles.count -eq 0)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", "Null")}
			else {
			for($k = 0;$k -lt $Data[$i].OperationMasterRoles.count; $k++) {
				$OPRoles +=  $Data[$i].OperationMasterRoles[$k].Tostring() + "<br/>"}	
			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@OperationMasterRoles", $OPRoles)}
		
			if (! $Data[$i].OperatingSystemServicePack)
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $Data[$i].OperatingSystemServicePack)}

			$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $Data[$i].jnUTCMonitored)

			if (! $Data[$i].OperatingSystem)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $Data[$i].OperatingSystem)}

			if ($Data[$i].dcdiag_advertising.count -eq 0)
				{$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@dcdiag_advertising", "Null")}
			else {
			for($j = 0;$j -lt $Data[$i].dcdiag_advertising.count; $j++) {   
			$advertising += $Data[$i].dcdiag_advertising[$j] + "<br/>"}
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@dcdiag_advertising", $advertising)}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $Data[$i].IsError.ToString());
                
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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($myResult) {Insert-ADDSAdvertisement -Data $myResult}

# Get w32time service sync status.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADDSW32TimeSyncResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
			)

			ForEach -Parallel ($server in $Servers)
			{
				Sequence
				{
					InlineScript
					{
						$Credential = $using:Credential
						$server = $using:server
						$DebugPreference = $using:DebugPreference

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
								$mydc = Get-ADDomainController
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (get-wmiobject win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack} else {(Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
								$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
								$hash.IsRODC = $mydc.IsReadOnly
								$hash.OperationMasterRoles = $mydc.OperationMasterRoles
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

								# w32tm /query: Display a computer's windows time service information.
								$buf = w32tm /query /status
								$buf_LastSuccessfulSyncedTime = $buf[6].SubString($buf[6].IndexOf(":")+2)
								$buf_TimeSource = $buf[7].Split(":")[1].Trim();
								if ($buf_LastSuccessfulSyncedTime)
								{
									$hash.LastSuccessfulSyncedTime = $buf_LastSuccessfulSyncedTime
									$hash.TimeSource = $buf_TimeSource
									$hash.IsError = $False
								} else {
									$hash.LastSuccessfulSyncedTime = $null
									$hash.TimeSource = $null
									$hash.IsError = $True
								}
			
								if ($hash.Count -gt 0) 
									{return $hash}

							}

							if ($hash.Count -gt 0)
							{
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							if ($PSVersionTable.PSVersion.Major -ge 3)
							{
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							} else {
								$Message | Add-Content -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
							}
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug -Message "session closed: $($session.ComputerName)"
							}
						}

					}
				}
			}
		}

		$myResult = GetADDSW32TimeSyncResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	if ($session)
	{
		Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
		Write-Host "session closed: $($session.ComputerName)`n"
	}
}

function Insert-ADDSW32TimeSync {
param (
    [Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL,`
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			 @computername nvarchar(100) `
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

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
	
	$procName = "IF_ProblemManagement"
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0
	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError)
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				$ProbScrp = "W32Time: " + $data[$i].LastSuccessfulSyncedTime + "; TimeSource: " + $data[$i].TimeSource
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {
	
	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADDSW32TimeSync"
	$ProcName = "IF_$($company)_ADDSW32TimeSync"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
			$OPRoles = $null
		
			if (! $data[$i].ComputerName)
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}

			if (! $data[$i].LastSuccessfulSyncedTime)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@LastSuccessfulSyncedTime", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@LastSuccessfulSyncedTime", $data[$i].LastSuccessfulSyncedTime)}
		
			if (! $data[$i].TimeSource)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@TimeSource", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@TimeSource", $data[$i].TimeSource)}
		
			if (! $data[$i].IsGlobalCatalog)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@IsGlobalCatalog", $data[$i].IsGlobalCatalog.ToString())}
        
			if (! $data[$i].IsRODC)
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
	
			if (! $data[$i].OperatingSystemServicePack)				
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		
			if (! $data[$i].OperatingSystem)
				{$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
		
			$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());

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

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

}
}
if ($myResult) {Insert-ADDSW32TimeSync -Data $myResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName

