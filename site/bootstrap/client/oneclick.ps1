$ErrorActionPreference = 'Stop'
$Channel = 'https://bayusegara27.github.io/nakumi-sync'
$Root = [IO.Path]::GetFullPath($env:NAKUMI_INSTANCE_ROOT)
if (!(Test-Path (Join-Path $Root 'instance.cfg'))) {
    throw 'Taruh Nakumi-Sync-Client-OneClick.cmd di root instance yang berisi instance.cfg.'
}
$Targets = @{
    'bootstrap/client/INSTALL-NAKUMI-SYNC.ps1' = 'INSTALL-NAKUMI-SYNC.ps1'
    'bootstrap/client/minecraft/nakumi-sync/update-client.ps1' = 'minecraft/nakumi-sync/update-client.ps1'
    'bootstrap/client/minecraft/nakumi-sync/packwiz-installer-bootstrap.jar' = 'minecraft/nakumi-sync/packwiz-installer-bootstrap.jar'
}
foreach ($Pair in $Targets.GetEnumerator()) {
    $Destination = Join-Path $Root $Pair.Value
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "$Channel/$($Pair.Key)" -OutFile $Destination
}
& (Join-Path $Root 'INSTALL-NAKUMI-SYNC.ps1') -ChannelBaseUrl $Channel

