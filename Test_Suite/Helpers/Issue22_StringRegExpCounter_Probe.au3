Global $Root = @ScriptDir

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test28'
Local $sTarget = $sWork & '\Counter.txt'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $hTarget = FileOpen($sTarget, 2)
If $hTarget <> -1 Then
	FileWrite($hTarget, 'cat cat cat')
	FileClose($hTarget)
EndIf

Local $iChanged = _StringRegExpReplace($sTarget, 'cat~dog', '~|2')
Local $iCallError = @error
Local $sResult = FileRead($sTarget)

Local $bCountLimited = ($sResult = 'dog dog cat')
Local $bCallSucceeded = ($iChanged = 1 And $iCallError = 0)

_WriteProbeResult($sLog, 'Counter limits replacements to configured number', $bCountLimited)
_WriteProbeResult($sLog, 'Limited replacement call reports success', $bCallSucceeded)

If Not $bCountLimited Or Not $bCallSucceeded Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _WriteProbeResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return

	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf

	FileClose($hFile)
EndFunc
