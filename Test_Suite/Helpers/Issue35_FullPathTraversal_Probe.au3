Global $Root = @ScriptDir

#include 'x-udf.au3'

If $CmdLine[0] > 0 Then
	If $CmdLine[1] = '--excessive-child' Then
		_T36RunExcessiveChild()
		Exit 0
	EndIf
EndIf

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test36'
Local $sLog = $sWork & '\Probe.log'
Local $sChildMarker = $sWork & '\ChildReached.txt'
Local $sChildOutcome = $sWork & '\ChildOutcome.txt'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sValid = _FullPath('..\Target', 'C:\Base\Child')
Local $iValidError = @error
Local $bValid = ($iValidError = 0 And $sValid = 'C:\Base\Target')
_T36WriteResult($sLog, 'Valid parent path normalized', $bValid)
If Not $bValid Then $bAllPass = False

Local $sCommand = '"' & @AutoItExe & '" /ErrorStdOut "' & @ScriptFullPath & '" --excessive-child'
Local $iChildExit = RunWait($sCommand, @ScriptDir, @SW_HIDE)

Local $bFailure = (FileRead($sChildOutcome) = 'PASS')
_T36WriteResult($sLog, 'Excessive traversal returns failure', $bFailure)
If Not $bFailure Then $bAllPass = False

Local $bSurvives = ($iChildExit = 0 And FileRead($sChildMarker) = 'reached')
_T36WriteResult($sLog, 'Child survives path error', $bSurvives)
If Not $bSurvives Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T36RunExcessiveChild()
	Local $sChildWork = @ScriptDir & '\Test_Suite\Working\Test36'
	Local $sResult = _FullPath('..\..\..\Target', 'C:\Base')
	Local $iError = @error
	Local $sOutcome = 'FAIL'
	If $iError <> 0 And $sResult = '' Then $sOutcome = 'PASS'
	FileWrite($sChildWork & '\ChildOutcome.txt', $sOutcome)
	FileWrite($sChildWork & '\ChildReached.txt', 'reached')
EndFunc

Func _T36WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
