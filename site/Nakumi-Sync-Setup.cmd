@echo off
setlocal
title Nakumi Sync Setup
echo Nakumi Sync: mendeteksi instance lama atau memasang modpack baru...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; irm 'https://bayusegara27.github.io/nakumi-sync/bootstrap/client/setup.ps1' -OutFile (Join-Path $env:TEMP 'nakumi-client-setup.ps1'); & (Join-Path $env:TEMP 'nakumi-client-setup.ps1')"
if errorlevel 1 (
  echo.
  echo Instalasi gagal. Baca pesan di atas.
  pause
  exit /b 1
)
echo.
echo SELESAI. Buka/refresh PineconeMC lalu launch instance Nakumi.
pause

