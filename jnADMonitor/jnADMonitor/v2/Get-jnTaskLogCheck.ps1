param(
	[string]$server
	, [string]$domain
	, [string]$admuser
	, [string]$admpwd
)

$server = $server
$domain = $domain
$serverfqdn = "$($server).$($domain)"
$userfqdn = "$($admuser)@$($domain)"
$pwd = ConvertTo-SecureString $admpwd -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userfqdn, $pwd

#################################
##### SQL Authentication ########
#################################
$SqlServerName = '165.243.197.174'
$DataBaseName = 'ADSysMon'
$SQLUserName = 'ADMAdmin'
$SQLUserPwd = 'qwer123$'

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
	, [Parameter(Mandatory=$True)][ValidateSet("SERVERS", "CONNECT", "ADDS", "ADCS", "DNS", "DHCP", "RADIUS", "HEALTH", "TASK")][string]$ADService
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
Insert-MonitoringTaskLogs -TaskType BEGIN -ADService TASK -jnUTCMonitored $jnUTCMonitored

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
$TableName = "View_ServersTable"
$ProcName = "IF_SERVERS"
[array]$servers = Get-jnSQLData -TableName $TableName

if ($servers.Count -gt 0) {
	Write-Host "[SQL] Servers Retrieved: $($servers.Count)."
}
else {
	$Message = "[SQL] No Servers Retrieved."
    Write-Host $Message -fore yellow

	# Log the END time as GMT.
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	Insert-MonitoringTaskLogs -TaskType END -ADService TASK -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

	break
}

# Add host to TrustedHosts to the local client to use NTLM.
if ($domain -ne $env:USERDNSDOMAIN ) {
    if (!(Get-jnTrustedHosts -Value "*.$($domain)"))
	{ 
		if (!(Get-jnTrustedHosts -Value $serverfqdn))
			{Add-jnTrustedHosts -Value $val}
	}
}

