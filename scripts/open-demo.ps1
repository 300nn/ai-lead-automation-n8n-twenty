param([string]$N8nContainer="lead-automatisation")
Set-StrictMode -Version 2.0
$ErrorActionPreference="Stop"
$r=@(& docker.exe port $N8nContainer 5678/tcp 2>&1)
if($LASTEXITCODE -ne 0){ throw "Could not read n8n port from container '$N8nContainer'." }
$port=$null
foreach($line in $r){ if(([string]$line) -match ':(\d+)$'){ $port=[int]$Matches[1]; break } }
if($null -eq $port){ throw "Could not detect n8n host port." }
$url="http://localhost:$port/webhook/portfolio/demo"
Write-Host "Opening $url"
Start-Process $url
