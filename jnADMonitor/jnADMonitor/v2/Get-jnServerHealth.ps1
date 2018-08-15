param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

# .\Get-jnServerHealth-v2.ps1 -server dnprod05 -domain dotnetsoft.co.kr -admuser admin2 -admpwd *

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
    if (Test-Path Variable:\conn) 
		{$conn.close()} 
	else 
		{$conn = new-object ('System.Data.SqlClient.SqlConnection')}

    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    $conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
}

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
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService HEALTH -jnUTCMonitored $jnUTCMonitored

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

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

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
[array]$servers = Get-jnSQLData -TableName $TableName -ServiceFlag 'DHCP'

if ($servers.Count -gt 0) {
	Write-Host "[SQL] Servers Retrieved: $($servers.Count)."
}
else {
	$Message = "[SQL] No Servers Retrieved."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService HEALTH -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

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
else {
	$Message = "[PSSession] No new PSSession established."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService HEALTH -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

	break
}

# to connect to the Managed Server in the domain.

$jnServerHealth = Invoke-Command -Session $session -script {

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

function Get-jnModuleByName {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
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

    if (!(Get-jnModuleByName -ModuleName "ActiveDirectory")) {
        Write-Host "Importing Module..."
        Import-Module ActiveDirectory
        Write-Host "Successfully Imported."
    }
 
    Write-Host "Finding Domain Controllers...`n"

    Write-Debug "-ServerName-"$ServerName.GetType()"--"$ServerName.count"--" $ServerName
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

    #$servers | % {Write-Host $_.Name "`t" $_.Site}
    Write-Host "$($servers.Count) servers found.`n"

    if ($servers.Count -gt 0) {return $servers}

} # End of function

function Get-jnADServer {
[CmdletBinding()]
Param(
    [string]$ServerName
)

    Write-Host "Finding All servers...`n"

    if ($ServerName -eq $null -or $ServerName -eq "") {
        $servers = Get-ADComputer -Filter {Enabled -eq $True} | Sort Name
    }
    else {
        $servers = Get-ADComputer -Filter {Name -eq $ServerName} | Sort Name
    }

    # to cast [Microsoft.ActiveDirectory.Management.ADDomainController] to Array
    [array]$servers = $servers | 
        ? {$_.Name -ne $null -and $_.Name -ne ""} | 
        sort Name

    Write-Host "$($servers.Count) servers found.`n"

    if ($servers.Count -gt 0) {return $servers}

} # End of function

workflow Get-jnMemory {
[CmdletBinding()]
param (
    [string]$ServerName
)
    if ($ServerName -eq $null -or $ServerName -eq "") 
        {$servers = Get-jnADServer}
    else {$servers = Get-jnADServer $ServerName}

    $myresult = @()

    $servers | % {

		if (!(Test-Connection $_.Name -Count 1 -Quiet -ea 0)) {
			Write-Debug "`Connecting to ($($_.Name))... FAILED."
		}
		else {
			Write-Debug "`Connected to ($($_.Name))."

			$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
			$Free = @{Name="Free (GB)";Expression={[math]::Round($_.FreePhysicalMemory/1MB, 2)}}
			$Total = @{Name="Total (GB)";Expression={[math]::Round($_.TotalVisibleMemorySize/1MB, 2)}}
			$ratio = @{Name="Free (%)";Expression={[math]::Round($_.FreePhysicalMemory/$_.TotalVisibleMemorySize*100, 2)}}

			$buf = @(gwmi Win32_Operatingsystem -cn $_.Name | Select $free, $total, $ratio, CSName, $jnUTCMonitored)

			if ($buf.Count -gt 0) {
				$myresult += @($buf)
				Write-Debug "`$buf ($($_.Name)): $($buf.gettype()): $($buf.count)"
				Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)"
			} 
		} # end of if the server is connected.

    } # end of Foreach.

    Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

    return $myresult

} # End of workflow

workflow Get-jnProcessByService {
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True)]
    [string]$ProcessName
	, [string]$ServerName
)
	
	$myresult= @()

	if (gv ps -ea 0) {gv ps | rv}
	$ps = tasklist -svc /fo csv
	$ps = $ps | ? {$_ -match $processname}
	$ps = $ps.trimstart("`"")
	$ps_imagename = $ps.Substring(0, $ps.IndexOf("`",`""))
	$ps = $ps.trimstart($ps_imagename + "`",`"")
	$ps_pid = $ps.Substring(0, $ps.IndexOf("`",`""))
	$buf = get-process -id $ps_pid

	if ($buf.Count -gt 0) {
		$myresult += @($buf)
		Write-Debug "`$buf ($($_.Name)): $($buf.gettype()): $($buf.count)"
		Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)"
	} 
    
	Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

    return $myresult


} # End of workflow

Get-jnMemory -PSConnectionRetryCount 1 -PSPersist $True
Get-jnProcessByService -ProcessName "WinRM" -ServerName $env:COMPUTERNAME -PSConnectionRetryCount 1 -PSPersist $True

} -ea 0 # End of remote session

$jnServerHealth

# to close powershell remoting session
if (Get-PSSession -InstanceId $session.InstanceId) {
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Host "`n[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"
}
else {Write-Host "`n[PSSession] Session failed to close from $($session.ComputerName), InstanceId: $($session.InstanceId)." -ForegroundColor Red}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService HEALTH -jnUTCMonitored $jnUTCMonitored



