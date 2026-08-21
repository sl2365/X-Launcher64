@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage5B_Application_Trace_Test"
set "TEST_EXE=%TEST_ROOT%\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage5B_Application_Trace_Test.ini"
set "ROOT=%TEST_ROOT%\Root"
set "PROCMON_DIR=%ROOT%\Lib\Tools\ProcessMonitor"
set "PROCMON=%PROCMON_DIR%\Procmon64.exe"
set "PROCMON_BEFORE=%PROCMON_DIR%\Procmon64.before.exe"
set "RESULTS=%KIT_ROOT%Stage5B_Application_Trace_Test_Results.txt"
set "SESSION="
set "SUMMARY="
set "DEBUG_LOG="
set "SETTINGS_LOG="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 5B Application Trace Test

echo ============================================================
echo X-LAUNCHER STAGE 5B - APPLICATION TRACE FOCUSED TEST
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
    echo ERROR: The previous Stage 5B test folder could not be removed:
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

>"%ROOT%\Before.bat" echo @echo off
>>"%ROOT%\Before.bat" echo ^>"%%~dp0RunBefore_PASS.txt" echo RUNBEFORE_RAN
>>"%ROOT%\Before.bat" echo exit /b 0

>"%ROOT%\After.bat" echo @echo off
>>"%ROOT%\After.bat" echo if not exist "%%~dp0Payload_PASS.txt" exit /b 21
>>"%ROOT%\After.bat" echo ^>"%%~dp0RunAfter_PASS.txt" echo RUNAFTER_RAN
>>"%ROOT%\After.bat" echo exit /b 0

>"%ROOT%\Payload.bat" echo @echo off
>>"%ROOT%\Payload.bat" echo if not exist "%%~dp0RunBefore_PASS.txt" exit /b 11
>>"%ROOT%\Payload.bat" echo if not exist "%%~dp0Created\FunctionCreated.txt" exit /b 12
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0PayloadArguments.txt" echo %%*
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0PayloadStarted.txt" echo PAYLOAD_STARTED
>>"%ROOT%\Payload.bat" echo "%%SystemRoot%%\System32\ping.exe" 127.0.0.1 -n 6 ^>nul
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0Payload_PASS.txt" echo PAYLOAD_COMPLETED
>>"%ROOT%\Payload.bat" echo exit /b 0

>"%PROCMON%" echo DISPOSABLE_STAGE5B_PROCMON_FIXTURE
copy /y "%PROCMON%" "%PROCMON_BEFORE%" >nul 2>&1

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage5BApplicationTraceTest
    echo AppVer=FocusedTest
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
    echo RunWait=false
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
    echo.
    echo [Environment]
    echo STAGE5B_TRACE=ready^|=
    echo.
    echo [Functions]
    echo DirCreate=.\Created
    echo FileCreate=.\Created\FunctionCreated.txt
    echo.
    echo [RunBefore]
    echo RunFile=.\Before.bat
    echo.
    echo [RunAfter]
    echo RunFile=.\After.bat
)

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 5B APPLICATION TRACE TEST RESULTS
    echo =================================================
    echo.
)

echo An Application Trace confirmation will appear.
echo Click Yes to run the disposable real payload and configured operations.
echo.
echo When the completion message appears, click OK.
echo The generated summary report may then open automatically.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=trace TRACE_PAYLOAD_ARGUMENT
set "LAUNCH_RC=!ERRORLEVEL!"

for /f "delims=" %%D in ('dir /b /ad /o-d "%TEST_ROOT%\Diagnostics\Stage5BApplicationTraceTest" 2^>nul') do if not defined SESSION set "SESSION=%TEST_ROOT%\Diagnostics\Stage5BApplicationTraceTest\%%D"
if defined SESSION (
    set "SUMMARY=!SESSION!\Application_Trace_Summary.log"
    set "DEBUG_LOG=!SESSION!\X-Launcher_Debug.dbg"
    set "SETTINGS_LOG=!SESSION!\X-Launcher_Settings.log"
)

if "!LAUNCH_RC!"=="0" (
    call :RECORD PASS "Launcher process exit code"
) else (
    call :RECORD FAIL "Launcher process exit code was !LAUNCH_RC!"
)

call :CHECK_FILE "Disposable payload completed normally" "%ROOT%\Payload_PASS.txt"
call :CHECK_FILE "RunBefore completed before payload" "%ROOT%\RunBefore_PASS.txt"
call :CHECK_FILE "RunAfter completed after payload" "%ROOT%\RunAfter_PASS.txt"
call :CHECK_FILE "Configured Function created its file" "%ROOT%\Created\FunctionCreated.txt"

