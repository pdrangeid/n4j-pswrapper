# n4j-pswrapper
Powershell scripts to securely store a Neo4j datasource with username &amp; password in the registry for use with other automation (ps) scripts

First run the set-n4jcredentials.ps1
First you will be prompted to provide the path to the Neo4j.Driver.dll
Next you are asked to define the name of the datasource, URL of the Neo4j database server, and
a username/password.  Once connectivity is verified, it will be stored in the HKCU registry (the password first being hashed).
This script requires you to have previously downloaded and installed the Neo4j dotnet driver dll.
Running the set-n4jcredentials.ps1 subsequent times allows you to modify previously created datasources, or create new ones.


The second script, execute-cypher-query.ps1 will use one of your previously stored datasources to run a neo4j CYPHER query.
A basic sample CYPHER query is included.
