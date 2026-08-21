@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage6L_Full_Test_Debug_Reporting"
set "TEST_EXE=%TEST_ROOT%\Launcher\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage6L_Full_Test_Debug_Reporting.ini"
set "CONFIGURED_ROOT=%TEST_ROOT%\ConfiguredRoot"
set "RESULTS=%KIT_ROOT%Stage6L_Full_Test_Debug_Reporting_Results.txt"
set "REPORT="
set "WORKSPACE="
set "SELFTEST_REG="
set "VIEW_REG="
set "WORKSPACE_LINE="
set "REGISTRY_LINE="
set "VIEW_REGISTRY_LINE="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 6L Full Test Debug Reporting

echo ============================================================
echo X-LAUNCHER STAGE 6L - FULL TEST DEBUG REPORTING
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
    echo ERROR: The previous Stage 6L test folder could not be removed.
    goto EARLY_FAIL
)
if exist "%RESULTS%" del /q "%RESULTS%"
mkdir "%TEST_ROOT%\Launcher" >nul 2>&1
mkdir "%CONFIGURED_ROOT%" >nul 2>&1
copy /y "%SOURCE_EXE%" "%TEST_EXE%" >nul 2>&1
if not exist "%TEST_EXE%" goto EARLY_FAIL

>"%CONFIGURED_ROOT%\Payload.bat" echo @echo off
>>"%CONFIGURED_ROOT%\Payload.bat" echo ^>"%%~dp0PayloadRan.txt" echo RAN
>>"%CONFIGURED_ROOT%\Payload.bat" echo exit /b 0
>"%CONFIGURED_ROOT%\Before.bat" echo @echo off
>>"%CONFIGURED_ROOT%\Before.bat" echo ^>"%%~dp0RunBeforeRan.txt" echo RAN
>>"%CONFIGURED_ROOT%\Before.bat" echo exit /b 0
>"%CONFIGURED_ROOT%\After.bat" echo @echo off
>>"%CONFIGURED_ROOT%\After.bat" echo ^>"%%~dp0RunAfterRan.txt" echo RAN
>>"%CONFIGURED_ROOT%\After.bat" echo exit /b 0

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage6LConfiguredTargetsMustNotRun
    echo AppVer=FocusedTest
    echo Lang=en
    echo.
    echo [FileSystem]
    echo Root=.\ConfiguredRoot
    echo Temp=.\ConfiguredTemp
    echo Lib=.\ConfiguredLib
    echo.
    echo [FileToRun]
    echo PathToExe=.\Payload.bat
    echo WorkingDir=.
    echo.
    echo [Options]
    echo DeleteTemp=false
    echo MultipleInstances=true
    echo RunWait=true
    echo ShowSplash=false
    echo ShowTrayTip=false
    echo WriteLog=false
    echo HideShellWindow=true
    echo FirstRun=false
    echo Java=false
    echo JavaPath=.\ConfiguredJavaMustNotRun
    echo JavaURL=https://example.invalid/must-not-download.zip
    echo Debug=false
    echo RegView=Native
    echo TestRun=false
    echo.
    echo [Environment]
    echo XLAUNCHER_CONFIGURED_ENV=.\ConfiguredEnvironmentMustNotRun
    echo.
    echo [Functions]
    echo FileCreate=.\FunctionRan.txt
    echo.
    echo [RunBefore]
    echo RunFile=.\Before.bat
    echo.
    echo [RunAfter]
    echo RunFile=.\After.bat
)

reg delete "HKCU\Software\XLauncher_Test\Stage6L_Full" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Stage6L_Full" /v State /t REG_SZ /d HOST /f >nul 2>&1

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 6L FULL TEST DEBUG REPORTING RESULTS
    echo ======================================================
    echo.
)

echo A Full X-Launcher Test confirmation will appear.
echo Click Yes to run the isolated built-in Debug reporting tests.
echo.
echo The private debug log remains inside the Full Test Temp workspace.
echo No configured application operation Java download or Process Monitor runs.
echo This test does not request elevation.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=full
set "LAUNCH_RC=!ERRORLEVEL!"

for /d %%D in ("%TEST_ROOT%\Launcher\Diagnostics\X-Launcher-SelfTest\*") do set "REPORT=%%~fD\Full_Test_Report.log"

