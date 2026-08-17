@echo off
setlocal EnableExtensions
for %%I in ("%~dp0Debug_Feature_Test_Work") do set "WORK=%%~fI"

if not exist "%WORK%\RunBefore_PASS.txt" goto BEFORE_FAILED
if /i not "%XL_DEBUG_FEATURE%"=="ready" goto ENVIRONMENT_FAILED
if /i not "%XL_DEBUG_FEATURE_PATH%"=="%WORK%" goto ENVIRONMENT_PATH_FAILED
if /i not "%CD%"=="%WORK%" goto WORKING_DIRECTORY_FAILED
if not exist "%WORK%\Created\created.txt" goto FUNCTION_FAILED

>"%WORK%\Payload_PASS.txt" echo Payload, environment, working directory and Functions checks passed.
exit /b 0

:BEFORE_FAILED
>"%WORK%\Payload_FAIL.txt" echo RunBefore marker was missing.
exit /b 11

:ENVIRONMENT_FAILED
>"%WORK%\Payload_FAIL.txt" echo XL_DEBUG_FEATURE was not set correctly.
exit /b 12

:ENVIRONMENT_PATH_FAILED
>"%WORK%\Payload_FAIL.txt" echo XL_DEBUG_FEATURE_PATH did not resolve correctly.
exit /b 13

:WORKING_DIRECTORY_FAILED
>"%WORK%\Payload_FAIL.txt" echo WorkingDir was not applied correctly.
exit /b 14

:FUNCTION_FAILED
>"%WORK%\Payload_FAIL.txt" echo The expected FileCreate result was missing.
exit /b 15
