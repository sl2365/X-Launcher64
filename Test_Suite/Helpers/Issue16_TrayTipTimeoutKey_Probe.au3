Local $sSourceFile = @ScriptDir & '\x-launcher.au3'
Local $sLog = @ScriptDir & '\Test_Suite\Working\Test26\Probe.log'
Local $sSource = FileRead($sSourceFile)
Local $bAllPass = True

Local $sStandardRead = "$TimeOut_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'Timeout', '')"
Local $sLegacyFallback = "If $TimeOut_TT = '' Then $TimeOut_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'TimeOut ', '')"

Local $bStandardKey = (StringInStr($sSource, $sStandardRead, 1) > 0)
Local $bLegacyCompatible = (StringInStr($sSource, $sLegacyFallback, 1) > 0)

_WriteProbeResult($sLog, 'Documented Timeout key read first', $bStandardKey)
_WriteProbeResult($sLog, 'Legacy trailing-space key retained as fallback', $bLegacyCompatible)

If Not $bStandardKey Or Not $bLegacyCompatible Then $bAllPass = False

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
