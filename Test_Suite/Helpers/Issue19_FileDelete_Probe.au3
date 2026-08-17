Global $Root = @ScriptDir & '\Test_Suite\Working\Test18\Root'

#include 'x-udf.au3'

Local $sLog = @ScriptDir & '\Test_Suite\Working\Test18\Probe.log'
Local $bAllPass = True
Local $iCallError

DirRemove($Root, 1)
DirCreate($Root)

; Scenario A:
; A successful single-file delete must delete the file and report success.
Local $hSingle = FileOpen($Root & '\SingleSuccess.txt', 2)
If $hSingle <> -1 Then
	FileWriteLine($hSingle, 'DELETE_ME')
	FileClose($hSingle)
EndIf

_FileDelete('.\SingleSuccess.txt')
$iCallError = @error

Local $bSingleDeleted = Not FileExists($Root & '\SingleSuccess.txt')
Local $bSingleStatus = ($iCallError = 0)

_WriteProbeResult($sLog, 'Single file deleted', $bSingleDeleted)
_WriteProbeResult($sLog, 'Successful delete reports success', $bSingleStatus)

If Not $bSingleDeleted Or Not $bSingleStatus Then $bAllPass = False

; Scenario B:
; An early delete failure must not be hidden by a later successful delete.
DirCreate($Root & '\Blocked')

Local $hLater = FileOpen($Root & '\Later.txt', 2)
If $hLater <> -1 Then
	FileWriteLine($hLater, 'DELETE_LATER')
	FileClose($hLater)
EndIf

_FileDelete('.\Blocked;Later.txt')
$iCallError = @error

Local $bFailureRetained = ($iCallError <> 0)
Local $bBlockedPreserved = FileExists($Root & '\Blocked')
Local $bLaterDeleted = Not FileExists($Root & '\Later.txt')

_WriteProbeResult($sLog, 'Earlier delete failure retained', $bFailureRetained)
_WriteProbeResult($sLog, 'Failed target preserved', $bBlockedPreserved)
_WriteProbeResult($sLog, 'Later valid file deleted', $bLaterDeleted)

If Not $bFailureRetained Or Not $bBlockedPreserved Or Not $bLaterDeleted Then $bAllPass = False

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
