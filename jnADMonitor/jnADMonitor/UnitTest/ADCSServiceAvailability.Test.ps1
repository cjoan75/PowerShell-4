#
# ADCSServiceAvailability.Test.ps1
#


	[array]$jnADCSServiceAvailabilityResult = Invoke-Command -Session $session -script {
	param ($Credential, $servers, $myDebugPreference)

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
							Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {

								Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								$hash.ComputerName = $env:COMPUTERNAME
								$hash.DomainName = $env:USERDNSDOMAIN
								$OS = gwmi Win32_OperatingSystem
								$hash.OperatingSystem = $OS.Caption
								$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()
								$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
								$hash.IsError = $False
						
								<# CERTUTIL -CAINFO Name: Display CA name
									
								certutil -CAInfo name
								========
								CA name: dotnetsoft-DNPROD01-CA
								CertUtil: -CAInfo command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -CAInfo name
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.CAName += $_.TrimStart(" ")}
								} else {
									$buf | % {
										if ($_ -match "CA Name") {$hash.CAName += @($_.Substring($_.IndexOf("CA Name")+7+1+2))}
									}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CAName: $($hash.CAName)"

								<# CERTUTIL -CAINFO dns: Display CA DNS Name

								certutil -CAInfo dns
								========
								DNS Name: DNPROD01.dotnetsoft.co.kr
								CertUtil: -CAInfo command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -CAInfo dns
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.DNSName += $_.TrimStart(" ")}
								} else {
									$buf | % {
										if ($_ -match "DNS Name") {$hash.DNSName += @($_.Substring($_.IndexOf("Dns Name")+8+1+2))}
									}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.DNSName: $($hash.DNSName)"

								<# CERTUTIL -CAINFO type: Display CA Type
								# ENUM_CATYPES enumeration, http://msdn.microsoft.com/en-us/library/windows/desktop/bb648652(v=vs.85).aspx

								certutil -CAInfo type
								========
								CA type: 0 -- Enterprise Root CA
									ENUM_ENTERPRISE_ROOTCA -- 0
								CertUtil: -CAInfo command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -CAInfo type
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.CAType += $_.TrimStart(" ")}
								} else {
									$buf | % {
										if ($_ -match "ENUM_")
										{
											$buf_inner = $_.TrimStart(" "); 
											$hash.CAType += @($buf_inner.Substring($buf_inner.IndexOf("ENUM_"), $buf_inner.IndexOf(" ")))
										}
									}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CAType: $($hash.CAType)"

								<# certutil -ping: Attempt to contact the AD CS Request interface
									
								certutil -ping
								========
								Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...
								Server "dotnetsoft-DNPROD01-CA" ICertRequest2 interface is alive (0ms)
								CertUtil: -ping command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -ping
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.ping += $_.TrimStart(" ")}
								} else {
									$buf | % {
										if ($_ -match "Server """) {$hash.ping += @($_.TrimStart(" "))}
									}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.ping: $($hash.ping)"

								<# certutil -pingadmin: Attempt to contact the AD CS Admin interface
								
								certutil -pingadmin
								========
								Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...
								Server ICertAdmin2 interface is alive
								CertUtil: -pingadmin command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -pingadmin
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.pingadmin += $_.TrimStart(" ")}
								} else {
									$buf | % {
										if ($_ -match "Server ") {$hash.pingadmin += @($_.TrimStart(" "))}
									}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.pingadmin: $($hash.pingadmin)"

								<# certutil -CAInfo crlstatus: CRL Status

								certutil -CAInfo crlstatus
								========
								CRL Publish Status[0]: 0x45 (69)
									CPF_BASE -- 1
									CPF_COMPLETE -- 4
									CPF_MANUAL -- 40 (64)
								CertUtil: -CAInfo command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -CAInfo crlstatus
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.CrlPublishStatus += $_.TrimStart(" ")}
								} else {
									$buf | % {if ($_ -notmatch "Certutil: ") {$hash.CrlPublishStatus += @($_.TrimStart(" "))}}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CrlPublishStatus: $($hash.CrlPublishStatus)"

								<# certutil -CAInfo deltacrlstatus: Delta CRL Publish Status
								
								certutil -CAInfo deltacrlstatus
								========
								Delta CRL Publish Status[0]: 6
									CPF_DELTA -- 2
									CPF_COMPLETE -- 4
								CertUtil: -CAInfo command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -CAInfo deltacrlstatus
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.DeltaCrlPublishStatus += $_.TrimStart(" ")}
								} else {
									$buf | % {if ($_ -notmatch "Certutil: ") {$hash.DeltaCrlPublishStatus += @($_.TrimStart(" "))}}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.DeltaCrlPublishStatus: $($hash.DeltaCrlPublishStatus)"

								<# certutil -CAInfo crlstate: CRL State

								certutil -CAInfo crlstate
								========
								CRL[0]: 3 -- Valid
								CertUtil: -CAInfo command completed successfully.

								#>
								#$hash = @{}
								$buf_error = $False
								$buf = certutil -CAInfo crlstate
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
									$buf | % {$hash.CrlState += $_.TrimStart(" ")}
								} else {
									$buf | % {if ($_ -notmatch "Certutil: ") {$hash.CrlState += @($_.SubString($_.IndexOf("-- ")+3))}}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CrlState: $($hash.CrlState)"

								<# CA Certificate Info.
								
								gci Cert:\Localmachine\Root\ | ? {$_.Subject -like "CN=$($hash.CAName)*"} | sort Thumbprint -unique | select NotAfter, Subject | ft -a
								#>
								#$hash = @{}; $buf = certutil -CAInfo name; $buf | % {if ($_ -match "CA Name") {$hash.CAName += @($_.Substring($_.IndexOf("CA Name")+7+1+2))}};
								$buf_error = $False
								$buf = gci Cert:\Localmachine\Root\ | ? {$_.Subject -like "CN=$($hash.CAName)*"} | sort Thumbprint -unique
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
								} else {
									$buf | % {$hash.CACertificates += @($_)}
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CACertificates: $($hash.CACertificates)"

								<# Crl Validity Period Info.
								
								certutil -getreg CA\CrlPeriodUnits
								certutil -getreg CA\CrlPeriod
								certutil -getreg CA\CrlDeltaPeriodUnits
								certutil -getreg CA\CrlDeltaPeriod
								#>
								#$hash = @{}
								$buf_error = $False
								certutil -getreg CA\CrlPeriod | % {if ($_ -like '* = *') {$buf_metric = $_.SubString($_.IndexOf("= ")+2)}}
								certutil -getreg CA\CrlPeriodUnits | % {if ($_ -like '* = *') {[int]$buf_unit = $_.SubString($_.IndexOf("= ")+2)}}
								if ($buf_metric -eq 'Weeks') {$buf_unit = $buf_unit * 7}
								$hash.CrlPeriod = New-TimeSpan -Days $buf_unit
								certutil -getreg CA\CrlDeltaPeriod | % {if ($_ -like '* = *') {$buf_metric = $_.SubString($_.IndexOf("= ")+2)}}
								certutil -getreg CA\CrlDeltaPeriodUnits | % {if ($_ -like '* = *') {[int]$buf_unit = $_.SubString($_.IndexOf("= ")+2)}}
								if ($buf_metric -eq 'Weeks') {$buf_unit = $buf_unit * 7}
								$hash.CrlDeltaPeriod = New-TimeSpan -Days $buf_unit
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CrlPeriod: $($hash.CrlPeriod)"
								Write-Debug "`$hash.CrlDeltaPeriod: $($hash.CrlDeltaPeriod)"

								if ($hash.Count -gt 0) 
									{return $hash}

							}

							if ($hash.Count -gt 0) {
								Write-Debug "`$hash: $($hash.gettype()): $($hash.count)"
								return $hash
							}

						}
						Catch {
							$jnUTCMonitored = (Get-Date).ToUniversalTime()
							$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
							Write-Host $Message -fore red
						}
						Finally {
					
							# To free resources used by a script.

							# to close powershell remote session
							Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
							Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
						}

					}
				}
			}
		}

		$myResult = GetADCSServiceAvailability -Credential $Credential -Servers $Servers -DebugPreference $DebugPreference
		$myResult
		Write-Host "Data collected: $($myResult.Count)."

	} -ArgumentList ($credential, $servers, $DebugPreference)