# Get events.
try {
	$ErrorActionPreference = "Stop"

	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $cred
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

	[array]$jnDHCPEventResult = Invoke-Command -Session $session -script {
	param (
		[Parameter(Mandatory=$True)]$Credential
		, [Parameter(Mandatory=$True)][array]$servers
		, [Parameter(Mandatory=$True)][System.Management.Automation.ActionPreference]$myDebugPreference
	)

		$DebugPreference = $myDebugPreference
		$myresult = @()

		$servers | % {

			if (Test-Connection $_.ComputerName -Count 1 -Quiet) {

			try {
				$ErrorActionPreference = "Stop"

				# to create powershell remote session
				$session = New-PSSession -cn $_.ComputerName -credential $Credential
				Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

				[array]$buf = Invoke-Command -Session $session -script {

					Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

					$jnComputerName = @{Name='ComputerName'; Expression={$_.MachineName.SubString(0, $_.MachineName.IndexOf("."))}}
					$jnUTCMonitored = @{Name="jnUTCMonitored"; EXPRESSION={(Get-Date).ToUniversalTime()}}
					$jnServiceFlag = @{Name="jnServiceFlag"; Expression={"TASK"}}
					$begindate = (Get-Date).AddHours(-1*0.08)

					[array]$buf = Get-WinEvent -FilterHashTable @{ `
						ProviderName = `
							'Microsoft-Windows-TaskScheduler' `
							, 'TaskScheduler' `
							; `
						StartTime = $begindate; `
						Level = 1, 2, 3, 4 } -ea 0 | 
						? { `
							$_.ID -ne 100 -And $_.ID -ne 101 -And $_.ID -ne 102 -And $_.ID -ne 103 -And $_.ID -ne 107 -And 
                            $_.ID -ne 108 -And $_.ID -ne 110 -And $_.ID -ne 111 -And $_.ID -ne 114 -And $_.ID -ne 118 -And
                            $_.ID -ne 119 -And $_.ID -ne 129 -And $_.ID -ne 140 -And $_.ID -ne 153 -And $_.ID -ne 200 -And 
                            $_.ID -ne 201 -And $_.ID -ne 202 -And $_.ID -ne 203 -And $_.ID -ne 322 -And $_.ID -ne 324 -And 
                            $_.ID -ne 325 -And $_.ID -ne 329 -And $_.ID -ne 330 -And $_.ID -ne 332 -And $_.ID -ne 400 -And
                            $_.ID -ne 402 -And $_.ID -ne 700 `
							#100 : 작업이 시작되었습니다.
                            #101 : 작업을 시작하지 못했습니다.
                            #102 : 작업이 완료되었습니다.
                            #103 : 동작을 시작하지 못했습니다.
                            #106 : 등록된 작업
                            #107 : 스케줄러에서 작업이 트리거되었습니다.
                            #108 : 이벤트에서 작업이 트리거되었습니다.
                            #110 : 사용자가 작업을 트리거했습니다.
                            #111 : 작업이 종료되었습니다.
                            #114 : 누락된 작업이 시작되었습니다.
                            #118 : 컴퓨터 시작에 의해 작업이 트리거되었습니다.
                            #119 : 로그온 시 작업이 트리거되었습니다.
                            #129 : 만들어진 작업 프로세스
                            #140 : 작업 등록이 업데이트되었습니다.
                            #141 : 작업 등록이 삭제되었습니다.
                            #153 : 누락된 작업 시작이 거부되었습니다.
                            #200 : 동작이 시작되었습니다.
                            #201 : 동작이 완료되었습니다.
                            #202 : 동작이 실패했습니다.
                            #203 : 동작을 시작하지 못했습니다.
                            #322 : 인스턴스가 이미 실행 중이므로 시작 요청이 무시되었습니다.
                            #324 : 인스턴스가 이미 실행 중이므로 시작 요청이 지연되었습니다.
                            #325 : 대기 중인 요청 실행
                            #329 : 시간 제한에 도달했으므로 작업을 중지 중입니다.
                            #330 : 사용자 요청으로 인해 작업을 중지 중입니다.
                            #332 : 사용자가 로그온하지 않았기 때문에 시작 조건을 충족하지 못했습니다.
                            #400 : 서비스 시작됨
                            #402 : 서비스를 종료하고 있습니다.
                            #700 : 호환성 모듈을 시작했습니다.
							} |
						sort TimeCreated |
						select LogName, TimeCreated, Id, ProviderName, LevelDisplayName, Message, $jnComputerName, $jnUTCMonitored, $jnServiceFlag

					if ($buf.Count -gt 0) {
						Write-Debug "$($env:COMPUTERNAME): $($buf.GetType()), $($buf.count)."
						return $buf
					}

				}

				if ($buf.Count -gt 0) {
					$myresult += @($buf)
					Write-Debug "`$buf ($($_.ComputerName)): $($buf.gettype()): $($buf.count)"
					Write-Debug "`$myresult: $($myresult.gettype()): $($myresult.count)"
				}
			}
			Catch {
				$jnUTCMonitored = (Get-Date).ToUniversalTime()
				$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
				Write-Host $Message -fore red
			}
			Finally {
				$ErrorActionPreference = "Continue"
	
				# To free resources used by a script.

				# to close powershell remote session
				Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
				Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

			}

			} # End of If the server is currently connected.

		} # end of Foreach.

		Write-Host "`n[PSSession] Data collected: $($myresult.Count)."

		return $myresult

	} -ArgumentList ($cred, $servers, $DebugPreference)

	$jnDHCPEventResult | group ComputerName | sort Count
}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService TASK -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-Event {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)

Function Create-jnSqlTableIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
)
	    	  
    $cmd = new-object "System.Data.SqlClient.SqlCommand"
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
        
    $cmd.CommandText = " `
IF OBJECT_ID('[dbo].[$($TableName)]') IS NULL `
CREATE TABLE [dbo].[$($TableName)](	`
[LogName] [nvarchar](30) NOT NULL,`
[TimeCreated] [datetime] NOT NULL,`
[Id] [nvarchar](30) NOT NULL,`
[ProviderName] [nvarchar](30) NOT NULL,`
[LevelDisplayName] [nvarchar](30) NOT NULL,`
[Message] [nvarchar](max) NOT NULL,`
[ComputerName] [nvarchar](50) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[ServiceFlag] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()

}

