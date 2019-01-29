<# 
.SYNOPSIS 
 Configure Neo4J database and credentials and (secure-string) store them in the registry.
 
.DESCRIPTION 
 This script must be run as the account that will be used to run tasks that connect and query
 the neo4j database. The password is converted into a securestring object and stored in the registry, and only
 retreivable by the same (user) account. We are assuming the dotnet neo4j driver is already installed.

 Thanks to Glenn Sarti for the primer article: https://glennsarti.github.io/blog/using-neo4j-dotnet-client-in-ps/ 
 and thanks to the Neo4j community!
 
  ***Please be aware, securestring storage is only as secure as the machine and users operating
 (or with access to) it. If you have access to the scripts, and some level of local administrative privilleges,
 it is a trivial task to alter the scripts in order to recover/retrieve the original text of the stored
 securestring values.  As best security practices demand, these stored credentials should only provide the least
 privillege required to accomplish the task.

 Any processes that store/retrieve these values should ONLY be stored and run on a secured and limited-access
 endpoint, with a secured service account.
 
 
.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ set-neo4jcredentials.ps1                                                                    │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 1.26.2019												     				  │ 
│   AUTHOR      : Paul Drangeid 															  │ 
└─────────────────────────────────────────────────────────────────────────────────────────────┘ 
 
#> 
$scriptname=$($MyInvocation.MyCommand.Name)
New-EventLog -LogName Application -Source $scriptname -erroraction 'silentlycontinue'

function AmINull([String]$x) {
  if ($x) {return $false} else {return $true}
}

Function sendto-eventlog {
	param(
		[Parameter(Position = 0, Mandatory = $true)]
		[String]$Message
		,	
		[Parameter(Position = 1, Mandatory = $false)]
		[String]$EntryType
		)
process {
Write-EventLog -LogName Application -Source $scriptname -EntryType $EntryType -EventId 5980 -Message $Message
}
}

Function LogError($e,[String]$mymsg,[String]$section){
$msg = $e.Message
while ($e.InnerException) {
  $e = $e.InnerException
  $msg += "`n" + $e.Message
  }
$warningmessage=$($section)+" - "+$($mymsg)+" - "+$($msg)
Write-Warning $warningmessage
sendto-eventlog -message $warningmessage -entrytype "Error"
BREAK
}

Function Ver-RegistryValue {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]$RegPath
        ,
        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Name
        ,
        [Parameter(Position = 2, Mandatory = $false)]
		[String]$DefValue
    ) 
	
 process {
 if (Test-Path $RegPath) {
            $Key = Get-Item -LiteralPath $RegPath
            if ($Key.GetValue($Name, $null) -ne $null) {
                return (Get-ItemProperty -Path $regpath -Name $Name).$Name 			
				} else
				{
				if (![string]::IsNullOrEmpty($DefValue)) {
				New-ItemProperty -Path $RegPath -Name $Name  -Value $DefValue -Force | Out-Null
				return $DefValue
                } }
        } else {
		if (![string]::IsNullOrEmpty($DefValue)) {
		New-Item $RegPath -Force | New-ItemProperty -Name $Name  -Value $DefValue -Force | Out-Null
		return $DefValue
        }}
		
		}
		}

		function Test-RegistryValue {
		param (
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]$Path,

		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]$Value
		)

		try {
		Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
		 return $true
		 }
		catch {
		return $false
		}
		}#End Function (Test-RegistryValue)
		
Function Get-SecurePassword([String]$pwpath,[String]$RegValName){
Try{
$hashedpw = Ver-RegistryValue -RegPath $pwpath -Name $RegValName -DefValue $null
$securepassword = $hashedpw | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}
Catch{
LogError $_.Exception "Sorry, unable to retrieve password.  Password retrieval requires execution as the same user as when password was stored." "Get-SecurePassword"
BREAK
}

Return $UnsecurePassword
# End of Function
}		

Function AddRegPath([String]$regpath){
$testpathresult = Test-Path -Path $regpath
if($testpathresult -eq $false){
try{
        New-Item -Path $regpath -ItemType Key -Force #| Out-Null
        }
Catch{
LogError $_.Exception "Adding missing key to registry" "Verify Existance of registry key $regpath"
BREAK
}
}
}

Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "DLL (*.dll)| *.dll"
	$OpenFileDialog.ShowDialog() | Out-Null
	$OpenFileDialog.filename
}

