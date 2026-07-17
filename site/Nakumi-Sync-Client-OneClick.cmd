@echo off
setlocal
cd /d "%~dp0"
set "NAKUMI_INSTANCE_ROOT=%CD%"
echo Memasang Nakumi Sync ke instance ini...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-RestMethod 'https://bayusegara27.github.io/nakumi-sync/bootstrap/client/oneclick.ps1' | Invoke-Expression"
if errorlevel 1 (
  echo.
  echo Instalasi gagal. Pastikan file ini berada di root instance PineconeMC.
  pause
  exit /b 1
)
echo.
echo SELESAI. Update berikutnya otomatis sebelum Minecraft dibuka.
pause

