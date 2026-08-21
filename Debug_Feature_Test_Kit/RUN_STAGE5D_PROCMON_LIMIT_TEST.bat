@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "PROCMON_SOURCE=D:\SyMenu\ProgramFiles\SPSSuite\SyMenuSuite\Process_Monitor_sps\Procmon64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage5D_ProcMon_Limit_Test"
set "TEST_EXE=%TEST_ROOT%\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage5D_ProcMon_Limit_Test.ini"
set "ROOT=%TEST_ROOT%\Root"
set "PROCMON_DIR=%ROOT%\Lib\Tools\ProcessMonitor"
set "PROCMON=%PROCMON_DIR%\Procmon64.exe"
set "PROCMON_BEFORE=%TEST_ROOT%\Procmon64.before.exe"
set "RESULTS=%KIT_ROOT%Stage5D_ProcMon_Limit_Test_Results.txt"
set "SESSION="
set "SUMMARY="
set "DEBUG_LOG="
set "SETTINGS_LOG="
set "PML="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 5D Process Monitor Limit Test

echo ============================================================
echo X-LAUNCHER STAGE 5D - PROCESS MONITOR LIMIT TEST
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
    goto EARLY_FAIL
)

call :PROCMON_RUNNING
if not errorlevel 1 (
    echo ERROR: A Process Monitor instance is already running.
    echo Close it, then run this test again.
    goto EARLY_FAIL
)

if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
if exist "%TEST_ROOT%" (
    echo ERROR: The previous Stage 5D test folder could not be removed:
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
copy /y "%PROCMON_SOURCE%" "%PROCMON%" >nul 2>&1
copy /y "%PROCMON_SOURCE%" "%PROCMON_BEFORE%" >nul 2>&1
if not exist "%TEST_EXE%" goto COPY_FAIL
if not exist "%PROCMON%" goto COPY_FAIL
if not exist "%PROCMON_BEFORE%" goto COPY_FAIL

>"%ROOT%\Before.bat" echo @echo off
>>"%ROOT%\Before.bat" echo ^>"%%~dp0RunBefore_PASS.txt" echo RUNBEFORE_RAN
>>"%ROOT%\Before.bat" echo exit /b 0

>"%ROOT%\After.bat" echo @echo off
>>"%ROOT%\After.bat" echo if not exist "%%~dp0Payload_PASS.txt" exit /b 21
>>"%ROOT%\After.bat" echo ^>"%%~dp0RunAfter_PASS.txt" echo RUNAFTER_RAN
>>"%ROOT%\After.bat" echo exit /b 0

>"%ROOT%\Payload.bat" echo @echo off
>>"%ROOT%\Payload.bat" echo if not exist "%%~dp0RunBefore_PASS.txt" exit /b 11
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0PayloadStarted.txt" echo PAYLOAD_STARTED
>>"%ROOT%\Payload.bat" echo "%%SystemRoot%%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $p=Join-Path $env:TEMP 'XLauncherStage5D.tmp'; $end=(Get-Date).AddSeconds(180); do { for($i=0; $i -lt 200; $i++){ [IO.File]::WriteAllText($p,[guid]::NewGuid().ToString()); [void][IO.File]::ReadAllText($p) } } while ((Get-Date) -lt $end -and (Get-Process -Name Procmon64 -ErrorAction SilentlyContinue)); Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; exit 0 } catch { exit 1 }"
>>"%ROOT%\Payload.bat" echo if errorlevel 1 exit /b 12
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0Payload_PASS.txt" echo PAYLOAD_COMPLETED
>>"%ROOT%\Payload.bat" echo exit /b 0

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage5DProcMonLimitTest
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
    echo ProcMonMaxMB=64
    echo ProcMonReserveMB=256
    echo.
    echo [RunBefore]
    echo RunFile=.\Before.bat
    echo.
    echo [RunAfter]
    echo RunFile=.\After.bat
)

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 5D PROCESS MONITOR LIMIT TEST RESULTS
    echo ===================================================
    echo.
    echo Maximum PML: 64 MB
    echo Reserved free space: 256 MB
    echo.
)

echo This test deliberately generates enough activity to reach a 64 MB
echo PML safety limit while the disposable payload is still running.
echo.
echo Click Yes at the Application Trace confirmation.
echo Approve the UAC prompt when Process Monitor starts.
echo A second UAC prompt should appear when the size limit stops capture.
echo Approve it promptly. The payload will then continue to completion.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=trace
set "LAUNCH_RC=!ERRORLEVEL!"

