$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
& (Join-Path $Root 'nakumi-sync/update-server.ps1') -ServerRoot $Root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $Root 'start.ps1')
exit $LASTEXITCODE
