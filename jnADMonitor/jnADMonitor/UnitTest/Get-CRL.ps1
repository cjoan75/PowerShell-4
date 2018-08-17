#
# Get_CRL.ps1
#
#####################################################################
# Get-CRL.ps1
# Version 1.0
#
# Retrieves CRL object from a file or a DER-encoded byte array.
#
# Vadims Podans (c) 2011
# http://www.sysadmins.lv/
#####################################################################
#requires -Version 2.0

function Get-CRL {
<#
.Synopsis
    Retrieves CRL object from a file or a DER-encoded byte array.
.Description
    Retrieves CRL object from a file or a DER-encoded byte array.
.Parameter Path
    Specifies the path to a file.
.Parameter RawCRL
    Specifies a pointer to a DER-encoded CRL byte array.
.Example
    Get-CRL C:\Custom.crl
    
    Returns X509CRL2 object from a specified file
.Example
    $Raw = [IO.FILE]::ReadAllBytes("C:\Custom.crl")
    Get-CRL -RawCRL $Raw
    
    Returns X509CRL2 object from a DER-encoded byte array.
.Outputs
    System.Security.Cryptography.X509Certificates.X509CRL2
.NOTES
    Author: Vadims Podans
    Blog  : http://en-us.sysadmins.lv
#>
[OutputType('System.Security.Cryptography.X509Certificates.X509CRL2')]
[CmdletBinding(DefaultParameterSetName='FileName')]
param(
	[Parameter(ParameterSetName = "FileName", Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
	[string]$Path,
	[Parameter(ParameterSetName = "RawData", Mandatory = $true, Position = 0)]
	[Byte[]]$RawCRL
)
    
#region content parser
	switch ($PsCmdlet.ParameterSetName) {
		"FileName" {
			if ($(Get-Item $Path -ErrorAction Stop).PSProvider.Name -ne "FileSystem") {
				throw {"File either does not exist or not a file object"}
			}
			if ($(Get-Item $Path -ErrorAction Stop).Extension -ne ".crl") {
				throw {"File is not valid CRL file"}
			}
			$Content = Get-Content $Path
			if ($Content[0] -eq "-----BEGIN X509 CRL-----") {
				[Byte[]]$cBytes = [Convert]::FromBase64String($(-join $Content[1..($Content.Count - 2)]))
			} elseif ($Content[0][0] -eq "M") {
				[Byte[]]$cBytes = [Convert]::FromBase64String($(-join $Content))
			} else {
				[Byte[]]$cBytes = [IO.File]::ReadAllBytes($Path)
			}
		}
		"RawData" {[Byte[]]$cBytes = $RawCRL}
	}
#endregion

$signature = @"
[DllImport("CRYPT32.DLL", CharSet = CharSet.Auto, SetLastError = true)]
public static extern int CertCreateCRLContext(
    int dwCertEncodingType,
    byte[] pbCrlEncoded,
    int cbCrlEncoded
);

[DllImport("CRYPT32.DLL", SetLastError = true)]
public static extern Boolean CertFreeCRLContext(
    IntPtr pCrlContext
);

[DllImport("CRYPT32.DLL", CharSet = CharSet.Auto, SetLastError = true)]
public static extern int CertNameToStr(
    int dwCertEncodingType,
    ref CRYPTOAPI_BLOB pName,
    int dwStrType,
    System.Text.StringBuilder psz,
    int csz
);

[DllImport("CRYPT32.DLL", CharSet = CharSet.Auto, SetLastError = true)]
public static extern IntPtr CertFindExtension(
    [MarshalAs(UnmanagedType.LPStr)]String pszObjId,
    int cExtensions,
    IntPtr rgExtensions
);

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct CRL_CONTEXT
{
    public int dwCertEncodingType;
    public byte[] pbCrlEncoded;
    public int cbCrlEncoded;
    public IntPtr pCrlInfo;
    public IntPtr hCertStore;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct CRL_INFO
{
    public int dwVersion;
    public CRYPT_ALGORITHM_IDENTIFIER SignatureAlgorithm;
    public CRYPTOAPI_BLOB Issuer;
    public Int64 ThisUpdate;
    public Int64 NextUpdate;
    public int cCRLEntry;
    public IntPtr rgCRLEntry;
    public int cExtension;
    public IntPtr rgExtension;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct CRYPT_ALGORITHM_IDENTIFIER
{
    [MarshalAs(UnmanagedType.LPStr)]public String pszObjId;
    public CRYPTOAPI_BLOB Parameters;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct CRYPTOAPI_BLOB
{
    public int cbData;
    public IntPtr pbData;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct CRL_ENTRY
{
    public CRYPTOAPI_BLOB SerialNumber;
    public Int64 RevocationDate;
    public int cExtension;
    public IntPtr rgExtension;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct CERT_EXTENSION
{
    [MarshalAs(UnmanagedType.LPStr)]public String pszObjId;
    public Boolean fCritical;
    public CRYPTOAPI_BLOB Value;
}
"@
Add-Type @"
using System;
using System.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace System
{
    namespace Security
    {
        namespace Cryptography
        {
            namespace X509Certificates
            {
                public class X509CRL2
                {
                    public int Version;
                    public string Type;
                    public X500DistinguishedName IssuerDN;
                    public string Issuer;
                    public DateTime ThisUpdate;
                    public DateTime NextUpdate;
                    public Oid SignatureAlgorithm;
                    public X509ExtensionCollection Extensions;
                    public X509CRLEntry[] RevokedCertificates;
                    public byte[] RawData;
                }
                public class X509CRLEntry
                {
                    public string SerialNumber;
                    public DateTime RevocationDate;
                    public int ReasonCode;
                    public string ReasonMessage;
                }
            }
        }
    }
}
"@

	try {Add-Type -MemberDefinition $signature -Namespace PKI -Name CRL}
	catch {throw "Unable to load required types"}

	#region Variables
	[IntPtr]$pvContext = [IntPtr]::Zero
	[IntPtr]$rgCRLEntry = [IntPtr]::Zero
	[IntPtr]$pByte = [IntPtr]::Zero
	[byte]$bByte = 0
	[IntPtr]$rgExtension = [IntPtr]::Zero
	$ptr = [IntPtr]::Zero
	$Reasons = @{1="Key compromise";2="CA Compromise";3="Change of Affiliation";4="Superseded";5="Cease Of Operation";
		6="Hold Certificiate";7="Privilege Withdrawn";10="aA Compromise"}
	#endregion

	# retrive CRL context and CRL_CONTEXT structure
	$pvContext = [PKI.CRL]::CertCreateCRLContext(65537,$cBytes,$cBytes.Count)
	if ($pvContext.Equals([IntPtr]::Zero)) {throw "Unable to retrieve context"}
	$CRL = New-Object System.Security.Cryptography.X509Certificates.X509CRL2
	# void first marshaling operation, because it throws unexpected exception
	try {$CRLContext = [Runtime.InteropServices.Marshal]::PtrToStructure([IntPtr]$pvContext,[PKI.CRL+CRL_CONTEXT])} catch {}
	$CRLContext = [Runtime.InteropServices.Marshal]::PtrToStructure([IntPtr]$pvContext,[PKI.CRL+CRL_CONTEXT])
	$CRLInfo = [Runtime.InteropServices.Marshal]::PtrToStructure($CRLContext.pCrlInfo,[PKI.CRL+CRL_INFO])
	$CRL.Version = $CRLInfo.dwVersion + 1
	$CRL.Type = "Base CRL"
	$CRL.RawData = $cBytes
	$CRL.SignatureAlgorithm = New-Object Security.Cryptography.Oid $CRLInfo.SignatureAlgorithm.pszObjId
	$CRL.ThisUpdate = [datetime]::FromFileTime($CRLInfo.ThisUpdate)
	$CRL.NextUpdate = [datetime]::FromFileTime($CRLInfo.NextUpdate)
	$csz = [PKI.CRL]::CertNameToStr(65537,[ref]$CRLInfo.Issuer,3,$null,0)
	$psz = New-Object text.StringBuilder $csz
	$csz = [PKI.CRL]::CertNameToStr(65537,[ref]$CRLInfo.Issuer,3,$psz,$csz)
	$CRL.IssuerDN = New-Object Security.Cryptography.X509Certificates.X500DistinguishedName $psz
	$CRL.Issuer = $CRL.IssuerDN.Format(0)
	$rgCRLEntry = $CRLInfo.rgCRLEntry
	if ($CRLInfo.cCRLEntry -ge 1) {
		for ($n = 0; $n -lt $CRLInfo.cCRLEntry; $n++) {
			$Entry = New-Object System.Security.Cryptography.X509Certificates.X509CRLEntry
			$SerialNumber  = ""
			$CRLEntry = [Runtime.InteropServices.Marshal]::PtrToStructure($rgCRLEntry,[PKI.CRL+CRL_ENTRY])
			$pByte = $CRLEntry.SerialNumber.pbData
			$SerialNumber = ""
			for ($m = 0; $m -lt $CRLEntry.SerialNumber.cbData; $m++) {
				$bByte = [Runtime.InteropServices.Marshal]::ReadByte($pByte)
				$SerialNumber = "{0:x2}" -f $bByte + $SerialNumber
				$pByte = [int]$pByte + [Runtime.InteropServices.Marshal]::SizeOf([byte])
			}
			$Entry.SerialNumber = $SerialNumber
			$Entry.RevocationDate = [datetime]::FromFileTime($CRLEntry.RevocationDate)
			$CRLReasonCode = ""
			[IntPtr]$rcExtension = [PKI.CRL]::CertFindExtension("2.5.29.21",$CRLEntry.cExtension,$CRLEntry.rgExtension)
			if (!$rcExtension.Equals([IntPtr]::Zero)) {
				$CRLExtension = [Runtime.InteropServices.Marshal]::PtrToStructure($rcExtension,[PKI.CRL+CERT_EXTENSION])
				$pByte = $CRLExtension.Value.pbData
				$bBytes = $null
				for ($m = 0; $m -lt $CRLExtension.Value.cbData; $m++) {
					$bByte = [Runtime.InteropServices.Marshal]::ReadByte($pByte)
					[Byte[]]$bBytes += $bByte
					$pByte = [int]$pByte + [Runtime.InteropServices.Marshal]::SizeOf([byte])
				}
				$Entry.ReasonCode = $bBytes[2]
				$Entry.ReasonMessage = $Reasons[$Entry.ReasonCode]
			}
			$CRL.RevokedCertificates += $Entry
			$rgCRLEntry = [int]$rgCRLEntry + [Runtime.InteropServices.Marshal]::SizeOf([PKI.CRL+CRL_ENTRY])
		}
	}
	$rgExtension = $CRLInfo.rgExtension
	if ($CRLInfo.cExtension -ge 1) {
		$Exts = New-Object Security.Cryptography.X509Certificates.X509ExtensionCollection
		for ($n = 0; $n -lt $CRLInfo.cExtension; $n++) {
			$ExtEntry = [Runtime.InteropServices.Marshal]::PtrToStructure($rgExtension,[PKI.CRL+CERT_EXTENSION])
			[IntPtr]$rgExtension = [PKI.CRL]::CertFindExtension($ExtEntry.pszObjId,$CRLInfo.cExtension,$CRLInfo.rgExtension)
			$pByte = $ExtEntry.Value.pbData
			$bBytes = $null
			for ($m = 0; $m -lt $ExtEntry.Value.cbData; $m++) {
				[byte[]]$bBytes += [Runtime.InteropServices.Marshal]::ReadByte($pByte)
				$pByte = [int]$pByte + [Runtime.InteropServices.Marshal]::SizeOf([byte])
			}
			$ext = New-Object Security.Cryptography.X509Certificates.X509Extension $ExtEntry.pszObjId, @([Byte[]]$bBytes), $ExtEntry.fCritical
			[void]$Exts.Add($ext)
			$rgExtension = [int]$rgExtension + [Runtime.InteropServices.Marshal]::SizeOf([PKI.CRL+CERT_EXTENSION])
		}
		if ($exts | ?{$_.Oid.Value -eq "2.5.29.27"}) {$CRL.Type = "Delta CRL"}
		$CRL.Extensions = $Exts
	}
	$CRL
	[void][PKI.CRL]::CertFreeCRLContext($pvContext)
}
