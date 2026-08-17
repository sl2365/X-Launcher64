AutoItSetOption('ExpandEnvStrings', 1)
AutoItSetOption('ExpandVarStrings', 1)

Global $Root = @ScriptDir & '\Test_Suite\Working\Test48\Root'
Global $Lib = $Root & '\Lib'
Global $ScriptIni = @ScriptDir & '\Test_Suite\Working\Test48\Trace.ini'
Global $ScriptName = 'TraceFixture'
Global $Lang = 'en'
Global $AppName = 'Trace Fixture'
Global $AppVer = '1.0'
Global $PathToExe = $Root & '\Payload.bat'
Global $TraceActive = True, $TraceFinalized = False
Global $TraceSessionDir = @ScriptDir & '\Test_Suite\Working\Test48\Session'
Global $TraceSummaryPath = $TraceSessionDir & '\Application_Trace_Summary.txt'
Global $TraceSettingsPath = $TraceSessionDir & '\X-Launcher_Settings.log'
Global $TraceStartTime = '2026-08-11 10:00:00.000'
Global $TraceProcMonPath = '', $TraceProcMonState = 'not available; continued with X-Launcher-only logging'
Global $TraceProcMonCapturePath = $TraceSessionDir & '\Application_Trace.pml', $TraceProcMonPID = 0
Global $TraceProcMonCSVPath = $TraceSessionDir & '\Application_Trace.csv'
Global $TracePortabilityReportPath = $TraceSessionDir & '\Application_Portability_Report.txt'
Global $TracePortabilityState = 'not attempted'
Global $TraceProcMonCaptureActive = False, $TraceProcMonCaptureSaved = False
Global $TraceProcMonMaxMB = 512, $TraceProcMonReserveMB = 1024
Global $TraceProcMonCaptureBytes = 0, $TraceProcMonCaptureTimer = 0
Global $TraceProcMonCaptureDurationMs = 0, $TraceProcMonFreeStartMB = -1
Global $TraceProcMonCapturePartial = False, $TraceProcMonPartialReason = ''
Global $TraceProcMonLimitStopAttempted = False, $TraceProcMonSpaceCheckWarned = False
Global $TraceApplicationPID = 1234, $TraceApplicationExitCode = 0
Global $TraceObservedPIDs = '|2345|'
Global $TraceObservedProcesses = 'PID: 2345; Parent PID: 1234; Name: child.exe; Command line: child.exe --fixture' & @CRLF
Global $TraceProcessObservation = 'available'
Global $TraceWMI = 0, $TraceCOMErrorObject = 0, $TraceCOMError = False
Global $Debug = 'true', $DebugFile = $TraceSessionDir & '\X-Launcher_Debug.dbg'
Global $DebugSessionID = 'fixture-session', $DebugSessionStarted = True, $DebugSessionEnded = True
Global $DebugPassCount = 4, $DebugFailCount = 0, $DebugWarnCount = 1, $DebugSkipCount = 0, $DebugNotUsedCount = 2
Global $WriteLog = 'true', $ExitHandlerRegistered = False
Global $RegView = 'Native', $Temp = $Root & '\Temp', $Bin = $Root & '\Bin'
Global $Home = $Root & '\Home', $Java = 'false'

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test48'
Local $sLog = $sWork & '\Helper.log'
Local $bAllPass = True
DirCreate($TraceSessionDir)
DirCreate($Root)
FileWrite($PathToExe, '@echo off' & @CRLF & 'exit /b 0' & @CRLF)

Local $hDebug = FileOpen($DebugFile, 2 + 128)
If $hDebug <> -1 Then
	FileWrite($hDebug, '[2026-08-11 10:00:00] [PASS] [RunBefore] FileCopy=' & $Root & '\A|B (result=1)' & @CRLF & _
			'[2026-08-11 10:00:00] [PASS] [Functions] DirCreate=' & $Root & '\Created (result=1)' & @CRLF & _
			'[2026-08-11 10:00:01] [PASS] [RunBefore] Regedit=' & $Root & '\Portable.reg (result=1)' & @CRLF & _
			'[2026-08-11 10:00:02] [PASS] [Process] Application launch PID=1234' & @CRLF & _
			'[2026-08-11 10:00:03] [WARN] [RunAfter] Fixture warning' & @CRLF & _
			'[2026-08-11 10:00:04] [SUMMARY] fixture ordered detail' & @CRLF)
	FileClose($hDebug)
