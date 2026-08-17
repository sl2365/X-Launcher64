Local $sSourcePath = @ScriptDir & '\x-udf.au3'
Local $sWork = @ScriptDir & '\Test_Suite\Working\Test41'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sSource = FileRead($sSourcePath)
Local $sCompare = '_VersionCompare($s_JavaWinVer, $s_JavaPackVer) >= 0'

Local $bInclude = StringInStr($sSource, '#Include <Misc.au3>', 1) > 0
_T41WriteResult($sLog, 'Misc version helper included', $bInclude)
If Not $bInclude Then $bAllPass = False

Local $bCompare = StringInStr($sSource, $sCompare, 1) > 0
_T41WriteResult($sLog, 'VersionCompare used for Java versions', $bCompare)
If Not $bCompare Then $bAllPass = False

Local $bDirectRemoved = StringInStr($sSource, 'If $s_JavaWinVer >= $s_JavaPackVer Then', 1) = 0
_T41WriteResult($sLog, 'Direct version operator removed', $bDirectRemoved)
If Not $bDirectRemoved Then $bAllPass = False

Local $sEqualHost = 'If ' & $sCompare & ' Then' & @CRLF & @TAB & @TAB & 'Return SetError($iJavaGetResult, 0, $s_JavaWinPath)'
Local $bEqualHost = StringInStr($sSource, $sEqualHost, 1) > 0
_T41WriteResult($sLog, 'Equal versions still prefer host Java', $bEqualHost)
If Not $bEqualHost Then $bAllPass = False

Local $bPropagation = StringInStr($sSource, 'Return SetError($iJavaGetResult, 0, $s_JavaPackPath)', 1) > 0
_T41WriteResult($sLog, 'Java result propagation retained', $bPropagation)
If Not $bPropagation Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T41WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
