@echo off
setlocal
title Minecraft Sunucusu
cd /d "%~dp0"
if not exist "sunucu\paper.jar" goto kurulmamis
if not exist "java\bin\java.exe" goto kurulmamis
if not exist "AYARLAR.cmd" goto kurulmamis
call "%~dp0AYARLAR.cmd"

:dongu
echo.
echo [%date% %time%] Yedek aliniyor...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0araclar\yedekle.ps1" -Otomatik
rem Duyurular, saatlik yedek ve gece restart icin gizli yardimci; zaten calisiyorsa yenisi hemen kapanir.
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0araclar\arkaplan.ps1"
echo [%date% %time%] Sunucu baslatiliyor. Kapatmak icin bu pencereye stop yazip Enter'a bas.
cd /d "%~dp0sunucu"
"%~dp0java\bin\java.exe" -Xms%RAM% -Xmx%RAM% %JVM_FLAGS% -jar paper.jar --nogui
cd /d "%~dp0"
echo.
echo [%date% %time%] Sunucu kapandi.
choice /c EH /t 10 /d E /m "10 saniye icinde yeniden baslatilacak. Tamamen kapatmak icin H'ye bas. Yeniden baslatilsin mi"
if errorlevel 2 goto son
goto dongu

:kurulmamis
echo Sunucu henuz kurulmamis. Once KUR.bat dosyasini calistir.
pause
exit /b 1

:son
endlocal
