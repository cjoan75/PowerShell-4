#
# GetEvent.ps1
#
$ManagedServerFQDN = "dndc01.dotnetsoft.co.kr"
$userPrincipalName = "admin2@dotnetsoft.co.kr"

$ServiceFlag = "ADDS"
$DomainName = $ManagedServerFQDN.SubString($ManagedServerFQDN.IndexOf(".")+1)
$FilePath = "$env:temp\$($userPrincipalName).cred"
if (Test-Path $FilePath)
{
	$credential = Import-Clixml -Path $FilePath
} else {
	$Message = "The credential file NOT found: $FilePath"; 
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
}
Write-Host "`nReady for $($ManagedServerFQDN) (logged on as $($credential.UserName))`n"

$domServers = Get-ADComputer -Filter "Enabled -eq 'true' -and OperatingSystem -like '*server*'" -Properties OperatingSystem
$Servers = $domServers | ? Name -ne 'HiFilm' | select *, @{Name='ComputerName'; Expression={$_.DNSHostName}}
<#
$domServers = Get-ADDomainController -Filter *
$Servers = $domServers | select *, @{Name='ComputerName'; Expression={$_.HostName}}
#>
$Servers.Count

$EventIdExclusionString = '$_.ID -ne 0'
#$EventIdExclusionString = '$_.ID -ne 5722 -And $_.ID -ne 5723 -And $_.ID -ne 5805 -And $_.ID -ne 5719'


	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential -Authentication Kerberos
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
							$session = New-PSSession -cn $server.ComputerName -credential $Credential -Authentication Kerberos
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
								"[$($jnUTCMonitored)] EventIDExclusionString: $($EventIdExclusionString)" | Add-Content -Encoding Unicode -Path "$env:Temp\$($env:COMPUTERNAME)_admon.log"

								$command = "Get-WinEvent -FilterHashTable @{ProviderName = 'Active Directory Web Services', 'Microsoft-Windows-Directory-Services-SAM', 'Microsoft-Windows-ActiveDirectory_DomainService', 'Microsoft-Windows-DirectoryServices-DSROLE-Server', 'Microsoft-Windows-DirectoryServices-LSADB', 'Microsoft-Windows-DirectoryServices-Deployment', 'Microsoft-Windows-GroupPolicy', 'DSReplicationProvider', 'DFS Replication', 'File Replication Service', 'Netlogon', 'LSA', 'LsaSrv'; StartTime = `$begindate; Level = 1, 2, 3 } -ea 0 | ? { $EventIdExclusionString } | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, Level, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								[array]$buf = invoke-expression $command
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




