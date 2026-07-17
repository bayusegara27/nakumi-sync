param(
    [string]$ServerRoot = '',
    [string]$FullZipUrl = 'https://github.com/bayusegara27/nakumi-sync/releases/download/r9.3-full/Homestead-x-All-of-Create-Aeronautics-server-r9.3-fullsync-20260717.zip',
    [string]$FullZipSha256 = '1FDE6DFB08E82A8C4EDB0B64D5843D2703A6FC7C11F1A50DEAD4598F51C65B74',
    [switch]$SyncOnly
)

$ErrorActionPreference = 'Stop'
$Channel = 'https://bayusegara27.github.io/nakumi-sync'
$Root = if ($ServerRoot) { [IO.Path]::GetFullPath($ServerRoot) } else { $PWD.Path }

function Download-Verified([string]$Url, [string]$Destination, [string]$ExpectedHash) {
    & curl.exe -L --fail --retry 3 --progress-bar --output $Destination $Url
    if ($LASTEXITCODE -ne 0) { throw "Download gagal: $Url" }
    $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Destination).Hash
    if ($Actual -ne $ExpectedHash) {
        Remove-Item -LiteralPath $Destination -Force
        throw "SHA-256 snapshot server salah. Expected=$ExpectedHash Actual=$Actual"
    }
}

New-Item -ItemType Directory -Force -Path $Root | Out-Null
if (!(Test-Path -LiteralPath (Join-Path $Root 'start.ps1'))) {
    $Unsafe = @(Get-ChildItem -LiteralPath $Root -Force | Where-Object {
        $_.Name -notin @('crafty_managed.txt', 'crafty_managed.json', 'eula.txt')
    })
    if ($Unsafe.Count) {
        throw "Server kosong tidak terdeteksi dan start.ps1 tidak ada. Jangan menimpa folder berisi data: $Root"
    }
    $Temp = Join-Path $env:TEMP 'nakumi-full-server-r9.3.zip'
    Write-Host 'Mengunduh snapshot server penuh (sekitar 1 GB)...' -ForegroundColor Cyan
    Download-Verified $FullZipUrl $Temp $FullZipSha256
    Expand-Archive -LiteralPath $Temp -DestinationPath $Root -Force
    Remove-Item -LiteralPath $Temp -Force
    if (!(Test-Path -LiteralPath (Join-Path $Root 'start.ps1'))) {
        throw 'Snapshot server tidak menghasilkan start.ps1.'
    }
}

$Files = @{
    'bootstrap/server/start-with-sync.ps1' = 'start-with-sync.ps1'
    'bootstrap/server/nakumi-sync/update-server.ps1' = 'nakumi-sync/update-server.ps1'
    'bootstrap/server/nakumi-sync/packwiz-installer-bootstrap.jar' = 'nakumi-sync/packwiz-installer-bootstrap.jar'
}
foreach ($Pair in $Files.GetEnumerator()) {
    $Destination = Join-Path $Root $Pair.Value
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "$Channel/$($Pair.Key)" -OutFile $Destination
}
[IO.File]::WriteAllText((Join-Path $Root 'nakumi-sync/channel-url.txt'), $Channel + "`n", [Text.UTF8Encoding]::new($false))

if ($SyncOnly) {
    & (Join-Path $Root 'nakumi-sync/update-server.ps1') -ServerRoot $Root
    exit $LASTEXITCODE
}

& (Join-Path $Root 'start-with-sync.ps1')
exit $LASTEXITCODE
