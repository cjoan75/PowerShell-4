# Create a new scheduled task.

$rootpath = "\ADMONTEST"
$domains = @("LGE.NET")	# LG Electronics
$domains += @("LGDISPLAY.GLOBAL")	# LG Display
$domains += @("LGCHEM.COM")	# LG Chemistry
$domains += @("CORP.LGCNS.COM")	# LGCNS U-cloud
$domains += @("LGCLOUD.COM")	# LGCNS P-cloud
$domains += @("HIPLAZA.NET")	# LG Hiplaza
$domains += @("CORP.LGERICSSON.COM")	# LG Nortel

$psfilespath = "$HOME\Documents\ADMON"
$psfiles = ls $psfilespath\*.ps1 -Exclude *TOD*, *ODT*, *-jnServers*
Write-Debug "`$psfiles: $($psfiles.gettype()): $($psfiles.count)."
$psfiles.Name
$DebugPreference = "Continue"

function Get-jnScheduledTaskAction {
param(
	[string]$PSFileName
	, [string]$PSFilePath
	, [string]$TaskPath
)
	$STA = $null

	if ($TaskPath -match "LGE.NET") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server LGEADPMSE3Q -domain LGE.NET -admuser monitor_admin -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}
	elseif ($TaskPath -match "LGDISPLAY.GLOBAL") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server LGDIADP001P -domain LGDISPLAY.GLOBAL -admuser monitor_admin_lgd -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}
	elseif ($TaskPath -match "LGCHEM.COM") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server LCHADDCHQ1 -domain LGCHEM.COM -admuser monitor_admin_lgc -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}
	elseif ($TaskPath -match "CORP.LGCNS.COM") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server LCNPSDC01 -domain CORP.LGCNS.COM -admuser monitor_admin_ucloud -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}
	elseif ($TaskPath -match "LGCLOUD.COM") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server LCNSCPDC00 -domain LGCLOUD.COM -admuser monitor_admin_lgpcloud -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}
	elseif ($TaskPath -match "HIPLAZA.NET") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server HIPAADDC01 -domain HIPLAZA.NET -admuser monitor_admin_hip -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}
	elseif ($TaskPath -match "CORP.LGERICSSON.COM") 
		{$STA = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument ".\$($PSFileName) -server LESPVDC01 -domain CORP.LGERICSSON.COM -admuser monitor_admin_ericsson -admpwd @lgeuser@#" -WorkingDirectory $psfilespath}

	if ($STA -ne $null -and $STA -ne "") {
		return $STA
	}
} # End of function.

foreach ($dom in $domains) {

	$taskpath = "$rootpath\$($dom)\"
	Write-Debug "`$taskpath: $($taskpath.gettype()): $($taskpath.count)."

	$psfiles | % {

		$STT = New-ScheduledTaskTrigger -Once -at ((Get-Date).AddMinutes(2)) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 1)
		$STSS = New-ScheduledTaskSettingsSet -Priority 7
		$STP = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
		$STA = Get-jnScheduledTaskAction -PSFileName $_.Name -PSFilePath $psfilespath -TaskPath $taskpath 

		Write-Debug "`$taskname: $($taskname) in `$taskpath: $($taskpath)"
		#Write-Debug "`$STA: $($STA)"
		#Write-Debug "`$STSS: $($STSS)"
		#Write-Debug "`$STP: $($STP)."

		$taskname = $_.Name.TrimEnd(".ps1")
		Register-ScheduledTask -TaskPath $taskpath -TaskName $taskname -Action $STA -Settings $STSS -Principal $STP -Force

	}

} # End of domains.
