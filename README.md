# n4j-pswrapper

# Historical version.  For an updated methodology, please visit https://github.com/pdrangeid/graph-commit

Powershell scripts to securely store a Neo4j datasource with username &amp; password in the registry for use with other automation (ps) scripts.
It will also parse the provided .cypher script, and submit each transaction to a Neo4j server for execution, and collect (and optionally log) the metadata results of each transaction

First run the set-n4jcredentials.ps1
First you will be prompted to provide the path to the Neo4j.Driver.dll
Next you are asked to define the name of the datasource, URL of the Neo4j database server, and
a username/password.  Once connectivity is verified, it will be stored in the HKCU registry (the password first being converted to a secure-string).
This script requires you to have previously downloaded and installed the Neo4j dotnet driver dll.
Running the set-n4jcredentials.ps1 subsequent times allows you to modify previously created datasources, or create new ones.

set-customcredentials.ps1 allows you to store additional credentials.  This is handy to allow you to use credentials within your cypher script without storing sensitive credentials within your .cypher in clear-text.  It is a key/pair method that stores a find/replace pair referenced by a logical datasource name.

set-customcredentials.ps1 will use your previously stored datasource(s) to run a neo4j CYPHER query.  If logging is specified, then the results of the transactions are recorded to verify proper execution, and collect metadata about the results (number of labels, relationships, and properties modified for example)
