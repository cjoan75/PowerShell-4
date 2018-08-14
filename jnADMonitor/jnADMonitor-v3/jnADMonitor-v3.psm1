# jnADMonitor-v3.psm1

Write-Host "Welcome to jnADMonitor-v3.`n"
#$Servers = Get-ADComputer -Filter "Enabled -eq 'True' -AND OperatingSystem -like '*server*'" -Properties OperatingSystem | select *, @{Name='ComputerName'; Expression={$_.DNSHostName}}; $Servers.count

function New-SQLConnection {
Param (
[string]$SqlServerName = '165.243.197.174',
[string]$DataBaseName = 'ADSysMon',
[string]$SQLUserName = 'ADMAdmin',
[string]$SQLUserPwd = 'qwer123$'
)
    

	if (test-path variable:\conn) {
        $conn.close()
    } else {
        $conn = new-object ('System.Data.SqlClient.SqlConnection')
    }
    $connString = "Server=$SqlServerName;Database=$DataBaseName;User Id=$SQLUserName;Password=$SQLUserPwd"
    #$connString = "Data Source=$SqlServerName;Initial Catalog=$DataBaseName;uid=$SQLUserName;pwd=$SQLUserPwd"
	
	$conn.ConnectionString = $connString
    $conn.StatisticsEnabled = $true
    $conn.Open()
    $conn
} 

function Get-SQLData {
<#
	.Example
	Get-SQLData -TableName "TB_SERVERS" -Domain LGE.NET

	.Example
	Get-SQLData -TableName "TB_SERVERS" -ServiceFlag 'ADDS' -Domain LGE.NET
#>
param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [String]$ServiceFlag
	, [switch]$GetEventID
	, [string]$DomainName
)

	# Query data
	$cmd = new-object "System.Data.SqlClient.SqlCommand"
	$cmd.CommandType = [System.Data.CommandType]::Text
	$cmd.Connection = New-SQLConnection

    if ($GetEventID)
	{
		$cmd.CommandText = "SELECT * FROM $($TableName) WHERE ServiceFlag = '$($ServiceFlag)'"
	} else {
		if (! $DomainName) 
		{
			$cmd.CommandText = "SELECT * FROM $($TableName)"
		} else {
			if (! $ServiceFlag) 
			{
				$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($DomainName)'"
			} else {
				$cmd.CommandText = "SELECT * FROM $($TableName) WHERE Domain = '$($DomainName)' and ServiceFlag = '$($ServiceFlag)'"
			}
		}
	}
	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

	# Get data
	$dtdata = new-object "System.Data.DataTable"
	$rdr = $cmd.ExecuteReader()
	$dtdata.Load($rdr)

	$cmd.Connection.Close()

	return $dtdata

} 

function Add-TrustedHosts {
<#
    .SYNOPSIS
    Add host or domain to TrustedHosts on your local computer.
    NOTE: This task needs administrative privilege.
    .EXAMPLE
    Add-TrustedHosts -Value www.contoso.com
    .EXAMPLE
    Add-TrustedHosts -Value *.contoso.com
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$Value
)
    #Write-Host "This task needs administrative privilege." -fore yellow

    if ($env:USERDNSDOMAIN -eq $Value.substring($Value.IndexOf(".")+1)) {
        Write-Host "No need to register the host in the domain: $($Value.substring($Value.IndexOf(".")+1))." -fore green
        return $False
    } # End of If the host requested is in the same domain on which the command runs.
    else { 
        $curVal = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
        $buf01 = @()
        $buf01 += $curVal.Split(",")
        $buf = @()
        $buf01 | % {$buf += $_.Trim()}
        if ($buf.Count -le 1) {
            if ($buf[0].Length -lt 1) {
                Set-Item WSMan:\localhost\Client\TrustedHosts -Value $Value -force
                Write-Host "Successfully registered at first." -fore green
                return $True
            }
            else {
                if ($buf -notcontains $Value) {
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$curVal, $Value" -force
                    Write-Host "Successfully registered at second." -fore green
                    return $True
                }
                else {
                    Write-Host "Already registered." -fore green
                    return $False
                }
            }
        } 
        elseif ($buf -notcontains $Value) {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$curVal, $Value" -force
            Write-Host "Successfully registered." -fore green
            return $True
        } 
        else {
            Write-Host "Already registered." -fore green
        }

    } # End of If Not the host requested is in the same domain on which the command runs.

}

function Get-TrustedHosts {
<#
    .SYNOPSIS
    Get TrustedHosts on your local computer.
    .EXAMPLE
    Get-TrustedHosts -Value www.contoso.com
    .EXAMPLE
    Add-TrustedHosts -Value *.contoso.com
#>
[CmdletBinding()]
Param(
    [string]$Value
)
    $curVal = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    $buf01 = @()
    $buf01 += $curVal.Split(",")
    $buf = @()
    $buf01 | % {$buf += @($_.Trim())}
    if (! $Value)
	{
        if ($buf) {return $buf}
    } else {
        if ($buf.count -ge 1 -and $buf -contains $Value) {
                return $Value
        }

    }

}

