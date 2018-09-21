#
# Get_ADGroupMemberMemberOfByUser.ps1
#
Function Get-ADDirectReports
{
<#
.SYNOPSIS
List all users that report to a given mananger.
.DESCRIPTION
Connects to AD and collects the direct reports for a given manager.
.PARAMETER SamAccountName of the manager
Command returns the users assigned to a manager.
.EXAMPLE
Get-ADdirectReports Bboberson|ft
.EXAMPLE
$a = "bboberson","memyself";$a|%{Get-ADdirectReports $_}
#>
	PARAM ($SamAccountName)
    $User = Get-Aduser -identity $SamAccountName -Properties directreports
	foreach ($usr in $User)
	{
		foreach ($buf in $usr.directreports)
		{
			# Output the current Object information
			Get-ADUser -identity $Psitem -Properties mail,manager,Title,OfficePhone,Office | Select-Object -Property Name, SamAccountName,Title, Mail,OfficePhone,Office, @{ L = "Manager"; E = { (Get-Aduser -iden $psitem.manager).samaccountname } }
            
			# Find the DirectReports of the current item ($PSItem / $_)
			Get-ADdirectReports -SamAccountName $PSItem
		}
	}
}
