@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-MSI-Claw-A8-Compatibility.ps1"
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%
