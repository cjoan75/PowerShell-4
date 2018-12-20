$strings = @'
function GetComputerInfo
{
	$property = @{
		ComputerName = $env:COMPUTERNAME;
		PSVersion = $PSVersiontable.PSVersion;
		BuildVersion = $PSVersiontable.BuildVersion;
		ClrVersion = $PSVersiontable.CLRVersion;
	}
						
	# Get Hardware Information
						
	$buf = gwmi Win32_BIOS
	$BIOSAge = @{Label="BIOSAge";Expression={if ($_.ReleaseDate) {(Get-Date) - $_.ConvertToDateTime($_.ReleaseDate)}}}
	$property += @{
		BIOSManufacturer = $buf.Manufacturer;
		BIOSSerialNumber = $buf.SerialNumber;
		BIOSBIOSVersion = $buf.SMBIOSBIOSVersion;
		BIOSAgeDays = ($buf | select $BIOSAge).BiosAge.Days;
	}
						
	# Get Computer system Information
						
	$buf = gwmi Win32_ComputerSystem
	$property += @{
		CSModel = $buf.Model;   # Identifies if it's a virtual machine.
		CSBootupState = $buf.BootupState;
		CSDomain = $buf.Domain;
		CSDomainRole = $buf.DomainRole;
		CSSystemType = $buf.SystemType;
	}
						
	# Get Operating System Information
						
	$buf = gwmi Win32_OperatingSystem
	$property += @{
		OSVersion = $buf.Caption;
		OSVersionServicePackMajor = $buf.ServicePackMajorVersion;
		OSLanguage = $buf.OSLanguage;
		OSMUILanguages = $buf.MUILanguages;
		OSArchitecture = $buf.OSArchitecture;
		OSSystemDevice = $buf.SystemDevice;
		OSSystemDirectory = $buf.SystemDirectory;
	}
						
	# gets processor Information
						
	$buf = gwmi Win32_Processor
	$property += @{
		Processor = $buf.Name;
		ProcessorNumberOfCores = $buf.NumberOfCores;
		ProcessorNumberOfLogicalProcessors = $buf.NumberOfLogicalProcessors;
		ProcessorLoadPercentage = $buf.LoadPercentage;
	}
						
	# gets memory status
						
	$Free = @{Name="FreeMemoryGB"; Expression={[math]::Round($_.FreePhysicalMemory/1MB, 2)}}
	$Total = @{Name="TotalMemoryGB"; Expression={[math]::Round($_.TotalVisibleMemorySize/1MB, 2)}}
	$freeMemoryPercentage = @{Name="FreeMemoryPercentage"; Expression={[math]::Round($_.FreePhysicalMemory/$_.TotalVisibleMemorySize*100, 2)}}
	$buf = gwmi Win32_Operatingsystem  | Select PSComputerName, $total, $free, $freeMemoryPercentage
	$property += @{
		FreeMemoryGB = $buf.FreeMemoryGB;
		TotalMemoryGB = $buf.TotalMemoryGB;
		FreeMemoryPercentage = $buf.FreeMemoryPercentage;
	}
						
	# Get disk status
						
	$SizeGB = @{Name="SizeGB"; Expression={[int]($_.size/1GB)}}
	$FreeSpaceGB = @{Name="FreeDiskSpaceGB"; Expression={[int]($_.freespace/1GB)}}
	$FreePercentage = @{Name="FreeDiskPercentage"; Expression={[int]($_.freespace/$_.size*100)}}
						
	$buf = gwmi Win32_LogicalDisk -Filter {drivetype = 3} | 
	select Name, $SizeGB, $FreeSpaceGB, $FreePercentage, FileSystem, PScomputerName
	$property += @{
	LogicalDisk = $buf;
	}
						
	$SizeGB = @{Name="SizeGB"; Expression={[int]($_.Size/1GB)}}
	$buf = gwmi Win32_diskdrive | select Model, InterfaceType, SerialNumber, $SizeGB
	$property += @{
	DiskDrive = $buf;
	}
						
	$property += @{Result = "Success"}
	$obj = New-Object -TypeName PSObject -Property $property
						
	return $obj
}
'@
function GetServerInfo ([string[]]$ComputerName = $env:COMPUTERNAME, [PSCredential]$credential, [string[]]$strings)
{
	$myResult = @()
	if ($ComputerName -eq $env:COMPUTERNAME)
	{
		iex $strings
		$myResult = GetComputerInfo
	} else {
		ForEach ($servername in $ComputerName)
		{
			Write-Debug -Message "$($credential.UserName) (to $($server.DNSHostName))";
			Write-Debug -Message "$($strings)";
			$buf = Invoke-Command -cn $servername -Credential $credential -Authentication Kerberos -ArgumentList $strings -ScriptBlock {
				param ($strings)
				iex $strings; return GetComputerInfo
			}
			$myResult += $buf
		}
	}

	return $myResult
}
Workflow GetServerInfo ([string[]]$ComputerName, [PSCredential]$credential, [string[]]$strings)
{
	ForEach -parallel ($servername in $ComputerName)
	{
		Sequence
		{
			InlineScript
			{
				$servername = $using:servername
				$credential = $using:credential
				$strings = $Using:strings

				Write-Debug -Message "$($credential.UserName) (to $($servername))";
				Write-Debug -Message "$($strings)";
				$buf = Invoke-Command -cn $servername -Credential $credential -Authentication Kerberos -ArgumentList $strings -ScriptBlock {
					param ($strings)
					iex $strings; return GetComputerInfo
				}
				return $buf
			}				
		}
	}
	$myResult += @($buf)
	return $myResult
}

