@echo off
setlocal EnableExtensions
set "WORK=%~dp0Debug_Feature_Test_Work"
if not exist "%WORK%" mkdir "%WORK%" >nul 2>&1
>"%WORK%\RunBefore_PASS.txt" echo RunBefore completed before the payload.
if not exist "%WORK%\RunBefore_PASS.txt" exit /b 1
exit /b 0
