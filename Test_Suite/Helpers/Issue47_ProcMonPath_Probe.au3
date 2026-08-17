AutoItSetOption('ExpandEnvStrings', 1)
AutoItSetOption('ExpandVarStrings', 1)

Global $Root = @ScriptDir & '\Test_Suite\Working\Test47\HelperRoot'
Global $Lib = $Root & '\Lib'

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test47'
Local $sLog = $sWork & '\Helper.log'
Local $bAllPass = True
Local $sResolved = ''
Local $sResolution = ''
Local $bResult
Local $iResolveError

DirCreate($Root & '\Absolute')
DirCreate($Root & '\Relative')
DirCreate($Root & '\Folder')
DirCreate($Root & '\Invalid')
DirCreate($Lib & '\Tools\ProcessMonitor')
FileWrite($Root & '\Absolute\Procmon64.exe', 'ABSOLUTE')
FileWrite($Root & '\Relative\Procmon.exe', 'RELATIVE')
FileWrite($Root & '\Folder\Procmon64.exe', 'FOLDER')
FileWrite($Root & '\Invalid\OtherTool.exe', 'INVALID')
FileWrite($Lib & '\Tools\ProcessMonitor\Procmon64.exe', 'DEFAULT')

$bResult = _ResolveProcMonPath($Root & '\Absolute\Procmon64.exe', $sResolved, $sResolution)
_T47WriteResult($sLog, 'Absolute ProcMon executable resolves', $bResult And _
		$sResolved = $Root & '\Absolute\Procmon64.exe' And $sResolution = 'configured-file')
If Not ($bResult And $sResolved = $Root & '\Absolute\Procmon64.exe' And _
		$sResolution = 'configured-file') Then $bAllPass = False

$bResult = _ResolveProcMonPath('.\Relative\Procmon.exe', $sResolved, $sResolution)
_T47WriteResult($sLog, 'Relative ProcMon path resolves against Root', $bResult And _
		$sResolved = $Root & '\Relative\Procmon.exe')
If Not ($bResult And $sResolved = $Root & '\Relative\Procmon.exe') Then $bAllPass = False

$bResult = _ResolveProcMonPath($Root & '\Folder', $sResolved, $sResolution)
_T47WriteResult($sLog, 'ProcMon folder selects a supported executable', $bResult And _
		$sResolved = $Root & '\Folder\Procmon64.exe' And $sResolution = 'configured-folder')
If Not ($bResult And $sResolved = $Root & '\Folder\Procmon64.exe' And _
		$sResolution = 'configured-folder') Then $bAllPass = False

$bResult = _ResolveProcMonPath('', $sResolved, $sResolution)
_T47WriteResult($sLog, 'Blank ProcMonPath checks the documented default', $bResult And _
		$sResolved = $Lib & '\Tools\ProcessMonitor\Procmon64.exe' And _
		$sResolution = 'default-file')
If Not ($bResult And $sResolved = $Lib & '\Tools\ProcessMonitor\Procmon64.exe' And _
		$sResolution = 'default-file') Then $bAllPass = False

$bResult = _ResolveProcMonPath($Root & '\Invalid\OtherTool.exe', $sResolved, $sResolution)
$iResolveError = @error
_T47WriteResult($sLog, 'Unexpected executable name is rejected', Not $bResult And _
		$iResolveError = 4 And $sResolution = 'configured-file-name')
If $bResult Or $iResolveError <> 4 Or $sResolution <> 'configured-file-name' Then $bAllPass = False

$bResult = _ResolveProcMonPath('.\Missing\Procmon64.exe', $sResolved, $sResolution)
$iResolveError = @error
_T47WriteResult($sLog, 'Missing configured ProcMon path is reported', Not $bResult And _
		$iResolveError = 3 And $sResolved = $Root & '\Missing\Procmon64.exe')
If $bResult Or $iResolveError <> 3 Or $sResolved <> $Root & '\Missing\Procmon64.exe' Then $bAllPass = False

Local $sUNC = '\\127.0.0.1\XLauncherProcMonMissing\Procmon64.exe'
$bResult = _ResolveProcMonPath($sUNC, $sResolved, $sResolution)
$iResolveError = @error
_T47WriteResult($sLog, 'UNC ProcMon path prefix is preserved', Not $bResult And _
		$iResolveError = 3 And $sResolved = $sUNC)
If $bResult Or $iResolveError <> 3 Or $sResolved <> $sUNC Then $bAllPass = False

Local $sUdfSource = FileRead(@ScriptDir & '\x-udf.au3')
Local $iResolverStart = StringInStr($sUdfSource, 'Func _ResolveProcMonPath(', 1)
Local $iResolverEnd = StringInStr($sUdfSource, 'EndFunc   ;==>_ResolveProcMonPath', 1, 1, $iResolverStart)
Local $sResolverSource = ''
If $iResolverStart > 0 And $iResolverEnd > $iResolverStart Then
	$sResolverSource = StringMid($sUdfSource, $iResolverStart, $iResolverEnd - $iResolverStart)
EndIf
Local $bReadOnly = ($sResolverSource <> '' And _
		StringInStr($sResolverSource, 'Run(', 1) = 0 And _
		StringInStr($sResolverSource, 'ShellExecute(', 1) = 0 And _
		StringInStr($sResolverSource, 'Inet', 1) = 0 And _
		StringInStr($sResolverSource, 'accepteula', 1) = 0)
_T47WriteResult($sLog, 'Resolver performs no launch download or EULA action', $bReadOnly)
If Not $bReadOnly Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T47WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