EndIf

Local $sFileCategory = _TraceSelectDebugLines(FileRead($DebugFile), 'file')
Local $bFileCategory = (StringInStr($sFileCategory, '] DirCreate=', 1) > 0 And _
		StringInStr($sFileCategory, '] FileCopy=', 1) > 0)
_T48WriteResult($sLog, 'Trace file category includes directory creation and file operations', $bFileCategory)
If Not $bFileCategory Then $bAllPass = False

Local $bReportCreated = _TraceFinalize(False)
Local $sReport = FileRead($TraceSummaryPath)
Local $bReportContract = ($bReportCreated And _
		StringInStr($sReport, 'X-LAUNCHER APPLICATION TRACE', 1) > 0 And _
		StringInStr($sReport, 'Mode: X-Launcher-only Application Trace (Process Monitor was not started)', 1) > 0 And _
		StringInStr($sReport, 'Capture safeguards: maximum 512 MiB; reserved free space 1024 MiB', 1) > 0 And _
		StringInStr($sReport, '[NOT USED] Native Process Monitor capture was not available.', 1) > 0 And _
		StringInStr($sReport, '[NOT USED] Capture result: no native PML was saved.', 1) > 0 And _
		StringInStr($sReport, 'FILE AND DIRECTORY OPERATIONS (X-LAUNCHER-RECORDED)', 1) > 0 And _
		StringInStr($sReport, 'REGISTRY OPERATIONS (X-LAUNCHER-RECORDED)', 1) > 0 And _
		StringInStr($sReport, 'PROCESS ACTIVITY', 1) > 0 And _
		StringInStr($sReport, 'ERRORS AND WARNINGS', 1) > 0 And _
		StringInStr($sReport, 'ROOT BOUNDARY AND RESIDUE', 1) > 0 And _
		StringInStr($sReport, 'Inside Root:', 1) > 0 And _
		StringInStr($sReport, '[NOT USED] Outside Root:', 1) > 0 And _
		StringInStr($sReport, '[NOT USED] File residue:', 1) > 0 And _
		StringInStr($sReport, '[NOT USED] Registry residue:', 1) > 0 And _
		StringInStr($sReport, 'PASS: 4', 1) > 0 And _
		StringInStr($sReport, 'WARN: 1', 1) > 0 And _
		StringInStr($sReport, 'OVERALL: PASS WITH WARNINGS', 1) > 0 And _
		StringInStr($sReport, 'Privacy: Review usernames, paths, command lines and document names before sharing.', 1) > 0 And _
		StringInStr($sReport, 'ORDERED DIAGNOSTIC DETAIL', 1) > 0)
_T48WriteResult($sLog, 'Trace summary contains required metadata categories totals privacy and ordered detail', $bReportContract)
If Not $bReportContract Then $bAllPass = False

Local $bProcessContract = (StringInStr($sReport, 'Launcher PID:', 1) > 0 And _
		StringInStr($sReport, 'Application launch PID: 1234', 1) > 0 And _
		StringInStr($sReport, 'PID: 2345; Parent PID: 1234; Name: child.exe', 1) > 0 And _
		StringInStr($sReport, 'Application exit code: 0', 1) > 0)
_T48WriteResult($sLog, 'Trace summary records launcher application and observed child process details', $bProcessContract)
If Not $bProcessContract Then $bAllPass = False

Local $sReportBeforeSecondFinalize = $sReport
FileWrite($DebugFile, '[2026-08-11 10:00:05] SHOULD_NOT_OVERWRITE_REPORT' & @CRLF)
_TraceFinalize(False)
Local $bFinalizeGuard = FileRead($TraceSummaryPath) = $sReportBeforeSecondFinalize
_T48WriteResult($sLog, 'Trace finalization guard prevents report overwrite', $bFinalizeGuard)
If Not $bFinalizeGuard Then $bAllPass = False

Local $vRealExitCode = _TraceRunAndWait(_CommandLineQuoteArgument(@ComSpec) & _
		' /d /s /c "ping.exe 127.0.0.1 -n 2 >nul & exit /b 0"', @SW_HIDE)
