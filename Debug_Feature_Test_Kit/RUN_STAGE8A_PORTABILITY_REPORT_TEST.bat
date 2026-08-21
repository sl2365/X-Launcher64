@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "SOURCE_EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "PROCMON_SOURCE=D:\SyMenu\ProgramFiles\SPSSuite\SyMenuSuite\Process_Monitor_sps\Procmon64.exe"
set "TEST_ROOT=%KIT_ROOT%Stage8A_Portability_Report_Test"
set "TEST_EXE=%TEST_ROOT%\X-Launcher_x64.exe"
set "TEST_INI=%TEST_ROOT%\Stage8A_Portability_Report_Test.ini"
set "ROOT=%TEST_ROOT%\Root"
set "EXTERNAL=%TEST_ROOT%\External"
set "MANAGED_FILE=%EXTERNAL%\Managed_Settings.ini"
set "UNMANAGED_FILE=%EXTERNAL%\Unmanaged_Settings.ini"
set "PROCMON_DIR=%ROOT%\Lib\Tools\ProcessMonitor"
set "PROCMON=%PROCMON_DIR%\Procmon64.exe"
set "PROCMON_BEFORE=%TEST_ROOT%\Procmon64.before.exe"
set "RESULTS=%KIT_ROOT%Stage8A_Portability_Report_Test_Results.txt"
set "REPORT_COPY=%KIT_ROOT%Stage8A_Application_Portability_Report.log"
set "MANAGED_REG=HKCU\Software\XLauncher_Test\Stage8A_Managed"
set "UNMANAGED_REG=HKCU\Software\XLauncher_Test\Stage8A_Unmanaged"
set "SESSION="
set "SUMMARY="
set "PORTABILITY="
set "DEBUG_LOG="
set "SETTINGS_LOG="
set "PML="
set "CSV="
set "XML="
set "PMC="
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 8A Readable Portability Report Test

echo ============================================================
echo X-LAUNCHER STAGE 8A - READABLE PORTABILITY REPORT TEST
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
    echo Close it and run this test again. The test never terminates a
    echo pre-existing Process Monitor session.
    goto EARLY_FAIL
)

reg delete "%MANAGED_REG%" /f >nul 2>&1
reg delete "%UNMANAGED_REG%" /f >nul 2>&1
if exist "%TEST_ROOT%" rmdir /s /q "%TEST_ROOT%"
if exist "%RESULTS%" del /q "%RESULTS%"
if exist "%REPORT_COPY%" del /q "%REPORT_COPY%"
mkdir "%PROCMON_DIR%" >nul 2>&1
mkdir "%EXTERNAL%" >nul 2>&1
if not exist "%PROCMON_DIR%" goto EARLY_FAIL

copy /y "%SOURCE_EXE%" "%TEST_EXE%" >nul 2>&1
copy /y "%PROCMON_SOURCE%" "%PROCMON%" >nul 2>&1
copy /y "%PROCMON_SOURCE%" "%PROCMON_BEFORE%" >nul 2>&1
if not exist "%TEST_EXE%" goto EARLY_FAIL
if not exist "%PROCMON%" goto EARLY_FAIL

>"%ROOT%\Portable.reg" echo Windows Registry Editor Version 5.00
>>"%ROOT%\Portable.reg" echo.
>>"%ROOT%\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Stage8A_Managed]
>>"%ROOT%\Portable.reg" echo "Baseline"="portable"

>"%ROOT%\Payload.bat" echo @echo off
>>"%ROOT%\Payload.bat" echo setlocal EnableExtensions
>>"%ROOT%\Payload.bat" echo if not exist "%%~dp0RunBefore_PASS.txt" exit /b 11
>>"%ROOT%\Payload.bat" echo if not exist "%%~dp0Data" mkdir "%%~dp0Data"
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0Data\Contained_Settings.ini" echo contained=true
>>"%ROOT%\Payload.bat" echo ^>"%MANAGED_FILE%" echo managed=true
>>"%ROOT%\Payload.bat" echo ^>"%UNMANAGED_FILE%" echo unmanaged=true
>>"%ROOT%\Payload.bat" echo reg add "%MANAGED_REG%" /v PayloadSetting /t REG_SZ /d managed /f ^>nul 2^>^&1
>>"%ROOT%\Payload.bat" echo reg add "%UNMANAGED_REG%" /v PayloadSetting /t REG_SZ /d unmanaged /f ^>nul 2^>^&1
>>"%ROOT%\Payload.bat" echo ^>"%%~dp0Payload_PASS.txt" echo PAYLOAD_COMPLETED
>>"%ROOT%\Payload.bat" echo exit /b 0

