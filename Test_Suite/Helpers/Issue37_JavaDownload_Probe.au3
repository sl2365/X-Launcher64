Local $sSourcePath = @ScriptDir & '\x-udf.au3'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test37'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sSource = FileRead($sSourcePath)
Local $aFunction = StringRegExp($sSource, '(?is)(Func[ \t]+_Download[ \t]*\(.*?EndFunc[ \t]*;[ \t]*==>_Download)', 1)
Local $sFunction = ''
If IsArray($aFunction) Then $sFunction = $aFunction[0]

Local $bWait = StringRegExp($sFunction, '(?im)^[ \t]*While[ \t]+Not[ \t]+InetGetInfo\(\$hDownload,[ \t]*2\)') = 1
_T37WriteResult($sLog, 'Waits until download completion', $bWait)
If Not $bWait Then $bAllPass = False

Local $bStartError = StringRegExp($sFunction, '(?im)^[ \t]*If[ \t]+@error[ \t]+Or[ \t]+\$hDownload[ \t]*=[ \t]*0[ \t]+Then') = 1
_T37WriteResult($sLog, 'Async start failure detected', $bStartError)
If Not $bStartError Then $bAllPass = False

Local $bTransferStatus = StringRegExp($sFunction, 'InetGetInfo\(\$hDownload,[ \t]*3\)') = 1
_T37WriteResult($sLog, 'Transfer success status checked', $bTransferStatus)
If Not $bTransferStatus Then $bAllPass = False

Local $bSize = StringRegExp($sFunction, '(?im)^[ \t]*If[ \t]+\$iBytesRead[ \t]*<>[ \t]*\$iSize[ \t]+Then[ \t]+Return[ \t]+SetError\(') = 1
_T37WriteResult($sLog, 'Downloaded size verified', $bSize)
If Not $bSize Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T37WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
