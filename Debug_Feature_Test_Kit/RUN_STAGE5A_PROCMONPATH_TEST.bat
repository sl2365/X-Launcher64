@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage5A_ProcMonPath_Test"
set "TEST_EXE=%TEST_ROOT%\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage5A_ProcMonPath_Test.ini"
set "ROOT=%TEST_ROOT%\Root"
set "PROCMON_DIR=%ROOT%\Lib\Tools\ProcessMonitor"
set "PROCMON=%PROCMON_DIR%\Procmon64.exe"
set "PROCMON_BEFORE=%PROCMON_DIR%\Procmon64.before.exe"
set "RESULTS=%KIT_ROOT%Stage5A_ProcMonPath_Test_Results.txt"
set "REPORT="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 5A ProcMonPath Test

echo ============================================================
echo X-LAUNCHER STAGE 5A - PROCMONPATH FOCUSED TEST
echo ============================================================
echo.

if not exist "%SOURCE_EXE%" (
    echo ERROR: X-Launcher_x64.exe was not found in:
    echo "%PROJECT_ROOT%"
    echo.
    echo Double-click BUILD.bat before running this test.
    goto EARLY_FAIL
)

if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
if exist "%TEST_ROOT%" (
    echo ERROR: The previous Stage 5A test folder could not be removed:
    echo "%TEST_ROOT%"
    goto EARLY_FAIL
)

if exist "%RESULTS%" del /q "%RESULTS%"
mkdir "%PROCMON_DIR%" >nul 2>&1
if not exist "%PROCMON_DIR%" (
    echo ERROR: The disposable test folders could not be created.
    goto EARLY_FAIL
)

copy /y "%SOURCE_EXE%" "%TEST_EXE%" >nul 2>&1
if not exist "%TEST_EXE%" (
    echo ERROR: The compiled launcher could not be copied into the test folder.
    goto EARLY_FAIL
)

>"%ROOT%\Payload.bat" echo @echo off
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0PayloadRan.txt" echo PAYLOAD_RAN
>>"%ROOT%\Payload.bat" echo exit /b 0

>"%PROCMON%" echo DISPOSABLE_STAGE5A_PROCMON_FIXTURE
copy /y "%PROCMON%" "%PROCMON_BEFORE%" >nul 2>&1

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage5AProcMonPathTest
    echo Lang=en
    echo.
    echo [FileSystem]
    echo Root=.\Root
    echo Temp=.\Temp
    echo Cache=.\Cache
    echo Home=.\Home
    echo Bin=.\Bin
    echo Lib=.\Lib
    echo Doc=.\Documents
    echo Backup=.\Backups
    echo Download=.\Downloads
    echo.
    echo [FileToRun]
    echo PathToExe=.\Payload.bat
    echo Parameters=
    echo WorkingDir=.
    echo WinGetProcess=
    echo.
    echo [Options]
    echo DeleteTemp=false
    echo MultipleInstances=true
    echo FixAppData=false
    echo RunWait=true
    echo ShowSplash=false
    echo ShowTrayTip=false
    echo WriteLog=false
    echo HideShellWindow=true
    echo FirstRun=false
    echo Java=false
    echo Debug=false
    echo RegView=Native
    echo TestRun=false
    echo ProcMonPath=$Lib$\Tools\ProcessMonitor
)

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 5A PROCMONPATH TEST RESULTS
    echo ============================================
    echo.
)

echo A Configuration Probe confirmation will appear.
echo Click Yes to run the read-only Probe.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=probe
set "LAUNCH_RC=!ERRORLEVEL!"

for %%F in ("%TEST_ROOT%\Diagnostics\*.txt") do set "REPORT=%%~fF"

if "!LAUNCH_RC!"=="0" (
    call :RECORD PASS "Configuration Probe exit code"
) else (
    call :RECORD FAIL "Configuration Probe exit code was !LAUNCH_RC!"
)

if defined REPORT (
    call :RECORD PASS "Configuration Probe report was created"
) else (
    call :RECORD FAIL "Configuration Probe report was not created"
)

set "PROCMON_PASS=FAIL"
if defined REPORT (
    findstr /l /b /c:"[PASS] [Process Monitor] ProcMonPath resolved from the configured folder:" "!REPORT!" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /c:"Procmon64.exe" "!REPORT!" >nul 2>&1
        if not errorlevel 1 set "PROCMON_PASS=PASS"
    )
)
call :RECORD !PROCMON_PASS! "X-Launcher variable folder resolved to Procmon64.exe"

set "SUMMARY_PASS=FAIL"
if defined REPORT (
    findstr /l /x /c:"FAIL: 0" "!REPORT!" >nul 2>&1
    if not errorlevel 1 set "SUMMARY_PASS=PASS"
)
call :RECORD !SUMMARY_PASS! "Probe completed with no configuration failures"

if not exist "%ROOT%\PayloadRan.txt" (
    call :RECORD PASS "Configured payload was not launched"
) else (
    call :RECORD FAIL "Configured payload was unexpectedly launched"
)

fc /b "%PROCMON%" "%PROCMON_BEFORE%" >nul 2>&1
if not errorlevel 1 (
    call :RECORD PASS "Process Monitor fixture remained unchanged"
) else (
    call :RECORD FAIL "Process Monitor fixture was changed"
)

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined REPORT >>"%RESULTS%" echo Report: !REPORT!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 5A PROCMONPATH TEST: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage5A_ProcMonPath_Test_Results.txt.
    goto FINISH_FAIL
)

echo STAGE 5A PROCMONPATH TEST: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo All test files are inside Debug_Feature_Test_Kit.
echo.
pause
exit /b 0

:RECORD
if /i "%~1"=="PASS" (
    set /a PASS_COUNT+=1
) else (
    set /a FAIL_COUNT+=1
)
echo - %~2: %~1
>>"%RESULTS%" echo - %~2: %~1
exit /b 0

:EARLY_FAIL
echo.
echo STAGE 5A PROCMONPATH TEST: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
