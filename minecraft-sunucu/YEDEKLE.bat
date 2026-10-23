@echo off
title Minecraft Sunucusu - Yedekleme
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0araclar\yedekle.ps1"
echo.
pause
