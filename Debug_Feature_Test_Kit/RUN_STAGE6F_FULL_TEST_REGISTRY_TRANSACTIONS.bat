@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage6F_Full_Test_Registry_Transactions"
set "TEST_EXE=%TEST_ROOT%\Launcher\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage6F_Full_Test_Registry_Transactions.ini"
set "CONFIGURED_ROOT=%TEST_ROOT%\ConfiguredRoot"
set "RESULTS=%KIT_ROOT%Stage6F_Full_Test_Registry_Transactions_Results.txt"
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
title X-Launcher Stage 6F Full Test Registry Transactions

echo ============================================================
echo X-LAUNCHER STAGE 6F - FULL TEST REGISTRY TRANSACTIONS
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
    echo ERROR: The previous Stage 6F test folder could not be removed.
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
    echo AppName=Stage6FConfiguredTargetsMustNotRun
    echo AppVer=FocusedTest
    echo Lang=en
    echo.
    echo [FileSystem]
    echo Root=.\ConfiguredRoot
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
    echo RegEdit=.\Payload.bat
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
    echo RegView=32
    echo RegEdit=request
    echo TestRun=false
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

reg delete "HKCU\Software\XLauncher_Test\Stage6F_Full" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Stage6F_Full" /v State /t REG_SZ /d HOST /f >nul 2>&1

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 6F FULL TEST REGISTRY TRANSACTIONS RESULTS
    echo =========================================================
    echo.
)

echo A Full X-Launcher Test confirmation will appear.
echo Click Yes to run the isolated built-in registry tests.
echo.
echo The test uses only unique disposable HKCU branches and its Temp
echo workspace. It verifies both registry views, ordered restore and
echo interrupted-transaction recovery. It does not request elevation.
echo The configured payload, operations and registry manager must not run.
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
call :CHECK_TEXT "Registry paths passed the workspace boundary" "[PASS] [Registry] Every fixture and transaction path passed the isolated workspace boundary check" "!REPORT!"
call :CHECK_TEXT "Registry fixtures were created" "[PASS] [Registry] Isolated registry fixtures were created" "!REPORT!"
call :CHECK_TEXT "Registry commands selected both requested views" "[PASS] [Registry View] 32-bit and 64-bit registry commands selected the requested views" "!REPORT!"
call :CHECK_TEXT "Registry values remained isolated by view" "[PASS] [Registry View] 32-bit and 64-bit values remained isolated in separate registry views" "!REPORT!"
call :CHECK_TEXT "Both view-isolation keys were removed" "[PASS] [Registry View] View-isolation keys were removed from both registry views" "!REPORT!"
call :CHECK_TEXT "Portable values replaced protected host roots" "[PASS] [Registry Transaction] Portable values replaced both protected host roots" "!REPORT!"
call :CHECK_TEXT "Manifest preserved ordered distinct backups" "[PASS] [Registry Transaction] Transaction manifest recorded Native view and ordered distinct backups" "!REPORT!"
call :CHECK_TEXT "Normal close restored both host roots" "[PASS] [Registry Restore] Normal close restored both host roots in manifest order" "!REPORT!"
call :CHECK_TEXT "Normal close saved both portable states" "[PASS] [Registry Restore] Normal close saved current portable values back to both REG files" "!REPORT!"
call :CHECK_TEXT "Normal transaction data was removed" "[PASS] [Registry Restore] Normal transaction data was removed after successful restore" "!REPORT!"
call :CHECK_TEXT "Interrupted transaction created a pending marker" "[PASS] [Registry Recovery] Interrupted transaction fixture installed portable state with a pending marker" "!REPORT!"
call :CHECK_TEXT "Interrupted transaction recovered completely" "[PASS] [Registry Recovery] Recovery used the saved view, restored the caller view and removed transaction data" "!REPORT!"
call :CHECK_TEXT "Stage 6E writer coverage still passes" "[PASS] [Writer Semantics] WriteToReg generated the exact header, key and value structure" "!REPORT!"
call :CHECK_TEXT "Report contains privacy warning" "Privacy: Review paths and diagnostic details before sharing." "!REPORT!"

set "CONFIGURED_SAFE=PASS"
if exist "%CONFIGURED_ROOT%\PayloadRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\RunBeforeRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\RunAfterRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\FunctionRan.txt" set "CONFIGURED_SAFE=FAIL"
call :RECORD !CONFIGURED_SAFE! "Configured payload operations and registry manager were not executed"

reg query "HKCU\Software\XLauncher_Test\Stage6F_Full" /v State 2>nul | find /i "HOST" >nul
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

reg delete "HKCU\Software\XLauncher_Test\Stage6F_Full" /f >nul 2>&1

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
    echo STAGE 6F FULL TEST REGISTRY TRANSACTIONS: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage6F_Full_Test_Registry_Transactions_Results.txt and
    echo Full_Test_Report.log.
    goto FINISH_FAIL
)

echo STAGE 6F FULL TEST REGISTRY TRANSACTIONS: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide Stage6F_Full_Test_Registry_Transactions_Results.txt and
echo Full_Test_Report.log.
echo.
pause
exit /b 0

:CHECK_FILE
if "%~2"=="" (
    call :RECORD FAIL "%~1"
) else if exist "%~2" (
    call :RECORD PASS "%~1"
) else (
    call :RECORD FAIL "%~1"
)
exit /b 0

:CHECK_TEXT
if "%~3"=="" (
    call :RECORD FAIL "%~1"
    exit /b 0
)
if exist "%~3" (
    findstr /i /l /x /c:"%~2" "%~3" >nul 2>&1
    if not errorlevel 1 (
        call :RECORD PASS "%~1"
        exit /b 0
    )
)
call :RECORD FAIL "%~1"
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
echo STAGE 6F FULL TEST REGISTRY TRANSACTIONS: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