function Remove-TrustedHosts {
<#
    .SYNOPSIS
    Remove all hosts or the specified hosts on your local TrustedHosts.
    .EXAMPLE
    Remove-TrustedHosts
    This cmdlet removes all hosts in TrustedHosts.
    .EXAMPLE
    Remove-TrustedHosts -Value *.contoso.com
#>
[CmdletBinding()]
Param(
    #[ValidateSet("All","Normal")]
    #[string]$Mode = "Normal"
    #[Parameter(Mandatory=$true)]
    [string]$Value
)

    $curVal = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    $buf01 = @()
    $buf01 += $curVal.Split(",")
    $buf = @()
    $buf01 | % {$buf += $_.Trim()}
    if ($buf.Count -le 1 -and $buf[0].Length -lt 1) {
        Write-Host "No TrustedHosts exist." -fore green
        return $False
    }
    Else {
        if (! $Value) {
            Clear-Item WSMan:\localhost\Client\TrustedHosts
            Write-Host "All hosts are removed." -fore green
        } else { # when trying to remove the specified hosts only.
            $buf01 = "" # to define the variable with the string type.
            $I = 0
            $buf | % {
                if ($_ -ne $Value) {
                    $buf01 += $_
                    if ($I -lt $buf.Count - 1) {$buf01 += ", "}
                }
                $I++
            }
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value $buf01 -Force
            Write-Host "The specified hosts are removed." -fore green
        }

        return $True
    }

}

Function Create-ServersTableIfNotExist{
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)
	    	  
    $cmd = new-object "System.Data.SqlClient.SqlCommand"
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
        
    $cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)]( `
	[Domain] [nvarchar](30) NOT NULL, `
	[ServiceFlag] [nvarchar](10) NOT NULL, `
	[ComputerName] [nvarchar](100) NOT NULL, `
	[IPAddress] [nvarchar](15) NULL, `
	[UTCMonitored] [datetime] NOT NULL, `
PRIMARY KEY CLUSTERED ` 
( `
	[Domain] ASC, `
	[ServiceFlag] ASC, `
	[ComputerName] ASC `
)WITH `
	( `
		PAD_INDEX = OFF, `
		STATISTICS_NORECOMPUTE = OFF, `
		IGNORE_DUP_KEY = OFF, `
		ALLOW_ROW_LOCKS = ON, `
		ALLOW_PAGE_LOCKS = ON `
	) ON [PRIMARY] `
) ON [PRIMARY] `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

Function Create-ServersProcIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName 
)
	
    $cmd = new-object "System.Data.SqlClient.SqlCommand" 
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
    
    $cmd.CommandText = " `
IF object_id('[dbo].[$($ProcName)]', 'p') IS NULL
BEGIN
EXEC('
CREATE PROCEDURE [dbo].[$($ProcName)]
@Domain nvarchar(30)
,@ServiceFlag nvarchar(10)
,@computername nvarchar(100)
,@IPAddress nvarchar(15)
,@UTCMonitored datetime
AS
BEGIN

INSERT INTO [dbo].[$($TableName)]
( [Domain]
,[ServiceFlag]
,[ComputerName]
,[IPAddress]
,[UTCMonitored]
)
VALUES
( @Domain 
,@ServiceFlag
,@ComputerName
,@IPAddress
,@UTCMonitored)
END'
)
END"

	Write-Debug -Message "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug -Message "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-MonitoringTaskLogs {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()]
	[string]$jnUTCMonitored
	
	, [Parameter(Mandatory=$True)][ValidateSet("BEGIN", "END")]
	[string]$TaskType
	
	, [Parameter(Mandatory=$True)][ValidateSet("SERVERS", "CONNECT", "ADDS", "ADCS", "DNS", "DHCP", "RADIUS", "HEALTH")]
	[string]$ServiceType
	
	, [Parameter(Mandatory=$True)]
	[string]$DomainName

	, [string]$TaskScript
)

try {
	
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]::Text 
	$cmd.Connection = New-SQLConnection

	if (! $TaskScript) 
		{$TaskScript = ""}
	$cmd.CommandText = " `
Insert into TB_MonitoringTaskLogs ([TaskDate], [TaskType], [Company], [ADService], [TaskScript])
values('$($jnUTCMonitored)', '$($TaskType)', '$($DomainName)', '$($ServiceType)', '$($TaskScript)') `
"
	Write-Debug -Message "jnUTCMonitored: $($jnUTCMonitored)"
	Write-Debug -Message "TaskScript: $($TaskScript)"
	Write-Debug -Message "TaskType: $($TaskType)"
	Write-Debug -Message "ServiceType: $($ServiceType)"
	Write-Debug -Message "CommandText: $($cmd.CommandText)"

	$cmd.ExecuteNonQuery() | out-Null
	Write-Host "`n[TaskLogs] $($ServiceType): $($TaskType). ($($TaskScript))`n"

	$cmd.Connection.Close()

}

Catch {
}

Finally {
		
	# To free resources used by a script.
	if (gv jnUTCMonitored) {rv jnUTCMonitored}
	if (gv TaskType) {rv TaskType}
	if (gv ServiceType) {rv ServiceType}
	if (gv TaskScript) {rv TaskScript}

}
} 

function Get-Function {

}