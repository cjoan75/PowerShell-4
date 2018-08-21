try {
	# to create powershell remote session
	$session = New-PSSession -cn $ManagedServerFQDN -credential $credential -Authentication Kerberos
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
							$session = New-PSSession -cn $server.ComputerName -Credential $credential -Authentication Kerberos
							Write-Debug -Message "session established: $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {
						
								Write-Debug -Message "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}

								# Active Directory module for Windows PowerShell is only available on Windows 7 (as part of RSAT) and Windows Server 2008 R2 and later verions of Windows.
								$OSVersion = [System.Environment]::OSVersion.Version
								if ($OSVersion.Major -eq 6 -and $OSVersion.Minor -ge 1)
								{
									if (! (Get-Module ActiveDirectory)) {Import-Module ActiveDirectory}
									$mydc = Get-ADDomainController
								}
								if ($mydc) {$hash.ComputerName = $mydc.HostName} else {$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"}
								if ($mydc) {$hash.OperatingSystem = $mydc.OperatingSystem} else {$hash.OperatingSystem = (Get-WmiObject Win32_OperatingSystem).caption}
								if ($mydc) {$hash.OperatingSystemServicePack = $mydc.OperatingSystemServicePack}
								else {
									if ((Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion -eq 0)
									{$hash.OperatingSystemServicePack = $null}
									else {$hash.OperatingSystemServicePack = (Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion.ToString()}
								}
								if ($mydc)
								{
									$hash.IsGlobalCatalog = $mydc.IsGlobalCatalog
									$hash.IsRODC = $mydc.IsReadOnly
									$hash.OperationMasterRoles = $mydc.OperationMasterRoles
								}
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

								# REPADMIN /REPLSUMMARY: Display the replication status for all domain controllers in the forest to Identify domain controllers that are failing inbound replication or outbound replication, and summarizes the results in a report.
								# NOTE: /bysrc /bydest: displays the /bysrc parameter table first and the /bydest parameter table next. 
								$buf_command = @(REPADMIN /REPLSUMMARY $env:COMPUTERNAME /BYSRC /BYDEST /sort:delta | ? {$_})

								$hash.IsError = $False
								for ($I = 4; $I -lt $buf_command.count -2; $I++)
								{
									if ($buf_command[$I] -match ":")
									{
										[string]$buf_str = $buf_command[$I].Split("/")[0].Trim()
										[int]$buf_str = $buf_str.Split(" ")[-1].Trim()
										if ($buf_str -gt 0) {$hash.IsError = $True}
									}
								}
								$hash.repadmin = $buf_command[3..($buf_command.count-1-2)]
						
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

		$myResult = GetADDSReplicationResult -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult

	} -ArgumentList ($credential, $Servers, $DebugPreference)

	$myResult | % {"$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
	Write-Host "returned: $($myResult.Count), $($session.ComputerName)"
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "$($ServiceFlag)_RPL: ERROR: $($Error[0])"
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

