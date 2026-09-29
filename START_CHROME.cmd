@echo off
cd /d "%~dp0"
call flutter run -d chrome --web-port 51874
pause
