@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage7B_Trace_Without_ProcMon"
set "TEST_EXE=%TEST_ROOT%\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage7B_Trace_Without_ProcMon.ini"
set "ROOT=%TEST_ROOT%\Root"
set "RESULTS=%KIT_ROOT%Stage7B_Trace_Without_ProcMon_Results.txt"
set "REPORT_COPY=%KIT_ROOT%Stage7B_Application_Trace_Summary.txt"
set "SESSION="
set "SUMMARY="
set "DEBUG_LOG="
set "SETTINGS_LOG="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 7B Trace Without Process Monitor

echo ============================================================
echo X-LAUNCHER STAGE 7B - TRACE WITHOUT PROCESS MONITOR
echo ============================================================
echo.

if not exist "%SOURCE_EXE%" (
    echo ERROR: X-Launcher_x64.exe was not found in:
    echo "%PROJECT_ROOT%"
    echo.
    echo Copy Test_Suite\X-Launcher_x64.exe into the main source folder first.
    goto EARLY_FAIL
)

if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
if exist "%TEST_ROOT%" (
    echo ERROR: The previous Stage 7B test folder could not be removed:
    echo "%TEST_ROOT%"
    goto EARLY_FAIL
)

if exist "%RESULTS%" del /q "%RESULTS%"
if exist "%REPORT_COPY%" del /q "%REPORT_COPY%"
mkdir "%ROOT%" >nul 2>&1
if not exist "%ROOT%" (
    echo ERROR: The disposable test folder could not be created.
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
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0Payload_PASS.txt" echo PAYLOAD_COMPLETED
>>"%ROOT%\Payload.bat" echo exit /b 0

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage7BTraceWithoutProcMon
    echo AppVer=ManualSmoke
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
    echo ProcMonPath=.\Missing\Procmon64.exe
    echo ProcMonMaxMB=512
    echo ProcMonReserveMB=1024
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
    echo X-LAUNCHER STAGE 7B TRACE WITHOUT PROCESS MONITOR RESULTS
    echo ========================================================
    echo.
)

echo Three messages will appear:
echo 1. Application Trace confirmation - click Yes.
echo 2. Process Monitor was not found - click OK to continue.
echo 3. Application Trace completed - click OK.
echo.
echo The summary may then open automatically. Close it after viewing it.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=trace TRACE_WITHOUT_PROCMON
set "LAUNCH_RC=!ERRORLEVEL!"

for /f "delims=" %%D in ('dir /b /ad /o-d "%TEST_ROOT%\Diagnostics\Stage7BTraceWithoutProcMon" 2^>nul') do if not defined SESSION set "SESSION=%TEST_ROOT%\Diagnostics\Stage7BTraceWithoutProcMon\%%D"
if defined SESSION (
    set "SUMMARY=!SESSION!\Application_Trace_Summary.txt"
    set "DEBUG_LOG=!SESSION!\X-Launcher_Debug.dbg"
    set "SETTINGS_LOG=!SESSION!\X-Launcher_Settings.log"
)

if "!LAUNCH_RC!"=="0" (
    call :RECORD PASS "Launcher process exit code"
) else (
    call :RECORD FAIL "Launcher process exit code was !LAUNCH_RC!"
)

call :CHECK_FILE "Disposable payload completed" "%ROOT%\Payload_PASS.txt"
call :CHECK_FILE "RunBefore completed before payload" "%ROOT%\RunBefore_PASS.txt"
call :CHECK_FILE "RunAfter completed after payload" "%ROOT%\RunAfter_PASS.txt"
call :CHECK_FILE "Configured Function created its file" "%ROOT%\Created\FunctionCreated.txt"

if defined SESSION (
    call :RECORD PASS "Unique Application Trace session folder was created"
) else (
    call :RECORD FAIL "Application Trace session folder was not created"
)

call :CHECK_FILE "Application Trace summary was created" "!SUMMARY!"
call :CHECK_FILE "Enhanced debug log was created" "!DEBUG_LOG!"
call :CHECK_FILE "Settings log was created" "!SETTINGS_LOG!"

if defined SESSION (
    if not exist "!SESSION!\Application_Trace.pml" (
        call :RECORD PASS "No Process Monitor PML was created"
    ) else (
        call :RECORD FAIL "A Process Monitor PML was unexpectedly created"
    )
) else (
    call :RECORD FAIL "PML absence could not be checked"
)

call :CHECK_TEXT "Summary identifies X-Launcher-only mode" "Mode: X-Launcher-only Application Trace (Process Monitor was not started)" "!SUMMARY!"
call :CHECK_TEXT "Summary records unavailable Process Monitor continuation" "Process Monitor: not available; continued with X-Launcher-only logging" "!SUMMARY!"
call :CHECK_TEXT "Summary reports zero X-Launcher failures" "FAIL: 0" "!SUMMARY!"
call :CHECK_TEXT "Summary records application exit code" "Application exit code: 0" "!SUMMARY!"
call :CHECK_TEXT "Ordinary payload argument was forwarded" "TRACE_WITHOUT_PROCMON" "%ROOT%\PayloadArguments.txt"
call :CHECK_TEXT_ABSENT "Internal diagnostic switch was not forwarded" "x-launcher-test" "%ROOT%\PayloadArguments.txt"

if defined SUMMARY if exist "!SUMMARY!" copy /y "!SUMMARY!" "%REPORT_COPY%" >nul 2>&1
call :CHECK_FILE "Summary was copied beside the results file" "%REPORT_COPY%"

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined SESSION >>"%RESULTS%" echo Session: !SESSION!
if defined SUMMARY >>"%RESULTS%" echo Summary: !SUMMARY!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 7B TRACE WITHOUT PROCESS MONITOR: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage7B_Trace_Without_ProcMon_Results.txt,
    echo Stage7B_Application_Trace_Summary.txt and the Command Prompt output.
    goto FINISH_FAIL
)

echo STAGE 7B TRACE WITHOUT PROCESS MONITOR: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide these two files from Debug_Feature_Test_Kit:
echo 1. Stage7B_Trace_Without_ProcMon_Results.txt
echo 2. Stage7B_Application_Trace_Summary.txt
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
echo STAGE 7B TRACE WITHOUT PROCESS MONITOR: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
