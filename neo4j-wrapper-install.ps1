$path = $("$Env:Programfiles\Neo4jTools")
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

$client = new-object System.Net.WebClient
$client.DownloadFile("https://dist.nuget.org/win-x86-commandline/latest/nuget.exe","$path\nuget.exe")

$runthis=$("$path\nuget.exe")
&$runthis  install Neo4j.Driver -o "c:\program files\Neo4jTools"

$path = $("$Env:Programfiles\Neo4jTools\wrappers")
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

$client.DownloadFile("https://github.com/pdrangeid/graph-commit/blob/master/bg-sharedfunctions.ps1","$path\bg-sharedfunctions.ps1")
$client.DownloadFile("https://github.com/pdrangeid/graph-commit/blob/master/get-cypher-results.ps1","$path\get-cypher-results.ps1")
$client.DownloadFile("https://github.com/pdrangeid/n4j-pswrapper/blob/master/set-customcredentials.ps1","$path\set-customcredentials.ps1")
$client.DownloadFile("https://github.com/pdrangeid/n4j-pswrapper/blob/master/set-n4jcredentials.ps1","$path\set-n4jcredentials.ps1")