Local $iRealExitError = @error
Local $sRealExitDebug = FileRead($DebugFile)
Local $bRealExitCode = ($iRealExitError = 0 And $vRealExitCode = 0 And _
		$TraceApplicationExitCode = 0 And _
		StringInStr($sRealExitDebug, 'exit code was unavailable', 1) = 0)
_T48WriteResult($sLog, 'Trace retained process handle records the real application exit code', $bRealExitCode)
If Not $bRealExitCode Then $bAllPass = False

Local $sLauncherSource = FileRead(@ScriptDir & '\x-launcher.au3')
Local $sUdfSource = FileRead(@ScriptDir & '\x-udf.au3')
Local $iTraceCase = StringInStr($sLauncherSource, "Case 'trace'", 1)
Local $iFullCase = StringInStr($sLauncherSource, "Case 'full'", 1, 1, $iTraceCase + 1)
Local $sTraceRoute = ''
If $iTraceCase > 0 And $iFullCase > $iTraceCase Then
	$sTraceRoute = StringMid($sLauncherSource, $iTraceCase, $iFullCase - $iTraceCase)
EndIf
Local $bRealTraceRoute = ($sTraceRoute <> '' And _
		StringInStr($sTraceRoute, '_TestRunConfirm(', 1) > 0 And _
		StringInStr($sTraceRoute, '_TracePrepare(', 1) > 0 And _
		StringInStr($sTraceRoute, 'not implemented yet', 1) = 0)
_T48WriteResult($sLog, 'Confirmed Trace route continues into the real launcher lifecycle', $bRealTraceRoute)
If Not $bRealTraceRoute Then $bAllPass = False

Local $iPrepareStart = StringInStr($sUdfSource, 'Func _TracePrepare(', 1)
Local $iPrepareEnd = StringInStr($sUdfSource, 'EndFunc   ;==>_TracePrepare', 1, 1, $iPrepareStart)
Local $sPrepareSource = ''
If $iPrepareStart > 0 And $iPrepareEnd > $iPrepareStart Then
	$sPrepareSource = StringMid($sUdfSource, $iPrepareStart, $iPrepareEnd - $iPrepareStart)
EndIf

Local $iProcMonStart = StringInStr($sUdfSource, 'Func _TraceStartProcMonCapture(', 1)
Local $iProcMonStartEnd = StringInStr($sUdfSource, 'EndFunc   ;==>_TraceStartProcMonCapture', 1, 1, $iProcMonStart)
Local $iProcMonStop = StringInStr($sUdfSource, 'Func _TraceStopProcMonCapture(', 1)
Local $iProcMonStopEnd = StringInStr($sUdfSource, 'EndFunc   ;==>_TraceStopProcMonCapture', 1, 1, $iProcMonStop)
Local $sProcMonStartSource = '', $sProcMonStopSource = '', $sProcMonControlSource = ''
If $iProcMonStart > 0 And $iProcMonStartEnd > $iProcMonStart And _
		$iProcMonStop > 0 And $iProcMonStopEnd > $iProcMonStop Then
	$sProcMonStartSource = StringMid($sUdfSource, $iProcMonStart, _
			$iProcMonStartEnd - $iProcMonStart)
	$sProcMonStopSource = StringMid($sUdfSource, $iProcMonStop, _
			$iProcMonStopEnd - $iProcMonStop)
	$sProcMonControlSource = $sProcMonStartSource & $sProcMonStopSource
EndIf
Local $bSafeProcMonControl = ($sProcMonControlSource <> '' And _
		StringInStr($sProcMonControlSource, 'ShellExecute', 1) > 0 And _
		StringInStr($sProcMonControlSource, '_TraceProcMonAnyRunning()', 1) > 0 And _
		StringInStr($sProcMonControlSource, '/AcceptEula', 1) = 0 And _
		StringInStr($sProcMonControlSource, 'InetGet', 1) = 0 And _
		StringInStr($sProcMonControlSource, 'RegWrite', 1) = 0)
_T48WriteResult($sLog, 'Application Trace never downloads Process Monitor or accepts its EULA automatically', $bSafeProcMonControl)
If Not $bSafeProcMonControl Then $bAllPass = False

Local $bProcMonElevation = (StringInStr($sProcMonStartSource, "'runas'", 1) > 0 And _
		StringInStr($sProcMonStopSource, "'runas'", 1) > 0)
