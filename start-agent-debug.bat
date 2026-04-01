@echo off
REM Debug launcher: keep console open to inspect startup issues

cd /d %~dp0

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -NoExit -STA -File "%~dp0agent-control-launcher.ps1"
