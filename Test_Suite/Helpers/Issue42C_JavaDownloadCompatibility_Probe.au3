AutoItSetOption('ExpandEnvStrings', 1)
AutoItSetOption('ExpandVarStrings', 1)

Global $Root = @ScriptDir
Global $Lib = @ScriptDir & '\Test_Suite\Working\Test44\SelectionLib'
Global $ScriptIni = ''
Global $ScriptName = 'Test44'
Global $Debug = 'false', $DebugFile = ''

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test44'
Local $sLog = $sWork & '\Probe.log'
Local $sUdf = FileRead(@ScriptDir & '\x-udf.au3')
Local $sLauncher = FileRead(@ScriptDir & '\x-launcher.au3')
Local $sTemplate = @ScriptDir & '\x-launcher.ini'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sWork)

Local $bTemplate = IniRead($sTemplate, 'Options', 'JavaURL', '__missing__') = ''
_T44WriteResult($sLog, 'Optional JavaURL key documented in template', $bTemplate)
If Not $bTemplate Then $bAllPass = False

Local $bPathTemplate = IniRead($sTemplate, 'Options', 'JavaPath', '__missing__') = ''
_T44WriteResult($sLog, 'Optional JavaPath key documented in template', $bPathTemplate)
If Not $bPathTemplate Then $bAllPass = False

Local $bOldIni = StringInStr($sUdf, "IniRead($ScriptIni, 'Options', 'JavaURL', '')", 1) > 0
_T44WriteResult($sLog, 'Old INI without JavaURL remains compatible', $bOldIni)
If Not $bOldIni Then $bAllPass = False

Local $bOldPathIni = StringInStr($sUdf, "IniRead($ScriptIni, 'Options', 'JavaPath', '')", 1) > 0
_T44WriteResult($sLog, 'Old INI without JavaPath remains compatible', $bOldPathIni)
If Not $bOldPathIni Then $bAllPass = False

Local $sExternal64 = $sWork & '\External\Java64'
Local $sRelativeRoot = $sWork & '\RelativeRoot'
Local $sRelative32 = $sRelativeRoot & '\CommonFiles\Java'
Local $sFakeLauncher = $sWork & '\JavaPortableLauncher.exe'
_T44BuildRuntime($sExternal64)
_T44BuildRuntime($sRelative32)
FileWrite($sFakeLauncher, 'launcher')

Local $sAbsoluteResolved = Call('_JavaPathResolve', $sExternal64, $sWork)
Local $iAbsoluteError = @error
Local $sQuotedResolved = Call('_JavaPathResolve', '"' & $sExternal64 & '"', $sWork)
Local $iQuotedError = @error
Local $bAbsolutePath = ($iAbsoluteError = 0 And $iQuotedError = 0 And _
		StringLower($sAbsoluteResolved) = StringLower($sExternal64) And _
		StringLower($sQuotedResolved) = StringLower($sExternal64))
_T44WriteResult($sLog, 'Absolute and quoted JavaPath runtime roots accepted', $bAbsolutePath)
If Not $bAbsolutePath Then $bAllPass = False

Local $sBinResolved = Call('_JavaPathResolve', $sExternal64 & '\bin', $sWork)
Local $iBinError = @error
Local $sJavaResolved = Call('_JavaPathResolve', $sExternal64 & '\bin\java.exe', $sWork)
Local $iJavaError = @error
Local $sExecutableResolved = Call('_JavaPathResolve', $sExternal64 & '\bin\javaw.exe', $sWork)
Local $iExecutableError = @error
Local $bExecutablePath = ($iBinError = 0 And $iJavaError = 0 And $iExecutableError = 0 And _
		StringLower($sBinResolved) = StringLower($sExternal64) And _
		StringLower($sJavaResolved) = StringLower($sExternal64) And _
		StringLower($sExecutableResolved) = StringLower($sExternal64))
_T44WriteResult($sLog, 'JavaPath bin and Java executables normalized to runtime root', $bExecutablePath)
If Not $bExecutablePath Then $bAllPass = False

Local $sRelativeResolved = Call('_JavaPathResolve', 'CommonFiles\Java', $sRelativeRoot)
Local $iRelativeError = @error
Local $sDotRelativeResolved = Call('_JavaPathResolve', '.\CommonFiles\Java', $sRelativeRoot)
Local $iDotRelativeError = @error
Local $bRelativePath = ($iRelativeError = 0 And $iDotRelativeError = 0 And _
		StringLower($sRelativeResolved) = StringLower($sRelative32) And _
		StringLower($sDotRelativeResolved) = StringLower($sRelative32))
