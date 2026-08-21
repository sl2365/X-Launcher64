@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "PROCMON_SOURCE=D:\SyMenu\ProgramFiles\SPSSuite\SyMenuSuite\Process_Monitor_sps\Procmon64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage5C_ProcMon_Capture_Test"
set "TEST_EXE=%TEST_ROOT%\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage5C_ProcMon_Capture_Test.ini"
set "ROOT=%TEST_ROOT%\Root"
set "PROCMON_DIR=%ROOT%\Lib\Tools\ProcessMonitor"
set "PROCMON=%PROCMON_DIR%\Procmon64.exe"
set "PROCMON_BEFORE=%TEST_ROOT%\Procmon64.before.exe"
set "RESULTS=%KIT_ROOT%Stage5C_ProcMon_Capture_Test_Results.txt"
set "SESSION="
set "SUMMARY="
set "DEBUG_LOG="
set "SETTINGS_LOG="
set "PML="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 5C Process Monitor Capture Test

echo ============================================================
echo X-LAUNCHER STAGE 5C - PROCESS MONITOR CAPTURE TEST
echo ============================================================
echo.

if not exist "%SOURCE_EXE%" (
    echo ERROR: X-Launcher_x64.exe was not found in:
    echo "%PROJECT_ROOT%"
    echo.
    echo Double-click BUILD.bat before running this test.
    goto EARLY_FAIL
)

if not exist "%PROCMON_SOURCE%" (
    echo ERROR: The genuine SyMenu Process Monitor executable was not found:
    echo "%PROCMON_SOURCE%"
    echo.
    echo This focused test does not download Process Monitor.
    goto EARLY_FAIL
)

call :PROCMON_RUNNING
if not errorlevel 1 (
    echo ERROR: A Process Monitor instance is already running.
    echo.
    echo Close Procmon.exe, Procmon64.exe and Procmon64a.exe, then run
    echo this test again. The test will never terminate a pre-existing session.
    goto EARLY_FAIL
)

if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
if exist "%TEST_ROOT%" (
    echo ERROR: The previous Stage 5C test folder could not be removed:
    echo "%TEST_ROOT%"
    goto EARLY_FAIL
)

if exist "%RESULTS%" del /q "%RESULTS%"
mkdir "%PROCMON_DIR%" >nul 2>&1
if not exist "%PROCMON_DIR%" (
    echo ERROR: The isolated test folders could not be created.
    goto EARLY_FAIL
)

copy /y "%SOURCE_EXE%" "%TEST_EXE%" >nul 2>&1
if not exist "%TEST_EXE%" (
    echo ERROR: The compiled launcher could not be copied into the test folder.
    goto EARLY_FAIL
)

copy /y "%PROCMON_SOURCE%" "%PROCMON%" >nul 2>&1
copy /y "%PROCMON_SOURCE%" "%PROCMON_BEFORE%" >nul 2>&1
if not exist "%PROCMON%" (
    echo ERROR: Process Monitor could not be copied into the isolated fixture.
    goto EARLY_FAIL
)
if not exist "%PROCMON_BEFORE%" (
    echo ERROR: The Process Monitor comparison copy could not be created.
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

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage5CProcMonCaptureTest
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
    echo ProcMonMaxMB=2048
    echo ProcMonReserveMB=1024
    echo.
    echo [Environment]
    echo STAGE5C_TRACE=ready^|=
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
    echo X-LAUNCHER STAGE 5C PROCESS MONITOR CAPTURE TEST RESULTS
    echo ======================================================
    echo.
    echo External Process Monitor source:
    echo %PROCMON_SOURCE%
    echo Test INI ProcMonPath: $Lib$\Tools\ProcessMonitor
    echo.
)

echo An Application Trace confirmation will appear.
echo Click Yes to run the disposable payload and native PML capture.
echo.
echo Windows may ask permission when Process Monitor starts and stops.
echo Process Monitor may also show its own licence/EULA on first use.
echo Approve those prompts to test capture. X-Launcher does not accept
echo the EULA automatically.
echo.
echo When the completion message appears, click OK.
echo The generated summary report may then open automatically.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=trace TRACE_PAYLOAD_ARGUMENT
set "LAUNCH_RC=!ERRORLEVEL!"

