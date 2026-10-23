@echo off
title Minecraft Sunucusu - Kurulum
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0araclar\kurulum.ps1"
echo.
pause
