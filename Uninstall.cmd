@echo off
rem Double-click to remove Hardcore Tactical Realism (GOG/custom folder: drag the game folder onto this file).
if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -Uninstall
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -Game "%~1" -Uninstall
)
pause
