Global $Root = @ScriptDir

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test30'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sStringFile = $sWork & '\StringReplace.txt'
_T30WriteBinary($sStringFile, 'EFBBBF616C7068613D3C6F6C643E0A776F72643D636166C3A90A0A')
_StringReplace($sStringFile, '<', '>', 'new')
Local $bStringReplace = _T30BinaryEquals($sStringFile, 'EFBBBF616C7068613D3C6E65773E0A776F72643D636166C3A90A0A')
_T30WriteResult($sLog, 'StringReplace preserves UTF-8 BOM LF and trailing blank line', $bStringReplace)
If Not $bStringReplace Then $bAllPass = False

Local $sRegExpFile = $sWork & '\StringRegExpReplace.txt'
_T30WriteBinary($sRegExpFile, 'EFBBBF746F6B656E3D6F6C640A776F72643D636166C3A90A0A')
_StringRegExpReplace($sRegExpFile, 'old~new', '~|1')
Local $bRegExpReplace = _T30BinaryEquals($sRegExpFile, 'EFBBBF746F6B656E3D6E65770A776F72643D636166C3A90A0A')
_T30WriteResult($sLog, 'StringRegExpReplace preserves UTF-8 BOM LF and trailing blank line', $bRegExpReplace)
If Not $bRegExpReplace Then $bAllPass = False

Local $sWriteFile = $sWork & '\WriteToFile.txt'
_T30WriteBinary($sWriteFile, 'EFBBBF616C7068613D6F6C640A776F72643D636166C3A90A0A')
_WriteToFile($sWriteFile, 'Line1', 'alpha=new')
Local $bWriteToFile = _T30BinaryEquals($sWriteFile, 'EFBBBF616C7068613D6E65770A776F72643D636166C3A90A0A')
_T30WriteResult($sLog, 'WriteToFile preserves UTF-8 BOM LF and trailing blank line', $bWriteToFile)
If Not $bWriteToFile Then $bAllPass = False

Local $sPrefFile = $sWork & '\WriteToPref.txt'
_T30WriteBinary($sPrefFile, 'EFBBBF6B65795B6E616D655D3D6F6C643B0A776F72643D636166C3A90A0A')
_WriteToPref($sPrefFile, 'key[', ']=', ';', 'name', 'new')
Local $bWriteToPref = _T30BinaryEquals($sPrefFile, 'EFBBBF6B65795B6E616D655D3D6E65773B0A776F72643D636166C3A90A0A')
_T30WriteResult($sLog, 'WriteToPref preserves UTF-8 BOM LF and trailing blank line', $bWriteToPref)
If Not $bWriteToPref Then $bAllPass = False

Local $sMozFile = $sWork & '\MozPrefs.txt'
_T30WriteBinary($sMozFile, 'EFBBBF757365725F70726566282273616D706C652E6E616D65222C20226F6C6422293B0A776F72643D636166C3A90A0A')
_MozPrefs($sMozFile, 'sample.name', '"new"', 'User')
Local $bMozPrefs = _T30BinaryEquals($sMozFile, 'EFBBBF757365725F70726566282273616D706C652E6E616D65222C20226E657722293B0A776F72643D636166C3A90A0A')
_T30WriteResult($sLog, 'MozPrefs preserves UTF-8 BOM LF and trailing blank line', $bMozPrefs)
If Not $bMozPrefs Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T30WriteBinary($sFile, $sHex)
	Local $hFile = FileOpen($sFile, 18)
	If $hFile = -1 Then Return False
	FileWrite($hFile, Binary('0x' & $sHex))
	FileClose($hFile)
	Return True
EndFunc

Func _T30BinaryEquals($sFile, $sExpectedHex)
	Local $hFile = FileOpen($sFile, 16)
	If $hFile = -1 Then Return False
	Local $bActual = FileRead($hFile)
	FileClose($hFile)
	Return $bActual = Binary('0x' & $sExpectedHex)
EndFunc

Func _T30WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
