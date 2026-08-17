@echo off
setlocal EnableExtensions
title X-Launcher Stage 6J Real Java64 Smoke Test

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_STAGE6J_REAL_JAVA64_SMOKE.ps1"
set "TEST_RC=%ERRORLEVEL%"

echo.
if "%TEST_RC%"=="0" (
    echo Expected result achieved. Please upload only:
    echo Stage6J_Real_Java64_Smoke_Results.txt
) else (
    echo The smoke test did not pass.
    echo Please upload Stage6J_Real_Java64_Smoke_Results.txt.
)
echo.
pause
exit /b %TEST_RC%

