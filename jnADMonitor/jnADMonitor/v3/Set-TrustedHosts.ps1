#
# Set_TrustedHosts.ps1
#
# Add host to TrustedHosts to the local client to use NTLM.

function Set-jnTrustedHosts
{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName
)
	if (! (Get-TrustedHosts -Value "*.$($DomainName)"))
	{
		Add-TrustedHosts -Value "*.$($DomainName)"
	}
}

Set-jnTrustedHosts -DomainName "CORP.LGCNS.COM"

Set-jnTrustedHosts -DomainName "CORP.LGERICSSON.COM"

Set-jnTrustedHosts -DomainName "HIPLAZA.NET"

Set-jnTrustedHosts -DomainName "LGCHEM.COM"

Set-jnTrustedHosts -DomainName "LGCLOUD.COM"

Set-jnTrustedHosts -DomainName "LGDISPLAY.GLOBAL"

Set-jnTrustedHosts -DomainName "LGE.NET"

