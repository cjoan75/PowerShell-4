#
# ForeachParallelTest.ps1
#
<#
$domServers = Get-ADComputer -Filter "Enabled -eq 'true' -and OperatingSystem -like '*server*'" -Properties OperatingSystem
$Servers = $domServers | select *, @{Name='ComputerName'; Expression={$_.DNSHostName}}
$Servers.Count
#>

workflow GetConnectionStatus
{
	param ([array]$Servers)

	foreach -Parallel ($server in $servers)
	{
		Sequence
		{
			$hash = @{}
			$hash += @{"ComputerName" = $server.ComputerName}
			$hash += @{"jnUTCMonitored" = (Get-Date).ToUniversalTime()}
			$hash += @{"jnServiceFlag" = "CONNECT"}
		
			Write-Debug "Connecting to: $($server.ComputerName)"
			$hash += @{"CanPing" = $(Test-Connection $server.ComputerName -Count 1 -Quiet)}
			if ($hash.CanPing)
			{
				$hash += @{"CanPort5985" = $(Test-NetConnection -ComputerName $server.ComputerName -Port 5985 -InformationLevel Quiet)}
				$hash += @{"CanPort135" = $(Test-NetConnection -ComputerName $server.ComputerName -Port 135 -InformationLevel Quiet)}
			} else {
				$hash += @{"CanPort5985" = $False}
				$hash += @{"CanPort135" = $False}
			}
		
			if ($hash.CanPing -AND $hash.CanPort5985) 
				{$hash += @{"IsError" = $False}}
			else {$hash += @{"IsError" = $True}}

			Write-Debug "Error found: $($hash.IsError), $($hash.ComputerName)"
			$hash
		}
	}
}

$servers = @($servers | Sort ComputerName -Unique)
[array]$myResult = GetConnectionStatus -Servers $servers
Write-Host "Data collected: $($myresult.Count)."


workflow Test-InlineScript
{
	$innerarray = @("apple", "banana")
	InlineScript
	{
		"1"
		Write-Output (Get-Date)
		Write-Debug "debug message"
		Write-Verbose "Verbose message"
		Write-Error "Error message"
		return $using:innerarray
	}
	
}

Test-InlineScript -Verbose


workflow Test-Workflow
{
	param ([array]$Servers)

	foreach -parallel ($server in $servers)
	{
		$hash = @{}
		$hash += @{"name" = $server.computername}
		if ($hash.Count -gt 0)
		{
			$hash
		}
	}
}

Test-Workflow -Servers $Servers


workflow wf1
{
	workflow wf11
	{
		Write-Output $false
	}

	workflow wf12
	{
		if (wf11) {Write-Output "Done"} else {Write-Output "Fuck"}
	}
	wf12
}
wf1


workflow wf1
{
	workflow wf11
	{
		try
		{
			$ErrorActionPreference = "stop"

			foreach -parallel ($a in (1,2,3,4))
			{
				Write-Output $a
			}
		Write-Output $false

		}
		catch {throw}
		finally {}
	}

	workflow wf12
	{
		if (wf11) {Write-Output "Done"} else {Write-Output "Fuck"}
	}
	wf12
}
wf1

# RADIUS Service Availability: Event id 6723, 6724 Reason code Addition.
<#
$string = @"
MT-SO10-DC11.LGE.NET
VN-SM10-DC15.LGE.NET
CICHQ10-DC15.LGE.NET
LGEADNS01.LGE.NET
LGECWMFNS01.LGE.NET
NB-MF10-DC10.LGE.NET
LGEEUADCAL4Q.LGE.NET
AICHQ10-DC15.LGE.NET
CB-SO10-DC11.LGE.NET
HLBRD10-NS11.LGE.NET
HLBRD10-NS10.LGE.NET
AICHQ10-DC16.LGE.NET
"@
[array]$arr = $string.Split("`n")
$Servers = $Servers | ? ComputerName -In $arr
#>

<#
LogName: Security
Event ID 6273 with reason code 23 (bad/missing certificate)
Event ID 6273 Reason Code 48 (bad network policy)
Event ID 6273 Reason Code 49 (bad request policy)
Event ID 6273 Reason Code 66 (auth settings mismatch)
Event ID 6273 Reason Code 8 (bad username or password)
Event ID 6273 Reason Code 265 (untrusted CA)

LogName: System
Event ID 13:  A RADIUS message was received from the invalid RADIUS client (APs not added as clients)
Event ID 18: An Access-Request message was received from RADIUS client x.x.x.x with a Message-Authenticator attribute that is not valid (bad shared secret)
#>

<#
			$command = "Get-WinEvent -LogName 'Security' -MaxEvents 10000 -ea 0 | ? {`$_.TimeCreated -gt `$begindate} | ? {`$_.Id -eq 6723}"
			$command += " | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								
			[array]$buf = Invoke-Expression $command

#>

[array]$myResult = Invoke-Command -cn $ManagedServerFQDN -Credential $credential -ScriptBlock {
	
	$myResult = @()
	foreach ($server in $using:Servers)
	{
		[array]$buf = Invoke-Command -cn $server.ComputerName -Credential $using:credential -ScriptBlock {

								$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={$ServiceFlag}}
								$begindate = (Get-Date).AddHours(-1*24*180)

			$buf = Get-WinEvent -FilterHashTable @{LogName = 'Security'; StartTime = $begindate; ID = 6723 } -ea 0 `
				 | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag

			if ($buf) {return $buf}
		}
		$myResult += $buf
	}
	return $myResult;
}
$myResult.Count


