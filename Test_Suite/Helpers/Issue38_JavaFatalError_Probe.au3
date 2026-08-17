Local $sSourcePath = @ScriptDir & '\x-udf.au3'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test38'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sSource = FileRead($sSourcePath)
Local $aErrorMsg = StringRegExp($sSource, '(?is)(Func[ \t]+_Error_Msg[ \t]*\(.*?EndFunc[ \t]*;[ \t]*==>_Error_Msg)', 1)
Local $sErrorMsg = ''
If IsArray($aErrorMsg) Then $sErrorMsg = $aErrorMsg[0]

Local $bHelperReturn = StringRegExp($sErrorMsg, '(?im)^[ \t]*Return[ \t]+_CloseJG\(4\)') = 1
_T38WriteResult($sLog, 'Fatal helper returns close code', $bHelperReturn)
If Not $bHelperReturn Then $bAllPass = False

Local $sReturnCaller = 'If @error Then Return _Error_Msg(1, $iLang)'
Local $sOldCaller = 'If @error Then _Error_Msg(1, $iLang)'
Local $bFourthCaller = StringInStr($sSource, $sReturnCaller, 1, 4) > 0
Local $bFifthCaller = StringInStr($sSource, $sReturnCaller, 1, 5) > 0
Local $bOldCaller = StringInStr($sSource, $sOldCaller, 1) > 0
Local $bCallers = ($bFourthCaller And Not $bFifthCaller And Not $bOldCaller)
_T38WriteResult($sLog, 'All fatal callers return immediately', $bCallers)
If Not $bCallers Then $bAllPass = False

Local $bRestore = StringRegExp($sErrorMsg, '(?im)^[ \t]*_JavaResume\(\$sJBak\)') = 1
_T38WriteResult($sLog, 'Backup restore retained', $bRestore)
If Not $bRestore Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T38WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