if "!LAUNCH_RC!"=="0" (
    call :RECORD PASS "Full Test launcher exit code"
) else (
    call :RECORD FAIL "Full Test launcher exit code was !LAUNCH_RC!"
)
call :CHECK_FILE "Full Test report was created" "!REPORT!"
call :CHECK_TEXT "Report contains zero failures" "FAIL: 0" "!REPORT!"
call :CHECK_TEXT "Report overall result is PASS" "OVERALL: PASS" "!REPORT!"
call :CHECK_TEXT "Debug log passed workspace boundary" "[PASS] [Debug Reporting] Debug classification log passed the isolated workspace boundary check" "!REPORT!"
call :CHECK_TEXT "Debug false produced no output" "[PASS] [Debug Reporting] Debug false produced no diagnostic result output" "!REPORT!"
call :CHECK_TEXT "Successful operation classified PASS" "[PASS] [Debug Reporting] Successful Boolean operation was classified PASS" "!REPORT!"
call :CHECK_TEXT "Failed operation classified FAIL" "[PASS] [Debug Reporting] Failed Boolean operation was classified FAIL" "!REPORT!"
call :CHECK_TEXT "No-change operation classified SKIP" "[PASS] [Debug Reporting] Legitimate text no-change result was classified SKIP" "!REPORT!"
call :CHECK_TEXT "Zero return was not blindly PASS" "[PASS] [Debug Reporting] Zero without error was not blindly classified PASS" "!REPORT!"
call :CHECK_TEXT "Unknown operation remained WARN" "[PASS] [Debug Reporting] Unknown operation name remained compatible and was classified WARN" "!REPORT!"
call :CHECK_TEXT "Launch success and failure distinguished" "[PASS] [Debug Reporting] Application launch success and failure were distinguished" "!REPORT!"
call :CHECK_TEXT "Registry recovery result recorded" "[PASS] [Debug Reporting] Registry recovery success was recorded" "!REPORT!"
call :CHECK_TEXT "Environment classifications distinguished" "[PASS] [Debug Reporting] Environment PASS SKIP and FAIL results were distinguished" "!REPORT!"
call :CHECK_TEXT "Cleanup classifications distinguished" "[PASS] [Debug Reporting] Temp cleanup removed disabled and failed results were distinguished" "!REPORT!"
call :CHECK_TEXT "Debug session summary totals exact" "[PASS] [Debug Reporting] Debug session boundaries and summary totals were exact" "!REPORT!"
call :CHECK_TEXT "Debug counters matched output" "[PASS] [Debug Reporting] Debug counters matched the emitted result classifications" "!REPORT!"
call :CHECK_TEXT "Debug state restored" "[PASS] [Debug Reporting] Debug globals counters session and environment were restored" "!REPORT!"
call :CHECK_TEXT "Stage 6K Java transactions still pass" "[PASS] [Java Transaction] Java transaction working directory and cancellation state were restored" "!REPORT!"
call :CHECK_TEXT "Stage 6J JavaPath still passes" "[PASS] [Java Path] JavaPath test globals and process environment were restored" "!REPORT!"
call :CHECK_TEXT "Stage 6I splash and tray still pass" "[PASS] [Splash Tray] Splash windows and timeout callbacks were closed after inspection" "!REPORT!"
call :CHECK_TEXT "Stage 6H path safety still passes" "[PASS] [Path Safety] Launcher path globals were restored after cleanup checks" "!REPORT!"
call :CHECK_TEXT "Stage 6G environment paths still pass" "[PASS] [Environment Path] Process environment, working directory and launcher path globals were restored" "!REPORT!"
call :CHECK_TEXT "Stage 6F registry recovery still passes" "[PASS] [Registry Recovery] Recovery used the saved view, restored the caller view and removed transaction data" "!REPORT!"
call :CHECK_TEXT "Report contains privacy warning" "Privacy: Review paths and diagnostic details before sharing." "!REPORT!"

set "CONFIGURED_SAFE=PASS"
if exist "%CONFIGURED_ROOT%\PayloadRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\RunBeforeRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\RunAfterRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\FunctionRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\ConfiguredEnvironmentMustNotRun" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\ConfiguredJavaMustNotRun" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\ConfiguredLib" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\ConfiguredTemp" set "CONFIGURED_SAFE=FAIL"
call :RECORD !CONFIGURED_SAFE! "Configured payload environment Java settings and operations were not executed"

reg query "HKCU\Software\XLauncher_Test\Stage6L_Full" /v State 2>nul | find /i "HOST" >nul
if not errorlevel 1 (
    call :RECORD PASS "Unrelated host registry sentinel remained unchanged"
) else (
    call :RECORD FAIL "Unrelated host registry sentinel was changed"
)

