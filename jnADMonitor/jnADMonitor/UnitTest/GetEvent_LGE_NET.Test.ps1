#
# GetEvent.ps1
#

$ManagedServerFQDN = "LGEADPMSE6Q.LGE.NET"
$userPrincipalName = "monitor_admin@LGE.NET"

$ServiceFlag = "RADIUS"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:USERPROFILE\Documents\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
} else {
	$Message = "The credential file NOT found: $FilePath"; 
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"

$TableName = "TB_SERVERS2"
[array]$Servers = Get-SQLData -TableName $TableName -Domain $DomainName -ServiceFlag $ServiceFlag
if ($Servers)
{
	Write-Host "Servers Retrieved: $($Servers.Count)"
} else {
	$Message = "No Servers Retrieved."
    $jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ServiceType $ServiceFlag -jnUTCMonitored $jnUTCMonitored -TaskScript $Message
}

<#
PS C:\Users\AdMonAdm> $Servers[0..15].ComputerName
AICHQ10-DC14.LGE.NET
AICHQ10-DC15.LGE.NET
AICHQ10-DC16.LGE.NET
AK-MF10-DC13.LGE.NET
AP-SO10-DC11.LGE.NET
AZ-MF10-DC11.LGE.NET
BSNDR10-NS10.LGE.NET
CB-SO10-DC11.LGE.NET
CHJMF10-DC10.LGE.NET
CHLMF10-DC10.LGE.NET
CHRRD10-DC10.LGE.NET
CICHQ10-DC13.LGE.NET
CICHQ10-DC15.LGE.NET
CI-SO10-DC12.LGE.NET
EG-MF10-DC10.LGE.NET
ES-SO10-DC12.LGE.NET
#>
$Servers = $Servers | ? ComputerName -like "C*"

<#
$domServers = Get-ADDomainController -Filter *
$Servers = $domServers | select *, @{Name='ComputerName'; Expression={$_.HostName}}
#>
$Servers.Count

#$EventIdExclusionString = '$_.ID -ne 0'
#$EventIdExclusionString = '$_.ID -ne 5722 -And $_.ID -ne 5723 -And $_.ID -ne 5805 -And $_.ID -ne 5719'


	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$myResult = Invoke-Command -Session $session -script {
		param ($Credential, $servers, $myDebugPreference)

		$DebugPreference = $myDebugPreference

		workflow GetRADIUSServiceAvailabilityResult
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
							Write-Debug "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							[array]$buf = Invoke-Command -Session $session -script {

								Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"RADIUS"}}
								$begindate = (Get-Date).AddHours(-1*1)

								# For debug purpose, you can look up the log that saved at the workflow target computers.
								# invoke-command -cn $Servers.ComputerName -Credential $credential -Authentication Kerberos -script {type "$env:temp\$($env:computername)_admon.log"}
								"[$($jnUTCMonitored)] EventIDExclusionString: $($EventIdExclusionString)" | Add-Content -Encoding Unicode -Path "$env:Temp\$($env:COMPUTERNAME)_admon.log"

								$command = "Get-WinEvent -FilterHashTable @{LogName = 'Security'; StartTime = `$begindate; ID = 6273, 6274 } -ea 0 | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf = invoke-expression $command
								if ($buf)
								{
									Write-Debug "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}

							}
                        
							if ($buf)
							{
								Write-Debug "returned: $($buf.Count), $($session.ComputerName)"
								return $buf
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
							$Message = "ERROR: $($Error[0])"

						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug "session closed: $($session.ComputerName)."
							}
						}

					}
				}
			}
		}

		$myResult = GetRADIUSServiceAvailabilityResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $servers, $DebugPreference)
	$myResult | group ComputerName | sort Count
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
	





$Data = $myResult;

		for($i = 0;$i -lt $Data.count;$i++) {
			if ($Data[$i].count -eq 0) {continue}

<#
Event ID 6273, Security: Reason Code 8 (bad username or password)
Event ID 6273, Security: Reason code 23 (bad/missing certificate)
Event ID 6273, Security: Reason Code 48 (bad network policy)
Event ID 6273, Security: Reason Code 49 (bad request policy)
Event ID 6273, Security: Reason Code 66 (auth settings mismatch)
Event ID 6273, Security: Reason Code 265 (untrusted CA)

Common Wireless RADIUS Configuration Issues
https://documentation.meraki.com/MR/Encryption_and_Authentication/Common_Wireless_RADIUS_Configuration_Issues

Event ID 6274, Security: Reason Code 3
Event ID 6274, Security: Reason Code 262

#>
			if ($data[$i].ID -eq "6273" -or $data[$i].ID -eq "6274")
			{
				$ReasonCode = $data[$i].Message
				$ReasonCode = $ReasonCode.Substring($ReasonCode.IndexOf("Reason Code:"))
				$ReasonCode = $ReasonCode.Split("`n")[0]
				$ReasonCode = $ReasonCode.Split(":")[1].Trim()
				if (
					(($data[$i].ID -eq "6273") -AND ($ReasonCode -eq "23" -or $ReasonCode -eq "48" -or $ReasonCode -eq "49" -or $ReasonCode -eq "66" -or $ReasonCode -eq "265")) `
					-or (($data[$i].ID -eq "6274") -and ($ReasonCode -eq "3" -or $ReasonCode -eq "262"))
				)
				{
					$ProbScrp = "Event ID: " + $data[$i].ID + ", Reason Code: " + $ReasonCode
				}
				if ($data[$i].ID -eq "6274") {Write-Host $ProbScrp}

			} # End of If it contains Critical or Error event, not Warning.

		} # End of For.

