@echo off
setlocal
set "ROOT=%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Run-Validated-LegionGo-AMD-26.10.1-Public-Beta-v5.0.ps1"
exit /b %ERRORLEVEL%