if defined REPORT if exist "!REPORT!" (
    for /f "delims=" %%L in ('findstr /b /c:"Workspace: " "!REPORT!"') do set "WORKSPACE_LINE=%%L"
    for /f "delims=" %%L in ('findstr /b /c:"Registry root: " "!REPORT!"') do set "REGISTRY_LINE=%%L"
    for /f "delims=" %%L in ('findstr /b /c:"Registry view root: " "!REPORT!"') do set "VIEW_REGISTRY_LINE=%%L"
    if defined WORKSPACE_LINE set "WORKSPACE=!WORKSPACE_LINE:Workspace: =!"
    if defined REGISTRY_LINE set "SELFTEST_REG=!REGISTRY_LINE:Registry root: =!"
    if defined VIEW_REGISTRY_LINE set "VIEW_REG=!VIEW_REGISTRY_LINE:Registry view root: =!"
)

if defined WORKSPACE if not exist "!WORKSPACE!" (
    call :RECORD PASS "Successful isolated workspace was removed"
) else (
    call :RECORD FAIL "Successful isolated workspace was not removed"
)

if defined SELFTEST_REG (
    reg query "!SELFTEST_REG!" >nul 2>&1
    if errorlevel 1 (
        call :RECORD PASS "Dedicated HKCU self-test root was removed"
    ) else (
        call :RECORD FAIL "Dedicated HKCU self-test root was not removed"
    )
) else (
    call :RECORD FAIL "Dedicated HKCU self-test root was not reported"
)

set "VIEW_CLEAN=PASS"
if not defined VIEW_REG set "VIEW_CLEAN=FAIL"
if defined VIEW_REG (
    reg query "!VIEW_REG!" /reg:32 >nul 2>&1
    if not errorlevel 1 set "VIEW_CLEAN=FAIL"
    reg query "!VIEW_REG!" /reg:64 >nul 2>&1
    if not errorlevel 1 set "VIEW_CLEAN=FAIL"
)
call :RECORD !VIEW_CLEAN! "Dedicated registry-view root was removed from both views"

reg delete "HKCU\Software\XLauncher_Test\Stage6L_Full" /f >nul 2>&1

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
    echo STAGE 6L FULL TEST DEBUG REPORTING: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage6L_Full_Test_Debug_Reporting_Results.txt and
    echo Full_Test_Report.log.
    goto FINISH_FAIL
)

if not "!PASS_COUNT!"=="30" (
    echo STAGE 6L FULL TEST DEBUG REPORTING: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    >>"%RESULTS%" echo Expected pass count: 30
    echo Expected 30 passes but received !PASS_COUNT!.
    goto FINISH_FAIL
)

echo STAGE 6L FULL TEST DEBUG REPORTING: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide these two files:
echo 1. Stage6L_Full_Test_Debug_Reporting_Results.txt
echo 2. Full_Test_Report.log from the Report path shown above
goto FINISH_OK

:CHECK_FILE
if exist "%~2" (
    call :RECORD PASS "%~1"
) else (
    call :RECORD FAIL "%~1"
)
exit /b 0

:CHECK_TEXT
if not exist "%~3" (
    call :RECORD FAIL "%~1"
    exit /b 0
)
findstr /i /l /c:"%~2" "%~3" >nul 2>&1
if errorlevel 1 (
    call :RECORD FAIL "%~1"
) else (
    call :RECORD PASS "%~1"
)
exit /b 0

:RECORD
if /i "%~1"=="PASS" (
    set /a PASS_COUNT+=1
    >>"%RESULTS%" echo [PASS] %~2
    echo [PASS] %~2
) else (
    set /a FAIL_COUNT+=1
    >>"%RESULTS%" echo [FAIL] %~2
    echo [FAIL] %~2
)
exit /b 0

:EARLY_FAIL
if not exist "%RESULTS%" (
    >"%RESULTS%" echo X-LAUNCHER STAGE 6L FULL TEST DEBUG REPORTING RESULTS
)
>>"%RESULTS%" echo [FAIL] Focused runner setup failed before Full Test launch
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: 0
>>"%RESULTS%" echo Failed: 1
>>"%RESULTS%" echo Overall: FAIL
echo.
echo Please leave this window open and provide the visible error text.

:FINISH_FAIL
echo.
pause
exit /b 1

:FINISH_OK
echo.
pause
exit /b 0
