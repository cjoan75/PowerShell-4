#
# Set_CredentialFile.ps1
#
# Sets credential file.

$buf = @()
$buf += @{upn = "monitor_admin_ucloud@CORP.LGCNS.COM"; pwd = '#fhzjf01'}
$buf += @{upn = "monitor_admin_ericsson@CORP.LGERICSSON.COM"; pwd = '!qaz2wsx3e'}
$buf += @{upn = "monitor_admin_hip@HIPLAZA.NET"; pwd = '!qaz2wsx3e'}
$buf += @{upn = "monitor_admin_lgc@LGCHEM.COM"; pwd = 'lgchem2017!'}
$buf += @{upn = "monitor_admin_pcloud@LGCLOUD.COM"; pwd = '#fhzjf01'}
$buf += @{upn = "monitor_admin_lgd@LGDISPLAY.GLOBAL"; pwd = 'LGD@dmin1!'}
$buf += @{upn = "monitor_admin@LGE.NET"; pwd = '@adams12#$'}

if ($PSVersionTable.PSVersion.Major -ge 3)
{
	foreach ($ht in $buf)
	{
		$pwd = ConvertTo-SecureString $ht.pwd -AsPlainText -Force
		$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ht.upn, $pwd
	
		$FilePath = "$env:USERPROFILE\Documents\$($ht.upn).cred"
		if ($credential) {$credential | Export-CliXml $FilePath}
		Write-Host (ls $FilePath)
	}
}

