@echo off
title playit.gg Tuneli
cd /d "%~dp0"
if not exist "playit\playit.exe" goto kurulmamis

:dongu
"%~dp0playit\playit.exe"
echo.
echo Tunel kapandi. 10 saniye icinde yeniden baslatilacak. Cikmak icin pencereyi kapat.
timeout /t 10
goto dongu

:kurulmamis
echo playit.gg bulunamadi. Once KUR.bat dosyasini calistir.
pause
exit /b 1
