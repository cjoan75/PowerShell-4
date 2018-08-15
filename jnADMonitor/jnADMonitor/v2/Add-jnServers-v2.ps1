param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Add-jnServers-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

$server = $server
$domain = $domain
$serverfqdn = "$($server).$($domain)"
$userfqdn = "$($admuser)@$($domain)"
$pwd = ConvertTo-SecureString $admpwd -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userfqdn, $pwd

#################################
##### SQL Authentication ########
#################################
$SqlServerName = 'dxm'
$DataBaseName = 'ADSysMon'
$SQLUserName = 'sa'
$SQLUserPwd = 'P@ssw0rd'

#$DebugPreference = "Continue"
Write-Debug "CONNECTED TO $($serverfqdn) AS $($userfqdn).`n"

function New-SQLConnection {
Param (
)
    if (Test-Path Variable:\conn) 
		{$conn.close()} 
	else 
		{$conn = new-object ('System.Data.SqlClient.SqlConnection')}

    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    $conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
} # End of function.

function Insert-MonitoringTaskLogs {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$jnUTCMonitored
	, [Parameter(Mandatory=$True)][ValidateSet("BEGIN", "END")][string]$TaskType
	, [Parameter(Mandatory=$True)][ValidateSet("SERVERS", "CONNECT", "ADDS", "ADCS", "DNS", "DHCP", "RADIUS", "HEALTH")][string]$ADService
	, [string]$TaskScript
)

try {
	$ErrorActionPreference = "Stop"

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"Text" 
	$cmd.Connection = New-SQLConnection

	if ($TaskScript -eq $null -or $TaskScript -eq "") 
		{$TaskScript = ""}
	$cmd.CommandText = " `
Insert into TB_MonitoringTaskLogs ([TaskDate], [TaskType], [Company], [ADService], [TaskScript])
values('$($jnUTCMonitored)', '$($TaskType)', '$($Domain)', '$($ADService)', '$($TaskScript)') `
"

	$cmd.ExecuteNonQuery() | out-Null
	Write-Host "`n[TaskLogs] $($ADService): $($TaskType). ($($TaskScript))`n"

	$cmd.Connection.Close()

}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv jnUTCMonitored) {rv jnUTCMonitored}
	if (gv TaskType) {rv TaskType}
	if (gv ADService) {rv ADService}
	if (gv TaskScript) {rv TaskScript}

}
} # End of function.

# Log the BEGIN time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService SERVERS -jnUTCMonitored $jnUTCMonitored

function Get-jnModuleByName {
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[string]$ModuleName
)

	$mds = Get-Module
	if ($mds) {
		$mds | % {
			if ($_.Name -eq $modulename) {
				return $True
			}
		}
	}

} # End of function

function Get-jnADDSServer {
[CmdletBinding()]
Param(
	[string]$ServerName
)

	$modulename = "ActiveDirectory"
	if (!(Get-jnModuleByName -ModuleName $modulename)) {
		Write-Host "Importing Module...$($modulename)"
		if (Import-Module $modulename)
			{Write-Host "Successfully Imported...$($modulename)"}
	}

	Write-Host "Searching Domain Controllers...`n"

	if ($ServerName -eq $null -or $ServerName -eq "") {
		$servers = Get-ADDomainController -Filter {Enabled -eq $True} | Sort Name
	}
	else {
		$servers = Get-ADDomainController -Filter {Name -eq $ServerName} | Sort Name
	}

	# to cast [Microsoft.ActiveDirectory.Management.ADDomainController] to Array
	[array]$servers = $servers | 
		? {$_.Name -ne $null -and $_.Name -ne ""} | 
		sort Name

	Write-Host "$($servers.Count) Servers are found.`n"

	if ($servers.Count -gt 0) {return $servers}

} # End of function

