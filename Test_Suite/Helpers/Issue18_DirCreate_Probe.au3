Global $Root = @ScriptDir & '\Test_Suite\Working\Test17\Root'

#include 'x-udf.au3'

Local $sLog = @ScriptDir & '\Test_Suite\Working\Test17\Probe.log'
Local $bAllPass = True
Local $iCallError

DirRemove($Root, 1)
DirCreate($Root)

; Scenario A:
; A successful single-directory request must not report an internal error.
_DirCreate('.\SingleSuccess')
$iCallError = @error

Local $bSingleCreated = FileExists($Root & '\SingleSuccess')
Local $bSingleStatus = ($iCallError = 0)

_WriteProbeResult($sLog, 'Single directory created', $bSingleCreated)
_WriteProbeResult($sLog, 'Successful call reports success', $bSingleStatus)

If Not $bSingleCreated Or Not $bSingleStatus Then $bAllPass = False

; Scenario B:
; An early failure must not be hidden by later successful creates.
Local $hBlocked = FileOpen($Root & '\Blocked', 2)
If $hBlocked <> -1 Then
	FileWriteLine($hBlocked, 'THIS_FILE_BLOCKS_DIRECTORY_CREATION')
	FileClose($hBlocked)
EndIf

_DirCreate('.\Blocked|.\Later\One;Two')
$iCallError = @error

Local $bFailureRetained = ($iCallError <> 0)
Local $bLaterOne = FileExists($Root & '\Later\One')
Local $bLaterTwo = FileExists($Root & '\Later\Two')
Local $bLaterCreated = ($bLaterOne And $bLaterTwo)

_WriteProbeResult($sLog, 'Earlier create failure retained', $bFailureRetained)
_WriteProbeResult($sLog, 'Later valid directories created', $bLaterCreated)

If Not $bFailureRetained Or Not $bLaterCreated Then $bAllPass = False

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
