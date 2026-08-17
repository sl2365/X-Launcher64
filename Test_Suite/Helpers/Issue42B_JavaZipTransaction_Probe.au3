Global $Root = @ScriptDir

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test43'
Local $sLog = $sWork & '\Probe.log'
Local $sSource = FileRead(@ScriptDir & '\x-udf.au3')
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $bPatterns = StringInStr($sSource, 'Local $sSetup = "setup\*.zip|setup\*.exe"', 1) > 0
_T43WriteResult($sLog, 'ZIP and legacy setup packages accepted', $bPatterns)
If Not $bPatterns Then $bAllPass = False

Local $iPrepare = StringInStr($sSource, '_JavaPreparePackage($sSetup, $sStage, $s7Zip)', 1)
Local $iBackup = 0
If $iPrepare > 0 Then $iBackup = StringInStr($sSource, '_JavaBackup($sJBak)', 1, 1, $iPrepare)
Local $bStagedFirst = ($iPrepare > 0 And $iBackup > $iPrepare)
_T43WriteResult($sLog, 'Package staged before live backup', $bStagedFirst)
If Not $bStagedFirst Then $bAllPass = False

Local $sDirect = $sWork & '\DirectStage'
DirCreate($sDirect & '\bin')
FileWrite($sDirect & '\bin\java.exe', 'java')
FileWrite($sDirect & '\bin\javaw.exe', 'javaw')
Local $sDirectResult = Call('_JavaFindRuntimeRoot', $sDirect)
Local $iDirectError = @error
Local $bDirect = ($iDirectError = 0 And $sDirectResult = $sDirect)
_T43WriteResult($sLog, 'Direct ZIP runtime root recognized', $bDirect)
If Not $bDirect Then $bAllPass = False

Local $sWrapped = $sWork & '\WrappedStage'
DirCreate($sWrapped & '\jdk-portable\bin')
FileWrite($sWrapped & '\jdk-portable\bin\java.exe', 'java')
FileWrite($sWrapped & '\jdk-portable\bin\javaw.exe', 'javaw')
Local $sWrappedResult = Call('_JavaFindRuntimeRoot', $sWrapped)
Local $iWrappedError = @error
Local $bWrapped = ($iWrappedError = 0 And $sWrappedResult = $sWrapped & '\jdk-portable')
_T43WriteResult($sLog, 'Wrapped ZIP runtime root recognized', $bWrapped)
If Not $bWrapped Then $bAllPass = False

Local $sAmbiguous = $sWork & '\AmbiguousStage'
DirCreate($sAmbiguous & '\jdk-one\bin')
DirCreate($sAmbiguous & '\jdk-two\bin')
FileWrite($sAmbiguous & '\jdk-one\bin\java.exe', 'java')
FileWrite($sAmbiguous & '\jdk-one\bin\javaw.exe', 'javaw')
FileWrite($sAmbiguous & '\jdk-two\bin\java.exe', 'java')
FileWrite($sAmbiguous & '\jdk-two\bin\javaw.exe', 'javaw')
Local $sAmbiguousResult = Call('_JavaFindRuntimeRoot', $sAmbiguous)
Local $iAmbiguousError = @error
Local $bAmbiguous = ($iAmbiguousError = 2 And $sAmbiguousResult = '')
_T43WriteResult($sLog, 'Ambiguous ZIP runtime rejected', $bAmbiguous)
If Not $bAmbiguous Then $bAllPass = False

Local $sBackupJava = $sWork & '\BackupJava'
Local $sBackup = $sBackupJava & '\old_java'
_T43BuildRuntime($sBackupJava)
FileChangeDir($sBackupJava)
Local $iBackupResult = _JavaBackup($sBackup)
FileChangeDir(@ScriptDir)
Local $bBackup = ($iBackupResult = 1 And _
	FileRead($sBackup & '\release') = 'old-release' And _
	FileRead($sBackup & '\bin\java.exe') = 'old-java' And _
	FileRead($sBackup & '\lib\runtime.txt') = 'old-lib' And _
	FileRead($sBackup & '\conf\settings.txt') = 'old-conf' And _
	FileRead($sBackup & '\legal\notice.txt') = 'old-legal' And _
	Not FileExists($sBackupJava & '\bin') And _
	Not FileExists($sBackupJava & '\conf'))
_T43WriteResult($sLog, 'Complete portable runtime backed up', $bBackup)
If Not $bBackup Then $bAllPass = False

Local $sRestoreJava = $sWork & '\RestoreJava'
Local $sRestoreBackup = $sRestoreJava & '\old_java'
_T43BuildRuntime($sRestoreJava)
FileChangeDir($sRestoreJava)
_JavaBackup($sRestoreBackup)
DirCreate($sRestoreJava & '\bin')
DirCreate($sRestoreJava & '\conf')
DirCreate($sRestoreJava & '\jmods')
FileWrite($sRestoreJava & '\bin\partial.txt', 'partial')
FileWrite($sRestoreJava & '\conf\settings.txt', 'partial-conf')
FileWrite($sRestoreJava & '\jmods\partial.txt', 'partial')
FileWrite($sRestoreJava & '\partial.txt', 'partial')
Local $iRestoreResult = _JavaResume($sRestoreBackup)
FileChangeDir(@ScriptDir)
Local $bRestore = ($iRestoreResult = 1 And _
	FileRead($sRestoreJava & '\release') = 'old-release' And _
	FileRead($sRestoreJava & '\bin\java.exe') = 'old-java' And _
	FileRead($sRestoreJava & '\lib\runtime.txt') = 'old-lib' And _
	FileRead($sRestoreJava & '\conf\settings.txt') = 'old-conf' And _
	FileRead($sRestoreJava & '\legal\notice.txt') = 'old-legal' And _
	Not FileExists($sRestoreJava & '\bin\partial.txt') And _
	Not FileExists($sRestoreJava & '\jmods') And _
	Not FileExists($sRestoreJava & '\partial.txt') And _
	Not FileExists($sRestoreBackup))
_T43WriteResult($sLog, 'Failed install restores complete runtime', $bRestore)
If Not $bRestore Then $bAllPass = False

Local $bSetup = (FileRead($sBackupJava & '\setup\package.zip') = 'setup-package' And _
	FileRead($sRestoreJava & '\setup\package.zip') = 'setup-package')
_T43WriteResult($sLog, 'Setup package preserved during transaction', $bSetup)
If Not $bSetup Then $bAllPass = False

Local $bLegacy = (StringInStr($sSource, '_UnZip("core.zip", ".\", $s7Zip)', 1) > 0 And _
	StringInStr($sSource, '_UnPack("lib\*.pack", $sUnPack)', 1) > 0)
_T43WriteResult($sLog, 'Legacy EXE extraction retained', $bLegacy)
If Not $bLegacy Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T43BuildRuntime($sPath)
	DirCreate($sPath & '\bin')
	DirCreate($sPath & '\lib')
	DirCreate($sPath & '\conf')
	DirCreate($sPath & '\legal')
	DirCreate($sPath & '\setup')
	FileWrite($sPath & '\release', 'old-release')
	FileWrite($sPath & '\bin\java.exe', 'old-java')
	FileWrite($sPath & '\bin\javaw.exe', 'old-javaw')
	FileWrite($sPath & '\lib\runtime.txt', 'old-lib')
	FileWrite($sPath & '\conf\settings.txt', 'old-conf')
	FileWrite($sPath & '\legal\notice.txt', 'old-legal')
	FileWrite($sPath & '\setup\package.zip', 'setup-package')
EndFunc

Func _T43WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
