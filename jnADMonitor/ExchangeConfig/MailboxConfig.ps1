param(
	[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$userPrincipalName
)
$hash = @{}
$hash.userPrincipalName = $userPrincipalName
$hash.PSCommandPath = $PSCommandPath

$myResult = $hash

$myResult | Export-Clixml -Path "$env:PUBLIC\$($PSCommandPath.Split("\")[-1]).xml"
