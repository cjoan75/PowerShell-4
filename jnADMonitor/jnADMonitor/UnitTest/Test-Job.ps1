$server = $server
$domain = $domain
$serverfqdn = "$($server).$($domain)"
$userfqdn = "$($admuser)@$($domain)"
$pwd = ConvertTo-SecureString $admpwd -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userfqdn, $pwd


$servers = Get-ADDomainController -Filter {enabled -eq $True}
$servers | % {

Invoke-Command -ComputerName $_.Name -ScriptBlock {

#$DebugPreference = "Continue"
Write-Debug "Now connected to $($env:COMPUTERNAME).$($env:USERDNSDOMAIN) logged on as $(whoami).`n"

Get-Process svchost

} -AsJob -ThrottleLimit 10

$j = get-job
$results = $j | Receive-Job
Write-Host $results -ForegroundColor yellow
} # end of Foreach.

