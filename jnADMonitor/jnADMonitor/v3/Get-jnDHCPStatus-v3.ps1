param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ManagedServerFQDN
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$userPrincipalName
)

# .\Get-jnDHCPStatus-v3.ps1 -ManagedServerFQDN "LGEADPMSE6Q.LGE.NET" -userPrincipalName "monitor_admin@LGE.NET"

$ServiceFlag = "DHCP"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:USERPROFILE\Documents\ADMON\v3\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: The credential file NOT found: $FilePath"
	 
	Insert-MonitoringTaskLogs -TaskType BEGIN -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
	throw $Message; exit;
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"

$TB_Servers = "TB_SERVERS2"
[array]$Servers = Get-SQLData -TableName $TB_Servers -Domain $DomainName -ServiceFlag $ServiceFlag | Sort ComputerName -Unique
if ($Servers)
{
	Write-Host "Servers Retrieved: $($Servers.Count)"
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: No Servers Retrieved."

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

		workflow GetDHCPEventResult
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
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							[array]$buf = Invoke-Command -Session $session -script {

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

								$command = "Get-WinEvent -FilterHashTable @{ProviderName = 'Microsoft-Windows-DHCP-Server'; StartTime = `$begindate; Level = 1, 2, 3 } -ea 0 | ? { $EventIdExclusionString } | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf = invoke-expression $command
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

		$myResult = GetDHCPEventResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference -EventIdExclusionString $EventIdExclusionString -ServiceFlag $ServiceFlag

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

			if ($data[$i].LevelDisplayName -ne "warning")
			{
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $procName
		
				$ProbScrp = "EventID($($data[$i].ID)); $($data[$i].LevelDisplayName); $($data[$i].message)"

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
        
				Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
				Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			if (! $data[$i].LevelDisplayName) 
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", $data[$i].LevelDisplayName.ToString())}
			if (! $data[$i].Message) 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", $data[$i].Message)}
			if (! $data[$i].ComputerName) 
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
	
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)

			if ($data[$i].jnServiceFlag) 
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
if ($myResult)	{Insert-Event -Data $myResult}

# Get services.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
	param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetDHCPServiceResult
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
										Write-Debug -Message "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf01.GetType()), $($buf01.Count)."
									} 

								} # End of services.

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

		$myResult = GetDHCPServiceResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	$myResult | group computername | sort Count
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
        
				Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
				Write-Debug -Message "CommandText: $($cmd.CommandText)."

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

		workflow GetDHCPPerformanceDataResult
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

							[array]$cntrsets = Invoke-Command -Session $session -script {

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

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

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME) + "." + ($env:USERDNSDOMAIN)}}
								$jnCookedValue = @{Name="Value"; Expression={[math]::Round($_.CookedValue, 2)}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"DHCP"}}

								[array]$buf = (Get-Counter $args[0] -ea 0).CounterSamples | 
									select TimeStamp, TimeStamp100NSec, $jnCookedValue, Path, InstanceName, $jnComputerName, $jnUTCMonitored, $jnServiceFlag
								if ($buf)
								{
									Write-Debug -Message "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}
							} -ea 0 -ArgumentList (, $cntrs)

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

		$myResult = GetDHCPPerformanceDataResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	$myResult | group computername | sort Count
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

