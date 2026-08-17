Global $Root = @ScriptDir

#include 'x-udf.au3'

If $CmdLine[0] > 0 Then
	If $CmdLine[1] = '--non-drive-child' Then
		_T34RunNonDriveChild()
		Exit 0
	EndIf
EndIf

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test34'
Local $sLog = $sWork & '\Probe.log'
Local $sScopeFile = $sWork & '\Scope.txt'
Local $sChildFile = $sWork & '\NonDrive.txt'
Local $sChildMarker = $sWork & '\NonDriveReached.txt'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $hScope = FileOpen($sScopeFile, 2)
FileWriteLine($hScope, 'valid=C:\Portable\Data')
FileWriteLine($hScope, 'embedded=ABC:\NotAPath')
FileWriteLine($hScope, 'url=https://example.test/C:/docs')
FileClose($hScope)

_FixDriveLetter($sScopeFile, 'X:\Portable')
Local $sScopeResult = FileRead($sScopeFile)

Local $bValid = StringInStr($sScopeResult, 'valid=X:\Portable\Data', 1) > 0
_T34WriteResult($sLog, 'Valid absolute path rewritten', $bValid)
If Not $bValid Then $bAllPass = False

Local $bEmbedded = StringInStr($sScopeResult, 'embedded=ABC:\NotAPath', 1) > 0
_T34WriteResult($sLog, 'Embedded drive-like text preserved', $bEmbedded)
If Not $bEmbedded Then $bAllPass = False

Local $bURL = StringInStr($sScopeResult, 'url=https://example.test/C:/docs', 1) > 0
_T34WriteResult($sLog, 'URL drive-like segment preserved', $bURL)
If Not $bURL Then $bAllPass = False

FileWrite($sChildFile, 'sentinel')
Local $sCommand = '"' & @AutoItExe & '" /ErrorStdOut "' & @ScriptFullPath & '" --non-drive-child'
Local $iChildExit = RunWait($sCommand, @ScriptDir, @SW_HIDE)
Local $bNonDrive = ($iChildExit = 0 And FileExists($sChildMarker) And FileRead($sChildFile) = 'sentinel')
_T34WriteResult($sLog, 'Non-drive Root rejected safely', $bNonDrive)
If Not $bNonDrive Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T34RunNonDriveChild()
	Local $sChildWork = @ScriptDir & '\Test_Suite\Working\Test34'
	Local $sFile = $sChildWork & '\NonDrive.txt'
	_FixDriveLetter($sFile, '\\server\share')
	FileWrite($sChildWork & '\NonDriveReached.txt', 'reached')
EndFunc

Func _T34WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
