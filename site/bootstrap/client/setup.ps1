param(
    [string]$InstanceRoot = '',
    [string]$InstancesRoot = '',
    [string]$FullZipUrl = 'https://github.com/bayusegara27/nakumi-sync/releases/download/r9.3-full/Homestead-x-All-of-Create-Aeronautics-client-r9.3-fullsync-20260717.zip',
    [string]$FullZipSha256 = 'FD01E14F174F8BA4288C3968A0CFE0322497719B4D9A27191CDC84E4877377A1'
)

$ErrorActionPreference = 'Stop'
$Channel = 'https://bayusegara27.github.io/nakumi-sync'
$InstanceFolderName = 'Homestead-x-All-of-Create-Aeronautics'

function Test-Instance([string]$Path) {
    return $Path -and (Test-Path -LiteralPath (Join-Path $Path 'instance.cfg')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'minecraft'))
}

function Get-InstancesRoots {
    if ($InstancesRoot) {
        if (Test-Path -LiteralPath $InstancesRoot -PathType Container) {
            return ,([IO.Path]::GetFullPath($InstancesRoot))
        }
        return @()
    }
    $Candidates = [Collections.Generic.List[string]]::new()
    foreach ($Drive in Get-PSDrive -PSProvider FileSystem) {
        $Candidates.Add((Join-Path $Drive.Root 'PineconeMC\Instance'))
        $Candidates.Add((Join-Path $Drive.Root 'PineconeMC\instances'))
    }
    $Candidates.Add((Join-Path $env:APPDATA 'PineconeMC\instances'))
    $Candidates.Add((Join-Path $env:APPDATA 'PrismLauncher\instances'))
    return $Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
}

function Select-InstancesRoot {
    $Roots = @(Get-InstancesRoots)
    if ($Roots.Count -eq 1) { return $Roots[0] }
    if ($Roots.Count -gt 1) {
        $Pinecone = @($Roots | Where-Object { $_ -match 'PineconeMC' })
        if ($Pinecone.Count -eq 1) { return $Pinecone[0] }
    }
    Add-Type -AssemblyName System.Windows.Forms
    $Dialog = [Windows.Forms.FolderBrowserDialog]::new()
    $Dialog.Description = 'Pilih folder Instance/instances milik PineconeMC atau Prism Launcher'
    $Dialog.UseDescriptionForTitle = $true
    if ($Dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {
        throw 'Instalasi dibatalkan: folder instances belum dipilih.'
    }
    return $Dialog.SelectedPath
}

function Find-ExistingInstance {
    if (Test-Instance $InstanceRoot) { return [IO.Path]::GetFullPath($InstanceRoot) }
    if (Test-Instance $PWD.Path) { return $PWD.Path }
    $Matches = [Collections.Generic.List[IO.DirectoryInfo]]::new()
    foreach ($Root in Get-InstancesRoots) {
        foreach ($Directory in Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue) {
            if (!(Test-Instance $Directory.FullName)) { continue }
            $Cfg = Get-Content -LiteralPath (Join-Path $Directory.FullName 'instance.cfg') -Raw -ErrorAction SilentlyContinue
            if ($Directory.Name -match '(?i)Homestead.*(All.of.Create|Aeronautics)' -or
                $Cfg -match '(?im)^name=.*Homestead.*(All of Create|Aeronautics)') {
                $Matches.Add($Directory)
            }
        }
    }
    if ($Matches.Count) {
        return ($Matches | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
    return ''
}

function Download-Verified([string]$Url, [string]$Destination, [string]$ExpectedHash) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    & curl.exe -L --fail --retry 3 --progress-bar --output $Destination $Url
    if ($LASTEXITCODE -ne 0) { throw "Download gagal: $Url" }
    $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Destination).Hash
    if ($Actual -ne $ExpectedHash) {
        Remove-Item -LiteralPath $Destination -Force
        throw "SHA-256 snapshot client salah. Expected=$ExpectedHash Actual=$Actual"
    }
}

$Existing = Find-ExistingInstance
if ($Existing) {
    $Target = $Existing
    Write-Host "Instance lama ditemukan: $Target" -ForegroundColor Cyan
} else {
    if ($InstanceRoot) {
        $Target = [IO.Path]::GetFullPath($InstanceRoot)
        $Root = Split-Path $Target -Parent
        New-Item -ItemType Directory -Force -Path $Root | Out-Null
    } else {
        $Root = Select-InstancesRoot
        $Target = Join-Path $Root $InstanceFolderName
    }
    if (Test-Path -LiteralPath $Target) {
        throw "Folder tujuan sudah ada tetapi bukan instance yang valid: $Target"
    }
    $Temp = Join-Path $env:TEMP 'nakumi-full-client-r9.3.zip'
    Write-Host 'Mengunduh snapshot client penuh (sekitar 1 GB)...' -ForegroundColor Cyan
    Download-Verified $FullZipUrl $Temp $FullZipSha256
    $Staging = "$Target.installing"
    if (Test-Path -LiteralPath $Staging) { Remove-Item -LiteralPath $Staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Staging | Out-Null
    Expand-Archive -LiteralPath $Temp -DestinationPath $Staging -Force
    if (!(Test-Instance $Staging)) { throw 'Snapshot selesai diekstrak tetapi instance.cfg/minecraft tidak ditemukan.' }
    Move-Item -LiteralPath $Staging -Destination $Target
    Remove-Item -LiteralPath $Temp -Force
    Write-Host "Instance baru dibuat: $Target" -ForegroundColor Green
}

$Bootstrap = @{
    'bootstrap/client/INSTALL-NAKUMI-SYNC.ps1' = 'INSTALL-NAKUMI-SYNC.ps1'
    'bootstrap/client/minecraft/nakumi-sync/update-client.ps1' = 'minecraft/nakumi-sync/update-client.ps1'
    'bootstrap/client/minecraft/nakumi-sync/packwiz-installer-bootstrap.jar' = 'minecraft/nakumi-sync/packwiz-installer-bootstrap.jar'
}
foreach ($Pair in $Bootstrap.GetEnumerator()) {
    $Destination = Join-Path $Target $Pair.Value
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "$Channel/$($Pair.Key)" -OutFile $Destination
}
& (Join-Path $Target 'INSTALL-NAKUMI-SYNC.ps1') -ChannelBaseUrl $Channel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'SELESAI. Instance lama/baru sekarang mengikuti Nakumi Sync otomatis.' -ForegroundColor Green
Write-Host "Instance: $Target"
