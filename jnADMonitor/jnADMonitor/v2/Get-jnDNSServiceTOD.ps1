param(
	 [Parameter(mandatory=$True)][Int32]$idx 
	, [string]$domain
	, [string]$server
	, [string]$admuser
	, [string]$admpwd
)

#
# .\Get-jnDNSServiceTOD.ps1 -idx 1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *
#
#################################
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

#[SQL Connection]
function New-SQLConnection {
Param (
)
    if (test-path variable:\conn) {
        $conn.close()
    } else {
        $conn = new-object ('System.Data.SqlClient.SqlConnection')
    }
    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    $conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
}

# DNSServiceTOD Log
function Insert-MonitoringTODTaskLogs{
param (
    [Parameter(Mandatory=$True)][string]$Messages
	, [Parameter(Mandatory=$True)][string]$Type
	, [Parameter(Mandatory=$True)][string]$EventName
)

	$ProcName = "USP_INSERT_SYSTEM_LOG"

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 
	$cmd.Connection = New-SQLConnection
	$cmd.CommandText = $ProcName

	# Log the time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()

	$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@TYPE", $Type)
	$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@EVENT_NAME", $EventName)
	$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@MESSAGE", $Messages)
	$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CREATE_DATE", $jnUTCMonitored)
	$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@CREATER_ID", "PS")
	
	$cmd.Parameters.Clear()
               
    [void]$cmd.Parameters.Add($SQLParameter1)
	[void]$cmd.Parameters.Add($SQLParameter2)
	[void]$cmd.Parameters.Add($SQLParameter3)
	[void]$cmd.Parameters.Add($SQLParameter4)
	[void]$cmd.Parameters.Add($SQLParameter5)
		
	$cmd.ExecuteNonQuery() | out-Null
	$cmd.Connection.Close()
}

$type = "Info"
$eventname = "Get-jnDNSServiceTOD"
$messages = "[`$jnDNSServiceTOD] Start running..."
Insert-MonitoringTODTaskLogs -Type $type -EventName $eventname -Messages $messages 

function Get-jnSQLData {
param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [String]$ServiceFlag
)

	# Query data
	$cmd = new-object "System.Data.SqlClient.SqlCommand"
	$cmd.CommandType = [System.Data.CommandType]"Text"
	$cmd.Connection = New-SQLConnection

	if ($domain -eq $null -or $domain -eq "") 
		{$cmd.CommandText = "SELECT * FROM $($TableName)"}
	else {
		if ($ServiceFlag -eq $null -or $ServiceFlag -eq "") 
			{$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($Domain)'"}
		else 
			{$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($Domain)' and ServiceFlag = '$($ServiceFlag)'"}
	}

#	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
#	Write-Debug "CommandText: $($cmd.CommandText)."

	# Get data
	$dtdata = new-object "System.Data.DataTable"
	$rdr = $cmd.ExecuteReader()
	$dtdata.Load($rdr)

	$cmd.Connection.Close()

	return $dtdata

} # End of function

#$company = $domain.replace(".","_")
$TableName = "TB_SERVERS"
$ProcName = "IF_SERVERS"
[array]$servers = Get-jnSQLData -TableName $TableName -ServiceFlag 'DNS'

if ($servers.Count -gt 0) {
	Write-Host "`n[SQL] Servers Retrieved: $($servers.Count)."
}
else {
    Write-Host "`n[SQL] No Servers Retrieved.`n" -fore yellow
	break
}

# Add host to TrustedHosts to the local client to use NTLM.
if ($domain -ne $env:USERDNSDOMAIN ) {
    if (!(Get-jnTrustedHosts -Value "*.$($domain)"))
	{ 
		if (!(Get-jnTrustedHosts -Value $serverfqdn))
			{Add-jnTrustedHosts -Value $serverfqdn}
	}
}

# to create powershell remoting session
if ($session = New-PSSession -cn $serverfqdn -credential $cred)
	{Write-Host "`n[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."}
else 
	{break}

# to connect to the Managed Server in the domain.

[array]$jnDNSServiceTODResult = Invoke-Command -Session $session -script {
param(
	[Parameter(Mandatory=$True)][array]$Servers
)

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

function Test-jnDNSServerServiceAvailability {
param (
	[Parameter(Mandatory=$True)][array]$Servers
)

	$myresult = @()

    $servers | % {
		
		if (!(Get-Module ActiveDirectory -ea 0)) 
			{Import-Module ActiveDirectory}
		$myserver = Get-ADComputer -Identity $_.ComputerName | Sort Name

		if (Test-Connection $myserver.Name -Count 1 -Quiet) {

			Write-Debug "Processing at: $($myserver.Name) `n"

			$hash = @{}
			$hash.ComputerName = $myserver.Name
			$hash.OperatingSystem = $myserver.OperatingSystem
			if ($myserver.OperatingSystemServicePack -eq $null) 
				{$hash.OperatingSystemServicePack = "0"}
			else {$hash.OperatingSystemServicePack = $myserver.OperatingSystemServicePack}

			$hash.jnUTCMonitored = (Get-Date).ToUniversalTime()

			if ($myserver.Name -eq $env:COMPUTERNAME) {

				$OS = gwmi Win32_OperatingSystem
				$hash.OperatingSystem = $OS.Caption
				$hash.OperatingSystemServicePack = $OS.ServicePackMajorVersion.ToString()

				# /DNSBASIC: Performs basic DNS tests, including network connectivity, DNS client configuration, service availability, and zone existence.
				# /DNSRECORDREGISTRATION: Performs the /DnsBasic tests, and also checks if the address (A), canonical name (CNAME) and well-known service (SRV) resource records are registered.
				# /DNSRESOLVEEXTNAME: Performs the /DnsBasic tests, and also attempts to resolve InternetName. If ¡°/DnsInternetName:<InternetName>¡± is not specified, attempts to resolve the name www.microsoft.com.
				$hash.dnsstatus = @(dcdiag /test:DNS /DnsRecordRegistration /DnsResolveExtName | ? {$_ -ne $null -and $_ -ne ""})

			} # End of If the managed server.
			else {
				$hash = Invoke-Command -ComputerName $myserver.Name -ScriptBlock {

					param ($hash)
                    
					#$DebugPreference = "Continue"
					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					# /DNSBASIC: Performs basic DNS tests, including network connectivity, DNS client configuration, service availability, and zone existence.
					# /DNSRECORDREGISTRATION: Performs the /DnsBasic tests, and also checks if the address (A), canonical name (CNAME) and well-known service (SRV) resource records are registered.
					# /DNSRESOLVEEXTNAME: Performs the /DnsBasic tests, and also attempts to resolve InternetName. If ¡°/DnsInternetName:<InternetName>¡± is not specified, attempts to resolve the name www.microsoft.com.
					$hash.dnsstatus = @(dcdiag /test:DNS /DnsRecordRegistration /DnsResolveExtName | ? {$_ -ne $null -and $_ -ne ""})

					if ($hash.Count -gt 0) 
						{return $hash}

				} -ea 0 -ArgumentList $hash

			} # End of If Not the managed server.

			if ($hash -ne $null) {
				if (($hash.Values -match "ERROR" -or $hash.Values -match "FAIL") -and $hash.Values -notmatch "NO ERROR") 
					{$hash.IsError = $True} 
				else {$hash.IsError = $False}
			}

			if ($hash.Count -gt 0) {
				$myresult += @($hash)
				Write-Debug "`$hash ($($_.ComputerName)): $($hash.gettype()): $($hash.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)."
			}

		} # End of If the server is currently connected.

    } # end of Foreach.

    Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

    return $myresult

} # End of function

Test-jnDNSServerServiceAvailability -Servers $Servers

} -ArgumentList (, $servers)

#Write-Host "`nResult:" $jnDNSServiceTODResult.GetType() "--" ($jnDNSServiceTODResult | group ComputerName).count "servers grouped by server.`n" -fore yellow
$jnDNSServiceTODResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}
#$jnDNSServiceTODResult | % {$_; "--`n"}

