Local $sWork = @ScriptDir & '\Test_Suite\Working\Test51'
Local $sLog = $sWork & '\Probe.log'
Local $sSourcePath = @ScriptDir & '\x-udf.au3'
Local $hSource = FileOpen($sSourcePath, 0)
Local $sSource = ''

DirRemove($sWork, 1)
DirCreate($sWork)

If $hSource <> -1 Then
	$sSource = FileRead($hSource)
	FileClose($hSource)
EndIf

Local $sCompact = StringRegExpReplace($sSource, '\s+', '')
$sCompact = StringReplace($sCompact, ',_', ',')
Local $sAddCall = 'DllCall("user32.dll","lresult","SendMessageTimeoutW","hwnd",$HWND_BROADCAST,"uint",$WM_FONTCHANGE,"wparam",0,"lparam",0,"uint",BitOR($SMTO_ABORTIFHUNG,$SMTO_NOTIMEOUTIFNOTHUNG),"uint",50,"dword_ptr*",0)'
Local $sRemoveCall = 'DllCall("user32.dll","lresult","SendMessageTimeoutW","hwnd",$HWND_BROADCAST,"uint",$WM_FONTCHANGE,"wparam",0,"lparam",0,"uint",BitOR($SMTO_ABORTIFHUNG,$SMTO_NOTIMEOUTIFNOTHUNG),"uint",100,"dword_ptr*",0)'

Local $bSourceRead = ($sSource <> '')
Local $bAddSignature = (StringInStr($sCompact, $sAddCall, 1) > 0)
Local $bRemoveSignature = (StringInStr($sCompact, $sRemoveCall, 1) > 0)
Local $bLegacyAbsent = (StringInStr($sCompact, '"SendMessageTimeout",', 1) = 0)

_WriteProbeResult($sLog, 'x-udf source was readable', $bSourceRead)
_WriteProbeResult($sLog, 'AddFonts uses pointer-sized SendMessageTimeoutW types', $bAddSignature)
_WriteProbeResult($sLog, 'RemoveFonts uses pointer-sized SendMessageTimeoutW types', $bRemoveSignature)
_WriteProbeResult($sLog, 'Legacy non-pointer-sized SendMessageTimeout calls are absent', $bLegacyAbsent)

If $bSourceRead And $bAddSignature And $bRemoveSignature And $bLegacyAbsent Then Exit 0
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