function Get-jnDHCPServer {
param (
    [string]$ServerName
)

	$modulename = "ActiveDirectory"
    if (!(Get-jnModuleByName -ModuleName $modulename)) {
        Write-Host "Importing Module...$($modulename)"
        if (Import-Module $modulename)
			{Write-Host "Successfully Imported...$($modulename)"}
    }

     Write-Host "Searching authorized DHCP Servers...`n"

	$servers = @()

    if ($ServerName -eq $null -or $ServerName -eq "") {

        $servers01 = Get-ADObject -SearchBase "cn=configuration,$((Get-ADDomain).DistinguishedName)" `
            -Filter {objectclass -eq "dHCPClass" -AND Name -ne "dhcproot"} |
	        ? {$_.Name -ne $null -and $_.Name -ne "" -and $_.Name -like "*.$((Get-ADDomain).DnsRoot)"} |
            sort name 
        $servers= @()
		$servers01 | % {
			$Name = ($_.Name).Substring(0, ($_.Name).IndexOf("."))
			if (Test-Connection $Name -Count 1 -ea 0) {
				$servers += Get-ADComputer $Name -Properties OperatingSystem, OperatingSystemServicePack -ea 0
			} # End of If the server is currently connected.
		} # end of servers01.

    } # End of If all servers are specified.
    else {
		
		$servers = Get-ADComputer $ServerName -Properties OperatingSystem, OperatingSystemServicePack -ea 0
    } # End of If the server is specified.

    [array]$servers = $servers | 
        ? {$_.Name -ne $null -and $_.Name -ne ""} | 
        sort Name

    Write-Host "$($servers.Count) Servers are found.`n"

    if ($servers.Count -gt 0) {return $servers}

} # End of function

function Import-Servers {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$WorkingDir
)

	$myresult = @()

	$company = $Domain.replace(".", "_")

	if ($addsservers = Get-Content -Path "$($WorkingDir)\Serverlist_$($company)_ADDS.txt" -ea 0 |
		? {$_ -ne $null -and $_ -ne ""} | 
		select @{Name="Name"; Expression={$_.TrimStart(" ")}})
		{
		$addsservers | % {

			$hash = @{}
			$hash.ComputerName = $_.Name
			$hash.jnServiceFlag = "ADDS"
			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
		
			if ($buf = Test-Connection "$($_.Name).$($Domain)" -Count 1 -ea 0)
			{
				$hash.IPv4Address = $buf.IPV4Address.IPAddressToString
				$hash.IsError = $False
			}
			else
			{
				$hash.IsError = $True
			}

			if ($hash.Count -gt 0)
			{
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # end of Foreach.
	} # End of function.

	if ($adcsservers = Get-Content -Path "$($WorkingDir)\Serverlist_$($company)_ADCS.txt" -ea 0 |
		? {$_ -ne $null -and $_ -ne ""} |
		select @{Name="Name"; Expression={$_.TrimStart(" ")}}) {
		$adcsservers | % {

			$hash = @{}
			$hash.ComputerName = $_.Name
			$hash.jnServiceFlag = "ADCS"
			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
		
			if ($buf = Test-Connection "$($_.Name).$($Domain)" -Count 1 -ea 0) {
				$hash.IPv4Address = $buf.IPV4Address.IPAddressToString
				$hash.IsError = $False
			}
			else {$hash.IsError = $True}

			if ($hash.Count -gt 0) {
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # end of Foreach.
	} # End of function.

	if ($dnsservers = Get-Content -Path "$($WorkingDir)\Serverlist_$($company)_DNS.txt" -ea 0 |
		? {$_ -ne $null -and $_ -ne ""} |
		select @{Name="Name"; Expression={$_.TrimStart(" ")}}) {
		$dnsservers | % {

			$hash = @{}
			$hash.ComputerName = $_.Name
			$hash.jnServiceFlag = "DNS"
			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
		
			if ($buf = Test-Connection "$($_.Name).$($Domain)" -Count 1 -ea 0) {
				$hash.IPv4Address = $buf.IPV4Address.IPAddressToString
				$hash.IsError = $False
			}
			else {$hash.IsError = $True}

			if ($hash.Count -gt 0) {
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # end of Foreach.
	} # End of function.

	if ($dhcpservers = Get-Content -Path "$($WorkingDir)\Serverlist_$($company)_DHCP.txt" -ea 0 |
		? {$_ -ne $null -and $_ -ne ""} |
		select @{Name="Name"; Expression={$_.TrimStart(" ")}}) {
		$dhcpservers | % {

			$hash = @{}
			$hash.ComputerName = $_.Name
			$hash.jnServiceFlag = "DHCP"
			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
		
			if ($buf = Test-Connection "$($_.Name).$($Domain)" -Count 1 -ea 0) {
				$hash.IPv4Address = $buf.IPV4Address.IPAddressToString
				$hash.IsError = $False
			}
			else {$hash.IsError = $True}

			if ($hash.Count -gt 0) {
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # end of Foreach.
	} # End of function.

	if ($radiusservers = Get-Content -Path "$($WorkingDir)\Serverlist_$($company)_RADIUS.txt" -ea 0 |
		? {$_ -ne $null -and $_ -ne ""} |
		select @{Name="Name"; Expression={$_.TrimStart(" ")}}) {
		$radiusservers | % {

			$hash = @{}
			$hash.ComputerName = $_.Name
			$hash.jnServiceFlag = "RADIUS"
			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()
		
			if ($buf = Test-Connection "$($_.Name).$($Domain)" -Count 1 -ea 0) {
				$hash.IPv4Address = $buf.IPV4Address.IPAddressToString
				$hash.IsError = $False
			}
			else {$hash.IsError = $True}

			if ($hash.Count -gt 0) {
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # end of Foreach.
	} # End of function.

	Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

	return $myresult

} # End of function.

$company = $domain.replace(".","_")
$jnServersResult = Import-Servers -WorkingDir ".\$($company)"

function Insert-jnSqlData {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName
	, [Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
	

	$rowcount = 0

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
[Domain] [nvarchar](30) NOT NULL, `
[ServiceFlag] [nvarchar](10) NOT NULL, `
[ComputerName] [nvarchar](50) NOT NULL, `
[IPAddress] [nvarchar](15) NULL, `
[UTCMonitored] [datetime] NOT NULL, `
PRIMARY KEY (Domain, ServiceFlag, ComputerName) `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

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
			@Domain nvarchar(30) `
			,@ServiceFlag nvarchar(10) `
			,@ComputerName nvarchar(50) `
			,@IPAddress nvarchar(15) `
			,@UTCMonitored datetime`
	AS`
	BEGIN`
	`
	INSERT INTO [dbo].[$($TableName)] `
			( [Domain] `
			,[ServiceFlag] `
			,[ComputerName] `
			,[IPAddress] `
			,[UTCMonitored] `
			) `
			VALUES`
			( @Domain` 
			,@ServiceFlag`
			,@ComputerName`
			,@IPAddress`
			,@UTCMonitored`
			) `
`
	END'`
	) `
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

	$cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

} # End of function.

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
    
	Write-Debug "[SQL] Started to insert."

try {
	$ErrorActionPreference = "Stop"

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName

			$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@Domain", $domain)
			$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", $data[$i].jnServiceFlag)
			$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)

			if ($data[$i].IPv4Address -eq $null -or $data[$i].IPv4Address -eq "")
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@IPAddress", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@IPAddress", $data[$i].IPv4Address)}

			$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
	         
			$cmd.Parameters.Clear()
               
			[void]$cmd.Parameters.Add($SQLParameter1)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter2)
			[void]$cmd.Parameters.Add($SQLParameter5)

			Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
			Write-Debug "CommandText: $($cmd.CommandText)."

			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			$rowcount +=  1

		} # End of for.

		if ($rowcount.Count -gt 0) 
			{Write-host "[`$jnServersResult] Completed Successfully."}
		else {Write-Host "[`$jnServersResult] No Data returned."}

	} # End of If data is found.

}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

} # End of Finally.

} # End of Function.

#$company = $domain.replace(".","_")
$TableName = "TB_SERVERS"
$ProcName = "IF_SERVERS"

Insert-jnSqlData -Data $jnServersResult -TableName $TableName -ProcName $ProcName

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService SERVERS -jnUTCMonitored $jnUTCMonitored



