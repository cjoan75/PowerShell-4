#
# AuditMembershipChange.ps1
#

$ManagedServerFQDN = "dndc01.dotnetsoft.co.kr"
$userPrincipalName = "admin2@dotnetsoft.co.kr"

$ServiceFlag = "ADDS"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:USERPROFILE\Documents\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"


<#
Event IDs for membership changes

4756	A member was added to a security-enabled universal group.
4757	A member was removed from a security-enabled universal group.
4732	A member was added to a security-enabled local group.
4733	A member was removed from a security-enabled local group.
4728	A member was added to a security-enabled global group.
4729	A member was removed from a security-enabled global group.

ID = 4756, 4757, 4732, 4733, 4728, 4729

PS C:\Users\Jino> (get-adgroup "domain admins").GroupScope
Global

PS C:\Users\Jino> (get-adgroup "enterprise admins").GroupScope
Universal

PS C:\Users\Jino> (get-adgroup "administrators").GroupScope
DomainLocal

#>

	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential
	Write-Host "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

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
							Write-Debug "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							[array]$buf = Invoke-Command -Session $session -script {
								param ($EventIdExclusionString, $ServiceFlag)

								Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={$ServiceFlag}}
								$begindate = (Get-Date).AddHours(-1*1)

								# For debug purpose, you can look up the log that saved at the workflow target computers.
								# invoke-command -cn $Servers.ComputerName -Credential $credential -Authentication Kerberos -script {type "$env:temp\$($env:computername)_admon.log"}
								$Message = "[$($jnUTCMonitored)] EventIDExclusionString: $($EventIdExclusionString)"
								$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"

								$command = "Get-WinEvent -FilterHashTable @{ProviderName = 'Active Directory Web Services', 'Microsoft-Windows-Directory-Services-SAM', 'Microsoft-Windows-ActiveDirectory_DomainService', 'Microsoft-Windows-DirectoryServices-DSROLE-Server', 'Microsoft-Windows-DirectoryServices-LSADB', 'Microsoft-Windows-DirectoryServices-Deployment', 'Microsoft-Windows-GroupPolicy', 'DSReplicationProvider', 'DFS Replication', 'File Replication Service', 'Netlogon', 'LSA', 'LsaSrv'; StartTime = `$begindate; Level = 1, 2, 3 } -ea 0 | ? { $EventIdExclusionString } | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf = invoke-expression $command

<#
[array]$buf = Invoke-Command -Session $session -script {
$begindate = (Get-Date).AddHours(-1*1)
$command = "Get-WinEvent -FilterHashtable @{LogName = 'Security'; StartTime = `$begindate; ID = 4756, 4757, 4732, 4733, 4728, 4729} -ea 0 | sort TimeCreated"
$buf = Invoke-Expression $command
$buf
}
$buf.count

foreach ($b in $buf)
{
	$userName = (($b.Message.Split("`n"))[10].Split(":"))[1].Trim()
	$groupName = (($b.Message.Split("`n"))[14].Split(":"))[1].Trim()
	Write-Host "ID: $($b.Id), GroupName: $($groupName), Member: $($userName)"
}
#>
								# Audits AD Group membership changes
								$command = "Get-WinEvent -FilterHashtable @{LogName = 'Security'; StartTime = `$begindate; ID = 4756, 4757, 4732, 4733, 4728, 4729} -ea 0 | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf += invoke-expression $command
								
								$buf = $buf | sort TimeCreated
								if ($buf)
								{
									Write-Debug "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}

							} -ArgumentList ($EventIdExclusionString, $ServiceFlag)
                        
							if ($buf)
							{
								Write-Debug "returned: $($buf.Count), $($session.ComputerName)"
								return $buf
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss")
							$Message = "$($jnUTCMonitored): ERROR: $($Error[0])"

							$Message | Add-Content -Encoding Unicode -Path "$env:USERPROFILE\Documents\$($env:COMPUTERNAME)_ADMON.log"
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

		$myResult = GetADDSEventResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference -EventIdExclusionString $EventIdExclusionString -ServiceFlag $ServiceFlag

		# Unlike Level, LevelDisplayName is null on Windows Server 2008 or earlier versions.
		foreach ($buf in ($myResult | ? LevelDisplayName -eq $null))
		{
			switch ($buf.Level)
			{
				1 {$buf.LevelDisplayName = "Critical"}
				2 {$buf.LevelDisplayName = "Error"}
				3 {$buf.LevelDisplayName = "Warning"}
				4 {$buf.LevelDisplayName = "Information"}
				Default {$LevelDisplayName = $null}
			}
		}
		$myResult

	} -ArgumentList ($credential, $servers, $DebugPreference, $EventIdExclusionString, $ServiceFlag)
	$myResult | group ComputerName | sort Count
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"