_T48WriteResult($sLog, 'Process Monitor capture start and stop explicitly request Windows elevation', $bProcMonElevation)
If Not $bProcMonElevation Then $bAllPass = False

Local $sStartArguments = _TraceProcMonStartArguments('C:\Trace Folder\Application_Trace.pml')
Local $sStopArguments = _TraceProcMonStopArguments()
Local $bProcMonCommands = ($sStartArguments == '/Quiet /Minimized /BackingFile "C:\Trace Folder\Application_Trace.pml"' And _
		$sStopArguments == '/Terminate /Quiet')
_T48WriteResult($sLog, 'Process Monitor capture uses verified backing-file and terminate switches', $bProcMonCommands)
If Not $bProcMonCommands Then $bAllPass = False

Local $bProcMonPromptWait = (StringInStr($sProcMonControlSource, _
		'Until TimerDiff($hReadyTimer) >= 60000', 1) > 0 And _
		StringInStr($sProcMonControlSource, _
		'And Not _TraceProcMonAnyRunning() Then ExitLoop', 1) = 0)
_T48WriteResult($sLog, 'Process Monitor startup preserves the full elevation and licence prompt allowance', $bProcMonPromptWait)
If Not $bProcMonPromptWait Then $bAllPass = False

Local $bProcMonLimits = (_TraceProcMonPreflightReason(1536, 512, 1024) = '' And _
		_TraceProcMonPreflightReason(1535, 512, 1024) <> '' And _
		_TraceProcMonLimitReason(64 * 1024 * 1024, 4096, 64, 256) == _
		'maximum PML size of 64 MB reached' And _
		_TraceProcMonLimitReason(1, 255, 64, 256) == _
		'reserved free-space minimum of 256 MB reached')
_T48WriteResult($sLog, 'Process Monitor storage safeguards enforce maximum size and reserved free space', $bProcMonLimits)
If Not $bProcMonLimits Then $bAllPass = False

Local $iFinalizeStart = StringInStr($sUdfSource, 'Func _TraceFinalize(', 1)
Local $iFinalizeEnd = StringInStr($sUdfSource, 'EndFunc   ;==>_TraceFinalize', 1, 1, $iFinalizeStart)
Local $sFinalizeSource = ''
If $iFinalizeStart > 0 And $iFinalizeEnd > $iFinalizeStart Then
	$sFinalizeSource = StringMid($sUdfSource, $iFinalizeStart, $iFinalizeEnd - $iFinalizeStart)
EndIf
Local $iStopInFinalize = StringInStr($sFinalizeSource, '_TraceStopProcMonCapture()', 1)
Local $iDebugEndInFinalize = StringInStr($sFinalizeSource, "_DebugSessionEnd('trace-finalize')", 1)
Local $bProcMonStopOrder = ($iStopInFinalize > 0 And $iDebugEndInFinalize > $iStopInFinalize And _
		StringInStr($sFinalizeSource, 'Application_Trace.pml', 1) > 0)
_T48WriteResult($sLog, 'Trace finalization stops Process Monitor after cleanup and preserves the native PML path', $bProcMonStopOrder)
If Not $bProcMonStopOrder Then $bAllPass = False

Local $iCloseStart = StringInStr($sLauncherSource, 'Func _XClose(', 1)
Local $iCloseEnd = StringInStr($sLauncherSource, 'EndFunc   ;==>_XClose', 1, 1, $iCloseStart)
Local $sCloseSource = ''
If $iCloseStart > 0 And $iCloseEnd > $iCloseStart Then
	$sCloseSource = StringMid($sLauncherSource, $iCloseStart, $iCloseEnd - $iCloseStart)
EndIf
Local $iTraceFinalizeInClose = StringInStr($sCloseSource, '_TraceFinalize($bInteractiveTraceReport)', 1)
Local $iNormalEndInClose = StringInStr($sCloseSource, "_DebugSessionEnd('normal-close')", 1)
Local $iExitStart = StringInStr($sLauncherSource, 'Func OnAutoItExit()', 1)
Local $iExitEnd = StringInStr($sLauncherSource, 'EndFunc   ;==>OnAutoItExit', 1, 1, $iExitStart)
Local $sExitSource = ''
If $iExitStart > 0 And $iExitEnd > $iExitStart Then
	$sExitSource = StringMid($sLauncherSource, $iExitStart, $iExitEnd - $iExitStart)
