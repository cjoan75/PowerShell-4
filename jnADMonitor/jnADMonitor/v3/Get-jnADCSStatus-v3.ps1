param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ManagedServerFQDN
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$userPrincipalName
)

# .\Get-jnADCSStatus-v3.ps1 -ManagedServerFQDN "LGEADPMSE6Q.LGE.NET" -userPrincipalName "monitor_admin@LGE.NET"

$ServiceFlag = "ADCS"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:USERPROFILE\Documents\ADMON\v3\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: The credential file NOT found: $FilePath"
	
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
	throw $Message; exit;
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"

$TB_Servers = "TB_SERVERS2"
[array]$Servers = Get-SQLData -TableName $TB_Servers -Domain $DomainName -ServiceFlag $ServiceFlag | Sort ComputerName -Unique
if ($Servers)
{
	Write-Host "Servers Retrieved: $($Servers.Count)"
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: No Servers Retrieved."

	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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

		workflow GetADCSEventResult
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

								$command = "Get-WinEvent -FilterHashTable @{ProviderName = 'Microsoft-Windows-CertificationAuthority', 'Microsoft-Windows-CertificationAuthorityClient-CertCli', 'Microsoft-Windows-CertificationAuthority-EnterprisePolicy', 'Microsoft-Windows-CertPolEng'; StartTime = `$begindate; Level = 1, 2, 3 } -ea 0 | ? { $EventIdExclusionString } | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
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
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
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

		$myResult = GetADCSEventResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference -EventIdExclusionString $EventIdExclusionString -ServiceFlag $ServiceFlag

		# Unlike Level, LevelDisplayName can be null on Windows Server 2008 or earlier versions.
		foreach ($buf in ($myResult | ? {$_.LevelDisplayName -eq $null}))
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
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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
	$rowcount = 0

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
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", ($data[$i].LevelDisplayName).ToString())}
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
			$rowcount += 1

		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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

		workflow GetADCSServiceResult
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
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
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

		$myResult = GetADCSServiceResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	$myResult | group computername | sort Count
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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
				switch($Data[$i].jnServiceFlag) {
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

	$rowcount = 0
	
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
			$rowcount +=  1
		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow
	}	
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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

		workflow GetADCSPerformanceDataResult
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

								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name="ComputerName"; Expression={($env:COMPUTERNAME) + "." + ($env:USERDNSDOMAIN)}}
								$jnCookedValue = @{Name="Value"; Expression={[math]::Round($_.CookedValue, 2)}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"ADCS"}}

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
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
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

		$myResult = GetADCSPerformanceDataResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	$myResult | group computername | sort Count
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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
	$rowcount = 0

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
			$rowcount +=  1
		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow
	}
}

Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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
	param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADCSServiceAvailability
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
								$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
								$hash.DomainName = $env:USERDNSDOMAIN
								$OS = Get-WmiObject Win32_OperatingSystem
								$hash.OperatingSystem = $OS.Caption
								$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()
								$hash.PSVersion = $PSVersionTable.PSVersion.Major
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
								$hash.IsError = $False

								<# CERTUTIL -CAINFO Name: Display CA name
									
								certutil -CAInfo name
								========
								CA name: dotnetsoft-DNPROD01-CA
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo name
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.CAName = $null
								} else {
									$hash.CAName = ($buf[0].Split(":"))[1].Trim()
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CAName: $($hash.CAName)"

								<# CERTUTIL -CAINFO dns: Display CA DNS Name

								certutil -CAInfo dns
								========
								DNS Name: DNPROD01.dotnetsoft.co.kr
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo dns
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.DNSName = $null
								} else {
									$hash.DNSName = ($buf[0].Split(":"))[1].Trim()
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.DNSName: $($hash.DNSName)"

								<# CERTUTIL -CAINFO type: Display CA Type
								# ENUM_CATYPES enumeration, http://msdn.microsoft.com/en-us/library/windows/desktop/bb648652(v=vs.85).aspx

								certutil -CAInfo type
								========
								CA type: 0 -- Enterprise Root CA
									ENUM_ENTERPRISE_ROOTCA -- 0
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo type
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.CAType = $null
								} else {
									$buf | % {$hash.CAType = $buf[1].Trim()}
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CAType: $($hash.CAType)"

								<# certutil -ping: Attempt to contact the AD CS Request interface
									
								certutil -ping
								========
								Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...
								Server "dotnetsoft-DNPROD01-CA" ICertRequest2 interface is alive (0ms)
								CertUtil: -ping command completed successfully.

								#>
								$buf = certutil -ping
								if (! $buf)
								{
									$hash.IsError = $True
									$hash.ping = $null
								} else {
									$hash.ping = $buf[1].Trim()
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.ping: $($hash.ping)"

								<# certutil -pingadmin: Attempt to contact the AD CS Admin interface
								
								certutil -pingadmin
								========
								Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...
								Server ICertAdmin2 interface is alive
								CertUtil: -pingadmin command completed successfully.

								#>
								$buf = certutil -pingadmin
								if (! $buf)
								{
									$hash.IsError = $True
									$hash.pingadmin = $null
								} else {
									$hash.pingadmin = $buf[1].Trim()
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.pingadmin: $($hash.pingadmin)"

								<# certutil -CAInfo crlstatus: CRL Status

								certutil -CAInfo crlstatus
								========
								CRL Publish Status[0]: 0x45 (69)
									CPF_BASE -- 1
									CPF_COMPLETE -- 4
									CPF_MANUAL -- 40 (64)
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo crlstatus
								if (! $buf)
								{
									$hash.IsError = $True
									$hash.CrlPublishStatus = $null
								} else {
									$hash.CrlPublishStatus = $buf[0].Split(" ")[3]
								}
								Write-Debug -Message "`$buf_error: $($buf_error)"
								Write-Debug -Message "`$hash.CrlPublishStatus: $($hash.CrlPublishStatus)"

								<# certutil -CAInfo deltacrlstatus: Delta CRL Publish Status
								
								certutil -CAInfo deltacrlstatus
								========
								Delta CRL Publish Status[0]: 6
									CPF_DELTA -- 2
									CPF_COMPLETE -- 4
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo deltacrlstatus
								if (! $buf)
								{
									$hash.IsError = $True
									$hash.DeltaCrlPublishStatus = $null
								} else {
									$hash.DeltaCrlPublishStatus = $buf[0].Split(" ")[4]
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.DeltaCrlPublishStatus: $($hash.DeltaCrlPublishStatus)"

								<# certutil -CAInfo crlstate: CRL State

								certutil -CAInfo crlstate
								========
								CRL[0]: 3 -- Valid
								CertUtil: -CAInfo command completed successfully.

								ICertAdmin2::GetCAProperty method
								https://docs.microsoft.com/en-us/windows/desktop/api/certadm/nf-certadm-icertadmin2-getcaproperty

								CR_PROP_CRLSTATE

								Data type of the property: Long 
								State of the CA's CRL. The values can be:

								CA_DISP_REVOKED
								CA_DISP_VALID
								CA_DISP_INVALID
								CA_DISP_ERROR
								#>
								$buf = certutil -CAInfo crlstate
								if (! $buf)
								{
									$hash.IsError = $True
									$hash.CrlState = $null
								} else {
									$hash.CrlState = $buf[0].Split("-- ")[5]
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CrlState: $($hash.CrlState)"

								<# CA Certificate Info.
								
								gci Cert:\Localmachine\ -Recurse| ? {$_.Subject -like "CN=$($hash.CAName)*"} | sort Thumbprint -unique | select NotAfter, Subject | ft -a
								
[lgeadpmse1q.lge.net]: PS C:\Users\TEMP.LGE.001\Documents> 
$session = New-PSSession -cn BSNDR10-DC11.lge.net
$buf = invoke-command -Session $session -script {
	gci Cert:\Localmachine\ -Recurse | ? {$_.Subject -like "CN=lgeissuingca6*"} | sort Thumbprint -unique | sort NotAfter -Descending
}
$buf.CACertificate.NotAfter.ToString("yyyyMMdd-HHmmss") + "`t" + $buf.IsCACertExpiringIndays


PSPath             : Microsoft.PowerShell.Security\Certificate::Localmachine\CA\4CC456549008464C58E78442F29935F157D6C31
                     F
PSParentPath       : Microsoft.PowerShell.Security\Certificate::Localmachine\CA
PSChildName        : 4CC456549008464C58E78442F29935F157D6C31F
PSDrive            : cert
PSProvider         : Microsoft.PowerShell.Security\Certificate
PSIsContainer      : False
Archived           : False
Extensions         : {System.Security.Cryptography.X509Certificates.X509Extension, System.Security.Cryptography.X509Cer
                     tificates.X509SubjectKeyIdentifierExtension, System.Security.Cryptography.X509Certificates.X509Ext
                     ension, System.Security.Cryptography.X509Certificates.X509KeyUsageExtension...}
FriendlyName       :
IssuerName         : System.Security.Cryptography.X509Certificates.X500DistinguishedName
NotAfter           : 1/17/2024 4:48:24 PM
NotBefore          : 1/17/2014 4:38:24 PM
HasPrivateKey      : False
PrivateKey         :
PublicKey          : System.Security.Cryptography.X509Certificates.PublicKey
RawData            : {48, 130, 6, 198...}
SerialNumber       : 2AEC1F2400000000000D
SubjectName        : System.Security.Cryptography.X509Certificates.X500DistinguishedName
SignatureAlgorithm : System.Security.Cryptography.Oid
Thumbprint         : 4CC456549008464C58E78442F29935F157D6C31F
Version            : 3
Handle             : 436007664
Issuer             : CN=LGERootCA
Subject            : CN=LGEIssuingCA6, DC=LGE, DC=NET
PSComputerName     : bsndr10-dc11
RunspaceId         : e06fcc5a-58e4-4187-9e41-611c29fbd333
PSShowComputerName : True
								
								#>
								$buf = gci Cert:\Localmachine\ -Recurse | ? {$_.Subject -like "CN=$($hash.CAName)*"} | sort Thumbprint -unique | sort NotAfter -Descending
								if (! $buf)
								{
									$hash.IsError = $True
								} else {
									#$buf.NotAfter	<<< sets IsError to TRUE, if .NotAfter is less than last specified days.
									$hash.IsCACertExpiringInDays = $False
									if ($buf.NotAfter -lt (Get-Date).AddDays(1 * 7))
									{
										$hash.IsCACertExpiringInDays = $True
										$hash.IsError = $True
									}

									$hash.CACertificate = $buf
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CACertificate: $($hash.CACertificate)"

								<# Crl Validity Period Info.
								
								certutil -getreg CA\CrlPeriodUnits
								certutil -getreg CA\CrlPeriod
								certutil -getreg CA\CrlDeltaPeriodUnits
								certutil -getreg CA\CrlDeltaPeriod

								#>
								$buf = certutil -getreg CA\CrlPeriod
								$buf_metric = $buf[2].Split("=")[1].Trim()
								$buf = certutil -getreg CA\CrlPeriodUnits
								if ($buf[2].IndexOf("(") -gt 0)
								{
									[int]$buf_unit = $buf[2].Split("(")[1].TrimEnd(")")
								} else {
									[int]$buf_unit = $buf[2].Split("=")[1].Trim()
								}
								Switch ($buf_metric)
								{
									'Weeks' {$buf_unit = $buf_unit * 7}
									'Months' {$buf_unit = $buf_unit * 30}
									'Years' {$buf_unit = $buf_unit * 365}
								}
								$hash.CrlPeriod = New-TimeSpan -Days $buf_unit
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CrlPeriod: $($hash.CrlPeriod)"
								
								$buf = certutil -getreg CA\CrlDeltaPeriod
								$buf_metric = $buf[2].Split("=")[1].Trim()
								$buf = certutil -getreg CA\CrlDeltaPeriodUnits
								if ($buf[2].IndexOf("(") -gt 0)
								{
									[int]$buf_unit = $buf[2].Split("(")[1].TrimEnd(")")
								} else {
									[int]$buf_unit = $buf[2].Split("=")[1].Trim()
								}
								
								Switch ($buf_metric)
								{
									'Weeks' {$buf_unit = $buf_unit * 7}
									'Months' {$buf_unit = $buf_unit * 30}
									'Years' {$buf_unit = $buf_unit * 365}
								}
								$hash.CrlDeltaPeriod = New-TimeSpan -Days $buf_unit
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CrlDeltaPeriod: $($hash.CrlDeltaPeriod)"

								if ($hash.Count -gt 0) 
									{return $hash}
							}

							if ($hash.Count -gt 0) {
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
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

		$myResult = GetADCSServiceAvailability -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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

function Insert-ADCSServiceAvailability {
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
[ManageDate] [datetime] NULL, `
[Subject] [nvarchar](200) NOT NULL, `
[Thumbprint] [nvarchar](100) NOT NULL, `
[NotAfter] [datetime] NOT NULL, `
[CrlState] [nvarchar](20) NOT NULL, `
[CrlPeriod] [nvarchar](20) NOT NULL, `
[CrlDeltaPeriod] [nvarchar](20) NOT NULL `
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
			,@IsError nvarchar(10) `
			,@Subject nvarchar(200) `
			,@Thumbprint nvarchar(100) `
			,@NotAfter datetime `
			,@CrlState nvarchar(20) `
			,@CrlPeriod nvarchar(20) `
			,@CrlDeltaPeriod nvarchar(20) ` 
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
			  [IsError], `
			  [Subject], `
			  [Thumbprint], `
			  [NotAfter], `
			  [CrlState], `
			  [CrlPeriod], `
			  [CrlDeltaPeriod]`
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
			  @IsError,`
			  @Subject, `
			  @Thumbprint, `
			  @NotAfter, `
			  @CrlState, `
			  @CrlPeriod, `
			  @CrlDeltaPeriod `
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
		
				<#
				for($k = 0;$k -lt $data[$i].PingAdmin.count;$k++) {$PingAdmin += $data[$i].PingAdmin[$k] + "<br/>"}
				for($j = 0;$j -lt $data[$i].Ping.count;$j++) {$Ping += $data[$i].Ping[$j] + "<br/>"}
				#>
				$PingAdmin = $data[$i].PingAdmin
				$Ping = $data[$i].Ping
				<#
				for($l = 0;$l -lt $data[$i].CrlPublishStatus.count;$l++) {$CrlPublishStatus += $data[$i].CrlPublishStatus[$l] + "<br/>"}
				for($m = 0;$m -lt $data[$i].DeltaCrlPublishStatus.count;$m++) {$DeltaCrlPublishStatus += $data[$i].DeltaCrlPublishStatus[$m] + "<br/>"}
				#>
				$CrlPublishStatus = $data[$i].CrlPublishStatus
				$DeltaCrlPublishStatus = $data[$i].DeltaCrlPublishStatus

				if ($data[$i].IsCACertExpiringInDays)
				{
					$ProbScrp = "CACertExpiringIn: $($data[$i].CACertificate.NotAfter.ToString("yyyy-MM-dd HH:mm:ss")) ($($data[$i].CACertificate.Subject))"
				} else {
					#$ProbScrp = "CAName(" + $data[$i].CAName + "); DNSName(" + $data[$i].DNSName + "); CAType(" + $data[$i].CAType + "); PingAdmin(" + $PingAdmin + "); Ping(" + $Ping + "); CrlPublishStatus(" + $CrlPublishStatus + "); DeltaCrlPublishStatus(" + $DeltaCrlPublishStatus + ")"
					#$ProbScrp = "CAName($($data[$i].CAName)); DNSName($($data[$i].DNSName)); CAType($($data[$i].CAType)); PingAdmin($($PingAdmin)); Ping($($Ping)); CrlPublishStatus($($CrlPublishStatus)); DeltaCrlPublishStatus($($DeltaCrlPublishStatus))"
					$ProbScrp = "CAName: $($data[$i].CAName)<br/>DNSName: $($data[$i].DNSName)<br/>CAType: $($data[$i].CAType)<br/>Ping: $($Ping)<br/>PingAdmin: $($PingAdmin)<br/>CrlPublishStatus: $($CrlPublishStatus)<br/>DeltaCrlPublishStatus: $($DeltaCrlPublishStatus)"
				}
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}

	} # End of function.

}

try {

	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADCSServiceAvailability"
	$ProcName = "IF_$($company)_ADCSServiceAvailability"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::StoredProcedure 

	$rowcount = 0

	if ($Data.count -gt 0)
	{
		for($i = 0;$i -lt $Data.count;$i++)
		{
 
			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
	
			$PingAdmin, $PingAdmin, $CrlPublishStatus, $DeltaCrlPublishStatus = $null
	
			if (! $data[$i].ComputerName) 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
       
			if (! $data[$i].OperatingSystem) 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
		
			if (! $data[$i].OperatingSystemServicePack) 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if (! $data[$i].CAName) 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", $data[$i].CAName)}
		
			if (! $data[$i].DNSName) 
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", $data[$i].DNSName)}
		
			if (! $data[$i].CAType) 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", $data[$i].CAType)}	
		
			if (! $data[$i].PingAdmin)
			{
				$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", "Null")
			} else {
				#for ($k = 0; $k -lt $data[$i].PingAdmin.count; $k++) {$PingAdmin += $data[$i].PingAdmin[$k] + "<br/>"}
				#$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", $PingAdmin)
				$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", $data[$i].PingAdmin)
			}
		
			if ($data[$i].Ping.count -eq 0)
			{
				$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", "Null")
			} else {
				#for($j = 0;$j -lt $data[$i].Ping.count;$j++) {$Ping += $data[$i].Ping[$j] + "<br/>"}
				#$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", $Ping)
				$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", $data[$i].Ping)
			}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		
			if ($data[$i].CrlPublishStatus.count -eq 0)
			{
				$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", "Null")
			} else {
				<#
				for($l = 0;$l -lt $data[$i].CrlPublishStatus.count;$l++) 
					{$CrlPublishStatus += $data[$i].CrlPublishStatus[$l] + "<br/>"}
				$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", $CrlPublishStatus)
				#>
				$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", $data[$i].CrlPublishStatus)
			}
		
			if ($data[$i].DeltaCrlPublishStatus.count -eq 0)
			{
				$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", "Null")
			} else {
				<#
				for($m = 0;$m -lt $data[$i].DeltaCrlPublishStatus.count;$m++) 
					{$DeltaCrlPublishStatus += $data[$i].DeltaCrlPublishStatus[$m] + "<br/>"}
				$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", $DeltaCrlPublishStatus)
				#>
				$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", $data[$i].DeltaCrlPublishStatus)
			}
		
			$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString());

			if (! $data[$i].CACertificate.Subject) 
				{$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@Subject", "Null")}
			else {$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@Subject", $data[$i].CACertificate.Subject)}

			if (! $data[$i].CACertificate.Thumbprint) 
				{$SQLParameter14 = New-Object System.Data.SqlClient.SqlParameter("@Thumbprint", "Null")}
			else {$SQLParameter14 = New-Object System.Data.SqlClient.SqlParameter("@Thumbprint", $data[$i].CACertificate.Thumbprint)}

			if (! $data[$i].CACertificate.NotAfter) 
				{$SQLParameter15 = New-Object System.Data.SqlClient.SqlParameter("@NotAfter", "Null")}
			else {$SQLParameter15 = New-Object System.Data.SqlClient.SqlParameter("@NotAfter", $data[$i].CACertificate.NotAfter)}

			if (! $data[$i].CrlDeltaPeriod) 
				{$SQLParameter16 = New-Object System.Data.SqlClient.SqlParameter("@CrlDeltaPeriod", "Null")}
			else {$SQLParameter16 = New-Object System.Data.SqlClient.SqlParameter("@CrlDeltaPeriod", $data[$i].CrlDeltaPeriod.ToString())}

			if (! $data[$i].CrlPeriod) 
				{$SQLParameter17 = New-Object System.Data.SqlClient.SqlParameter("@CrlPeriod", "Null")}
			else {$SQLParameter17 = New-Object System.Data.SqlClient.SqlParameter("@CrlPeriod", $data[$i].CrlPeriod.ToString())}

			if (! $data[$i].CrlState) 
				{$SQLParameter18 = New-Object System.Data.SqlClient.SqlParameter("@CrlState", "Null")}
			else {$SQLParameter18 = New-Object System.Data.SqlClient.SqlParameter("@CrlState", $data[$i].CrlState)}


			

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
			[void]$cmd.Parameters.Add($SQLParameter15)
			[void]$cmd.Parameters.Add($SQLParameter16)
			[void]$cmd.Parameters.Add($SQLParameter17)
			[void]$cmd.Parameters.Add($SQLParameter18)
					
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			$rowcount +=  1
		}
		Write-Host "[Services] inserted: $($Data.Count)" -Fore yellow

	}
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}
  }

}
if ($myResult) {Insert-ADCSServiceAvailability -Data $myResult}

# Get Enrollment Policy Templates.

try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	[array]$myResult = Invoke-Command -Session $session -script {
	param ($Credential, $Servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetADCSEnrollmentPolicyTemplate
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
								$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
								$hash.DomainName = $env:USERDNSDOMAIN
								$OS = Get-WmiObject Win32_OperatingSystem
								$hash.OperatingSystem = $OS.Caption
								$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()
								$hash.PSVersion = $PSVersionTable.PSVersion.Major
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
								$hash.IsError = $False
						
								<# CERTUTIL -CAINFO Name: Display CA name
									
								certutil -CAInfo name
								========
								CA name: dotnetsoft-DNPROD01-CA
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo name
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.CAName = $null
								} else {
									$hash.CAName = ($buf[0].Split(":"))[1].Trim()
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CAName: $($hash.CAName)"

								<# CERTUTIL -CAINFO dns: Display CA DNS Name

								certutil -CAInfo dns
								========
								DNS Name: DNPROD01.dotnetsoft.co.kr
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo dns
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.DNSName = $null
								} else {
									$hash.DNSName = ($buf[0].Split(":"))[1].Trim()
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.DNSName: $($hash.DNSName)"

								<# CERTUTIL -CAINFO type: Display CA Type
								# ENUM_CATYPES enumeration, http://msdn.microsoft.com/en-us/library/windows/desktop/bb648652(v=vs.85).aspx

								certutil -CAInfo type
								========
								CA type: 0 -- Enterprise Root CA
									ENUM_ENTERPRISE_ROOTCA -- 0
								CertUtil: -CAInfo command completed successfully.

								#>
								$buf = certutil -CAInfo type
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.CAType = $null
								} else {
									$buf | % {$hash.CAType = $buf[1].Trim()}
								}
								Write-Debug -Message "`$buf: $($buf)"
								Write-Debug -Message "`$hash.CAType: $($hash.CAType)"

								<# CERTUTIL –TEMPLATE: Display Certificate Enrollment Policy templates.
								
								(Certutil –Template | ? {$_ -match "TemplatePropCommonName = "}).Trim()

TemplatePropCommonName = Administrator
TemplatePropCommonName = ClientAuth
TemplatePropCommonName = AutoenrolledUser
TemplatePropCommonName = AutoEnrolUser
TemplatePropCommonName = EFS
TemplatePropCommonName = CAExchange
TemplatePropCommonName = CEPEncryption
TemplatePropCommonName = CodeSigning
TemplatePropCommonName = CodeSign_lgsvl.com
TemplatePropCommonName = Machine
TemplatePropCommonName = Copy of LG Electronics Inc. Code Signing
TemplatePropCommonName = Copy of LGE Web Server (5years) SHA256
TemplatePropCommonName = Copy of User
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
TemplatePropCommonName = LGElectronicsIncTMGWebServer
TemplatePropCommonName = LGElectronicsInc.HPPrinter
TemplatePropCommonName = LGElectronicsInc.WebServer
TemplatePropCommonName = LGECodeSigning
TemplatePropCommonName = LGElectronicsInc.User
TemplatePropCommonName = LGElectronicsInc.UserSHA256
TemplatePropCommonName = LGEWebServer (5years)
TemplatePropCommonName = LGEWebServer(5years)SHA256
TemplatePropCommonName = LGSSPSTG
TemplatePropCommonName = OCSPResponseSigning
TemplatePropCommonName = OCSPResponseSigningLGE
TemplatePropCommonName = RASAndIASServer
TemplatePropCommonName = CA
TemplatePropCommonName = OfflineRouter
TemplatePropCommonName = SmartcardLogon
TemplatePropCommonName = SmartcardUser
TemplatePropCommonName = SubCA
TemplatePropCommonName = test
TemplatePropCommonName = CTLSigning
TemplatePropCommonName = User
TemplatePropCommonName = UserSignature
TemplatePropCommonName = WebServer
TemplatePropCommonName = Wireless
TemplatePropCommonName = Workstation
								
								#>
								$buf = Certutil –Template
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$hash.CertEnrollPolicyTemplates = $buf[0]
								} else {
									$buf_outer = @()
									$buf | ? {$_ -match "TemplatePropCommonName = "} | % {$buf_outer += ($_.Split("=")[1].Trim())}
									$hash.CertEnrollPolicyTemplates = $buf_outer
								}
								Write-Debug -Message "`$buf_error: $($buf_error)"
								Write-Debug -Message "`$hash.CertEnrollPolicyTemplates: $($hash.CertEnrollPolicyTemplates)"

								<# CERTUTIL –CATEMPLATES: Display templates for CA.
								
								certutil -catemplates | % {$_.Substring(0, $_.IndexOf(":"))} | Sort

Administrator
CertUtil
DirectoryEmailReplication
DomainController
DomainControllerAuthentication
EFS
EFSRecovery
LGECodeSigning
LGElectronicsInc.HPPrinter
LGElectronicsInc.User
LGElectronicsInc.WebServer
LGElectronicsIncTMGWebServer
LGEWebServer (5years)
LGSSPSTG
Machine
OCSPResponseSigningLGE
SubCA
User
WebServer
								#>
								$buf = certutil -catemplates
								$buf_error = $False
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									#$hash.IsError = $True	# Do not set it error even if the command generates error or fail
									$hash.CATemplates = $buf[0]
								} else {
									$buf_outer = @()
									$buf[0..($buf.count-1-1)] | % {$buf_outer += $_.Split(":")[0].Trim()}
									$hash.CATemplates = $buf_outer
								}
								Write-Debug -Message "`$buf_error: $($buf_error)"
								Write-Debug -Message "`$hash.CATemplates: $($hash.CATemplates)"

								if ($hash.Count -gt 0) 
									{return $hash}

							}

							if ($hash.Count -gt 0) {
								Write-Debug -Message "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
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

		$myResult = GetADCSEnrollmentPolicyTemplate -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)
	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
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

function Insert-ADCSEnrollmentPolicyTemplate {
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
		
				if ($data[$i].CATemplates.count -gt 1)
				{
					for($j = 0; $j -lt $data[$i].CertEnrollPolicyTemplates.count; $j++) {$CertEnroll += $data[$i].CertEnrollPolicyTemplates[$j] + "; "}
				} else {
					$CertEnroll = $data[$i].CertEnrollPolicyTemplates
				}
				if ($data[$i].CATemplates.count -gt 1)
				{
					for($l = 0; $l -lt $data[$i].CATemplates.count; $l++) {$CATemplates += $data[$i].CATemplates[$l] + "; "}
				} else {
					$CATemplates = $data[$i].CATemplates
				}
				
				#$ProbScrp = "CAName(" + $data[$i].CAName + "); DNSName(" + $data[$i].DNSName + "); CAType(" + $data[$i].CAType + "); CertEnrollPolicyTemplates(" + $CertEnroll + "); CATemplates(" + $CATemplates + ")"
				$ProbScrp = "CAName: $($data[$i].CAName)<br/>DNSName: $($data[$i].DNSName)<br/>CAType: $($data[$i].CAType)<br/>CertEnrollPolicyTemplates: $($CertEnroll)<br/>CATemplates: $($CATemplates)"
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $DomainName)
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

		if ($rowcount) {Write-Host "[ProblemManagement] inserted: $($rowcount)" -fore yellow}
	}

}