_T44WriteResult($sLog, 'Relative JavaPath resolved against Root', $bRelativePath)
If Not $bRelativePath Then $bAllPass = False

Call('_JavaPathResolve', $sFakeLauncher, $sWork)
Local $iLauncherError = @error
Local $bLauncherRejected = $iLauncherError <> 0
_T44WriteResult($sLog, 'JavaPortableLauncher executable rejected as a runtime', $bLauncherRejected)
If Not $bLauncherRejected Then $bAllPass = False

Local $bUrlValidation = _T44URLValid('http://example.invalid/java.zip', True) And _
		_T44URLValid('https://example.invalid/java.zip', True) And _
		_T44URLValid('', False) And _
		_T44URLValid('ftp://example.invalid/java.zip', False) And _
		_T44URLValid('file:///C:/java.zip', False)
_T44WriteResult($sLog, 'Only HTTP and HTTPS Java URLs accepted', $bUrlValidation)
If Not $bUrlValidation Then $bAllPass = False

Local $bInvalidGuidance = (StringInStr($sLauncher, '$iJavaCheckError = 6', 1) > 0 And _
		StringInStr($sLauncher, 'HTTP', 0) > 0 And _
		StringInStr($sLauncher, 'HTTPS', 0) > 0 And _
		StringInStr($sLauncher, 'JavaURL', 1) > 0)
_T44WriteResult($sLog, 'Invalid JavaURL has brief required-Java guidance', $bInvalidGuidance)
If Not $bInvalidGuidance Then $bAllPass = False

Local $bNeutralName = StringInStr($sUdf, 'Local $sSetupDown = "setup\java-download.package"', 1) > 0
_T44WriteResult($sLog, 'Downloaded package uses format-neutral filename', $bNeutralName)
If Not $bNeutralName Then $bAllPass = False

Local $bUrlUnchanged = StringInStr($sUdf, '_Download($sJavaURL, $sSetupDown, $iLang)', 1) > 0
_T44WriteResult($sLog, 'Configured JavaURL passed unchanged to downloader', $bUrlUnchanged)
If Not $bUrlUnchanged Then $bAllPass = False

Local $sOldJavaHome = EnvGet('JAVA_HOME')
Local $sOldPath = EnvGet('PATH')
Local $sJavaHomeRuntime = $sWork & '\JavaHomeRuntime'
Local $sPathRuntime = $sWork & '\PathRuntime'
_T44BuildRuntime($sJavaHomeRuntime)
_T44BuildRuntime($sPathRuntime)

EnvSet('JAVA_HOME', $sJavaHomeRuntime)
EnvSet('PATH', '')
Local $sJavaHomeFound = Call('_JavaFindSystemJava')
Local $iJavaHomeError = @error
Local $bJavaHome = ($iJavaHomeError = 0 And StringLower($sJavaHomeFound) = StringLower($sJavaHomeRuntime))
_T44WriteResult($sLog, 'JAVA_HOME system fallback recognized', $bJavaHome)
If Not $bJavaHome Then $bAllPass = False

EnvSet('JAVA_HOME', '')
EnvSet('PATH', $sPathRuntime & '\bin')
Local $sPathFound = Call('_JavaFindSystemJava')
Local $iPathError = @error
Local $bPath = ($iPathError = 0 And StringLower($sPathFound) = StringLower($sPathRuntime))
_T44WriteResult($sLog, 'PATH system fallback recognized', $bPath)
If Not $bPath Then $bAllPass = False

EnvSet('JAVA_HOME', $sOldJavaHome)
EnvSet('PATH', $sOldPath)

Local $bRegistry = (StringInStr($sUdf, 'JavaSoft\Java Runtime Environment', 1) > 0 And _
		StringInStr($sUdf, 'JavaSoft\JRE', 1) > 0 And _
		StringInStr($sUdf, 'JavaSoft\JDK', 1) > 0 And _
		StringInStr($sUdf, 'HKLM64', 1) > 0 And _
		StringInStr($sUdf, 'HKLM32', 1) > 0)
