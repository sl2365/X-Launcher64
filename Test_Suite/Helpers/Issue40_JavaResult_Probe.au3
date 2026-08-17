Local $sUdfPath = @ScriptDir & '\x-udf.au3'
Local $sLauncherPath = @ScriptDir & '\x-launcher.au3'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test40'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sUdf = FileRead($sUdfPath)
Local $sLauncher = FileRead($sLauncherPath)

Local $bCaptured = (StringInStr($sUdf, 'Local $iJavaGetResult = 0', 1) > 0 And StringInStr($sUdf, '$iJavaGetResult = _JavaGet(', 1) > 0)
_T40WriteResult($sLog, 'JavaGet result captured', $bCaptured)
If Not $bCaptured Then $bAllPass = False

Local $bPropagated = StringInStr($sUdf, 'Return SetError($iJavaGetResult, 0, $s_JavaPackPath)', 1) > 0
_T40WriteResult($sLog, 'Nonzero result propagated', $bPropagated)
If Not $bPropagated Then $bAllPass = False

Local $bLauncherCapture = StringInStr($sLauncher, 'Local $iJavaCheckError = @error', 1) > 0
_T40WriteResult($sLog, 'Launcher captures Java error', $bLauncherCapture)
If Not $bLauncherCapture Then $bAllPass = False

Local $bRequiredStop = (StringInStr($sLauncher, 'If $iJavaCheckError <> 0 Then', 1) > 0 And _
		StringInStr($sLauncher, "IniRead($ScriptIni, 'Options', 'Java', 'false') = 'true'", 1) > 0 And _
		StringInStr($sLauncher, 'Exit(8)', 1) > 0)
_T40WriteResult($sLog, 'Required Java failure stops launch', $bRequiredStop)
If Not $bRequiredStop Then $bAllPass = False

Local $bOptional = (StringInStr($sUdf, "$JavaNeeded = 'optional'", 1) > 0 And _
		StringInStr($sUdf, "IniWrite($ScriptIni, 'Options', 'Java', 'false')", 1) > 0)
_T40WriteResult($sLog, 'Optional Java fallback retained', $bOptional)
If Not $bOptional Then $bAllPass = False

Local $bPath = StringInStr($sLauncher, '$Java = _JavaCheck(', 1) > 0
_T40WriteResult($sLog, 'Java path assignment retained', $bPath)
If Not $bPath Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T40WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
