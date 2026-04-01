@echo off
REM Legacy launcher: keep cmd windows for node and frpc

start "Code Agent" cmd /k "cd /d %~dp0 && node server.js"
start "frpc" cmd /k "cd /d %~dp0 && frpc.exe -c frpc.toml"

echo.
echo [Agent] Started Node.js + frpc in separate windows.
echo [Agent] Web UI: http://agent.xujinlong.asia
pause
