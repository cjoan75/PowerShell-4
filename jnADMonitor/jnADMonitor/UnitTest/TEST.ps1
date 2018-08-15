#
	$DebugPreference = 'continue';

[array]$myResult = invoke-command -cn $ManagedServerFQDN -credential $credential -script {
	
	param ($Servers, $credential, $myDebugPreference)
	
	$DebugPreference = $myDebugPreference;
	
	$myResult = @()
	ForEach ($server in $Servers)
	{
		[array]$buf = invoke-command -cn $server.ComputerName -credential $credential -script {
			param ($myDebugPreference)
			$DebugPreference = $myDebugPreference;
			
			#######
			$uri = "http://files.thecybershadow.net/dhcptest/dhcptest-0.7-win64.exe"
			$FilePath = "$env:USERPROFILE\Downloads\" + $uri.Substring($uri.LastIndexOf("/")+1)
			
			$buf = @{}
			$buf.ComputerName = $env:ComputerName
			$buf.DoesExist = Test-Path $FilePath
									$buf.Result = & $FilePath --Query --Quiet
			
			#######
			
			if ($buf) {return $buf}
		} -ArgumentList ($DebugPreference)
		if ($buf) {$myResult += $buf}
	}
	if ($myResult) {return $myResult}
} -ArgumentList ($Servers, $credential, $DebugPreference)

	$DebugPreference = 'silentlycontinue';

$myResult.Count

