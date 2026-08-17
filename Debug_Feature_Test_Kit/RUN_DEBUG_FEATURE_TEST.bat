@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "KIT_ROOT=%~dp0"
set "EXE=%PROJECT_ROOT%\X-Launcher_x64.exe"
set "INI=%KIT_ROOT%Debug_Feature_Test.ini"
set "WORK=%KIT_ROOT%Debug_Feature_Test_Work"
set "LEGACY_WORK=%PROJECT_ROOT%\Debug_Feature_Test_Work"
set "ROOT_DEBUG_LOG=%PROJECT_ROOT%\Debug_Feature_Test.dbg"
set "ROOT_SETTINGS_LOG=%PROJECT_ROOT%\Debug_Feature_Test.log"
set "ROOT_RESULTS=%PROJECT_ROOT%\Debug_Feature_Test_Results.txt"
set "DEBUG_LOG=%KIT_ROOT%Debug_Feature_Test.dbg"
set "SETTINGS_LOG=%KIT_ROOT%Debug_Feature_Test.log"
set "RESULTS=%KIT_ROOT%Debug_Feature_Test_Results.txt"
set /a PASS_COUNT=0
set /a FAIL_COUNT=0

cd /d "%PROJECT_ROOT%"
title X-Launcher Stage 2 Debug Feature Test

echo ============================================================
echo X-LAUNCHER STAGE 2 - REAL DEBUG FEATURE TEST
echo ============================================================
echo.

if not exist "%EXE%" (
    echo ERROR: X-Launcher_x64.exe was not found in:
    echo "%PROJECT_ROOT%"
    echo.
    echo Place Debug_Feature_Test_Kit inside the project folder.
    goto EARLY_FAIL
)

if not exist "%INI%" (
    echo ERROR: Debug_Feature_Test.ini is missing from the test kit.
    goto EARLY_FAIL
)

if exist "%WORK%" rmdir /s /q "%WORK%"
if exist "%WORK%" (
    echo ERROR: The previous test workspace could not be removed:
    echo "%WORK%"
    goto EARLY_FAIL
)

if exist "%LEGACY_WORK%" rmdir /s /q "%LEGACY_WORK%"
if exist "%LEGACY_WORK%" (
    echo ERROR: The previous root-level test workspace could not be removed:
    echo "%LEGACY_WORK%"
    goto EARLY_FAIL
)

if exist "%ROOT_DEBUG_LOG%" del /q "%ROOT_DEBUG_LOG%"
if exist "%ROOT_SETTINGS_LOG%" del /q "%ROOT_SETTINGS_LOG%"
if exist "%ROOT_RESULTS%" del /q "%ROOT_RESULTS%"
if exist "%DEBUG_LOG%" del /q "%DEBUG_LOG%"
if exist "%SETTINGS_LOG%" del /q "%SETTINGS_LOG%"
if exist "%RESULTS%" del /q "%RESULTS%"

mkdir "%WORK%" >nul 2>&1
>"%WORK%\NoChange.txt" echo This content deliberately needs no replacement.

>"%RESULTS%" (
    echo X-LAUNCHER STAGE 2 DEBUG FEATURE TEST RESULTS
    echo =============================================
    echo.
)

echo Running the compiled launcher with the isolated test INI...
echo.
"%EXE%" "--x-launcher-config=%INI%"
set "LAUNCH_RC=!ERRORLEVEL!"

if exist "%ROOT_DEBUG_LOG%" move /y "%ROOT_DEBUG_LOG%" "%DEBUG_LOG%" >nul
if exist "%ROOT_SETTINGS_LOG%" move /y "%ROOT_SETTINGS_LOG%" "%SETTINGS_LOG%" >nul

if "!LAUNCH_RC!"=="0" (
    call :RECORD PASS "Launcher process exit code"
) else (
    call :RECORD FAIL "Launcher process exit code was !LAUNCH_RC!"
)

call :CHECK_FILE "Payload completed normally" "%WORK%\Payload_PASS.txt"
call :CHECK_FILE "RunBefore completed before payload" "%WORK%\RunBefore_PASS.txt"
call :CHECK_FILE "RunAfter completed after payload" "%WORK%\RunAfter_PASS.txt"
call :CHECK_FILE "Functions created the expected file" "%WORK%\Created\created.txt"
call :CHECK_FILE "WriteToIni created its output" "%WORK%\Generated.ini"
call :CHECK_NOT_EXISTS "Missing source was not fabricated" "%WORK%\Created\missing.file"
call :CHECK_NOT_EXISTS "Temp cleanup removed the isolated Temp" "%WORK%\Temp"
call :CHECK_FILE "Debug log was generated" "%DEBUG_LOG%"

