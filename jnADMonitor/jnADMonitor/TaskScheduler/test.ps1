#
# test.ps1
#
$logFilePath = "C:\Users\AdMonAdm\Documents\ADMON\v3\Test.log"

$ManagedServerFQDN ="LGEADPMSE6Q.LGE.NET"; $userPrincipalName = "monitor_admin@LGE.NET"
$FilePath = "C:\Users\AdMonAdm\Documents\ADMON\v3\$($userPrincipalName).cred"
$credential = Import-Clixml $FilePath
$credential.UserName | Add-Content -Encoding Unicode -Path $logFilePath
