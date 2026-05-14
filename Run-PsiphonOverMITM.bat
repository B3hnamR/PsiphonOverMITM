@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "ROOT=%~dp0"
set "SCRIPT=%ROOT%PsiphonOverMITM.ps1"

if not exist "%SCRIPT%" (
  echo Missing script: %SCRIPT%
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "ERR=%ERRORLEVEL%"
echo.
echo Log file: "%ROOT%PsiphonOverMITM.log"
if /I not "%MITM_NO_PAUSE%"=="1" pause
exit /b %ERR%