_T44WriteResult($sLog, 'Legacy and modern JavaSoft registry fallbacks retained', $bRegistry)
If Not $bRegistry Then $bAllPass = False

Local $sPriority = 'If FileExists($s_JavaPackPath & "\bin\javaw.exe") Then' & @CRLF & @TAB & @TAB & _
		'Return SetError($iJavaGetResult, 0, $s_JavaPackPath)' & @CRLF & @TAB & 'EndIf'
Local $bPriority = StringInStr($sUdf, $sPriority, 1) > 0
_T44WriteResult($sLog, 'Portable Java remains preferred over system Java', $bPriority)
If Not $bPriority Then $bAllPass = False

Local $sSelectionIni = $sWork & '\JavaPathSelection.ini'
Local $sSelectionRoot = $sWork & '\SelectionRoot'
Local $sSystemRuntime = $sWork & '\SystemRuntime'
Local $sExternalJavaBefore = FileRead($sExternal64 & '\bin\java.exe')
Local $sExternalJavawBefore = FileRead($sExternal64 & '\bin\javaw.exe')
_T44BuildRuntime($Lib & '\Java')
_T44BuildRuntime($sSystemRuntime)
FileWrite($Lib & '\Java\PackSentinel.txt', 'pack')
IniWrite($sSelectionIni, 'Options', 'Java', 'true')
IniWrite($sSelectionIni, 'Options', 'JavaPath', $sExternal64 & '\bin\javaw.exe')
IniWrite($sSelectionIni, 'Options', 'JavaURL', 'https://example.invalid/java-runtime.zip')

Local $sSelectionOldJavaHome = EnvGet('JAVA_HOME')
Local $sSelectionOldPath = EnvGet('PATH')
EnvSet('JAVA_HOME', $sSystemRuntime)
EnvSet('PATH', '')
Local $sSelectedPath = Call('_JavaCheck', 'Test44', $sSelectionIni, $Lib, $sSelectionRoot)
Local $iSelectedError = @error
Local $iSelectedExtended = @extended
Local $bConfiguredPriority = ($iSelectedError = 0 And $iSelectedExtended = 10 And _
		StringLower($sSelectedPath) = StringLower($sExternal64))
_T44WriteResult($sLog, 'Configured JavaPath takes priority over bundled system and URL sources', _
		$bConfiguredPriority)
If Not $bConfiguredPriority Then $bAllPass = False

Local $bURLBypassed = (Not FileExists($Lib & '\Java\setup\java-download.package') And _
		FileRead($Lib & '\Java\PackSentinel.txt') = 'pack')
_T44WriteResult($sLog, 'Usable JavaPath bypasses JavaURL download and JavaGet writes', $bURLBypassed)
If Not $bURLBypassed Then $bAllPass = False

IniWrite($sSelectionIni, 'Options', 'Java', 'false')
Local $sDisabledPath = Call('_JavaCheck', 'Test44', $sSelectionIni, $Lib, $sSelectionRoot)
Local $bDisabled = (StringLower($sDisabledPath) = StringLower($Lib & '\Java') And _
		IniRead($sSelectionIni, 'Options', 'JavaPath', '') = $sExternal64 & '\bin\javaw.exe')
_T44WriteResult($sLog, 'Java false ignores but retains configured JavaPath', $bDisabled)
If Not $bDisabled Then $bAllPass = False

EnvSet('JAVA_HOME', $sSelectionOldJavaHome)
EnvSet('PATH', $sSelectionOldPath)
Local $bReadOnly = (FileRead($sExternal64 & '\bin\java.exe') = $sExternalJavaBefore And _
		FileRead($sExternal64 & '\bin\javaw.exe') = $sExternalJavawBefore)
_T44WriteResult($sLog, 'External JavaPath runtime remains byte-identical', $bReadOnly)
If Not $bReadOnly Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _T44URLValid($sURL, $bExpected)
	Local $vResult = Call('_JavaURLValid', $sURL)
	Local $iCallError = @error
	If $iCallError <> 0 Then Return False
	Return (Not Not $vResult) = $bExpected
EndFunc

Func _T44BuildRuntime($sPath)
	DirCreate($sPath & '\bin')
	FileWrite($sPath & '\bin\java.exe', 'java')
	FileWrite($sPath & '\bin\javaw.exe', 'javaw')
EndFunc

Func _T44WriteResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf
	FileClose($hFile)
EndFunc
