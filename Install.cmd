@echo off
rem Double-click to install Hardcore Tactical Realism (finds the Steam copy automatically).
rem GOG or custom folder: drag your "SpaceBourne 2" folder onto this file.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %1
pause
