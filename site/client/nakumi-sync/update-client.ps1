param(
    [string]$Java = $env:INST_JAVA,
    [string]$MinecraftDir = $env:INST_MC_DIR
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($MinecraftDir)) {
    $MinecraftDir = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($Java)) { $Java = 'java' }

$SyncDir = Join-Path $MinecraftDir 'nakumi-sync'
$UrlFile = Join-Path $SyncDir 'channel-url.txt'
$Bootstrap = Join-Path $SyncDir 'packwiz-installer-bootstrap.jar'
$StateDir = Join-Path $SyncDir 'state'
$LogDir = Join-Path $SyncDir 'logs'
New-Item -ItemType Directory -Force -Path $StateDir, $LogDir | Out-Null

if (!(Test-Path -LiteralPath $UrlFile) -or !(Test-Path -LiteralPath $Bootstrap)) {
    throw 'Nakumi Sync belum dikonfigurasi. Jalankan INSTALL-NAKUMI-SYNC.cmd satu kali.'
}
$BaseUrl = (Get-Content -LiteralPath $UrlFile -Raw).Trim().TrimEnd('/')
if ($BaseUrl -notmatch '^https?://') { throw 'channel-url.txt harus berisi URL HTTP/HTTPS.' }

$RemoteVersion = (Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/client/channel-version.txt").Content.Trim()
$RemotePaths = (Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/client/backup-paths.txt").Content -split "`r?`n"
$DeletePaths = (Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/client/delete-paths.txt").Content -split "`r?`n"
$LastVersionFile = Join-Path $StateDir 'last-version.txt'
$LastVersion = if (Test-Path $LastVersionFile) { (Get-Content $LastVersionFile -Raw).Trim() } else { '' }

if ($RemoteVersion -ne $LastVersion) {
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $Backup = Join-Path $MinecraftDir "backups/nakumi-sync/$Stamp-$RemoteVersion"
    foreach ($RelRaw in $RemotePaths) {
        $Rel = $RelRaw.Trim().Replace('/', [IO.Path]::DirectorySeparatorChar)
        if (!$Rel) { continue }
        if ([IO.Path]::IsPathRooted($Rel) -or $Rel.Split([IO.Path]::DirectorySeparatorChar) -contains '..') {
            throw "Path backup tidak aman: $RelRaw"
        }
        $Source = Join-Path $MinecraftDir $Rel
        if (Test-Path -LiteralPath $Source -PathType Leaf) {
            $Destination = Join-Path $Backup $Rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
            Copy-Item -LiteralPath $Source -Destination $Destination
        }
    }
    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    [IO.File]::WriteAllText((Join-Path $Backup 'from-version.txt'), $LastVersion + "`n", [Text.UTF8Encoding]::new($false))
}

$Log = Join-Path $LogDir ('update-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
Push-Location $MinecraftDir
try {
    & $Java -jar $Bootstrap -g -s client "$BaseUrl/client/pack.toml" 2>&1 | Tee-Object -FilePath $Log
    $Code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($Code -ne 0) { throw "Nakumi Sync gagal (exit $Code). Game dibatalkan agar versi tidak berbeda dengan server. Log: $Log" }
foreach ($RelRaw in $DeletePaths) {
    $Rel = $RelRaw.Trim().Replace('/', [IO.Path]::DirectorySeparatorChar)
    if (!$Rel) { continue }
    if ([IO.Path]::IsPathRooted($Rel) -or $Rel.Split([IO.Path]::DirectorySeparatorChar) -contains '..') {
        throw "Path penghapusan tidak aman: $RelRaw"
    }
    $Target = Join-Path $MinecraftDir $Rel
    if (Test-Path -LiteralPath $Target -PathType Leaf) { Remove-Item -LiteralPath $Target -Force }
}
[IO.File]::WriteAllText($LastVersionFile, $RemoteVersion + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Nakumi Sync client sudah versi $RemoteVersion" -ForegroundColor Green
