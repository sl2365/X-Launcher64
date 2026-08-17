Local $sUdfPath = @ScriptDir & '\x-udf.au3'
Local $sLauncherPath = @ScriptDir & '\x-launcher.au3'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test42'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sUdf = FileRead($sUdfPath)
Local $sLauncher = FileRead($sLauncherPath)

Local $bUrlRead = StringInStr($sUdf, "IniRead($ScriptIni, 'Options', 'JavaURL', '')", 1) > 0
_T42WriteResult($sLog, 'JavaURL read from application INI', $bUrlRead)
If Not $bUrlRead Then $bAllPass = False

Local $bUrlPassed = StringInStr($sUdf, '$s_JavaWinPath, $sJavaURL)', 1) > 0
_T42WriteResult($sLog, 'Configured URL passed to JavaGet', $bUrlPassed)
If Not $bUrlPassed Then $bAllPass = False

Local $bOldUrlRemoved = StringInStr($sLauncher, 'winpenpack.com/main/request.php?956', 1) = 0
_T42WriteResult($sLog, 'Hidden legacy download URL removed', $bOldUrlRemoved)
If Not $bOldUrlRemoved Then $bAllPass = False

Local $sPriority = 'If FileExists($s_JavaPackPath & "\bin\javaw.exe") Then' & @CRLF & @TAB & @TAB & _
		'Return SetError($iJavaGetResult, 0, $s_JavaPackPath)' & @CRLF & @TAB & 'EndIf'
Local $bPriority = StringInStr($sUdf, $sPriority, 1) > 0
_T42WriteResult($sLog, 'Portable Java takes priority', $bPriority)
If Not $bPriority Then $bAllPass = False

Local $bMissingCode = StringInStr($sUdf, 'If $sJavaURL = "" Then Return _CloseJG(5)', 1) > 0
_T42WriteResult($sLog, 'Missing JavaURL has explicit result', $bMissingCode)
If Not $bMissingCode Then $bAllPass = False

Local $bGuidance = (StringInStr($sLauncher, '$iJavaCheckError = 5', 1) > 0 And _
		StringInStr($sLauncher, 'JavaURL=', 1) > 0 And _
		StringInStr($sLauncher, 'Lib\Java\setup', 1) > 0 And _
		StringInStr($sLauncher, 'MsgBox(', 1) > 0)
_T42WriteResult($sLog, 'Required Java guidance is shown', $bGuidance)
If Not $bGuidance Then $bAllPass = False

Local $bRequired = (StringInStr($sLauncher, "IniRead($ScriptIni, 'Options', 'Java', 'false') = 'true'", 1) > 0 And _
		StringInStr($sLauncher, 'Exit(8)', 1) > 0)
_T42WriteResult($sLog, 'Required Java still stops safely', $bRequired)
If Not $bRequired Then $bAllPass = False

Local $bOptional = (StringInStr($sUdf, "$JavaNeeded = 'optional'", 1) > 0 And _
		StringInStr($sUdf, "IniWrite($ScriptIni, 'Options', 'Java', 'false')", 1) > 0)
_T42WriteResult($sLog, 'Optional Java fallback retained', $bOptional)
If Not $bOptional Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T42WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