>"%ROOT%\Before.bat" echo @echo off
>>"%ROOT%\Before.bat" echo ^>"%%~dp0RunBefore_PASS.txt" echo RUNBEFORE_RAN
>>"%ROOT%\Before.bat" echo exit /b 0

>"%TEST_INI%" (
    echo [Setup]
    echo AppName=Stage8APortabilityReportTest
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
    echo [Functions]
    echo DirCreate=.\Data
    echo FileCreate=.\Launcher_Function_Action.txt
    echo.
    echo [RunBefore]
    echo Regedit=.\Portable.reg
    echo RunFile=.\Before.bat
    echo.
    echo [RunAfter]
    echo FileMove=%MANAGED_FILE%^|.\Managed_Captured.ini^|o
)

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 8A READABLE PORTABILITY REPORT TEST RESULTS
    echo ===========================================================
    echo.
    echo External Process Monitor source:
    echo %PROCMON_SOURCE%
)

echo An Application Trace confirmation will appear. Click Yes.
echo Windows may request elevation while Process Monitor starts, stops,
echo and exports the captured PML for analysis. Approve those prompts.
echo Process Monitor may show its licence/EULA on first use; X-Launcher
echo does not accept it automatically.
echo.
echo Use the disposable payload normally if a window appears. When the
echo completion message appears, click OK, then close any opened report.
echo.
"%TEST_EXE%" "--x-launcher-config=%TEST_INI%" --x-launcher-test=trace STAGE8A_TRACE
set "LAUNCH_RC=!ERRORLEVEL!"

for /f "delims=" %%D in ('dir /b /ad /o-d "%TEST_ROOT%\Diagnostics\Stage8APortabilityReportTest" 2^>nul') do if not defined SESSION set "SESSION=%TEST_ROOT%\Diagnostics\Stage8APortabilityReportTest\%%D"
if defined SESSION (
    set "SUMMARY=!SESSION!\Application_Trace_Summary.log"
    set "PORTABILITY=!SESSION!\Application_Portability_Report.log"
    set "DEBUG_LOG=!SESSION!\X-Launcher_Debug.dbg"
    set "SETTINGS_LOG=!SESSION!\X-Launcher_Settings.log"
    set "PML=!SESSION!\Application_Trace.pml"
    set "CSV=!SESSION!\Application_Trace.csv"
    set "XML=!SESSION!\Application_Trace.xml"
    set "PMC=!SESSION!\Application_Trace_Filter.pmc"
)

if "!LAUNCH_RC!"=="0" (
    call :RECORD PASS "Launcher process exit code"
) else (
    call :RECORD FAIL "Launcher process exit code was !LAUNCH_RC!"
)
call :CHECK_FILE "Disposable payload completed" "%ROOT%\Payload_PASS.txt"
call :CHECK_FILE "Readable portability report was created" "!PORTABILITY!"
call :CHECK_NONEMPTY_FILE "Native PML remains preserved" "!PML!"
call :CHECK_TEXT "Report analysis completed" "ANALYSIS STATUS: COMPLETE" "!PORTABILITY!"
call :CHECK_TEXT "Automatic write-focused capture filter is stated" "Capture Filter: automatic write-focused" "!PORTABILITY!"
call :CHECK_TEXT "Contained application write is visible" "Contained_Settings.ini" "!PORTABILITY!"
call :CHECK_TEXT "Managed external file is visible" "Managed_Settings.ini" "!PORTABILITY!"
call :CHECK_TEXT "Managed file cites the current INI rule" "[RunAfter] FileMove source" "!PORTABILITY!"
call :CHECK_TEXT "Unmanaged external file is visible" "Unmanaged_Settings.ini" "!PORTABILITY!"
call :CHECK_TEXT "Managed registry root is visible" "HKCU\SOFTWARE\XLAUNCHER_TEST\STAGE8A_MANAGED" "!PORTABILITY!"
call :CHECK_TEXT "Unmanaged registry root is visible" "HKCU\Software\XLauncher_Test\Stage8A_Unmanaged" "!PORTABILITY!"
call :CHECK_TEXT "Unmanaged entries contain practical review guidance" "add an appropriate INI rule" "!PORTABILITY!"
call :CHECK_TEXT "X-Launcher actions are separated" "X-LAUNCHER ACTIONS" "!PORTABILITY!"
call :CHECK_TEXT "Processes and command lines are included" "ATTRIBUTED PROCESSES AND COMMAND LINES" "!PORTABILITY!"
call :CHECK_TEXT "After-exit file presence is stated" "PRESENT AFTER EXIT" "!PORTABILITY!"
call :CHECK_TEXT "Limitations are stated" "LIMITATIONS" "!PORTABILITY!"
call :CHECK_TEXT "Privacy warning is stated" "Privacy:" "!PORTABILITY!"
call :CHECK_TEXT "Debug log records readable report completion" "[Portability] Readable portability report created" "!DEBUG_LOG!"
call :CHECK_TEXT "Settings log records completed analysis" "PortabilityAnalysis=complete; readable application-write report created" "!SETTINGS_LOG!"
call :CHECK_TEXT "Debug log records automatic write-focused filtering" "Automatic write-focused filter created" "!DEBUG_LOG!"
call :CHECK_TEXT "Settings log records the temporary ProcMon filter" "ProcessMonitorFilter=" "!SETTINGS_LOG!"
call :CHECK_TEXT "Debug log records timed XML export completion" "XML export completed (seconds=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records timed XML conversion completion" "XML conversion completed (seconds=" "!DEBUG_LOG!"
call :CHECK_TEXT "Debug log records timed indexed classification completion" "Target classification completed (seconds=" "!DEBUG_LOG!"
call :CHECK_TEXT "Settings log records total portability processing time" "PortabilityTotalSeconds=" "!SETTINGS_LOG!"

if defined CSV (
    if not exist "!CSV!" (
        call :RECORD PASS "Intermediate CSV was removed after successful analysis"
    ) else (
        call :RECORD FAIL "Intermediate CSV was not removed after successful analysis"
    )
) else (
    call :RECORD FAIL "Intermediate CSV path was unavailable"
)
if defined XML (
    if not exist "!XML!" (
        call :RECORD PASS "Intermediate XML was removed after successful analysis"
    ) else (
        call :RECORD FAIL "Intermediate XML was not removed after successful analysis"
    )
) else (
    call :RECORD FAIL "Intermediate XML path was unavailable"
)
if defined PMC (
    if not exist "!PMC!" (
        call :RECORD PASS "Temporary ProcMon filter was removed after successful analysis"
    ) else (
        call :RECORD FAIL "Temporary ProcMon filter was not removed after successful analysis"
    )
) else (
    call :RECORD FAIL "Temporary ProcMon filter path was unavailable"
)

fc /b "%PROCMON_SOURCE%" "%PROCMON_BEFORE%" >nul 2>&1
if not errorlevel 1 (
    call :RECORD PASS "Original Process Monitor remained unchanged"
) else (
    call :RECORD FAIL "Original Process Monitor was changed"
)
call :PROCMON_RUNNING
if errorlevel 1 (
    call :RECORD PASS "No Process Monitor instance remained running"
) else (
    call :RECORD FAIL "A Process Monitor instance remained running"
)

if defined PORTABILITY if exist "!PORTABILITY!" copy /y "!PORTABILITY!" "%REPORT_COPY%" >nul 2>&1
call :CHECK_FILE "Readable report was copied beside the results file" "%REPORT_COPY%"

reg delete "%MANAGED_REG%" /f >nul 2>&1
reg delete "%UNMANAGED_REG%" /f >nul 2>&1

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!
if defined SESSION >>"%RESULTS%" echo Session: !SESSION!
if defined PORTABILITY >>"%RESULTS%" echo Readable report: !PORTABILITY!
if defined PML >>"%RESULTS%" echo Native PML: !PML!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo STAGE 8A READABLE PORTABILITY REPORT TEST: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Stage8A_Portability_Report_Test_Results.txt,
    echo Stage8A_Application_Portability_Report.log and Command Prompt output.
    goto FINISH_FAIL
)

echo STAGE 8A READABLE PORTABILITY REPORT TEST: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide these two files from Debug_Feature_Test_Kit:
echo 1. Stage8A_Portability_Report_Test_Results.txt
echo 2. Stage8A_Application_Portability_Report.log
echo Keep Application_Trace.pml private unless detailed troubleshooting is needed.
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
if exist "%~2" for %%F in ("%~2") do if %%~zF GTR 0 (
    call :RECORD PASS "%~1"
    exit /b 0
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
reg delete "%MANAGED_REG%" /f >nul 2>&1
reg delete "%UNMANAGED_REG%" /f >nul 2>&1
echo.
echo STAGE 8A READABLE PORTABILITY REPORT TEST: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
