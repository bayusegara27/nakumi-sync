param([string]$ChannelBaseUrl = 'https://bayusegara27.github.io/nakumi-sync')

$ErrorActionPreference = 'Stop'
$InstanceRoot = $PSScriptRoot
$MinecraftDir = Join-Path $InstanceRoot 'minecraft'
$SyncDir = Join-Path $MinecraftDir 'nakumi-sync'
$Cfg = Join-Path $InstanceRoot 'instance.cfg'
if (!(Test-Path $Cfg) -or !(Test-Path (Join-Path $SyncDir 'packwiz-installer-bootstrap.jar'))) {
    throw 'Jalankan installer ini dari root instance PineconeMC/Prism yang berisi instance.cfg dan folder minecraft.'
}
if ([string]::IsNullOrWhiteSpace($ChannelBaseUrl)) {
    $ChannelBaseUrl = Read-Host 'Masukkan URL Nakumi Sync, contoh https://mods.domainkamu.com'
}
$ChannelBaseUrl = $ChannelBaseUrl.Trim().TrimEnd('/')
if ($ChannelBaseUrl -notmatch '^https?://') { throw 'URL harus diawali http:// atau https://.' }

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$CfgBackup = "$Cfg.before-nakumi-sync-$Stamp.bak"
Copy-Item -LiteralPath $Cfg -Destination $CfgBackup
[IO.File]::WriteAllText((Join-Path $SyncDir 'channel-url.txt'), $ChannelBaseUrl + "`n", [Text.UTF8Encoding]::new($false))

$Lines = [Collections.Generic.List[string]](Get-Content -LiteralPath $Cfg)
function Set-Key([string]$Key, [string]$Value) {
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^' + [regex]::Escape($Key) + '=')) {
            $Lines[$i] = "$Key=$Value"
            return
        }
    }
    $Lines.Add("$Key=$Value")
}
Set-Key 'OverrideCommands' 'true'
Set-Key 'PreLaunchCommand' 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INST_MC_DIR/nakumi-sync/update-client.ps1"'
[IO.File]::WriteAllLines($Cfg, $Lines, [Text.UTF8Encoding]::new($false))

$Redirected = Join-Path $MinecraftDir 'mods/redirected-neoforge-1.0.0-1.21.1.jar'
if (Test-Path $Redirected) {
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Redirected).Hash
    if ($Hash -eq 'BDAF4C3399B7436D3BE7D79729D87ED707A964420DC58720E13FB2F4960C8B9E') {
        $Disabled = Join-Path $MinecraftDir 'mods-disabled/nakumi-sync-bootstrap'
        New-Item -ItemType Directory -Force -Path $Disabled | Out-Null
        Move-Item -LiteralPath $Redirected -Destination $Disabled
    } else {
        Write-Warning 'Redirected ditemukan tetapi hash berbeda; file tidak dipindahkan otomatis.'
    }
}

$Java = ((Get-Content $Cfg | Where-Object { $_ -match '^JavaPath=' } | Select-Object -First 1) -replace '^JavaPath=', '')
if (!$Java) { $Java = 'java' }
if ($Java -match 'javaw\.exe$') {
    $ConsoleJava = $Java -replace 'javaw\.exe$', 'java.exe'
    if (Test-Path $ConsoleJava) { $Java = $ConsoleJava }
}
try {
    & (Join-Path $SyncDir 'update-client.ps1') -Java $Java -MinecraftDir $MinecraftDir
} catch {
    Copy-Item -LiteralPath $CfgBackup -Destination $Cfg -Force
    throw
}
Write-Host 'Nakumi Sync terpasang. Mulai sekarang update dicek otomatis sebelum Minecraft dibuka.' -ForegroundColor Green
