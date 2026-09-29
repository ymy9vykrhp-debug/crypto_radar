@echo off
cd /d "%~dp0"
echo Crypto Radar: http://127.0.0.1:51875
echo Open this address in Chrome after the server is ready.
echo Keep this window open while using the app.
call flutter --no-version-check run -d web-server --web-hostname 127.0.0.1 --web-port 51875
pause