for /f "delims=" %%D in ('dir /b /ad /o-d "%TEST_ROOT%\Diagnostics\Stage5CProcMonCaptureTest" 2^>nul') do if not defined SESSION set "SESSION=%TEST_ROOT%\Diagnostics\Stage5CProcMonCaptureTest\%%D"
if defined SESSION (
    set "SUMMARY=!SESSION!\Application_Trace_Summary.log"
    set "DEBUG_LOG=!SESSION!\X-Launcher_Debug.dbg"
    set "SETTINGS_LOG=!SESSION!\X-Launcher_Settings.log"
    set "PML=!SESSION!\Application_Trace.pml"
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
call :CHECK_NONEMPTY_FILE "Native Application_Trace.pml was created and is non-empty" "!PML!"

fc /b "%PROCMON_SOURCE%" "%PROCMON_BEFORE%" >nul 2>&1
if not errorlevel 1 (
    call :RECORD PASS "Original SyMenu Process Monitor remained unchanged"
) else (
    call :RECORD FAIL "Original SyMenu Process Monitor was changed"
)

fc /b "%PROCMON%" "%PROCMON_BEFORE%" >nul 2>&1
if not errorlevel 1 (
    call :RECORD PASS "Isolated Process Monitor fixture remained unchanged"
) else (
    call :RECORD FAIL "Isolated Process Monitor fixture was changed"
)

call :PROCMON_RUNNING
if errorlevel 1 (
    call :RECORD PASS "No Process Monitor instance remained running"
) else (
    call :RECORD FAIL "A Process Monitor instance remained running"
)

call :CHECK_TEXT "Summary identifies native Process Monitor capture mode" "Mode=Application Trace with native Process Monitor capture" "!SUMMARY!"
call :CHECK_TEXT "Summary reports the saved native PML" "Process Monitor=capture saved; automatic write-focused drop filter; native PML=" "!SUMMARY!"
call :CHECK_TEXT "Summary names the native capture file" "Native Process Monitor capture=" "!SUMMARY!"
call :CHECK_TEXT "Summary reports configured capture safeguards" "Capture safeguards=maximum 2048 MiB; reserved free space 1024 MiB" "!SUMMARY!"
call :CHECK_TEXT "Summary reports a complete capture with size and duration" "Capture result=complete; size=" "!SUMMARY!"
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

call :CHECK_TEXT "Debug log records Process Monitor capture start" "[PASS] [Process Monitor] Capture started" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records Process Monitor capture stop" "[PASS] [Process Monitor] Capture stopped and saved" "!DEBUG_LOG!"
call :CHECK_TEXT "Complete lifecycle waiting was enforced" "RunWait forced true:" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records application PID" "[PASS] [Process] Application launch PID=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records the disposable child process" "name=ping.exe" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records RunBefore success" "[PASS] [RunBefore] RunFile=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records RunAfter success" "[PASS] [RunAfter] RunFile=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records Function success" "[PASS] [Functions] FileCreate=" "!DEBUG_LOG!"
call :CHECK_ORDER "Capture started before configured operations" "[PASS] [Process Monitor] Capture started" "[PASS] [Functions] FileCreate=" "!DEBUG_LOG!"
call :CHECK_ORDER "Capture stopped after RunAfter cleanup" "[PASS] [RunAfter] RunFile=" "[PASS] [Process Monitor] Capture stopped and saved" "!DEBUG_LOG!"
call :CHECK_ORDER "Trace session ended after Process Monitor stopped" "[PASS] [Process Monitor] Capture stopped and saved" "[SESSION END]" "!DEBUG_LOG!"

call :CHECK_TEXT "Settings log records Process Monitor capture mode" "Mode=Process Monitor capture" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records saved native PML state" "ProcessMonitor=capture saved; native PML=" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records Application_Trace.pml path" "Application_Trace.pml" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records complete capture status" "ProcessMonitorCaptureStatus=complete" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records maximum PML size" "ProcMonMaxMB=2048" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records reserved free space" "ProcMonReserveMB=1024" "!SETTINGS_LOG!"

call :CHECK_TEXT "Ordinary payload argument was forwarded" "TRACE_PAYLOAD_ARGUMENT" "%ROOT%\PayloadArguments.txt"
call :CHECK_TEXT_ABSENT "Internal diagnostic switch was not forwarded" "x-launcher-test" "%ROOT%\PayloadArguments.txt"

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined SESSION >>"%RESULTS%" echo Session: !SESSION!
if defined SUMMARY >>"%RESULTS%" echo Summary: !SUMMARY!
if defined DEBUG_LOG >>"%RESULTS%" echo Debug log: !DEBUG_LOG!
if defined PML >>"%RESULTS%" echo Native PML: !PML!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 5C PROCESS MONITOR CAPTURE TEST: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage5C_ProcMon_Capture_Test_Results.txt,
    echo Application_Trace_Summary.log and X-Launcher_Debug.dbg.
    goto FINISH_FAIL
)

echo STAGE 5C PROCESS MONITOR CAPTURE TEST: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo All generated test files are inside Debug_Feature_Test_Kit.
echo Please provide Stage5C_ProcMon_Capture_Test_Results.txt and
echo Application_Trace_Summary.log. Keep Application_Trace.pml private for now.
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

:CHECK_NONEMPTY_FILE
if "%~2"=="" (
    call :RECORD FAIL "%~1"
    exit /b 0
)
if exist "%~2" (
    for %%F in ("%~2") do if %%~zF GTR 0 (
        call :RECORD PASS "%~1"
        exit /b 0
    )
)
call :RECORD FAIL "%~1"
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

:CHECK_ORDER
set "ORDER_FIRST="
set "ORDER_SECOND="
if not "%~4"=="" if exist "%~4" (
    for /f "tokens=1 delims=:" %%L in ('findstr /n /i /l /c:"%~2" "%~4" 2^>nul') do if not defined ORDER_FIRST set "ORDER_FIRST=%%L"
    for /f "tokens=1 delims=:" %%L in ('findstr /n /i /l /c:"%~3" "%~4" 2^>nul') do if not defined ORDER_SECOND set "ORDER_SECOND=%%L"
)
if defined ORDER_FIRST if defined ORDER_SECOND if !ORDER_FIRST! LSS !ORDER_SECOND! (
    call :RECORD PASS "%~1"
    exit /b 0
)
call :RECORD FAIL "%~1"
exit /b 0

:PROCMON_RUNNING
tasklist /fi "IMAGENAME eq Procmon.exe" /nh 2>nul | find /i "Procmon.exe" >nul
if not errorlevel 1 exit /b 0
tasklist /fi "IMAGENAME eq Procmon64.exe" /nh 2>nul | find /i "Procmon64.exe" >nul
if not errorlevel 1 exit /b 0
tasklist /fi "IMAGENAME eq Procmon64a.exe" /nh 2>nul | find /i "Procmon64a.exe" >nul
if not errorlevel 1 exit /b 0
exit /b 1

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
echo STAGE 5C PROCESS MONITOR CAPTURE TEST: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
