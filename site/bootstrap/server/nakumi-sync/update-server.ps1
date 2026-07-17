param([string]$Java = 'java', [string]$ServerRoot = '')
$ErrorActionPreference = 'Stop'
if (!$ServerRoot) { $ServerRoot = Split-Path -Parent $PSScriptRoot }
$SyncDir = Join-Path $ServerRoot 'nakumi-sync'
$BaseUrl = (Get-Content (Join-Path $SyncDir 'channel-url.txt') -Raw).Trim().TrimEnd('/')
if ($BaseUrl -notmatch '^https?://') { throw 'channel-url.txt harus HTTP/HTTPS.' }
$State = Join-Path $SyncDir 'state'; $Logs = Join-Path $SyncDir 'logs'
New-Item -ItemType Directory -Force -Path $State, $Logs | Out-Null
$RemoteVersion = (Invoke-WebRequest -UseBasicParsing "$BaseUrl/server/channel-version.txt").Content.Trim()
$Paths = (Invoke-WebRequest -UseBasicParsing "$BaseUrl/server/backup-paths.txt").Content -split "`r?`n"
$DeletePaths = (Invoke-WebRequest -UseBasicParsing "$BaseUrl/server/delete-paths.txt").Content -split "`r?`n"
$LastFile = Join-Path $State 'last-version.txt'
$Last = if (Test-Path $LastFile) { (Get-Content $LastFile -Raw).Trim() } else { '' }
if ($RemoteVersion -ne $Last) {
    $Backup = Join-Path $ServerRoot ('backups/nakumi-sync/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $RemoteVersion)
    foreach ($Raw in $Paths) {
        $Rel = $Raw.Trim().Replace('/', [IO.Path]::DirectorySeparatorChar); if (!$Rel) { continue }
        if ([IO.Path]::IsPathRooted($Rel) -or $Rel.Split([IO.Path]::DirectorySeparatorChar) -contains '..') { throw "Path tidak aman: $Raw" }
        $Source = Join-Path $ServerRoot $Rel
        if (Test-Path $Source -PathType Leaf) {
            $Dest = Join-Path $Backup $Rel; New-Item -ItemType Directory -Force (Split-Path $Dest) | Out-Null
            Copy-Item -LiteralPath $Source -Destination $Dest
        }
    }
    New-Item -ItemType Directory -Force $Backup | Out-Null
    [IO.File]::WriteAllText((Join-Path $Backup 'from-version.txt'), $Last + "`n", [Text.UTF8Encoding]::new($false))
}
$Log = Join-Path $Logs ('update-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
Push-Location $ServerRoot
try { & $Java -jar (Join-Path $SyncDir 'packwiz-installer-bootstrap.jar') -g -s server "$BaseUrl/server/pack.toml" 2>&1 | Tee-Object $Log; $Code=$LASTEXITCODE }
finally { Pop-Location }
if ($Code -ne 0) { throw "Nakumi Sync gagal (exit $Code); startup server dibatalkan." }
foreach ($Raw in $DeletePaths) {
    $Rel = $Raw.Trim().Replace('/', [IO.Path]::DirectorySeparatorChar); if (!$Rel) { continue }
    if ([IO.Path]::IsPathRooted($Rel) -or $Rel.Split([IO.Path]::DirectorySeparatorChar) -contains '..') { throw "Path penghapusan tidak aman: $Raw" }
    $Target = Join-Path $ServerRoot $Rel
    if (Test-Path -LiteralPath $Target -PathType Leaf) { Remove-Item -LiteralPath $Target -Force }
}
[IO.File]::WriteAllText($LastFile, $RemoteVersion + "`n", [Text.UTF8Encoding]::new($false))
