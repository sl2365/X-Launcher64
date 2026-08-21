@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage6A_Full_Test_Foundation"
set "TEST_EXE=%TEST_ROOT%\Launcher\X-Launcher_x64.exe"
set "NOINI_EXE=%TEST_ROOT%\NoIniLauncher\X-Launcher_x64.exe"
set "NOINI_PATH=%TEST_ROOT%\Missing.ini"
set "TEST_INI=%TEST_ROOT%\Stage6A_Full_Test_Foundation.ini"
set "CONFIGURED_ROOT=%TEST_ROOT%\ConfiguredRoot"
set "RESULTS=%KIT_ROOT%Stage6A_Full_Test_Foundation_Results.txt"
set "REPORT="
set "NOINI_REPORT="
set "WORKSPACE="
set "SELFTEST_REG="
set "WORKSPACE_LINE="
set "REGISTRY_LINE="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 6A Full Test Foundation

echo ============================================================
echo X-LAUNCHER STAGE 6A - FULL TEST FOUNDATION
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
    echo ERROR: The previous Stage 6A test folder could not be removed.
    goto EARLY_FAIL
)
if exist "%RESULTS%" del /q "%RESULTS%"
mkdir "%TEST_ROOT%\Launcher" >nul 2>&1
mkdir "%TEST_ROOT%\NoIniLauncher" >nul 2>&1
mkdir "%CONFIGURED_ROOT%" >nul 2>&1
copy /y "%SOURCE_EXE%" "%TEST_EXE%" >nul 2>&1
copy /y "%SOURCE_EXE%" "%NOINI_EXE%" >nul 2>&1
if not exist "%TEST_EXE%" goto EARLY_FAIL
if not exist "%NOINI_EXE%" goto EARLY_FAIL

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
    echo AppName=Stage6AConfiguredTargetsMustNotRun
    echo AppVer=FocusedTest
    echo Lang=en
    echo.
    echo [FileSystem]
    echo Root=..\ConfiguredRoot
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

reg delete "HKCU\Software\XLauncher_Test\Stage6A_Full" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Stage6A_Full" /v State /t REG_SZ /d HOST /f >nul 2>&1

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 6A FULL TEST FOUNDATION RESULTS
    echo =================================================
    echo.
)

echo A Full X-Launcher Test confirmation will appear.
echo Click Yes to run the isolated built-in test.
echo.
echo The configured disposable payload and operations must not run.
echo This test does not use Process Monitor and should not request elevation.
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
call :CHECK_TEXT "Report identifies isolated built-in mode" "Mode: isolated built-in integrity test" "!REPORT!"
call :CHECK_TEXT "Report contains zero failures" "FAIL: 0" "!REPORT!"
call :CHECK_TEXT "Report overall result is PASS" "OVERALL: PASS" "!REPORT!"
call :CHECK_TEXT "Private helper success exit was verified" "[PASS] [Self Helper] Private helper completed with success exit code: exit=0; error=0" "!REPORT!"
call :CHECK_TEXT "Exact command-line quoting was verified" "[PASS] [Command Line] Exact arguments and quoted spacing were preserved" "!REPORT!"
call :CHECK_TEXT "Isolated working directory was verified" "[PASS] [Process] Private helper received the isolated working directory" "!REPORT!"
call :CHECK_TEXT "Inherited environment was verified" "[PASS] [Environment] Private helper inherited the isolated session variable" "!REPORT!"
call :CHECK_TEXT "Waited completion was verified" "[PASS] [Process] RunWait retained complete helper lifecycle" "!REPORT!"
call :CHECK_TEXT "Controlled nonzero exit was verified" "[PASS] [Process] Controlled nonzero helper exit code was observed: exit=23; error=0" "!REPORT!"
call :CHECK_TEXT "Report states configured targets were not used" "INI context only (configured targets were not used):" "!REPORT!"
call :CHECK_TEXT "Report identifies the self-test application" "Application: X-Launcher Full Self-Test" "!REPORT!"
call :CHECK_TEXT "Report records the tested executable" "Executable:" "!REPORT!"
call :CHECK_TEXT "Report contains privacy warning" "Privacy: Review paths and diagnostic details before sharing." "!REPORT!"

set "CONFIGURED_SAFE=PASS"
if exist "%CONFIGURED_ROOT%\PayloadRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\RunBeforeRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\RunAfterRan.txt" set "CONFIGURED_SAFE=FAIL"
if exist "%CONFIGURED_ROOT%\FunctionRan.txt" set "CONFIGURED_SAFE=FAIL"
call :RECORD !CONFIGURED_SAFE! "Configured payload and operations were not executed"

reg query "HKCU\Software\XLauncher_Test\Stage6A_Full" /v State 2>nul | find /i "HOST" >nul
if not errorlevel 1 (
    call :RECORD PASS "Host registry sentinel remained unchanged"
) else (
    call :RECORD FAIL "Host registry sentinel was changed"
)

if defined REPORT if exist "!REPORT!" (
    for /f "delims=" %%L in ('findstr /b /c:"Workspace: " "!REPORT!"') do set "WORKSPACE_LINE=%%L"
    for /f "delims=" %%L in ('findstr /b /c:"Registry root: " "!REPORT!"') do set "REGISTRY_LINE=%%L"
    if defined WORKSPACE_LINE set "WORKSPACE=!WORKSPACE_LINE:Workspace: =!"
    if defined REGISTRY_LINE set "SELFTEST_REG=!REGISTRY_LINE:Registry root: =!"
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

echo.
echo Running the isolated no-INI check automatically...
"%NOINI_EXE%" "--x-launcher-config=%NOINI_PATH%" --x-launcher-test=full --x-launcher-test-automated
set "NOINI_RC=!ERRORLEVEL!"
for /d %%D in ("%TEST_ROOT%\NoIniLauncher\Diagnostics\X-Launcher-SelfTest\*") do set "NOINI_REPORT=%%~fD\Full_Test_Report.log"
if "!NOINI_RC!"=="0" (
    call :RECORD PASS "No-INI Full Test launcher exit code"
) else (
    call :RECORD FAIL "No-INI Full Test launcher exit code was !NOINI_RC!"
)
if not exist "%NOINI_PATH%" (
    call :RECORD PASS "Missing application INI was not created"
) else (
    call :RECORD FAIL "Missing application INI was unexpectedly created"
)
call :CHECK_FILE "No-INI Full Test report was created" "!NOINI_REPORT!"
call :CHECK_TEXT "No-INI Full Test report contains zero failures" "FAIL: 0" "!NOINI_REPORT!"
call :CHECK_TEXT "No-INI report records the missing INI as context only" "INI context only (configured targets were not used): %NOINI_PATH%" "!NOINI_REPORT!"

reg delete "HKCU\Software\XLauncher_Test\Stage6A_Full" /f >nul 2>&1

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined REPORT >>"%RESULTS%" echo Report: !REPORT!
if defined NOINI_REPORT >>"%RESULTS%" echo No-INI report: !NOINI_REPORT!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 6A FULL TEST FOUNDATION: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage6A_Full_Test_Foundation_Results.txt and
    echo Full_Test_Report.log.
    goto FINISH_FAIL
)

echo STAGE 6A FULL TEST FOUNDATION: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide Stage6A_Full_Test_Foundation_Results.txt and
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
    findstr /i /l /c:"%~2" "%~3" >nul 2>&1
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
echo STAGE 6A FULL TEST FOUNDATION: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
