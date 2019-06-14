<# 
.SYNOPSIS 
 Configure key/(securestring)value pairs and securely store them in the registry.
 
.DESCRIPTION 
 This script must be run as the account that will be used to run tasks that connect and query
 the neo4j database. The value in the pair is converted to a securestringand stored in the registry,
 and only retreivable when run as the same (user) account that created/stored the values. 

 ***Please be aware, securestring storage is only as secure as the machine and users operating
 (or with access to) it. If you have access to the scripts, and some level of local administrative privilleges,
 it is a trivial task to alter the scripts in order to recover/retrieve the original text of the stored
 securestring values.  As best security practices demand, these stored credentials should only provide the least
 privillege required to accomplish the task.

 Any processes that store/retrieve these values should ONLY be stored and run on a secured and limited-access
 endpoint, with a secured service account.

 
.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ set-customcredentials.ps1                                                                   │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 2018.12.23																  │ 
│   AUTHOR      : Paul Drangeid 															  │ 
│   SITE        : https://blog.graphcommit.com/                                               │ 
└─────────────────────────────────────────────────────────────────────────────────────────────┘ 
 
#> 

param (
[string]$credname,
[string]$findstring,
[string]$creds
)

$global:scriptname = $($MyInvocation.MyCommand.Name)
$global:srccmdline = $($MyInvocation.MyCommand.Name)

Write-Host "`nLoading $psscriptroot\bg-sharedfunctions.ps1"
Try{. "$psscriptroot\bg-sharedfunctions.ps1" | Out-Null}
Catch{
    Write-Warning "I wasn't able to load the sharedfunctions includes.  We are going to bail now, sorry 'bout that! "
    Write-Host "Try running them manually, and see what error message is causing this to puke: .\bg-sharedfunctions.ps1"
    BREAK
    }

 Prepare-EventLog
 #LogError "this is the actual error" "And here's some details to help provide context for the errors."
		

Add-Type -AssemblyName Microsoft.VisualBasic
Write-Host "`nIf this config has been run before (by this user, on this PC), successful settings will be stored in the registry under:"
Write-Host "HKEY_CURRENT_USER\Software\neo4j-wrapper\Credentials"
Write-Host "`nThe wizard will use those values, and give you a chance to modify them if you need."

# If the credential name is NOT supplied on the commandline then we must ask
if ([string]::IsNullOrEmpty($credname)) {
$ValName = "LastCredName"	
$Path = "HKCU:\Software\neo4j-wrapper\Credentials"
AddRegPath $Path
$CredNameDef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "Mycredential"
if (AmINull $($CredNameDef.Trim()) -eq $true ){$CredNameDef="Mycredential"}
Write-Host ""
Write-Host "We need a logical name for this Credential."
$CredName = [Microsoft.VisualBasic.Interaction]::InputBox('Enter name for this Credential.', 'Credential Name', $($CredNameDef))
} 
$CredName=$CredName.Trim()
if (AmINull $($CredName) -eq $true){
write-host "No Datasource name provided.   Exiting setup..."
BREAK
}

#if (![string]::IsNullOrEmpty($findstring)) {$defvalue=$findstring} else {$defvalue='this-is-a-unique-string-to-find-within-the-cypher-code'}
if ([string]::IsNullOrEmpty($findstring)) {$defvalue='this-is-a-unique-string-to-find-within-the-cypher-code'
$ValName = "Matchstring"	
$Path = "HKCU:\Software\neo4j-wrapper\Credentials\$CredName"
AddRegPath $Path
$CredMatchStringDef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue $defvalue
if (AmINull $($CredMatchStringDef.Trim()) -eq $true ){$CredMatchStringDef=$defvalue}
Write-Host ""
Write-Host "Provide a unique string to find within your cypher script which will be replaced with the contents of a secure string value."
$CredMatchString = [Microsoft.VisualBasic.Interaction]::InputBox('Unique string to find within your cypher script which will be replaced with a secure value', 'String to match', $($CredMatchStringDef))
$CredMatchString=$CredMatchString.Trim()
} else {$CredMatchString=$findstring.Trim()}
if (AmINull $($CredMatchString) -eq $true){
write-host "Null match string provided or Dialog cancelled.  No changes will be written for this key/value pair.  Exiting script..."
BREAK
}

$ValName = "SecureStringValue"	
$Path = "HKCU:\Software\neo4j-wrapper\Credentials\$CredName"
AddRegPath $Path

if ((Test-RegistryValue -Path $Path -Value "SecureStringValue") -and (Test-RegistryValue -Path $Path -Value "secure-value-to-be-stored")){
write-host "Existing Credential -- It looks like we already have a validated key/value pair stored for $CredName.."
write-host "Would you like to update the key/value pair used for Credential [$CredName]?"
$intsetacct=-1
if (YesorNo "Would you like to update the key/value pair used for the Credential [$CredName]?" "Credential Store") {
$intsetacct=1
}
} # End if (key/value pair already stored in registry)

if ($intsetacct -eq -1){
$CredSecureStringValue = Get-SecurePassword $Path "SecureStringValue" 
}

if ($intsetacct -ne -1){
#$n4jUserdef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "neo4j"
#$StoredCred = Get-Credential -Credential $CredMatchString | Out-Null
$StoredCred =$mycred=$Host.ui.PromptForCredential("","Provide the string to be secured in the 'Password:' field",$CredMatchString,"")
if ([string]::IsNullOrEmpty($StoredCred.password)) {
Write-Host "Null secure string provided or Dialog cancelled.  No changes will be written for this key/value pair.  Exiting script..."
BREAK
}

$StoredCredUser=$StoredCred.username
$SecureString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($StoredCred.password))
if (AmINull $($SecureString.trim()) -eq $true) {
Write-Host "Secure String Value cannot be blank."
Break
} # End if provided password was blank/null
} # End if $intsetacct -ne -1

$Path = "HKCU:\Software\neo4j-wrapper\Credentials\$CredName"
AddRegPath $Path
Set-ItemProperty -Path $path -Name "Matchstring" -Value $CredMatchString -Force #| Out-Null

if ($intsetacct -ne -1){
# -1 means we already validated the registry contains the user/password, and the user doesn't want to change them
$secure = ConvertTo-SecureString $SecureString -force -asPlainText 
$bytes = ConvertFrom-SecureString $secure
Set-ItemProperty -Path $path -Name "SecureStringValue"-Value $bytes -Force #| Out-Null
$Path = "HKCU:\Software\neo4j-wrapper\Credentials"
}
Set-ItemProperty -Path $path -Name "LastCredName" -Value $CredName -Force | Out-Null