Function Create-jnSqlProcedureIfNotExist {
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
 @LogName nvarchar(30)
,@TimeCreated datetime
,@Id nvarchar(30)
,@ProviderName nvarchar(30)
,@LevelDisplayName nvarchar(30)
,@Message nvarchar(max)
,@ComputerName nvarchar(50)
,@UTCMonitored datetime
,@ServiceFlag nvarchar(10)

AS
BEGIN

INSERT INTO [dbo].[$($TableName)]
   ([LogName]
   ,[TimeCreated]
   ,[Id]
   ,[ProviderName]
   ,[LevelDisplayName]
   ,[Message]
   ,[ComputerName]
   ,[UTCMonitored]
   ,[ServiceFlag])
 VALUES
   (@LogName,
	@TimeCreated,
	@Id,
	@ProviderName,
	@LevelDisplayName,
    @Message,
    @ComputerName,
    @UTCMonitored,
    @ServiceFlag)

END'
)
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

}

function Insert-ProblemManagement {
param (
	[Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
	$insertproblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].Id -eq "106") {
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertproblem
		
				$ProbScrp = $data[$i].LevelDisplayName.ToString() + "<br/>" + $data[$i].message
				$serviceitem = $null
				switch($Data[$i].jnServiceFlag) {
					"ADCS" {$serviceitem = "CS01"; Break}
					"ADDS" {$serviceitem = "DS01"; Break}
					"DNS" {$serviceitem = "DN01"; Break}
					"DHCP" {$serviceitem = "DH01"; Break}
					"TASK" {$serviceitem = "TS01"; Break}
					Default {$serviceitem = $null }
				}

	
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", $Data[$i].jnServiceFlag)
				if ($serviceitem -eq $null)
					{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "Null")}
				else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", $serviceitem)}
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
		
			                       
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
				Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
				Write-Debug "CommandText: $($cmd.CommandText)."

				$cmd.ExecuteNonQuery() | out-Null
				$cmd.Connection.Close()
      
				$rowcount +=  1
			}
		}

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}
	}

}

try {
	$ErrorActionPreference = "Stop"

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_EVENT"
	$ProcName = "IF_$($company)_EVENT"

	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
   
	#Sql Command definition
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

				#Connect to Sql Server        
				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $ProcName
		
				if ($data[$i].LogName -eq $null -or $data[$i].LogName -eq "") 
					{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@LogName", "Null")}
				else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@LogName", $data[$i].LogName)}

				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@TimeCreated", $data[$i].TimeCreated)
	
				if ($data[$i].Id -eq $null -or $data[$i].Id -eq "") 
					{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Id", "Null")}
				else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@Id", $data[$i].Id)}
				if ($data[$i].ProviderName -eq $null -or $data[$i].ProviderName -eq "") 
					{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ProviderName", "Null")}
				else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ProviderName", $data[$i].ProviderName)}
				if ($data[$i].LevelDisplayName.ToString() -eq $null -or $data[$i].LevelDisplayName.ToString() -eq "") 
					{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", "Null")}
				else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@LevelDisplayName", ($data[$i].LevelDisplayName).ToString())}
				if ($data[$i].Message -eq $null -or $data[$i].Message -eq "") 
					{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", "Null")}
				else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@Message", $data[$i].Message)}
				if ($data[$i].ComputerName -eq $null -or  $data[$i].ComputerName -eq "") 
					{$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
				else {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
	
				$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)

				if ($data[$i].jnServiceFlag -eq $null -or $data[$i].jnServiceFlag -eq "") 
					{$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", "Null")}
				else {$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@ServiceFlag", $data[$i].jnServiceFlag)}
        
				$cmd.Parameters.Clear()
        
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
				[void]$cmd.Parameters.Add($SQLParameter7)
				[void]$cmd.Parameters.Add($SQLParameter8)
				[void]$cmd.Parameters.Add($SQLParameter9)
       
				$cmd.ExecuteNonQuery() | out-null

				$cmd.Connection.Close()

			} # End of for.

	} # End of If it contains data.
	else {
		Write-host "[SQL] No Data returned from PSSession."
	} # End of If it doesn't contain data.

}
  
Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

Finally {
	$ErrorActionPreference = "Continue"
	
	# To free resources used by a script.
	if (gv Data) {rv Data}
}
  
}
if ($jnDHCPEventResult.Count -gt 0)	{Insert-Event -Data $jnDHCPEventResult}
if (gv jnDHCPEventResult -ea 0) {rv jnDHCPEventResult}

# Log the END time as GMT.
$jnUTCMonitored = (Get-Date).ToUniversalTime()
Insert-MonitoringTaskLogs -TaskType END -ADService TASK -jnUTCMonitored $jnUTCMonitored

