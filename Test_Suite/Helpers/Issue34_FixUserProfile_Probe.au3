Global $Root = @ScriptDir

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test35'
Local $sLog = $sWork & '\Probe.log'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $sValidProfile = $sWork & '\ValidProfile'
DirCreate($sValidProfile & '\OldDesktop')
FileWrite($sValidProfile & '\OldDesktop\Sentinel.txt', 'valid')
IniWrite($sValidProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', 'OldDesktop')
_FixUserProfile($sValidProfile, 'NewDesktop', 'Desktop')
Local $bValid = (Not FileExists($sValidProfile & '\OldDesktop') And _
	FileRead($sValidProfile & '\NewDesktop\Sentinel.txt') = 'valid' And _
	IniRead($sValidProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', '') = 'NewDesktop')
_T35WriteResult($sLog, 'Valid child directory renamed', $bValid)
If Not $bValid Then $bAllPass = False

Local $sEmptyProfile = $sWork & '\EmptyProfile'
DirCreate($sEmptyProfile)
FileWrite($sEmptyProfile & '\RootSentinel.txt', 'root')
IniWrite($sEmptyProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', '')
_FixUserProfile($sEmptyProfile, 'NewDesktop', 'Desktop')
Local $bEmpty = (FileExists($sEmptyProfile) And _
	FileRead($sEmptyProfile & '\RootSentinel.txt') = 'root' And _
	Not FileExists($sEmptyProfile & '\NewDesktop') And _
	IniRead($sEmptyProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', '') = 'NewDesktop')
_T35WriteResult($sLog, 'Empty old value preserves profile root', $bEmpty)
If Not $bEmpty Then $bAllPass = False

Local $sTraversalProfile = $sWork & '\TraversalProfile'
Local $sTraversalVictim = $sWork & '\TraversalVictim'
DirCreate($sTraversalProfile)
DirCreate($sTraversalVictim)
FileWrite($sTraversalVictim & '\Sentinel.txt', 'traversal')
IniWrite($sTraversalProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', '..\TraversalVictim')
_FixUserProfile($sTraversalProfile, 'NewDesktop', 'Desktop')
Local $bTraversal = (FileRead($sTraversalVictim & '\Sentinel.txt') = 'traversal' And _
	Not FileExists($sTraversalProfile & '\NewDesktop'))
_T35WriteResult($sLog, 'Parent traversal source rejected', $bTraversal)
If Not $bTraversal Then $bAllPass = False

Local $sNestedProfile = $sWork & '\NestedProfile'
Local $sNestedOld = $sNestedProfile & '\Nested\OldDesktop'
DirCreate($sNestedOld)
FileWrite($sNestedOld & '\Sentinel.txt', 'nested')
IniWrite($sNestedProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', 'Nested\OldDesktop')
_FixUserProfile($sNestedProfile, 'NewDesktop', 'Desktop')
Local $bNested = (FileRead($sNestedOld & '\Sentinel.txt') = 'nested' And _
	Not FileExists($sNestedProfile & '\NewDesktop'))
_T35WriteResult($sLog, 'Nested old source rejected', $bNested)
If Not $bNested Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T35WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
