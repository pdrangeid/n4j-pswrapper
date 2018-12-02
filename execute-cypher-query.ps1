<# 
.SYNOPSIS 
 Query the graphDB using a previously stored Neo4j datasource
 
.DESCRIPTION 
 Using a stored server URL, user, and password connect to a neo4j database to run a query.
 paired with set-n4jcredentials.ps1 to create & store the datasource.
 
 
.NOTES 
┌─────────────────────────────────────────────────────────────────────────────────────────────┐ 
│ execute-cypher-query.ps1                                                                    │ 
├─────────────────────────────────────────────────────────────────────────────────────────────┤ 
│   DATE        : 2018.11.18                               									  │ 
│   AUTHOR      : Paul Drangeid 							                              	  |
│   Change the variable $DSName = "N4jDataSource" to match the name of your stored datasource │ 
│   A sample query is provided returning the number of nodes in the datasource graphdb        │ 
│                                                                                             │ 
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
  Write-Host "If this config has been run before (by this user, on this PC), successful settings will be stored in the registry under:"
  Write-Host "HKEY_CURRENT_USER\Software\neo4j-wrapper\"
  Write-Host "The wizard will use those values."
  $ValName = "N4jDriverpath"
  $Path = "HKCU:\Software\neo4j-wrapper\Datasource"
  $Neo4jdriver = Ver-RegistryValue -RegPath $Path -Name $ValName

  Try{
  # Import DLLs
  Add-Type -Path $Neo4jdriver
  }
  Catch{
    LogError $_.Exception "Loading Neo4j drivers." "Could not load Neo4j dlls from $PSScriptRoot.  For help please visit: https://glennsarti.github.io/blog/using-neo4j-dotnet-client-in-ps/ 
	`n If you've already followed these instructions and are receiving an error, you may need to update your dotnet framework: https://dotnet.microsoft.com/download/dotnet-framework-runtime/net47"
  BREAK
  }
  
  $DSName = "N4jDataSource"	
  $Path = "HKCU:\Software\neo4j-wrapper\Datasource"
  AddRegPath $Path
  $Path = "HKCU:\Software\neo4j-wrapper\Datasource\$DSName"
  $Neo4jServerName = Ver-RegistryValue -RegPath $Path -Name "ServerURL" -DefValue "bolt://neo4j.mydomain.com:7687"
  $n4jUser = Ver-RegistryValue -RegPath $Path -Name "DSUser" -DefValue "neo4j"
  $n4juPW = Get-SecurePassword $Path "DSPW" 
  
  
  Try {
  write-host "Connecting to Neo4j Server " $($Neo4jServerName) "..."
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
      }
  Catch{
	  LogError $_.Exception "Running Query." "Could not Execute query."
  BREAK
  }
  
    $result.PSObject.Properties | ForEach-Object {
  $_.Name
  $_.Value
  }

  $result | ForEach-Object {
    $_ | fl
      $_["NumNodes"]
      $_.Name
      $_.Value
  }
    
  $session = $null
  $dbDriver = $null
  
  