for /f "delims=" %%D in ('dir /b /ad /o-d "%TEST_ROOT%\Diagnostics\Stage5DProcMonLimitTest" 2^>nul') do if not defined SESSION set "SESSION=%TEST_ROOT%\Diagnostics\Stage5DProcMonLimitTest\%%D"
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

call :CHECK_FILE "Disposable payload completed after capture stopped" "%ROOT%\Payload_PASS.txt"
call :CHECK_FILE "RunBefore completed" "%ROOT%\RunBefore_PASS.txt"
call :CHECK_FILE "RunAfter completed" "%ROOT%\RunAfter_PASS.txt"
if defined SESSION (
    call :RECORD PASS "Unique Application Trace session folder was created"
) else (
    call :RECORD FAIL "Application Trace session folder was not created"
)
call :CHECK_FILE "Application Trace summary was created" "!SUMMARY!"
call :CHECK_FILE "Enhanced debug log was created" "!DEBUG_LOG!"
call :CHECK_FILE "Settings log was created" "!SETTINGS_LOG!"
call :CHECK_MIN_SIZE "Partial PML reached the configured 64 MB limit" "!PML!" 67108864

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

call :CHECK_TEXT "Summary identifies partial native capture mode" "Mode: Application Trace with partial native Process Monitor capture" "!SUMMARY!"
call :CHECK_TEXT "Summary records the maximum-size reason" "reason=maximum PML size of 64 MB reached" "!SUMMARY!"
call :CHECK_TEXT "Summary records partial capture size and duration" "Capture result: partial; reason=" "!SUMMARY!"
call :CHECK_TEXT "Summary reports PASS WITH WARNINGS" "OVERALL: PASS WITH WARNINGS" "!SUMMARY!"
call :CHECK_TEXT "Summary reports zero X-Launcher failures" "FAIL: 0" "!SUMMARY!"
call :CHECK_TEXT "Summary records the configured safeguards" "Capture safeguards: maximum 64 MiB; reserved free space 256 MiB" "!SUMMARY!"
call :CHECK_TEXT "Debug log records safeguard stop" "[WARN] [Process Monitor] Capture safeguard stopped collection early" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records saved partial capture" "[PASS] [Process Monitor] Capture stopped and saved" "!DEBUG_LOG!"
call :CHECK_ORDER "Safeguard stopped capture before payload closed" "Capture safeguard stopped collection early" "[INFO] [Process] Application PID=" "!DEBUG_LOG!"
call :CHECK_ORDER "RunAfter occurred after partial capture stop" "[PASS] [Process Monitor] Capture stopped and saved" "[PASS] [RunAfter] RunFile=" "!DEBUG_LOG!"
call :CHECK_ORDER "Trace session ended after RunAfter" "[PASS] [RunAfter] RunFile=" "[SESSION END]" "!DEBUG_LOG!"
call :CHECK_TEXT "Settings log records partial capture mode" "Mode=Process Monitor partial capture" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records partial capture status" "ProcessMonitorCaptureStatus=partial" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records the partial reason" "ProcessMonitorPartialReason=maximum PML size of 64 MB reached" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records maximum PML size" "ProcMonMaxMB=64" "!SETTINGS_LOG!"
call :CHECK_TEXT "Settings log records reserved free space" "ProcMonReserveMB=256" "!SETTINGS_LOG!"

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined SESSION >>"%RESULTS%" echo Session: !SESSION!
if defined SUMMARY >>"%RESULTS%" echo Summary: !SUMMARY!
if defined DEBUG_LOG >>"%RESULTS%" echo Debug log: !DEBUG_LOG!
if defined PML >>"%RESULTS%" echo Partial PML: !PML!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 5D PROCESS MONITOR LIMIT TEST: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage5D_ProcMon_Limit_Test_Results.txt,
    echo Application_Trace_Summary.log and X-Launcher_Debug.dbg.
    goto FINISH_FAIL
)

echo STAGE 5D PROCESS MONITOR LIMIT TEST: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide Stage5D_ProcMon_Limit_Test_Results.txt and
echo Application_Trace_Summary.log. Keep Application_Trace.pml private.
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

:CHECK_MIN_SIZE
if "%~2"=="" (
    call :RECORD FAIL "%~1"
    exit /b 0
)
if exist "%~2" (
    for %%F in ("%~2") do if %%~zF GEQ %~3 (
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

:COPY_FAIL
echo ERROR: The launcher or Process Monitor fixture could not be copied.

:EARLY_FAIL
echo.
echo STAGE 5D PROCESS MONITOR LIMIT TEST: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
