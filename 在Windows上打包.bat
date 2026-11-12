@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-windows.ps1"
echo.
if errorlevel 1 (
  echo 打包失败。请截图上面的错误信息，不要发送 Cookie 文件。
) else (
  echo 打包完成：dist\VideoDownloader-Windows-x64.zip
)
pause
