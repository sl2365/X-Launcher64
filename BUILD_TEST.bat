@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title X-Launcher - Build and Test

set "PROJECT_ROOT=%CD%"
set "AUTOIT_DIR=%PROJECT_ROOT%\..\_Tools\AutoIT\- 3.3.18.0"
set "WRAPPER_DIR=%PROJECT_ROOT%\..\_Tools\AutoIT\AutoIt3Wrapper"
set "SOURCE=%PROJECT_ROOT%\x-compiler.au3"
set "OUTPUT=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_DIR=%PROJECT_ROOT%\Test_Suite"
set "TEST_EXE=%TEST_DIR%\X-Launcher_x64.exe"

echo ============================================================
echo X-LAUNCHER - BUILD AND TEST v2
echo ============================================================
echo.

if not exist "%AUTOIT_DIR%\AutoIt3_x64.exe" goto MISSING_AUTOIT
if not exist "%AUTOIT_DIR%\Au3Check.exe" goto MISSING_AU3CHECK
if not exist "%AUTOIT_DIR%\Aut2Exe\Aut2exe_x64.exe" goto MISSING_AUT2EXE
if not exist "%WRAPPER_DIR%\AutoIt3Wrapper.au3" goto MISSING_WRAPPER
if not exist "%SOURCE%" goto MISSING_SOURCE
if not exist "%TEST_DIR%\RUN_TEST.bat" goto MISSING_TEST

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
if exist "%TEST_EXE%" del /q "%TEST_EXE%"

"%AUTOIT_DIR%\AutoIt3_x64.exe" "%WRAPPER_DIR%\AutoIt3Wrapper.au3" /NoStatus /prod /AutoIt3Dir "%AUTOIT_DIR%" /in "%SOURCE%"
set "BUILD_RC=%ERRORLEVEL%"

echo ------------------------------------------------------------
echo.
if not "%BUILD_RC%"=="0" goto BUILD_FAILED
if not exist "%OUTPUT%" goto BUILD_FAILED

echo Build: PASS
echo.
echo Moving compiled EXE to Test_Suite...
move /y "%OUTPUT%" "%TEST_EXE%" >nul
if errorlevel 1 goto MOVE_FAILED

echo Move:  PASS
echo.
echo Starting regression tests...
echo.

call "%TEST_DIR%\RUN_TEST.bat" /nopause
set "TEST_RC=%ERRORLEVEL%"

echo.
if "%TEST_RC%"=="0" (
    echo ============================================================
    echo BUILD AND REGRESSION TESTS: PASS
    echo ============================================================
) else (
    echo ============================================================
    echo BUILD: PASS
    echo REGRESSION TESTS: FAIL
    echo ============================================================
)

echo.
pause
exit /b %TEST_RC%

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

:MISSING_TEST
echo ERROR: Test_Suite\RUN_TEST.bat was not found.
goto STOP

:BUILD_FAILED
echo ============================================================
echo BUILD: FAIL
echo ============================================================
echo.
echo AutoIt3Wrapper or Aut2Exe failed.
echo The tests were NOT started.
goto STOP

:MOVE_FAILED
echo ============================================================
echo BUILD: PASS
echo MOVE TO TEST_SUITE: FAIL
echo ============================================================
goto STOP

:STOP
echo.
echo The window will remain open so the output can be copied.
echo.
pause
exit /b 1
