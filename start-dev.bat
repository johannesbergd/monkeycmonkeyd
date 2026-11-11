@echo off
rem Start a work session: installs the pinned Rojo version (first run only), then starts syncing.
rem In Studio, click Connect in the Rojo plugin. Close this window to stop syncing.
setlocal
cd /d "%~dp0"

where rokit >nul 2>nul
if errorlevel 1 goto norokit

echo Checking tools...
rokit install
echo.
echo Rojo is starting. In Studio: Plugins ^> Rojo ^> Connect.
echo Keep this window open while you work.
echo.
rojo serve
pause
exit /b 0

:norokit
echo Rokit isn't installed yet. Open PowerShell and run:
echo.
echo   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 ^| Invoke-Expression
echo.
echo Then close PowerShell and double-click start-dev.bat again.
pause
exit /b 1
