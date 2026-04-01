@echo off
REM start-agent.bat - Desktop controller launcher

cd /d %~dp0

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0agent-control-launcher.ps1"