try {

	$company = $DomainName.replace(".","_")
	$TableName = "TB_$($company)_ADCSEnrollmentPolicy"
	$ProcName = "IF_$($company)_ADCSEnrollmentPolicy"
	
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

			$CertEnroll = $null
		
			if (! $data[$i].ComputerName) 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
       
			if (! $data[$i].OperatingSystem) 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}

			if (! $data[$i].OperatingSystemServicePack) 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "0")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if (! $data[$i].CAName) 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", "Null")}		
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", $data[$i].CAName)}
		
			if (! $data[$i].DNSName) 
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", $data[$i].DNSName)}
		
			if (! $data[$i].CAtype) 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", $data[$i].CAtype)}
		
			if ($data[$i].CertEnrollPolicyTemplates.count -eq 0)
			{
				$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@CertEnrollPolicyTemplates", "Null")
			} else {
				#
				$buf_outer = $null
				foreach ($buf in $data[$i].CertEnrollPolicyTemplates)
				{
					$buf_outer += $buf + "; "
				}
				$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@CertEnrollPolicyTemplates", $buf_outer)
			}
		
			if ($data[$i].CATemplates.count -eq 0)
			{
				$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@CATemplates", "Null")
			} else {
				$buf_outer = $null
				foreach ($buf in $data[$i].CATemplates)
				{
					$buf_outer += $buf + "; "
				}
				$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@CATemplates", $buf_outer)
			}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		

			$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.toString());
        
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
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType EXCEPTION -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName -TaskScript $Message
}
finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}
  }

 }
if ($myResult) {Insert-ADCSEnrollmentPolicyTemplate -Data $myResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -DomainName $DomainName

