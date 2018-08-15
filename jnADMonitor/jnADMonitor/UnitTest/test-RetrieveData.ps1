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
							Write-Debug "Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."
							Write-Debug $EventIdExclusionString
							Write-Debug $ServiceFlag

							[array]$buf = Invoke-Command -Session $session -script {
								param ($EventIdExclusionString, $ServiceFlag)

								Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName}}
								$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
								$jnServiceFlag = @{Name="jnServiceFlag"; Expression={$ServiceFlag}}
								$begindate = (Get-Date).AddHours(-1*24)

								<#
								$command = "Get-WinEvent -FilterHashTable @{ProviderName = 
									'Active Directory Web Services'
									, 'Microsoft-Windows-Directory-Services-SAM'
									, 'Microsoft-Windows-ActiveDirectory_DomainService'
									, 'Microsoft-Windows-DirectoryServices-DSROLE-Server'
									, 'Microsoft-Windows-DirectoryServices-LSADB'
									, 'Microsoft-Windows-DirectoryServices-Deployment'
									, 'Microsoft-Windows-GroupPolicy'
									, 'DSReplicationProvider'
									, 'DFS Replication'
									, 'File Replication Service'
									, 'Netlogon'
									, 'LSA'
									, 'LsaSrv'; StartTime = `$begindate; Level = 1, 2, 3 } -ea 0"
								#>
$EventIdExclusionString = '$_.ID -ne 1083 -AND $_.ID -ne 2887 -AND $_.ID -ne 5719 -AND $_.ID -ne 5722 -AND $_.ID -ne 5723 -AND $_.ID -ne 5805 -AND $_.ID -ne 5807 -AND $_.ID -ne 6314 -AND $_.ID -ne 7016'
								$command = "Get-WinEvent -FilterHashTable @{LogName='System'; StartTime = `$begindate; Level = 1, 2, 3 }"
								#$command += " | ? {" + $EventIdExclusionString + "}"
								#$command += " | sort TimeCreated | select LogName, TimeCreated, Id, ProviderName, LevelDisplayName, Message, `$jnComputerName, `$jnUTCMonitored, `$jnServiceFlag"
								
								[array]$buf = Invoke-Expression $command
								if ($buf)
								{
									Write-Debug "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN): $($buf.GetType()), $($buf.count)."
									return $buf
								}

							} -ArgumentList ($EventIdExclusionString, $ServiceFlag)
                        
							if ($buf)
							{
								Write-Debug "`$buf: $($buf.Count); $($buf.GetType()); $($session.ComputerName)"
								return $buf
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
							$Message = "ERROR: $($Error[0])"
							#throw $Message
						}
						Finally {
						
							# To free resources used by a script.

							# to close powershell remote session
							if ($session)
							{
								Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
								Write-Debug "Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
							}
						}
					}
				}
			}
		}

		$myResult = GetADDSEventResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference -EventIdExclusionString $EventIdExclusionString -ServiceFlag $ServiceFlag
$myResult.count
