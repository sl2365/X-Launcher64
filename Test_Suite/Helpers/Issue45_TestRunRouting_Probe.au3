Local $sLauncher = FileRead(@ScriptDir & '\x-launcher.au3')
Local $sUdf = FileRead(@ScriptDir & '\x-udf.au3')
Local $sTemplate = @ScriptDir & '\x-launcher.ini'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test45'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirCreate($sWork)

Local $bTemplate = IniRead($sTemplate, 'Options', 'TestRun', '__missing__') = 'false'
_T45WriteResult($sLog, 'Template documents TestRun false', $bTemplate)
If Not $bTemplate Then $bAllPass = False

Local $bMissingDefault = StringInStr($sLauncher, "IniRead($ScriptIni, 'Options', 'TestRun', 'false')", 1) > 0
_T45WriteResult($sLog, 'Missing TestRun defaults to false', $bMissingDefault)
If Not $bMissingDefault Then $bAllPass = False

Local $bBlankDefault = StringInStr($sLauncher, "If $TestRun = '' Then $TestRun = 'false'", 1) > 0
_T45WriteResult($sLog, 'Blank TestRun falls back to false', $bBlankDefault)
If Not $bBlankDefault Then $bAllPass = False

Local $bCaseInsensitive = (StringInStr($sLauncher, '$TestRun = StringLower(StringStripWS(', 1) > 0 And _
		StringInStr($sLauncher, "Case 'probe'", 1) > 0 And _
		StringInStr($sLauncher, "Case 'trace'", 1) > 0 And _
		StringInStr($sLauncher, "Case 'full'", 1) > 0)
_T45WriteResult($sLog, 'Valid TestRun modes are case insensitive', $bCaseInsensitive)
If Not $bCaseInsensitive Then $bAllPass = False

Local $bInvalidStop = (StringInStr($sLauncher, 'Invalid TestRun value:', 1) > 0 And _
		StringInStr($sLauncher, "_DebugSessionEnd('invalid-test-run')", 1) > 0 And _
		StringInStr($sLauncher, 'Exit(9)', 1) > 0)
_T45WriteResult($sLog, 'Invalid INI value stops safely', $bInvalidStop)
If Not $bInvalidStop Then $bAllPass = False

Local $bDirectModes = (StringInStr($sLauncher, "Case $sTestArgument = '--x-launcher-test'", 1) > 0 And _
		StringInStr($sLauncher, "'--x-launcher-test='", 1) > 0 And _
		StringInStr($sLauncher, "$TestRun <> 'probe' And $TestRun <> 'trace' And $TestRun <> 'full'", 1) > 0)
_T45WriteResult($sLog, 'Direct command line modes are recognized', $bDirectModes)
If Not $bDirectModes Then $bAllPass = False

Local $iCommandBranch = StringInStr($sLauncher, 'If $TestRunCommandLineCount = 1 Then', 1)
Local $iIniRead = StringInStr($sLauncher, "IniRead($ScriptIni, 'Options', 'TestRun', 'false')", 1)
Local $iRegistryRecovery = StringInStr($sLauncher, '_RegRecoverPending(', 1)
Local $bOverride = ($iCommandBranch > 0 And $iIniRead > $iCommandBranch And $iRegistryRecovery > $iIniRead)
_T45WriteResult($sLog, 'Command line mode overrides INI', $bOverride)
If Not $bOverride Then $bAllPass = False

Local $bSelector = (StringInStr($sUdf, "Return 'probe'", 1) > 0 And _
		StringInStr($sUdf, "Return 'trace'", 1) > 0 And _
		StringInStr($sUdf, "Return 'full'", 1) > 0 And _
		StringInStr($sUdf, "Return 'cancel'", 1) > 0)
_T45WriteResult($sLog, 'Selection window exposes four outcomes', $bSelector)
If Not $bSelector Then $bAllPass = False

Local $iSelectionCancel = StringInStr($sLauncher, "If $TestRun = 'cancel' Then", 1)
Local $sSelectionCancelBlock = ''
If $iSelectionCancel > 0 Then $sSelectionCancelBlock = StringMid($sLauncher, $iSelectionCancel, 500)
Local $bSelectionCancel = ($iSelectionCancel > 0 And _
		StringInStr($sSelectionCancelBlock, "_DebugSessionEnd('test-run-selection-cancelled')", 1) > 0 And _
		StringInStr($sSelectionCancelBlock, 'Exit', 1) > 0)
_T45WriteResult($sLog, 'Selection cancellation stops launch', $bSelectionCancel)
If Not $bSelectionCancel Then $bAllPass = False

Local $iConfirmationCancel = StringInStr($sLauncher, 'If Not _TestRunConfirm(', 1)
Local $sConfirmationCancelBlock = ''
If $iConfirmationCancel > 0 Then $sConfirmationCancelBlock = StringMid($sLauncher, $iConfirmationCancel, 500)
Local $bConfirmationCancel = ($iConfirmationCancel > 0 And _
		StringInStr($sConfirmationCancelBlock, "_DebugSessionEnd('test-run-confirmation-cancelled')", 1) > 0 And _
		StringInStr($sConfirmationCancelBlock, 'Exit', 1) > 0)
_T45WriteResult($sLog, 'Confirmation cancellation stops launch', $bConfirmationCancel)
If Not $bConfirmationCancel Then $bAllPass = False

Local $iTraceCase = StringInStr($sLauncher, "Case 'trace'", 1)
Local $iFullCase = StringInStr($sLauncher, "Case 'full'", 1, 1, $iTraceCase + 1)
Local $iFullRun = StringInStr($sLauncher, '_FullTestRun(', 1, 1, $iFullCase)
Local $bModeRouting = ($iTraceCase > 0 And $iFullCase > $iTraceCase And _
		$iFullRun > $iFullCase And $iRegistryRecovery > $iFullRun And _
		StringInStr(StringMid($sLauncher, $iTraceCase, $iFullCase - $iTraceCase), _
		'_TracePrepare(', 1) > 0)
_T45WriteResult($sLog, 'Trace routes to preparation and Full routes to isolated self-test', $bModeRouting)
If Not $bModeRouting Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T45WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
