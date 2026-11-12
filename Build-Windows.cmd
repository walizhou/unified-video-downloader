@echo off
cd /d "%~dp0"
if errorlevel 1 goto fail
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-windows.ps1"
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" goto fail
echo.
echo Build finished. See dist\VideoDownloader-Windows-x64.zip
pause
exit /b 0
:fail
echo.
echo Build failed. Send a screenshot of this window; do not send cookies.
pause
exit /b 1
