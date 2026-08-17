Global $Root = @ScriptDir

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test33'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sExpectedFile = '\\server\share\folder\file.txt'
Local $sExpectedParent = '\\server\share\folder'

Local $bFullPath = (_FullPath($sExpectedFile) == $sExpectedFile)
_T33WriteResult($sLog, 'FullPath direct UNC retained', $bFullPath)
If Not $bFullPath Then $bAllPass = False

Local $bNormalPath = (_NormalPath('\\server\share\folder\\file.txt') == $sExpectedFile)
_T33WriteResult($sLog, 'NormalPath UNC prefix retained', $bNormalPath)
If Not $bNormalPath Then $bAllPass = False

Local $bSlashUNC = (_NormalPath('//server/share//folder/file.txt') == $sExpectedFile)
_T33WriteResult($sLog, 'Forward-slash UNC normalized safely', $bSlashUNC)
If Not $bSlashUNC Then $bAllPass = False

Local $bFileInfo = (_FileInfo($sExpectedFile, 0) == $sExpectedParent)
_T33WriteResult($sLog, 'FileInfo UNC parent retained', $bFileInfo)
If Not $bFileInfo Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T33WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