call :CHECK_TEXT "Session-start record" "[SESSION START]" "%DEBUG_LOG%"
call :CHECK_TEXT "Session metadata record" "[INFO] [Session]" "%DEBUG_LOG%"
call :CHECK_TEXT "Environment PASS record" "[PASS] [Environment] XL_DEBUG_FEATURE=ready" "%DEBUG_LOG%"
call :CHECK_TEXT "Blank PATH SKIP record" "[SKIP] [Environment] PATH=" "%DEBUG_LOG%"
call :CHECK_TEXT "DirCreate PASS record" "[PASS] [Functions] DirCreate=" "%DEBUG_LOG%"
call :CHECK_TEXT "FileCreate PASS record" "[PASS] [Functions] FileCreate=" "%DEBUG_LOG%"
call :CHECK_TEXT "Intentional FileCopy FAIL record" "[FAIL] [Functions] FileCopy=" "%DEBUG_LOG%"
call :CHECK_TEXT "Unknown-operation WARN record" "[WARN] [Functions] Unknown operation=UnknownOperation" "%DEBUG_LOG%"
call :CHECK_TEXT "Legitimate no-change SKIP record" "[SKIP] [Sections] StringReplace=" "%DEBUG_LOG%"
call :CHECK_TEXT "WriteToIni PASS record" "[PASS] [Sections] WriteToIni=" "%DEBUG_LOG%"
call :CHECK_TEXT "RunBefore PASS record" "[PASS] [RunBefore] RunFile=" "%DEBUG_LOG%"
call :CHECK_TEXT "Application-launch PASS record" "[PASS] [FileToRun] Launch=" "%DEBUG_LOG%"
call :CHECK_TEXT "Waited application exit code" "mode=RunWait; exitcode=0" "%DEBUG_LOG%"
call :CHECK_TEXT "RunAfter PASS record" "[PASS] [RunAfter] RunFile=" "%DEBUG_LOG%"
call :CHECK_TEXT "Temp-cleanup PASS record" "[PASS] [Cleanup] Temp=" "%DEBUG_LOG%"
call :CHECK_TEXT "Summary record" "[SUMMARY]" "%DEBUG_LOG%"
call :CHECK_TEXT "Summary contains one intentional failure" "fail=1" "%DEBUG_LOG%"
call :CHECK_TEXT "Summary contains one intentional warning" "warn=1" "%DEBUG_LOG%"
call :CHECK_TEXT "Session-end record" "[SESSION END]" "%DEBUG_LOG%"

>>"%RESULTS%" echo.
>>"%RESULTS%" echo Passed: !PASS_COUNT!
>>"%RESULTS%" echo Failed: !FAIL_COUNT!

echo.
echo ------------------------------------------------------------
echo Passed: !PASS_COUNT!
echo Failed: !FAIL_COUNT!
echo ------------------------------------------------------------
echo.

if not "!FAIL_COUNT!"=="0" (
    echo DEBUG FEATURE TEST: FAIL
    >>"%RESULTS%" echo.
    >>"%RESULTS%" echo Overall: FAIL
    echo.
    echo Please provide Debug_Feature_Test_Results.txt and
    echo Debug_Feature_Test.dbg from Debug_Feature_Test_Kit.
    goto FINISH_FAIL
)

echo DEBUG FEATURE TEST: PASS
>>"%RESULTS%" echo.
>>"%RESULTS%" echo Overall: PASS
echo.
echo Please provide Debug_Feature_Test.dbg from Debug_Feature_Test_Kit.
echo.
pause
exit /b 0

:CHECK_FILE
if exist "%~2" (
    call :RECORD PASS "%~1"
) else (
    call :RECORD FAIL "%~1"
)
exit /b 0

:CHECK_NOT_EXISTS
if not exist "%~2" (
    call :RECORD PASS "%~1"
) else (
    call :RECORD FAIL "%~1"
)
exit /b 0

:CHECK_TEXT
findstr /l /c:"%~2" "%~3" >nul 2>&1
if not errorlevel 1 (
    call :RECORD PASS "%~1"
) else (
    call :RECORD FAIL "%~1"
)
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
echo DEBUG FEATURE TEST: NOT RUN
echo.
pause
exit /b 1

:FINISH_FAIL
echo.
pause
exit /b 1
