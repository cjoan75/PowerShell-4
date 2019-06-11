#
# DHCP.ps1
#
								$hash = @{}
								$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
								$hash.DomainName = $env:USERDNSDOMAIN
								$OS = gwmi Win32_OperatingSystem
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
								$uri = "http://files.thecybershadow.net/dhcptest/dhcptest-0.7-win64.exe"

								$FilePath = "$env:USERPROFILE\Downloads\" + $uri.Substring($uri.LastIndexOf("/")+1)
								if (! (Test-Path $FilePath)) {Invoke-RestMethod -URI $uri -OutFile $FilePath}
								if (Test-Path $FilePath)
								{
									$hash.IsAvailableByClient = $False
									if (& $FilePath --Query --Quiet) {$hash.IsAvailableByClient = $True}
								}