EndIf
Local $iTraceFinalizeInExit = StringInStr($sExitSource, '_TraceFinalize(False)', 1)
Local $iDebugEndInExit = StringInStr($sExitSource, "_DebugSessionEnd('exit-method='", 1)
Local $bSessionEndOrder = ($iTraceFinalizeInClose > 0 And $iNormalEndInClose > $iTraceFinalizeInClose And _
		$iTraceFinalizeInExit > 0 And $iDebugEndInExit > $iTraceFinalizeInExit)
_T48WriteResult($sLog, 'Trace session end is recorded after native Process Monitor finalization', $bSessionEndOrder)
If Not $bSessionEndOrder Then $bAllPass = False

Local $bMissingChoice = (StringInStr($sUdfSource, 'Click OK to continue with X-Launcher-only logging.', 1) > 0 And _
		StringInStr($sUdfSource, 'Click Cancel to stop without launching the application.', 1) > 0)
_T48WriteResult($sLog, 'Missing Process Monitor offers X-Launcher-only logging or Cancel', $bMissingChoice)
If Not $bMissingChoice Then $bAllPass = False

Local $bUniqueSession = (StringInStr($sPrepareSource, 'While FileExists($sCandidate)', 1) > 0 And _
		StringInStr($sPrepareSource, "$sCandidate = $sSessionBase & '-' & $iSuffix", 1) > 0 And _
		StringInStr($sPrepareSource, "'\Diagnostics\'", 1) > 0)
_T48WriteResult($sLog, 'Trace creates a unique application diagnostics session folder', $bUniqueSession)
If Not $bUniqueSession Then $bAllPass = False

Local $iRunStart = StringInStr($sUdfSource, 'Func _TraceRunAndWait(', 1)
Local $iRunEnd = StringInStr($sUdfSource, 'EndFunc   ;==>_TraceRunAndWait', 1, 1, $iRunStart)
Local $sRunSource = ''
If $iRunStart > 0 And $iRunEnd > $iRunStart Then
	$sRunSource = StringMid($sUdfSource, $iRunStart, $iRunEnd - $iRunStart)
EndIf
Local $bPIDWait = ($sRunSource <> '' And _
		StringInStr($sRunSource, 'Run(', 1) > 0 And _
		StringInStr($sRunSource, '_TraceCheckProcMonCaptureLimits()', 1) > 0 And _
		StringInStr($sRunSource, '$TraceApplicationPID = $iPID', 1) > 0 And _
		StringInStr($sRunSource, "'OpenProcess'", 1) > 0 And _
		StringInStr($sRunSource, "'WaitForSingleObject'", 1) > 0 And _
		StringInStr($sRunSource, "'GetExitCodeProcess'", 1) > 0 And _
		StringInStr($sRunSource, "'CloseHandle'", 1) > 0)
_T48WriteResult($sLog, 'Trace records application PID while retaining waited completion', $bPIDWait)
If Not $bPIDWait Then $bAllPass = False

Local $iForwardStart = StringInStr($sLauncherSource, '; CommandLine', 1)
Local $iForwardEnd = StringInStr($sLauncherSource, '; ChangeDir', 1, 1, $iForwardStart)
Local $sForwardSource = ''
If $iForwardStart > 0 And $iForwardEnd > $iForwardStart Then
	$sForwardSource = StringMid($sLauncherSource, $iForwardStart, _
			$iForwardEnd - $iForwardStart)
EndIf
Local $bInternalArguments = ($sForwardSource <> '' And _
		StringInStr($sForwardSource, "$sForwardArgument = '--x-launcher-test'", 1) > 0 And _
		StringInStr($sForwardSource, "StringLeft($sForwardArgument, 18) = '--x-launcher-test='", 1) > 0 And _
		StringInStr($sForwardSource, "$sForwardArgument = '--x-launcher-test-automated'", 1) > 0 And _
		StringInStr($sForwardSource, "StringLen('--x-launcher-selftest-helper=')", 1) > 0 And _
		StringInStr($sForwardSource, "'--x-launcher-selftest-helper=' Then ContinueLoop", 1) > 0)
_T48WriteResult($sLog, 'Internal diagnostic switches are not forwarded to the configured payload', $bInternalArguments)
If Not $bInternalArguments Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T48WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