if defined SESSION (
    call :RECORD PASS "Unique Application Trace session folder was created"
) else (
    call :RECORD FAIL "Application Trace session folder was not created"
)

call :CHECK_FILE "Application Trace summary was created" "!SUMMARY!"
call :CHECK_FILE "Enhanced debug log was created in the session folder" "!DEBUG_LOG!"
call :CHECK_FILE "Settings log was created in the session folder" "!SETTINGS_LOG!"

fc /b "%PROCMON%" "%PROCMON_BEFORE%" >nul 2>&1
if not errorlevel 1 (
    call :RECORD PASS "Process Monitor fixture remained unchanged"
) else (
    call :RECORD FAIL "Process Monitor fixture was changed"
)

call :CHECK_TEXT "Summary identifies X-Launcher-only mode" "Mode=X-Launcher-only Application Trace (Process Monitor was not started)" "!SUMMARY!"
call :CHECK_TEXT "Summary reports resolved but unstarted Process Monitor" "Process Monitor=available; resolved but not started in this stage" "!SUMMARY!"
call :CHECK_TEXT "Summary contains file and directory section" "FILE AND DIRECTORY OPERATIONS (X-LAUNCHER-RECORDED)" "!SUMMARY!"
call :CHECK_TEXT "Summary contains registry section" "REGISTRY OPERATIONS (X-LAUNCHER-RECORDED)" "!SUMMARY!"
call :CHECK_TEXT "Summary contains process section" "PROCESS ACTIVITY" "!SUMMARY!"
call :CHECK_TEXT "Summary contains error section" "ERRORS AND WARNINGS" "!SUMMARY!"
call :CHECK_TEXT "Summary separates Root boundary and residue" "ROOT BOUNDARY AND RESIDUE" "!SUMMARY!"
call :CHECK_TEXT "Summary contains privacy warning" "Privacy=Review usernames, paths, command lines and document names before sharing." "!SUMMARY!"
call :CHECK_TEXT "Summary contains ordered diagnostic detail" "ORDERED DIAGNOSTIC DETAIL" "!SUMMARY!"
call :CHECK_TEXT "Summary reports zero X-Launcher failures" "FAIL=0" "!SUMMARY!"
call :CHECK_TEXT "Summary reports zero X-Launcher warnings" "WARN=0" "!SUMMARY!"
call :CHECK_TEXT "Summary records launcher PID" "Launcher PID=" "!SUMMARY!"
call :CHECK_TEXT "Summary records application PID" "Application launch PID=" "!SUMMARY!"
call :CHECK_TEXT "Summary records application exit code" "Application exit code=0" "!SUMMARY!"
call :CHECK_TEXT "Summary observed the disposable child process" "Name= ping.exe" "!SUMMARY!"

call :CHECK_TEXT "Complete lifecycle waiting was enforced" "RunWait forced true:" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records application PID" "[PASS] [Process] Application launch PID=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records the disposable child process" "name=ping.exe" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records RunBefore success" "[PASS] [RunBefore] RunFile=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records RunAfter success" "[PASS] [RunAfter] RunFile=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records Function success" "[PASS] [Functions] FileCreate=" "!DEBUG_LOG!"

call :CHECK_TEXT "Ordinary payload argument was forwarded" "TRACE_PAYLOAD_ARGUMENT" "%ROOT%\PayloadArguments.txt"
call :CHECK_TEXT_ABSENT "Internal diagnostic switch was not forwarded" "x-launcher-test" "%ROOT%\PayloadArguments.txt"

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined SESSION >>"%RESULTS%" echo Session: !SESSION!
if defined SUMMARY >>"%RESULTS%" echo Summary: !SUMMARY!
if defined DEBUG_LOG >>"%RESULTS%" echo Debug log: !DEBUG_LOG!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 5B APPLICATION TRACE TEST: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage5B_Application_Trace_Test_Results.txt,
    echo Application_Trace_Summary.log and X-Launcher_Debug.dbg.
    goto FINISH_FAIL
)

echo STAGE 5B APPLICATION TRACE TEST: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo All test files are inside Debug_Feature_Test_Kit.
echo Please provide Stage5B_Application_Trace_Test_Results.txt and
echo Application_Trace_Summary.log.
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

:CHECK_TEXT_ABSENT
if "%~3"=="" (
    call :RECORD FAIL "%~1"
    exit /b 0
)
if exist "%~3" (
    findstr /i /l /c:"%~2" "%~3" >nul 2>&1
    if errorlevel 1 (
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
echo STAGE 5B APPLICATION TRACE TEST: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
