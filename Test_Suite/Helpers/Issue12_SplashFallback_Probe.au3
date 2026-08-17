Global $Root = @ScriptDir & '\Test_Suite\Working\Test22\Root'
Global $tempdir = @ScriptDir & '\Test_Suite\Working\Test22\WrongTemp'

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test22'
Local $sIntendedTemp = $sWork & '\IntendedTemp'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($Root)
DirCreate($tempdir)
DirCreate($sIntendedTemp)

; Use an empty image to exercise the built-in fallback. The controlled global
; $tempdir makes the current defect safe: it cannot write to a drive root.
_SplashScreen('', '', 500, $sIntendedTemp, $Root, '', '')

Local $bSuppliedTempUsed = FileExists($sIntendedTemp & '\x-splash.jpg')
Local $bWrongGlobalUnused = Not FileExists($tempdir & '\x-splash.jpg')

_WriteProbeResult($sLog, 'Fallback stored in supplied Temp', $bSuppliedTempUsed)
_WriteProbeResult($sLog, 'Wrong global temp unused', $bWrongGlobalUnused)

If Not $bSuppliedTempUsed Or Not $bWrongGlobalUnused Then $bAllPass = False

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
