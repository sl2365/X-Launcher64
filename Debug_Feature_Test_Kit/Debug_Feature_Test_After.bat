@echo off
setlocal EnableExtensions
set "WORK=%~dp0Debug_Feature_Test_Work"
if not exist "%WORK%\Payload_PASS.txt" exit /b 1
>"%WORK%\RunAfter_PASS.txt" echo RunAfter completed after the payload.
if not exist "%WORK%\RunAfter_PASS.txt" exit /b 2
exit /b 0
