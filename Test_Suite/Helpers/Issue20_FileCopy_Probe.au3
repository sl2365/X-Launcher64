Global $Root = @ScriptDir & '\Test_Suite\Working\Test19\Root'

#include 'x-udf.au3'

Local $sLog = @ScriptDir & '\Test_Suite\Working\Test19\Probe.log'
Local $bAllPass = True
Local $iCallError

DirRemove($Root, 1)
DirCreate($Root & '\Source')
DirCreate($Root & '\Destination')

; Scenario A:
; A successful single-file copy must copy the file and report success.
Local $hSingle = FileOpen($Root & '\Source\SingleSuccess.txt', 2)
If $hSingle <> -1 Then
	FileWriteLine($hSingle, 'COPY_ME')
	FileClose($hSingle)
EndIf

_FileCopy('.\Source\SingleSuccess.txt|.\Destination')
$iCallError = @error

Local $bSingleCopied = FileExists($Root & '\Destination\SingleSuccess.txt')
Local $bSingleStatus = ($iCallError = 0)

_WriteProbeResult($sLog, 'Single file copied', $bSingleCopied)
_WriteProbeResult($sLog, 'Successful copy reports success', $bSingleStatus)

If Not $bSingleCopied Or Not $bSingleStatus Then $bAllPass = False

; Scenario B:
; An early copy failure must not be hidden by a later successful copy.
Local $hLater = FileOpen($Root & '\Source\Later.txt', 2)
If $hLater <> -1 Then
	FileWriteLine($hLater, 'COPY_LATER')
	FileClose($hLater)
EndIf

_FileCopy('.\Source\Missing.txt;Later.txt|.\Destination')
$iCallError = @error

Local $bFailureRetained = ($iCallError <> 0)
Local $bLaterCopied = FileExists($Root & '\Destination\Later.txt')
Local $bMissingAbsent = Not FileExists($Root & '\Destination\Missing.txt')

_WriteProbeResult($sLog, 'Earlier copy failure retained', $bFailureRetained)
_WriteProbeResult($sLog, 'Later valid file copied', $bLaterCopied)
_WriteProbeResult($sLog, 'Missing source not fabricated', $bMissingAbsent)

If Not $bFailureRetained Or Not $bLaterCopied Or Not $bMissingAbsent Then $bAllPass = False

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