Function YesorNo([String]$thequestion,[String]$thetitle) {
$a = new-object -comobject wscript.shell
$intAnswer = $a.popup($thequestion, `
0,$thetitle,4)
If ($intAnswer -eq 6) {
  return $true
} else {
  return $false
}
}

Add-Type -AssemblyName Microsoft.VisualBasic
Write-Host "`nIf this config has been run before (by this user, on this PC), successful settings will be stored in the registry under:"
Write-Host "HKEY_CURRENT_USER\Software\neo4j-wrapper\Datasource"
Write-Host "`nThe wizard will use those values, and give you a chance to modify them if you need."

Write-Host "`nFirst we need to verify that we can load the Neo4j dotnet driver..."
$ValName = "N4jDriverpath"
$Path = "HKCU:\Software\neo4j-wrapper\Datasource"
#$Dllpathdef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "C:\Program Files\2Neo4j.Driver.1.7.0\lib\netstandard1.3\Neo4j.Driver.dll"
$Dllpathdef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "C:\temp\"
$Neo4jdriver = Get-FileName $Dllpathdef
write-host "The driver will be tested here: $Neo4jdriver"
if (AmINull $($Neo4jdriver) -eq $true){
	write-host "No Path for Neo4j Driver provided.   Exiting setup...`nFor help loading the neo4j dotnet drivers please visit: https://glennsarti.github.io/blog/using-neo4j-dotnet-client-in-ps/"
	BREAK
	}

Try{
# Import DLLs
Add-Type -Path $Neo4jdriver
}
Catch{
	LogError $_.Exception "Loading Neo4j drivers." "Could not load Neo4j dlls from $PSScriptRoot.  For help please visit: https://glennsarti.github.io/blog/using-neo4j-dotnet-client-in-ps/ 
	`n If you've already followed these instructions and are receiving an error, you may need to update your dotnet framework: https://dotnet.microsoft.com/download/dotnet-framework-runtime/net47"
BREAK
}
Set-ItemProperty -Path $path -Name $ValName -Value $Neo4jdriver -Force #| Out-Null
Write-Host "Verified Neo4J Driver!"

$ValName = "LastDSName"	
$Path = "HKCU:\Software\neo4j-wrapper\Datasource"
AddRegPath $Path
$DSNamedef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "N4jDataSource"
if (AmINull $($DSNamedef.Trim()) -eq $true ){$DSNamedef="N4jDataSource"}
Write-Host ""
Write-Host "We need a logical name for this Neo4j Datasource."
$DSName = [Microsoft.VisualBasic.Interaction]::InputBox('Enter name for this Neo4j Datasource.', 'Neo4j Datasource Name', $($DSNamedef))
$DSName=$DSName.Trim()
if (AmINull $($DSName) -eq $true){
write-host "No Datasource name provided.   Exiting setup..."
BREAK
}

$ValName = "ServerURL"	
$Path = "HKCU:\Software\neo4j-wrapper\Datasource\$DSName"
AddRegPath $Path
$Neo4jServerNamedef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "bolt://neo4j.mydomain.com:7687"
if (AmINull $($Neo4jServerNamedef.Trim()) -eq $true ){$Neo4jServerNamedef="bolt://neo4j.mydomain.com:7687"}
Write-Host ""
Write-Host "Define your Neo4j graphDB. "
$Neo4jServerName = [Microsoft.VisualBasic.Interaction]::InputBox('Enter fully qualified name (or IP address) of Neo4j Server that will host the graphDB.', 'Neo4j Server URL', $($Neo4jServerNamedef))
$Neo4jServerName=$Neo4jServerName.Trim()
if (AmINull $($Neo4jServerName) -eq $true){
write-host "No Neo4j Server provided.   Exiting setup..."
BREAK
}

$ValName = "DSUser"	
$Path = "HKCU:\Software\neo4j-wrapper\Datasource\$DSName"
AddRegPath $Path

write-host "Lemme see if we already have your PW stored..."
if ((Test-RegistryValue -Path $Path -Value "DSUser") -and (Test-RegistryValue -Path $Path -Value "DSPW")){
write-host "Oh good! -- It looks like we already have a validated user/pw stored!"
write-host "Would you like to update the credentials used for Datasource [$DSName]?"
$intsetacct=-1
if (YesorNo "Would you like to update the credentials used for the Datasource [$DSName]?" "Datastore Credentials") {
$intsetacct=1
}
} # End if (username AND password stored in registry)

if ($intsetacct -eq -1){
$n4jUser = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "neo4j"
$n4juPW = Get-SecurePassword $Path "DSPW" 
}

if ($intsetacct -ne -1){
$n4jUserdef = Ver-RegistryValue -RegPath $Path -Name $ValName -DefValue "neo4j"
$n4jcred = Get-Credential -Credential $n4jUserdef
$n4jUser=$n4jcred.username
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($n4jcred.password))
$n4juPW=$password
#write-host "password  from cred is " $($password)
if (AmINull $($password.trim()) -eq $true) {
Write-Host "Neo4j user password cannot be blank."
Break
} # End if provided password was blank/null
} # End if $intsetacct -ne -1


Try {
write-host "Let's test our connection to Neo4j Server " $($Neo4jServerName) " and perform a quick test query..."
$authToken = [Neo4j.Driver.V1.AuthTokens]::Basic($n4jUser,$n4juPW)
$dbDriver = [Neo4j.Driver.V1.GraphDatabase]::Driver($Neo4jServerName,$authToken)
$session = $dbDriver.Session()
}
Catch{
	LogError $_.Exception "Loading Neo4j driver." "Could not Load Driver"
BREAK
}

try {
  $result = $session.Run("MATCH (n) RETURN Count(n) AS NumNodes")

  Write-Host ($result | ConvertTo-JSON -Depth 5)
}
Catch{
	LogError $_.Exception "Running Query." "Could not Execute query."
BREAK
}

$Path = "HKCU:\Software\neo4j-wrapper\Datasource\$DSName"
AddRegPath $Path
Set-ItemProperty -Path $path -Name "ServerURL" -Value $Neo4jServerName -Force #| Out-Null
Write-Host "Session worked!"

Write-Host "Validated Datasource credentials..."
if ($intsetacct -ne -1){
# -1 means we already validated the registry contains the user/password, and the user doesn't want to change them
Set-ItemProperty -Path $path -Name "DSUser"	-Value $n4jcred.username -Force #| Out-Null
$secure = ConvertTo-SecureString $password -force -asPlainText 
$bytes = ConvertFrom-SecureString $secure
Set-ItemProperty -Path $path -Name "DSPW"	-Value $bytes -Force #| Out-Null
}

$session = $null
$dbDriver = $null