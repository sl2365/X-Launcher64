@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title X-Launcher - Build

set "PROJECT_ROOT=%CD%"
set "AUTOIT_DIR=%PROJECT_ROOT%\..\_Tools\AutoIT\- 3.3.18.0"
set "WRAPPER_DIR=%PROJECT_ROOT%\..\_Tools\AutoIT\AutoIt3Wrapper"
set "SOURCE=%PROJECT_ROOT%\x-compiler.au3"
set "OUTPUT=%PROJECT_ROOT%\X-Launcher_x64.exe"

echo ============================================================
echo X-LAUNCHER - BUILD
echo ============================================================
echo.

if not exist "%AUTOIT_DIR%\AutoIt3_x64.exe" goto MISSING_AUTOIT
if not exist "%AUTOIT_DIR%\Au3Check.exe" goto MISSING_AU3CHECK
if not exist "%AUTOIT_DIR%\Aut2Exe\Aut2exe_x64.exe" goto MISSING_AUT2EXE
if not exist "%WRAPPER_DIR%\AutoIt3Wrapper.au3" goto MISSING_WRAPPER
if not exist "%SOURCE%" goto MISSING_SOURCE

echo Running AU3Check...
echo ------------------------------------------------------------
"%AUTOIT_DIR%\Au3Check.exe" -I "%AUTOIT_DIR%\Include" "%SOURCE%"
set "CHECK_RC=%ERRORLEVEL%"
echo ------------------------------------------------------------
echo AU3Check ended. rc:%CHECK_RC%
echo.

if not "%CHECK_RC%"=="0" (
    echo ============================================================
    echo AU3CHECK: FAIL
    echo ============================================================
    echo.
    echo Compilation was NOT started.
    goto STOP
)

echo AU3Check: PASS
echo.
echo Compiling X-Launcher_x64.exe...
echo ------------------------------------------------------------

if exist "%OUTPUT%" del /q "%OUTPUT%"
if exist "%OUTPUT%" goto OUTPUT_DELETE_FAILED

"%AUTOIT_DIR%\AutoIt3_x64.exe" "%WRAPPER_DIR%\AutoIt3Wrapper.au3" /NoStatus /prod /AutoIt3Dir "%AUTOIT_DIR%" /in "%SOURCE%"
set "BUILD_RC=%ERRORLEVEL%"

echo ------------------------------------------------------------
echo.
if not "%BUILD_RC%"=="0" goto BUILD_FAILED
if not exist "%OUTPUT%" goto BUILD_FAILED

echo ============================================================
echo BUILD: PASS
echo ============================================================
echo.
echo Compiled EXE:
echo "%OUTPUT%"
echo.
pause
exit /b 0

:MISSING_AUTOIT
echo ERROR: AutoIt 3.3.18.0 was not found in:
echo "%AUTOIT_DIR%"
goto STOP

:MISSING_AU3CHECK
echo ERROR: Au3Check.exe was not found:
echo "%AUTOIT_DIR%\Au3Check.exe"
goto STOP

:MISSING_AUT2EXE
echo ERROR: Aut2exe_x64.exe was not found:
echo "%AUTOIT_DIR%\Aut2Exe\Aut2exe_x64.exe"
goto STOP

:MISSING_WRAPPER
echo ERROR: AutoIt3Wrapper.au3 was not found:
echo "%WRAPPER_DIR%\AutoIt3Wrapper.au3"
goto STOP

:MISSING_SOURCE
echo ERROR: x-compiler.au3 was not found in the project folder.
goto STOP

:BUILD_FAILED
echo ============================================================
echo BUILD: FAIL
echo ============================================================
echo.
echo AutoIt3Wrapper or Aut2Exe failed.
goto STOP

:OUTPUT_DELETE_FAILED
echo ============================================================
echo BUILD: FAIL
echo ============================================================
echo.
echo The existing X-Launcher_x64.exe could not be removed.
echo Close it if it is running, then try again.
goto STOP

:STOP
echo.
echo The window will remain open so the output can be copied.
echo.
pause
exit /b 1
