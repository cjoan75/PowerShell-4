param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ManagedServerFQDN
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$userPrincipalName
)

# .\Test-jnConnection-v3.ps1 -ManagedServerFQDN "LGEADPMSE6Q.LGE.NET" -userPrincipalName "monitor_admin@LGE.NET"

$ServiceFlag = "CONNECT"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:USERPROFILE\Documents\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: The credential file not found: $FilePath"

	Insert-MonitoringTaskLogs -TaskType BEGIN -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -TaskScript $Message
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"

$TB_Servers = "TB_SERVERS2"
[array]$Servers = Get-SQLData -TableName $TB_Servers -Domain $DomainName | Sort ComputerName -Unique
if ($Servers)
{
	Write-Host "Servers Retrieved: $($Servers.Count)"
} else {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: No servers returned."

	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -TaskScript $Message
}

# Log the BEGIN time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType BEGIN -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored

# Get connection status.

try {
	# to create powershell remoting session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)"

	# to connect to the Managed Server in the domain.
	[array]$myResult = Invoke-Command -Session $session -script {
	param ($Servers)

		Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

		workflow GetConnectionStatus
		{
			param ([array]$Servers)

			foreach -Parallel ($server in $Servers)
			{
				Sequence
				{
					$hash = @{}
					$hash += @{"ComputerName" = $server.ComputerName}
					$hash += @{"jnUTCMonitored" = (Get-Date).ToUniversalTime()}
					$hash += @{"jnServiceFlag" = "CONNECT"}
		
					$hash += @{"CanPing" = $(Test-Connection $server.ComputerName -Count 1 -Quiet)}
					$buf = InlineScript {
function Test-jnTcpPort2
{
<#
	.SYNOPSIS
	Determines whether the port from the remote computer is open.
	
	.EXAMPLE
	Determines the remote computer's port is open.
	
	$computerName = @('Dndc01.dotnetsoft.co.kr')
	$computerName += @('Dnex05.dotnetsoft.co.kr')
	
	$Ports = @(3389, 5985)
	Foreach ($port in $ports)
	{
		Test-jnTcpPort2 -ComputerName $computerName -Port $port
	}
	
	.EXAMPLE
	Tests the remote machine's port open for Active Directory. Just refer to the article, How to configure a firewall for domains and trusts, http://support.microsoft.com/kb/179442.
	
	$computerName = @('Dndc01.dotnetsoft.co.kr')
	$computerName += @('Dnprod05.dotnetsoft.co.kr')
	$Ports = @(53, 88, 135, 389, 636, 445, 3268, 3269)
	Foreach ($port in $ports)
	{
		Test-jnTcpPort2 -ComputerName $computerName -Port $port
	}
	
	.EXAMPLE
	Tests the remote machine's port open for Exchange Server. Just refer to the article, Network ports for clients and mail flow in Exchange 2013, https://technet.microsoft.com/en-us/library/bb331973(v=exchg.150).aspx.
	
	$computerName = @('DnEX04.dotnetsoft.co.kr')
	$computerName += @('DnEX05.dotnetsoft.co.kr')
	
	$Ports = @(443, 80, 25, 587)
	Foreach ($port in $ports)
	{
		Test-jnTcpPort2 -ComputerName $computerName -Port $port
	}
	
	.PARAMETER Port
	Specifies the port number to verify.
	
	.Link
	https://gallery.technet.microsoft.com/scriptcenter/97119ed6-6fb2-446d-98d8-32d823867131
	
#>
param
(
	[parameter(mandatory=$true)]
	[string[]]$ComputerName
	
	, [parameter()][ValidateRange(1, 65535)]
	[int]$Timeout=1000
	
	, [parameter()][ValidateRange(1, 65535)]
	[int]$Port = 5985
)
	$myResult = @()
	ForEach ($Computer in $ComputerName)
	{
		$open = $false
		
		# Create object for connecting to port on computer
		$tcpobject = New-Object -TypeName System.Net.Sockets.TcpClient
		Write-Debug -Message "Connected: $($tcpobject.Connected)";
		
		# Connect to remote machine's port
		$connect = $tcpobject.BeginConnect($Computer, $Port, $null, $null)
		Write-Debug -Message "BeginConnect: $($connect.IsCompleted); Connected: $($tcpobject.Connected)"
		
		# Configure a timeout before quitting
		$wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
		
		# If timed out
		if (! $wait)
		{
			$tcpobject.Close()
			$Result = "Timed Out"
		} else {
			
			try
			{
				$tcpobject.EndConnect($connect) | out-Null
				Write-Debug -Message "EndConnect: $($connect.IsCompleted); Connected: $($tcpobject.Connected)";
				$open = $true
				$Result = 'Success'
			}
			catch {$Result = "ERROR: $(Error[0])"}
			finally {$tcpobject.Close()}
		}
		
		$properties = @{
			Computer = $Computer
			Port = $Port
			Open = $open
			Result = $Result
		}
		$obj = New-Object -TypeName PSObject -Property $properties
		If ($obj) {$myResult += $obj}
	}
	if ($myResult) {Return $myResult;}
}

						(Test-jnTcpPort2 -ComputerName $using:server.ComputerName -Port 5985).Open
					}
					$hash += @{"CanPort5985" = $buf}
		
					if ($hash.CanPing -AND $hash.CanPort5985) 
						{$hash += @{"IsError" = $False}}
					else {$hash += @{"IsError" = $True}}

					Write-Debug -Message "`$hash: $($hash.count); $($hash.gettype()); $($server.ComputerName)"
					$hash
				}
			}
		}

		$myResult = GetConnectionStatus -Servers $Servers
		$myResult

	} -ArgumentList (, $Servers)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
	$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -TaskScript $Message
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

function Insert-Connection {
param (
	[Parameter(Mandatory=$True)][array]$Data
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
[ComputerName] [nvarchar](100) NOT NULL, `
[CanPing] [nvarchar](5) NOT NULL, `
[CanPort135] [nvarchar](5) NOT NULL, `
[CanPort5985] [nvarchar](5) NOT NULL, `
[UTCMonitored] [datetime] NOT NULL, `
PRIMARY KEY (ComputerName, UTCMonitored) `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
			@computername nvarchar(100) `
			,@CanPing nvarchar(5) `
			,@CanPort135 nvarchar(5) `
			,@CanPort5985 nvarchar(5) `
			,@UTCMonitored datetime`
	AS`
	BEGIN`
	`
	INSERT INTO [dbo].[$($TableName)] `
			( [ComputerName] `
			,[CanPing] `
			,[CanPort135] `
			,[CanPort5985] `
			,[UTCMonitored] `
			) `
			VALUES`
			( @ComputerName` 
			,@CanPing`
			,@CanPort135`
			,@CanPort5985`
			,@UTCMonitored`
			) `
`
	END'`
	) `
END"

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

} # End of function.

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][array]$Data
)
	$procName = "IF_ProblemManagement2"

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
				if ($data[$i].CanPing -eq $False -and $data[$i].CanPort5985 -eq $False)
					{$ProbScrp = "Failed to connect to " + $data[$i].ComputerName + "."}
				else {
					if ($data[$i].CanPing -eq $False)
						{$ProbScrp = "Failed to ping " + $data[$i].ComputerName + "."}
					elseif ($data[$i].CanPort5985 -eq $False)
						{$ProbScrp = "Failed to WinRM port query  " + $data[$i].ComputerName + "."}
				}

				#>
				if ($data[$i].CanPing -eq $False)
					{$ProbScrp = "Failed to ping: " + $data[$i].ComputerName + "."}
				if ($data[$i].CanPort5985 -eq $False)
					{$ProbScrp = "Failed to query WinRM: " + $data[$i].ComputerName + "."}

				$serviceitem = $null
				switch($Data[$i].jnServiceFlag)
				{
					"CONNECT" {$serviceitem = "CN01"; Break}
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
	$TableName = "TB_$($company)_CONNECTIVITY"
	$ProcName = "IF_$($company)_CONNECTIVITY"
	
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

			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)
			$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
	
			if (! $data[$i].CanPing)
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CanPing", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CanPing", $data[$i].CanPing.Tostring())}

			if (! $data[$i].CanPort135)
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@CanPort135", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@CanPort135", $data[$i].CanPort135.Tostring())}

			if (! $data[$i].CanPort5985)
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@CanPort5985", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@CanPort5985", $data[$i].CanPort5985.Tostring())}

			$cmd.Parameters.Clear()
               
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter5)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter3)
			[void]$cmd.Parameters.Add($SQLParameter2)

			Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
			Write-Debug -Message "CommandText: $($cmd.CommandText)."

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
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -TaskScript $Message
}
Finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}

} # End of Finally.

} # End of Function.
if ($myResult) {Insert-Connection -Data $myResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored

