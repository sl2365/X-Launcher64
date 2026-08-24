@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title X-Launcher Regression Test Suite

set "LAUNCHER=%CD%\X-Launcher_x64.exe"
set "RESULTS=%CD%\Results.log"
set /a PASSCOUNT=0
set /a FAILCOUNT=0
set /a TOTAL=0

if not exist "%LAUNCHER%" (
    echo FAIL - X-Launcher_x64.exe is not in Test_Suite.
    if /I not "%~1"=="/nopause" pause
    exit /b 1
)

if exist "Working" rmdir /s /q "Working"
mkdir "Working\Test01\Temp"
mkdir "Working\Test02\Temp"
mkdir "Working\Test03A\Temp"
mkdir "Working\Test03B\Temp"

> "%RESULTS%" echo X-LAUNCHER REGRESSION TEST RESULTS
>>"%RESULTS%" echo ==================================
>>"%RESULTS%" echo.

echo Running Test 01 - Exit Handler...
set /a TOTAL+=1
> "Working\Test01\Temp\01_Exit_Handler.log" echo [Status]
>>"Working\Test01\Temp\01_Exit_Handler.log" echo IsRunning=true
>>"Working\Test01\Temp\01_Exit_Handler.log" echo IsClosing=true
start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\01_Exit_Handler.ini" >nul 2>&1
findstr /i /x /c:"IsClosing=false" "Working\Test01\Temp\01_Exit_Handler.log" >nul 2>&1
if errorlevel 1 (
    set "T1=FAIL"
    set /a FAILCOUNT+=1
) else (
    set "T1=PASS"
    set /a PASSCOUNT+=1
)

echo Running Test 02 - Launch Failure Detection...
set /a TOTAL+=1
mkdir "Working\Test02\CannotRun.exe" >nul 2>&1
start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\02_Launch_Failure.ini" >nul 2>&1
set "T2EXIT=!ERRORLEVEL!"
if "!T2EXIT!"=="5" (
    set "T2=PASS"
    set /a PASSCOUNT+=1
) else (
    set "T2=FAIL"
    set /a FAILCOUNT+=1
)

echo Running Test 03A - Ignore Unrelated Same-Name Process...
set /a TOTAL+=1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test03A\PID_Test_App.exe" >nul
start "" /b "Working\Test03A\PID_Test_App.exe" 127.0.0.1 -n 12 -w 1000 >nul 2>&1
ping 127.0.0.1 -n 2 >nul

start "" "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\03A_Unrelated_Process.ini" >nul 2>&1
ping 127.0.0.1 -n 5 >nul

findstr /i /x /c:"IsRunning=false" "Working\Test03A\Temp\03A_Unrelated_Process.log" >nul 2>&1
if errorlevel 1 (
    set "T3A=FAIL"
    set /a FAILCOUNT+=1
) else (
    set "T3A=PASS"
    set /a PASSCOUNT+=1
)

taskkill /f /im PID_Test_App.exe >nul 2>&1
ping 127.0.0.1 -n 2 >nul

echo Running Test 03B - Preserve Multiple Instance Waiting...
set /a TOTAL+=1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test03B\PID_Test_App.exe" >nul

start "" "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\03B_Multiple_Instances.ini" 127.0.0.1 -n 3 -w 1000 >nul 2>&1
ping 127.0.0.1 -n 2 >nul

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\03B_Multiple_Instances.ini" 127.0.0.1 -n 7 -w 1000 >nul 2>&1

rem Primary target should have closed, but the second portable instance should still be running.
ping 127.0.0.1 -n 3 >nul
findstr /i /x /c:"IsRunning=true" "Working\Test03B\Temp\03B_Multiple_Instances.log" >nul 2>&1
if errorlevel 1 (
    set "T3B_MID=FAIL"
) else (
    set "T3B_MID=PASS"
)

rem After the second portable instance closes, primary X-Launcher should clean up.
ping 127.0.0.1 -n 6 >nul
findstr /i /x /c:"IsRunning=false" "Working\Test03B\Temp\03B_Multiple_Instances.log" >nul 2>&1
if errorlevel 1 (
    set "T3B_END=FAIL"
) else (
    set "T3B_END=PASS"
)

if "!T3B_MID!"=="PASS" if "!T3B_END!"=="PASS" (
    set "T3B=PASS"
    set /a PASSCOUNT+=1
) else (
    set "T3B=FAIL"
    set /a FAILCOUNT+=1
)

taskkill /f /im PID_Test_App.exe >nul 2>&1

echo Running Test 04A - Preserve RunWait False...
set /a TOTAL+=1
mkdir "Working\Test04A\Temp" >nul 2>&1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test04A\RunWait_Test_App.exe" >nul

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\04A_RunWait_False.ini" >nul 2>&1

tasklist /FI "IMAGENAME eq RunWait_Test_App.exe" /NH 2>nul | find /I "RunWait_Test_App.exe" >nul
set "T4A_PROCESS=!ERRORLEVEL!"

if exist "Working\Test04A\Temp" (
    set "T4A_TEMP=FAIL"
) else (
    set "T4A_TEMP=PASS"
)

if "!T4A_PROCESS!"=="0" if "!T4A_TEMP!"=="PASS" (
    set "T4A=PASS"
    set /a PASSCOUNT+=1
) else (
    set "T4A=FAIL"
    set /a FAILCOUNT+=1
)

taskkill /f /im RunWait_Test_App.exe >nul 2>&1

echo Running Test 04B - RunAfter Requires Waiting...
set /a TOTAL+=1
mkdir "Working\Test04B\Temp" >nul 2>&1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test04B\RunWait_Test_App.exe" >nul

> "Working\Test04B\AfterMarker.bat" echo @echo off
>>"Working\Test04B\AfterMarker.bat" echo echo RUNAFTER_OK^>"%%~dp0RunAfter.marker"

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\04B_RunWait_RunAfter.ini" >nul 2>&1

if exist "Working\Test04B\RunAfter.marker" (
    set "T4B=PASS"
    set /a PASSCOUNT+=1
) else (
    set "T4B=FAIL"
    set /a FAILCOUNT+=1
)

taskkill /f /im RunWait_Test_App.exe >nul 2>&1

echo Running Test 05 - Registry Command Exit Code...
set /a TOTAL+=1
mkdir "Working\Test05\Temp" >nul 2>&1

del /q "05_RegEdit_ExitCode.dbg" >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue03" /f >nul 2>&1

> "Working\Test05\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test05\Portable.reg" echo.
>>"Working\Test05\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue03]
>>"Working\Test05\Portable.reg" echo "Portable"="TEST"

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\05_RegEdit_ExitCode.ini" >nul 2>&1

rem The key did not exist before launch, so the initial REG EXPORT must fail.
rem The fixed _RegEdit() must log that non-zero REG.EXE exit code.
findstr /i /c:"Registry EXPORT failed" "05_RegEdit_ExitCode.dbg" >nul 2>&1
if errorlevel 1 (
    set "T5_DETECT=FAIL"
) else (
    set "T5_DETECT=PASS"
)

rem Cleanup should leave the deliberately absent host key absent.
reg query "HKCU\Software\XLauncher_Test\Issue03" >nul 2>&1
if errorlevel 1 (
    set "T5_RESTORE=PASS"
) else (
    set "T5_RESTORE=FAIL"
)

if "!T5_RESTORE!"=="PASS" if "!T5_DETECT!"=="PASS" (
    set "T5=PASS"
    set /a PASSCOUNT+=1
) else (
    set "T5=FAIL"
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test" /f >nul 2>&1

echo Running Test 06 - Registry Backup Failure Safety...
set /a TOTAL+=1

mkdir "Working\Test06\Temp\Regedit\backup1\backup-11.reg" >nul 2>&1
mkdir "Working\Test06\Temp\Regedit\backup1\backup-1-1.reg" >nul 2>&1

reg delete "HKCU\Software\XLauncher_Test\Issue02" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Issue02" /v Original /t REG_SZ /d HOST /f >nul 2>&1

> "Working\Test06\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test06\Portable.reg" echo.
>>"Working\Test06\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue02]
>>"Working\Test06\Portable.reg" echo "Portable"="TEST"

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\06_Registry_Backup_Failure.ini" >nul 2>&1
set "T6EXIT=!ERRORLEVEL!"

reg query "HKCU\Software\XLauncher_Test\Issue02" /v Original 2>nul | find /I "HOST" >nul
if errorlevel 1 (
    set "T6_HOST=FAIL"
) else (
    set "T6_HOST=PASS"
)

if "!T6_HOST!"=="PASS" if "!T6EXIT!"=="6" (
    set "T6=PASS"
    set /a PASSCOUNT+=1
) else (
    set "T6=FAIL"
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test" /f >nul 2>&1

echo Running Test 07 - Registry Restore Failure Preservation...
set /a TOTAL+=1

mkdir "Working\Test07\Temp" >nul 2>&1
del /q "07_Registry_Restore_Failure.dbg" >nul 2>&1

reg delete "HKCU\Software\XLauncher_Test\Issue04" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Issue04" /v Original /t REG_SZ /d HOST /f >nul 2>&1

> "Working\Test07\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test07\Portable.reg" echo.
>>"Working\Test07\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue04]
>>"Working\Test07\Portable.reg" echo "Portable"="TEST"

> "Working\Test07\CorruptBackup.bat" echo @echo off
>>"Working\Test07\CorruptBackup.bat" echo ^> "%%~dp0Temp\Regedit\backup1\backup-1-1.reg" echo THIS_IS_NOT_A_VALID_REGISTRY_FILE

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\07_Registry_Restore_Failure.ini" >nul 2>&1

if exist "Working\Test07\Temp\Regedit\backup1\backup-1-1.reg" (
    set "T7_BACKUP=PASS"
) else (
    set "T7_BACKUP=FAIL"
)

findstr /i /c:"Registry IMPORT failed" "07_Registry_Restore_Failure.dbg" >nul 2>&1
if errorlevel 1 (
    set "T7_DETECT=FAIL"
) else (
    set "T7_DETECT=PASS"
)

set "T7=FAIL"
if "!T7_BACKUP!"=="PASS" if "!T7_DETECT!"=="PASS" set "T7=PASS"

if "!T7!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test" /f >nul 2>&1

echo Running Test 08 - Registry 32-bit View...
set /a TOTAL+=1

mkdir "Working\Test08\Temp" >nul 2>&1
del /q "Working\Test08\ViewResult.txt" >nul 2>&1

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /f /reg:64 >nul 2>&1

reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /v Original /t REG_SZ /d HOST32 /f /reg:32 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /v Original /t REG_SZ /d HOST64 /f /reg:64 >nul 2>&1

> "Working\Test08\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test08\Portable.reg" echo.
>>"Working\Test08\Portable.reg" echo [HKEY_CURRENT_USER\Software\Classes\CLSID\XLauncher_Test_Issue05]
>>"Working\Test08\Portable.reg" echo "Portable"="TEST"

> "Working\Test08\CheckView.bat" echo @echo off
>>"Working\Test08\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /v Portable /reg:32 ^>nul 2^>^&1
>>"Working\Test08\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test08\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /v Original /reg:64 ^>nul 2^>^&1
>>"Working\Test08\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test08\CheckView.bat" echo ^> "%%~dp0ViewResult.txt" echo PASS
>>"Working\Test08\CheckView.bat" echo exit /b 0

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\08_Registry_View_32.ini" >nul 2>&1

findstr /x /c:"PASS" "Working\Test08\ViewResult.txt" >nul 2>&1
if errorlevel 1 (
    set "T8_ACTIVE=FAIL"
) else (
    set "T8_ACTIVE=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /v Original /reg:32 2>nul | find /I "HOST32" >nul
if errorlevel 1 (
    set "T8_RESTORE32=FAIL"
) else (
    set "T8_RESTORE32=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /v Original /reg:64 2>nul | find /I "HOST64" >nul
if errorlevel 1 (
    set "T8_RESTORE64=FAIL"
) else (
    set "T8_RESTORE64=PASS"
)

set "T8=FAIL"
if "!T8_ACTIVE!"=="PASS" if "!T8_RESTORE32!"=="PASS" if "!T8_RESTORE64!"=="PASS" set "T8=PASS"

if "!T8!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05" /f /reg:64 >nul 2>&1

echo Running Test 08B - Registry 64-bit View...
set /a TOTAL+=1

mkdir "Working\Test08B\Temp" >nul 2>&1
del /q "Working\Test08B\ViewResult.txt" >nul 2>&1

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /f /reg:64 >nul 2>&1

reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /v Original /t REG_SZ /d HOST32 /f /reg:32 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /v Original /t REG_SZ /d HOST64 /f /reg:64 >nul 2>&1

> "Working\Test08B\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test08B\Portable.reg" echo.
>>"Working\Test08B\Portable.reg" echo [HKEY_CURRENT_USER\Software\Classes\CLSID\XLauncher_Test_Issue05_64]
>>"Working\Test08B\Portable.reg" echo "Portable"="TEST"

> "Working\Test08B\CheckView.bat" echo @echo off
>>"Working\Test08B\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /v Portable /reg:64 ^>nul 2^>^&1
>>"Working\Test08B\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test08B\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /v Original /reg:32 ^>nul 2^>^&1
>>"Working\Test08B\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test08B\CheckView.bat" echo ^> "%%~dp0ViewResult.txt" echo PASS
>>"Working\Test08B\CheckView.bat" echo exit /b 0

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\08B_Registry_View_64.ini" >nul 2>&1

findstr /x /c:"PASS" "Working\Test08B\ViewResult.txt" >nul 2>&1
if errorlevel 1 (
    set "T8B_ACTIVE=FAIL"
) else (
    set "T8B_ACTIVE=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /v Original /reg:64 2>nul | find /I "HOST64" >nul
if errorlevel 1 (
    set "T8B_RESTORE64=FAIL"
) else (
    set "T8B_RESTORE64=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /v Original /reg:32 2>nul | find /I "HOST32" >nul
if errorlevel 1 (
    set "T8B_RESTORE32=FAIL"
) else (
    set "T8B_RESTORE32=PASS"
)

set "T8B=FAIL"
if "!T8B_ACTIVE!"=="PASS" if "!T8B_RESTORE64!"=="PASS" if "!T8B_RESTORE32!"=="PASS" set "T8B=PASS"

if "!T8B!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_64" /f /reg:64 >nul 2>&1

echo Running Test 08C - Registry Native View Compatibility...
set /a TOTAL+=1

mkdir "Working\Test08C\Temp" >nul 2>&1
del /q "Working\Test08C\ViewResult.txt" >nul 2>&1

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /f /reg:64 >nul 2>&1

reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /v Original /t REG_SZ /d HOST32 /f /reg:32 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /v Original /t REG_SZ /d HOST64 /f /reg:64 >nul 2>&1

> "Working\Test08C\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test08C\Portable.reg" echo.
>>"Working\Test08C\Portable.reg" echo [HKEY_CURRENT_USER\Software\Classes\CLSID\XLauncher_Test_Issue05_Native]
>>"Working\Test08C\Portable.reg" echo "Portable"="TEST"

> "Working\Test08C\CheckView.bat" echo @echo off
>>"Working\Test08C\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /v Portable /reg:64 ^>nul 2^>^&1
>>"Working\Test08C\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test08C\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /v Original /reg:32 ^>nul 2^>^&1
>>"Working\Test08C\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test08C\CheckView.bat" echo ^> "%%~dp0ViewResult.txt" echo PASS
>>"Working\Test08C\CheckView.bat" echo exit /b 0

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\08C_Registry_View_Native.ini" >nul 2>&1

findstr /x /c:"PASS" "Working\Test08C\ViewResult.txt" >nul 2>&1
if errorlevel 1 (
    set "T8C_ACTIVE=FAIL"
) else (
    set "T8C_ACTIVE=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /v Original /reg:64 2>nul | find /I "HOST64" >nul
if errorlevel 1 (
    set "T8C_RESTORE64=FAIL"
) else (
    set "T8C_RESTORE64=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /v Original /reg:32 2>nul | find /I "HOST32" >nul
if errorlevel 1 (
    set "T8C_RESTORE32=FAIL"
) else (
    set "T8C_RESTORE32=PASS"
)

set "T8C=FAIL"
if "!T8C_ACTIVE!"=="PASS" if "!T8C_RESTORE64!"=="PASS" if "!T8C_RESTORE32!"=="PASS" set "T8C=PASS"

if "!T8C!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Native" /f /reg:64 >nul 2>&1

echo Running Test 09 - Interrupted Registry Recovery...
set /a TOTAL+=1

mkdir "Working\Test09\Temp" >nul 2>&1

rem Use uniquely named copies so the test can force-close only its own
rem launcher and target processes without touching unrelated programs.
copy /y "%LAUNCHER%" "Issue06_Launcher.exe" >nul
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test09\Issue06_Target.exe" >nul

reg delete "HKCU\Software\XLauncher_Test\Issue06" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Issue06" /v Original /t REG_SZ /d HOST /f >nul 2>&1

> "Working\Test09\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test09\Portable.reg" echo.
>>"Working\Test09\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue06]
>>"Working\Test09\Portable.reg" echo "Portable"="FIRST"

rem Start the uniquely named launcher asynchronously.
start "" "Issue06_Launcher.exe" "--x-launcher-config=%CD%\Configs\09_Registry_Interrupted_Recovery.ini" 127.0.0.1 -n 30 -w 1000

set "T9_IMPORTED=FAIL"
for /l %%N in (1,1,15) do (
    reg query "HKCU\Software\XLauncher_Test\Issue06" /v Portable 2>nul | find /I "FIRST" >nul
    if not errorlevel 1 (
        set "T9_IMPORTED=PASS"
        goto T9_IMPORTED_READY
    )
    timeout /t 1 /nobreak >nul
)

:T9_IMPORTED_READY
taskkill /f /im Issue06_Launcher.exe >nul 2>&1
taskkill /f /im Issue06_Target.exe >nul 2>&1
timeout /t 1 /nobreak >nul

set "T9_BACKUP=FAIL"
if exist "Working\Test09\Temp\Regedit\backup1\transaction.ini" (
    dir /b /a-d "Working\Test09\Temp\Regedit\backup1\*.reg" >nul 2>&1
    if not errorlevel 1 set "T9_BACKUP=PASS"
)

set "T9_CRASH_STATE=FAIL"
if "!T9_IMPORTED!"=="PASS" if "!T9_BACKUP!"=="PASS" set "T9_CRASH_STATE=PASS"

rem Change the portable data before the second launch. A safe implementation
rem must recover HOST from the interrupted transaction before making a new backup.
> "Working\Test09\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test09\Portable.reg" echo.
>>"Working\Test09\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue06]
>>"Working\Test09\Portable.reg" echo "Portable"="SECOND"

rem Make the second target run short so this regression test completes quickly.
start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\09_Registry_Interrupted_Recovery.ini" 127.0.0.1 -n 1 -w 100 >nul 2>&1

reg query "HKCU\Software\XLauncher_Test\Issue06" /v Original 2>nul | find /I "HOST" >nul
if errorlevel 1 (
    set "T9_RECOVERY=FAIL"
) else (
    set "T9_RECOVERY=PASS"
)

set "T9=FAIL"
if "!T9_CRASH_STATE!"=="PASS" if "!T9_RECOVERY!"=="PASS" set "T9=PASS"

if "!T9!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

taskkill /f /im Issue06_Launcher.exe >nul 2>&1
taskkill /f /im Issue06_Target.exe >nul 2>&1
del /q "Issue06_Launcher.exe" >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test" /f >nul 2>&1

echo Running Test 10 - Protected Registry Failure Safety...
set /a TOTAL+=1

mkdir "Working\Test10" >nul 2>&1
del /q "Working\Test10\Launched.txt" >nul 2>&1
del /q "10_Protected_Registry.dbg" >nul 2>&1

> "Working\Test10\ClearDeny.ps1" echo $ErrorActionPreference = 'Stop'
>>"Working\Test10\ClearDeny.ps1" echo $path = 'Software\XLauncher_Test\Issue27'
>>"Working\Test10\ClearDeny.ps1" echo $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
>>"Working\Test10\ClearDeny.ps1" echo $rights = [System.Security.AccessControl.RegistryRights]::ChangePermissions -bor [System.Security.AccessControl.RegistryRights]::ReadPermissions
>>"Working\Test10\ClearDeny.ps1" echo $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($path, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, $rights)
>>"Working\Test10\ClearDeny.ps1" echo if ($null -eq $key) { exit 0 }
>>"Working\Test10\ClearDeny.ps1" echo $acl = $key.GetAccessControl()
>>"Working\Test10\ClearDeny.ps1" echo $rules = $acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier])
>>"Working\Test10\ClearDeny.ps1" echo foreach ($rule in $rules) {
>>"Working\Test10\ClearDeny.ps1" echo     if ($rule.IdentityReference.Value -eq $sid.Value -and $rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
>>"Working\Test10\ClearDeny.ps1" echo         [void]$acl.RemoveAccessRuleSpecific($rule)
>>"Working\Test10\ClearDeny.ps1" echo     }
>>"Working\Test10\ClearDeny.ps1" echo }
>>"Working\Test10\ClearDeny.ps1" echo $key.SetAccessControl($acl)
>>"Working\Test10\ClearDeny.ps1" echo $key.Close()

rem Clean up a possible interrupted previous Test 10 before recreating the key.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test10\ClearDeny.ps1" >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue27" /f >nul 2>&1
if exist "Working\Test10\Temp" rmdir /s /q "Working\Test10\Temp"
mkdir "Working\Test10\Temp" >nul 2>&1

reg add "HKCU\Software\XLauncher_Test\Issue27" /v Original /t REG_SZ /d HOST /f >nul 2>&1

> "Working\Test10\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test10\Portable.reg" echo.
>>"Working\Test10\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue27]
>>"Working\Test10\Portable.reg" echo "Portable"="TEST"

> "Working\Test10\SetDeny.ps1" echo $ErrorActionPreference = 'Stop'
>>"Working\Test10\SetDeny.ps1" echo $path = 'Software\XLauncher_Test\Issue27'
>>"Working\Test10\SetDeny.ps1" echo $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($path, $true)
>>"Working\Test10\SetDeny.ps1" echo if ($null -eq $key) { throw 'Test registry key not found.' }
>>"Working\Test10\SetDeny.ps1" echo $acl = $key.GetAccessControl()
>>"Working\Test10\SetDeny.ps1" echo $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
>>"Working\Test10\SetDeny.ps1" echo $rights = [System.Security.AccessControl.RegistryRights]::SetValue -bor [System.Security.AccessControl.RegistryRights]::CreateSubKey -bor [System.Security.AccessControl.RegistryRights]::Delete
>>"Working\Test10\SetDeny.ps1" echo $rule = New-Object System.Security.AccessControl.RegistryAccessRule($sid, $rights, [System.Security.AccessControl.AccessControlType]::Deny)
>>"Working\Test10\SetDeny.ps1" echo [void]$acl.AddAccessRule($rule)
>>"Working\Test10\SetDeny.ps1" echo $key.SetAccessControl($acl)
>>"Working\Test10\SetDeny.ps1" echo $key.Close()

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test10\SetDeny.ps1" >nul 2>&1
if errorlevel 1 (
    set "T10_SETUP=FAIL"
) else (
    rem Prove the test key is actually protected before launching X-Launcher.
    reg add "HKCU\Software\XLauncher_Test\Issue27" /v Probe /t REG_SZ /d SHOULD_NOT_WRITE /f >nul 2>&1
    if errorlevel 1 (
        set "T10_SETUP=PASS"
    ) else (
        set "T10_SETUP=FAIL"
    )
)

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\10_Protected_Registry.ini" >nul 2>&1
set "T10EXIT=!ERRORLEVEL!"

reg query "HKCU\Software\XLauncher_Test\Issue27" /v Original 2>nul | find /I "HOST" >nul
if errorlevel 1 (
    set "T10_HOST=FAIL"
) else (
    set "T10_HOST=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue27" /v Portable >nul 2>&1
if errorlevel 1 (
    set "T10_PORTABLE=PASS"
) else (
    set "T10_PORTABLE=FAIL"
)

if exist "Working\Test10\Launched.txt" (
    set "T10_BLOCKED=FAIL"
) else (
    set "T10_BLOCKED=PASS"
)

set "T10=FAIL"
if "!T10_SETUP!"=="PASS" if "!T10_HOST!"=="PASS" if "!T10_PORTABLE!"=="PASS" if "!T10_BLOCKED!"=="PASS" set "T10=PASS"

if "!T10!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

rem Always remove the temporary deny rule before deleting the disposable key.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test10\ClearDeny.ps1" >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue27" /f >nul 2>&1
if exist "Working\Test10\Temp" rmdir /s /q "Working\Test10\Temp"

echo Running Test 11A - RegView Auto Detect 32-bit EXE...
set /a TOTAL+=1

if exist "Working\Test11A" rmdir /s /q "Working\Test11A"
mkdir "Working\Test11A\Temp" >nul 2>&1
copy /y "%SystemRoot%\SysWOW64\ping.exe" "Working\Test11A\Auto32_Target.exe" >nul
copy /y "%LAUNCHER%" "Issue05Auto_Launcher.exe" >nul

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /f /reg:64 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /v Original /t REG_SZ /d HOST32 /f /reg:32 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /v Original /t REG_SZ /d HOST64 /f /reg:64 >nul 2>&1

> "Working\Test11A\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test11A\Portable.reg" echo.
>>"Working\Test11A\Portable.reg" echo [HKEY_CURRENT_USER\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32]
>>"Working\Test11A\Portable.reg" echo "Portable"="TEST"

start "" "Issue05Auto_Launcher.exe" "--x-launcher-config=%CD%\Configs\11A_RegView_Auto_32.ini" 127.0.0.1 -n 6 -w 1000

set "T11A_ACTIVE=FAIL"
for /l %%N in (1,1,10) do (
    reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /v Portable /reg:32 2>nul | find /I "TEST" >nul
    if not errorlevel 1 (
        reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /v Original /reg:64 2>nul | find /I "HOST64" >nul
        if not errorlevel 1 (
            set "T11A_ACTIVE=PASS"
            goto T11A_ACTIVE_READY
        )
    )
    timeout /t 1 /nobreak >nul
)

:T11A_ACTIVE_READY
for /l %%N in (1,1,12) do (
    tasklist /fi "imagename eq Issue05Auto_Launcher.exe" 2>nul | find /I "Issue05Auto_Launcher.exe" >nul
    if errorlevel 1 goto T11A_FINISHED
    timeout /t 1 /nobreak >nul
)

:T11A_FINISHED
reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /v Original /reg:32 2>nul | find /I "HOST32" >nul
if errorlevel 1 (
    set "T11A_RESTORE32=FAIL"
) else (
    set "T11A_RESTORE32=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /v Original /reg:64 2>nul | find /I "HOST64" >nul
if errorlevel 1 (
    set "T11A_RESTORE64=FAIL"
) else (
    set "T11A_RESTORE64=PASS"
)

set "T11A=FAIL"
if "!T11A_ACTIVE!"=="PASS" if "!T11A_RESTORE32!"=="PASS" if "!T11A_RESTORE64!"=="PASS" set "T11A=PASS"

if "!T11A!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

taskkill /f /im Issue05Auto_Launcher.exe >nul 2>&1
taskkill /f /im Auto32_Target.exe >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto32" /f /reg:64 >nul 2>&1

echo Running Test 11B - RegView Auto Detect 64-bit EXE...
set /a TOTAL+=1

if exist "Working\Test11B" rmdir /s /q "Working\Test11B"
mkdir "Working\Test11B\Temp" >nul 2>&1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test11B\Auto64_Target.exe" >nul

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /f /reg:64 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /v Original /t REG_SZ /d HOST32 /f /reg:32 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /v Original /t REG_SZ /d HOST64 /f /reg:64 >nul 2>&1

> "Working\Test11B\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test11B\Portable.reg" echo.
>>"Working\Test11B\Portable.reg" echo [HKEY_CURRENT_USER\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64]
>>"Working\Test11B\Portable.reg" echo "Portable"="TEST"

start "" "Issue05Auto_Launcher.exe" "--x-launcher-config=%CD%\Configs\11B_RegView_Auto_64.ini" 127.0.0.1 -n 6 -w 1000

set "T11B_ACTIVE=FAIL"
for /l %%N in (1,1,10) do (
    reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /v Portable /reg:64 2>nul | find /I "TEST" >nul
    if not errorlevel 1 (
        reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /v Original /reg:32 2>nul | find /I "HOST32" >nul
        if not errorlevel 1 (
            set "T11B_ACTIVE=PASS"
            goto T11B_ACTIVE_READY
        )
    )
    timeout /t 1 /nobreak >nul
)

:T11B_ACTIVE_READY
for /l %%N in (1,1,12) do (
    tasklist /fi "imagename eq Issue05Auto_Launcher.exe" 2>nul | find /I "Issue05Auto_Launcher.exe" >nul
    if errorlevel 1 goto T11B_FINISHED
    timeout /t 1 /nobreak >nul
)

:T11B_FINISHED
reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /v Original /reg:64 2>nul | find /I "HOST64" >nul
if errorlevel 1 (
    set "T11B_RESTORE64=FAIL"
) else (
    set "T11B_RESTORE64=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /v Original /reg:32 2>nul | find /I "HOST32" >nul
if errorlevel 1 (
    set "T11B_RESTORE32=FAIL"
) else (
    set "T11B_RESTORE32=PASS"
)

set "T11B=FAIL"
if "!T11B_ACTIVE!"=="PASS" if "!T11B_RESTORE64!"=="PASS" if "!T11B_RESTORE32!"=="PASS" set "T11B=PASS"

if "!T11B!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

taskkill /f /im Issue05Auto_Launcher.exe >nul 2>&1
taskkill /f /im Auto64_Target.exe >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_Auto64" /f /reg:64 >nul 2>&1
del /q "Issue05Auto_Launcher.exe" >nul 2>&1

echo Running Test 11C - RegView Auto Native Fallback...
set /a TOTAL+=1

if exist "Working\Test11C" rmdir /s /q "Working\Test11C"
mkdir "Working\Test11C\Temp" >nul 2>&1

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /f /reg:64 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /v Original /t REG_SZ /d HOST32 /f /reg:32 >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /v Original /t REG_SZ /d HOST64 /f /reg:64 >nul 2>&1

> "Working\Test11C\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test11C\Portable.reg" echo.
>>"Working\Test11C\Portable.reg" echo [HKEY_CURRENT_USER\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback]
>>"Working\Test11C\Portable.reg" echo "Portable"="TEST"

> "Working\Test11C\CheckView.bat" echo @echo off
>>"Working\Test11C\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /v Portable /reg:64 ^>nul 2^>^&1
>>"Working\Test11C\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test11C\CheckView.bat" echo reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /v Original /reg:32 ^>nul 2^>^&1
>>"Working\Test11C\CheckView.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test11C\CheckView.bat" echo ^> "%%~dp0ViewResult.txt" echo PASS
>>"Working\Test11C\CheckView.bat" echo exit /b 0

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\11C_RegView_Auto_Fallback.ini" >nul 2>&1

findstr /x /c:"PASS" "Working\Test11C\ViewResult.txt" >nul 2>&1
if errorlevel 1 (
    set "T11C_ACTIVE=FAIL"
) else (
    set "T11C_ACTIVE=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /v Original /reg:64 2>nul | find /I "HOST64" >nul
if errorlevel 1 (
    set "T11C_RESTORE64=FAIL"
) else (
    set "T11C_RESTORE64=PASS"
)

reg query "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /v Original /reg:32 2>nul | find /I "HOST32" >nul
if errorlevel 1 (
    set "T11C_RESTORE32=FAIL"
) else (
    set "T11C_RESTORE32=PASS"
)

set "T11C=FAIL"
if "!T11C_ACTIVE!"=="PASS" if "!T11C_RESTORE64!"=="PASS" if "!T11C_RESTORE32!"=="PASS" set "T11C=PASS"

if "!T11C!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /f /reg:32 >nul 2>&1
reg delete "HKCU\Software\Classes\CLSID\XLauncher_Test_Issue05_AutoFallback" /f /reg:64 >nul 2>&1

echo Running Test 12 - Multi-Root Registry Safety...
set /a TOTAL+=1

if exist "Working\Test12" rmdir /s /q "Working\Test12"
mkdir "Working\Test12\Temp" >nul 2>&1

reg delete "HKCU\Software\XLauncher_Test\Issue24_A" /f >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue24_B" /f >nul 2>&1

reg add "HKCU\Software\XLauncher_Test\Issue24_A" /v State /t REG_SZ /d HOST_A /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Issue24_B" /v State /t REG_SZ /d HOST_B /f >nul 2>&1

> "Working\Test12\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test12\Portable.reg" echo.
>>"Working\Test12\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue24_A]
>>"Working\Test12\Portable.reg" echo "State"="PORTABLE_A"
>>"Working\Test12\Portable.reg" echo.
>>"Working\Test12\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue24_B]
>>"Working\Test12\Portable.reg" echo "State"="PORTABLE_B"

> "Working\Test12\CheckRoots.bat" echo @echo off
>>"Working\Test12\CheckRoots.bat" echo reg query "HKCU\Software\XLauncher_Test\Issue24_A" /v State 2^>nul ^| find /I "PORTABLE_A" ^>nul
>>"Working\Test12\CheckRoots.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test12\CheckRoots.bat" echo reg query "HKCU\Software\XLauncher_Test\Issue24_B" /v State 2^>nul ^| find /I "PORTABLE_B" ^>nul
>>"Working\Test12\CheckRoots.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test12\CheckRoots.bat" echo reg add "HKCU\Software\XLauncher_Test\Issue24_A" /v RuntimeA /t REG_SZ /d SAVE_A /f ^>nul
>>"Working\Test12\CheckRoots.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test12\CheckRoots.bat" echo reg add "HKCU\Software\XLauncher_Test\Issue24_B" /v RuntimeB /t REG_SZ /d SAVE_B /f ^>nul
>>"Working\Test12\CheckRoots.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test12\CheckRoots.bat" echo ^> "%%~dp0Active.txt" echo PASS
>>"Working\Test12\CheckRoots.bat" echo exit /b 0

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\12_Multi_Root_Registry.ini" >nul 2>&1

findstr /x /c:"PASS" "Working\Test12\Active.txt" >nul 2>&1
if errorlevel 1 (
    set "T12_ACTIVE=FAIL"
) else (
    set "T12_ACTIVE=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue24_A" /v State 2>nul | find /I "HOST_A" >nul
if errorlevel 1 (
    set "T12_ROOT1=FAIL"
) else (
    set "T12_ROOT1=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue24_B" /v State 2>nul | find /I "HOST_B" >nul
if errorlevel 1 (
    set "T12_ROOT2=FAIL"
) else (
    set "T12_ROOT2=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue24_A" /v RuntimeA >nul 2>&1
if errorlevel 1 (
    set "T12_CLEAN1=PASS"
) else (
    set "T12_CLEAN1=FAIL"
)

reg query "HKCU\Software\XLauncher_Test\Issue24_B" /v RuntimeB >nul 2>&1
if errorlevel 1 (
    set "T12_CLEAN2=PASS"
) else (
    set "T12_CLEAN2=FAIL"
)

set "T12_SAVE=FAIL"
> "Working\Test12\CheckPortableReg.ps1" echo $c = Get-Content -Raw -LiteralPath 'Working\Test12\Portable.reg'
>>"Working\Test12\CheckPortableReg.ps1" echo if ($c -notmatch [regex]::Escape('[HKEY_CURRENT_USER\Software\XLauncher_Test\Issue24_A]')) { exit 1 }
>>"Working\Test12\CheckPortableReg.ps1" echo if ($c -notmatch [regex]::Escape('"RuntimeA"="SAVE_A"')) { exit 1 }
>>"Working\Test12\CheckPortableReg.ps1" echo if ($c -notmatch [regex]::Escape('[HKEY_CURRENT_USER\Software\XLauncher_Test\Issue24_B]')) { exit 1 }
>>"Working\Test12\CheckPortableReg.ps1" echo if ($c -notmatch [regex]::Escape('"RuntimeB"="SAVE_B"')) { exit 1 }
>>"Working\Test12\CheckPortableReg.ps1" echo exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test12\CheckPortableReg.ps1" >nul 2>&1
if not errorlevel 1 set "T12_SAVE=PASS"

set "T12=FAIL"
if "!T12_ACTIVE!"=="PASS" if "!T12_ROOT1!"=="PASS" if "!T12_ROOT2!"=="PASS" if "!T12_CLEAN1!"=="PASS" if "!T12_CLEAN2!"=="PASS" if "!T12_SAVE!"=="PASS" set "T12=PASS"

if "!T12!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test\Issue24_A" /f >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue24_B" /f >nul 2>&1

echo Running Test 13 - Registry Restore Order Manifest...
set /a TOTAL+=1

if exist "Working\Test13" rmdir /s /q "Working\Test13"
mkdir "Working\Test13\Temp" >nul 2>&1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test13\Hold.exe" >nul
copy /y "%LAUNCHER%" "Issue26_Launcher.exe" >nul

reg delete "HKCU\Software\XLauncher_Test\Issue26_A" /f >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue26_B" /f >nul 2>&1

reg add "HKCU\Software\XLauncher_Test\Issue26_A" /v State /t REG_SZ /d HOST_A /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Issue26_B" /v State /t REG_SZ /d HOST_B /f >nul 2>&1

> "Working\Test13\One.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test13\One.reg" echo.
>>"Working\Test13\One.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue26_A]
>>"Working\Test13\One.reg" echo "State"="PORTABLE_A"

> "Working\Test13\Two.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test13\Two.reg" echo.
>>"Working\Test13\Two.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue26_B]
>>"Working\Test13\Two.reg" echo "State"="PORTABLE_B"

start "" "Issue26_Launcher.exe" "--x-launcher-config=%CD%\Configs\13_Registry_Restore_Order.ini" 127.0.0.1 -n 8 -w 1000

set "T13_ACTIVE=FAIL"
for /l %%N in (1,1,10) do (
    reg query "HKCU\Software\XLauncher_Test\Issue26_A" /v State 2>nul | find /I "PORTABLE_A" >nul
    if not errorlevel 1 (
        reg query "HKCU\Software\XLauncher_Test\Issue26_B" /v State 2>nul | find /I "PORTABLE_B" >nul
        if not errorlevel 1 (
            set "T13_ACTIVE=PASS"
            goto T13_ACTIVE_READY
        )
    )
    timeout /t 1 /nobreak >nul
)

:T13_ACTIVE_READY
if exist "Working\Test13\Temp\Regedit\backup1\transaction.ini" (
    set "T13_MANIFEST=PASS"
) else (
    set "T13_MANIFEST=FAIL"
)

set "T13_ORDER=FAIL"
> "Working\Test13\CheckManifest.ps1" echo $dir = 'Working\Test13\Temp\Regedit\backup1'
>>"Working\Test13\CheckManifest.ps1" echo $p = Join-Path $dir 'transaction.ini'
>>"Working\Test13\CheckManifest.ps1" echo if (-not (Test-Path -LiteralPath $p)) { exit 1 }
>>"Working\Test13\CheckManifest.ps1" echo $b1 = (Get-Content -LiteralPath $p ^| Where-Object { $_ -match '^Backup1=' }) -replace '^Backup1=', ''
>>"Working\Test13\CheckManifest.ps1" echo $b2 = (Get-Content -LiteralPath $p ^| Where-Object { $_ -match '^Backup2=' }) -replace '^Backup2=', ''
>>"Working\Test13\CheckManifest.ps1" echo if ([string]::IsNullOrWhiteSpace($b1) -or [string]::IsNullOrWhiteSpace($b2)) { exit 1 }
>>"Working\Test13\CheckManifest.ps1" echo if ($b1 -eq $b2) { exit 1 }
>>"Working\Test13\CheckManifest.ps1" echo $f1 = Join-Path $dir $b1.Trim()
>>"Working\Test13\CheckManifest.ps1" echo $f2 = Join-Path $dir $b2.Trim()
>>"Working\Test13\CheckManifest.ps1" echo if (-not (Test-Path -LiteralPath $f1) -or -not (Test-Path -LiteralPath $f2)) { exit 1 }
>>"Working\Test13\CheckManifest.ps1" echo $c1 = Get-Content -Raw -LiteralPath $f1
>>"Working\Test13\CheckManifest.ps1" echo $c2 = Get-Content -Raw -LiteralPath $f2
>>"Working\Test13\CheckManifest.ps1" echo if ($c1 -notmatch 'HOST_A') { exit 1 }
>>"Working\Test13\CheckManifest.ps1" echo if ($c2 -notmatch 'HOST_B') { exit 1 }
>>"Working\Test13\CheckManifest.ps1" echo exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test13\CheckManifest.ps1" >nul 2>&1
if not errorlevel 1 set "T13_ORDER=PASS"

for /l %%N in (1,1,15) do (
    tasklist /fi "imagename eq Issue26_Launcher.exe" 2>nul | find /I "Issue26_Launcher.exe" >nul
    if errorlevel 1 goto T13_FINISHED
    timeout /t 1 /nobreak >nul
)

:T13_FINISHED
reg query "HKCU\Software\XLauncher_Test\Issue26_A" /v State 2>nul | find /I "HOST_A" >nul
if errorlevel 1 (
    set "T13_HOSTA=FAIL"
) else (
    set "T13_HOSTA=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue26_B" /v State 2>nul | find /I "HOST_B" >nul
if errorlevel 1 (
    set "T13_HOSTB=FAIL"
) else (
    set "T13_HOSTB=PASS"
)

set "T13_RESTORE=FAIL"
if "!T13_HOSTA!"=="PASS" if "!T13_HOSTB!"=="PASS" set "T13_RESTORE=PASS"

set "T13=FAIL"
if "!T13_ACTIVE!"=="PASS" if "!T13_MANIFEST!"=="PASS" if "!T13_ORDER!"=="PASS" if "!T13_RESTORE!"=="PASS" set "T13=PASS"

if "!T13!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

taskkill /f /im Issue26_Launcher.exe >nul 2>&1
taskkill /f /im Hold.exe >nul 2>&1
del /q "Issue26_Launcher.exe" >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue26_A" /f >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue26_B" /f >nul 2>&1

echo Running Test 14 - Registry Backup Filename Uniqueness...
set /a TOTAL+=1

if exist "Working\Test14" rmdir /s /q "Working\Test14"
mkdir "Working\Test14\Temp" >nul 2>&1
copy /y "%SystemRoot%\System32\ping.exe" "Working\Test14\Hold.exe" >nul
copy /y "%LAUNCHER%" "Issue25_Launcher.exe" >nul

reg delete "HKCU\Software\XLauncher_Test\Issue25" /f >nul 2>&1

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R1" /v State /t REG_SZ /d HOST_G1R1 /f >nul 2>&1
> "Working\Test14\G1_1.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_1.reg" echo.
>>"Working\Test14\G1_1.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R1]
>>"Working\Test14\G1_1.reg" echo "State"="PORTABLE_G1R1"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R2" /v State /t REG_SZ /d HOST_G1R2 /f >nul 2>&1
> "Working\Test14\G1_2.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_2.reg" echo.
>>"Working\Test14\G1_2.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R2]
>>"Working\Test14\G1_2.reg" echo "State"="PORTABLE_G1R2"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R3" /v State /t REG_SZ /d HOST_G1R3 /f >nul 2>&1
> "Working\Test14\G1_3.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_3.reg" echo.
>>"Working\Test14\G1_3.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R3]
>>"Working\Test14\G1_3.reg" echo "State"="PORTABLE_G1R3"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R4" /v State /t REG_SZ /d HOST_G1R4 /f >nul 2>&1
> "Working\Test14\G1_4.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_4.reg" echo.
>>"Working\Test14\G1_4.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R4]
>>"Working\Test14\G1_4.reg" echo "State"="PORTABLE_G1R4"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R5" /v State /t REG_SZ /d HOST_G1R5 /f >nul 2>&1
> "Working\Test14\G1_5.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_5.reg" echo.
>>"Working\Test14\G1_5.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R5]
>>"Working\Test14\G1_5.reg" echo "State"="PORTABLE_G1R5"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R6" /v State /t REG_SZ /d HOST_G1R6 /f >nul 2>&1
> "Working\Test14\G1_6.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_6.reg" echo.
>>"Working\Test14\G1_6.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R6]
>>"Working\Test14\G1_6.reg" echo "State"="PORTABLE_G1R6"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R7" /v State /t REG_SZ /d HOST_G1R7 /f >nul 2>&1
> "Working\Test14\G1_7.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_7.reg" echo.
>>"Working\Test14\G1_7.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R7]
>>"Working\Test14\G1_7.reg" echo "State"="PORTABLE_G1R7"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R8" /v State /t REG_SZ /d HOST_G1R8 /f >nul 2>&1
> "Working\Test14\G1_8.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_8.reg" echo.
>>"Working\Test14\G1_8.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R8]
>>"Working\Test14\G1_8.reg" echo "State"="PORTABLE_G1R8"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R9" /v State /t REG_SZ /d HOST_G1R9 /f >nul 2>&1
> "Working\Test14\G1_9.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_9.reg" echo.
>>"Working\Test14\G1_9.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R9]
>>"Working\Test14\G1_9.reg" echo "State"="PORTABLE_G1R9"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R10" /v State /t REG_SZ /d HOST_G1R10 /f >nul 2>&1
> "Working\Test14\G1_10.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_10.reg" echo.
>>"Working\Test14\G1_10.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R10]
>>"Working\Test14\G1_10.reg" echo "State"="PORTABLE_G1R10"

reg add "HKCU\Software\XLauncher_Test\Issue25\G1R11" /v State /t REG_SZ /d HOST_G1R11 /f >nul 2>&1
> "Working\Test14\G1_11.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G1_11.reg" echo.
>>"Working\Test14\G1_11.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G1R11]
>>"Working\Test14\G1_11.reg" echo "State"="PORTABLE_G1R11"

reg add "HKCU\Software\XLauncher_Test\Issue25\G2" /v State /t REG_SZ /d HOST_G2 /f >nul 2>&1
> "Working\Test14\G2.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G2.reg" echo.
>>"Working\Test14\G2.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G2]
>>"Working\Test14\G2.reg" echo "State"="PORTABLE_G2"

reg add "HKCU\Software\XLauncher_Test\Issue25\G3" /v State /t REG_SZ /d HOST_G3 /f >nul 2>&1
> "Working\Test14\G3.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G3.reg" echo.
>>"Working\Test14\G3.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G3]
>>"Working\Test14\G3.reg" echo "State"="PORTABLE_G3"

reg add "HKCU\Software\XLauncher_Test\Issue25\G4" /v State /t REG_SZ /d HOST_G4 /f >nul 2>&1
> "Working\Test14\G4.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G4.reg" echo.
>>"Working\Test14\G4.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G4]
>>"Working\Test14\G4.reg" echo "State"="PORTABLE_G4"

reg add "HKCU\Software\XLauncher_Test\Issue25\G5" /v State /t REG_SZ /d HOST_G5 /f >nul 2>&1
> "Working\Test14\G5.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G5.reg" echo.
>>"Working\Test14\G5.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G5]
>>"Working\Test14\G5.reg" echo "State"="PORTABLE_G5"

reg add "HKCU\Software\XLauncher_Test\Issue25\G6" /v State /t REG_SZ /d HOST_G6 /f >nul 2>&1
> "Working\Test14\G6.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G6.reg" echo.
>>"Working\Test14\G6.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G6]
>>"Working\Test14\G6.reg" echo "State"="PORTABLE_G6"

reg add "HKCU\Software\XLauncher_Test\Issue25\G7" /v State /t REG_SZ /d HOST_G7 /f >nul 2>&1
> "Working\Test14\G7.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G7.reg" echo.
>>"Working\Test14\G7.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G7]
>>"Working\Test14\G7.reg" echo "State"="PORTABLE_G7"

reg add "HKCU\Software\XLauncher_Test\Issue25\G8" /v State /t REG_SZ /d HOST_G8 /f >nul 2>&1
> "Working\Test14\G8.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G8.reg" echo.
>>"Working\Test14\G8.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G8]
>>"Working\Test14\G8.reg" echo "State"="PORTABLE_G8"

reg add "HKCU\Software\XLauncher_Test\Issue25\G9" /v State /t REG_SZ /d HOST_G9 /f >nul 2>&1
> "Working\Test14\G9.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G9.reg" echo.
>>"Working\Test14\G9.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G9]
>>"Working\Test14\G9.reg" echo "State"="PORTABLE_G9"

reg add "HKCU\Software\XLauncher_Test\Issue25\G10" /v State /t REG_SZ /d HOST_G10 /f >nul 2>&1
> "Working\Test14\G10.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G10.reg" echo.
>>"Working\Test14\G10.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G10]
>>"Working\Test14\G10.reg" echo "State"="PORTABLE_G10"

reg add "HKCU\Software\XLauncher_Test\Issue25\G11" /v State /t REG_SZ /d HOST_G11 /f >nul 2>&1
> "Working\Test14\G11.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test14\G11.reg" echo.
>>"Working\Test14\G11.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Issue25\G11]
>>"Working\Test14\G11.reg" echo "State"="PORTABLE_G11"

start "" "Issue25_Launcher.exe" "--x-launcher-config=%CD%\Configs\14_Registry_Backup_Filename_Collision.ini" 127.0.0.1 -n 8 -w 1000

set "T14_ACTIVE=FAIL"
for /l %%N in (1,1,10) do (
    reg query "HKCU\Software\XLauncher_Test\Issue25\G1R11" /v State 2>nul | find /I "PORTABLE_G1R11" >nul
    if not errorlevel 1 (
        reg query "HKCU\Software\XLauncher_Test\Issue25\G11" /v State 2>nul | find /I "PORTABLE_G11" >nul
        if not errorlevel 1 (
            set "T14_ACTIVE=PASS"
            goto T14_ACTIVE_READY
        )
    )
    timeout /t 1 /nobreak >nul
)

:T14_ACTIVE_READY
set "T14_UNIQUE=FAIL"
> "Working\Test14\CheckUniqueBackups.ps1" echo $p = 'Working\Test14\Temp\Regedit\backup1\transaction.ini'
>>"Working\Test14\CheckUniqueBackups.ps1" echo if (-not (Test-Path -LiteralPath $p)) { exit 1 }
>>"Working\Test14\CheckUniqueBackups.ps1" echo $lines = Get-Content -LiteralPath $p
>>"Working\Test14\CheckUniqueBackups.ps1" echo $inBackups = $false
>>"Working\Test14\CheckUniqueBackups.ps1" echo $values = @()
>>"Working\Test14\CheckUniqueBackups.ps1" echo foreach ($line in $lines) {
>>"Working\Test14\CheckUniqueBackups.ps1" echo     if ($line -match '^\[Backups\]$') { $inBackups = $true; continue }
>>"Working\Test14\CheckUniqueBackups.ps1" echo     if ($inBackups -and $line -match '^\[') { break }
>>"Working\Test14\CheckUniqueBackups.ps1" echo     if ($inBackups -and $line -match '^Backup\d+=(.+)$') { $values += $matches[1].Trim() }
>>"Working\Test14\CheckUniqueBackups.ps1" echo }
>>"Working\Test14\CheckUniqueBackups.ps1" echo if ($values.Count -lt 21) { exit 1 }
>>"Working\Test14\CheckUniqueBackups.ps1" echo if (($values ^| Sort-Object -Unique).Count -ne $values.Count) { exit 1 }
>>"Working\Test14\CheckUniqueBackups.ps1" echo exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test14\CheckUniqueBackups.ps1" >nul 2>&1
if not errorlevel 1 set "T14_UNIQUE=PASS"

for /l %%N in (1,1,15) do (
    tasklist /fi "imagename eq Issue25_Launcher.exe" 2>nul | find /I "Issue25_Launcher.exe" >nul
    if errorlevel 1 goto T14_FINISHED
    timeout /t 1 /nobreak >nul
)

:T14_FINISHED
reg query "HKCU\Software\XLauncher_Test\Issue25\G1R11" /v State 2>nul | find /I "HOST_G1R11" >nul
if errorlevel 1 (
    set "T14_VICTIM=FAIL"
) else (
    set "T14_VICTIM=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue25\G11" /v State 2>nul | find /I "HOST_G11" >nul
if errorlevel 1 (
    set "T14_WINNER=FAIL"
) else (
    set "T14_WINNER=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue25\G1R1" /v State 2>nul | find /I "HOST_G1R1" >nul
if errorlevel 1 (
    set "T14_SAMPLE=FAIL"
) else (
    set "T14_SAMPLE=PASS"
)

set "T14=FAIL"
if "!T14_ACTIVE!"=="PASS" if "!T14_UNIQUE!"=="PASS" if "!T14_VICTIM!"=="PASS" if "!T14_WINNER!"=="PASS" if "!T14_SAMPLE!"=="PASS" set "T14=PASS"

if "!T14!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

taskkill /f /im Issue25_Launcher.exe >nul 2>&1
taskkill /f /im Hold.exe >nul 2>&1
del /q "Issue25_Launcher.exe" >nul 2>&1
reg delete "HKCU\Software\XLauncher_Test\Issue25" /f >nul 2>&1

echo Running Test 15 - WriteToReg REG Syntax...
set /a TOTAL+=1

if exist "Working\Test15" rmdir /s /q "Working\Test15"
mkdir "Working\Test15\Temp" >nul 2>&1

reg delete "HKCU\Software\XLauncher_Test\Issue23" /f >nul 2>&1

> "Working\Test15\CheckReg.bat" echo @echo off
>>"Working\Test15\CheckReg.bat" echo reg query "HKCU\Software\XLauncher_Test\Issue23" /v RootValue 2^>nul ^| find /I "ROOT_DATA" ^>nul
>>"Working\Test15\CheckReg.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test15\CheckReg.bat" echo reg query "HKCU\Software\XLauncher_Test\Issue23\Child" /v ChildValue 2^>nul ^| find /I "CHILD_DATA" ^>nul
>>"Working\Test15\CheckReg.bat" echo if errorlevel 1 exit /b 1
>>"Working\Test15\CheckReg.bat" echo ^> "%%~dp0Active.txt" echo PASS
>>"Working\Test15\CheckReg.bat" echo exit /b 0

"%LAUNCHER%" "--x-launcher-config=%CD%\Configs\15_WriteToReg_Syntax.ini" >nul 2>&1
set "T15_EXIT=!ERRORLEVEL!"

if exist "Working\Test15\Generated.reg" (
    set "T15_FILE=PASS"
) else (
    set "T15_FILE=FAIL"
)

findstr /x /c:"PASS" "Working\Test15\Active.txt" >nul 2>&1
if errorlevel 1 (
    set "T15_ACTIVE=FAIL"
) else (
    set "T15_ACTIVE=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue23" >nul 2>&1
if errorlevel 1 (
    set "T15_CLEAN=PASS"
) else (
    set "T15_CLEAN=FAIL"
)

reg import "Working\Test15\Generated.reg" >nul 2>&1
if errorlevel 1 (
    set "T15_IMPORT=FAIL"
) else (
    set "T15_IMPORT=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue23" /v RootValue 2>nul | find /I "ROOT_DATA" >nul
if errorlevel 1 (
    set "T15_ROOT=FAIL"
) else (
    set "T15_ROOT=PASS"
)

reg query "HKCU\Software\XLauncher_Test\Issue23\Child" /v ChildValue 2>nul | find /I "CHILD_DATA" >nul
if errorlevel 1 (
    set "T15_CHILD=FAIL"
) else (
    set "T15_CHILD=PASS"
)

set "T15_SYNTAX=FAIL"
> "Working\Test15\CheckSyntax.ps1" echo $p = 'Working\Test15\Generated.reg'
>>"Working\Test15\CheckSyntax.ps1" echo if (-not (Test-Path -LiteralPath $p)) { exit 1 }
>>"Working\Test15\CheckSyntax.ps1" echo $c = Get-Content -Raw -LiteralPath $p
>>"Working\Test15\CheckSyntax.ps1" echo if ($c -notmatch [regex]::Escape('"RootValue"="ROOT_DATA"')) { exit 1 }
>>"Working\Test15\CheckSyntax.ps1" echo if ($c -notmatch [regex]::Escape('[HKEY_CURRENT_USER\Software\XLauncher_Test\Issue23\Child]')) { exit 1 }
>>"Working\Test15\CheckSyntax.ps1" echo if ($c -notmatch [regex]::Escape('"ChildValue"="CHILD_DATA"')) { exit 1 }
>>"Working\Test15\CheckSyntax.ps1" echo exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Working\Test15\CheckSyntax.ps1" >nul 2>&1
if not errorlevel 1 set "T15_SYNTAX=PASS"

set "T15=FAIL"
if "!T15_FILE!"=="PASS" if "!T15_ACTIVE!"=="PASS" if "!T15_CLEAN!"=="PASS" if "!T15_IMPORT!"=="PASS" if "!T15_ROOT!"=="PASS" if "!T15_CHILD!"=="PASS" if "!T15_SYNTAX!"=="PASS" if "!T15_EXIT!"=="0" set "T15=PASS"

if "!T15!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test\Issue23" /f >nul 2>&1

echo Running Test 16 - DirMove Partial Failure Safety...
set /a TOTAL+=1

if exist "Working\Test16" rmdir /s /q "Working\Test16"
mkdir "Working\Test16\Source" >nul 2>&1
mkdir "Working\Test16\Destination" >nul 2>&1
mkdir "Working\Test16\Temp" >nul 2>&1

> "Working\Test16\Source\Conflict.txt" echo SOURCE_MUST_SURVIVE
> "Working\Test16\Source\Movable.txt" echo MOVE_ME
> "Working\Test16\Destination\Conflict.txt" echo DESTINATION_ORIGINAL

> "Working\Test16\CheckMove.bat" echo @echo off
>>"Working\Test16\CheckMove.bat" echo ^> "%%~dp0Active.txt" echo PASS
>>"Working\Test16\CheckMove.bat" echo exit /b 0

"%LAUNCHER%" "--x-launcher-config=%CD%\Configs\16_DirMove_Partial_Failure_Safety.ini" >nul 2>&1
set "T16_EXIT=!ERRORLEVEL!"

findstr /x /c:"PASS" "Working\Test16\Active.txt" >nul 2>&1
if errorlevel 1 (
    set "T16_ACTIVE=FAIL"
) else (
    set "T16_ACTIVE=PASS"
)

findstr /x /c:"DESTINATION_ORIGINAL" "Working\Test16\Destination\Conflict.txt" >nul 2>&1
if errorlevel 1 (
    set "T16_DESTCONFLICT=FAIL"
) else (
    set "T16_DESTCONFLICT=PASS"
)

findstr /x /c:"MOVE_ME" "Working\Test16\Destination\Movable.txt" >nul 2>&1
if errorlevel 1 (
    set "T16_MOVED=FAIL"
) else (
    set "T16_MOVED=PASS"
)

if exist "Working\Test16\Source\Movable.txt" (
    set "T16_MOVEDSOURCE=FAIL"
) else (
    set "T16_MOVEDSOURCE=PASS"
)

findstr /x /c:"SOURCE_MUST_SURVIVE" "Working\Test16\Source\Conflict.txt" >nul 2>&1
if errorlevel 1 (
    set "T16_SOURCE=FAIL"
) else (
    set "T16_SOURCE=PASS"
)

set "T16=FAIL"
if "!T16_ACTIVE!"=="PASS" if "!T16_DESTCONFLICT!"=="PASS" if "!T16_MOVED!"=="PASS" if "!T16_MOVEDSOURCE!"=="PASS" if "!T16_SOURCE!"=="PASS" if "!T16_EXIT!"=="0" set "T16=PASS"

if "!T16!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 17 - DirCreate Return Contract...
set /a TOTAL+=1

if exist "Working\Test17" rmdir /s /q "Working\Test17"
mkdir "Working\Test17" >nul 2>&1

set "T17=FAIL"
set "T17_SINGLE_CREATED=FAIL"
set "T17_SINGLE_STATUS=FAIL"
set "T17_FAILURE_RETAINED=FAIL"
set "T17_LATER_CREATED=FAIL"

set "T17_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T17_PROBE=%CD%\..\_Issue18_DirCreate_Probe.au3"

if exist "!T17_PROBE!" del /q "!T17_PROBE!" >nul 2>&1

if exist "!T17_AUTOIT!" (
    copy /y "Helpers\Issue18_DirCreate_Probe.au3" "!T17_PROBE!" >nul 2>&1

    if exist "!T17_PROBE!" (
        pushd ".."
        "!T17_AUTOIT!" "_Issue18_DirCreate_Probe.au3" >nul 2>&1
        set "T17_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T17_EXIT=99"
    )
) else (
    set "T17_EXIT=98"
)

if exist "!T17_PROBE!" del /q "!T17_PROBE!" >nul 2>&1

findstr /x /c:"Single directory created: PASS" "Working\Test17\Probe.log" >nul 2>&1
if not errorlevel 1 set "T17_SINGLE_CREATED=PASS"

findstr /x /c:"Successful call reports success: PASS" "Working\Test17\Probe.log" >nul 2>&1
if not errorlevel 1 set "T17_SINGLE_STATUS=PASS"

findstr /x /c:"Earlier create failure retained: PASS" "Working\Test17\Probe.log" >nul 2>&1
if not errorlevel 1 set "T17_FAILURE_RETAINED=PASS"

findstr /x /c:"Later valid directories created: PASS" "Working\Test17\Probe.log" >nul 2>&1
if not errorlevel 1 set "T17_LATER_CREATED=PASS"

if "!T17_SINGLE_CREATED!"=="PASS" if "!T17_SINGLE_STATUS!"=="PASS" if "!T17_FAILURE_RETAINED!"=="PASS" if "!T17_LATER_CREATED!"=="PASS" if "!T17_EXIT!"=="0" set "T17=PASS"

if "!T17!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 18 - FileDelete Return Contract...
set /a TOTAL+=1

if exist "Working\Test18" rmdir /s /q "Working\Test18"
mkdir "Working\Test18" >nul 2>&1

set "T18=FAIL"
set "T18_SINGLE_DELETED=FAIL"
set "T18_SINGLE_STATUS=FAIL"
set "T18_FAILURE_RETAINED=FAIL"
set "T18_FAILED_PRESERVED=FAIL"
set "T18_LATER_DELETED=FAIL"

set "T18_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T18_PROBE=%CD%\..\_Issue19_FileDelete_Probe.au3"

if exist "!T18_PROBE!" del /q "!T18_PROBE!" >nul 2>&1

if exist "!T18_AUTOIT!" (
    copy /y "Helpers\Issue19_FileDelete_Probe.au3" "!T18_PROBE!" >nul 2>&1

    if exist "!T18_PROBE!" (
        pushd ".."
        "!T18_AUTOIT!" "_Issue19_FileDelete_Probe.au3" >nul 2>&1
        set "T18_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T18_EXIT=99"
    )
) else (
    set "T18_EXIT=98"
)

if exist "!T18_PROBE!" del /q "!T18_PROBE!" >nul 2>&1

findstr /x /c:"Single file deleted: PASS" "Working\Test18\Probe.log" >nul 2>&1
if not errorlevel 1 set "T18_SINGLE_DELETED=PASS"

findstr /x /c:"Successful delete reports success: PASS" "Working\Test18\Probe.log" >nul 2>&1
if not errorlevel 1 set "T18_SINGLE_STATUS=PASS"

findstr /x /c:"Earlier delete failure retained: PASS" "Working\Test18\Probe.log" >nul 2>&1
if not errorlevel 1 set "T18_FAILURE_RETAINED=PASS"

findstr /x /c:"Failed target preserved: PASS" "Working\Test18\Probe.log" >nul 2>&1
if not errorlevel 1 set "T18_FAILED_PRESERVED=PASS"

findstr /x /c:"Later valid file deleted: PASS" "Working\Test18\Probe.log" >nul 2>&1
if not errorlevel 1 set "T18_LATER_DELETED=PASS"

if "!T18_SINGLE_DELETED!"=="PASS" if "!T18_SINGLE_STATUS!"=="PASS" if "!T18_FAILURE_RETAINED!"=="PASS" if "!T18_FAILED_PRESERVED!"=="PASS" if "!T18_LATER_DELETED!"=="PASS" if "!T18_EXIT!"=="0" set "T18=PASS"

if "!T18!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 19 - FileCopy Return Contract...
set /a TOTAL+=1

if exist "Working\Test19" rmdir /s /q "Working\Test19"
mkdir "Working\Test19" >nul 2>&1

set "T19=FAIL"
set "T19_SINGLE_COPIED=FAIL"
set "T19_SINGLE_STATUS=FAIL"
set "T19_FAILURE_RETAINED=FAIL"
set "T19_LATER_COPIED=FAIL"
set "T19_MISSING_ABSENT=FAIL"

set "T19_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T19_PROBE=%CD%\..\_Issue20_FileCopy_Probe.au3"

if exist "!T19_PROBE!" del /q "!T19_PROBE!" >nul 2>&1

if exist "!T19_AUTOIT!" (
    copy /y "Helpers\Issue20_FileCopy_Probe.au3" "!T19_PROBE!" >nul 2>&1

    if exist "!T19_PROBE!" (
        pushd ".."
        "!T19_AUTOIT!" "_Issue20_FileCopy_Probe.au3" >nul 2>&1
        set "T19_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T19_EXIT=99"
    )
) else (
    set "T19_EXIT=98"
)

if exist "!T19_PROBE!" del /q "!T19_PROBE!" >nul 2>&1

findstr /x /c:"Single file copied: PASS" "Working\Test19\Probe.log" >nul 2>&1
if not errorlevel 1 set "T19_SINGLE_COPIED=PASS"

findstr /x /c:"Successful copy reports success: PASS" "Working\Test19\Probe.log" >nul 2>&1
if not errorlevel 1 set "T19_SINGLE_STATUS=PASS"

findstr /x /c:"Earlier copy failure retained: PASS" "Working\Test19\Probe.log" >nul 2>&1
if not errorlevel 1 set "T19_FAILURE_RETAINED=PASS"

findstr /x /c:"Later valid file copied: PASS" "Working\Test19\Probe.log" >nul 2>&1
if not errorlevel 1 set "T19_LATER_COPIED=PASS"

findstr /x /c:"Missing source not fabricated: PASS" "Working\Test19\Probe.log" >nul 2>&1
if not errorlevel 1 set "T19_MISSING_ABSENT=PASS"

if "!T19_SINGLE_COPIED!"=="PASS" if "!T19_SINGLE_STATUS!"=="PASS" if "!T19_FAILURE_RETAINED!"=="PASS" if "!T19_LATER_COPIED!"=="PASS" if "!T19_MISSING_ABSENT!"=="PASS" if "!T19_EXIT!"=="0" set "T19=PASS"

if "!T19!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 20 - FirstRun Required Operation Failure...
set /a TOTAL+=1

if exist "Working\Test20A" rmdir /s /q "Working\Test20A"
if exist "Working\Test20B" rmdir /s /q "Working\Test20B"

mkdir "Working\Test20A\Source" >nul 2>&1
mkdir "Working\Test20A\Destination" >nul 2>&1
mkdir "Working\Test20A\Temp" >nul 2>&1
mkdir "Working\Test20B\Temp" >nul 2>&1

copy /y "Configs\20A_FirstRun_Required_Failure.template.ini" "Working\Test20A\Test.ini" >nul
copy /y "Configs\20B_FirstRun_Success.template.ini" "Working\Test20B\Test.ini" >nul

> "Working\Test20A\Payload.bat" echo @echo off
>>"Working\Test20A\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test20A\Payload.bat" echo exit /b 0

> "Working\Test20B\Payload.bat" echo @echo off
>>"Working\Test20B\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test20B\Payload.bat" echo exit /b 0

copy /y "%LAUNCHER%" "Issue21Fail_Launcher.exe" >nul
copy /y "%LAUNCHER%" "Issue21Success_Launcher.exe" >nul

set "T20_FAIL_RETAINED=FAIL"
set "T20_FAIL_BLOCKED=FAIL"
set "T20_SUCCESS_CLEARED=FAIL"
set "T20_SUCCESS_OPERATION=FAIL"
set "T20_SUCCESS_PAYLOAD=FAIL"
set "T20_SUCCESS_EXIT=99"

start "" "Issue21Fail_Launcher.exe" "--x-launcher-config=%CD%\Working\Test20A\Test.ini"

rem A repaired launcher displays its existing FirstRun error message and waits.
rem A defective launcher continues and runs the payload. Give either path time
rem to establish its externally visible state, then terminate only this test copy.
timeout /t 4 /nobreak >nul

powershell.exe -NoProfile -Command "$c=Get-Content -LiteralPath 'Working\Test20A\Test.ini'; if($c -match '^\s*FirstRun\s*=\s*true\s*$'){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 set "T20_FAIL_RETAINED=PASS"

if not exist "Working\Test20A\PayloadRan.txt" set "T20_FAIL_BLOCKED=PASS"

taskkill /f /im Issue21Fail_Launcher.exe >nul 2>&1
taskkill /f /im Payload.bat >nul 2>&1

"Issue21Success_Launcher.exe" "--x-launcher-config=%CD%\Working\Test20B\Test.ini" >nul 2>&1
set "T20_SUCCESS_EXIT=!ERRORLEVEL!"

powershell.exe -NoProfile -Command "$c=Get-Content -LiteralPath 'Working\Test20B\Test.ini'; if($c -match '^\s*FirstRun\s*=\s*false\s*$'){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 set "T20_SUCCESS_CLEARED=PASS"

if exist "Working\Test20B\CreatedByFirstRun" set "T20_SUCCESS_OPERATION=PASS"
if exist "Working\Test20B\PayloadRan.txt" set "T20_SUCCESS_PAYLOAD=PASS"

set "T20=FAIL"
if "!T20_FAIL_RETAINED!"=="PASS" if "!T20_FAIL_BLOCKED!"=="PASS" if "!T20_SUCCESS_CLEARED!"=="PASS" if "!T20_SUCCESS_OPERATION!"=="PASS" if "!T20_SUCCESS_PAYLOAD!"=="PASS" if "!T20_SUCCESS_EXIT!"=="0" set "T20=PASS"

if "!T20!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

del /q "Issue21Fail_Launcher.exe" >nul 2>&1
del /q "Issue21Success_Launcher.exe" >nul 2>&1

echo Running Test 21 - Temp Root Deletion Safety...
set /a TOTAL+=1

if exist "Working\Test21" rmdir /s /q "Working\Test21"
mkdir "Working\Test21\ProtectedRoot" >nul 2>&1

> "Working\Test21\ProtectedRoot\Payload.bat" echo @echo off
>>"Working\Test21\ProtectedRoot\Payload.bat" echo ^> "%%~dp0..\PayloadRan.txt" echo RAN
>>"Working\Test21\ProtectedRoot\Payload.bat" echo exit /b 0

> "Working\Test21\ProtectedRoot\Sentinel.txt" echo ROOT_MUST_SURVIVE

"%LAUNCHER%" "--x-launcher-config=%CD%\Configs\21_Temp_Root_Deletion_Safety.ini" >nul 2>&1
set "T21_EXIT=!ERRORLEVEL!"

set "T21_PAYLOAD=FAIL"
set "T21_ROOT=FAIL"
set "T21_SENTINEL=FAIL"

if exist "Working\Test21\PayloadRan.txt" set "T21_PAYLOAD=PASS"
if exist "Working\Test21\ProtectedRoot" set "T21_ROOT=PASS"

findstr /x /c:"ROOT_MUST_SURVIVE" "Working\Test21\ProtectedRoot\Sentinel.txt" >nul 2>&1
if not errorlevel 1 set "T21_SENTINEL=PASS"

set "T21=FAIL"
if "!T21_PAYLOAD!"=="PASS" if "!T21_ROOT!"=="PASS" if "!T21_SENTINEL!"=="PASS" if "!T21_EXIT!"=="0" set "T21=PASS"

if "!T21!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 22 - Splash Fallback Temp Parameter...
set /a TOTAL+=1

if exist "Working\Test22" rmdir /s /q "Working\Test22"

set "T22=FAIL"
set "T22_SUPPLIED_TEMP=FAIL"
set "T22_WRONG_GLOBAL=FAIL"

set "T22_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T22_PROBE=%CD%\..\_Issue12_SplashFallback_Probe.au3"

if exist "!T22_PROBE!" del /q "!T22_PROBE!" >nul 2>&1

if exist "!T22_AUTOIT!" (
    copy /y "Helpers\Issue12_SplashFallback_Probe.au3" "!T22_PROBE!" >nul 2>&1

    if exist "!T22_PROBE!" (
        pushd ".."
        "!T22_AUTOIT!" "_Issue12_SplashFallback_Probe.au3" >nul 2>&1
        set "T22_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T22_EXIT=99"
    )
) else (
    set "T22_EXIT=98"
)

if exist "!T22_PROBE!" del /q "!T22_PROBE!" >nul 2>&1

findstr /x /c:"Fallback stored in supplied Temp: PASS" "Working\Test22\Probe.log" >nul 2>&1
if not errorlevel 1 set "T22_SUPPLIED_TEMP=PASS"

findstr /x /c:"Wrong global temp unused: PASS" "Working\Test22\Probe.log" >nul 2>&1
if not errorlevel 1 set "T22_WRONG_GLOBAL=PASS"

if "!T22_SUPPLIED_TEMP!"=="PASS" if "!T22_WRONG_GLOBAL!"=="PASS" if "!T22_EXIT!"=="0" set "T22=PASS"

if "!T22!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 23 - Splash Does Not Delay Startup...
set /a TOTAL+=1

if exist "Working\Test23" rmdir /s /q "Working\Test23"
mkdir "Working\Test23\Temp" >nul 2>&1

> "Working\Test23\Payload.bat" echo @echo off
>>"Working\Test23\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test23\Payload.bat" echo exit /b 0

copy /y "%LAUNCHER%" "Issue13_Launcher.exe" >nul

set "T23_START=FAIL"

start "" "Issue13_Launcher.exe" "--x-launcher-config=%CD%\Configs\23_Splash_Nonblocking.ini" >nul 2>&1
timeout /t 2 /nobreak >nul

if exist "Working\Test23\PayloadRan.txt" set "T23_START=PASS"

set "T23=FAIL"
if "!T23_START!"=="PASS" set "T23=PASS"

if "!T23!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

taskkill /f /im Issue13_Launcher.exe >nul 2>&1
del /q "Issue13_Launcher.exe" >nul 2>&1

echo Running Test 24 - Splash Title and Dimensions...
set /a TOTAL+=1

if exist "Working\Test24" rmdir /s /q "Working\Test24"

set "T24=FAIL"
set "T24_TITLE=FAIL"
set "T24_WIDTH=FAIL"
set "T24_HEIGHT=FAIL"
set "T24_FIXTURE=FAIL"
set "T24_DETECT=FAIL"
set "T24_NATURAL_WIDTH=FAIL"
set "T24_NATURAL_HEIGHT=FAIL"
set "T24_WIDTH_ASPECT=FAIL"
set "T24_HEIGHT_ASPECT=FAIL"

set "T24_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T24_PROBE=%CD%\..\_Issue14_SplashSettings_Probe.au3"

if exist "!T24_PROBE!" del /q "!T24_PROBE!" >nul 2>&1

if exist "!T24_AUTOIT!" (
    copy /y "Helpers\Issue14_SplashSettings_Probe.au3" "!T24_PROBE!" >nul 2>&1

    if exist "!T24_PROBE!" (
        pushd ".."
        "!T24_AUTOIT!" "_Issue14_SplashSettings_Probe.au3" >nul 2>&1
        set "T24_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T24_EXIT=99"
    )
) else (
    set "T24_EXIT=98"
)

if exist "!T24_PROBE!" del /q "!T24_PROBE!" >nul 2>&1

findstr /x /c:"Configured splash title used: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_TITLE=PASS"

findstr /x /c:"Configured splash width used: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_WIDTH=PASS"

findstr /x /c:"Configured splash height used: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_HEIGHT=PASS"

findstr /x /c:"Natural-size splash fixture created: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_FIXTURE=PASS"

findstr /x /c:"Image dimensions detected: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_DETECT=PASS"

findstr /x /c:"Blank width used natural image width: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_NATURAL_WIDTH=PASS"

findstr /x /c:"Blank height used natural image height: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_NATURAL_HEIGHT=PASS"

findstr /x /c:"Blank height preserved image aspect ratio: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_WIDTH_ASPECT=PASS"

findstr /x /c:"Blank width preserved image aspect ratio: PASS" "Working\Test24\Probe.log" >nul 2>&1
if not errorlevel 1 set "T24_HEIGHT_ASPECT=PASS"

if "!T24_TITLE!"=="PASS" if "!T24_WIDTH!"=="PASS" if "!T24_HEIGHT!"=="PASS" if "!T24_FIXTURE!"=="PASS" if "!T24_DETECT!"=="PASS" if "!T24_NATURAL_WIDTH!"=="PASS" if "!T24_NATURAL_HEIGHT!"=="PASS" if "!T24_WIDTH_ASPECT!"=="PASS" if "!T24_HEIGHT_ASPECT!"=="PASS" if "!T24_EXIT!"=="0" set "T24=PASS"

if "!T24!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 25 - Automatic Language Result...
set /a TOTAL+=1

if exist "Working\Test25" rmdir /s /q "Working\Test25"
mkdir "Working\Test25\Temp" >nul 2>&1
del /q "25_Automatic_Language.log" >nul 2>&1

> "Working\Test25\Payload.bat" echo @echo off
>>"Working\Test25\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test25\Payload.bat" echo exit /b 0

set "T25_OLD_LANG=!LANG!"
set "LANG=it"

"%LAUNCHER%" "--x-launcher-config=%CD%\Configs\25_Automatic_Language.ini" >nul 2>&1
set "T25_EXIT=!ERRORLEVEL!"

set "LANG=!T25_OLD_LANG!"

set "T25_LANG=FAIL"
set "T25_PAYLOAD=FAIL"

findstr /i /x /c:"Lang=it" "25_Automatic_Language.log" >nul 2>&1
if not errorlevel 1 set "T25_LANG=PASS"

if exist "Working\Test25\PayloadRan.txt" set "T25_PAYLOAD=PASS"

set "T25=FAIL"
if "!T25_LANG!"=="PASS" if "!T25_PAYLOAD!"=="PASS" if "!T25_EXIT!"=="0" set "T25=PASS"

if "!T25!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 26 - TrayTip Timeout Key Compatibility...
set /a TOTAL+=1

if exist "Working\Test26" rmdir /s /q "Working\Test26"
mkdir "Working\Test26" >nul 2>&1

set "T26=FAIL"
set "T26_STANDARD=FAIL"
set "T26_LEGACY=FAIL"

set "T26_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T26_PROBE=%CD%\..\_Issue16_TrayTipTimeoutKey_Probe.au3"

if exist "!T26_PROBE!" del /q "!T26_PROBE!" >nul 2>&1

if exist "!T26_AUTOIT!" (
    copy /y "Helpers\Issue16_TrayTipTimeoutKey_Probe.au3" "!T26_PROBE!" >nul 2>&1

    if exist "!T26_PROBE!" (
        pushd ".."
        "!T26_AUTOIT!" "_Issue16_TrayTipTimeoutKey_Probe.au3" >nul 2>&1
        set "T26_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T26_EXIT=99"
    )
) else (
    set "T26_EXIT=98"
)

if exist "!T26_PROBE!" del /q "!T26_PROBE!" >nul 2>&1

findstr /x /c:"Documented Timeout key read first: PASS" "Working\Test26\Probe.log" >nul 2>&1
if not errorlevel 1 set "T26_STANDARD=PASS"

findstr /x /c:"Legacy trailing-space key retained as fallback: PASS" "Working\Test26\Probe.log" >nul 2>&1
if not errorlevel 1 set "T26_LEGACY=PASS"

if "!T26_STANDARD!"=="PASS" if "!T26_LEGACY!"=="PASS" if "!T26_EXIT!"=="0" set "T26=PASS"

if "!T26!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 27 - TrayTip Duration Units...
set /a TOTAL+=1

if exist "Working\Test27" rmdir /s /q "Working\Test27"
mkdir "Working\Test27" >nul 2>&1

set "T27=FAIL"
set "T27_CONVERTED=FAIL"
set "T27_TRAYTIP=FAIL"
set "T27_CALLBACK=FAIL"

set "T27_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T27_PROBE=%CD%\..\_Issue17_TrayTipDuration_Probe.au3"

if exist "!T27_PROBE!" del /q "!T27_PROBE!" >nul 2>&1

if exist "!T27_AUTOIT!" (
    copy /y "Helpers\Issue17_TrayTipDuration_Probe.au3" "!T27_PROBE!" >nul 2>&1

    if exist "!T27_PROBE!" (
        pushd ".."
        "!T27_AUTOIT!" "_Issue17_TrayTipDuration_Probe.au3" >nul 2>&1
        set "T27_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T27_EXIT=99"
    )
) else (
    set "T27_EXIT=98"
)

if exist "!T27_PROBE!" del /q "!T27_PROBE!" >nul 2>&1

findstr /x /c:"Configured milliseconds converted to TrayTip seconds: PASS" "Working\Test27\Probe.log" >nul 2>&1
if not errorlevel 1 set "T27_CONVERTED=PASS"

findstr /x /c:"TrayTip uses converted timeout: PASS" "Working\Test27\Probe.log" >nul 2>&1
if not errorlevel 1 set "T27_TRAYTIP=PASS"

findstr /x /c:"Callback retains millisecond timeout: PASS" "Working\Test27\Probe.log" >nul 2>&1
if not errorlevel 1 set "T27_CALLBACK=PASS"

if "!T27_CONVERTED!"=="PASS" if "!T27_TRAYTIP!"=="PASS" if "!T27_CALLBACK!"=="PASS" if "!T27_EXIT!"=="0" set "T27=PASS"

if "!T27!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 28 - StringRegExp Counter Option...
set /a TOTAL+=1

if exist "Working\Test28" rmdir /s /q "Working\Test28"
mkdir "Working\Test28" >nul 2>&1

set "T28=FAIL"
set "T28_LIMITED=FAIL"
set "T28_STATUS=FAIL"

set "T28_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T28_PROBE=%CD%\..\_Issue22_StringRegExpCounter_Probe.au3"

if exist "!T28_PROBE!" del /q "!T28_PROBE!" >nul 2>&1

if exist "!T28_AUTOIT!" (
    copy /y "Helpers\Issue22_StringRegExpCounter_Probe.au3" "!T28_PROBE!" >nul 2>&1

    if exist "!T28_PROBE!" (
        pushd ".."
        "!T28_AUTOIT!" "_Issue22_StringRegExpCounter_Probe.au3" >nul 2>&1
        set "T28_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T28_EXIT=99"
    )
) else (
    set "T28_EXIT=98"
)

if exist "!T28_PROBE!" del /q "!T28_PROBE!" >nul 2>&1

findstr /x /c:"Counter limits replacements to configured number: PASS" "Working\Test28\Probe.log" >nul 2>&1
if not errorlevel 1 set "T28_LIMITED=PASS"

findstr /x /c:"Limited replacement call reports success: PASS" "Working\Test28\Probe.log" >nul 2>&1
if not errorlevel 1 set "T28_STATUS=PASS"

if "!T28_LIMITED!"=="PASS" if "!T28_STATUS!"=="PASS" if "!T28_EXIT!"=="0" set "T28=PASS"

if "!T28!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 29 - Hidden EXE Command-Line Quoting...
set /a TOTAL+=1

if exist "Working\Test29" rmdir /s /q "Working\Test29"
mkdir "Working\Test29\Temp" >nul 2>&1

set "T29=FAIL"
set "T29_COMPILE=FAIL"
set "T29_COUNT=FAIL"
set "T29_OPTION=FAIL"
set "T29_META=FAIL"
set "T29_FORWARD_COUNT=FAIL"
set "T29_FORWARD_VALUE=FAIL"

set "T29_AUT2EXE=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\Aut2Exe\Aut2exe_x64.exe"
set "T29_SOURCE=%CD%\Helpers\Issue28_CommandLine_Probe.au3"
set "T29_PAYLOAD=%CD%\Working\Test29\Hidden Argument Probe.exe"

if exist "!T29_AUT2EXE!" if exist "!T29_SOURCE!" (
    "!T29_AUT2EXE!" /in "!T29_SOURCE!" /out "!T29_PAYLOAD!" /x64 >nul 2>&1
    set "T29_COMPILE_EXIT=!ERRORLEVEL!"
) else (
    set "T29_COMPILE_EXIT=98"
)

if "!T29_COMPILE_EXIT!"=="0" if exist "!T29_PAYLOAD!" set "T29_COMPILE=PASS"

if "!T29_COMPILE!"=="PASS" (
    start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\29_Command_Line_Quoting.ini" >nul 2>&1
    set "T29_EXIT=!ERRORLEVEL!"
) else (
    set "T29_EXIT=99"
)

findstr /x /l /c:"ARG_COUNT=2" "Working\Test29\Arguments.log" >nul 2>&1
if not errorlevel 1 set "T29_COUNT=PASS"

findstr /x /l /c:"ARG_1=--mode" "Working\Test29\Arguments.log" >nul 2>&1
if not errorlevel 1 set "T29_OPTION=PASS"

findstr /x /l /c:"ARG_2=alpha&beta" "Working\Test29\Arguments.log" >nul 2>&1
if not errorlevel 1 set "T29_META=PASS"

if exist "Working\Test29\Arguments.log" del /q "Working\Test29\Arguments.log" >nul 2>&1

if "!T29_COMPILE!"=="PASS" (
    start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\29B_Forwarded_Option_Quoting.ini" "--label value" >nul 2>&1
    set "T29_FORWARD_EXIT=!ERRORLEVEL!"
) else (
    set "T29_FORWARD_EXIT=99"
)

findstr /x /l /c:"ARG_COUNT=1" "Working\Test29\Arguments.log" >nul 2>&1
if not errorlevel 1 set "T29_FORWARD_COUNT=PASS"

findstr /x /l /c:"ARG_1=--label value" "Working\Test29\Arguments.log" >nul 2>&1
if not errorlevel 1 set "T29_FORWARD_VALUE=PASS"

if "!T29_COMPILE!"=="PASS" if "!T29_COUNT!"=="PASS" if "!T29_OPTION!"=="PASS" if "!T29_META!"=="PASS" if "!T29_FORWARD_COUNT!"=="PASS" if "!T29_FORWARD_VALUE!"=="PASS" if "!T29_EXIT!"=="0" if "!T29_FORWARD_EXIT!"=="0" set "T29=PASS"

if "!T29!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 30 - Text Rewrite Format Preservation...
set /a TOTAL+=1

if exist "Working\Test30" rmdir /s /q "Working\Test30"
mkdir "Working\Test30" >nul 2>&1

set "T30=FAIL"
set "T30_STRING=FAIL"
set "T30_REGEXP=FAIL"
set "T30_FILE=FAIL"
set "T30_PREF=FAIL"
set "T30_MOZ=FAIL"

set "T30_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T30_PROBE=%CD%\..\_Issue29_TextFormat_Probe.au3"

if exist "!T30_PROBE!" del /q "!T30_PROBE!" >nul 2>&1

if exist "!T30_AUTOIT!" (
    copy /y "Helpers\Issue29_TextFormat_Probe.au3" "!T30_PROBE!" >nul 2>&1
    if exist "!T30_PROBE!" (
        pushd ".."
        "!T30_AUTOIT!" "_Issue29_TextFormat_Probe.au3" >nul 2>&1
        set "T30_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T30_EXIT=99"
    )
) else (
    set "T30_EXIT=98"
)

if exist "!T30_PROBE!" del /q "!T30_PROBE!" >nul 2>&1

findstr /x /c:"StringReplace preserves UTF-8 BOM LF and trailing blank line: PASS" "Working\Test30\Probe.log" >nul 2>&1
if not errorlevel 1 set "T30_STRING=PASS"

findstr /x /c:"StringRegExpReplace preserves UTF-8 BOM LF and trailing blank line: PASS" "Working\Test30\Probe.log" >nul 2>&1
if not errorlevel 1 set "T30_REGEXP=PASS"

findstr /x /c:"WriteToFile preserves UTF-8 BOM LF and trailing blank line: PASS" "Working\Test30\Probe.log" >nul 2>&1
if not errorlevel 1 set "T30_FILE=PASS"

findstr /x /c:"WriteToPref preserves UTF-8 BOM LF and trailing blank line: PASS" "Working\Test30\Probe.log" >nul 2>&1
if not errorlevel 1 set "T30_PREF=PASS"

findstr /x /c:"MozPrefs preserves UTF-8 BOM LF and trailing blank line: PASS" "Working\Test30\Probe.log" >nul 2>&1
if not errorlevel 1 set "T30_MOZ=PASS"

if "!T30_STRING!"=="PASS" if "!T30_REGEXP!"=="PASS" if "!T30_FILE!"=="PASS" if "!T30_PREF!"=="PASS" if "!T30_MOZ!"=="PASS" if "!T30_EXIT!"=="0" set "T30=PASS"

if "!T30!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 31 - MozPrefs Exact Preference Matching...
set /a TOTAL+=1

if exist "Working\Test31" rmdir /s /q "Working\Test31"
mkdir "Working\Test31" >nul 2>&1

set "T31=FAIL"
set "T31_USER=FAIL"
set "T31_GLOBAL=FAIL"

set "T31_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T31_PROBE=%CD%\..\_Issue30_MozPrefsExactMatch_Probe.au3"

if exist "!T31_PROBE!" del /q "!T31_PROBE!" >nul 2>&1

if exist "!T31_AUTOIT!" (
    copy /y "Helpers\Issue30_MozPrefsExactMatch_Probe.au3" "!T31_PROBE!" >nul 2>&1
    if exist "!T31_PROBE!" (
        pushd ".."
        "!T31_AUTOIT!" "_Issue30_MozPrefsExactMatch_Probe.au3" >nul 2>&1
        set "T31_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T31_EXIT=99"
    )
) else (
    set "T31_EXIT=98"
)

if exist "!T31_PROBE!" del /q "!T31_PROBE!" >nul 2>&1

findstr /x /c:"User preference exact match only: PASS" "Working\Test31\Probe.log" >nul 2>&1
if not errorlevel 1 set "T31_USER=PASS"

findstr /x /c:"Global preference exact match only: PASS" "Working\Test31\Probe.log" >nul 2>&1
if not errorlevel 1 set "T31_GLOBAL=PASS"

if "!T31_USER!"=="PASS" if "!T31_GLOBAL!"=="PASS" if "!T31_EXIT!"=="0" set "T31=PASS"

if "!T31!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 32 - Multi-Path Relative Path Consistency...
set /a TOTAL+=1

if exist "Working\Test32" rmdir /s /q "Working\Test32"
mkdir "Working\Test32" >nul 2>&1

set "T32=FAIL"
set "T32_ORDINARY=FAIL"
set "T32_WILDCARD=FAIL"
set "T32_WORKDIR=FAIL"

set "T32_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T32_PROBE=%CD%\..\_Issue31_ExpandMultiPath_Probe.au3"

if exist "!T32_PROBE!" del /q "!T32_PROBE!" >nul 2>&1

if exist "!T32_AUTOIT!" (
    copy /y "Helpers\Issue31_ExpandMultiPath_Probe.au3" "!T32_PROBE!" >nul 2>&1
    if exist "!T32_PROBE!" (
        pushd ".."
        "!T32_AUTOIT!" "_Issue31_ExpandMultiPath_Probe.au3" >nul 2>&1
        set "T32_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T32_EXIT=99"
    )
) else (
    set "T32_EXIT=98"
)

if exist "!T32_PROBE!" del /q "!T32_PROBE!" >nul 2>&1

findstr /x /c:"Ordinary path normalized against Root: PASS" "Working\Test32\Probe.log" >nul 2>&1
if not errorlevel 1 set "T32_ORDINARY=PASS"

findstr /x /c:"Wildcard path normalized against Root: PASS" "Working\Test32\Probe.log" >nul 2>&1
if not errorlevel 1 set "T32_WILDCARD=PASS"

findstr /x /c:"OnlyIfExist independent of working directory: PASS" "Working\Test32\Probe.log" >nul 2>&1
if not errorlevel 1 set "T32_WORKDIR=PASS"

if "!T32_ORDINARY!"=="PASS" if "!T32_WILDCARD!"=="PASS" if "!T32_WORKDIR!"=="PASS" if "!T32_EXIT!"=="0" set "T32=PASS"

if "!T32!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 33 - UNC Path Preservation...
set /a TOTAL+=1

if exist "Working\Test33" rmdir /s /q "Working\Test33"
mkdir "Working\Test33" >nul 2>&1

set "T33=FAIL"
set "T33_FULLPATH=FAIL"
set "T33_NORMALPATH=FAIL"
set "T33_SLASHUNC=FAIL"
set "T33_FILEINFO=FAIL"

set "T33_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T33_PROBE=%CD%\..\_Issue32_UNCPath_Probe.au3"

if exist "!T33_PROBE!" del /q "!T33_PROBE!" >nul 2>&1

if exist "!T33_AUTOIT!" (
    copy /y "Helpers\Issue32_UNCPath_Probe.au3" "!T33_PROBE!" >nul 2>&1
    if exist "!T33_PROBE!" (
        pushd ".."
        "!T33_AUTOIT!" "_Issue32_UNCPath_Probe.au3" >nul 2>&1
        set "T33_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T33_EXIT=99"
    )
) else (
    set "T33_EXIT=98"
)

if exist "!T33_PROBE!" del /q "!T33_PROBE!" >nul 2>&1

findstr /x /c:"FullPath direct UNC retained: PASS" "Working\Test33\Probe.log" >nul 2>&1
if not errorlevel 1 set "T33_FULLPATH=PASS"

findstr /x /c:"NormalPath UNC prefix retained: PASS" "Working\Test33\Probe.log" >nul 2>&1
if not errorlevel 1 set "T33_NORMALPATH=PASS"

findstr /x /c:"Forward-slash UNC normalized safely: PASS" "Working\Test33\Probe.log" >nul 2>&1
if not errorlevel 1 set "T33_SLASHUNC=PASS"

findstr /x /c:"FileInfo UNC parent retained: PASS" "Working\Test33\Probe.log" >nul 2>&1
if not errorlevel 1 set "T33_FILEINFO=PASS"

if "!T33_FULLPATH!"=="PASS" if "!T33_NORMALPATH!"=="PASS" if "!T33_SLASHUNC!"=="PASS" if "!T33_FILEINFO!"=="PASS" if "!T33_EXIT!"=="0" set "T33=PASS"

if "!T33!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 34 - FixDriveLetter Safety and Scope...
set /a TOTAL+=1

if exist "Working\Test34" rmdir /s /q "Working\Test34"
mkdir "Working\Test34" >nul 2>&1

set "T34=FAIL"
set "T34_VALID=FAIL"
set "T34_EMBEDDED=FAIL"
set "T34_URL=FAIL"
set "T34_NONDRIVE=FAIL"

set "T34_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T34_PROBE=%CD%\..\_Issue33_FixDriveLetter_Probe.au3"

if exist "!T34_PROBE!" del /q "!T34_PROBE!" >nul 2>&1

if exist "!T34_AUTOIT!" (
    copy /y "Helpers\Issue33_FixDriveLetter_Probe.au3" "!T34_PROBE!" >nul 2>&1
    if exist "!T34_PROBE!" (
        pushd ".."
        "!T34_AUTOIT!" /ErrorStdOut "_Issue33_FixDriveLetter_Probe.au3" >nul 2>&1
        set "T34_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T34_EXIT=99"
    )
) else (
    set "T34_EXIT=98"
)

if exist "!T34_PROBE!" del /q "!T34_PROBE!" >nul 2>&1

findstr /x /c:"Valid absolute path rewritten: PASS" "Working\Test34\Probe.log" >nul 2>&1
if not errorlevel 1 set "T34_VALID=PASS"

findstr /x /c:"Embedded drive-like text preserved: PASS" "Working\Test34\Probe.log" >nul 2>&1
if not errorlevel 1 set "T34_EMBEDDED=PASS"

findstr /x /c:"URL drive-like segment preserved: PASS" "Working\Test34\Probe.log" >nul 2>&1
if not errorlevel 1 set "T34_URL=PASS"

findstr /x /c:"Non-drive Root rejected safely: PASS" "Working\Test34\Probe.log" >nul 2>&1
if not errorlevel 1 set "T34_NONDRIVE=PASS"

if "!T34_VALID!"=="PASS" if "!T34_EMBEDDED!"=="PASS" if "!T34_URL!"=="PASS" if "!T34_NONDRIVE!"=="PASS" if "!T34_EXIT!"=="0" set "T34=PASS"

if "!T34!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 35 - FixUserProfile Source Safety...
set /a TOTAL+=1

if exist "Working\Test35" rmdir /s /q "Working\Test35"
mkdir "Working\Test35" >nul 2>&1

set "T35=FAIL"
set "T35_VALID=FAIL"
set "T35_EMPTY=FAIL"
set "T35_TRAVERSAL=FAIL"
set "T35_NESTED=FAIL"

set "T35_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T35_PROBE=%CD%\..\_Issue34_FixUserProfile_Probe.au3"

if exist "!T35_PROBE!" del /q "!T35_PROBE!" >nul 2>&1

if exist "!T35_AUTOIT!" (
    copy /y "Helpers\Issue34_FixUserProfile_Probe.au3" "!T35_PROBE!" >nul 2>&1
    if exist "!T35_PROBE!" (
        pushd ".."
        "!T35_AUTOIT!" /ErrorStdOut "_Issue34_FixUserProfile_Probe.au3" >nul 2>&1
        set "T35_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T35_EXIT=99"
    )
) else (
    set "T35_EXIT=98"
)

if exist "!T35_PROBE!" del /q "!T35_PROBE!" >nul 2>&1

findstr /x /c:"Valid child directory renamed: PASS" "Working\Test35\Probe.log" >nul 2>&1
if not errorlevel 1 set "T35_VALID=PASS"

findstr /x /c:"Empty old value preserves profile root: PASS" "Working\Test35\Probe.log" >nul 2>&1
if not errorlevel 1 set "T35_EMPTY=PASS"

findstr /x /c:"Parent traversal source rejected: PASS" "Working\Test35\Probe.log" >nul 2>&1
if not errorlevel 1 set "T35_TRAVERSAL=PASS"

findstr /x /c:"Nested old source rejected: PASS" "Working\Test35\Probe.log" >nul 2>&1
if not errorlevel 1 set "T35_NESTED=PASS"

if "!T35_VALID!"=="PASS" if "!T35_EMPTY!"=="PASS" if "!T35_TRAVERSAL!"=="PASS" if "!T35_NESTED!"=="PASS" if "!T35_EXIT!"=="0" set "T35=PASS"

if "!T35!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 36 - FullPath Excessive Traversal Handling...
set /a TOTAL+=1

if exist "Working\Test36" rmdir /s /q "Working\Test36"
mkdir "Working\Test36" >nul 2>&1

set "T36=FAIL"
set "T36_VALID=FAIL"
set "T36_FAILURE=FAIL"
set "T36_SURVIVES=FAIL"

set "T36_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T36_PROBE=%CD%\..\_Issue35_FullPathTraversal_Probe.au3"

if exist "!T36_PROBE!" del /q "!T36_PROBE!" >nul 2>&1

if exist "!T36_AUTOIT!" (
    copy /y "Helpers\Issue35_FullPathTraversal_Probe.au3" "!T36_PROBE!" >nul 2>&1
    if exist "!T36_PROBE!" (
        pushd ".."
        "!T36_AUTOIT!" /ErrorStdOut "_Issue35_FullPathTraversal_Probe.au3" >nul 2>&1
        set "T36_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T36_EXIT=99"
    )
) else (
    set "T36_EXIT=98"
)

if exist "!T36_PROBE!" del /q "!T36_PROBE!" >nul 2>&1

findstr /x /c:"Valid parent path normalized: PASS" "Working\Test36\Probe.log" >nul 2>&1
if not errorlevel 1 set "T36_VALID=PASS"

findstr /x /c:"Excessive traversal returns failure: PASS" "Working\Test36\Probe.log" >nul 2>&1
if not errorlevel 1 set "T36_FAILURE=PASS"

findstr /x /c:"Child survives path error: PASS" "Working\Test36\Probe.log" >nul 2>&1
if not errorlevel 1 set "T36_SURVIVES=PASS"

if "!T36_VALID!"=="PASS" if "!T36_FAILURE!"=="PASS" if "!T36_SURVIVES!"=="PASS" if "!T36_EXIT!"=="0" set "T36=PASS"

if "!T36!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 37 - Java Download Completion Handling...
set /a TOTAL+=1

if exist "Working\Test37" rmdir /s /q "Working\Test37"
mkdir "Working\Test37" >nul 2>&1

set "T37=FAIL"
set "T37_WAIT=FAIL"
set "T37_START=FAIL"
set "T37_STATUS=FAIL"
set "T37_SIZE=FAIL"

set "T37_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T37_PROBE=%CD%\..\_Issue37_JavaDownload_Probe.au3"

if exist "!T37_PROBE!" del /q "!T37_PROBE!" >nul 2>&1

if exist "!T37_AUTOIT!" (
    copy /y "Helpers\Issue37_JavaDownload_Probe.au3" "!T37_PROBE!" >nul 2>&1
    if exist "!T37_PROBE!" (
        pushd ".."
        "!T37_AUTOIT!" /ErrorStdOut "_Issue37_JavaDownload_Probe.au3" >nul 2>&1
        set "T37_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T37_EXIT=99"
    )
) else (
    set "T37_EXIT=98"
)

if exist "!T37_PROBE!" del /q "!T37_PROBE!" >nul 2>&1

findstr /x /c:"Waits until download completion: PASS" "Working\Test37\Probe.log" >nul 2>&1
if not errorlevel 1 set "T37_WAIT=PASS"

findstr /x /c:"Async start failure detected: PASS" "Working\Test37\Probe.log" >nul 2>&1
if not errorlevel 1 set "T37_START=PASS"

findstr /x /c:"Transfer success status checked: PASS" "Working\Test37\Probe.log" >nul 2>&1
if not errorlevel 1 set "T37_STATUS=PASS"

findstr /x /c:"Downloaded size verified: PASS" "Working\Test37\Probe.log" >nul 2>&1
if not errorlevel 1 set "T37_SIZE=PASS"

if "!T37_WAIT!"=="PASS" if "!T37_START!"=="PASS" if "!T37_STATUS!"=="PASS" if "!T37_SIZE!"=="PASS" if "!T37_EXIT!"=="0" set "T37=PASS"

if "!T37!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 38 - Java Fatal Error Propagation...
set /a TOTAL+=1

if exist "Working\Test38" rmdir /s /q "Working\Test38"
mkdir "Working\Test38" >nul 2>&1

set "T38=FAIL"
set "T38_RETURN=FAIL"
set "T38_CALLERS=FAIL"
set "T38_RESTORE=FAIL"

set "T38_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T38_PROBE=%CD%\..\_Issue38_JavaFatalError_Probe.au3"

if exist "!T38_PROBE!" del /q "!T38_PROBE!" >nul 2>&1

if exist "!T38_AUTOIT!" (
    copy /y "Helpers\Issue38_JavaFatalError_Probe.au3" "!T38_PROBE!" >nul 2>&1
    if exist "!T38_PROBE!" (
        pushd ".."
        "!T38_AUTOIT!" /ErrorStdOut "_Issue38_JavaFatalError_Probe.au3" >nul 2>&1
        set "T38_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T38_EXIT=99"
    )
) else (
    set "T38_EXIT=98"
)

if exist "!T38_PROBE!" del /q "!T38_PROBE!" >nul 2>&1

findstr /x /c:"Fatal helper returns close code: PASS" "Working\Test38\Probe.log" >nul 2>&1
if not errorlevel 1 set "T38_RETURN=PASS"

findstr /x /c:"All fatal callers return immediately: PASS" "Working\Test38\Probe.log" >nul 2>&1
if not errorlevel 1 set "T38_CALLERS=PASS"

findstr /x /c:"Backup restore retained: PASS" "Working\Test38\Probe.log" >nul 2>&1
if not errorlevel 1 set "T38_RESTORE=PASS"

if "!T38_RETURN!"=="PASS" if "!T38_CALLERS!"=="PASS" if "!T38_RESTORE!"=="PASS" if "!T38_EXIT!"=="0" set "T38=PASS"

if "!T38!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 39 - Java Tray Exit Cancellation...
set /a TOTAL+=1

if exist "Working\Test39" rmdir /s /q "Working\Test39"
mkdir "Working\Test39" >nul 2>&1

set "T39=FAIL"
set "T39_STATE=FAIL"
set "T39_SIGNAL=FAIL"
set "T39_JAVA=FAIL"
set "T39_DOWNLOAD=FAIL"
set "T39_CLEANUP=FAIL"

set "T39_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T39_PROBE=%CD%\..\_Issue39_JavaCancel_Probe.au3"

if exist "!T39_PROBE!" del /q "!T39_PROBE!" >nul 2>&1

if exist "!T39_AUTOIT!" (
    copy /y "Helpers\Issue39_JavaCancel_Probe.au3" "!T39_PROBE!" >nul 2>&1
    if exist "!T39_PROBE!" (
        pushd ".."
        "!T39_AUTOIT!" /ErrorStdOut "_Issue39_JavaCancel_Probe.au3" >nul 2>&1
        set "T39_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T39_EXIT=99"
    )
) else (
    set "T39_EXIT=98"
)

if exist "!T39_PROBE!" del /q "!T39_PROBE!" >nul 2>&1

findstr /x /c:"Cancellation state declared: PASS" "Working\Test39\Probe.log" >nul 2>&1
if not errorlevel 1 set "T39_STATE=PASS"

findstr /x /c:"Tray Exit signals cancellation: PASS" "Working\Test39\Probe.log" >nul 2>&1
if not errorlevel 1 set "T39_SIGNAL=PASS"

findstr /x /c:"JavaGet returns on cancellation: PASS" "Working\Test39\Probe.log" >nul 2>&1
if not errorlevel 1 set "T39_JAVA=PASS"

findstr /x /c:"Active download stops on cancellation: PASS" "Working\Test39\Probe.log" >nul 2>&1
if not errorlevel 1 set "T39_DOWNLOAD=PASS"

findstr /x /c:"Restore and close path retained: PASS" "Working\Test39\Probe.log" >nul 2>&1
if not errorlevel 1 set "T39_CLEANUP=PASS"

if "!T39_STATE!"=="PASS" if "!T39_SIGNAL!"=="PASS" if "!T39_JAVA!"=="PASS" if "!T39_DOWNLOAD!"=="PASS" if "!T39_CLEANUP!"=="PASS" if "!T39_EXIT!"=="0" set "T39=PASS"

if "!T39!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 40 - JavaGet Result Handling...
set /a TOTAL+=1

if exist "Working\Test40" rmdir /s /q "Working\Test40"
mkdir "Working\Test40" >nul 2>&1

set "T40=FAIL"
set "T40_CAPTURE=FAIL"
set "T40_PROPAGATE=FAIL"
set "T40_LAUNCHER=FAIL"
set "T40_REQUIRED=FAIL"
set "T40_OPTIONAL=FAIL"
set "T40_PATH=FAIL"

set "T40_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T40_PROBE=%CD%\..\_Issue40_JavaResult_Probe.au3"

if exist "!T40_PROBE!" del /q "!T40_PROBE!" >nul 2>&1

if exist "!T40_AUTOIT!" (
    copy /y "Helpers\Issue40_JavaResult_Probe.au3" "!T40_PROBE!" >nul 2>&1
    if exist "!T40_PROBE!" (
        pushd ".."
        "!T40_AUTOIT!" /ErrorStdOut "_Issue40_JavaResult_Probe.au3" >nul 2>&1
        set "T40_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T40_EXIT=99"
    )
) else (
    set "T40_EXIT=98"
)

if exist "!T40_PROBE!" del /q "!T40_PROBE!" >nul 2>&1

findstr /x /c:"JavaGet result captured: PASS" "Working\Test40\Probe.log" >nul 2>&1
if not errorlevel 1 set "T40_CAPTURE=PASS"

findstr /x /c:"Nonzero result propagated: PASS" "Working\Test40\Probe.log" >nul 2>&1
if not errorlevel 1 set "T40_PROPAGATE=PASS"

findstr /x /c:"Launcher captures Java error: PASS" "Working\Test40\Probe.log" >nul 2>&1
if not errorlevel 1 set "T40_LAUNCHER=PASS"

findstr /x /c:"Required Java failure stops launch: PASS" "Working\Test40\Probe.log" >nul 2>&1
if not errorlevel 1 set "T40_REQUIRED=PASS"

findstr /x /c:"Optional Java fallback retained: PASS" "Working\Test40\Probe.log" >nul 2>&1
if not errorlevel 1 set "T40_OPTIONAL=PASS"

findstr /x /c:"Java path assignment retained: PASS" "Working\Test40\Probe.log" >nul 2>&1
if not errorlevel 1 set "T40_PATH=PASS"

if "!T40_CAPTURE!"=="PASS" if "!T40_PROPAGATE!"=="PASS" if "!T40_LAUNCHER!"=="PASS" if "!T40_REQUIRED!"=="PASS" if "!T40_OPTIONAL!"=="PASS" if "!T40_PATH!"=="PASS" if "!T40_EXIT!"=="0" set "T40=PASS"

if "!T40!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 41 - Java Version Comparison...
set /a TOTAL+=1

if exist "Working\Test41" rmdir /s /q "Working\Test41"
mkdir "Working\Test41" >nul 2>&1

set "T41=FAIL"
set "T41_INCLUDE=FAIL"
set "T41_COMPARE=FAIL"
set "T41_DIRECT=FAIL"
set "T41_EQUAL=FAIL"
set "T41_RESULT=FAIL"

set "T41_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T41_PROBE=%CD%\..\_Issue41_JavaVersion_Probe.au3"

if exist "!T41_PROBE!" del /q "!T41_PROBE!" >nul 2>&1

if exist "!T41_AUTOIT!" (
    copy /y "Helpers\Issue41_JavaVersion_Probe.au3" "!T41_PROBE!" >nul 2>&1
    if exist "!T41_PROBE!" (
        pushd ".."
        "!T41_AUTOIT!" /ErrorStdOut "_Issue41_JavaVersion_Probe.au3" >nul 2>&1
        set "T41_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T41_EXIT=99"
    )
) else (
    set "T41_EXIT=98"
)

if exist "!T41_PROBE!" del /q "!T41_PROBE!" >nul 2>&1

findstr /x /c:"Misc version helper included: PASS" "Working\Test41\Probe.log" >nul 2>&1
if not errorlevel 1 set "T41_INCLUDE=PASS"

findstr /x /c:"VersionCompare used for Java versions: PASS" "Working\Test41\Probe.log" >nul 2>&1
if not errorlevel 1 set "T41_COMPARE=PASS"

findstr /x /c:"Direct version operator removed: PASS" "Working\Test41\Probe.log" >nul 2>&1
if not errorlevel 1 set "T41_DIRECT=PASS"

findstr /x /c:"Equal versions still prefer host Java: PASS" "Working\Test41\Probe.log" >nul 2>&1
if not errorlevel 1 set "T41_EQUAL=PASS"

findstr /x /c:"Java result propagation retained: PASS" "Working\Test41\Probe.log" >nul 2>&1
if not errorlevel 1 set "T41_RESULT=PASS"

if "!T41_INCLUDE!"=="PASS" if "!T41_COMPARE!"=="PASS" if "!T41_DIRECT!"=="PASS" if "!T41_EQUAL!"=="PASS" if "!T41_RESULT!"=="PASS" if "!T41_EXIT!"=="0" set "T41=PASS"

if "!T41!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 42 - Java Runtime Policy and Guidance...
set /a TOTAL+=1

if exist "Working\Test42" rmdir /s /q "Working\Test42"
mkdir "Working\Test42" >nul 2>&1

set "T42=FAIL"
set "T42_URLREAD=FAIL"
set "T42_URLPASS=FAIL"
set "T42_OLDURL=FAIL"
set "T42_PRIORITY=FAIL"
set "T42_MISSING=FAIL"
set "T42_GUIDANCE=FAIL"
set "T42_REQUIRED=FAIL"
set "T42_OPTIONAL=FAIL"

set "T42_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T42_PROBE=%CD%\..\_Issue42A_JavaPolicy_Probe.au3"

if exist "!T42_PROBE!" del /q "!T42_PROBE!" >nul 2>&1

if exist "!T42_AUTOIT!" (
    copy /y "Helpers\Issue42A_JavaPolicy_Probe.au3" "!T42_PROBE!" >nul 2>&1
    if exist "!T42_PROBE!" (
        pushd ".."
        "!T42_AUTOIT!" /ErrorStdOut "_Issue42A_JavaPolicy_Probe.au3" >nul 2>&1
        set "T42_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T42_EXIT=99"
    )
) else (
    set "T42_EXIT=98"
)

if exist "!T42_PROBE!" del /q "!T42_PROBE!" >nul 2>&1

findstr /x /c:"JavaURL read from application INI: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_URLREAD=PASS"

findstr /x /c:"Configured URL passed to JavaGet: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_URLPASS=PASS"

findstr /x /c:"Hidden legacy download URL removed: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_OLDURL=PASS"

findstr /x /c:"Portable Java takes priority: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_PRIORITY=PASS"

findstr /x /c:"Missing JavaURL has explicit result: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_MISSING=PASS"

findstr /x /c:"Required Java guidance is shown: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_GUIDANCE=PASS"

findstr /x /c:"Required Java still stops safely: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_REQUIRED=PASS"

findstr /x /c:"Optional Java fallback retained: PASS" "Working\Test42\Probe.log" >nul 2>&1
if not errorlevel 1 set "T42_OPTIONAL=PASS"

if "!T42_URLREAD!"=="PASS" if "!T42_URLPASS!"=="PASS" if "!T42_OLDURL!"=="PASS" if "!T42_PRIORITY!"=="PASS" if "!T42_MISSING!"=="PASS" if "!T42_GUIDANCE!"=="PASS" if "!T42_REQUIRED!"=="PASS" if "!T42_OPTIONAL!"=="PASS" if "!T42_EXIT!"=="0" set "T42=PASS"

if "!T42!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 43 - Modern Java ZIP Transaction...
set /a TOTAL+=1

if exist "Working\Test43" rmdir /s /q "Working\Test43"
mkdir "Working\Test43" >nul 2>&1

set "T43=FAIL"
set "T43_PATTERNS=FAIL"
set "T43_STAGE=FAIL"
set "T43_DIRECT=FAIL"
set "T43_WRAPPED=FAIL"
set "T43_AMBIGUOUS=FAIL"
set "T43_BACKUP=FAIL"
set "T43_RESTORE=FAIL"
set "T43_SETUP=FAIL"
set "T43_LEGACY=FAIL"

set "T43_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T43_PROBE=%CD%\..\_Issue42B_JavaZipTransaction_Probe.au3"

if exist "!T43_PROBE!" del /q "!T43_PROBE!" >nul 2>&1

if exist "!T43_AUTOIT!" (
    copy /y "Helpers\Issue42B_JavaZipTransaction_Probe.au3" "!T43_PROBE!" >nul 2>&1
    if exist "!T43_PROBE!" (
        pushd ".."
        "!T43_AUTOIT!" /ErrorStdOut "_Issue42B_JavaZipTransaction_Probe.au3" >nul 2>&1
        set "T43_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T43_EXIT=99"
    )
) else (
    set "T43_EXIT=98"
)

if exist "!T43_PROBE!" del /q "!T43_PROBE!" >nul 2>&1

findstr /x /c:"ZIP and legacy setup packages accepted: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_PATTERNS=PASS"

findstr /x /c:"Package staged before live backup: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_STAGE=PASS"

findstr /x /c:"Direct ZIP runtime root recognized: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_DIRECT=PASS"

findstr /x /c:"Wrapped ZIP runtime root recognized: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_WRAPPED=PASS"

findstr /x /c:"Ambiguous ZIP runtime rejected: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_AMBIGUOUS=PASS"

findstr /x /c:"Complete portable runtime backed up: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_BACKUP=PASS"

findstr /x /c:"Failed install restores complete runtime: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_RESTORE=PASS"

findstr /x /c:"Setup package preserved during transaction: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_SETUP=PASS"

findstr /x /c:"Legacy EXE extraction retained: PASS" "Working\Test43\Probe.log" >nul 2>&1
if not errorlevel 1 set "T43_LEGACY=PASS"

if "!T43_PATTERNS!"=="PASS" if "!T43_STAGE!"=="PASS" if "!T43_DIRECT!"=="PASS" if "!T43_WRAPPED!"=="PASS" if "!T43_AMBIGUOUS!"=="PASS" if "!T43_BACKUP!"=="PASS" if "!T43_RESTORE!"=="PASS" if "!T43_SETUP!"=="PASS" if "!T43_LEGACY!"=="PASS" if "!T43_EXIT!"=="0" set "T43=PASS"

if "!T43!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 44 - Configurable Java Download Compatibility...
set /a TOTAL+=1

if exist "Working\Test44" rmdir /s /q "Working\Test44"
mkdir "Working\Test44" >nul 2>&1

set "T44=FAIL"
set "T44_TEMPLATE=FAIL"
set "T44_PATHTEMPLATE=FAIL"
set "T44_OLDINI=FAIL"
set "T44_OLDPATH=FAIL"
set "T44_ABSOLUTE=FAIL"
set "T44_EXECUTABLE=FAIL"
set "T44_RELATIVE=FAIL"
set "T44_LAUNCHER=FAIL"
set "T44_URLVALID=FAIL"
set "T44_GUIDANCE=FAIL"
set "T44_FILENAME=FAIL"
set "T44_URLPASS=FAIL"
set "T44_JAVAHOME=FAIL"
set "T44_PATH=FAIL"
set "T44_REGISTRY=FAIL"
set "T44_PRIORITY=FAIL"
set "T44_CONFIGURED=FAIL"
set "T44_URLBYPASS=FAIL"
set "T44_DISABLED=FAIL"
set "T44_READONLY=FAIL"

set "T44_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T44_PROBE=%CD%\..\_Issue42C_JavaDownloadCompatibility_Probe.au3"

if exist "!T44_PROBE!" del /q "!T44_PROBE!" >nul 2>&1

if exist "!T44_AUTOIT!" (
    copy /y "Helpers\Issue42C_JavaDownloadCompatibility_Probe.au3" "!T44_PROBE!" >nul 2>&1
    if exist "!T44_PROBE!" (
        pushd ".."
        "!T44_AUTOIT!" /ErrorStdOut "_Issue42C_JavaDownloadCompatibility_Probe.au3" >nul 2>&1
        set "T44_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T44_EXIT=99"
    )
) else (
    set "T44_EXIT=98"
)

if exist "!T44_PROBE!" del /q "!T44_PROBE!" >nul 2>&1

findstr /x /c:"Optional JavaURL key documented in template: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_TEMPLATE=PASS"

findstr /x /c:"Optional JavaPath key documented in template: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_PATHTEMPLATE=PASS"

findstr /x /c:"Old INI without JavaURL remains compatible: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_OLDINI=PASS"

findstr /x /c:"Old INI without JavaPath remains compatible: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_OLDPATH=PASS"

findstr /x /c:"Absolute and quoted JavaPath runtime roots accepted: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_ABSOLUTE=PASS"

findstr /x /c:"JavaPath bin and Java executables normalized to runtime root: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_EXECUTABLE=PASS"

findstr /x /c:"Relative JavaPath resolved against Root: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_RELATIVE=PASS"

findstr /x /c:"JavaPortableLauncher executable rejected as a runtime: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_LAUNCHER=PASS"

findstr /x /c:"Only HTTP and HTTPS Java URLs accepted: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_URLVALID=PASS"

findstr /x /c:"Invalid JavaURL has brief required-Java guidance: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_GUIDANCE=PASS"

findstr /x /c:"Downloaded package uses format-neutral filename: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_FILENAME=PASS"

findstr /x /c:"Configured JavaURL passed unchanged to downloader: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_URLPASS=PASS"

findstr /x /c:"JAVA_HOME system fallback recognized: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_JAVAHOME=PASS"

findstr /x /c:"PATH system fallback recognized: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_PATH=PASS"

findstr /x /c:"Legacy and modern JavaSoft registry fallbacks retained: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_REGISTRY=PASS"

findstr /x /c:"Portable Java remains preferred over system Java: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_PRIORITY=PASS"

findstr /x /c:"Configured JavaPath takes priority over bundled system and URL sources: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_CONFIGURED=PASS"

findstr /x /c:"Usable JavaPath bypasses JavaURL download and JavaGet writes: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_URLBYPASS=PASS"

findstr /x /c:"Java false ignores but retains configured JavaPath: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_DISABLED=PASS"

findstr /x /c:"External JavaPath runtime remains byte-identical: PASS" "Working\Test44\Probe.log" >nul 2>&1
if not errorlevel 1 set "T44_READONLY=PASS"

if "!T44_TEMPLATE!"=="PASS" if "!T44_PATHTEMPLATE!"=="PASS" if "!T44_OLDINI!"=="PASS" if "!T44_OLDPATH!"=="PASS" if "!T44_ABSOLUTE!"=="PASS" if "!T44_EXECUTABLE!"=="PASS" if "!T44_RELATIVE!"=="PASS" if "!T44_LAUNCHER!"=="PASS" if "!T44_URLVALID!"=="PASS" if "!T44_GUIDANCE!"=="PASS" if "!T44_FILENAME!"=="PASS" if "!T44_URLPASS!"=="PASS" if "!T44_JAVAHOME!"=="PASS" if "!T44_PATH!"=="PASS" if "!T44_REGISTRY!"=="PASS" if "!T44_PRIORITY!"=="PASS" if "!T44_CONFIGURED!"=="PASS" if "!T44_URLBYPASS!"=="PASS" if "!T44_DISABLED!"=="PASS" if "!T44_READONLY!"=="PASS" if "!T44_EXIT!"=="0" set "T44=PASS"

if "!T44!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 45 - TestRun Parsing and Safe Routing...
set /a TOTAL+=1

if exist "Working\Test45" rmdir /s /q "Working\Test45"
mkdir "Working\Test45\Missing\Temp" >nul 2>&1
mkdir "Working\Test45\False\Temp" >nul 2>&1

> "Working\Test45\Missing\Payload.bat" echo @echo off
>>"Working\Test45\Missing\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test45\Missing\Payload.bat" echo exit /b 0

> "Working\Test45\False\Payload.bat" echo @echo off
>>"Working\Test45\False\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test45\False\Payload.bat" echo exit /b 0

"%LAUNCHER%" "--x-launcher-config=%CD%\Configs\45A_TestRun_Missing.ini" >nul 2>&1
set "T45_MISSING_EXIT=!ERRORLEVEL!"

"%LAUNCHER%" "--x-launcher-config=%CD%\Configs\45B_TestRun_False.ini" >nul 2>&1
set "T45_FALSE_EXIT=!ERRORLEVEL!"

set "T45_MISSING=FAIL"
set "T45_FALSE=FAIL"
if exist "Working\Test45\Missing\PayloadRan.txt" if "!T45_MISSING_EXIT!"=="0" set "T45_MISSING=PASS"
if exist "Working\Test45\False\PayloadRan.txt" if "!T45_FALSE_EXIT!"=="0" set "T45_FALSE=PASS"

set "T45_TEMPLATE=FAIL"
set "T45_DEFAULT=FAIL"
set "T45_BLANK=FAIL"
set "T45_CASE=FAIL"
set "T45_INVALID=FAIL"
set "T45_DIRECT=FAIL"
set "T45_OVERRIDE=FAIL"
set "T45_SELECTOR=FAIL"
set "T45_SELECT_CANCEL=FAIL"
set "T45_CONFIRM_CANCEL=FAIL"
set "T45_STOP=FAIL"
set "T45_EXIT=99"

set "T45_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T45_PROBE=%CD%\..\_Issue45_TestRunRouting_Probe.au3"

if exist "!T45_PROBE!" del /q "!T45_PROBE!" >nul 2>&1

if exist "!T45_AUTOIT!" (
    copy /y "Helpers\Issue45_TestRunRouting_Probe.au3" "!T45_PROBE!" >nul 2>&1
    if exist "!T45_PROBE!" (
        pushd ".."
        "!T45_AUTOIT!" /ErrorStdOut "_Issue45_TestRunRouting_Probe.au3" >nul 2>&1
        set "T45_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T45_EXIT=99"
    )
) else (
    set "T45_EXIT=98"
)

if exist "!T45_PROBE!" del /q "!T45_PROBE!" >nul 2>&1

findstr /x /c:"Template documents TestRun false: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_TEMPLATE=PASS"

findstr /x /c:"Missing TestRun defaults to false: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_DEFAULT=PASS"

findstr /x /c:"Blank TestRun falls back to false: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_BLANK=PASS"

findstr /x /c:"Valid TestRun modes are case insensitive: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_CASE=PASS"

findstr /x /c:"Invalid INI value stops safely: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_INVALID=PASS"

findstr /x /c:"Direct command line modes are recognized: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_DIRECT=PASS"

findstr /x /c:"Command line mode overrides INI: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_OVERRIDE=PASS"

findstr /x /c:"Selection window exposes four outcomes: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_SELECTOR=PASS"

findstr /x /c:"Selection cancellation stops launch: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_SELECT_CANCEL=PASS"

findstr /x /c:"Confirmation cancellation stops launch: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_CONFIRM_CANCEL=PASS"

findstr /x /c:"Trace routes to preparation and Full routes to isolated self-test: PASS" "Working\Test45\Probe.log" >nul 2>&1
if not errorlevel 1 set "T45_STOP=PASS"

set "T45_SOURCE=FAIL"
if "!T45_TEMPLATE!"=="PASS" if "!T45_DEFAULT!"=="PASS" if "!T45_BLANK!"=="PASS" if "!T45_CASE!"=="PASS" if "!T45_INVALID!"=="PASS" if "!T45_DIRECT!"=="PASS" if "!T45_OVERRIDE!"=="PASS" if "!T45_SELECTOR!"=="PASS" if "!T45_SELECT_CANCEL!"=="PASS" if "!T45_CONFIRM_CANCEL!"=="PASS" if "!T45_STOP!"=="PASS" set "T45_SOURCE=PASS"

set "T45=FAIL"
if "!T45_MISSING!"=="PASS" if "!T45_FALSE!"=="PASS" if "!T45_SOURCE!"=="PASS" if "!T45_EXIT!"=="0" set "T45=PASS"

if "!T45!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 46 - Configuration Probe Read-Only Checks...
set /a TOTAL+=1

if exist "Working\Test46" rmdir /s /q "Working\Test46"
mkdir "Working\Test46\Valid\Launcher" >nul 2>&1
mkdir "Working\Test46\Valid\Root" >nul 2>&1
mkdir "Working\Test46\Invalid\Launcher" >nul 2>&1
mkdir "Working\Test46\Invalid\Root" >nul 2>&1

copy /y "%LAUNCHER%" "Working\Test46\Valid\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test46\Invalid\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\46A_Probe_Core_Valid.ini" "Working\Test46\Valid\Config.ini" >nul 2>&1
copy /y "Configs\46B_Probe_Core_Invalid.ini" "Working\Test46\Invalid\Config.ini" >nul 2>&1
copy /y "Working\Test46\Valid\Config.ini" "Working\Test46\Valid\Config.before.ini" >nul 2>&1
copy /y "Working\Test46\Invalid\Config.ini" "Working\Test46\Invalid\Config.before.ini" >nul 2>&1

> "Working\Test46\Valid\Root\Payload.bat" echo @echo off
>>"Working\Test46\Valid\Root\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test46\Valid\Root\Payload.bat" echo exit /b 0
> "Working\Test46\Valid\Root\Sentinel.txt" echo UNCHANGED
> "Working\Test46\Valid\Root\OperationPayload.bat" echo @echo off
>>"Working\Test46\Valid\Root\OperationPayload.bat" echo ^> "%%~dp0OperationRan.txt" echo RAN
>>"Working\Test46\Valid\Root\OperationPayload.bat" echo exit /b 0
mkdir "Working\Test46\Valid\Root\SourceDir" >nul 2>&1
mkdir "Working\Test46\Valid\Root\MoveSourceDir" >nul 2>&1
mkdir "Working\Test46\Valid\Root\RemoveMe" >nul 2>&1
mkdir "Working\Test46\Valid\Root\RemoveMeEmpty" >nul 2>&1
> "Working\Test46\Valid\Root\SourceDir\Source.txt" echo SOURCE
> "Working\Test46\Valid\Root\MoveSourceDir\MoveSource.txt" echo MOVE_SOURCE
> "Working\Test46\Valid\Root\Source.txt" echo SOURCE
> "Working\Test46\Valid\Root\DeleteMe.txt" echo KEEP
> "Working\Test46\Valid\Root\MoveMe.txt" echo KEEP
> "Working\Test46\Valid\Root\RewriteTarget.txt" echo C:\KEEP
> "Working\Test46\Valid\Root\DummyFont.ttf" echo PROBE_ONLY
> "Working\Test46\Valid\Root\DynamicWildcardOne.txt" echo BEGIN old END
> "Working\Test46\Valid\Root\DynamicWildcardTwo.txt" echo BEGIN old END
> "Working\Test46\Valid\Root\DynamicRegex.txt" echo old value
> "Working\Test46\Valid\Root\DynamicWrite.txt" echo ORIGINAL_WRITE
> "Working\Test46\Valid\Root\DynamicWrite.ini" echo [Original]
>>"Working\Test46\Valid\Root\DynamicWrite.ini" echo State=UNCHANGED
> "Working\Test46\Valid\Root\DynamicPrefs.js" echo user_pref^("original", true^);
mkdir "Working\Test46\Valid\Root\Lib\Java\bin" >nul 2>&1
mkdir "Working\Test46\Valid\Root\Lib\Java\setup" >nul 2>&1
> "Working\Test46\Valid\Root\Lib\Java\bin\java.exe" echo PROBE_FAKE_JAVA
> "Working\Test46\Valid\Root\Lib\Java\bin\javaw.exe" echo PROBE_FAKE_JAVAW
> "Working\Test46\Valid\Root\Lib\Java\setup\runtime.zip" echo PROBE_FAKE_ZIP
> "Working\Test46\Valid\Root\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test46\Valid\Root\Portable.reg" echo.
>>"Working\Test46\Valid\Root\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\Probe46]
>>"Working\Test46\Valid\Root\Portable.reg" echo "State"="PORTABLE"
copy /y "Working\Test46\Valid\Root\Portable.reg" "Working\Test46\Valid\Root\Portable.before.reg" >nul 2>&1
copy /y "Working\Test46\Valid\Root\DynamicWildcardOne.txt" "Working\Test46\Valid\Root\Before_DynamicWildcardOne.txt" >nul 2>&1
copy /y "Working\Test46\Valid\Root\DynamicWildcardTwo.txt" "Working\Test46\Valid\Root\Before_DynamicWildcardTwo.txt" >nul 2>&1
copy /y "Working\Test46\Valid\Root\DynamicRegex.txt" "Working\Test46\Valid\Root\DynamicRegex.before.txt" >nul 2>&1
copy /y "Working\Test46\Valid\Root\DynamicWrite.txt" "Working\Test46\Valid\Root\DynamicWrite.before.txt" >nul 2>&1
copy /y "Working\Test46\Valid\Root\DynamicWrite.ini" "Working\Test46\Valid\Root\DynamicWrite.before.ini" >nul 2>&1
copy /y "Working\Test46\Valid\Root\DynamicPrefs.js" "Working\Test46\Valid\Root\DynamicPrefs.before.js" >nul 2>&1
copy /y "Working\Test46\Valid\Root\Lib\Java\bin\java.exe" "Working\Test46\Valid\Root\Lib\Java\bin\java.before.exe" >nul 2>&1
copy /y "Working\Test46\Valid\Root\Lib\Java\bin\javaw.exe" "Working\Test46\Valid\Root\Lib\Java\bin\javaw.before.exe" >nul 2>&1
copy /y "Working\Test46\Valid\Root\Lib\Java\setup\runtime.zip" "Working\Test46\Valid\Root\Lib\Java\setup\runtime.before.bin" >nul 2>&1

> "Working\Test46\Invalid\Root\InvalidDynamic.txt" echo INVALID_PATTERN_SOURCE
mkdir "Working\Test46\Invalid\Root\Lib\Java\setup" >nul 2>&1
> "Working\Test46\Invalid\Root\Lib\Java\setup\Broken.exe" echo NOT_AN_MZ_EXECUTABLE
copy /y "Working\Test46\Invalid\Root\InvalidDynamic.txt" "Working\Test46\Invalid\Root\InvalidDynamic.before.txt" >nul 2>&1
copy /y "Working\Test46\Invalid\Root\Lib\Java\setup\Broken.exe" "Working\Test46\Invalid\Root\Lib\Java\setup\Broken.before.bin" >nul 2>&1

reg delete "HKCU\Software\XLauncher_Test\Probe46" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Probe46" /v State /t REG_SZ /d HOST /f >nul 2>&1

"Working\Test46\Valid\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test46\Valid\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T46_VALID_EXIT=!ERRORLEVEL!"

"Working\Test46\Invalid\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test46\Invalid\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T46_INVALID_EXIT=!ERRORLEVEL!"

set "T46_VALID_CODE=FAIL"
set "T46_INVALID_CODE=FAIL"
if "!T46_VALID_EXIT!"=="0" set "T46_VALID_CODE=PASS"
if "!T46_INVALID_EXIT!"=="10" set "T46_INVALID_CODE=PASS"

set "T46_NO_LAUNCH=PASS"
if exist "Working\Test46\Valid\Root\PayloadRan.txt" set "T46_NO_LAUNCH=FAIL"

set "T46_INI_SAFE=FAIL"
fc /b "Working\Test46\Valid\Config.ini" "Working\Test46\Valid\Config.before.ini" >nul 2>&1
if not errorlevel 1 (
    fc /b "Working\Test46\Invalid\Config.ini" "Working\Test46\Invalid\Config.before.ini" >nul 2>&1
    if not errorlevel 1 set "T46_INI_SAFE=PASS"
)

set "T46_FILES_SAFE=PASS"
findstr /x /c:"UNCHANGED" "Working\Test46\Valid\Root\Sentinel.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Temp" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Cache" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Home" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\CopiedDir" set "T46_FILES_SAFE=FAIL"
if not exist "Working\Test46\Valid\Root\MoveSourceDir\MoveSource.txt" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\MovedDir" set "T46_FILES_SAFE=FAIL"
if not exist "Working\Test46\Valid\Root\RemoveMe" set "T46_FILES_SAFE=FAIL"
if not exist "Working\Test46\Valid\Root\RemoveMeEmpty" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\AlreadyAbsentFunctions" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\AlreadyAbsentFirstRun" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\AlreadyAbsentRunAfter" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Copied.txt" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\WouldCreate.txt" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\WouldCreateDir" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\FirstRunWouldCreate.txt" set "T46_FILES_SAFE=FAIL"
if not exist "Working\Test46\Valid\Root\DeleteMe.txt" set "T46_FILES_SAFE=FAIL"
if not exist "Working\Test46\Valid\Root\MoveMe.txt" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Moved.txt" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\OperationRan.txt" set "T46_FILES_SAFE=FAIL"
findstr /x /c:"C:\KEEP" "Working\Test46\Valid\Root\RewriteTarget.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\Portable.reg" "Working\Test46\Valid\Root\Portable.before.reg" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\DynamicWildcardOne.txt" "Working\Test46\Valid\Root\Before_DynamicWildcardOne.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\DynamicWildcardTwo.txt" "Working\Test46\Valid\Root\Before_DynamicWildcardTwo.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\DynamicRegex.txt" "Working\Test46\Valid\Root\DynamicRegex.before.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\DynamicWrite.txt" "Working\Test46\Valid\Root\DynamicWrite.before.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\DynamicWrite.ini" "Working\Test46\Valid\Root\DynamicWrite.before.ini" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\DynamicPrefs.js" "Working\Test46\Valid\Root\DynamicPrefs.before.js" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\DynamicGenerated.reg" set "T46_FILES_SAFE=FAIL"
fc /b "Working\Test46\Invalid\Root\InvalidDynamic.txt" "Working\Test46\Invalid\Root\InvalidDynamic.before.txt" >nul 2>&1
if errorlevel 1 set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\InvalidWrite.txt" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\InvalidWrite.ini" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\InvalidPrefs.js" set "T46_FILES_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\InvalidGenerated.reg" set "T46_FILES_SAFE=FAIL"

set "T46_JAVA_SAFE=PASS"
fc /b "Working\Test46\Valid\Root\Lib\Java\bin\java.exe" "Working\Test46\Valid\Root\Lib\Java\bin\java.before.exe" >nul 2>&1
if errorlevel 1 set "T46_JAVA_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\Lib\Java\bin\javaw.exe" "Working\Test46\Valid\Root\Lib\Java\bin\javaw.before.exe" >nul 2>&1
if errorlevel 1 set "T46_JAVA_SAFE=FAIL"
fc /b "Working\Test46\Valid\Root\Lib\Java\setup\runtime.zip" "Working\Test46\Valid\Root\Lib\Java\setup\runtime.before.bin" >nul 2>&1
if errorlevel 1 set "T46_JAVA_SAFE=FAIL"
fc /b "Working\Test46\Invalid\Root\Lib\Java\setup\Broken.exe" "Working\Test46\Invalid\Root\Lib\Java\setup\Broken.before.bin" >nul 2>&1
if errorlevel 1 set "T46_JAVA_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Lib\Java\setup\java-download.package" set "T46_JAVA_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Lib\Java\.java-stage" set "T46_JAVA_SAFE=FAIL"
if exist "Working\Test46\Valid\Root\Lib\Java\old_java" set "T46_JAVA_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\Lib\Java\setup\java-download.package" set "T46_JAVA_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\Lib\Java\.java-stage" set "T46_JAVA_SAFE=FAIL"
if exist "Working\Test46\Invalid\Root\Lib\Java\old_java" set "T46_JAVA_SAFE=FAIL"

set "T46_REG_SAFE=FAIL"
reg query "HKCU\Software\XLauncher_Test\Probe46" /v State 2>nul | find /I "HOST" >nul
if not errorlevel 1 set "T46_REG_SAFE=PASS"

set "T46_VALID_REPORT_PATH="
set "T46_INVALID_REPORT_PATH="
for %%F in ("Working\Test46\Valid\Launcher\Diagnostics\*.txt" "Working\Test46\Valid\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T46_VALID_REPORT_PATH=%%~fF"
for %%F in ("Working\Test46\Invalid\Launcher\Diagnostics\*.txt" "Working\Test46\Invalid\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T46_INVALID_REPORT_PATH=%%~fF"

set "T46_REPORT_EXTENSION=FAIL"
if /i "!T46_VALID_REPORT_PATH:~-4!"==".log" if /i "!T46_INVALID_REPORT_PATH:~-4!"==".log" set "T46_REPORT_EXTENSION=PASS"

set "T46_REPORT=FAIL"
if defined T46_VALID_REPORT_PATH if exist "!T46_VALID_REPORT_PATH!" (
    findstr /c:"X-LAUNCHER CONFIGURATION PROBE" "!T46_VALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"Mode=READ-ONLY - configured application and operations were not executed." "!T46_VALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /b /c:"[PASS] [FileToRun] PathToExe exists=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /x /c:"[PASS] [Options] RegView is valid=Native" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 (
                    findstr /x /c:"[PASS] [Options] ProcMonMaxMB is valid=2048" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /x /c:"[PASS] [Options] ProcMonReserveMB is valid=1024" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                        if not errorlevel 1 (
                            findstr /x /c:"FAIL=0" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                            if not errorlevel 1 set "T46_REPORT=PASS"
                        )
                    )
                )
            )
        )
    )
)

set "T46_INVALID_REPORT=FAIL"
if defined T46_INVALID_REPORT_PATH if exist "!T46_INVALID_REPORT_PATH!" (
    findstr /b /c:"[FAIL] [FileSystem] Temp could not be resolved=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /b /c:"[FAIL] [FileToRun] PathToExe does not exist=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /x /c:"[FAIL] [Options] DeleteTemp must be true or false=maybe" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /x /c:"[FAIL] [Options] MultipleInstances must be true or false=maybe" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 (
                    findstr /x /c:"[FAIL] [Options] RegView is invalid; use Auto, Native, 32 or 64=Sideways" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /x /c:"[FAIL] [Options] TestRun is invalid; use false, Probe, Trace or Full=Unexpected" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                        if not errorlevel 1 (
                            findstr /x /c:"[FAIL] [Options] ProcMonMaxMB must be an integer from 64 to 102400 MB=tiny" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                            if not errorlevel 1 (
                                findstr /x /c:"[FAIL] [Options] ProcMonReserveMB must be an integer from 256 to 102400 MB=0" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                                if not errorlevel 1 (
                                    findstr /x /c:"[WARN] [General] Unknown section=[UnknownSection]" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                                    if not errorlevel 1 set "T46_INVALID_REPORT=PASS"
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

set "T46_OPERATIONS_REPORT=FAIL"
if defined T46_VALID_REPORT_PATH if exist "!T46_VALID_REPORT_PATH!" (
    findstr /x /c:"[PASS] [Environment] Variable name is accepted by Windows=PROBE_TEST_VAR" "!T46_VALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"[PASS] [Environment] Variable name is accepted by Windows=PROGRAMFILES(x86)" "!T46_VALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /x /c:"[PASS] [Functions] Recognized operation=DirCopy" "!T46_VALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /b /c:"[PASS] [FirstRunOperations] RunFile target exists=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 (
                    findstr /b /c:"[PASS] [RunBefore] REG file is readable and contains supported roots=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /x /c:"[PASS] [RunAfter] Recognized operation=FileDelete" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                        if not errorlevel 1 set "T46_OPERATIONS_REPORT=PASS"
                    )
                )
            )
        )
    )
)

set "T46_INVALID_OPERATIONS=FAIL"
if defined T46_INVALID_REPORT_PATH if exist "!T46_INVALID_REPORT_PATH!" (
    findstr /x /c:"[PASS] [Environment] Variable name is accepted by Windows=BAD NAME" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"[WARN] [Environment] EMPTY_VALUE has a blank value" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /x /c:"[WARN] [Functions] Unknown operation FileCoppy; did you mean FileCopy?" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /x /c:"[FAIL] [Functions] DirCopy requires source and destination" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 (
                    findstr /b /c:"[FAIL] [FirstRunOperations] RunFile target does not exist=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /b /c:"[FAIL] [RunBefore] REG file does not exist=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                        if not errorlevel 1 (
                            findstr /x /c:"[WARN] [RunAfter] Unknown operation RunFiel; did you mean RunFile?" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                            if not errorlevel 1 set "T46_INVALID_OPERATIONS=PASS"
                        )
                    )
                )
            )
        )
    )
)

set "T46_DIRREMOVE_REPORT=FAIL"
if defined T46_VALID_REPORT_PATH if exist "!T46_VALID_REPORT_PATH!" if defined T46_INVALID_REPORT_PATH if exist "!T46_INVALID_REPORT_PATH!" (
	set "T46_DIRREMOVE_REPORT=PASS"
	findstr /x /c:"[PASS] [Functions] DirRemove has no flag and will recursively remove populated directories" "!T46_VALID_REPORT_PATH!" >nul 2>&1
	if errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
	findstr /x /c:"[PASS] [Functions] DirRemove e flag will remove only empty directories recursively" "!T46_VALID_REPORT_PATH!" >nul 2>&1
	if errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
	findstr /x /c:"[FAIL] [RunAfter] DirRemove flag is invalid; omit it to recursively remove populated directories or use e to remove only empty directories=o" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
	if errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
	findstr /b /c:"[NOT USED] [Functions] DirRemove target is already absent; runtime cleanup is not needed=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
	if errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
	findstr /b /c:"[NOT USED] [FirstRunOperations] DirRemove target is already absent; runtime cleanup is not needed=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
	if errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
	findstr /b /c:"[NOT USED] [RunAfter] DirRemove target is already absent; runtime cleanup is not needed=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
	if errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
	findstr /l /b /c:"[FAIL] [Functions] DirRemove source does not exist=" /c:"[FAIL] [FirstRunOperations] DirRemove source does not exist=" /c:"[FAIL] [RunAfter] DirRemove source does not exist=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
	if not errorlevel 1 set "T46_DIRREMOVE_REPORT=FAIL"
)

set "T46_DYNAMIC_REPORT=FAIL"
if defined T46_VALID_REPORT_PATH if exist "!T46_VALID_REPORT_PATH!" (
    findstr /x /c:"[PASS] [StringReplace] Target pattern matched existing files=2" "!T46_VALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"[PASS] [StringReplace] Delimiter structure is valid=BEGIN|END" "!T46_VALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /x /c:"[PASS] [StringRegExpReplace] Regular expression pattern compiles without changing files=~|1" "!T46_VALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /x /c:"[PASS] [WriteToFile] Line selector is valid=Line1" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 (
                    findstr /x /c:"[PASS] [WriteToIni] Section and key names are valid=Probe|State" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /x /c:"[PASS] [WriteToPref] Format contains [PREF] and [VALUE] in the required order" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                        if not errorlevel 1 (
                            findstr /b /c:"[PASS] [WriteToReg] MainKey uses a supported registry root=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                            if not errorlevel 1 set "T46_DYNAMIC_REPORT=PASS"
                        )
                    )
                )
            )
        )
    )
)

set "T46_INVALID_DYNAMIC=FAIL"
if defined T46_INVALID_REPORT_PATH if exist "!T46_INVALID_REPORT_PATH!" (
    findstr /b /c:"[FAIL] [StringReplace] Target pattern did not match an existing file=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /b /c:"[FAIL] [StringReplace] Key must contain nonblank begin and end delimiters=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /x /c:"[FAIL] [StringRegExpReplace] Counter must be an integer=notnumber" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /b /c:"[FAIL] [StringRegExpReplace] Regular expression pattern does not compile=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 (
                    findstr /b /c:"[FAIL] [WriteToFile] Line selector must be EOF or Line followed by a positive integer=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                    if not errorlevel 1 (
                        findstr /b /c:"[FAIL] [WriteToIni] Key must contain nonblank section and key names=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                        if not errorlevel 1 (
                            findstr /b /c:"[FAIL] [WriteToPref] Format must contain [PREF] followed by [VALUE]=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                            if not errorlevel 1 (
                                findstr /x /c:"[FAIL] [WriteToReg] First entry must be MainKey" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
                                if not errorlevel 1 set "T46_INVALID_DYNAMIC=PASS"
                            )
                        )
                    )
                )
            )
        )
    )
)

set "T46_JAVA_REPORT=FAIL"
if defined T46_VALID_REPORT_PATH if exist "!T46_VALID_REPORT_PATH!" (
    findstr /b /c:"[PASS] [Java] Portable Java runtime is usable and has first priority=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /b /c:"[PASS] [Java] Java ZIP setup package is recognized without installation=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /b /c:"[PASS] [Java] JavaURL is a valid direct HTTP or HTTPS source; no download was performed=" "!T46_VALID_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 (
                findstr /x /c:"[PASS] [Java] Required Java has an available source; no download or installation was performed" "!T46_VALID_REPORT_PATH!" >nul 2>&1
                if not errorlevel 1 set "T46_JAVA_REPORT=PASS"
            )
        )
    )
)

set "T46_INVALID_JAVA=FAIL"
if defined T46_INVALID_REPORT_PATH if exist "!T46_INVALID_REPORT_PATH!" (
    findstr /b /c:"[FAIL] [Java] Legacy Java EXE setup package does not have an MZ header=" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"[FAIL] [Java] JavaURL must be a direct HTTP or HTTPS package URL=ftp://example.invalid/java-runtime.zip" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 set "T46_INVALID_JAVA=PASS"
    )
)

set "T46_ATTENTION_SUMMARY=FAIL"
if defined T46_INVALID_REPORT_PATH if exist "!T46_INVALID_REPORT_PATH!" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Helpers\Test46_ProbeAttentionSummary_Check.ps1" "!T46_INVALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T46_ATTENTION_SUMMARY=PASS"
)

set "T46=FAIL"
if "!T46_VALID_CODE!"=="PASS" if "!T46_INVALID_CODE!"=="PASS" if "!T46_NO_LAUNCH!"=="PASS" if "!T46_INI_SAFE!"=="PASS" if "!T46_FILES_SAFE!"=="PASS" if "!T46_JAVA_SAFE!"=="PASS" if "!T46_REG_SAFE!"=="PASS" if "!T46_REPORT!"=="PASS" if "!T46_INVALID_REPORT!"=="PASS" if "!T46_OPERATIONS_REPORT!"=="PASS" if "!T46_INVALID_OPERATIONS!"=="PASS" if "!T46_DIRREMOVE_REPORT!"=="PASS" if "!T46_DYNAMIC_REPORT!"=="PASS" if "!T46_INVALID_DYNAMIC!"=="PASS" if "!T46_JAVA_REPORT!"=="PASS" if "!T46_INVALID_JAVA!"=="PASS" if "!T46_ATTENTION_SUMMARY!"=="PASS" if "!T46_REPORT_EXTENSION!"=="PASS" set "T46=PASS"

if "!T46!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test\Probe46" /f >nul 2>&1

echo Running Test 47 - ProcMonPath Resolution and Probe Reporting...
set /a TOTAL+=1

if exist "Working\Test47" rmdir /s /q "Working\Test47"
mkdir "Working\Test47\Macro\Launcher" >nul 2>&1
mkdir "Working\Test47\Macro\Root\Lib\Tools\ProcessMonitor" >nul 2>&1
mkdir "Working\Test47\Default\Launcher" >nul 2>&1
mkdir "Working\Test47\Default\Root\Lib\Tools\ProcessMonitor" >nul 2>&1
mkdir "Working\Test47\Missing\Launcher" >nul 2>&1
mkdir "Working\Test47\Missing\Root" >nul 2>&1
mkdir "Working\Test47\Invalid\Launcher" >nul 2>&1
mkdir "Working\Test47\Invalid\Root\Tools" >nul 2>&1
mkdir "Working\Test47\Environment\Launcher" >nul 2>&1
mkdir "Working\Test47\Environment\Root\EnvTools" >nul 2>&1

for %%C in (Macro Default Missing Invalid Environment) do (
    copy /y "%LAUNCHER%" "Working\Test47\%%C\Launcher\X-Launcher_x64.exe" >nul 2>&1
    > "Working\Test47\%%C\Root\Payload.bat" echo @echo off
    >>"Working\Test47\%%C\Root\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
    >>"Working\Test47\%%C\Root\Payload.bat" echo exit /b 0
)

copy /y "Configs\47A_ProcMon_Macro_Folder.ini" "Working\Test47\Macro\Config.ini" >nul 2>&1
copy /y "Configs\47B_ProcMon_Blank_Default.ini" "Working\Test47\Default\Config.ini" >nul 2>&1
copy /y "Configs\47C_ProcMon_Missing.ini" "Working\Test47\Missing\Config.ini" >nul 2>&1
copy /y "Configs\47D_ProcMon_Invalid_Name.ini" "Working\Test47\Invalid\Config.ini" >nul 2>&1
copy /y "Configs\47E_ProcMon_Environment.ini" "Working\Test47\Environment\Config.ini" >nul 2>&1

> "Working\Test47\Macro\Root\Lib\Tools\ProcessMonitor\Procmon64.exe" echo FAKE_PROCMON_MACRO
> "Working\Test47\Default\Root\Lib\Tools\ProcessMonitor\Procmon64.exe" echo FAKE_PROCMON_DEFAULT
> "Working\Test47\Invalid\Root\Tools\NotProcessMonitor.exe" echo FAKE_OTHER_TOOL
> "Working\Test47\Environment\Root\EnvTools\Procmon64.exe" echo FAKE_PROCMON_ENVIRONMENT
copy /y "Working\Test47\Macro\Root\Lib\Tools\ProcessMonitor\Procmon64.exe" "Working\Test47\Macro\Root\Lib\Tools\ProcessMonitor\Procmon64.before.exe" >nul 2>&1
copy /y "Working\Test47\Default\Root\Lib\Tools\ProcessMonitor\Procmon64.exe" "Working\Test47\Default\Root\Lib\Tools\ProcessMonitor\Procmon64.before.exe" >nul 2>&1
copy /y "Working\Test47\Invalid\Root\Tools\NotProcessMonitor.exe" "Working\Test47\Invalid\Root\Tools\NotProcessMonitor.before.exe" >nul 2>&1
copy /y "Working\Test47\Environment\Root\EnvTools\Procmon64.exe" "Working\Test47\Environment\Root\EnvTools\Procmon64.before.exe" >nul 2>&1

set "T47_PROCMON_ENV=%CD%\Working\Test47\Environment\Root\EnvTools\Procmon64.exe"

"Working\Test47\Macro\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test47\Macro\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T47_MACRO_EXIT=!ERRORLEVEL!"
"Working\Test47\Default\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test47\Default\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T47_DEFAULT_EXIT=!ERRORLEVEL!"
"Working\Test47\Missing\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test47\Missing\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T47_MISSING_EXIT=!ERRORLEVEL!"
"Working\Test47\Invalid\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test47\Invalid\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T47_INVALID_EXIT=!ERRORLEVEL!"
"Working\Test47\Environment\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test47\Environment\Config.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T47_ENV_EXIT=!ERRORLEVEL!"

set "T47_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T47_PROBE=%CD%\..\_Issue47_ProcMonPath_Probe.au3"
set "T47_HELPER_EXIT=99"
if exist "!T47_PROBE!" del /q "!T47_PROBE!" >nul 2>&1
if exist "!T47_AUTOIT!" (
    copy /y "Helpers\Issue47_ProcMonPath_Probe.au3" "!T47_PROBE!" >nul 2>&1
    if exist "!T47_PROBE!" (
        pushd ".."
        "!T47_AUTOIT!" /ErrorStdOut "_Issue47_ProcMonPath_Probe.au3" >nul 2>&1
        set "T47_HELPER_EXIT=!ERRORLEVEL!"
        popd
    )
)
if exist "!T47_PROBE!" del /q "!T47_PROBE!" >nul 2>&1

set "T47_MACRO_REPORT_PATH="
set "T47_DEFAULT_REPORT_PATH="
set "T47_MISSING_REPORT_PATH="
set "T47_INVALID_REPORT_PATH="
set "T47_ENV_REPORT_PATH="
for %%F in ("Working\Test47\Macro\Launcher\Diagnostics\*.txt" "Working\Test47\Macro\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T47_MACRO_REPORT_PATH=%%~fF"
for %%F in ("Working\Test47\Default\Launcher\Diagnostics\*.txt" "Working\Test47\Default\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T47_DEFAULT_REPORT_PATH=%%~fF"
for %%F in ("Working\Test47\Missing\Launcher\Diagnostics\*.txt" "Working\Test47\Missing\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T47_MISSING_REPORT_PATH=%%~fF"
for %%F in ("Working\Test47\Invalid\Launcher\Diagnostics\*.txt" "Working\Test47\Invalid\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T47_INVALID_REPORT_PATH=%%~fF"
for %%F in ("Working\Test47\Environment\Launcher\Diagnostics\*.txt" "Working\Test47\Environment\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T47_ENV_REPORT_PATH=%%~fF"

set "T47_EXITS=FAIL"
if "!T47_MACRO_EXIT!"=="0" if "!T47_DEFAULT_EXIT!"=="0" if "!T47_MISSING_EXIT!"=="0" if "!T47_INVALID_EXIT!"=="0" if "!T47_ENV_EXIT!"=="0" set "T47_EXITS=PASS"

set "T47_MACRO=FAIL"
if defined T47_MACRO_REPORT_PATH (
    findstr /b /c:"[PASS] [Process Monitor] ProcMonPath resolved from the configured folder=" "!T47_MACRO_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T47_MACRO=PASS"
)

set "T47_DEFAULT=FAIL"
if defined T47_DEFAULT_REPORT_PATH (
    findstr /b /c:"[PASS] [Process Monitor] Default ProcMon executable was found=" "!T47_DEFAULT_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T47_DEFAULT=PASS"
)

set "T47_MISSING=FAIL"
if defined T47_MISSING_REPORT_PATH (
    findstr /b /c:"[WARN] [Process Monitor] ProcMonPath does not exist; Application Trace will be unavailable=" "!T47_MISSING_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T47_MISSING=PASS"
)

set "T47_INVALID=FAIL"
if defined T47_INVALID_REPORT_PATH (
    findstr /b /c:"[WARN] [Process Monitor] ProcMonPath file name is not supported; use Procmon.exe, Procmon64.exe or Procmon64a.exe=" "!T47_INVALID_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T47_INVALID=PASS"
)

set "T47_ENV=FAIL"
if defined T47_ENV_REPORT_PATH (
    findstr /b /c:"[PASS] [Process Monitor] ProcMonPath resolved to an executable=" "!T47_ENV_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T47_ENV=PASS"
)

set "T47_NO_LAUNCH=PASS"
for %%C in (Macro Default Missing Invalid Environment) do if exist "Working\Test47\%%C\Root\PayloadRan.txt" set "T47_NO_LAUNCH=FAIL"

set "T47_FILES_SAFE=PASS"
fc /b "Working\Test47\Macro\Root\Lib\Tools\ProcessMonitor\Procmon64.exe" "Working\Test47\Macro\Root\Lib\Tools\ProcessMonitor\Procmon64.before.exe" >nul 2>&1
if errorlevel 1 set "T47_FILES_SAFE=FAIL"
fc /b "Working\Test47\Default\Root\Lib\Tools\ProcessMonitor\Procmon64.exe" "Working\Test47\Default\Root\Lib\Tools\ProcessMonitor\Procmon64.before.exe" >nul 2>&1
if errorlevel 1 set "T47_FILES_SAFE=FAIL"
fc /b "Working\Test47\Invalid\Root\Tools\NotProcessMonitor.exe" "Working\Test47\Invalid\Root\Tools\NotProcessMonitor.before.exe" >nul 2>&1
if errorlevel 1 set "T47_FILES_SAFE=FAIL"
fc /b "Working\Test47\Environment\Root\EnvTools\Procmon64.exe" "Working\Test47\Environment\Root\EnvTools\Procmon64.before.exe" >nul 2>&1
if errorlevel 1 set "T47_FILES_SAFE=FAIL"

set "T47_TEMPLATE=FAIL"
findstr /x /c:"ProcMonPath=" "..\x-launcher.ini" >nul 2>&1
if not errorlevel 1 (
    findstr /x /c:"; *** optional Process Monitor executable or folder used by Application Trace" "..\x-launcher.ini" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"; *** absolute or Root-relative; blank tries $Lib$\Tools\ProcessMonitor\Procmon64.exe" "..\x-launcher.ini" >nul 2>&1
        if not errorlevel 1 set "T47_TEMPLATE=PASS"
    )
)

set "T47_ABSOLUTE=FAIL"
set "T47_RELATIVE=FAIL"
set "T47_FOLDER=FAIL"
set "T47_HELPER_DEFAULT=FAIL"
set "T47_HELPER_INVALID=FAIL"
set "T47_HELPER_MISSING=FAIL"
set "T47_UNC=FAIL"
set "T47_READONLY=FAIL"
findstr /x /c:"Absolute ProcMon executable resolves=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_ABSOLUTE=PASS"
findstr /x /c:"Relative ProcMon path resolves against Root=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_RELATIVE=PASS"
findstr /x /c:"ProcMon folder selects a supported executable=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_FOLDER=PASS"
findstr /x /c:"Blank ProcMonPath checks the documented default=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_HELPER_DEFAULT=PASS"
findstr /x /c:"Unexpected executable name is rejected=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_HELPER_INVALID=PASS"
findstr /x /c:"Missing configured ProcMon path is reported=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_HELPER_MISSING=PASS"
findstr /x /c:"UNC ProcMon path prefix is preserved=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_UNC=PASS"
findstr /x /c:"Resolver performs no launch download or EULA action=PASS" "Working\Test47\Helper.log" >nul 2>&1
if not errorlevel 1 set "T47_READONLY=PASS"

set "T47=FAIL"
if "!T47_EXITS!"=="PASS" if "!T47_MACRO!"=="PASS" if "!T47_DEFAULT!"=="PASS" if "!T47_MISSING!"=="PASS" if "!T47_INVALID!"=="PASS" if "!T47_ENV!"=="PASS" if "!T47_NO_LAUNCH!"=="PASS" if "!T47_FILES_SAFE!"=="PASS" if "!T47_TEMPLATE!"=="PASS" if "!T47_ABSOLUTE!"=="PASS" if "!T47_RELATIVE!"=="PASS" if "!T47_FOLDER!"=="PASS" if "!T47_HELPER_DEFAULT!"=="PASS" if "!T47_HELPER_INVALID!"=="PASS" if "!T47_HELPER_MISSING!"=="PASS" if "!T47_UNC!"=="PASS" if "!T47_READONLY!"=="PASS" if "!T47_HELPER_EXIT!"=="0" set "T47=PASS"

if "!T47!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 48 - X-Launcher-Only Application Trace...
set /a TOTAL+=1

if exist "Working\Test48" rmdir /s /q "Working\Test48"
mkdir "Working\Test48" >nul 2>&1

set "T48_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T48_PROBE=%CD%\..\_Issue48_ApplicationTrace_Probe.au3"
set "T48_HELPER_EXIT=99"
if exist "!T48_PROBE!" del /q "!T48_PROBE!" >nul 2>&1
if exist "!T48_AUTOIT!" (
    copy /y "Helpers\Issue48_ApplicationTrace_Probe.au3" "!T48_PROBE!" >nul 2>&1
    if exist "!T48_PROBE!" (
        pushd ".."
        "!T48_AUTOIT!" /ErrorStdOut "_Issue48_ApplicationTrace_Probe.au3" >nul 2>&1
        set "T48_HELPER_EXIT=!ERRORLEVEL!"
        popd
    )
)
if exist "!T48_PROBE!" del /q "!T48_PROBE!" >nul 2>&1

set "T48_REPORT=FAIL"
set "T48_FILE_CATEGORY=FAIL"
set "T48_EXITCODE=FAIL"
set "T48_PROCESS=FAIL"
set "T48_FINALIZE=FAIL"
set "T48_ROUTE=FAIL"
set "T48_NO_PROCMON=FAIL"
set "T48_PROCMON_ELEVATION=FAIL"
set "T48_PROCMON_COMMANDS=FAIL"
set "T48_PROCMON_PROMPT_WAIT=FAIL"
set "T48_PROCMON_LIMITS=FAIL"
set "T48_PROCMON_STOP=FAIL"
set "T48_SESSION_END=FAIL"
set "T48_MISSING=FAIL"
set "T48_UNIQUE=FAIL"
set "T48_PIDWAIT=FAIL"
set "T48_ARGS=FAIL"
set "T48_AUTO_OPEN=FAIL"

findstr /x /c:"Trace summary contains required metadata categories totals privacy and ordered detail=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_REPORT=PASS"
findstr /x /c:"Trace file category includes directory creation and file operations=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_FILE_CATEGORY=PASS"
findstr /x /c:"Trace retained process handle records the real application exit code=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_EXITCODE=PASS"
findstr /x /c:"Trace summary records launcher application and observed child process details=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PROCESS=PASS"
findstr /x /c:"Trace finalization guard prevents report overwrite=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_FINALIZE=PASS"
findstr /x /c:"Confirmed Trace route continues into the real launcher lifecycle=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_ROUTE=PASS"
findstr /x /c:"Application Trace never downloads Process Monitor or accepts its EULA automatically=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_NO_PROCMON=PASS"
findstr /x /c:"Process Monitor capture start and stop explicitly request Windows elevation=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PROCMON_ELEVATION=PASS"
findstr /x /c:"Process Monitor capture uses verified backing-file and terminate switches=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PROCMON_COMMANDS=PASS"
findstr /x /c:"Process Monitor startup preserves the full elevation and licence prompt allowance=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PROCMON_PROMPT_WAIT=PASS"
findstr /x /c:"Process Monitor storage safeguards enforce maximum size and reserved free space=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PROCMON_LIMITS=PASS"
findstr /x /c:"Trace finalization stops Process Monitor after cleanup and preserves the native PML path=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PROCMON_STOP=PASS"
findstr /x /c:"Trace session end is recorded after native Process Monitor finalization=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_SESSION_END=PASS"
findstr /x /c:"Missing Process Monitor offers X-Launcher-only logging or Cancel=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_MISSING=PASS"
findstr /x /c:"Trace creates a unique application diagnostics session folder=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_UNIQUE=PASS"
findstr /x /c:"Trace records application PID while retaining waited completion=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_PIDWAIT=PASS"
findstr /x /c:"Internal diagnostic switches are not forwarded to the configured payload=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_ARGS=PASS"
findstr /x /c:"Plain-language Trace results open first with advanced report and Trace Summary fallbacks=PASS" "Working\Test48\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48_AUTO_OPEN=PASS"

set "T48=FAIL"
if "!T48_REPORT!"=="PASS" if "!T48_FILE_CATEGORY!"=="PASS" if "!T48_EXITCODE!"=="PASS" if "!T48_PROCESS!"=="PASS" if "!T48_FINALIZE!"=="PASS" if "!T48_ROUTE!"=="PASS" if "!T48_NO_PROCMON!"=="PASS" if "!T48_PROCMON_ELEVATION!"=="PASS" if "!T48_PROCMON_COMMANDS!"=="PASS" if "!T48_PROCMON_PROMPT_WAIT!"=="PASS" if "!T48_PROCMON_LIMITS!"=="PASS" if "!T48_PROCMON_STOP!"=="PASS" if "!T48_SESSION_END!"=="PASS" if "!T48_MISSING!"=="PASS" if "!T48_UNIQUE!"=="PASS" if "!T48_PIDWAIT!"=="PASS" if "!T48_ARGS!"=="PASS" if "!T48_AUTO_OPEN!"=="PASS" if "!T48_HELPER_EXIT!"=="0" set "T48=PASS"

if "!T48!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 48B - Readable Application Portability Report...
set /a TOTAL+=1

if exist "Working\Test48B" rmdir /s /q "Working\Test48B"
mkdir "Working\Test48B" >nul 2>&1

set "T48B_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T48B_PROBE=%CD%\..\_Issue48B_PortabilityReport_Probe.au3"
set "T48B_HELPER_EXIT=99"
if exist "!T48B_PROBE!" del /q "!T48B_PROBE!" >nul 2>&1
if exist "!T48B_AUTOIT!" (
    copy /y "Helpers\Issue48B_PortabilityReport_Probe.au3" "!T48B_PROBE!" >nul 2>&1
    if exist "!T48B_PROBE!" (
        pushd ".."
        "!T48B_AUTOIT!" /ErrorStdOut "_Issue48B_PortabilityReport_Probe.au3" >nul 2>&1
        set "T48B_HELPER_EXIT=!ERRORLEVEL!"
        popd
    )
)
if exist "!T48B_PROBE!" del /q "!T48B_PROBE!" >nul 2>&1

set "T48B_CREATED=FAIL"
set "T48B_SIMPLE=FAIL"
set "T48B_SIMPLE_INI=FAIL"
set "T48B_BLOCKED_GROUP=FAIL"
set "T48B_NTFS_METADATA=FAIL"
set "T48B_SYSTEM_INSTALL=FAIL"
set "T48B_XML=FAIL"
set "T48B_FILTER=FAIL"
set "T48B_FASTCSV=FAIL"
set "T48B_INDEXED=FAIL"
set "T48B_REGPARSER=FAIL"
set "T48B_COLLAPSE=FAIL"
set "T48B_ATTRIBUTION=FAIL"
set "T48B_MANAGED=FAIL"
set "T48B_UNMANAGED=FAIL"
set "T48B_DISCLOSURE=FAIL"
set "T48B_FORMAT=FAIL"
findstr /x /c:"ProcMon XML process index maps to PID and canonical parser input=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_XML=PASS"
findstr /x /c:"Automatic ProcMon write filter is generated loaded and applied without INI changes=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_FILTER=PASS"
findstr /x /c:"Fast canonical CSV parser retains commas and escaped quotes=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_FASTCSV=PASS"
findstr /x /c:"Indexed repeated-target collapse avoids linear report growth=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_INDEXED=PASS"
findstr /x /c:"Direct REG parser extracts the portable top-level registry root=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_REGPARSER=PASS"
findstr /x /c:"Readable portability report is created from exported Process Monitor CSV=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_CREATED=PASS"
findstr /x /c:"Plain-language Trace results separate launcher failures blocked warnings and portability passes=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_SIMPLE=PASS"
findstr /x /c:"Plain-language Trace passes identify matching INI settings and omit launcher-only counts=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_SIMPLE_INI=PASS"
findstr /x /c:"Plain-language Trace separates blocked counts and groups DriverStore targets=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_BLOCKED_GROUP=PASS"
findstr /x /c:"Plain-language Trace excludes NTFS metadata from portability warnings=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_NTFS_METADATA=PASS"
findstr /x /c:"Plain-language Trace separates Windows files and installation changes without hiding registry warnings=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_SYSTEM_INSTALL=PASS"
findstr /x /c:"Repeated low-level file events collapse into unique target counts=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_COLLAPSE=PASS"
findstr /x /c:"Application child PID activity is attributed and unrelated PID activity is excluded=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_ATTRIBUTION=PASS"
findstr /x /c:"Current INI file and registry rules classify external targets as managed=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_MANAGED=PASS"
findstr /x /c:"Unmanaged file and registry writes remain visible for user review=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_UNMANAGED=PASS"
findstr /x /c:"Relevant failures state limitations residue and privacy are explicit=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_DISCLOSURE=PASS"
findstr /x /c:"Portability report uses equals separators for readable key-value fields=PASS" "Working\Test48B\Helper.log" >nul 2>&1
if not errorlevel 1 set "T48B_FORMAT=PASS"

set "T48B=FAIL"
if "!T48B_XML!"=="PASS" if "!T48B_FILTER!"=="PASS" if "!T48B_FASTCSV!"=="PASS" if "!T48B_INDEXED!"=="PASS" if "!T48B_REGPARSER!"=="PASS" if "!T48B_CREATED!"=="PASS" if "!T48B_SIMPLE!"=="PASS" if "!T48B_SIMPLE_INI!"=="PASS" if "!T48B_BLOCKED_GROUP!"=="PASS" if "!T48B_NTFS_METADATA!"=="PASS" if "!T48B_SYSTEM_INSTALL!"=="PASS" if "!T48B_COLLAPSE!"=="PASS" if "!T48B_ATTRIBUTION!"=="PASS" if "!T48B_MANAGED!"=="PASS" if "!T48B_UNMANAGED!"=="PASS" if "!T48B_DISCLOSURE!"=="PASS" if "!T48B_FORMAT!"=="PASS" if "!T48B_HELPER_EXIT!"=="0" set "T48B=PASS"

if "!T48B!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 48C - FileMove Wildcard No-Match Semantics...
set /a TOTAL+=1

if exist "Working\Test48C" rmdir /s /q "Working\Test48C"
mkdir "Working\Test48C\Launcher" >nul 2>&1
mkdir "Working\Test48C\Root\Temp" >nul 2>&1
mkdir "Working\Test48C\Root\Downloads" >nul 2>&1
mkdir "Working\Test48C\Root\CleanupTarget" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48C\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\48C_FileMove_Wildcard_No_Match.ini" "Working\Test48C\Launcher\48C_FileMove_Wildcard_No_Match.ini" >nul 2>&1

> "Working\Test48C\Root\Payload.bat" echo @echo off
>>"Working\Test48C\Root\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test48C\Root\Payload.bat" echo exit /b 0
> "Working\Test48C\Root\CleanupTarget\Sentinel.txt" echo REMOVE_WITH_DIRECTORY

"Working\Test48C\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48C\Launcher\48C_FileMove_Wildcard_No_Match.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T48C_PROBE_EXIT=!ERRORLEVEL!"

set "T48C_PROBE_REPORT_PATH="
for %%F in ("Working\Test48C\Launcher\Diagnostics\48C_FileMove_Wildcard_No_Match_Configuration_Probe_*.txt" "Working\Test48C\Launcher\Diagnostics\48C_FileMove_Wildcard_No_Match_Configuration_Probe_*.log") do if exist "%%~fF" set "T48C_PROBE_REPORT_PATH=%%~fF"

set "T48C_PROBE_CODE=FAIL"
set "T48C_PROBE_WILDCARD=FAIL"
set "T48C_PROBE_EXACT=FAIL"
if "!T48C_PROBE_EXIT!"=="10" set "T48C_PROBE_CODE=PASS"
if defined T48C_PROBE_REPORT_PATH if exist "!T48C_PROBE_REPORT_PATH!" (
    findstr /l /b /c:"[NOT USED] [RunAfter] FileMove wildcard source matched no files; runtime will skip this operation=" "!T48C_PROBE_REPORT_PATH!" | findstr /l /c:"StremioSetup-" >nul 2>&1
    if not errorlevel 1 set "T48C_PROBE_WILDCARD=PASS"
    findstr /l /b /c:"[FAIL] [RunAfter] FileMove source does not exist=" "!T48C_PROBE_REPORT_PATH!" | findstr /l /c:"Required.exe" >nul 2>&1
    if not errorlevel 1 set "T48C_PROBE_EXACT=PASS"
)

start "" /wait "Working\Test48C\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48C\Launcher\48C_FileMove_Wildcard_No_Match.ini" >nul 2>&1
set "T48C_EXIT=!ERRORLEVEL!"
set "T48C_DEBUG_PATH=%CD%\Working\Test48C\Launcher\48C_FileMove_Wildcard_No_Match.dbg"

set "T48C_LAUNCH=FAIL"
set "T48C_DEBUG=FAIL"
set "T48C_WILDCARD_SKIP=FAIL"
set "T48C_WILDCARD_NO_FAIL=FAIL"
set "T48C_CONTINUE=FAIL"
set "T48C_EXACT_FAIL=FAIL"
if "!T48C_EXIT!"=="0" if exist "Working\Test48C\Root\PayloadRan.txt" set "T48C_LAUNCH=PASS"
if exist "!T48C_DEBUG_PATH!" set "T48C_DEBUG=PASS"
if "!T48C_DEBUG!"=="PASS" (
    findstr /l /c:"[SKIP] [RunAfter] FileMove=" "!T48C_DEBUG_PATH!" | findstr /l /c:"StremioSetup-" >nul 2>&1
    if not errorlevel 1 set "T48C_WILDCARD_SKIP=PASS"
    findstr /l /c:"[FAIL] [RunAfter] FileMove=" "!T48C_DEBUG_PATH!" | findstr /l /c:"StremioSetup-" >nul 2>&1
    if errorlevel 1 set "T48C_WILDCARD_NO_FAIL=PASS"
    findstr /l /c:"[FAIL] [RunAfter] FileMove=" "!T48C_DEBUG_PATH!" | findstr /l /c:"Required.exe" >nul 2>&1
    if not errorlevel 1 set "T48C_EXACT_FAIL=PASS"
)
if not exist "Working\Test48C\Root\CleanupTarget" set "T48C_CONTINUE=PASS"

set "T48C=FAIL"
if "!T48C_PROBE_CODE!"=="PASS" if "!T48C_PROBE_WILDCARD!"=="PASS" if "!T48C_PROBE_EXACT!"=="PASS" if "!T48C_LAUNCH!"=="PASS" if "!T48C_DEBUG!"=="PASS" if "!T48C_WILDCARD_SKIP!"=="PASS" if "!T48C_WILDCARD_NO_FAIL!"=="PASS" if "!T48C_CONTINUE!"=="PASS" if "!T48C_EXACT_FAIL!"=="PASS" set "T48C=PASS"

if "!T48C!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 48D - RunAfter Stop-On-Failure Policy...
set /a TOTAL+=1

if exist "Working\Test48D" rmdir /s /q "Working\Test48D"
mkdir "Working\Test48D\Default\Launcher" >nul 2>&1
mkdir "Working\Test48D\Default\Root\Temp" >nul 2>&1
mkdir "Working\Test48D\Default\Root\Downloads" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48D\Default\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\48D_Default_Continue.ini" "Working\Test48D\Default\Launcher\48D_Default_Continue.ini" >nul 2>&1

> "Working\Test48D\Default\Root\Payload.bat" echo @echo off
>>"Working\Test48D\Default\Root\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test48D\Default\Root\Payload.bat" echo exit /b 0
> "Working\Test48D\Default\Root\AfterFailure.bat" echo @echo off
>>"Working\Test48D\Default\Root\AfterFailure.bat" echo ^> "%%~dp0AfterFailure.marker" echo CONTINUED
>>"Working\Test48D\Default\Root\AfterFailure.bat" echo exit /b 0
> "Working\Test48D\Default\Root\Temp\Sentinel.txt" echo DELETE_WITH_TEMP

"Working\Test48D\Default\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48D\Default\Launcher\48D_Default_Continue.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T48D_DEFAULT_PROBE_EXIT=!ERRORLEVEL!"
set "T48D_DEFAULT_PROBE_PATH="
for %%F in ("Working\Test48D\Default\Launcher\Diagnostics\48D_Default_Continue_Configuration_Probe_*.txt" "Working\Test48D\Default\Launcher\Diagnostics\48D_Default_Continue_Configuration_Probe_*.log") do if exist "%%~fF" set "T48D_DEFAULT_PROBE_PATH=%%~fF"

set "T48D_PROBE_DEFAULT=FAIL"
if defined T48D_DEFAULT_PROBE_PATH if exist "!T48D_DEFAULT_PROBE_PATH!" (
    findstr /l /x /c:"[NOT USED] [Options] RunAfterStopOnFailure is not configured; default applies=false" "!T48D_DEFAULT_PROBE_PATH!" >nul 2>&1
    if not errorlevel 1 set "T48D_PROBE_DEFAULT=PASS"
)

start "" /wait "Working\Test48D\Default\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48D\Default\Launcher\48D_Default_Continue.ini" >nul 2>&1
set "T48D_DEFAULT_EXIT=!ERRORLEVEL!"

set "T48D_DEFAULT_CONTINUE=FAIL"
set "T48D_DEFAULT_TEMP=FAIL"
if "!T48D_DEFAULT_EXIT!"=="0" if exist "Working\Test48D\Default\Root\PayloadRan.txt" if exist "Working\Test48D\Default\Root\AfterFailure.marker" set "T48D_DEFAULT_CONTINUE=PASS"
if not exist "Working\Test48D\Default\Root\Temp" set "T48D_DEFAULT_TEMP=PASS"

mkdir "Working\Test48D\Stop\Launcher" >nul 2>&1
mkdir "Working\Test48D\Stop\Root\Temp" >nul 2>&1
mkdir "Working\Test48D\Stop\Root\Downloads" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48D\Stop\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\48D_Stop_On_Failure.ini" "Working\Test48D\Stop\Launcher\48D_Stop_On_Failure.ini" >nul 2>&1

> "Working\Test48D\Stop\Root\Payload.bat" echo @echo off
>>"Working\Test48D\Stop\Root\Payload.bat" echo reg query "HKCU\Software\XLauncher_Test\RunAfterStop48D" /v State 2^>nul ^| find /i "PORTABLE" ^>nul
>>"Working\Test48D\Stop\Root\Payload.bat" echo if errorlevel 1 exit /b 41
>>"Working\Test48D\Stop\Root\Payload.bat" echo ^> "%%~dp0PayloadPortable.marker" echo PORTABLE
>>"Working\Test48D\Stop\Root\Payload.bat" echo exit /b 0
> "Working\Test48D\Stop\Root\AfterSkip.bat" echo @echo off
>>"Working\Test48D\Stop\Root\AfterSkip.bat" echo ^> "%%~dp0AfterSkip.marker" echo CONTINUED_AFTER_SKIP
>>"Working\Test48D\Stop\Root\AfterSkip.bat" echo exit /b 0
> "Working\Test48D\Stop\Root\Blocked.bat" echo @echo off
>>"Working\Test48D\Stop\Root\Blocked.bat" echo ^> "%%~dp0Blocked.marker" echo SHOULD_NOT_RUN
>>"Working\Test48D\Stop\Root\Blocked.bat" echo exit /b 0
> "Working\Test48D\Stop\Root\Temp\Sentinel.txt" echo DELETE_WITH_TEMP
> "Working\Test48D\Stop\Root\Portable.reg" echo Windows Registry Editor Version 5.00
>>"Working\Test48D\Stop\Root\Portable.reg" echo.
>>"Working\Test48D\Stop\Root\Portable.reg" echo [HKEY_CURRENT_USER\Software\XLauncher_Test\RunAfterStop48D]
>>"Working\Test48D\Stop\Root\Portable.reg" echo "State"="PORTABLE"

reg delete "HKCU\Software\XLauncher_Test\RunAfterStop48D" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\RunAfterStop48D" /v State /t REG_SZ /d HOST /f >nul 2>&1

"Working\Test48D\Stop\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48D\Stop\Launcher\48D_Stop_On_Failure.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T48D_STOP_PROBE_EXIT=!ERRORLEVEL!"
set "T48D_STOP_PROBE_PATH="
for %%F in ("Working\Test48D\Stop\Launcher\Diagnostics\48D_Stop_On_Failure_Configuration_Probe_*.txt" "Working\Test48D\Stop\Launcher\Diagnostics\48D_Stop_On_Failure_Configuration_Probe_*.log") do if exist "%%~fF" set "T48D_STOP_PROBE_PATH=%%~fF"

set "T48D_PROBE_CODE=FAIL"
set "T48D_PROBE_TRUE=FAIL"
set "T48D_PROBE_KNOWN=FAIL"
set "T48D_PROBE_REGISTRY=FAIL"
if "!T48D_STOP_PROBE_EXIT!"=="10" set "T48D_PROBE_CODE=PASS"
if defined T48D_STOP_PROBE_PATH if exist "!T48D_STOP_PROBE_PATH!" (
    findstr /l /x /c:"[PASS] [Options] RunAfterStopOnFailure is a valid Boolean=true" "!T48D_STOP_PROBE_PATH!" >nul 2>&1
    if not errorlevel 1 set "T48D_PROBE_TRUE=PASS"
    findstr /l /x /c:"[WARN] [Options] Unknown key=RunAfterStopOnFailure" "!T48D_STOP_PROBE_PATH!" >nul 2>&1
    if errorlevel 1 set "T48D_PROBE_KNOWN=PASS"
)
reg query "HKCU\Software\XLauncher_Test\RunAfterStop48D" /v State 2>nul | find /i "HOST" >nul
if not errorlevel 1 set "T48D_PROBE_REGISTRY=PASS"

start "" /wait "Working\Test48D\Stop\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48D\Stop\Launcher\48D_Stop_On_Failure.ini" >nul 2>&1
set "T48D_STOP_EXIT=!ERRORLEVEL!"
set "T48D_STOP_DEBUG_PATH=%CD%\Working\Test48D\Stop\Launcher\48D_Stop_On_Failure.dbg"

set "T48D_PORTABLE=FAIL"
set "T48D_SKIP_CONTINUE=FAIL"
set "T48D_STOPPED=FAIL"
set "T48D_REGISTRY=FAIL"
set "T48D_TEMP=FAIL"
set "T48D_WILDCARD_SKIP=FAIL"
set "T48D_EXACT_FAIL=FAIL"
set "T48D_DEBUG_STOP=FAIL"
set "T48D_TEMPLATE=FAIL"
if "!T48D_STOP_EXIT!"=="0" if exist "Working\Test48D\Stop\Root\PayloadPortable.marker" set "T48D_PORTABLE=PASS"
if exist "Working\Test48D\Stop\Root\AfterSkip.marker" set "T48D_SKIP_CONTINUE=PASS"
if not exist "Working\Test48D\Stop\Root\Blocked.marker" set "T48D_STOPPED=PASS"
reg query "HKCU\Software\XLauncher_Test\RunAfterStop48D" /v State 2>nul | find /i "HOST" >nul
if not errorlevel 1 set "T48D_REGISTRY=PASS"
if not exist "Working\Test48D\Stop\Root\Temp" set "T48D_TEMP=PASS"
if exist "!T48D_STOP_DEBUG_PATH!" (
    findstr /l /c:"[SKIP] [RunAfter] FileMove=" "!T48D_STOP_DEBUG_PATH!" | findstr /l /c:"OptionalUpdate-" >nul 2>&1
    if not errorlevel 1 set "T48D_WILDCARD_SKIP=PASS"
    findstr /l /c:"[FAIL] [RunAfter] FileMove=" "!T48D_STOP_DEBUG_PATH!" | findstr /l /c:"Required.exe" >nul 2>&1
    if not errorlevel 1 set "T48D_EXACT_FAIL=PASS"
    findstr /l /c:"[SKIP] [RunAfter] Remaining configured operations stopped" "!T48D_STOP_DEBUG_PATH!" | findstr /l /c:"failed=FileMove" >nul 2>&1
    if not errorlevel 1 set "T48D_DEBUG_STOP=PASS"
)
findstr /l /x /c:"RunAfterStopOnFailure=false" "..\x-launcher.ini" >nul 2>&1
if not errorlevel 1 set "T48D_TEMPLATE=PASS"

set "T48D=FAIL"
if "!T48D_PROBE_DEFAULT!"=="PASS" if "!T48D_DEFAULT_CONTINUE!"=="PASS" if "!T48D_DEFAULT_TEMP!"=="PASS" if "!T48D_PROBE_CODE!"=="PASS" if "!T48D_PROBE_TRUE!"=="PASS" if "!T48D_PROBE_KNOWN!"=="PASS" if "!T48D_PROBE_REGISTRY!"=="PASS" if "!T48D_PORTABLE!"=="PASS" if "!T48D_SKIP_CONTINUE!"=="PASS" if "!T48D_STOPPED!"=="PASS" if "!T48D_REGISTRY!"=="PASS" if "!T48D_TEMP!"=="PASS" if "!T48D_WILDCARD_SKIP!"=="PASS" if "!T48D_EXACT_FAIL!"=="PASS" if "!T48D_DEBUG_STOP!"=="PASS" if "!T48D_TEMPLATE!"=="PASS" set "T48D=PASS"

if "!T48D!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test\RunAfterStop48D" /f >nul 2>&1

echo Running Test 48E - Portable LOCALAPPDATA TEMP and TMP Defaults...
set /a TOTAL+=1

if exist "Working\Test48E" rmdir /s /q "Working\Test48E"
mkdir "Working\Test48E\Default\Launcher" >nul 2>&1
mkdir "Working\Test48E\Default\Root" >nul 2>&1
mkdir "Working\Test48E\Enabled\Launcher" >nul 2>&1
mkdir "Working\Test48E\Enabled\Root" >nul 2>&1
mkdir "Working\Test48E\Override\Launcher" >nul 2>&1
mkdir "Working\Test48E\Override\Root" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48E\Default\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48E\Enabled\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48E\Override\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\48E_Portable_Environment_Default.ini" "Working\Test48E\Default\Launcher\48E_Portable_Environment_Default.ini" >nul 2>&1
copy /y "Configs\48E_Portable_Environment_Enabled.ini" "Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.ini" >nul 2>&1
copy /y "Configs\48E_Portable_Environment_Override.ini" "Working\Test48E\Override\Launcher\48E_Portable_Environment_Override.ini" >nul 2>&1

set "T48E_ORIGINAL_LOCALAPPDATA=!LOCALAPPDATA!"
set "T48E_ORIGINAL_TEMP=!TEMP!"
set "T48E_ORIGINAL_TMP=!TMP!"
set "T48E_HOST_LOCALAPPDATA=%CD%\Working\Test48E\Host\Local"
set "T48E_HOST_TEMP=%CD%\Working\Test48E\Host\Temp"
set "T48E_HOST_TMP=%CD%\Working\Test48E\Host\Tmp"
mkdir "!T48E_HOST_LOCALAPPDATA!" >nul 2>&1
mkdir "!T48E_HOST_TEMP!" >nul 2>&1
mkdir "!T48E_HOST_TMP!" >nul 2>&1
set "LOCALAPPDATA=!T48E_HOST_LOCALAPPDATA!"
set "TEMP=!T48E_HOST_TEMP!"
set "TMP=!T48E_HOST_TMP!"

> "Working\Test48E\Default\Root\Payload.bat" echo @echo off
>>"Working\Test48E\Default\Root\Payload.bat" echo if /i not "%%LOCALAPPDATA%%"=="!T48E_HOST_LOCALAPPDATA!" exit /b 51
>>"Working\Test48E\Default\Root\Payload.bat" echo if /i not "%%TEMP%%"=="!T48E_HOST_TEMP!" exit /b 52
>>"Working\Test48E\Default\Root\Payload.bat" echo if /i not "%%TMP%%"=="!T48E_HOST_TMP!" exit /b 53
>>"Working\Test48E\Default\Root\Payload.bat" echo ^> "%%~dp0Default.marker" echo PASS
>>"Working\Test48E\Default\Root\Payload.bat" echo exit /b 0

"Working\Test48E\Default\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48E\Default\Launcher\48E_Portable_Environment_Default.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T48E_DEFAULT_PROBE_EXIT=!ERRORLEVEL!"
set "T48E_DEFAULT_PROBE_PATH="
for %%F in ("Working\Test48E\Default\Launcher\Diagnostics\48E_Portable_Environment_Default_Configuration_Probe_*.txt" "Working\Test48E\Default\Launcher\Diagnostics\48E_Portable_Environment_Default_Configuration_Probe_*.log") do if exist "%%~fF" set "T48E_DEFAULT_PROBE_PATH=%%~fF"
set "T48E_PROBE_DEFAULT=FAIL"
set "T48E_DEFAULT_PROBE_CODE=FAIL"
if "!T48E_DEFAULT_PROBE_EXIT!"=="0" set "T48E_DEFAULT_PROBE_CODE=PASS"
if "!T48E_DEFAULT_PROBE_EXIT!"=="10" set "T48E_DEFAULT_PROBE_CODE=PASS"
if defined T48E_DEFAULT_PROBE_PATH if exist "!T48E_DEFAULT_PROBE_PATH!" (
    findstr /l /x /c:"[NOT USED] [Options] FixLocalAppData is not configured; default applies=false" "!T48E_DEFAULT_PROBE_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /x /c:"[NOT USED] [Options] FixTemp is not configured; default applies=false" "!T48E_DEFAULT_PROBE_PATH!" >nul 2>&1
        if not errorlevel 1 set "T48E_PROBE_DEFAULT=PASS"
    )
)

start "" /wait "Working\Test48E\Default\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48E\Default\Launcher\48E_Portable_Environment_Default.ini" >nul 2>&1
set "T48E_DEFAULT_EXIT=!ERRORLEVEL!"
set "T48E_DEFAULT_RUNTIME=FAIL"
set "T48E_DEFAULT_DIRECTORIES=FAIL"
if exist "Working\Test48E\Default\Root\Default.marker" set "T48E_DEFAULT_RUNTIME=PASS"
if not exist "Working\Test48E\Default\Root\Lib\AppData\Local" set "T48E_DEFAULT_DIRECTORIES=PASS"

> "Working\Test48E\Enabled\Root\Payload.bat" echo @echo off
>>"Working\Test48E\Enabled\Root\Payload.bat" echo if /i not "%%LOCALAPPDATA%%"=="%%~dp0Lib\AppData\Local" exit /b 61
>>"Working\Test48E\Enabled\Root\Payload.bat" echo if /i not "%%TEMP%%"=="%%~dp0Lib\AppData\Local\Temp" exit /b 62
>>"Working\Test48E\Enabled\Root\Payload.bat" echo if /i not "%%TMP%%"=="%%~dp0Lib\AppData\Local\Temp" exit /b 63
>>"Working\Test48E\Enabled\Root\Payload.bat" echo if not exist "%%LOCALAPPDATA%%\." exit /b 64
>>"Working\Test48E\Enabled\Root\Payload.bat" echo if not exist "%%TEMP%%\." exit /b 65
>>"Working\Test48E\Enabled\Root\Payload.bat" echo ^> "%%~dp0Enabled.marker" echo PASS
>>"Working\Test48E\Enabled\Root\Payload.bat" echo exit /b 0

"Working\Test48E\Enabled\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T48E_ENABLED_PROBE_EXIT=!ERRORLEVEL!"
set "T48E_ENABLED_PROBE_PATH="
for %%F in ("Working\Test48E\Enabled\Launcher\Diagnostics\48E_Portable_Environment_Enabled_Configuration_Probe_*.txt" "Working\Test48E\Enabled\Launcher\Diagnostics\48E_Portable_Environment_Enabled_Configuration_Probe_*.log") do if exist "%%~fF" set "T48E_ENABLED_PROBE_PATH=%%~fF"
set "T48E_PROBE_TRUE=FAIL"
set "T48E_PROBE_KNOWN=FAIL"
set "T48E_ENABLED_PROBE_CODE=FAIL"
if "!T48E_ENABLED_PROBE_EXIT!"=="0" set "T48E_ENABLED_PROBE_CODE=PASS"
if "!T48E_ENABLED_PROBE_EXIT!"=="10" set "T48E_ENABLED_PROBE_CODE=PASS"
if defined T48E_ENABLED_PROBE_PATH if exist "!T48E_ENABLED_PROBE_PATH!" (
    findstr /l /x /c:"[PASS] [Options] FixLocalAppData is a valid Boolean=true" "!T48E_ENABLED_PROBE_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /x /c:"[PASS] [Options] FixTemp is a valid Boolean=true" "!T48E_ENABLED_PROBE_PATH!" >nul 2>&1
        if not errorlevel 1 set "T48E_PROBE_TRUE=PASS"
    )
    findstr /l /c:"[WARN] [Options] Unknown key=FixLocalAppData" "!T48E_ENABLED_PROBE_PATH!" >nul 2>&1
    if errorlevel 1 (
        findstr /l /c:"[WARN] [Options] Unknown key=FixTemp" "!T48E_ENABLED_PROBE_PATH!" >nul 2>&1
        if errorlevel 1 set "T48E_PROBE_KNOWN=PASS"
    )
)

start "" /wait "Working\Test48E\Enabled\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.ini" >nul 2>&1
set "T48E_ENABLED_EXIT=!ERRORLEVEL!"
set "T48E_ENABLED_RUNTIME=FAIL"
set "T48E_ENABLED_DIRECTORIES=FAIL"
set "T48E_DEBUG=FAIL"
if exist "Working\Test48E\Enabled\Root\Enabled.marker" set "T48E_ENABLED_RUNTIME=PASS"
if exist "Working\Test48E\Enabled\Root\Lib\AppData\Local\." if exist "Working\Test48E\Enabled\Root\Lib\AppData\Local\Temp\." set "T48E_ENABLED_DIRECTORIES=PASS"
if exist "Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.dbg" (
    findstr /l /c:"[PASS] [Environment] LOCALAPPDATA=" "Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.dbg" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /c:"[PASS] [Environment] TEMP=" "Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.dbg" >nul 2>&1
        if not errorlevel 1 (
            findstr /l /c:"[PASS] [Environment] TMP=" "Working\Test48E\Enabled\Launcher\48E_Portable_Environment_Enabled.dbg" >nul 2>&1
            if not errorlevel 1 set "T48E_DEBUG=PASS"
        )
    )
)

> "Working\Test48E\Override\Root\Payload.bat" echo @echo off
>>"Working\Test48E\Override\Root\Payload.bat" echo if /i not "%%LOCALAPPDATA%%"=="%%~dp0Override\Local" exit /b 71
>>"Working\Test48E\Override\Root\Payload.bat" echo if /i not "%%TEMP%%"=="%%~dp0Override\Temp" exit /b 72
>>"Working\Test48E\Override\Root\Payload.bat" echo if /i not "%%TMP%%"=="%%~dp0Override\Tmp" exit /b 73
>>"Working\Test48E\Override\Root\Payload.bat" echo if not exist "%%~dp0Lib\AppData\Local\Temp\." exit /b 74
>>"Working\Test48E\Override\Root\Payload.bat" echo ^> "%%~dp0Override.marker" echo PASS
>>"Working\Test48E\Override\Root\Payload.bat" echo exit /b 0

start "" /wait "Working\Test48E\Override\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48E\Override\Launcher\48E_Portable_Environment_Override.ini" >nul 2>&1
set "T48E_OVERRIDE_EXIT=!ERRORLEVEL!"
set "T48E_OVERRIDE_RUNTIME=FAIL"
if exist "Working\Test48E\Override\Root\Override.marker" set "T48E_OVERRIDE_RUNTIME=PASS"

set "LOCALAPPDATA=!T48E_ORIGINAL_LOCALAPPDATA!"
set "TEMP=!T48E_ORIGINAL_TEMP!"
set "TMP=!T48E_ORIGINAL_TMP!"

set "T48E_TEMPLATE=FAIL"
set "T48E_DOCS=FAIL"
findstr /l /x /c:"FixLocalAppData=false" "..\x-launcher.ini" >nul 2>&1
if not errorlevel 1 (
    findstr /l /x /c:"FixTemp=false" "..\x-launcher.ini" >nul 2>&1
    if not errorlevel 1 set "T48E_TEMPLATE=PASS"
)
findstr /l /c:"does not delete the portable folder" "..\README.md" >nul 2>&1
if not errorlevel 1 (
    findstr /l /c:"sets both `TEMP` and `TMP`" "..\README.md" >nul 2>&1
    if not errorlevel 1 set "T48E_DOCS=PASS"
)

set "T48E=FAIL"
if "!T48E_DEFAULT_PROBE_CODE!"=="PASS" if "!T48E_PROBE_DEFAULT!"=="PASS" if "!T48E_DEFAULT_RUNTIME!"=="PASS" if "!T48E_DEFAULT_DIRECTORIES!"=="PASS" if "!T48E_ENABLED_PROBE_CODE!"=="PASS" if "!T48E_PROBE_TRUE!"=="PASS" if "!T48E_PROBE_KNOWN!"=="PASS" if "!T48E_ENABLED_RUNTIME!"=="PASS" if "!T48E_ENABLED_DIRECTORIES!"=="PASS" if "!T48E_DEBUG!"=="PASS" if "!T48E_OVERRIDE_RUNTIME!"=="PASS" if "!T48E_TEMPLATE!"=="PASS" if "!T48E_DOCS!"=="PASS" set "T48E=PASS"

if "!T48E!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 48F - FixAppData Environment Compatibility...
set /a TOTAL+=1

if exist "Working\Test48F" rmdir /s /q "Working\Test48F"
mkdir "Working\Test48F\Launcher" >nul 2>&1
mkdir "Working\Test48F\Root" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test48F\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\48F_FixAppData_Environment_Compatibility.ini" "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.ini" >nul 2>&1

set "T48F_APPDATA_NAME="
for %%D in ("!APPDATA!") do set "T48F_APPDATA_NAME=%%~nxD"

> "Working\Test48F\Root\Payload.bat" echo @echo off
>>"Working\Test48F\Root\Payload.bat" echo if /i not "%%USERPROFILE%%"=="%%~dp0Profile" exit /b 81
>>"Working\Test48F\Root\Payload.bat" echo if /i not "%%APPDATA%%"=="%%~dp0Profile\!T48F_APPDATA_NAME!" exit /b 82
>>"Working\Test48F\Root\Payload.bat" echo if /i not "%%LOCALAPPDATA%%"=="%%~dp0Profile\AppData\Local" exit /b 83
>>"Working\Test48F\Root\Payload.bat" echo if /i not "%%TEMP%%"=="%%~dp0Profile\AppData\Local\Temp" exit /b 84
>>"Working\Test48F\Root\Payload.bat" echo if /i not "%%TMP%%"=="%%~dp0Profile\AppData\Local\Temp" exit /b 85
>>"Working\Test48F\Root\Payload.bat" echo if /i not "%%PROGRAMFILES(x86)%%"=="%%~dp0ProgramFiles32" exit /b 86
>>"Working\Test48F\Root\Payload.bat" echo if not exist "%%APPDATA%%\stremio\." mkdir "%%APPDATA%%\stremio" ^>nul 2^>^&1
>>"Working\Test48F\Root\Payload.bat" echo ^> "%%APPDATA%%\stremio\Payload.marker" echo PASS
>>"Working\Test48F\Root\Payload.bat" echo ^> "%%~dp0Compatibility.marker" echo PASS
>>"Working\Test48F\Root\Payload.bat" echo exit /b 0

start "" /wait "Working\Test48F\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.ini" >nul 2>&1
set "T48F_FIRST_EXIT=!ERRORLEVEL!"

set "T48F_ENVIRONMENT=FAIL"
set "T48F_CONFIG=FAIL"
set "T48F_DEBUG=FAIL"
set "T48F_DEBUG_FORMAT=FAIL"
set "T48F_LOG=FAIL"
set "T48F_PROGRAMFILES=FAIL"
if exist "Working\Test48F\Root\Compatibility.marker" if exist "Working\Test48F\Root\Profile\!T48F_APPDATA_NAME!\stremio\Payload.marker" set "T48F_ENVIRONMENT=PASS"
if exist "Working\Test48F\Root\Profile\x-launcher.cfg" (
    findstr /l /x /c:"AppData=!T48F_APPDATA_NAME!" "Working\Test48F\Root\Profile\x-launcher.cfg" >nul 2>&1
    if not errorlevel 1 set "T48F_CONFIG=PASS"
    copy /y "Working\Test48F\Root\Profile\x-launcher.cfg" "Working\Test48F\FirstProfile.cfg" >nul 2>&1
)
if exist "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.dbg" (
    findstr /l /c:"[PASS] [Environment] APPDATA=" "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.dbg" | findstr /l /c:"\Profile\!T48F_APPDATA_NAME!" >nul 2>&1
    if not errorlevel 1 set "T48F_DEBUG=PASS"
    findstr /l /c:"[PASS] [Environment] PROGRAMFILES(x86)=" "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.dbg" | findstr /l /c:"\ProgramFiles32" >nul 2>&1
    if not errorlevel 1 set "T48F_PROGRAMFILES=PASS"
    findstr /l /c:" = [SESSION START] id=" "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.dbg" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /c:" : [SESSION START] id=" "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.dbg" >nul 2>&1
        if errorlevel 1 set "T48F_DEBUG_FORMAT=PASS"
    )
)
if exist "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.log" (
    findstr /l /b /c:"APPDATA=" "Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.log" | findstr /l /e /c:"\Profile\!T48F_APPDATA_NAME!" >nul 2>&1
    if not errorlevel 1 set "T48F_LOG=PASS"
)

if exist "Working\Test48F\Root\Compatibility.marker" del /q "Working\Test48F\Root\Compatibility.marker" >nul 2>&1
start "" /wait "Working\Test48F\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test48F\Launcher\48F_FixAppData_Environment_Compatibility.ini" >nul 2>&1
set "T48F_SECOND_EXIT=!ERRORLEVEL!"

set "T48F_STABLE=FAIL"
if exist "Working\Test48F\Root\Compatibility.marker" if exist "Working\Test48F\FirstProfile.cfg" if exist "Working\Test48F\Root\Profile\x-launcher.cfg" (
    fc /b "Working\Test48F\FirstProfile.cfg" "Working\Test48F\Root\Profile\x-launcher.cfg" >nul 2>&1
    if not errorlevel 1 set "T48F_STABLE=PASS"
)

set "T48F=FAIL"
if "!T48F_ENVIRONMENT!"=="PASS" if "!T48F_CONFIG!"=="PASS" if "!T48F_DEBUG!"=="PASS" if "!T48F_DEBUG_FORMAT!"=="PASS" if "!T48F_LOG!"=="PASS" if "!T48F_PROGRAMFILES!"=="PASS" if "!T48F_STABLE!"=="PASS" set "T48F=PASS"

if "!T48F!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 49 - Isolated Full Test Foundation...
set /a TOTAL+=1

if exist "Working\Test49" rmdir /s /q "Working\Test49"
mkdir "Working\Test49\Launcher" >nul 2>&1
mkdir "Working\Test49\NoIniLauncher" >nul 2>&1
mkdir "Working\Test49\ConfiguredRoot" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test49\Launcher\X-Launcher_x64.exe" >nul 2>&1
copy /y "%LAUNCHER%" "Working\Test49\NoIniLauncher\X-Launcher_x64.exe" >nul 2>&1
copy /y "Configs\49_Full_Test_Isolation.ini" "Working\Test49\Config.ini" >nul 2>&1

> "Working\Test49\ConfiguredRoot\Payload.bat" echo @echo off
>>"Working\Test49\ConfiguredRoot\Payload.bat" echo ^>"%%~dp0PayloadRan.txt" echo RAN
>>"Working\Test49\ConfiguredRoot\Payload.bat" echo exit /b 0
> "Working\Test49\ConfiguredRoot\Before.bat" echo @echo off
>>"Working\Test49\ConfiguredRoot\Before.bat" echo ^>"%%~dp0RunBeforeRan.txt" echo RAN
>>"Working\Test49\ConfiguredRoot\Before.bat" echo exit /b 0
> "Working\Test49\ConfiguredRoot\After.bat" echo @echo off
>>"Working\Test49\ConfiguredRoot\After.bat" echo ^>"%%~dp0RunAfterRan.txt" echo RAN
>>"Working\Test49\ConfiguredRoot\After.bat" echo exit /b 0

reg delete "HKCU\Software\XLauncher_Test\Full49" /f >nul 2>&1
reg add "HKCU\Software\XLauncher_Test\Full49" /v State /t REG_SZ /d HOST /f >nul 2>&1

"Working\Test49\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test49\Config.ini" --x-launcher-test=full --x-launcher-test-automated >nul 2>&1
set "T49_EXIT=!ERRORLEVEL!"

set "T49_REPORT_PATH="
for /d %%D in ("Working\Test49\Launcher\Diagnostics\X-Launcher-SelfTest\*") do set "T49_REPORT_PATH=%%~fD\Full_Test_Report.log"

set "T49_REPORT=FAIL"
set "T49_HELPER=FAIL"
set "T49_PROCESS=FAIL"
set "T49_FILESYSTEM=FAIL"
set /a T49_FILESYSTEM_COUNT=0
set "T49_TEXTFORMAT=FAIL"
set /a T49_TEXTFORMAT_COUNT=0
set "T49_WRITERS=FAIL"
set /a T49_WRITER_COUNT=0
set "T49_REGISTRY_STAGE6F=FAIL"
set /a T49_REGISTRY_STAGE6F_COUNT=0
set "T49_ENVPATH_STAGE6G=FAIL"
set /a T49_ENVPATH_STAGE6G_COUNT=0
set "T49_PATHSAFETY_STAGE6H=FAIL"
set /a T49_PATHSAFETY_STAGE6H_COUNT=0
set "T49_SPLASHTRAY_STAGE6I=FAIL"
set /a T49_SPLASHTRAY_STAGE6I_COUNT=0
set "T49_JAVAPATH_STAGE6J=FAIL"
set /a T49_JAVAPATH_STAGE6J_COUNT=0
set "T49_JAVATRANSACTION_STAGE6K=FAIL"
set /a T49_JAVATRANSACTION_STAGE6K_COUNT=0
set "T49_DEBUGREPORT_STAGE6L=FAIL"
set /a T49_DEBUGREPORT_STAGE6L_COUNT=0
set "T49_PROBEPARSER_STAGE6M=FAIL"
set /a T49_PROBEPARSER_STAGE6M_COUNT=0
set "T49_ISOLATION=FAIL"
set "T49_CONTEXT_LINE="
set "T49_CONTEXT_PATH="
set "T49_REGISTRY=FAIL"
set "T49_CLEANUP=FAIL"
set "T49_PRIVACY=FAIL"
set "T49_WORKSPACE="
set "T49_SELFTEST_REG="
set "T49_VIEW_REG="
set "T49_WORKSPACE_LINE="
set "T49_REGISTRY_LINE="
set "T49_VIEW_REGISTRY_LINE="
set "T49_ISOLATION_FILES=FAIL"
set "T49_NOINI=FAIL"
set "T49_NOINI_EXIT_CHECK=FAIL"
set "T49_NOINI_MISSING=FAIL"
set "T49_NOINI_REPORT_CHECK=FAIL"
set "T49_NOINI_ZERO=FAIL"
set "T49_NOINI_CONTEXT=FAIL"
set "T49_NOINI_CONTEXT_LINE="
set "T49_NOINI_CONTEXT_PATH="

if defined T49_REPORT_PATH if exist "!T49_REPORT_PATH!" (
    findstr /x /c:"Mode=isolated built-in integrity test" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /x /c:"FAIL=0" "!T49_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /x /c:"OVERALL=PASS" "!T49_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 set "T49_REPORT=PASS"
        )
    )
    findstr /l /x /c:"[PASS] [Self Helper] Private helper completed with success exit code=exit=0; error=0" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /x /c:"[PASS] [Command Line] Exact arguments and quoted spacing were preserved" "!T49_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /l /x /c:"[PASS] [Process] Controlled nonzero helper exit code was observed=exit=23; error=0" "!T49_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 set "T49_HELPER=PASS"
        )
    )
    findstr /l /b /c:"[PASS] [Process] Missing executable launch failure was detected=" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 (
        findstr /l /b /c:"[PASS] [Process] Two isolated self-helper instances ran concurrently=" "!T49_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /l /x /c:"[PASS] [Process] Both isolated self-helper instances closed normally" "!T49_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 set "T49_PROCESS=PASS"
        )
    )
    findstr /l /x /c:"[PASS] [File System] Every operation target passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [File System] Isolated file and directory fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [File System] Directory and empty-file creation operations succeeded" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [File System] File copy and move operations preserved exact content" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [Safety] Non-overwrite file-copy failure preserved source and destination" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [File System] Directory copy and move operations preserved nested content" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [File System] File and directory deletion removed only isolated targets" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [Safety] Empty-only directory removal preserved non-empty data" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    findstr /l /x /c:"[PASS] [File System] Missing directory removal succeeded as no-op while a file target failed" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_FILESYSTEM_COUNT+=1
    if !T49_FILESYSTEM_COUNT!==9 set "T49_FILESYSTEM=PASS"
    findstr /l /x /c:"[PASS] [Text Format] Every text fixture passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    findstr /l /x /c:"[PASS] [Text Format] UTF-8 BOM and LF fixtures with trailing blank lines were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    findstr /l /x /c:"[PASS] [Text Format] StringReplace preserved UTF-8 BOM, LF and trailing blank line" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    findstr /l /x /c:"[PASS] [Text Format] StringRegExpReplace preserved UTF-8 BOM, LF and trailing blank line" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    findstr /l /x /c:"[PASS] [Text Format] WriteToFile preserved UTF-8 BOM, LF and trailing blank line" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    findstr /l /x /c:"[PASS] [Text Format] WriteToPref preserved UTF-8 BOM, LF and trailing blank line" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    findstr /l /x /c:"[PASS] [Text Format] MozPrefs preserved UTF-8 BOM, LF and trailing blank line" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_TEXTFORMAT_COUNT+=1
    if !T49_TEXTFORMAT_COUNT!==7 set "T49_TEXTFORMAT=PASS"
    findstr /l /x /c:"[PASS] [Writer Semantics] Every writer output passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] Isolated writer fixture directory was created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] WriteToIni created a new INI value inside the workspace" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] WriteToIni updated one value while preserving another" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] WriteToPref created a new preference file" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] WriteToPref updated, appended and recognized an unchanged value" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] WriteToReg generated the exact header, key and value structure" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    findstr /l /x /c:"[PASS] [Writer Semantics] Generated REG file was not imported into the registry" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_WRITER_COUNT+=1
    if !T49_WRITER_COUNT!==8 set "T49_WRITERS=PASS"
    findstr /l /x /c:"[PASS] [Registry] Every fixture and transaction path passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry] Isolated registry fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry View] 32-bit and 64-bit registry commands selected the requested views" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry View] 32-bit and 64-bit values remained isolated in separate registry views" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry View] View-isolation keys were removed from both registry views" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Transaction] Portable values replaced both protected host roots" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Transaction] Transaction manifest recorded Native view and ordered distinct backups" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Restore] Normal close restored both host roots in manifest order" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Restore] Normal close saved current portable values back to both REG files" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Restore] Normal transaction data was removed after successful restore" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Recovery] Interrupted transaction fixture installed portable state with a pending marker" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    findstr /l /x /c:"[PASS] [Registry Recovery] Recovery used the saved view, restored the caller view and removed transaction data" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_REGISTRY_STAGE6F_COUNT+=1
    if !T49_REGISTRY_STAGE6F_COUNT!==12 set "T49_REGISTRY_STAGE6F=PASS"
    findstr /l /x /c:"[PASS] [Environment Path] Every fixture passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] Isolated environment and path fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] Environment-variable text expanded to the isolated workspace" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] Root and Lib launcher variables expanded inside INI values" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] FullPath resolved relative, absolute and valid parent paths against the supplied root" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] FullPathPlus preserved literal mode and applied slash and quote options" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] MultiPath resolved ordinary and wildcard entries against Root instead of the working directory" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] SetEnv resolved and assigned a process-local path value" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] Blank environment-variable name was rejected" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] SetPath resolved multiple entries and assigned the exact process PATH" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    findstr /l /x /c:"[PASS] [Environment Path] Process environment, working directory and launcher path globals were restored" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_ENVPATH_STAGE6G_COUNT+=1
    if !T49_ENVPATH_STAGE6G_COUNT!==11 set "T49_ENVPATH_STAGE6G=PASS"
    findstr /l /x /c:"[PASS] [Path Safety] Every mutable target passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] Isolated path and cleanup fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FullPath preserved a direct UNC path without accessing the network" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] NormalPath and FileInfo retained the UNC prefix and parent" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] Valid parent traversal resolved and excessive traversal returned a nonfatal error" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FixDriveLetter rewrote an absolute drive path to the current isolated drive" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FixDriveLetter preserved embedded drive-like text and URL segments" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FixDriveLetter rejected a non-drive base without changing the file" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FixUserProfile renamed one valid direct child and updated its preference" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FixUserProfile preserved the profile root when the old child was blank" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] FixUserProfile rejected parent traversal and nested old-source names" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] Temp cleanup refused to remove the isolated protected Root" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] Temp cleanup removed only the isolated disposable child" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    findstr /l /x /c:"[PASS] [Path Safety] Launcher path globals were restored after cleanup checks" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PATHSAFETY_STAGE6H_COUNT+=1
    if !T49_PATHSAFETY_STAGE6H_COUNT!==14 set "T49_PATHSAFETY_STAGE6H=PASS"
    findstr /l /x /c:"[PASS] [Splash Tray] Every mutable visual fixture passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /x /c:"[PASS] [Splash Tray] Isolated splash fallback directory was created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /x /c:"[PASS] [Splash Tray] Splash fallback image was extracted only to the supplied isolated Temp" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /b /c:"[PASS] [Splash Tray] Splash creation returned without waiting for its configured timeout=elapsed-ms=" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /x /c:"[PASS] [Splash Tray] Splash used the configured window title" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /x /c:"[PASS] [Splash Tray] Splash used the configured client width and height" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /x /c:"[PASS] [Splash Tray] Blank splash dimensions used the image's natural size" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /x /c:"[PASS] [Splash Tray] Splash windows and timeout callbacks were closed after inspection" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    findstr /l /b /c:"[PASS] [Splash Tray] TrayTip accepted a millisecond duration and returned without blocking=elapsed-ms=" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_SPLASHTRAY_STAGE6I_COUNT+=1
    if !T49_SPLASHTRAY_STAGE6I_COUNT!==9 set "T49_SPLASHTRAY_STAGE6I=PASS"
    findstr /l /x /c:"[PASS] [Java Path] Every JavaPath fixture passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Isolated JavaPath runtime and configuration fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Absolute and quoted Java64 runtime roots resolved as usable JavaPath values" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] bin, java.exe and javaw.exe paths normalized to their runtime root" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Relative Java runtime path resolved against Root" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Incomplete runtime and JavaPortableLauncher executable were rejected" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Configured JavaPath took priority over bundled system and URL sources" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Usable JavaPath bypassed JavaURL download staging and JavaGet writes" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] Java false ignored but retained the configured JavaPath" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] External JavaPath runtime files remained byte-identical" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Path] JavaPath test globals and process environment were restored" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVAPATH_STAGE6J_COUNT+=1
    if !T49_JAVAPATH_STAGE6J_COUNT!==11 set "T49_JAVAPATH_STAGE6J=PASS"
    findstr /l /x /c:"[PASS] [Java Transaction] Every Java transaction fixture passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Isolated runtime package staging backup and rollback fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] JavaURL accepted only direct HTTP and HTTPS values without network access" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Local ZIP and MZ legacy setup packages were recognized without execution" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Direct and single-wrapper staged runtime layouts were accepted" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Ambiguous and incomplete staged runtime layouts were rejected" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Failed package extraction removed staging before the live runtime was touched" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Backup path validation allowed only one direct child of the live runtime" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Complete runtime content was backed up before live replacement" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Setup and staging data stayed outside the portable runtime backup" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Prepared runtime installation copied the complete new runtime into place" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Cancellation stopped prepared installation before destination mutation" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Rollback removed partial content and restored the complete original runtime" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    findstr /l /x /c:"[PASS] [Java Transaction] Java transaction working directory and cancellation state were restored" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_JAVATRANSACTION_STAGE6K_COUNT+=1
    if !T49_JAVATRANSACTION_STAGE6K_COUNT!==14 set "T49_JAVATRANSACTION_STAGE6K=PASS"
    findstr /l /x /c:"[PASS] [Debug Reporting] Debug classification log passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Debug false produced no diagnostic result output" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Successful Boolean operation was classified PASS" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Failed Boolean operation was classified FAIL" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Legitimate text no-change result was classified SKIP" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Zero without error was not blindly classified PASS" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Missing directory removal was classified as successful no-op" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Unknown operation name remained compatible and was classified WARN" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Application launch success and failure were distinguished" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Registry recovery success was recorded" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Environment PASS SKIP and FAIL results were distinguished" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Temp cleanup removed disabled and failed results were distinguished" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Debug session boundaries and summary totals were exact" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Debug counters matched the emitted result classifications" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    findstr /l /x /c:"[PASS] [Debug Reporting] Debug globals counters session and environment were restored" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_DEBUGREPORT_STAGE6L_COUNT+=1
    if !T49_DEBUGREPORT_STAGE6L_COUNT!==15 set "T49_DEBUGREPORT_STAGE6L=PASS"
    findstr /l /x /c:"[PASS] [Probe Parser] Every parser fixture passed the isolated workspace boundary check" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Controlled valid invalid operation dynamic and Java fixtures were created" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Known fixed and dynamic sections were accepted while an unknown section was rejected" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] The correctly spelled MultipleInstances option key was recognized" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Valid Boolean RegView TestRun and integer options were accepted" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Invalid Boolean RegView TestRun and integer options produced findings" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Resolved path root boundary and UNC-prefix contracts were classified without access" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Windows environment names including parentheses and USERPROFILE paths were accepted read-only" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Valid operation arguments sources destinations and REG files were recognized read-only" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Valid dynamic delimiters regex and write selectors were accepted without writes" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Valid Java policy JavaPath and unused JavaURL fallback were reported without execution" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Safe disposable and protected Root cleanup targets were distinguished" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Windows-valid spaced names and blank environment values produced the expected findings" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Unknown operation spelling and invalid argument count produced findings" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Invalid dynamic delimiters regex and write selectors produced findings" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Invalid Java policy path package and URL produced findings without installation" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Parser cross-checks left INIs targets Java sources directories and registry unchanged" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    findstr /l /x /c:"[PASS] [Probe Parser] Parser globals working directory and expansion options were restored" "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set /a T49_PROBEPARSER_STAGE6M_COUNT+=1
    if !T49_PROBEPARSER_STAGE6M_COUNT!==18 set "T49_PROBEPARSER_STAGE6M=PASS"
    for /f "tokens=1,* delims==" %%L in ('findstr /l /b /c:"INI context only (configured targets were not used)=" "!T49_REPORT_PATH!"') do (
        set "T49_CONTEXT_LINE=%%L=%%M"
        set "T49_CONTEXT_PATH=%%M"
    )
    if /i "!T49_CONTEXT_PATH!"=="%CD%\Working\Test49\Config.ini" (
        findstr /x /c:"Application=X-Launcher Full Self-Test" "!T49_REPORT_PATH!" >nul 2>&1
        if not errorlevel 1 (
            findstr /b /c:"Executable=" "!T49_REPORT_PATH!" >nul 2>&1
            if not errorlevel 1 set "T49_ISOLATION=PASS"
        )
    )
    findstr /x /c:"Privacy=Review paths and diagnostic details before sharing." "!T49_REPORT_PATH!" >nul 2>&1
    if not errorlevel 1 set "T49_PRIVACY=PASS"
    for /f "tokens=1,* delims==" %%L in ('findstr /b /c:"Workspace=" "!T49_REPORT_PATH!"') do (
        set "T49_WORKSPACE_LINE=%%L=%%M"
        set "T49_WORKSPACE=%%M"
    )
    for /f "tokens=1,* delims==" %%L in ('findstr /b /c:"Registry root=" "!T49_REPORT_PATH!"') do (
        set "T49_REGISTRY_LINE=%%L=%%M"
        set "T49_SELFTEST_REG=%%M"
    )
    for /f "tokens=1,* delims==" %%L in ('findstr /b /c:"Registry view root=" "!T49_REPORT_PATH!"') do (
        set "T49_VIEW_REGISTRY_LINE=%%L=%%M"
        set "T49_VIEW_REG=%%M"
    )
)

if not exist "Working\Test49\ConfiguredRoot\PayloadRan.txt" if not exist "Working\Test49\ConfiguredRoot\RunBeforeRan.txt" if not exist "Working\Test49\ConfiguredRoot\RunAfterRan.txt" if not exist "Working\Test49\ConfiguredRoot\FunctionRan.txt" set "T49_ISOLATION_FILES=PASS"

reg query "HKCU\Software\XLauncher_Test\Full49" /v State 2>nul | find /i "HOST" >nul
if not errorlevel 1 set "T49_REGISTRY=PASS"

if defined T49_WORKSPACE if not exist "!T49_WORKSPACE!" (
    if defined T49_SELFTEST_REG (
        reg query "!T49_SELFTEST_REG!" >nul 2>&1
        if errorlevel 1 if defined T49_VIEW_REG (
            reg query "!T49_VIEW_REG!" /reg:32 >nul 2>&1
            if errorlevel 1 (
                reg query "!T49_VIEW_REG!" /reg:64 >nul 2>&1
                if errorlevel 1 set "T49_CLEANUP=PASS"
            )
        )
    )
)

"Working\Test49\NoIniLauncher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test49\Missing.ini" --x-launcher-test=full --x-launcher-test-automated >nul 2>&1
set "T49_NOINI_EXIT=!ERRORLEVEL!"
set "T49_NOINI_REPORT="
for /d %%D in ("Working\Test49\NoIniLauncher\Diagnostics\X-Launcher-SelfTest\*") do set "T49_NOINI_REPORT=%%~fD\Full_Test_Report.log"
if "!T49_NOINI_EXIT!"=="0" set "T49_NOINI_EXIT_CHECK=PASS"
if not exist "Working\Test49\Missing.ini" set "T49_NOINI_MISSING=PASS"
if defined T49_NOINI_REPORT if exist "!T49_NOINI_REPORT!" set "T49_NOINI_REPORT_CHECK=PASS"
if "!T49_NOINI_REPORT_CHECK!"=="PASS" (
    findstr /l /x /c:"FAIL=0" "!T49_NOINI_REPORT!" >nul 2>&1
    if not errorlevel 1 set "T49_NOINI_ZERO=PASS"
    for /f "tokens=1,* delims==" %%L in ('findstr /l /b /c:"INI context only (configured targets were not used)=" "!T49_NOINI_REPORT!"') do (
        set "T49_NOINI_CONTEXT_LINE=%%L=%%M"
        set "T49_NOINI_CONTEXT_PATH=%%M"
    )
    if /i "!T49_NOINI_CONTEXT_PATH!"=="%CD%\Working\Test49\Missing.ini" set "T49_NOINI_CONTEXT=PASS"
)
if "!T49_NOINI_EXIT_CHECK!"=="PASS" if "!T49_NOINI_MISSING!"=="PASS" if "!T49_NOINI_REPORT_CHECK!"=="PASS" if "!T49_NOINI_ZERO!"=="PASS" if "!T49_NOINI_CONTEXT!"=="PASS" set "T49_NOINI=PASS"

set "T49=FAIL"
if "!T49_EXIT!"=="0" if "!T49_REPORT!"=="PASS" if "!T49_HELPER!"=="PASS" if "!T49_PROCESS!"=="PASS" if "!T49_FILESYSTEM!"=="PASS" if "!T49_TEXTFORMAT!"=="PASS" if "!T49_WRITERS!"=="PASS" if "!T49_REGISTRY_STAGE6F!"=="PASS" if "!T49_ENVPATH_STAGE6G!"=="PASS" if "!T49_PATHSAFETY_STAGE6H!"=="PASS" if "!T49_SPLASHTRAY_STAGE6I!"=="PASS" if "!T49_JAVAPATH_STAGE6J!"=="PASS" if "!T49_JAVATRANSACTION_STAGE6K!"=="PASS" if "!T49_DEBUGREPORT_STAGE6L!"=="PASS" if "!T49_PROBEPARSER_STAGE6M!"=="PASS" if "!T49_ISOLATION!"=="PASS" if "!T49_ISOLATION_FILES!"=="PASS" if "!T49_REGISTRY!"=="PASS" if "!T49_CLEANUP!"=="PASS" if "!T49_PRIVACY!"=="PASS" if "!T49_NOINI!"=="PASS" set "T49=PASS"

if "!T49!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

reg delete "HKCU\Software\XLauncher_Test\Full49" /f >nul 2>&1

echo Running Test 50 - MultipleInstances Correct Spelling...
set /a TOTAL+=1

if exist "Working\Test50" rmdir /s /q "Working\Test50"

set "T50=FAIL"
set "T50_CORRECTED_FALSE=FAIL"
set "T50_CORRECTED_TRUE=FAIL"
set "T50_FORMER=FAIL"
set "T50_INVALID=FAIL"
set "T50_VALUE_CORRECTED_FALSE=(missing)"
set "T50_VALUE_CORRECTED_TRUE=(missing)"
set "T50_VALUE_FORMER=(missing)"
set "T50_VALUE_INVALID=(missing)"
set "T50_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T50_PROBE=%CD%\..\_IssueB_MultipleInstances_Probe.au3"

if exist "!T50_PROBE!" del /q "!T50_PROBE!" >nul 2>&1

if exist "!T50_AUTOIT!" (
    copy /y "Helpers\IssueB_MultipleInstances_Probe.au3" "!T50_PROBE!" >nul 2>&1
    if exist "!T50_PROBE!" (
        pushd ".."
        "!T50_AUTOIT!" /ErrorStdOut "_IssueB_MultipleInstances_Probe.au3" >nul 2>&1
        set "T50_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T50_EXIT=99"
    )
) else (
    set "T50_EXIT=98"
)

if exist "!T50_PROBE!" del /q "!T50_PROBE!" >nul 2>&1

findstr /x /c:"Corrected false value is accepted: PASS" "Working\Test50\Probe.log" >nul 2>&1
if not errorlevel 1 set "T50_CORRECTED_FALSE=PASS"
findstr /x /c:"Corrected true value is accepted: PASS" "Working\Test50\Probe.log" >nul 2>&1
if not errorlevel 1 set "T50_CORRECTED_TRUE=PASS"
findstr /x /c:"Former misspelling is not accepted: PASS" "Working\Test50\Probe.log" >nul 2>&1
if not errorlevel 1 set "T50_FORMER=PASS"
findstr /x /c:"Invalid corrected value uses the default: PASS" "Working\Test50\Probe.log" >nul 2>&1
if not errorlevel 1 set "T50_INVALID=PASS"

for /f "tokens=2 delims=:" %%V in ('findstr /b /c:"Corrected-false resolved value:" "Working\Test50\Probe.log"') do set "T50_VALUE_CORRECTED_FALSE=%%V"
for /f "tokens=2 delims=:" %%V in ('findstr /b /c:"Corrected-true resolved value:" "Working\Test50\Probe.log"') do set "T50_VALUE_CORRECTED_TRUE=%%V"
for /f "tokens=2 delims=:" %%V in ('findstr /b /c:"Former-only resolved value:" "Working\Test50\Probe.log"') do set "T50_VALUE_FORMER=%%V"
for /f "tokens=2 delims=:" %%V in ('findstr /b /c:"Invalid-corrected resolved value:" "Working\Test50\Probe.log"') do set "T50_VALUE_INVALID=%%V"

if "!T50_EXIT!"=="0" if "!T50_CORRECTED_FALSE!"=="PASS" if "!T50_CORRECTED_TRUE!"=="PASS" if "!T50_FORMER!"=="PASS" if "!T50_INVALID!"=="PASS" set "T50=PASS"

if "!T50!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 51 - SendMessageTimeout x64 Signature...
set /a TOTAL+=1

if exist "Working\Test51" rmdir /s /q "Working\Test51"

set "T51=FAIL"
set "T51_READ=FAIL"
set "T51_ADD=FAIL"
set "T51_REMOVE=FAIL"
set "T51_LEGACY=FAIL"
set "T51_AUTOIT=%CD%\..\..\_Tools\AutoIT\- 3.3.18.0\AutoIt3_x64.exe"
set "T51_PROBE=%CD%\..\_IssueA_SendMessageTimeoutTypes_Probe.au3"

if exist "!T51_PROBE!" del /q "!T51_PROBE!" >nul 2>&1

if exist "!T51_AUTOIT!" (
    copy /y "Helpers\IssueA_SendMessageTimeoutTypes_Probe.au3" "!T51_PROBE!" >nul 2>&1
    if exist "!T51_PROBE!" (
        pushd ".."
        "!T51_AUTOIT!" /ErrorStdOut "_IssueA_SendMessageTimeoutTypes_Probe.au3" >nul 2>&1
        set "T51_EXIT=!ERRORLEVEL!"
        popd
    ) else (
        set "T51_EXIT=99"
    )
) else (
    set "T51_EXIT=98"
)

if exist "!T51_PROBE!" del /q "!T51_PROBE!" >nul 2>&1

findstr /x /c:"x-udf source was readable: PASS" "Working\Test51\Probe.log" >nul 2>&1
if not errorlevel 1 set "T51_READ=PASS"
findstr /x /c:"AddFonts uses pointer-sized SendMessageTimeoutW types: PASS" "Working\Test51\Probe.log" >nul 2>&1
if not errorlevel 1 set "T51_ADD=PASS"
findstr /x /c:"RemoveFonts uses pointer-sized SendMessageTimeoutW types: PASS" "Working\Test51\Probe.log" >nul 2>&1
if not errorlevel 1 set "T51_REMOVE=PASS"
findstr /x /c:"Legacy non-pointer-sized SendMessageTimeout calls are absent: PASS" "Working\Test51\Probe.log" >nul 2>&1
if not errorlevel 1 set "T51_LEGACY=PASS"

if "!T51_EXIT!"=="0" if "!T51_READ!"=="PASS" if "!T51_ADD!"=="PASS" if "!T51_REMOVE!"=="PASS" if "!T51_LEGACY!"=="PASS" set "T51=PASS"

if "!T51!"=="PASS" (
    set /a PASSCOUNT+=1
) else (
    set /a FAILCOUNT+=1
)

echo Running Test 52A - Temporary Junction Lifecycle...
set /a TOTAL+=1
if exist "Working\Test52A" rmdir /s /q "Working\Test52A"
mkdir "Working\Test52A\Target"
> "Working\Test52A\Payload.bat" echo @echo off
>>"Working\Test52A\Payload.bat" echo ^> "%%~dp0TemporaryJunction\Payload.txt" echo TEMP_JUNCTION_OK
>>"Working\Test52A\Payload.bat" echo exit /b 0
if exist "52A_Junction_Temporary.dbg" del /q "52A_Junction_Temporary.dbg" >nul 2>&1

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\52A_Junction_Temporary.ini" >nul 2>&1
set "T52A_EXIT=!ERRORLEVEL!"
set "T52A=FAIL"
set "T52A_TARGET=FAIL"
set "T52A_REMOVED=FAIL"
set "T52A_DEBUG=FAIL"
set "T52A_FORCED=FAIL"
if exist "Working\Test52A\Target\Payload.txt" set "T52A_TARGET=PASS"
if not exist "Working\Test52A\TemporaryJunction" set "T52A_REMOVED=PASS"
findstr /l /c:"[PASS] [Functions] Junctions=.\Target|.\TemporaryJunction" "52A_Junction_Temporary.dbg" >nul 2>&1
if not errorlevel 1 findstr /l /c:"[PASS] [RunAfter] RemoveJunction=" "52A_Junction_Temporary.dbg" >nul 2>&1
if not errorlevel 1 set "T52A_DEBUG=PASS"
findstr /l /c:"RunWait forced true: end-of-run cleanup is required" "52A_Junction_Temporary.dbg" >nul 2>&1
if not errorlevel 1 set "T52A_FORCED=PASS"
if "!T52A_EXIT!"=="0" if "!T52A_TARGET!"=="PASS" if "!T52A_REMOVED!"=="PASS" if "!T52A_DEBUG!"=="PASS" if "!T52A_FORCED!"=="PASS" set "T52A=PASS"
if "!T52A!"=="PASS" (set /a PASSCOUNT+=1) else (set /a FAILCOUNT+=1)

echo Running Test 52B - Persistent Junction Flag...
set /a TOTAL+=1
if exist "Working\Test52B" rmdir /s /q "Working\Test52B"
mkdir "Working\Test52B\Target"
> "Working\Test52B\Payload.bat" echo @echo off
>>"Working\Test52B\Payload.bat" echo ^> "%%~dp0PersistentJunction\Payload.txt" echo PERSISTENT_JUNCTION_OK
>>"Working\Test52B\Payload.bat" echo exit /b 0
if exist "52B_Junction_Persistent.dbg" del /q "52B_Junction_Persistent.dbg" >nul 2>&1

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\52B_Junction_Persistent.ini" >nul 2>&1
set "T52B_EXIT=!ERRORLEVEL!"
set "T52B=FAIL"
set "T52B_TARGET=FAIL"
set "T52B_KEPT=FAIL"
set "T52B_DEBUG=FAIL"
set "T52B_CLEANUP=FAIL"
if exist "Working\Test52B\Target\Payload.txt" set "T52B_TARGET=PASS"
if exist "Working\Test52B\PersistentJunction\" set "T52B_KEPT=PASS"
findstr /l /c:"lifetime=persistent" "52B_Junction_Persistent.dbg" >nul 2>&1
if not errorlevel 1 (
    findstr /l /c:"RemoveJunction=" "52B_Junction_Persistent.dbg" >nul 2>&1
    if errorlevel 1 set "T52B_DEBUG=PASS"
)
rmdir "Working\Test52B\PersistentJunction" >nul 2>&1
if not exist "Working\Test52B\PersistentJunction" if exist "Working\Test52B\Target\Payload.txt" set "T52B_CLEANUP=PASS"
if "!T52B_EXIT!"=="0" if "!T52B_TARGET!"=="PASS" if "!T52B_KEPT!"=="PASS" if "!T52B_DEBUG!"=="PASS" if "!T52B_CLEANUP!"=="PASS" set "T52B=PASS"
if "!T52B!"=="PASS" (set /a PASSCOUNT+=1) else (set /a FAILCOUNT+=1)

echo Running Test 53A - Temporary Symbolic-Link Lifecycle...
set /a TOTAL+=1
if exist "Working\Test53A" rmdir /s /q "Working\Test53A"
mkdir "Working\Test53A"
> "Working\Test53A\Target.txt" echo SOURCE
> "Working\Test53A\Payload.bat" echo @echo off
>>"Working\Test53A\Payload.bat" echo if exist "%%~dp0TemporarySymLink.txt" ^> "%%~dp0TemporarySymLink.txt" echo TEMP_SYMLINK_OK
>>"Working\Test53A\Payload.bat" echo exit /b 0
if exist "53A_SymLink_Temporary.dbg" del /q "53A_SymLink_Temporary.dbg" >nul 2>&1

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\53A_SymLink_Temporary.ini" >nul 2>&1
set "T53A_EXIT=!ERRORLEVEL!"
set "T53A=FAIL"
set "T53A_MODE=FAILED"
findstr /l /c:"[PASS] [Functions] SymLinks=.\Target.txt|.\TemporarySymLink.txt" "53A_SymLink_Temporary.dbg" >nul 2>&1
if not errorlevel 1 (
    findstr /x /c:"TEMP_SYMLINK_OK" "Working\Test53A\Target.txt" >nul 2>&1
    if not errorlevel 1 if not exist "Working\Test53A\TemporarySymLink.txt" (
        findstr /l /c:"[PASS] [RunAfter] RemoveSymLink=" "53A_SymLink_Temporary.dbg" >nul 2>&1
        if not errorlevel 1 (
            set "T53A=PASS"
            set "T53A_MODE=CREATED_AND_REMOVED"
        )
    )
) else (
    findstr /l /c:"[FAIL] [Functions] SymLinks=.\Target.txt|.\TemporarySymLink.txt" "53A_SymLink_Temporary.dbg" >nul 2>&1
    if not errorlevel 1 findstr /l /c:"extended=1314)" "53A_SymLink_Temporary.dbg" >nul 2>&1
    if not errorlevel 1 (
        set "T53A=PASS"
        set "T53A_MODE=PRIVILEGE_UNAVAILABLE"
    )
)
if not "!T53A_EXIT!"=="0" set "T53A=FAIL"
if "!T53A!"=="PASS" (set /a PASSCOUNT+=1) else (set /a FAILCOUNT+=1)

echo Running Test 53B - Persistent Symbolic-Link Flag...
set /a TOTAL+=1
if exist "Working\Test53B" rmdir /s /q "Working\Test53B"
mkdir "Working\Test53B\Target"
> "Working\Test53B\Payload.bat" echo @echo off
>>"Working\Test53B\Payload.bat" echo if exist "%%~dp0PersistentSymLink" ^> "%%~dp0PersistentSymLink\Payload.txt" echo PERSISTENT_SYMLINK_OK
>>"Working\Test53B\Payload.bat" echo exit /b 0
if exist "53B_SymLink_Persistent.dbg" del /q "53B_SymLink_Persistent.dbg" >nul 2>&1

start "" /wait "%LAUNCHER%" "--x-launcher-config=%CD%\Configs\53B_SymLink_Persistent.ini" >nul 2>&1
set "T53B_EXIT=!ERRORLEVEL!"
set "T53B=FAIL"
set "T53B_MODE=FAILED"
findstr /l /c:"lifetime=persistent" "53B_SymLink_Persistent.dbg" >nul 2>&1
if not errorlevel 1 (
    if exist "Working\Test53B\PersistentSymLink\" if exist "Working\Test53B\Target\Payload.txt" (
        rmdir "Working\Test53B\PersistentSymLink" >nul 2>&1
        if not exist "Working\Test53B\PersistentSymLink" if exist "Working\Test53B\Target\Payload.txt" (
            set "T53B=PASS"
            set "T53B_MODE=CREATED_KEPT_AND_SAFE_REMOVED"
        )
    )
) else (
    findstr /l /c:"[FAIL] [Functions] SymLinks=.\Target|.\PersistentSymLink|*" "53B_SymLink_Persistent.dbg" >nul 2>&1
    if not errorlevel 1 findstr /l /c:"extended=1314)" "53B_SymLink_Persistent.dbg" >nul 2>&1
    if not errorlevel 1 (
        set "T53B=PASS"
        set "T53B_MODE=PRIVILEGE_UNAVAILABLE"
    )
)
if not "!T53B_EXIT!"=="0" set "T53B=FAIL"
if "!T53B!"=="PASS" (set /a PASSCOUNT+=1) else (set /a FAILCOUNT+=1)

echo Running Test 54 - Protected Lib DirRemove Modes...
set /a TOTAL+=1
if exist "Working\Test54" rmdir /s /q "Working\Test54"
for %%M in (A B C D) do (
	mkdir "Working\Test54\%%M\Launcher" >nul 2>&1
	mkdir "Working\Test54\%%M\Root\Lib" >nul 2>&1
	copy /y "%LAUNCHER%" "Working\Test54\%%M\Launcher\X-Launcher_x64.exe" >nul 2>&1
	> "Working\Test54\%%M\Root\Payload.bat" echo @echo off
	>>"Working\Test54\%%M\Root\Payload.bat" echo ^> "%%~dp0PayloadRan.txt" echo RAN
	>>"Working\Test54\%%M\Root\Payload.bat" echo exit /b 0
)
copy /y "Configs\54A_DirRemove_Lib_Empty.ini" "Working\Test54\A\Launcher\54A_DirRemove_Lib_Empty.ini" >nul 2>&1
copy /y "Configs\54B_DirRemove_Lib_Contents.ini" "Working\Test54\B\Launcher\54B_DirRemove_Lib_Contents.ini" >nul 2>&1
copy /y "Configs\54C_DirRemove_Lib_Contents_Empty.ini" "Working\Test54\C\Launcher\54C_DirRemove_Lib_Contents_Empty.ini" >nul 2>&1
copy /y "Configs\54D_DirRemove_Lib_Blocked.ini" "Working\Test54\D\Launcher\54D_DirRemove_Lib_Blocked.ini" >nul 2>&1

for %%M in (A C) do (
	mkdir "Working\Test54\%%M\Root\Lib\EmptyParent\EmptyChild" >nul 2>&1
	mkdir "Working\Test54\%%M\Root\Lib\Keep" >nul 2>&1
	> "Working\Test54\%%M\Root\Lib\Keep\Keep.txt" echo KEEP
	> "Working\Test54\%%M\Root\Lib\RootKeep.txt" echo KEEP_ROOT_FILE
)
for %%M in (B D) do (
	mkdir "Working\Test54\%%M\Root\Lib\DeleteDir" >nul 2>&1
	> "Working\Test54\%%M\Root\Lib\DeleteDir\Delete.txt" echo DELETE_OR_PRESERVE
	> "Working\Test54\%%M\Root\Lib\RootFile.txt" echo DELETE_OR_PRESERVE
)

"Working\Test54\A\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\A\Launcher\54A_DirRemove_Lib_Empty.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T54A_PROBE_EXIT=!ERRORLEVEL!"
"Working\Test54\B\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\B\Launcher\54B_DirRemove_Lib_Contents.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T54B_PROBE_EXIT=!ERRORLEVEL!"
"Working\Test54\C\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\C\Launcher\54C_DirRemove_Lib_Contents_Empty.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T54C_PROBE_EXIT=!ERRORLEVEL!"
"Working\Test54\D\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\D\Launcher\54D_DirRemove_Lib_Blocked.ini" --x-launcher-test=probe --x-launcher-test-automated >nul 2>&1
set "T54D_PROBE_EXIT=!ERRORLEVEL!"

set "T54A_PROBE_PATH="
set "T54B_PROBE_PATH="
set "T54C_PROBE_PATH="
set "T54D_PROBE_PATH="
for %%F in ("Working\Test54\A\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T54A_PROBE_PATH=%%~fF"
for %%F in ("Working\Test54\B\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T54B_PROBE_PATH=%%~fF"
for %%F in ("Working\Test54\C\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T54C_PROBE_PATH=%%~fF"
for %%F in ("Working\Test54\D\Launcher\Diagnostics\*.log") do if exist "%%~fF" set "T54D_PROBE_PATH=%%~fF"

set "T54_PROBE=FAIL"
if "!T54A_PROBE_EXIT!"=="0" if "!T54B_PROBE_EXIT!"=="0" if "!T54C_PROBE_EXIT!"=="0" if "!T54D_PROBE_EXIT!"=="10" if defined T54A_PROBE_PATH if defined T54B_PROBE_PATH if defined T54C_PROBE_PATH if defined T54D_PROBE_PATH (
	findstr /l /b /c:"[PASS] [RunAfter] DirRemove protected-base cleanup is safe: e flag will remove empty descendant directories while preserving Lib=" "!T54A_PROBE_PATH!" >nul 2>&1
	if not errorlevel 1 findstr /l /b /c:"[PASS] [RunAfter] DirRemove protected-base cleanup is safe: trailing separator will remove contents while preserving Lib=" "!T54B_PROBE_PATH!" >nul 2>&1
	if not errorlevel 1 findstr /l /b /c:"[PASS] [RunAfter] DirRemove protected-base cleanup is safe: e flag will remove empty descendant directories while preserving Lib=" "!T54C_PROBE_PATH!" >nul 2>&1
	if not errorlevel 1 findstr /l /b /c:"[FAIL] [RunAfter] DirRemove has a dangerous target: protected path=" "!T54D_PROBE_PATH!" >nul 2>&1
	if not errorlevel 1 set "T54_PROBE=PASS"
)

start "" /wait "Working\Test54\A\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\A\Launcher\54A_DirRemove_Lib_Empty.ini" >nul 2>&1
set "T54A_EXIT=!ERRORLEVEL!"
start "" /wait "Working\Test54\B\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\B\Launcher\54B_DirRemove_Lib_Contents.ini" >nul 2>&1
set "T54B_EXIT=!ERRORLEVEL!"
start "" /wait "Working\Test54\C\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\C\Launcher\54C_DirRemove_Lib_Contents_Empty.ini" >nul 2>&1
set "T54C_EXIT=!ERRORLEVEL!"
start "" /wait "Working\Test54\D\Launcher\X-Launcher_x64.exe" "--x-launcher-config=%CD%\Working\Test54\D\Launcher\54D_DirRemove_Lib_Blocked.ini" >nul 2>&1
set "T54D_EXIT=!ERRORLEVEL!"

set "T54_PAYLOAD=PASS"
for %%M in (A B C D) do if not exist "Working\Test54\%%M\Root\PayloadRan.txt" set "T54_PAYLOAD=FAIL"

set "T54_EMPTY=FAIL"
if exist "Working\Test54\A\Root\Lib" if not exist "Working\Test54\A\Root\Lib\EmptyParent" if exist "Working\Test54\A\Root\Lib\Keep\Keep.txt" if exist "Working\Test54\A\Root\Lib\RootKeep.txt" set "T54_EMPTY=PASS"

set "T54_CONTENTS=FAIL"
if exist "Working\Test54\B\Root\Lib" if not exist "Working\Test54\B\Root\Lib\DeleteDir" if not exist "Working\Test54\B\Root\Lib\RootFile.txt" set "T54_CONTENTS=PASS"

set "T54_CONTENTS_EMPTY=FAIL"
if exist "Working\Test54\C\Root\Lib" if not exist "Working\Test54\C\Root\Lib\EmptyParent" if exist "Working\Test54\C\Root\Lib\Keep\Keep.txt" if exist "Working\Test54\C\Root\Lib\RootKeep.txt" set "T54_CONTENTS_EMPTY=PASS"

set "T54_BLOCKED=FAIL"
if exist "Working\Test54\D\Root\Lib\DeleteDir\Delete.txt" if exist "Working\Test54\D\Root\Lib\RootFile.txt" set "T54_BLOCKED=PASS"

set "T54_DEBUG=FAIL"
findstr /l /c:"[PASS] [RunAfter] DirRemove=" "Working\Test54\A\Launcher\54A_DirRemove_Lib_Empty.dbg" >nul 2>&1
if not errorlevel 1 findstr /l /c:"[PASS] [RunAfter] DirRemove=" "Working\Test54\B\Launcher\54B_DirRemove_Lib_Contents.dbg" >nul 2>&1
if not errorlevel 1 findstr /l /c:"[PASS] [RunAfter] DirRemove=" "Working\Test54\C\Launcher\54C_DirRemove_Lib_Contents_Empty.dbg" >nul 2>&1
if not errorlevel 1 findstr /l /c:"[FAIL] [RunAfter] DirRemove=" "Working\Test54\D\Launcher\54D_DirRemove_Lib_Blocked.dbg" >nul 2>&1
if not errorlevel 1 findstr /l /c:"error=5" "Working\Test54\D\Launcher\54D_DirRemove_Lib_Blocked.dbg" >nul 2>&1
if not errorlevel 1 findstr /l /c:"reason=protected target blocked" "Working\Test54\D\Launcher\54D_DirRemove_Lib_Blocked.dbg" >nul 2>&1
if not errorlevel 1 set "T54_DEBUG=PASS"

set "T54=FAIL"
if "!T54A_EXIT!"=="0" if "!T54B_EXIT!"=="0" if "!T54C_EXIT!"=="0" if "!T54D_EXIT!"=="0" if "!T54_PROBE!"=="PASS" if "!T54_PAYLOAD!"=="PASS" if "!T54_EMPTY!"=="PASS" if "!T54_CONTENTS!"=="PASS" if "!T54_CONTENTS_EMPTY!"=="PASS" if "!T54_BLOCKED!"=="PASS" if "!T54_DEBUG!"=="PASS" set "T54=PASS"
if "!T54!"=="PASS" (set /a PASSCOUNT+=1) else (set /a FAILCOUNT+=1)

echo.

echo ============================================================
echo RESULTS
echo ============================================================
echo - Exit Handler:                    !T1!
echo - Launch Failure Detection:        !T2!
echo - Ignore Unrelated Same-Name EXE:  !T3A!
echo - Preserve Multiple Instances:     !T3B!
echo - Preserve RunWait False:           !T4A!
echo - RunAfter Requires Waiting:        !T4B!
echo - Registry Command Exit Code:       !T5!
echo - Registry Backup Failure Safety:   !T6!
echo - Registry Restore Failure Safety:  !T7!
echo - Registry 32-bit View:              !T8!
echo - Registry 64-bit View:              !T8B!
echo - Registry Native View Compatibility: !T8C!
echo - Interrupted Registry Recovery:       !T9!
echo - Protected Registry Failure Safety:   !T10!
echo - RegView Auto Detect 32-bit EXE:      !T11A!
echo - RegView Auto Detect 64-bit EXE:      !T11B!
echo - RegView Auto Native Fallback:        !T11C!
echo - Multi-Root Registry Safety:          !T12!
echo - Registry Restore Order Manifest:     !T13!
echo - Registry Backup Filename Uniqueness: !T14!
echo - WriteToReg REG Syntax:               !T15!
echo - DirMove Partial Failure Safety:      !T16!
echo - DirCreate Return Contract:           !T17!
echo - FileDelete Return Contract:          !T18!
echo - FileCopy Return Contract:            !T19!
echo - FirstRun Required Failure Handling:  !T20!
echo - Temp Root Deletion Safety:           !T21!
echo - Splash Fallback Temp Parameter:      !T22!
echo - Splash Does Not Delay Startup:       !T23!
echo - Splash Title and Dimensions:         !T24!
echo - Automatic Language Result:           !T25!
echo - TrayTip Timeout Key Compatibility:   !T26!
echo - TrayTip Duration Units:              !T27!
echo - StringRegExp Counter Option:          !T28!
echo - Hidden EXE Command-Line Quoting:      !T29!
echo - Text Rewrite Format Preservation:     !T30!
echo - MozPrefs Exact Preference Matching:    !T31!
echo - Multi-Path Relative Path Consistency:  !T32!
echo - UNC Path Preservation:                  !T33!
echo - FixDriveLetter Safety and Scope:        !T34!
echo - FixUserProfile Source Safety:           !T35!
echo - FullPath Excessive Traversal Handling:  !T36!
echo - Java Download Completion Handling:       !T37!
echo - Java Fatal Error Propagation:             !T38!
echo - Java Tray Exit Cancellation:              !T39!
echo - JavaGet Result Handling:                   !T40!
echo - Java Version Comparison:                   !T41!
echo - Java Runtime Policy and Guidance:           !T42!
echo - Modern Java ZIP Transaction:               !T43!
echo - Configurable Java Download Compatibility:      !T44!
echo - TestRun Parsing and Safe Routing:               !T45!
echo - Configuration Probe Read-Only Checks:           !T46!
echo - ProcMonPath Resolution and Probe Reporting:      !T47!
echo - X-Launcher-Only Application Trace:                !T48!
echo - Readable Application Portability Report:           !T48B!
echo - FileMove Wildcard No-Match Semantics:               !T48C!
echo - RunAfter Stop-On-Failure Policy:                     !T48D!
echo - Portable LOCALAPPDATA TEMP and TMP Defaults:          !T48E!
echo - FixAppData Environment Compatibility:                 !T48F!
echo - Isolated Full Test Foundation:                     !T49!
echo - Full Test Debug Result Reporting:                  !T49_DEBUGREPORT_STAGE6L!
echo - Full Test Configuration Probe Parser:              !T49_PROBEPARSER_STAGE6M!
echo - MultipleInstances Correct Spelling:               !T50!
echo - SendMessageTimeout x64 Signature:                  !T51!
echo - Temporary Junction Lifecycle:                      !T52A!
echo - Persistent Junction Flag:                          !T52B!
echo - Temporary Symbolic-Link Lifecycle:                 !T53A! ^(!T53A_MODE!^)
echo - Persistent Symbolic-Link Flag:                     !T53B! ^(!T53B_MODE!^)
echo - Protected Lib DirRemove Modes:                     !T54!
echo.
echo Passed: !PASSCOUNT!
echo Failed: !FAILCOUNT!
echo Total:  !TOTAL!
echo ============================================================

>>"%RESULTS%" echo - Exit Handler=                    !T1!
>>"%RESULTS%" echo - Launch Failure Detection=        !T2!
>>"%RESULTS%" echo - Ignore Unrelated Same-Name EXE=  !T3A!
>>"%RESULTS%" echo - Preserve Multiple Instances=     !T3B!
>>"%RESULTS%" echo - Preserve RunWait False=           !T4A!
>>"%RESULTS%" echo - RunAfter Requires Waiting=        !T4B!
>>"%RESULTS%" echo - Registry Command Exit Code=       !T5!
>>"%RESULTS%" echo - Registry Backup Failure Safety=   !T6!
>>"%RESULTS%" echo - Registry Restore Failure Safety=  !T7!
>>"%RESULTS%" echo - Registry 32-bit View=              !T8!
>>"%RESULTS%" echo - Registry 64-bit View=              !T8B!
>>"%RESULTS%" echo - Registry Native View Compatibility= !T8C!
>>"%RESULTS%" echo - Interrupted Registry Recovery=       !T9!
>>"%RESULTS%" echo - Protected Registry Failure Safety=   !T10!
>>"%RESULTS%" echo - RegView Auto Detect 32-bit EXE=      !T11A!
>>"%RESULTS%" echo - RegView Auto Detect 64-bit EXE=      !T11B!
>>"%RESULTS%" echo - RegView Auto Native Fallback=        !T11C!
>>"%RESULTS%" echo - Multi-Root Registry Safety=          !T12!
>>"%RESULTS%" echo - Registry Restore Order Manifest=     !T13!
>>"%RESULTS%" echo - Registry Backup Filename Uniqueness= !T14!
>>"%RESULTS%" echo - WriteToReg REG Syntax=               !T15!
>>"%RESULTS%" echo - DirMove Partial Failure Safety=      !T16!
>>"%RESULTS%" echo - DirCreate Return Contract=           !T17!
>>"%RESULTS%" echo - FileDelete Return Contract=          !T18!
>>"%RESULTS%" echo - FileCopy Return Contract=            !T19!
>>"%RESULTS%" echo - FirstRun Required Failure Handling=  !T20!
>>"%RESULTS%" echo - Temp Root Deletion Safety=           !T21!
>>"%RESULTS%" echo - Splash Fallback Temp Parameter=      !T22!
>>"%RESULTS%" echo - Splash Does Not Delay Startup=       !T23!
>>"%RESULTS%" echo - Splash Title and Dimensions=         !T24!
>>"%RESULTS%" echo - Automatic Language Result=           !T25!
>>"%RESULTS%" echo - TrayTip Timeout Key Compatibility=   !T26!
>>"%RESULTS%" echo - TrayTip Duration Units=              !T27!
>>"%RESULTS%" echo - StringRegExp Counter Option=          !T28!
>>"%RESULTS%" echo - Hidden EXE Command-Line Quoting=      !T29!
>>"%RESULTS%" echo - Text Rewrite Format Preservation=     !T30!
>>"%RESULTS%" echo - MozPrefs Exact Preference Matching=    !T31!
>>"%RESULTS%" echo - Multi-Path Relative Path Consistency=  !T32!
>>"%RESULTS%" echo - UNC Path Preservation=                  !T33!
>>"%RESULTS%" echo - FixDriveLetter Safety and Scope=        !T34!
>>"%RESULTS%" echo - FixUserProfile Source Safety=           !T35!
>>"%RESULTS%" echo - FullPath Excessive Traversal Handling=  !T36!
>>"%RESULTS%" echo - Java Download Completion Handling=       !T37!
>>"%RESULTS%" echo - Java Fatal Error Propagation=             !T38!
>>"%RESULTS%" echo - Java Tray Exit Cancellation=              !T39!
>>"%RESULTS%" echo - JavaGet Result Handling=                   !T40!
>>"%RESULTS%" echo - Java Version Comparison=                   !T41!
>>"%RESULTS%" echo - Java Runtime Policy and Guidance=           !T42!
>>"%RESULTS%" echo - Modern Java ZIP Transaction=               !T43!
>>"%RESULTS%" echo - Configurable Java Download Compatibility=      !T44!
>>"%RESULTS%" echo - TestRun Parsing and Safe Routing=               !T45!
>>"%RESULTS%" echo - Configuration Probe Read-Only Checks=           !T46!
>>"%RESULTS%" echo - ProcMonPath Resolution and Probe Reporting=      !T47!
>>"%RESULTS%" echo - X-Launcher-Only Application Trace=                !T48!
>>"%RESULTS%" echo - Readable Application Portability Report=           !T48B!
>>"%RESULTS%" echo - FileMove Wildcard No-Match Semantics=               !T48C!
>>"%RESULTS%" echo - RunAfter Stop-On-Failure Policy=                     !T48D!
>>"%RESULTS%" echo - Portable LOCALAPPDATA TEMP and TMP Defaults=          !T48E!
>>"%RESULTS%" echo - FixAppData Environment Compatibility=                 !T48F!
>>"%RESULTS%" echo - Isolated Full Test Foundation=                     !T49!
>>"%RESULTS%" echo - Full Test Debug Result Reporting=                  !T49_DEBUGREPORT_STAGE6L!
>>"%RESULTS%" echo - Full Test Configuration Probe Parser=              !T49_PROBEPARSER_STAGE6M!
>>"%RESULTS%" echo - MultipleInstances Correct Spelling=               !T50!
>>"%RESULTS%" echo - SendMessageTimeout x64 Signature=                  !T51!
>>"%RESULTS%" echo - Temporary Junction Lifecycle=                      !T52A!
>>"%RESULTS%" echo - Persistent Junction Flag=                          !T52B!
>>"%RESULTS%" echo - Temporary Symbolic-Link Lifecycle=                 !T53A! ^(!T53A_MODE!^)
>>"%RESULTS%" echo - Persistent Symbolic-Link Flag=                     !T53B! ^(!T53B_MODE!^)
>>"%RESULTS%" echo - Protected Lib DirRemove Modes=                     !T54!
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed= !PASSCOUNT!
>>"%RESULTS%" echo Failed= !FAILCOUNT!
>>"%RESULTS%" echo Total=  !TOTAL!
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Test 02 launcher exit code= !T2EXIT!
>>"%RESULTS%" echo Test 03B during second instance= !T3B_MID!
>>"%RESULTS%" echo Test 03B after all instances=    !T3B_END!
>>"%RESULTS%" echo Test 05 host-key restore=             !T5_RESTORE!
>>"%RESULTS%" echo Test 05 failure detection=            !T5_DETECT!
>>"%RESULTS%" echo Test 06 host registry preserved=        !T6_HOST!
>>"%RESULTS%" echo Test 06 launcher exit code=             !T6EXIT!
>>"%RESULTS%" echo Test 07 failed backup preserved=        !T7_BACKUP!
>>"%RESULTS%" echo Test 07 restore failure detected=       !T7_DETECT!
>>"%RESULTS%" echo Test 08 active view selection=          !T8_ACTIVE!
>>"%RESULTS%" echo Test 08 32-bit host restored=           !T8_RESTORE32!
>>"%RESULTS%" echo Test 08 64-bit host untouched=          !T8_RESTORE64!
>>"%RESULTS%" echo Test 08B active view selection=         !T8B_ACTIVE!
>>"%RESULTS%" echo Test 08B 64-bit host restored=          !T8B_RESTORE64!
>>"%RESULTS%" echo Test 08B 32-bit host untouched=         !T8B_RESTORE32!
>>"%RESULTS%" echo Test 08C native active view=            !T8C_ACTIVE!
>>"%RESULTS%" echo Test 08C native 64-bit restored=        !T8C_RESTORE64!
>>"%RESULTS%" echo Test 08C native 32-bit untouched=       !T8C_RESTORE32!
>>"%RESULTS%" echo Test 09 portable state reached=          !T9_IMPORTED!
>>"%RESULTS%" echo Test 09 original backup survived crash=  !T9_BACKUP!
>>"%RESULTS%" echo Test 09 crash state established=         !T9_CRASH_STATE!
>>"%RESULTS%" echo Test 09 original host recovered=         !T9_RECOVERY!
>>"%RESULTS%" echo Test 10 permission denial established=    !T10_SETUP!
>>"%RESULTS%" echo Test 10 original host preserved=          !T10_HOST!
>>"%RESULTS%" echo Test 10 portable write blocked=           !T10_PORTABLE!
>>"%RESULTS%" echo Test 10 application launch blocked=       !T10_BLOCKED!
>>"%RESULTS%" echo Test 10 launcher exit code=                !T10EXIT!
>>"%RESULTS%" echo Test 11A Auto selected 32-bit view=       !T11A_ACTIVE!
>>"%RESULTS%" echo Test 11A 32-bit host restored=           !T11A_RESTORE32!
>>"%RESULTS%" echo Test 11A 64-bit host untouched=          !T11A_RESTORE64!
>>"%RESULTS%" echo Test 11B Auto selected 64-bit view=       !T11B_ACTIVE!
>>"%RESULTS%" echo Test 11B 64-bit host restored=           !T11B_RESTORE64!
>>"%RESULTS%" echo Test 11B 32-bit host untouched=          !T11B_RESTORE32!
>>"%RESULTS%" echo Test 11C Auto fallback used Native=       !T11C_ACTIVE!
>>"%RESULTS%" echo Test 11C Native host restored=           !T11C_RESTORE64!
>>"%RESULTS%" echo Test 11C 32-bit host untouched=          !T11C_RESTORE32!
>>"%RESULTS%" echo Test 12 both portable roots active=          !T12_ACTIVE!
>>"%RESULTS%" echo Test 12 first host root restored=           !T12_ROOT1!
>>"%RESULTS%" echo Test 12 second host root restored=          !T12_ROOT2!
>>"%RESULTS%" echo Test 12 first portable-only value removed=   !T12_CLEAN1!
>>"%RESULTS%" echo Test 12 second portable-only value removed=  !T12_CLEAN2!
>>"%RESULTS%" echo Test 12 both roots saved to portable REG=    !T12_SAVE!
>>"%RESULTS%" echo Test 13 portable registry state active=       !T13_ACTIVE!
>>"%RESULTS%" echo Test 13 transaction manifest present=         !T13_MANIFEST!
>>"%RESULTS%" echo Test 13 ordered backup manifest recorded=     !T13_ORDER!
>>"%RESULTS%" echo Test 13 original host registry restored=      !T13_RESTORE!
>>"%RESULTS%" echo Test 14 portable collision keys active=       !T14_ACTIVE!
>>"%RESULTS%" echo Test 14 backup filenames all unique=          !T14_UNIQUE!
>>"%RESULTS%" echo Test 14 collision victim host restored=       !T14_VICTIM!
>>"%RESULTS%" echo Test 14 collision winner host restored=       !T14_WINNER!
>>"%RESULTS%" echo Test 14 non-colliding host restored=          !T14_SAMPLE!
>>"%RESULTS%" echo Test 15 generated REG file created=           !T15_FILE!
>>"%RESULTS%" echo Test 15 generated REG syntax correct=         !T15_SYNTAX!
>>"%RESULTS%" echo Test 15 generated REG imports successfully=   !T15_IMPORT!
>>"%RESULTS%" echo Test 15 generated root value correct=         !T15_ROOT!
>>"%RESULTS%" echo Test 15 generated subkey value correct=       !T15_CHILD!
>>"%RESULTS%" echo Test 15 application reached generated values=  !T15_ACTIVE!
>>"%RESULTS%" echo Test 15 host registry cleaned after launch=    !T15_CLEAN!
>>"%RESULTS%" echo Test 15 launcher exit code=                   !T15_EXIT!
>>"%RESULTS%" echo Test 16 application launched after DirMove=     !T16_ACTIVE!
>>"%RESULTS%" echo Test 16 destination conflict preserved=        !T16_DESTCONFLICT!
>>"%RESULTS%" echo Test 16 non-conflicting file moved=             !T16_MOVED!
>>"%RESULTS%" echo Test 16 moved file removed from source=         !T16_MOVEDSOURCE!
>>"%RESULTS%" echo Test 16 unmoved source file preserved=          !T16_SOURCE!
>>"%RESULTS%" echo Test 16 launcher exit code=                     !T16_EXIT!
>>"%RESULTS%" echo Test 17 single directory created=                !T17_SINGLE_CREATED!
>>"%RESULTS%" echo Test 17 successful call reports success=         !T17_SINGLE_STATUS!
>>"%RESULTS%" echo Test 17 earlier create failure retained=          !T17_FAILURE_RETAINED!
>>"%RESULTS%" echo Test 17 later valid directories created=          !T17_LATER_CREATED!
>>"%RESULTS%" echo Test 17 helper probe exit code=                   !T17_EXIT!
>>"%RESULTS%" echo Test 18 single file deleted=                     !T18_SINGLE_DELETED!
>>"%RESULTS%" echo Test 18 successful delete reports success=       !T18_SINGLE_STATUS!
>>"%RESULTS%" echo Test 18 earlier delete failure retained=          !T18_FAILURE_RETAINED!
>>"%RESULTS%" echo Test 18 failed target preserved=                  !T18_FAILED_PRESERVED!
>>"%RESULTS%" echo Test 18 later valid file deleted=                 !T18_LATER_DELETED!
>>"%RESULTS%" echo Test 18 helper probe exit code=                   !T18_EXIT!
>>"%RESULTS%" echo Test 19 single file copied=                      !T19_SINGLE_COPIED!
>>"%RESULTS%" echo Test 19 successful copy reports success=         !T19_SINGLE_STATUS!
>>"%RESULTS%" echo Test 19 earlier copy failure retained=            !T19_FAILURE_RETAINED!
>>"%RESULTS%" echo Test 19 later valid file copied=                  !T19_LATER_COPIED!
>>"%RESULTS%" echo Test 19 missing source not fabricated=            !T19_MISSING_ABSENT!
>>"%RESULTS%" echo Test 19 helper probe exit code=                   !T19_EXIT!
>>"%RESULTS%" echo Test 20 failed FirstRun remains enabled=          !T20_FAIL_RETAINED!
>>"%RESULTS%" echo Test 20 payload blocked after FirstRun failure=   !T20_FAIL_BLOCKED!
>>"%RESULTS%" echo Test 20 successful FirstRun clears flag=         !T20_SUCCESS_CLEARED!
>>"%RESULTS%" echo Test 20 successful FirstRun operation completed= !T20_SUCCESS_OPERATION!
>>"%RESULTS%" echo Test 20 successful FirstRun payload launched=    !T20_SUCCESS_PAYLOAD!
>>"%RESULTS%" echo Test 20 successful launcher exit code=           !T20_SUCCESS_EXIT!
>>"%RESULTS%" echo Test 21 payload ran before cleanup=              !T21_PAYLOAD!
>>"%RESULTS%" echo Test 21 protected Root directory preserved=      !T21_ROOT!
>>"%RESULTS%" echo Test 21 protected Root sentinel preserved=       !T21_SENTINEL!
>>"%RESULTS%" echo Test 21 launcher exit code=                      !T21_EXIT!
>>"%RESULTS%" echo Test 22 fallback stored in supplied Temp=        !T22_SUPPLIED_TEMP!
>>"%RESULTS%" echo Test 22 wrong global temp unused=                 !T22_WRONG_GLOBAL!
>>"%RESULTS%" echo Test 22 helper probe exit code=                   !T22_EXIT!
>>"%RESULTS%" echo Test 23 payload started before splash timeout=    !T23_START!
>>"%RESULTS%" echo Test 24 configured splash title used=             !T24_TITLE!
>>"%RESULTS%" echo Test 24 configured splash width used=             !T24_WIDTH!
>>"%RESULTS%" echo Test 24 configured splash height used=            !T24_HEIGHT!
>>"%RESULTS%" echo Test 24 natural-size image fixture created=        !T24_FIXTURE!
>>"%RESULTS%" echo Test 24 image dimensions detected=                 !T24_DETECT!
>>"%RESULTS%" echo Test 24 blank width used natural image width=      !T24_NATURAL_WIDTH!
>>"%RESULTS%" echo Test 24 blank height used natural image height=    !T24_NATURAL_HEIGHT!
>>"%RESULTS%" echo Test 24 width-only aspect ratio preserved=         !T24_WIDTH_ASPECT!
>>"%RESULTS%" echo Test 24 height-only aspect ratio preserved=        !T24_HEIGHT_ASPECT!
>>"%RESULTS%" echo Test 24 helper probe exit code=                   !T24_EXIT!
>>"%RESULTS%" echo Test 25 automatic LANG value retained=            !T25_LANG!
>>"%RESULTS%" echo Test 25 payload launched=                         !T25_PAYLOAD!
>>"%RESULTS%" echo Test 25 launcher exit code=                       !T25_EXIT!
>>"%RESULTS%" echo Test 26 documented Timeout key read first=        !T26_STANDARD!
>>"%RESULTS%" echo Test 26 legacy trailing-space fallback retained=  !T26_LEGACY!
>>"%RESULTS%" echo Test 26 helper probe exit code=                   !T26_EXIT!
>>"%RESULTS%" echo Test 27 milliseconds converted to seconds=        !T27_CONVERTED!
>>"%RESULTS%" echo Test 27 TrayTip uses converted timeout=            !T27_TRAYTIP!
>>"%RESULTS%" echo Test 27 callback retains millisecond timeout=      !T27_CALLBACK!
>>"%RESULTS%" echo Test 27 helper probe exit code=                   !T27_EXIT!
>>"%RESULTS%" echo Test 28 configured replacement count honored=      !T28_LIMITED!
>>"%RESULTS%" echo Test 28 limited replacement reports success=       !T28_STATUS!
>>"%RESULTS%" echo Test 28 helper probe exit code=                     !T28_EXIT!
>>"%RESULTS%" echo Test 29 helper payload compiled=                     !T29_COMPILE!
>>"%RESULTS%" echo Test 29 exact argument count retained=               !T29_COUNT!
>>"%RESULTS%" echo Test 29 leading-option argument retained=            !T29_OPTION!
>>"%RESULTS%" echo Test 29 literal ampersand argument retained=         !T29_META!
>>"%RESULTS%" echo Test 29 hidden EXE launcher exit code=               !T29_EXIT!
>>"%RESULTS%" echo Test 29 forwarded option kept as one argument=       !T29_FORWARD_COUNT!
>>"%RESULTS%" echo Test 29 forwarded option value retained=             !T29_FORWARD_VALUE!
>>"%RESULTS%" echo Test 29 forwarded-argument launcher exit code=       !T29_FORWARD_EXIT!
>>"%RESULTS%" echo Test 30 StringReplace exact format preserved=        !T30_STRING!
>>"%RESULTS%" echo Test 30 StringRegExpReplace exact format preserved=  !T30_REGEXP!
>>"%RESULTS%" echo Test 30 WriteToFile exact format preserved=          !T30_FILE!
>>"%RESULTS%" echo Test 30 WriteToPref exact format preserved=          !T30_PREF!
>>"%RESULTS%" echo Test 30 MozPrefs exact format preserved=             !T30_MOZ!
>>"%RESULTS%" echo Test 30 helper probe exit code=                      !T30_EXIT!
>>"%RESULTS%" echo Test 31 User preference exact match only=             !T31_USER!
>>"%RESULTS%" echo Test 31 Global preference exact match only=           !T31_GLOBAL!
>>"%RESULTS%" echo Test 31 helper probe exit code=                       !T31_EXIT!
>>"%RESULTS%" echo Test 32 ordinary path normalized against Root=        !T32_ORDINARY!
>>"%RESULTS%" echo Test 32 wildcard path normalized against Root=        !T32_WILDCARD!
>>"%RESULTS%" echo Test 32 OnlyIfExist independent of working directory= !T32_WORKDIR!
>>"%RESULTS%" echo Test 32 helper probe exit code=                       !T32_EXIT!
>>"%RESULTS%" echo Test 33 FullPath direct UNC retained=                  !T33_FULLPATH!
>>"%RESULTS%" echo Test 33 NormalPath UNC prefix retained=                !T33_NORMALPATH!
>>"%RESULTS%" echo Test 33 forward-slash UNC normalized safely=          !T33_SLASHUNC!
>>"%RESULTS%" echo Test 33 FileInfo UNC parent retained=                  !T33_FILEINFO!
>>"%RESULTS%" echo Test 33 helper probe exit code=                       !T33_EXIT!
>>"%RESULTS%" echo Test 34 valid absolute path rewritten=                 !T34_VALID!
>>"%RESULTS%" echo Test 34 embedded drive-like text preserved=           !T34_EMBEDDED!
>>"%RESULTS%" echo Test 34 URL drive-like segment preserved=             !T34_URL!
>>"%RESULTS%" echo Test 34 non-drive Root rejected safely=               !T34_NONDRIVE!
>>"%RESULTS%" echo Test 34 helper probe exit code=                       !T34_EXIT!
>>"%RESULTS%" echo Test 35 valid child directory renamed=                !T35_VALID!
>>"%RESULTS%" echo Test 35 empty old value preserves profile root=       !T35_EMPTY!
>>"%RESULTS%" echo Test 35 parent traversal source rejected=             !T35_TRAVERSAL!
>>"%RESULTS%" echo Test 35 nested old source rejected=                   !T35_NESTED!
>>"%RESULTS%" echo Test 35 helper probe exit code=                       !T35_EXIT!
>>"%RESULTS%" echo Test 36 valid parent path normalized=                 !T36_VALID!
>>"%RESULTS%" echo Test 36 excessive traversal returns failure=         !T36_FAILURE!
>>"%RESULTS%" echo Test 36 child survives path error=                   !T36_SURVIVES!
>>"%RESULTS%" echo Test 36 helper probe exit code=                       !T36_EXIT!
>>"%RESULTS%" echo Test 37 waits until download completion=                  !T37_WAIT!
>>"%RESULTS%" echo Test 37 async start failure detected=                     !T37_START!
>>"%RESULTS%" echo Test 37 transfer success status checked=                  !T37_STATUS!
>>"%RESULTS%" echo Test 37 downloaded size verified=                        !T37_SIZE!
>>"%RESULTS%" echo Test 37 helper probe exit code=                          !T37_EXIT!
>>"%RESULTS%" echo Test 38 fatal helper returns close code=                    !T38_RETURN!
>>"%RESULTS%" echo Test 38 all fatal callers return immediately=                !T38_CALLERS!
>>"%RESULTS%" echo Test 38 backup restore retained=                            !T38_RESTORE!
>>"%RESULTS%" echo Test 38 helper probe exit code=                             !T38_EXIT!
>>"%RESULTS%" echo Test 39 cancellation state declared=                         !T39_STATE!
>>"%RESULTS%" echo Test 39 Tray Exit signals cancellation=                     !T39_SIGNAL!
>>"%RESULTS%" echo Test 39 JavaGet returns on cancellation=                    !T39_JAVA!
>>"%RESULTS%" echo Test 39 active download stops on cancellation=              !T39_DOWNLOAD!
>>"%RESULTS%" echo Test 39 restore and close path retained=                    !T39_CLEANUP!
>>"%RESULTS%" echo Test 39 helper probe exit code=                             !T39_EXIT!
>>"%RESULTS%" echo Test 40 JavaGet result captured=                          !T40_CAPTURE!
>>"%RESULTS%" echo Test 40 nonzero result propagated=                       !T40_PROPAGATE!
>>"%RESULTS%" echo Test 40 launcher captures Java error=                    !T40_LAUNCHER!
>>"%RESULTS%" echo Test 40 required Java failure stops launch=              !T40_REQUIRED!
>>"%RESULTS%" echo Test 40 optional Java fallback retained=                 !T40_OPTIONAL!
>>"%RESULTS%" echo Test 40 Java path assignment retained=                   !T40_PATH!
>>"%RESULTS%" echo Test 40 helper probe exit code=                          !T40_EXIT!
>>"%RESULTS%" echo Test 41 Misc version helper included=                    !T41_INCLUDE!
>>"%RESULTS%" echo Test 41 VersionCompare used for Java versions=           !T41_COMPARE!
>>"%RESULTS%" echo Test 41 direct version operator removed=                 !T41_DIRECT!
>>"%RESULTS%" echo Test 41 equal versions still prefer host Java=           !T41_EQUAL!
>>"%RESULTS%" echo Test 41 Java result propagation retained=                !T41_RESULT!
>>"%RESULTS%" echo Test 41 helper probe exit code=                          !T41_EXIT!
>>"%RESULTS%" echo Test 42 JavaURL read from application INI=               !T42_URLREAD!
>>"%RESULTS%" echo Test 42 configured URL passed to JavaGet=                !T42_URLPASS!
>>"%RESULTS%" echo Test 42 hidden legacy download URL removed=              !T42_OLDURL!
>>"%RESULTS%" echo Test 42 portable Java takes priority=                    !T42_PRIORITY!
>>"%RESULTS%" echo Test 42 missing JavaURL has explicit result=             !T42_MISSING!
>>"%RESULTS%" echo Test 42 required Java guidance is shown=                 !T42_GUIDANCE!
>>"%RESULTS%" echo Test 42 required Java still stops safely=                !T42_REQUIRED!
>>"%RESULTS%" echo Test 42 optional Java fallback retained=                 !T42_OPTIONAL!
>>"%RESULTS%" echo Test 42 helper probe exit code=                          !T42_EXIT!
>>"%RESULTS%" echo Test 43 ZIP and legacy setup packages accepted=            !T43_PATTERNS!
>>"%RESULTS%" echo Test 43 package staged before live backup=                 !T43_STAGE!
>>"%RESULTS%" echo Test 43 direct ZIP runtime root recognized=                !T43_DIRECT!
>>"%RESULTS%" echo Test 43 wrapped ZIP runtime root recognized=               !T43_WRAPPED!
>>"%RESULTS%" echo Test 43 ambiguous ZIP runtime rejected=                    !T43_AMBIGUOUS!
>>"%RESULTS%" echo Test 43 complete portable runtime backed up=               !T43_BACKUP!
>>"%RESULTS%" echo Test 43 failed install restores complete runtime=           !T43_RESTORE!
>>"%RESULTS%" echo Test 43 setup package preserved during transaction=         !T43_SETUP!
>>"%RESULTS%" echo Test 43 legacy EXE extraction retained=                    !T43_LEGACY!
>>"%RESULTS%" echo Test 43 helper probe exit code=                            !T43_EXIT!
>>"%RESULTS%" echo Test 44 optional JavaURL key documented in template=         !T44_TEMPLATE!
>>"%RESULTS%" echo Test 44 optional JavaPath key documented in template=        !T44_PATHTEMPLATE!
>>"%RESULTS%" echo Test 44 old INI without JavaURL remains compatible=          !T44_OLDINI!
>>"%RESULTS%" echo Test 44 old INI without JavaPath remains compatible=         !T44_OLDPATH!
>>"%RESULTS%" echo Test 44 absolute and quoted JavaPath roots accepted=          !T44_ABSOLUTE!
>>"%RESULTS%" echo Test 44 JavaPath bin and Java executables normalized=         !T44_EXECUTABLE!
>>"%RESULTS%" echo Test 44 relative JavaPath resolved against Root=             !T44_RELATIVE!
>>"%RESULTS%" echo Test 44 JavaPortableLauncher rejected as runtime=             !T44_LAUNCHER!
>>"%RESULTS%" echo Test 44 only HTTP and HTTPS Java URLs accepted=              !T44_URLVALID!
>>"%RESULTS%" echo Test 44 invalid JavaURL has brief required-Java guidance=     !T44_GUIDANCE!
>>"%RESULTS%" echo Test 44 downloaded package uses format-neutral filename=     !T44_FILENAME!
>>"%RESULTS%" echo Test 44 configured JavaURL passed unchanged to downloader=    !T44_URLPASS!
>>"%RESULTS%" echo Test 44 JAVA_HOME system fallback recognized=                !T44_JAVAHOME!
>>"%RESULTS%" echo Test 44 PATH system fallback recognized=                     !T44_PATH!
>>"%RESULTS%" echo Test 44 legacy and modern JavaSoft registry fallbacks=        !T44_REGISTRY!
>>"%RESULTS%" echo Test 44 portable Java remains preferred over system Java=     !T44_PRIORITY!
>>"%RESULTS%" echo Test 44 configured JavaPath has first source priority=         !T44_CONFIGURED!
>>"%RESULTS%" echo Test 44 valid JavaPath bypasses JavaURL and JavaGet writes=    !T44_URLBYPASS!
>>"%RESULTS%" echo Test 44 Java false ignores but retains JavaPath=               !T44_DISABLED!
>>"%RESULTS%" echo Test 44 external JavaPath runtime remains byte-identical=      !T44_READONLY!
>>"%RESULTS%" echo Test 44 helper probe exit code=                               !T44_EXIT!
>>"%RESULTS%" echo Test 45 old INI without TestRun launches normally=             !T45_MISSING!
>>"%RESULTS%" echo Test 45 explicit TestRun false launches normally=              !T45_FALSE!
>>"%RESULTS%" echo Test 45 missing-key launcher exit code=                        !T45_MISSING_EXIT!
>>"%RESULTS%" echo Test 45 false-mode launcher exit code=                         !T45_FALSE_EXIT!
>>"%RESULTS%" echo Test 45 template documents TestRun false=                      !T45_TEMPLATE!
>>"%RESULTS%" echo Test 45 missing TestRun defaults to false=                     !T45_DEFAULT!
>>"%RESULTS%" echo Test 45 blank TestRun falls back to false=                     !T45_BLANK!
>>"%RESULTS%" echo Test 45 valid TestRun modes are case insensitive=              !T45_CASE!
>>"%RESULTS%" echo Test 45 invalid INI value stops safely=                        !T45_INVALID!
>>"%RESULTS%" echo Test 45 direct command line modes are recognized=              !T45_DIRECT!
>>"%RESULTS%" echo Test 45 command line mode overrides INI=                       !T45_OVERRIDE!
>>"%RESULTS%" echo Test 45 selection window exposes four outcomes=                !T45_SELECTOR!
>>"%RESULTS%" echo Test 45 selection cancellation stops launch=                   !T45_SELECT_CANCEL!
>>"%RESULTS%" echo Test 45 confirmation cancellation stops launch=                !T45_CONFIRM_CANCEL!
>>"%RESULTS%" echo Test 45 Trace route and safe Probe/Full stops=                  !T45_STOP!
>>"%RESULTS%" echo Test 45 helper probe exit code=                                !T45_EXIT!
>>"%RESULTS%" echo Test 46 valid Probe completed successfully=                    !T46_VALID_CODE!
>>"%RESULTS%" echo Test 46 invalid Probe returned findings exit code=             !T46_INVALID_CODE!
>>"%RESULTS%" echo Test 46 configured payload was not launched=                   !T46_NO_LAUNCH!
>>"%RESULTS%" echo Test 46 application INIs remained byte-identical=              !T46_INI_SAFE!
>>"%RESULTS%" echo Test 46 configured files and directories were unchanged=       !T46_FILES_SAFE!
>>"%RESULTS%" echo Test 46 Java runtime and setup sources were unchanged=          !T46_JAVA_SAFE!
>>"%RESULTS%" echo Test 46 configured registry state was unchanged=               !T46_REG_SAFE!
>>"%RESULTS%" echo Test 46 valid report and zero-failure summary created=          !T46_REPORT!
>>"%RESULTS%" echo Test 46 invalid core findings reported accurately=             !T46_INVALID_REPORT!
>>"%RESULTS%" echo Test 46 valid environment and operation checks reported=        !T46_OPERATIONS_REPORT!
>>"%RESULTS%" echo Test 46 Windows environment names and invalid operations reported= !T46_INVALID_OPERATIONS!
>>"%RESULTS%" echo Test 46 DirRemove modes and absent targets in supported sections= !T46_DIRREMOVE_REPORT!
>>"%RESULTS%" echo Test 46 valid dynamic rewrite and write checks reported=         !T46_DYNAMIC_REPORT!
>>"%RESULTS%" echo Test 46 invalid dynamic section findings reported=               !T46_INVALID_DYNAMIC!
>>"%RESULTS%" echo Test 46 valid Java source and policy checks reported=             !T46_JAVA_REPORT!
>>"%RESULTS%" echo Test 46 invalid Java package and URL findings reported=           !T46_INVALID_JAVA!
>>"%RESULTS%" echo Test 46 summary repeats only ordered FAIL and WARN findings=       !T46_ATTENTION_SUMMARY!
>>"%RESULTS%" echo Test 46 Configuration Probe reports use the .log extension=        !T46_REPORT_EXTENSION!
>>"%RESULTS%" echo Test 46 valid Probe exit code=                                 !T46_VALID_EXIT!
>>"%RESULTS%" echo Test 46 invalid Probe exit code=                               !T46_INVALID_EXIT!
>>"%RESULTS%" echo Test 47 all Probe cases returned success=                       !T47_EXITS!
>>"%RESULTS%" echo Test 47 X-Launcher variable folder resolved and reported=       !T47_MACRO!
>>"%RESULTS%" echo Test 47 blank key found documented default=                     !T47_DEFAULT!
>>"%RESULTS%" echo Test 47 missing optional path reported as warning=              !T47_MISSING!
>>"%RESULTS%" echo Test 47 unexpected executable name reported as warning=         !T47_INVALID!
>>"%RESULTS%" echo Test 47 environment-expanded absolute path resolved=            !T47_ENV!
>>"%RESULTS%" echo Test 47 configured payloads were not launched=                  !T47_NO_LAUNCH!
>>"%RESULTS%" echo Test 47 Process Monitor fixtures remained byte-identical=       !T47_FILES_SAFE!
>>"%RESULTS%" echo Test 47 optional key and default documented in template=         !T47_TEMPLATE!
>>"%RESULTS%" echo Test 47 direct absolute executable resolution=                  !T47_ABSOLUTE!
>>"%RESULTS%" echo Test 47 Root-relative executable resolution=                    !T47_RELATIVE!
>>"%RESULTS%" echo Test 47 directory executable selection=                         !T47_FOLDER!
>>"%RESULTS%" echo Test 47 direct blank-default resolution=                        !T47_HELPER_DEFAULT!
>>"%RESULTS%" echo Test 47 invalid executable name rejection=                      !T47_HELPER_INVALID!
>>"%RESULTS%" echo Test 47 missing configured path result=                         !T47_HELPER_MISSING!
>>"%RESULTS%" echo Test 47 UNC prefix preservation=                                !T47_UNC!
>>"%RESULTS%" echo Test 47 resolver contains no launch download or EULA action=    !T47_READONLY!
>>"%RESULTS%" echo Test 47 helper probe exit code=                                 !T47_HELPER_EXIT!
>>"%RESULTS%" echo Test 48 report metadata categories totals and privacy=           !T48_REPORT!
>>"%RESULTS%" echo Test 48 file category includes directory creation=               !T48_FILE_CATEGORY!
>>"%RESULTS%" echo Test 48 retained handle captures real application exit code=      !T48_EXITCODE!
>>"%RESULTS%" echo Test 48 launcher application and child process details=          !T48_PROCESS!
>>"%RESULTS%" echo Test 48 finalization no-overwrite guard=                         !T48_FINALIZE!
>>"%RESULTS%" echo Test 48 confirmed Trace enters real lifecycle=                   !T48_ROUTE!
>>"%RESULTS%" echo Test 48 no Process Monitor download or automatic EULA acceptance= !T48_NO_PROCMON!
>>"%RESULTS%" echo Test 48 Process Monitor start and stop request elevation=          !T48_PROCMON_ELEVATION!
>>"%RESULTS%" echo Test 48 verified Process Monitor command contract=                !T48_PROCMON_COMMANDS!
>>"%RESULTS%" echo Test 48 full Process Monitor elevation and licence prompt wait=     !T48_PROCMON_PROMPT_WAIT!
>>"%RESULTS%" echo Test 48 Process Monitor size and free-space safeguards=              !T48_PROCMON_LIMITS!
>>"%RESULTS%" echo Test 48 Process Monitor stop order and native PML path=            !T48_PROCMON_STOP!
>>"%RESULTS%" echo Test 48 Trace session end follows Process Monitor finalization=     !T48_SESSION_END!
>>"%RESULTS%" echo Test 48 missing Process Monitor choice=                          !T48_MISSING!
>>"%RESULTS%" echo Test 48 unique diagnostics session folder=                       !T48_UNIQUE!
>>"%RESULTS%" echo Test 48 PID recording with waited completion=                    !T48_PIDWAIT!
>>"%RESULTS%" echo Test 48 internal diagnostic arguments withheld=                  !T48_ARGS!
>>"%RESULTS%" echo Test 48 plain-language results auto-open and report fallbacks=     !T48_AUTO_OPEN!
>>"%RESULTS%" echo Test 48 helper probe exit code=                                  !T48_HELPER_EXIT!
>>"%RESULTS%" echo Test 48B readable portability report created=                     !T48B_CREATED!
>>"%RESULTS%" echo Test 48B launcher failures blocked warnings and portability passes= !T48B_SIMPLE!
>>"%RESULTS%" echo Test 48B pass lines identify matching INI settings=               !T48B_SIMPLE_INI!
>>"%RESULTS%" echo Test 48B blocked counts and DriverStore grouping=                  !T48B_BLOCKED_GROUP!
>>"%RESULTS%" echo Test 48B NTFS metadata excluded from portability warnings=         !T48B_NTFS_METADATA!
>>"%RESULTS%" echo Test 48B system/install grouping preserves registry warnings=       !T48B_SYSTEM_INSTALL!
>>"%RESULTS%" echo Test 48B ProcMon XML process-index/PID mapping=                   !T48B_XML!
>>"%RESULTS%" echo Test 48B automatic write-focused destructive ProcMon filter=       !T48B_FILTER!
>>"%RESULTS%" echo Test 48B fast canonical CSV parsing=                              !T48B_FASTCSV!
>>"%RESULTS%" echo Test 48B indexed repeated-target collapse=                       !T48B_INDEXED!
>>"%RESULTS%" echo Test 48B direct REG root parser=                                  !T48B_REGPARSER!
>>"%RESULTS%" echo Test 48B repeated events collapsed by target=                     !T48B_COLLAPSE!
>>"%RESULTS%" echo Test 48B child attribution and unrelated PID exclusion=            !T48B_ATTRIBUTION!
>>"%RESULTS%" echo Test 48B current INI file and registry coverage=                   !T48B_MANAGED!
>>"%RESULTS%" echo Test 48B unmanaged file and registry review visibility=            !T48B_UNMANAGED!
>>"%RESULTS%" echo Test 48B failures residue limitations and privacy disclosure=      !T48B_DISCLOSURE!
>>"%RESULTS%" echo Test 48B portability report key-value separators=                   !T48B_FORMAT!
>>"%RESULTS%" echo Test 48B helper probe exit code=                                   !T48B_HELPER_EXIT!
>>"%RESULTS%" echo Test 48C Configuration Probe returned exact-missing failure code=   !T48C_PROBE_CODE!
>>"%RESULTS%" echo Test 48C Probe reports wildcard zero-match as NOT USED=              !T48C_PROBE_WILDCARD!
>>"%RESULTS%" echo Test 48C Probe retains exact missing FileMove as FAIL=               !T48C_PROBE_EXACT!
>>"%RESULTS%" echo Test 48C payload launch and launcher exit code=                      !T48C_LAUNCH!
>>"%RESULTS%" echo Test 48C Debug log created=                                         !T48C_DEBUG!
>>"%RESULTS%" echo Test 48C Debug reports wildcard zero-match as SKIP=                 !T48C_WILDCARD_SKIP!
>>"%RESULTS%" echo Test 48C wildcard zero-match is not reported as FAIL=               !T48C_WILDCARD_NO_FAIL!
>>"%RESULTS%" echo Test 48C later RunAfter operation still executed=                    !T48C_CONTINUE!
>>"%RESULTS%" echo Test 48C runtime retains exact missing FileMove as FAIL=             !T48C_EXACT_FAIL!
>>"%RESULTS%" echo Test 48C runtime launcher exit code=                                 !T48C_EXIT!
>>"%RESULTS%" echo Test 48C Configuration Probe exit code=                             !T48C_PROBE_EXIT!
>>"%RESULTS%" echo Test 48D missing option reports backward-compatible false default=  !T48D_PROBE_DEFAULT!
>>"%RESULTS%" echo Test 48D missing option continues after RunAfter failure=            !T48D_DEFAULT_CONTINUE!
>>"%RESULTS%" echo Test 48D default-policy internal Temp cleanup completed=             !T48D_DEFAULT_TEMP!
>>"%RESULTS%" echo Test 48D true-policy Probe returned findings exit code=              !T48D_PROBE_CODE!
>>"%RESULTS%" echo Test 48D true option validated as Boolean=                           !T48D_PROBE_TRUE!
>>"%RESULTS%" echo Test 48D option is recognized instead of reported unknown=           !T48D_PROBE_KNOWN!
>>"%RESULTS%" echo Test 48D Probe left host registry unchanged=                         !T48D_PROBE_REGISTRY!
>>"%RESULTS%" echo Test 48D payload observed portable registry state=                   !T48D_PORTABLE!
>>"%RESULTS%" echo Test 48D wildcard SKIP did not stop next operation=                  !T48D_SKIP_CONTINUE!
>>"%RESULTS%" echo Test 48D genuine failure stopped later configured operation=         !T48D_STOPPED!
>>"%RESULTS%" echo Test 48D mandatory registry restoration still completed=             !T48D_REGISTRY!
>>"%RESULTS%" echo Test 48D mandatory internal Temp cleanup still completed=            !T48D_TEMP!
>>"%RESULTS%" echo Test 48D Debug retained wildcard no-match SKIP=                      !T48D_WILDCARD_SKIP!
>>"%RESULTS%" echo Test 48D Debug retained exact missing-source FAIL=                   !T48D_EXACT_FAIL!
>>"%RESULTS%" echo Test 48D Debug explains why remaining operations stopped=            !T48D_DEBUG_STOP!
>>"%RESULTS%" echo Test 48D template documents backward-compatible false default=      !T48D_TEMPLATE!
>>"%RESULTS%" echo Test 48D default-policy launcher exit code=                          !T48D_DEFAULT_EXIT!
>>"%RESULTS%" echo Test 48D default-policy Configuration Probe exit code=               !T48D_DEFAULT_PROBE_EXIT!
>>"%RESULTS%" echo Test 48D true-policy launcher exit code=                             !T48D_STOP_EXIT!
>>"%RESULTS%" echo Test 48D true-policy Configuration Probe exit code=                  !T48D_STOP_PROBE_EXIT!
>>"%RESULTS%" echo Test 48E missing options report false defaults=                       !T48E_PROBE_DEFAULT!
>>"%RESULTS%" echo Test 48E missing options retain inherited environment=                !T48E_DEFAULT_RUNTIME!
>>"%RESULTS%" echo Test 48E false defaults create no portable directories=               !T48E_DEFAULT_DIRECTORIES!
>>"%RESULTS%" echo Test 48E true options validate as Booleans=                           !T48E_PROBE_TRUE!
>>"%RESULTS%" echo Test 48E options are recognized rather than unknown=                  !T48E_PROBE_KNOWN!
>>"%RESULTS%" echo Test 48E enabled child received all three portable variables=         !T48E_ENABLED_RUNTIME!
>>"%RESULTS%" echo Test 48E enabled portable directories existed before launch=          !T48E_ENABLED_DIRECTORIES!
>>"%RESULTS%" echo Test 48E Debug reports LOCALAPPDATA TEMP and TMP success=              !T48E_DEBUG!
>>"%RESULTS%" echo Test 48E explicit Environment values take priority=                   !T48E_OVERRIDE_RUNTIME!
>>"%RESULTS%" echo Test 48E template contains backward-compatible false defaults=       !T48E_TEMPLATE!
>>"%RESULTS%" echo Test 48E README distinguishes redirection from cleanup=               !T48E_DOCS!
>>"%RESULTS%" echo Test 48E default launcher exit code=                                  !T48E_DEFAULT_EXIT!
>>"%RESULTS%" echo Test 48E default Configuration Probe exit code=                       !T48E_DEFAULT_PROBE_EXIT!
>>"%RESULTS%" echo Test 48E enabled launcher exit code=                                  !T48E_ENABLED_EXIT!
>>"%RESULTS%" echo Test 48E enabled Configuration Probe exit code=                       !T48E_ENABLED_PROBE_EXIT!
>>"%RESULTS%" echo Test 48E override launcher exit code=                                 !T48E_OVERRIDE_EXIT!
>>"%RESULTS%" echo Test 48F combined environment reached the payload=                    !T48F_ENVIRONMENT!
>>"%RESULTS%" echo Test 48F profile config retained the correct AppData name=            !T48F_CONFIG!
>>"%RESULTS%" echo Test 48F Debug retained the correct portable APPDATA=                 !T48F_DEBUG!
>>"%RESULTS%" echo Test 48F Debug timestamp separator uses equals=                       !T48F_DEBUG_FORMAT!
>>"%RESULTS%" echo Test 48F Log retained the full portable APPDATA path=                  !T48F_LOG!
>>"%RESULTS%" echo Test 48F PROGRAMFILES(x86) reached the payload and Debug=             !T48F_PROGRAMFILES!
>>"%RESULTS%" echo Test 48F profile config remained byte-stable across two launches=     !T48F_STABLE!
>>"%RESULTS%" echo Test 48F first launcher exit code=                                    !T48F_FIRST_EXIT!
>>"%RESULTS%" echo Test 48F second launcher exit code=                                   !T48F_SECOND_EXIT!
>>"%RESULTS%" echo Test 49 Full Test launcher exit code=                             !T49_EXIT!
>>"%RESULTS%" echo Test 49 report structure and zero failures=                       !T49_REPORT!
>>"%RESULTS%" echo Test 49 private self-helper command and exit contracts=            !T49_HELPER!
>>"%RESULTS%" echo Test 49 launch failure and concurrent process behaviour=             !T49_PROCESS!
>>"%RESULTS%" echo Test 49 isolated file-system operations and safety=                  !T49_FILESYSTEM!
>>"%RESULTS%" echo Test 49 text encoding and line-ending preservation=                  !T49_TEXTFORMAT!
>>"%RESULTS%" echo Test 49 isolated INI preference and REG writer semantics=             !T49_WRITERS!
>>"%RESULTS%" echo Test 49 isolated registry views transactions restore and recovery=     !T49_REGISTRY_STAGE6F!
>>"%RESULTS%" echo Test 49 isolated environment and path expansion=                        !T49_ENVPATH_STAGE6G!
>>"%RESULTS%" echo Test 49 isolated path traversal profile and cleanup safety=              !T49_PATHSAFETY_STAGE6H!
>>"%RESULTS%" echo Test 49 isolated splash and TrayTip runtime behavior=                      !T49_SPLASHTRAY_STAGE6I!
>>"%RESULTS%" echo Test 49 isolated JavaPath selection and read-only behavior=                 !T49_JAVAPATH_STAGE6J!
>>"%RESULTS%" echo Test 49 isolated Java package transaction and rollback behavior=            !T49_JAVATRANSACTION_STAGE6K!
>>"%RESULTS%" echo Test 49 isolated Debug result reporting classifications and state restore=    !T49_DEBUGREPORT_STAGE6L!
>>"%RESULTS%" echo Test 49 isolated Configuration Probe parser cross-checks and read-only proof= !T49_PROBEPARSER_STAGE6M!
>>"%RESULTS%" echo Test 49 configured INI is context only=                           !T49_ISOLATION!
>>"%RESULTS%" echo Test 49 configured files and operations untouched=                !T49_ISOLATION_FILES!
>>"%RESULTS%" echo Test 49 host registry sentinel untouched=                         !T49_REGISTRY!
>>"%RESULTS%" echo Test 49 isolated workspace and HKCU root removed=                 !T49_CLEANUP!
>>"%RESULTS%" echo Test 49 privacy warning present=                                  !T49_PRIVACY!
>>"%RESULTS%" echo Test 49 Full Test is independent of a missing application INI=     !T49_NOINI!
>>"%RESULTS%" echo Test 49 no-INI launcher exit code=                                 !T49_NOINI_EXIT_CHECK!
>>"%RESULTS%" echo Test 49 missing INI remained absent=                               !T49_NOINI_MISSING!
>>"%RESULTS%" echo Test 49 no-INI report was created=                                 !T49_NOINI_REPORT_CHECK!
>>"%RESULTS%" echo Test 49 no-INI report contains zero failures=                      !T49_NOINI_ZERO!
>>"%RESULTS%" echo Test 49 no-INI path recorded as context only=                      !T49_NOINI_CONTEXT!
>>"%RESULTS%" echo Test 50 corrected false value accepted=                            !T50_CORRECTED_FALSE!
>>"%RESULTS%" echo Test 50 corrected true value accepted=                             !T50_CORRECTED_TRUE!
>>"%RESULTS%" echo Test 50 former misspelling rejected=                               !T50_FORMER!
>>"%RESULTS%" echo Test 50 invalid corrected value uses default=                      !T50_INVALID!
>>"%RESULTS%" echo Test 50 helper exit code=                                           !T50_EXIT!
>>"%RESULTS%" echo Test 50 corrected-false resolved value=                             !T50_VALUE_CORRECTED_FALSE!
>>"%RESULTS%" echo Test 50 corrected-true resolved value=                              !T50_VALUE_CORRECTED_TRUE!
>>"%RESULTS%" echo Test 50 former-only resolved value=                                 !T50_VALUE_FORMER!
>>"%RESULTS%" echo Test 50 invalid-corrected resolved value=                           !T50_VALUE_INVALID!
>>"%RESULTS%" echo Test 51 x-udf source readable=                                      !T51_READ!
>>"%RESULTS%" echo Test 51 AddFonts pointer-sized signature=                          !T51_ADD!
>>"%RESULTS%" echo Test 51 RemoveFonts pointer-sized signature=                       !T51_REMOVE!
>>"%RESULTS%" echo Test 51 legacy signature absent=                                   !T51_LEGACY!
>>"%RESULTS%" echo Test 51 helper exit code=                                           !T51_EXIT!
>>"%RESULTS%" echo Test 52A launcher exit code=                                        !T52A_EXIT!
>>"%RESULTS%" echo Test 52A target received payload write=                             !T52A_TARGET!
>>"%RESULTS%" echo Test 52A temporary junction removed=                                !T52A_REMOVED!
>>"%RESULTS%" echo Test 52A creation and cleanup Debug records=                        !T52A_DEBUG!
>>"%RESULTS%" echo Test 52A temporary junction forced RunWait=                         !T52A_FORCED!
>>"%RESULTS%" echo Test 52B launcher exit code=                                        !T52B_EXIT!
>>"%RESULTS%" echo Test 52B target received payload write=                             !T52B_TARGET!
>>"%RESULTS%" echo Test 52B persistent junction remained a reparse point=              !T52B_KEPT!
>>"%RESULTS%" echo Test 52B persistent lifetime and no automatic cleanup=              !T52B_DEBUG!
>>"%RESULTS%" echo Test 52B test cleanup removed only link=                            !T52B_CLEANUP!
>>"%RESULTS%" echo Test 53A launcher exit code=                                        !T53A_EXIT!
>>"%RESULTS%" echo Test 53A symbolic-link test mode=                                   !T53A_MODE!
>>"%RESULTS%" echo Test 53B launcher exit code=                                        !T53B_EXIT!
>>"%RESULTS%" echo Test 53B symbolic-link test mode=                                   !T53B_MODE!
>>"%RESULTS%" echo Test 54 Probe accepted safe modes and blocked direct Lib removal=   !T54_PROBE!
>>"%RESULTS%" echo Test 54 all four application payloads launched=                     !T54_PAYLOAD!
>>"%RESULTS%" echo Test 54 Lib pipe-e removed empty descendants and preserved Lib=     !T54_EMPTY!
>>"%RESULTS%" echo Test 54 Lib trailing slash removed contents and preserved Lib=      !T54_CONTENTS!
>>"%RESULTS%" echo Test 54 Lib trailing slash pipe-e preserved non-empty content=      !T54_CONTENTS_EMPTY!
>>"%RESULTS%" echo Test 54 direct Lib removal was blocked and content survived=        !T54_BLOCKED!
>>"%RESULTS%" echo Test 54 runtime Debug classified safe and blocked modes=             !T54_DEBUG!
>>"%RESULTS%" echo Test 54A launcher exit code=                                        !T54A_EXIT!
>>"%RESULTS%" echo Test 54B launcher exit code=                                        !T54B_EXIT!
>>"%RESULTS%" echo Test 54C launcher exit code=                                        !T54C_EXIT!
>>"%RESULTS%" echo Test 54D launcher exit code=                                        !T54D_EXIT!

if !FAILCOUNT! GTR 0 (
    set "SUITE_RC=1"
) else (
    set "SUITE_RC=0"
)

if /I not "%~1"=="/nopause" (
    echo.
    echo Results also saved to:
    echo %RESULTS%
    echo.
    pause
)

exit /b !SUITE_RC!
