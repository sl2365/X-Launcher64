Global $Root = @ScriptDir

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test32'
Local $sLog = $sWork & '\Probe.log'
Local $sOrdinaryDir = $sWork & '\Ordinary'
Local $sWildcardDir = $sWork & '\Wildcard'
Local $sOriginalWorkingDir = @WorkingDir
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sOrdinaryDir)
DirCreate($sWildcardDir)
FileWrite($sOrdinaryDir & '\Plain.txt', 'ordinary')
FileWrite($sWildcardDir & '\Wild.txt', 'wildcard')

Local $sMultiPath = '.\Test_Suite\Working\Test32\Ordinary\Plain.txt|.\Test_Suite\Working\Test32\Wildcard\*.txt'
Local $sExpectedOrdinary = $Root & '\Test_Suite\Working\Test32\Ordinary\Plain.txt'
Local $sExpectedWildcard = $Root & '\Test_Suite\Working\Test32\Wildcard\Wild.txt'

FileChangeDir($sWork)
Local $aAll = _ExpandMultiPath($sMultiPath, False)
Local $aExisting = _ExpandMultiPath($sMultiPath, True)
FileChangeDir($sOriginalWorkingDir)

Local $bOrdinary = False
If $aAll[0] >= 1 Then $bOrdinary = ($aAll[1] == $sExpectedOrdinary)
_T32WriteResult($sLog, 'Ordinary path normalized against Root', $bOrdinary)
If Not $bOrdinary Then $bAllPass = False

Local $bWildcard = False
If $aAll[0] >= 2 Then $bWildcard = ($aAll[2] == $sExpectedWildcard)
_T32WriteResult($sLog, 'Wildcard path normalized against Root', $bWildcard)
If Not $bWildcard Then $bAllPass = False

Local $bOnlyIfExist = False
If $aExisting[0] = 2 Then
	$bOnlyIfExist = ($aExisting[1] == $sExpectedOrdinary And $aExisting[2] == $sExpectedWildcard)
EndIf
_T32WriteResult($sLog, 'OnlyIfExist independent of working directory', $bOnlyIfExist)
If Not $bOnlyIfExist Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T32WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