# Get service availability.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
	param ($Credential, $Servers, $myDebugPreference, $DomainName)

		$DebugPreference = $myDebugPreference

		workflow GetDHCPServiceAvailabilityResult
		{
			param (
				[PSCredential]$Credential
				, [array]$Servers
				, [System.Management.Automation.ActionPreference]$DebugPreference
				, [string]$DomainName
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
						$DomainName = $using:DomainName

						try {
				
							# to create powershell remote session
							$session = New-PSSession -cn $server.ComputerName -Credential $credential
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {
								param ($DomainName)

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
								$hash.DomainName = $env:USERDNSDOMAIN
								$OS = Get-WmiObject Win32_OperatingSystem
								$hash.OperatingSystem = $OS.Caption
								$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()
								$hash.PSVersion = $PSVersionTable.PSVersion.Major
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
								$hash.IsError = $False

								# Displays the current status for the DHCP server on which the command runs.
								$hash.serverstatus = @(netsh dhcp server show serverstatus | 
									% {if ($_ -like "*Server Attrib*") {$_.SubString($_.IndexOf("- ")+2)}})
								
								# Displays information about server database configuration for the specified DHCP server.
								netsh dhcp server show dbproperties | 
									? {$_} | 
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
								$serverversion = netsh dhcp server show version | ? {$_}
								$hash.version = $serverversion.Substring($serverversion.IndexOf(" is ")+4).TrimEnd(".")

								# Displays the availability by using DHCP client tool.								
								$hash.IsAvailableByClient = $False
								$hash.ClientExists = $False

								$uri = "http://files.thecybershadow.net/dhcptest/dhcptest-0.7-win64.exe"
								$FilePath = "$env:USERPROFILE\Downloads\" + $uri.Substring($uri.LastIndexOf("/")+1)

								# Make sure if the dhcp tool is available.
								if (! (Test-Path $FilePath))
								{
									if (! (Test-Path "\\$($DomainName)\netlogon\$($FilePath.SubString($FilePath.LastIndexOf("\")+1))"))
									{
										if ($PSVersionTable.PSVersion.Major -ge 3 `
											-and ($response = Invoke-RestMethod -URI $uri -OutFile $FilePath)
										)
										{
											Copy-Item $FilePath -Destination "\\$($DomainName)\netlogon"
										}
									} else {
										Copy-Item "\\$($DomainName)\netlogon\$($FilePath.SubString($FilePath.LastIndexOf("\")+1))" -Destination (Split-Path $FilePath)
									}
								}
								if (Test-Path $FilePath)
								{
									$hash.ClientExists = $True
									$buf = & $FilePath --Query --Quiet --timeout 30 --tries 1
									if ($buf) {$hash.IsAvailableByClient = $True}
									else {
										# Determines the service availability for DHCP Lease.
										$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName}}
										$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
										$jnServiceFlag = @{Name="jnServiceFlag"; Expression={$ServiceFlag}}
										$begindate = (Get-Date).AddHours(-1*1)

										$command = "Get-WinEvent -FilterHashTable @{ProviderName = 'Microsoft-Windows-DHCP-Server'; StartTime = `$begindate; ID = 1011, 1012, 1063, 1338 } -ea 0 | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
										[array]$buf = invoke-expression $command
										if ($buf)
										{
											$hash.HasErrorEvents = $True
											$hash.ErrorEvents = $buf

											$hash.IsError = $True
										}
									}
								}
								if ($hash.Count -gt 0)
									{return $hash}

							} -ArgumentList ($DomainName)

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

		$myResult = GetDHCPServiceAvailabilityResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference -Domain $DomainName
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference, $DomainName)
	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)`t$($_.IsAvailableByClient)`t$($_.ClientExists)"}
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

function Insert-DHCPServiceAvailability {
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
[ComputerName] [nvarchar](100)	NOT NULL,`
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
[ManageDate] [datetime] NULL, `
[IsAvailableByClient] [nvarchar](10) NOT NULL`
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
			    @computername nvarchar(100),` 
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
				@IsError nvarchar(10), `
				@IsAvailableByClient nvarchar(10) `
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
			[IsError],`
			[IsAvailableByClient]) `
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
				@IsError,`
				@IsAvailableByClient) `
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
		
				if ($data[$i].serverstatus -match "FALSE")
				{
					for($j = 0;$j -lt $data[$i].serverstatus.count;$j++) {$serverstatus += $data[$i].serverstatus[$j] + "<br/>"}
					$ProbScrp = "DHCP Server Status: " + $serverstatus
				}
				if ((! $data[$i].IsAvailableByClient) -and ($data[$i].ClientExists))
				{
					if ($data[$i].ErrorEvents)
					{
						$Message = $null
						foreach ($event in $data[$i].ErrorEvents)
						{
							$Message += "EventID($($event.ID)): $($event.LevelDisplayName)); "
						}
						$ProbScrp = $Message
					} else {
						$ProbScrp = "The service not discovered: $($Data[$i].ComputerName), $($Data[$i].jnUTCMonitored)"
					}
				}

				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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
        
				Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
				Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
	$TableName = "TB_$($company)_DHCPServiceAvailability"
	$ProcName = "IF_$($company)_DHCPServiceAvailability"

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

			$serverstatus = $null
		
			$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)
        
			if (! $data[$i].OperatingSystem)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if (! $data[$i].OperatingSystemServicePack)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
        
			if ($Data[$i].serverstatus.count -eq 0)
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@serverstatus", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].serverstatus.count;$j++) {$serverstatus += $data[$i].serverstatus[$J] + "<br/>"}
			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@serverstatus", $serverstatus)}

			$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
			if (! $data[$i].DatabaseName)
			{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseName", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseName", $data[$i].DatabaseName)}
			if (! $data[$i].DatabasePath)
				{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@DatabasePath", "Null")}
			else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@DatabasePath", $data[$i].DatabasePath)}
			if (! $data[$i].DatabaseBackupPath)
				{$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupPath", "Null")}
			else {$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupPath", $data[$i].DatabaseBackupPath)}
			if (! $data[$i].DatabaseBackupInterval)
				{$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupInterval", "Null")}
			else {$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseBackupInterval", $data[$i].DatabaseBackupInterval)}
			if (! $data[$i].DatabaseLoggingFlag)
				{$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseLoggingFlag", "Null")}
			else {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseLoggingFlag", $data[$i].DatabaseLoggingFlag)}
			if (! $data[$i].DatabaseRestoreFlag)
				{$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseRestoreFlag", "Null")}
			else {$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseRestoreFlag", $data[$i].DatabaseRestoreFlag)}
			if (! $data[$i].DatabaseCleanupInterval)
				{$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseCleanupInterval", "Null")}
			else {$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@DatabaseCleanupInterval", $data[$i].DatabaseCleanupInterval)}
			
			$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());

			$SQLParameter14 = New-Object System.Data.SqlClient.SqlParameter("@IsAvailableByClient", $data[$i].IsAvailableByClient.ToString());
			

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
			[void]$cmd.Parameters.Add($SQLParameter14)
        
			$cmd.ExecuteNonQuery() | out-null

			$cmd.Connection.Close()

		} # End of for.
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
if ($myResult) {Insert-DHCPServiceAvailability -Data $myResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName

