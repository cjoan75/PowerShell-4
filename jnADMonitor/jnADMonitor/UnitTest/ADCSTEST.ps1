#
# ADCSTEST.ps1 -- service availability.
#


$admpwd = 'rmatnsdl1!Wksek'
$server = 'dnprod05'
$domain = 'dotnetsoft.co.kr'
$admuser = 'admin2'
$serverfqdn = "$($server).$($domain)"
$userfqdn = "$($admuser)@$($domain)"
$pwd = ConvertTo-SecureString $admpwd -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userfqdn, $pwd
$servers = Get-SQLData -TableName 'Tb_Servers2' -ServiceFlag 'ADCS' -Domain 'dotnetsoft.co.kr'
 
$session = New-PSSession -cn $serverfqdn -credential $credential -Authentication Kerberos 

Write-Debug "CONNECTED TO $($serverfqdn) AS $($userfqdn).`n"



# Get service availability.

try {
	
	# to create powershell remote session
	$session = New-PSSession -cn $serverfqdn -credential $credential -Authentication Kerberos
	Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

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
							$session = New-PSSession -cn $server.ComputerName -Credential $credential -Authentication Kerberos
							Write-Debug "[PSSession] Session Established to $($session.ComputerName), InstanceId: $($session.InstanceId)."

							$hash = Invoke-Command -Session $session -script {

								Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

								$hash = @{}
								$hash.ComputerName = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
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
								if ($buf_error) {
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

								ICertAdmin2::GetCAProperty method
								https://docs.microsoft.com/en-us/windows/desktop/api/certadm/nf-certadm-icertadmin2-getcaproperty

								CR_PROP_CRLSTATE

								Data type of the property: Long 
								State of the CA's CRL. The values can be:

								CA_DISP_REVOKED
								CA_DISP_VALID
								CA_DISP_INVALID
								CA_DISP_ERROR
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
									#$buf | % {if ($_ -notmatch "Certutil: ") {$hash.CrlState += @($_.SubString($_.IndexOf("-- ")+3))}}
									$hash.CrlState = $buf[0].SubString($buf[0].IndexOf("-- ")+3)
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CrlState: $($hash.CrlState)"

								<# CA Certificate Info.
								
								gci Cert:\Localmachine\ -Recurse| ? {$_.Subject -like "CN=$($hash.CAName)*"} | sort Thumbprint -unique | select NotAfter, Subject | ft -a
								
[lgeadpmse1q.lge.net]: PS C:\Users\TEMP.LGE.001\Documents> invoke-command -cn BSNDR10-DC11 -script {gci Cert:\Localmachine\ -Recurse | ? {$_.Subject -like "CN=lgeissuingca6*"} | select * -first 1 }


PSPath             : Microsoft.PowerShell.Security\Certificate::Localmachine\CA\4CC456549008464C58E78442F29935F157D6C31
                     F
PSParentPath       : Microsoft.PowerShell.Security\Certificate::Localmachine\CA
PSChildName        : 4CC456549008464C58E78442F29935F157D6C31F
PSDrive            : cert
PSProvider         : Microsoft.PowerShell.Security\Certificate
PSIsContainer      : False
Archived           : False
Extensions         : {System.Security.Cryptography.X509Certificates.X509Extension, System.Security.Cryptography.X509Cer
                     tificates.X509SubjectKeyIdentifierExtension, System.Security.Cryptography.X509Certificates.X509Ext
                     ension, System.Security.Cryptography.X509Certificates.X509KeyUsageExtension...}
FriendlyName       :
IssuerName         : System.Security.Cryptography.X509Certificates.X500DistinguishedName
NotAfter           : 1/17/2024 4:48:24 PM
NotBefore          : 1/17/2014 4:38:24 PM
HasPrivateKey      : False
PrivateKey         :
PublicKey          : System.Security.Cryptography.X509Certificates.PublicKey
RawData            : {48, 130, 6, 198...}
SerialNumber       : 2AEC1F2400000000000D
SubjectName        : System.Security.Cryptography.X509Certificates.X500DistinguishedName
SignatureAlgorithm : System.Security.Cryptography.Oid
Thumbprint         : 4CC456549008464C58E78442F29935F157D6C31F
Version            : 3
Handle             : 436007664
Issuer             : CN=LGERootCA
Subject            : CN=LGEIssuingCA6, DC=LGE, DC=NET
PSComputerName     : bsndr10-dc11
RunspaceId         : e06fcc5a-58e4-4187-9e41-611c29fbd333
PSShowComputerName : True

								#>
								#$hash = @{}; $buf = certutil -CAInfo name; $buf | % {if ($_ -match "CA Name") {$hash.CAName += @($_.Substring($_.IndexOf("CA Name")+7+1+2))}};
								$buf_error = $False
								$buf = gci Cert:\Localmachine\ -Recurse | ? {$_.Subject -like "CN=$($hash.CAName)*"} | sort Thumbprint -unique | sort NotAfter -Descending
								$buf | % {if ($_ -match "ERROR" -or $_ -match "FAIL") {$buf_error = $True}}
								if ($buf_error)
								{
									$hash.IsError = $True
								} else {
									#$buf | % {$hash.CACertificate = $_}
									$hash.CACertificate = $buf[0]
								}
								Write-Debug "`$buf_error: $($buf_error)"
								Write-Debug "`$hash.CACertificate: $($hash.CACertificate)"

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
								#if ($buf_metric -eq 'Weeks') {$buf_unit = $buf_unit * 7}
								Switch ($buf_metric)
								{
									'Weeks' {$buf_unit = $buf_unit * 7}
									'Months' {$buf_unit = $buf_unit * 30}
									'Years' {$buf_unit = $buf_unit * 365}
								}
Write-Debug $buf_unit.GetType()
Write-Debug $buf_unit
								$hash.CrlPeriod = New-TimeSpan -Days $buf_unit
								certutil -getreg CA\CrlDeltaPeriod | % {if ($_ -like '* = *') {$buf_metric = $_.SubString($_.IndexOf("= ")+2)}}
								certutil -getreg CA\CrlDeltaPeriodUnits | % {if ($_ -like '* = *') {[int]$buf_unit = $_.SubString($_.IndexOf("= ")+2)}}
								#if ($buf_metric -eq 'Weeks') {$buf_unit = $buf_unit * 7}
								Switch ($buf_metric)
								{
									'Weeks' {$buf_unit = $buf_unit * 7}
									'Months' {$buf_unit = $buf_unit * 30}
									'Years' {$buf_unit = $buf_unit * 365}
								}
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

	$jnADCSServiceAvailabilityResult | % {"`t$($_.jnUTCMonitored)`t$($_.IsError)`t$($_.ComputerName)"}

}
Catch {
	$jnUTCMonitored = (Get-Date).ToUniversalTime()
	$Message = "[$($jnUTCMonitored)][ERROR] $($Error[0]).`n"
    Write-Host $Message -fore red

	# Log the END time as GMT.
	Insert-MonitoringTaskLogs -TaskType END -ADService ADCS -jnUTCMonitored $jnUTCMonitored -TaskScript $Message

}
Finally {
		
	# To free resources used by a script.

	# to close powershell remote session
	Remove-PSSession -InstanceId $session.InstanceId -Confirm:$False
	Write-Debug "[PSSession] Session closed from $($session.ComputerName), InstanceId: $($session.InstanceId).`n"

}

function Insert-ADCSServiceAvailability {
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
[ComputerName] [nvarchar](50) NOT NULL,`
[OperatingSystem] [nvarchar](100) NULL,`
[OperatingSystemServicePack] [nvarchar](100) NULL,`
[CAName] [nvarchar](30) NOT NULL,`
[DNSName] [nvarchar](30) NOT NULL,`
[CAType] [nvarchar](200) NOT NULL,`
[PingAdmin] [nvarchar](200) NOT NULL,`
[Ping] [nvarchar](200) NOT NULL,`
[UTCMonitored] [datetime] NOT NULL,`
[CrlPublishStatus] [nvarchar](MAX) NOT NULL,`
[DeltaCrlPublishStatus] [nvarchar](MAX) NOT NULL,`
[IsError] [nvarchar](10) NOT NULL,`
[ManageStatus] [nvarchar](2) NULL,`
[Manager] [nvarchar](20) NULL,`
[ManageScript] [nvarchar](max) NULL,`
[ManageDate] [datetime] NULL, `
[Subject] [nvarchar](200) NOT NULL, `
[Thumbprint] [nvarchar](100) NOT NULL, `
[NotAfter] [datetime] NOT NULL, `
[CrlState] [nvarchar](20) NOT NULL, `
[CrlPeriod] [nvarchar](20) NOT NULL, `
[CrlDeltaPeriod] [nvarchar](20) NOT NULL `
) `
ELSE `
PRINT 'The table already exists.' `
"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
	$cmd.Connection.Close()
Write-Host "Successfully Created!"

}

Function Create-jnSqlProcedureIfNotExist {
param (
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TableName
	, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ProcName 
)
    
    $cmd = new-object "System.Data.SqlClient.SqlCommand"
    $cmd.CommandType = [System.Data.CommandType]::Text
    $cmd.Connection = New-SQLConnection
    
    $cmd.CommandText = "IF object_id('[dbo].[$($ProcName)]', 'p') IS NULL `
BEGIN`
	EXEC('`
	CREATE PROCEDURE [dbo].[$($ProcName)] `
			 @ComputerName nvarchar(50) `
			,@OperatingSystem nvarchar(100) `
			,@OperatingSystemServicePack nvarchar(100) `
			,@CAName nvarchar(30) `
			,@DNSName nvarchar(30) ` 
			,@CAType nvarchar(200) `
			,@PingAdmin nvarchar(200) `
			,@Ping nvarchar(200) `
			,@UTCMonitored datetime`	
			,@CrlPublishStatus nvarchar(MAX) `
			,@DeltaCrlPublishStatus nvarchar(MAX) `
			,@IsError nvarchar(10) `
			,@Subject nvarchar(200) `
			,@Thumbprint nvarchar(100) `
			,@NotAfter datetime `
			,@CrlState nvarchar(20) `
			,@CrlPeriod nvarchar(20) `
			,@CrlDeltaPeriod nvarchar(20) ` 
	AS`
	BEGIN`
 `
	INSERT INTO [dbo].[$($TableName)] `
		   (  [ComputerName],`
			  [OperatingSystem],`
			  [OperatingSystemServicePack],`
			  [CAName],`
			  [DNSName],`
			  [CAType],`
			  [PingAdmin],`
			  [Ping],`
			  [UTCMonitored],`
			  [CrlPublishStatus],`
			  [DeltaCrlPublishStatus],`
			  [IsError], `
			  [Subject], `
			  [Thumbprint], `
			  [NotAfter], `
			  [CrlState], `
			  [CrlPeriod], 
			  [CrlDeltaPeriod]`
		   ) `
		 VALUES`
		   (  @ComputerName,`
			  @OperatingSystem,`
			  @OperatingSystemServicePack,`
			  @CAName,`
			  @DNSName,`
			  @CAType,`
			  @PingAdmin,`
			  @Ping,`
			  @UTCMonitored,`
			  @CrlPublishStatus,`
			  @DeltaCrlPublishStatus,`
			  @IsError,`
			  @Subject, `
			  @Thumbprint, `
			  @NotAfter, `
			  @CrlState, `
			  @CrlPeriod, `
			  @CrlDeltaPeriod `
		   ) `
`
	END'`
	) `
END"

	Write-Debug "ConnectionString: $($cmd.Connection.ConnectionString)."
	Write-Debug "CommandText: $($cmd.CommandText)."

    $cmd.ExecuteNonQuery() | out-null
    $cmd.Connection.Close()

 Write-Host "Successfully Created!"

}

function Insert-ProblemManagement {
param (
    [Parameter(Mandatory=$True)][AllowNull()][array]$Data
)
	
	$insertProblem = "IF_ProblemManagement"
	

	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

	if ($Data.count -gt 0) {

		for($i = 0;$i -lt $Data.count;$i++) {

			if ($Data[$i].count -eq 0) {continue}

			if ($data[$i].IsError -eq $true) {

				$cmd.Connection = New-SQLConnection
				$cmd.CommandText = $insertProblem
		
				for($k = 0;$k -lt $data[$i].PingAdmin.count;$k++) {$PingAdmin += $data[$i].PingAdmin[$k] + "<br/>"}
				for($j = 0;$j -lt $data[$i].Ping.count;$j++) {$Ping += $data[$i].Ping[$j] + "<br/>"}
				for($l = 0;$l -lt $data[$i].CrlPublishStatus.count;$l++) {$CrlPublishStatus += $data[$i].CrlPublishStatus[$l] + "<br/>"}
				for($m = 0;$m -lt $data[$i].DeltaCrlPublishStatus.count;$m++) {$DeltaCrlPublishStatus += $data[$i].DeltaCrlPublishStatus[$m] + "<br/>"}
		
				$ProbScrp = "CAName: " + $data[$i].CAName + "<br/>DNSName: " + $data[$i].DNSName + "<br/>CAType: " + $data[$i].CAType + "<br/>PingAdmin: " + $PingAdmin + "<br/>Ping: " + $Ping + "<br/>CrlPublishStatus: " + $CrlPublishStatus + "<br/>DeltaCrlPublishStatus: " + $DeltaCrlPublishStatus
		
				$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@MonitoredTime", $Data[$i].jnUTCMonitored)
				$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@Company", $Domain)
				$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@ADService", "ADCS")
				$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@ServiceItem", "CS04")
				$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $Data[$i].ComputerName)
				$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@ProblemScript", $ProbScrp)
		
			                       
				$cmd.Parameters.Clear()
               
				[void]$cmd.Parameters.Add($SQLParameter1)
				[void]$cmd.Parameters.Add($SQLParameter2)
				[void]$cmd.Parameters.Add($SQLParameter3)
				[void]$cmd.Parameters.Add($SQLParameter4)
				[void]$cmd.Parameters.Add($SQLParameter5)
				[void]$cmd.Parameters.Add($SQLParameter6)
        
				$cmd.ExecuteNonQuery() | out-Null

				$cmd.Connection.Close()
				$rowcount +=  1
			}
		} # End of for.

		if ($rowcount -gt 0) {Write-Host "[Problem Management] Rows Inserted: $($rowcount)." -fore yellow}

	} # End of function.

}

try {

	$company = $domain.replace(".","_")
	$TableName = "TB_$($company)_ADCSServiceAvailability"
	$ProcName = "IF_$($company)_ADCSServiceAvailability"
	
	Create-jnSqlTableIfNotExist -TableName $TableName
	Create-jnSqlProcedureIfNotExist -TableName $TableName -ProcName $ProcName
	Insert-ProblemManagement -Data $Data
 
	$cmd = new-object "System.Data.SqlClient.SqlCommand" 
	$cmd.CommandType = [System.Data.CommandType]"StoredProcedure" 

	$rowcount = 0

Write-Host $cmd -ForegroundColor Yellow

	if ($Data.count -gt 0) {
		Write-Debug "[SQL] Started to insert."

		for($i = 0;$i -lt $Data.count;$i++) {
 
#if ($Data[$i].count -eq 0) {continue}

			$cmd.Connection = New-SQLConnection
			$cmd.CommandText = $ProcName
Write-Host $cmd.Connection -ForegroundColor Green	
			$PingAdmin, $PingAdmin, $CrlPublishStatus, $DeltaCrlPublishStatus = $null
	
			if ($data[$i].ComputerName -eq $null -or $data[$i].ComputerName -eq "") 
				{$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", "Null")}
			else {$SQLParameter1 = New-Object System.Data.SqlClient.SqlParameter("@ComputerName", $data[$i].ComputerName)}
       
			if ($data[$i].OperatingSystem -eq $null -or $data[$i].OperatingSystem -eq "") 
				{$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", "Null")}
			else {$SQLParameter2 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystem", $data[$i].OperatingSystem)}
		
			if ($data[$i].OperatingSystemServicePack -eq $null -or $data[$i].OperatingSystemServicePack -eq "") 
				{$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", "Null")}
			else {$SQLParameter3 = New-Object System.Data.SqlClient.SqlParameter("@OperatingSystemServicePack", $data[$i].OperatingSystemServicePack)}
		
			if ($data[$i].CAName -eq $null -or $data[$i].CAName -eq "") 
				{$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", "Null")}
			else {$SQLParameter4 = New-Object System.Data.SqlClient.SqlParameter("@CAName", $data[$i].CAName)}
		
			if ($data[$i].DNSName -eq $null -or $data[$i].DNSName -eq "") 
				{$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", "Null")}
			else {$SQLParameter5 = New-Object System.Data.SqlClient.SqlParameter("@DNSName", $data[$i].DNSName)}
		
			if ($data[$i].CAType -eq $null -or $data[$i].CAType -eq "") 
				{$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", "Null")}
			else {$SQLParameter6 = New-Object System.Data.SqlClient.SqlParameter("@CAType", $data[$i].CAType)}	
		
			if ($data[$i].PingAdmin.count -eq 0) {$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", "Null")}
			else {
			for($k = 0;$k -lt $data[$i].PingAdmin.count;$k++) {$PingAdmin += $data[$i].PingAdmin[$k] + "<br/>"}
			$SQLParameter7 = New-Object System.Data.SqlClient.SqlParameter("@PingAdmin", $PingAdmin)}
		
			if ($data[$i].Ping.count -eq 0) {$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", "Null")}
			else {
			for($j = 0;$j -lt $data[$i].Ping.count;$j++) {$Ping += $data[$i].Ping[$j] + "<br/>"}
			$SQLParameter8 = New-Object System.Data.SqlClient.SqlParameter("@Ping", $Ping)}
		
			$SQLParameter9 = New-Object System.Data.SqlClient.SqlParameter("@UTCMonitored", $data[$i].jnUTCMonitored)
		
			if ($data[$i].CrlPublishStatus.count -eq 0) {$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", "Null")}
			else {
				for($l = 0;$l -lt $data[$i].CrlPublishStatus.count;$l++) 
					{$CrlPublishStatus += $data[$i].CrlPublishStatus[$l] + "<br/>"}
				$SQLParameter10 = New-Object System.Data.SqlClient.SqlParameter("@CrlPublishStatus", $CrlPublishStatus)
			}
		
			if ($data[$i].DeltaCrlPublishStatus.count -eq 0) {$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", "Null")}
			else {
				for($m = 0;$m -lt $data[$i].DeltaCrlPublishStatus.count;$m++) 
					{$DeltaCrlPublishStatus += $data[$i].DeltaCrlPublishStatus[$m] + "<br/>"}
				$SQLParameter11 = New-Object System.Data.SqlClient.SqlParameter("@DeltaCrlPublishStatus", $DeltaCrlPublishStatus)
			}
		
			if ($data[$i].IsError.Tostring() -eq $null -or $data[$i].IsError.Tostring() -eq "") 
				{$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@IsError", "Null")}
			else {$SQLParameter12 = New-Object System.Data.SqlClient.SqlParameter("@IsError", $data[$i].IsError.ToString())}
Write-Debug "Subject"
Write-Debug $data[$i].CACertificate.Subject.GetType()

			#if ($data[$i].CACertificate.Subject.Tostring() -eq $null -or $data[$i].CACertificate.Subject.Tostring() -eq "") 
				$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@Subject", "Null")
			#else {$SQLParameter13 = New-Object System.Data.SqlClient.SqlParameter("@Subject", $data[$i].CACertificate.Subject.Tostring())}
Write-Debug $SQLParameter13.Value
Write-Debug "Thumbprint"
Write-Debug $data[$i].CACertificate.Thumbprint.GetType()

			#if ($data[$i].CACertificate.Thumbprint.Tostring() -eq $null -or $data[$i].CACertificate.Thumbprint.Tostring() -eq "") 
				$SQLParameter14 = New-Object System.Data.SqlClient.SqlParameter("@Thumbprint", "Null")
			#else {$SQLParameter14 = New-Object System.Data.SqlClient.SqlParameter("@Thumbprint", $data[$i].CACertificate.Thumbprint.Tostring())}
Write-Debug $SQLParameter14.Value
Write-Debug "NotAfter"
Write-Debug $data[$i].CACertificate.NotAfter.Gettype()

			#if ($data[$i].CACertificate.NotAfter.ToString() -eq $null -or $data[$i].CACertificate.NotAfter.ToString() -eq "") 
				$SQLParameter15 = New-Object System.Data.SqlClient.SqlParameter("@NotAfter", (Get-Date).ToString())
			#else {$SQLParameter15 = New-Object System.Data.SqlClient.SqlParameter("@NotAfter", $data[$i].CACertificate.NotAfter.ToString())}
Write-Debug $SQLParameter15.Value
Write-Debug "CrlDeltaPeriod"
Write-Debug $data[$i].CrlDeltaPeriod.Tostring()

			if ($data[$i].CrlDeltaPeriod.Tostring() -eq $null -or $data[$i].CrlDeltaPeriod.Tostring() -eq "") 
				{$SQLParameter16 = New-Object System.Data.SqlClient.SqlParameter("@CrlDeltaPeriod", "Null")}
			else {$SQLParameter16 = New-Object System.Data.SqlClient.SqlParameter("@CrlDeltaPeriod", $data[$i].CrlDeltaPeriod.ToString())}
Write-Debug "CrlPeriod"
Write-Debug $data[$i].CrlPeriod.Tostring()

			if ($data[$i].CrlPeriod.Tostring() -eq $null -or $data[$i].CrlPeriod.Tostring() -eq "") 
				{$SQLParameter17 = New-Object System.Data.SqlClient.SqlParameter("@CrlPeriod", "Null")}
			else {$SQLParameter17 = New-Object System.Data.SqlClient.SqlParameter("@CrlPeriod", $data[$i].CrlPeriod.ToString())}

Write-Debug "CrlState"
Write-Debug $data[$i].CrlState.Gettype()
			if ($data[$i].CrlState.Tostring() -eq $null -or $data[$i].CrlState.Tostring() -eq "") 
				{$SQLParameter18 = New-Object System.Data.SqlClient.SqlParameter("@CrlState", "Null")}
			else {$SQLParameter18 = New-Object System.Data.SqlClient.SqlParameter("@CrlState", $data[$i].CrlState.Tostring())}

			$cmd.Parameters.Clear()

Write-Host "??" -ForegroundColor Green
               
			[void]$cmd.Parameters.Add($SQLParameter1)
			[void]$cmd.Parameters.Add($SQLParameter2)
			[void]$cmd.Parameters.Add($SQLParameter3)
			[void]$cmd.Parameters.Add($SQLParameter4)
			[void]$cmd.Parameters.Add($SQLParameter5)
			[void]$cmd.Parameters.Add($SQLParameter6)
			[void]$cmd.Parameters.Add($SQLParameter7)
			[void]$cmd.Parameters.Add($SQLParameter8)
			[void]$cmd.Parameters.Add($SQLParameter9)
			[void]$cmd.Parameters.Add($SQLParameter10)
			[void]$cmd.Parameters.Add($SQLParameter11)
			[void]$cmd.Parameters.Add($SQLParameter12)
			[void]$cmd.Parameters.Add($SQLParameter13)
			[void]$cmd.Parameters.Add($SQLParameter14)
			[void]$cmd.Parameters.Add($SQLParameter15)
			[void]$cmd.Parameters.Add($SQLParameter16)
			[void]$cmd.Parameters.Add($SQLParameter17)
			[void]$cmd.Parameters.Add($SQLParameter18)
Write-Host $cmd.Parameters.Value -ForegroundColor Yellow					
			$cmd.ExecuteNonQuery() | out-Null

			$cmd.Connection.Close()
			$rowcount +=  1
		} # End of For.

		Write-host "[SQL] Rows inserted: $($Data.count)."

	} # End of If it contains data.
	else {
		Write-host "[SQL] No Data returned from PSSession."
	} # End of If it doesn't contain data.

}

Catch {
	Write-Host "[ERROR] $($Error[0]).`n" -Fore Red
}

finally {
		
	# To free resources used by a script.
	if (gv Data) {rv Data}
  }

 }
Insert-ADCSServiceAvailability -Data $jnADCSServiceAvailabilityResult
if (gv jnADCSServiceAvailabilityResult -ea 0) {rv jnADCSServiceAvailabilityResult}



