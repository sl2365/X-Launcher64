Local $sSourcePath = @ScriptDir & '\x-udf.au3'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test39'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sSource = FileRead($sSourcePath)

Local $bState = StringInStr($sSource, 'Global $bJGCancel = False', 1) > 0
_T39WriteResult($sLog, 'Cancellation state declared', $bState)
If Not $bState Then $bAllPass = False

Local $bSignal = StringInStr($sSource, '$bJGCancel = True', 1) > 0
_T39WriteResult($sLog, 'Tray Exit signals cancellation', $bSignal)
If Not $bSignal Then $bAllPass = False

Local $bJavaStop = StringInStr($sSource, 'If $bJGCancel Then Return _CloseJG(1)', 1) > 0
_T39WriteResult($sLog, 'JavaGet returns on cancellation', $bJavaStop)
If Not $bJavaStop Then $bAllPass = False

Local $bDownloadStop = StringInStr($sSource, 'Return SetError(7, 0, 0)', 1) > 0
_T39WriteResult($sLog, 'Active download stops on cancellation', $bDownloadStop)
If Not $bDownloadStop Then $bAllPass = False

Local $bCleanup = (StringInStr($sSource, '_JavaResume($sJBak)', 1) > 0 And StringInStr($sSource, 'Return _CloseJG(1)', 1) > 0)
_T39WriteResult($sLog, 'Restore and close path retained', $bCleanup)
If Not $bCleanup Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T39WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
