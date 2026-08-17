Local $sSourceFile = @ScriptDir & '\x-udf.au3'
Local $sLog = @ScriptDir & '\Test_Suite\Working\Test27\Probe.log'
Local $sSource = FileRead($sSourceFile)
Local $bAllPass = True

Local $sConversion = "Local $iTrayTipSeconds = Ceiling(Number($TimeOut_SS) / 1000)"
Local $sTrayTipUse = ", $iTrayTipSeconds, 1+16)"
Local $sCallbackUse = 'AdlibRegister("_TrayTipOff", $TimeOut_SS)'

Local $bConverted = (StringInStr($sSource, $sConversion, 1) > 0)
Local $bTrayTipConverted = (StringInStr($sSource, $sTrayTipUse, 1) > 0)
Local $bCallbackMilliseconds = (StringInStr($sSource, $sCallbackUse, 1) > 0)

_WriteProbeResult($sLog, 'Configured milliseconds converted to TrayTip seconds', $bConverted)
_WriteProbeResult($sLog, 'TrayTip uses converted timeout', $bTrayTipConverted)
_WriteProbeResult($sLog, 'Callback retains millisecond timeout', $bCallbackMilliseconds)

If Not $bConverted Or Not $bTrayTipConverted Or Not $bCallbackMilliseconds Then $bAllPass = False

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