# to close powershell remoting session
if (Get-PSSession -InstanceId $session.InstanceId) {
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Host "`n[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
}
else {Write-Host "`n[PSSession] Session failed to close from $($session.ComputerName), InstanceId: $($session.InstanceId)." -ForegroundColor Red}

#[DNSServiceTOD]
function Insert-DNSServiceTOD {
param (
    [Parameter(mandatory=$True)][AllowNull()][Array]$Data
	, [Parameter(mandatory=$True)][Int32]$IDX
)

	
# DNSServiceTOD Result
function Insert-TODResult{
param (
    [Parameter(mandatory=$True)][Int32]$IDX
	, [Parameter(mandatory=$True)][string]$TODResult
	, [Parameter(mandatory=$True)][string]$ResultScript
)
	$ProcName = "USP_UPDATE_TEST_ON_DEMAND_COMPLETED"
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure"	
	$cmd.Connection = New-SQLConnection
    $cmd.CommandText = $ProcName

	$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@IDX", $IDX)
    $SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TOD_Result", $TODResult)
	$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@TOD_ResultScript", $ResultScript)
                               
    $cmd.Parameters.Clear()
               
    [void]$cmd.Parameters.Add($SQLParameter1)
    [void]$cmd.Parameters.Add($SQLParameter2)
	[void]$cmd.Parameters.Add($SQLParameter3)
                       
    $cmd.ExecuteNonQuery() | out-Null
    $cmd.Connection.Close()
}

try {
	$ErrorActionPreference = "Stop"

	$TODResult = "Y"
	$Type = "Info" 
	
	if ($Data.Count -gt 0) {
		foreach($row in $Data) {
			if ($row.count -eq 0) {continue}
			if ($row.dnsstatus.count -eq 0) {continue}
			else {
				foreach ($dnsstatus in $row.dnsstatus) {$ResultScript += $dnsstatus + "<br/>"}
			}
		}

		if ($ResultScript -ne $null -and $ResultScript -ne "") {
			$Message = "[`$jnDNSServiceTOD] Completed Successfully."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $ResultScript
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		}
		else {
			$Message = "[`$jnDNSServiceTOD] No Data returned from [`$ResultScript]."
			Write-host $Message

			Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
			Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		}
	} # End of If it contains data.
	else {
		$Message = "[`$jnDNSServiceTOD] No Data returned from PSSession."
		Write-host $Message

		Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName
		Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
	} # End of If it doesn't contain data.

}

Catch {

	$TODResult = "Y"
	$Type = "Error" 
	$EventName = "Get-jnDNSServiceTOD"
	$Message = "[EXCEPTION] $($Error[0]).`n"

	Insert-TODResult -IDX $IDX -TODResult $TODResult -ResultScript $Message
	Insert-MonitoringTODTaskLogs -Messages $Message -Type $Type -EventName $EventName

	Write-Host $Message -Fore Red
}

finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}
}

}
Insert-DNSServiceTOD -Data $jnDNSServiceTODResult -IDX $idx
if (gv jnDNSServiceTODResult) {rv jnDNSServiceTODResult}