Workflow GetServerStatistics
{
<#
.DESCRIPTION
# Gets statistics of the servers from the domain.

.Example
$domServers = Get-ADComputer -Filter {Enabled -eq $True -AND OperatingSystem -like "*server*"} -Properties OperatingSystem | Sort Name
Write-Host "found: $($domServers.Count)"
$myResult = GetServerStatistics -ComputerName $domServers -Credential $Credential
Write-Host "found: $($myResult.Count)"
#>
param
(
	[parameter(mandatory)]
	[array]$ComputerName
	, [parameter(mandatory)]
	[PSCredential]$Credential
)
	ForEach -parallel ($server in $ComputerName)
	{
		Sequence
		{
			InlineScript
			{
				$server = $using:server
				$credential = $using:credential
						
				try
				{
					$buf = Invoke-Command -cn $server.DNSHostName -Credential $credential -Authentication Kerberos -ScriptBlock {
						
						$property = @{
							ComputerName = $env:COMPUTERNAME
							PSVersion = $PSVersiontable.PSVersion
							BuildVersion = $PSVersiontable.BuildVersion
							ClrVersion = $PSVersiontable.CLRVersion
						}
						
						# Get Hardware Information
						
						$buf = gwmi Win32_BIOS
						$BIOSAge = @{Label="BIOSAge";Expression={if ($_.ReleaseDate) {(Get-Date) - $_.ConvertToDateTime($_.ReleaseDate)}}}
						$property += @{
							BIOSManufacturer = $buf.Manufacturer
							BIOSSerialNumber = $buf.SerialNumber
							BIOSBIOSVersion = $buf.SMBIOSBIOSVersion
							BIOSAgeDays = ($buf | select $BIOSAge).BiosAge.Days
						}
						
						# Get Computer system Information
						
						$buf = gwmi Win32_ComputerSystem
						$property += @{
							CSModel = $buf.Model   # Identifies if it's a virtual machine.
							CSBootupState = $buf.BootupState
							CSDomain = $buf.Domain
							CSDomainRole = $buf.DomainRole
							CSSystemType = $buf.SystemType
						}
						
						# Get Operating System Information
						
						$buf = gwmi Win32_OperatingSystem
						$property += @{
							OSVersion = $buf.Caption
							OSVersionServicePackMajor = $buf.ServicePackMajorVersion
							OSLanguage = $buf.OSLanguage
							OSMUILanguages = $buf.MUILanguages
							OSArchitecture = $buf.OSArchitecture
							OSSystemDevice = $buf.SystemDevice
							OSSystemDirectory = $buf.SystemDirectory
						}
						
						# gets processor Information
						
						$buf = gwmi Win32_Processor
						$property += @{
							Processor = $buf.Name
							ProcessorNumberOfCores = $buf.NumberOfCores
							ProcessorNumberOfLogicalProcessors = $buf.NumberOfLogicalProcessors
							ProcessorLoadPercentage = $buf.LoadPercentage
						}
						
						# gets memory status
						
						$FreeMemory = @{Name="FreeMemoryGB"; Expression={[math]::Round($_.FreePhysicalMemory/1MB, 2)}}
						$TotalMemory = @{Name="TotalMemoryGB"; Expression={[math]::Round($_.TotalVisibleMemorySize/1MB, 2)}}
						$freeMemoryPercentage = @{Name="FreeMemoryPercentage"; Expression={[math]::Round($_.FreePhysicalMemory/$_.TotalVisibleMemorySize*100, 2)}}
						$buf = gwmi Win32_Operatingsystem  | Select $totalMemory, $freeMemory, $freeMemoryPercentage
						$property += @{
							FreeMemoryGB = $buf.FreeMemoryGB
							TotalMemoryGB = $buf.TotalMemoryGB
							FreeMemoryPercentage = $buf.FreeMemoryPercentage
			
						}
						
						# Get disk status
						
						$SizeGB = @{Name="SizeGB"; Expression={[int]($_.size/1GB)}}
						$FreeSpaceGB = @{Name="FreeDiskSpaceGB"; Expression={[int]($_.freespace/1GB)}}
						$FreePercentage = @{Name="FreeDiskPercentage"; Expression={[int]($_.freespace/$_.size*100)}}
						
						$buf = gwmi Win32_LogicalDisk -Filter {drivetype = 3} | 
						select Name, $SizeGB, $FreeSpaceGB, $FreePercentage, FileSystem
						$property += @{
							LogicalDisk = $buf
						}
						
						$SizeGB = @{Name="SizeGB"; Expression={[int]($_.Size/1GB)}}
						$buf = gwmi Win32_diskdrive | select Model, InterfaceType, SerialNumber, $SizeGB
						$property += @{
							DiskDrive = $buf
						}
						
						$property += @{Result = "Success"}
						$obj = New-Object -TypeName PSObject -Property $property
						
						return $obj
					}
					Write-Debug "returned: $(($buf |gm -MemberType Properties).count) ($($server.DNSHostName))"
					if ($buf)
					{
						$filepath = "$($HOME)\Documents\ServerStat_$($server.DNSHostName).xml"
						$buf | Export-Clixml -Path $filepath
						return $buf
					}
				}
				catch {throw $_}
				finally {}
			}
		}
	}
	$myResult += @($buf)
		        
}
