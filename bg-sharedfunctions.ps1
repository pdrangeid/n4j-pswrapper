<# 
.SYNOPSIS 
 shared functions for Graph Wrapper scipts and commandlets
 
.DESCRIPTION 
 This contains shared functions for the other Neo4j scripts
 String, registry storage/retrieval, and logging functions 

.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ bg-sharedfunctions.ps1                                                                      │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 1.26.2019 				               									  │ 
│   AUTHOR      : Paul Drangeid 			                   								  │ 
│   SITE        : https://blog.graphcommit.com/                                               │ 
└─────────────────────────────────────────────────────────────────────────────────────────────┘ 
#> 

# Prepare to allow events written to the Windows EventLog.  Create the Eventlog SOURCE if it is missing.
Function Prepare-EventLog{
    #$srccmdline=$($MyInvocation.MyCommand.Name)

    Write-Host "My source is $srccmdline"

    $logFileExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq $srccmdline} 
    if (! $logFileExists) {
        New-EventLog -LogName Application -Source $srccmdline -erroraction 'silentlycontinue'}
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
Write-Host "Write-EventLog -LogName Application -Source $srccmdline -EntryType $EntryType -EventId 5980 -Message $Message"
    
  Write-EventLog -LogName Application -Source $srccmdline -EntryType $EntryType -EventId 5980 -Message $Message
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
    #BREAK
    }
function Cypherlog([String]$x){
    if (![string]::IsNullOrEmpty($logging)) {
    try {
        $logresult = $logsession.Run($x)
        $logresult | ForEach-Object {
            if (![string]::IsNullOrEmpty($($_["scriptid"]))) {  $global:scriptid=$($_["scriptid"])}
        }
      }#End Try
      Catch{
          LogError $_.Exception "Logging results." "Could not Write Log entry`n $x `nto $logging"
      BREAK
      }#End Catch
    }# End If ($logging)
}

function AmINull([String]$x) {
        if ($x) {return $false} else {return $true}
      }

# Check if registry key and value exist.  If they don't exist and the "DefValue" is not null then create the key/path with the supplied default value. 
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
                    New-ItemProperty -Path $RegPath -Name $Name -Value $DefValue -Force | Out-Null
                    return $DefValue
                    } }
            } else {
            if (![string]::IsNullOrEmpty($DefValue)) {
            New-Item $RegPath -Force | New-ItemProperty -Name $Name -Value $DefValue -Force | Out-Null
            return $DefValue
            }}
            
            }
            }

function Test-RegistryValue([String]$TestPath,[String]$TestValue){
    try {
    #Get-ItemProperty -Path $TestPath | Select-Object -ExpandProperty $TestValue -ErrorAction Stop | Out-Null
    Get-ItemProperty -Path $TestPath -Name $TestValue -ErrorAction Stop | Out-Null
        return $true
        }
    catch {
    return $false
    }
    }#End Function (Test-RegistryValue)
# With the supplied registry path and value name, retrieve the secured value, and convert to clear text (for use with URL or API call)
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
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "DLL (*.dll)| *.dll"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}
function GetAPIKEY{
    if (Test-RegistryValue $($Path+$tenantdomain) "APIKey"){
    $APIKey = Get-SecurePassword $($Path+$tenantdomain) "APIKey"
    }
    
    # No Key, so we need to prompt for input
    if ([string]::IsNullOrEmpty($APIKey))  {
    Write-Host "Requesting user to supply APIKey"
    #$password= Read-Host -assecurestring "Enter GUID for $tenantdomain"
    $password=$Host.ui.PromptForCredential("","Enter GUID for $tenantdomain","APIKey","")
    if ([string]::IsNullOrEmpty($password.password)) {
    Write-Host "No APIKey provided or dialog cancelled.   Exiting script..."
    BREAK
    }
    $SecureString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password.password))
$secure = ConvertTo-SecureString $SecureString -force -asPlainText 
$bytes = ConvertFrom-SecureString $secure
Ver-RegistryValue -RegPath $($Path+$tenantdomain) -Name "APIKey" -DefValue $bytes | Out-Null
Remove-Variable bytes
Remove-Variable password
Remove-Variable secure
Remove-Variable securestring
# Now the reg value is NOT empty
}

Try
{
$APIKey = Get-SecurePassword $($Path+$tenantdomain) "APIKey"
}
Catch
{
$ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Host "Retrieve GUID from registry Failed! We failed to read GUID from $($Path+$tenantdomain). The error message was '$ErrorMessage'  It is likely that you are not running this script as the original user who saved the secure tenant GUID."
    Break
}
return $APIKey
# End of Function
}

Function Loadn4jdriver {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $ValName = "N4jDriverpath"
    $Path = "HKCU:\Software\neo4j-wrapper\Datasource"
    $Neo4jdriver = Ver-RegistryValue -RegPath $Path -Name $ValName
    write-host "Loading Neo4J Driver: $Neo4jdriver"
    if (AmINull $($Neo4jdriver) -eq $true){
        write-host "No Path for Neo4j Driver provided.   Exiting setup...`nFor help loading the neo4j dotnet drivers please visit: https://glennsarti.github.io/blog/using-neo4j-dotnet-client-in-ps/"
        BREAK
        }

    Try{
    # Import DLLs
    Add-Type -Path $Neo4jdriver
    }
    Catch{
        LogError $_.Exception "Loading Neo4j drivers." "Could not load Neo4j dlls from $Neo4jdriver.`nFor help please visit: https://glennsarti.github.io/blog/using-neo4j-dotnet-client-in-ps/ 
        `nIf you've already followed these instructions and are receiving an error, you may need to update your dotnet framework: https://dotnet.microsoft.com/download/dotnet-framework-runtime/net47"
    BREAK
    }
}
    
    