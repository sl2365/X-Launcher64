#include-once
;~ #AutoIt3Wrapper_au3check_parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6
; ------------------------------------------------------------------------------
;
;					X-Launcher - The Universal Launcher!
;
; ------------------------------------------------------------------------------
;
; AutoIt Version:			3.2.12.1
; Platform:					Windows
; Script Name:				X-Launcher
; Script Function:			Runs every application from a removable drive
; Script Version:			1.5.4.0
; Author:					Gabriele Tittonel <tittoproject@gmail.com>
; Home Page:				http://x-launcher.sourceforge.net/
; License:					GNU General Public License
; Contributors:				winPenPack Team and winPenPack community
;							(http://www.winpenpack.com)
;
; ------------------------------------------------------------------------------

#NoTrayIcon
AutoItSetOption('ExpandEnvStrings', 1)
AutoItSetOption('ExpandVarStrings', 1)
AutoItSetOption("MustDeclareVars", 0)

Global $Root, $ScriptIni, $GlobalConfig

#Include <File.au3>
; ------------------------------------------------------------------------------
; Declare variables
; ------------------------------------------------------------------------------
Global $Temp, $TempLog, $DeleteTemp, $ExeName
Global $ExistingProcessPIDs = ""
Global $ScriptName, $ProcName, $VirtualMachine
Global $Cmd1, $_xcmd
Global $ScriptIniDir
Global $NoIni, $PleaseCheck
Global $Lang, $AppName, $AppVer, $Profile, $UserName
Global $Cache, $Home, $Bin, $Lib, $Doc, $Backup, $Download
Global $Drive, $DefaultFile, $WorkingDir
Global $PathToExe, $ExeDir
Global $FixAppData, $FixLocalAppData, $FixTemp, $MultipleInstances, $RunWait, $RunAfterStopOnFailure, $ShowSplash, $WriteLog
Global $_options, $Log, $IsRunning, $IsClosing
Global $CheckIni, $FileNotFound, $AlreadyRunning, $StillClosing, $WinGetProcess, $Image, $Title_SS, $Title_TT
Global $TimeOut_SS, $TimeOut_TT, $_environment, $UserProfile, $AppData, $Desktop, $Documents, $Favorites
Global $_functions, $_sections, $_file, $_values, $_runbefore, $Parameters, $Cmd, $StringToExe
Global $ProcList
Global $PreRoot, $TempDir, $HomeDir, $BinDir, $LibDir, $DocDir, $BackupDir, $DownloadDir
Global $HideShellWindow, $Java, $RegView
Global $TrayTipOn, $ShowTrayTip
Global $FirstRun, $_firstrunoperations
Global $PackShowSplash, $PackShowTrayTip
Global $Debug, $DebugFile
Global $TestRun = 'false'
Global $TestRunCommandLine = '', $TestRunCommandLineCount = 0, $TestRunShowSelector = False
Global $TestRunAutomated = False
Global $DebugSessionID = '', $DebugSessionStarted = False, $DebugSessionEnded = False
Global $DebugPassCount = 0, $DebugFailCount = 0, $DebugWarnCount = 0, $DebugSkipCount = 0, $DebugNotUsedCount = 0
Global $ExitHandlerRegistered = False
Global $TemporaryLinkCount = 0
Global $TemporaryLinks[1][4]
Global $TraceActive = False, $TraceFinalized = False
Global $TraceSessionDir = '', $TraceSummaryPath = '', $TraceSettingsPath = ''
Global $TraceStartTime = '', $TraceProcMonPath = '', $TraceProcMonState = ''
Global $TraceProcMonCapturePath = '', $TraceProcMonPID = 0
Global $TraceProcMonCSVPath = '', $TraceProcMonXMLPath = '', $TraceProcMonConfigPath = ''
Global $TraceResultsPath = '', $TracePortabilityReportPath = '', $TracePortabilityState = ''
Global $TraceProcMonCaptureActive = False, $TraceProcMonCaptureSaved = False
Global $TraceProcMonMaxMB = 512, $TraceProcMonReserveMB = 1024
Global $TraceProcMonCaptureBytes = 0, $TraceProcMonCaptureTimer = 0
Global $TraceProcMonCaptureDurationMs = 0, $TraceProcMonFreeStartMB = -1
Global $TraceProcMonCapturePartial = False, $TraceProcMonPartialReason = ''
Global $TraceProcMonLimitStopAttempted = False, $TraceProcMonSpaceCheckWarned = False
Global $TraceProcMonDetailAvailable = True
Global $TraceApplicationPID = 0, $TraceApplicationExitCode = 'not started'
Global $TraceObservedPIDs = '|', $TraceObservedProcesses = '', $TraceProcessObservation = 'not started'
Global $TraceWMI = 0, $TraceCOMErrorObject = 0, $TraceCOMError = False

; ------------------------------------------------------------------------------
; System Variables
; ------------------------------------------------------------------------------
Global $LocalAppData = RegRead('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Local AppData')
Global $LocalSettings = RegRead('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Local Settings')

; ------------------------------------------------------------------------------
; JavaGet Variables
; ------------------------------------------------------------------------------
Global $sJGAppName = "winPenPack Java Installer"
Global $iMsgBoxAnswer
Global $sJBak
Global $iJGAction = -1, $sJGTarget = ''

Global Const $aMessage[8][2] = [ _
		["Installazione interrotta dall'utente!", "Installation interrupted by user!"], _
		["Impossibile installare java!", "Unable to install java!"], _
		["Java non presente nel pacchetto." & @CRLF & "Vuoi scaricarlo ed installarlo?", "Java not found in the package." & @CRLF & "Do you want to download and install it?"], _
		["E' disponibile una nuova versione di Java." & @CRLF & "Desideri fare l'aggiornamento?", "A new version of Java is available." & @CRLF & "Do you want to upgrade?"], _
		["Installazione di Java in corso", "Java installation in progress"], _
		["Impossibile effettuare il download!", "Unable to download!"], _
		["Download in corso...", "Downloading..."], _
		["Java è in esecuzione!" & @CRLF & "Chiudere tutte le applicazioni Java.", "Java is running!" & @CRLF & "Close all Java applications."]]

#include 'x-udf.au3'
#include 'x-registry.au3'

; The private Full Test helper exits before INI discovery or normal launcher
; setup, so it cannot fall through into the configured application lifecycle.
Local $iFullTestHelperExit = _FullTestHelperEntry()
Local $bFullTestHelperRequested = @extended
If $bFullTestHelperRequested Then Exit($iFullTestHelperExit)

; ------------------------------------------------------------------------------
; ScriptIni
; ------------------------------------------------------------------------------

; Get script name from file name
$ScriptName = _FileInfo(@ScriptFullPath, 2)

; Get enviromental variable "XCONFIG"
If EnvGet('XCONFIG') <> '' Then
	$ScriptIni = EnvGet('XCONFIG')
Else
	$ScriptIni = @ScriptDir & '\' & $ScriptName & '.ini'
EndIf

; Get commandline option "--x-launcher-config"
If $CmdLine[0] <> 0 And StringInStr($CmdLine[1], '--x-launcher-config') Then
	$Cmd1 = 2
	$_xcmd = StringSplit($CmdLine[1], '=')
	Select
		Case $_xcmd[0] = 2
			$ScriptIni = _FullPath($_xcmd[2], @ScriptDir)
			$ScriptName = _FileInfo($ScriptIni, 2)
		Case Else
			FileInstall('x-launcher.ini', $ScriptIni)
			Exit (1)
	EndSelect
Else
	$Cmd1 = 1
EndIf

; Get commandline option "--x-launcher-test[=mode]"
If $CmdLine[0] >= $Cmd1 Then
	For $iTestArgument = $Cmd1 To $CmdLine[0]
		Local $sTestArgument = StringLower($CmdLine[$iTestArgument])
		Select
			Case $sTestArgument = '--x-launcher-test'
				$TestRunCommandLineCount += 1
				$TestRunShowSelector = True
			Case StringLeft($sTestArgument, 18) = '--x-launcher-test='
				$TestRunCommandLineCount += 1
				$TestRunCommandLine = StringTrimLeft($CmdLine[$iTestArgument], 18)
			Case $sTestArgument = '--x-launcher-test-automated'
				$TestRunAutomated = True
		EndSelect
	Next
EndIf

; Resolve the selected INI location. Full Test may continue without an INI;
; its fixtures are isolated and the selected path is report context only.
$ScriptIniDir = _FileInfo($ScriptIni, 0)

; Warning messages
$Lang = _SystemLanguage($Lang)
Select
	Case $Lang = 'it'
		$NoIni = 'Il file di configurazione "' & $ScriptIni & '" non esiste.' & @CRLF & @CRLF & 'Ne verrà creato uno con le opzioni predefinite.'
		$PleaseCheck = 'Si prega di controllare le impostazioni prima di proseguire.'
	Case Else
		$NoIni = 'The configuration file "' & $ScriptIni & '" does not exist.' & @CRLF & @CRLF & 'One with the default options will be created.'
		$PleaseCheck = 'Please check the settings before continue.'
EndSelect

_DebugWrite("================ " & $ScriptName & " === application started ================")
_DebugSessionStart()
;_DebugWrite("System : " & @OSVersion & " " & @OSServicePack & " (build " & @OSBuild & ") " & @ProcessorArch)

; ------------------------------------------------------------------------------
; Script Setup
; ------------------------------------------------------------------------------
$AppName = _IniReadPlus($ScriptIni, 'Setup', 'AppName', 'MyApp')
$AppVer = _IniReadPlus($ScriptIni, 'Setup', 'AppVer', '')
$Profile = _IniReadPlus($ScriptIni, 'Setup', 'Profile', 'Default')

; ------------------------------------------------------------------------------
; Global Preferences
; ------------------------------------------------------------------------------
_DebugWrite("Setting Global Preferences")
$GlobalConfig = @ScriptDir & '\X-Launcher.cfg'
If Not FileExists($GlobalConfig) Then $GlobalConfig = $ScriptIni

; Setup
$UserName = _IniReadPlus($GlobalConfig, 'Setup', 'UserName', 'User')
$Lang = _IniReadPlus($GlobalConfig, 'Setup', 'Lang', $Lang)

; FileSystem
$Root = _IniReadPlus($GlobalConfig, 'FileSystem', 'Root', @ScriptDir)
$Temp = _IniReadPlus($GlobalConfig, 'FileSystem', 'Temp', @TempDir & '\' & $ScriptName)
$Cache = _IniReadPlus($GlobalConfig, 'FileSystem', 'Cache', @TempDir & '\' & $ScriptName & '\Cache')
$Home = _IniReadPlus($GlobalConfig, 'FileSystem', 'Home', '.\' & $UserName)
$Bin = _IniReadPlus($GlobalConfig, 'FileSystem', 'Bin', '.\Bin')
$Lib = _IniReadPlus($GlobalConfig, 'FileSystem', 'Lib', '.\Lib')
$Doc = _IniReadPlus($GlobalConfig, 'FileSystem', 'Doc', '.\Documents')
$Backup = _IniReadPlus($GlobalConfig, 'FileSystem', 'Backup', '.\Backups')
$Download = _IniReadPlus($GlobalConfig, 'FileSystem', 'Download', '.\Downloads')

;Options
$PackShowSplash = _IniReadPlus($GlobalConfig, 'Options', 'ShowSplash', '')
$PackShowTrayTip = _IniReadPlus($GlobalConfig, 'Options', 'ShowTrayTip', '')

; ------------------------------------------------------------------------------
; User Preferences
; ------------------------------------------------------------------------------
_DebugWrite("Setting User Preferences")
;If FileExists($GlobalConfig) Then
If FileExists($ScriptIni) Then

	; Setup
	$UserName = _IniReadPlus($ScriptIni, 'Setup', 'UserName', $UserName)
	$Lang = _IniReadPlus($ScriptIni, 'Setup', 'Lang', $Lang)

	; FileSystem
	$Root = _IniReadPlus($ScriptIni, 'FileSystem', 'Root', $Root)
	$Temp = _IniReadPlus($ScriptIni, 'FileSystem', 'Temp', $Temp)
	$Cache = _IniReadPlus($ScriptIni, 'FileSystem', 'Cache', $Cache)
	$Home = _IniReadPlus($ScriptIni, 'FileSystem', 'Home', $Home)
	$Bin = _IniReadPlus($ScriptIni, 'FileSystem', 'Bin', $Bin)
	$Lib = _IniReadPlus($ScriptIni, 'FileSystem', 'Lib', $Lib)
	$Doc = _IniReadPlus($ScriptIni, 'FileSystem', 'Doc', $Doc)
	$Backup = _IniReadPlus($ScriptIni, 'FileSystem', 'Backup', $Backup)
	$Download = _IniReadPlus($ScriptIni, 'FileSystem', 'Download', $Download)

	;Options
	;--$ShowSplash = _IniReadPlus($ScriptIni, 'Options', 'ShowSplash', $ShowSplash)
	;--$ShowTrayTip = _IniReadPlus($ScriptIni, 'Options', 'ShowTrayTip', $ShowTrayTip)

EndIf

; Path
$Root = _FullPath($Root, @ScriptDir)
$Temp = _FullPath($Temp, $Root)
$Cache = _FullPath($Cache, $Root)
$Home = _FullPath($Home, $Root)
$Bin = _FullPath($Bin, $Root)
$Lib = _FullPath($Lib, $Root)
$Doc = _FullPath($Doc, $Root)
$Backup = _FullPath($Backup, $Root)
$Download = _FullPath($Download, $Root)
$PreRoot = _FullPath('..', $Root)

$Drive = StringLeft($Root, 2)

; Additional variables (names)
$RootName = StringRegExpReplace($Root, '.*?\\([^\\]+)\\?$', '\1')
$TempName = StringRegExpReplace($Temp, '.*?\\([^\\]+)\\?$', '\1')
$HomeName = StringRegExpReplace($Home, '.*?\\([^\\]+)\\?$', '\1')
$BinName = StringRegExpReplace($Bin, '.*?\\([^\\]+)\\?$', '\1')
$LibName = StringRegExpReplace($Lib, '.*?\\([^\\]+)\\?$', '\1')
$DocName = StringRegExpReplace($Doc, '.*?\\([^\\]+)\\?$', '\1')
$BackupName = StringRegExpReplace($Backup, '.*?\\([^\\]+)\\?$', '\1')
$DownloadName = StringRegExpReplace($Download, '.*?\\([^\\]+)\\?$', '\1')

; Temp log
$TempLog = $Temp & '\' & $ScriptName & '.log'

; ------------------------------------------------------------------------------
; Options
; ------------------------------------------------------------------------------

; Defaults
$DeleteTemp = 'true'
$FixAppData = 'false'
$FixLocalAppData = 'false'
$FixTemp = 'false'
$MultipleInstances = 'true'
$RunWait = 'true'
$RunAfterStopOnFailure = 'false'
$WriteLog = 'false'
$HideShellWindow = 'false'
$FirstRun = 'false'
$ShowSplash='false'
$ShowTrayTip='false'

; Get options from config file
$_options = IniReadSection($ScriptIni, 'Options')
If Not @error Then
	_DebugWrite("[Options] : about to execute")
	For $o = 1 To $_options[0][0]
		_DebugWrite("--> " & $_options[$o][0] & "=" & $_options[$o][1])
		If $_options[$o][1] = 'true' Or $_options[$o][1] = 'false' Then
			Select
				Case $_options[$o][0] = 'DeleteTemp'
					$DeleteTemp = $_options[$o][1]
				Case $_options[$o][0] = 'FixAppData'
					$FixAppData = $_options[$o][1]
				Case $_options[$o][0] = 'FixLocalAppData'
					$FixLocalAppData = $_options[$o][1]
				Case $_options[$o][0] = 'FixTemp'
					$FixTemp = $_options[$o][1]
				Case $_options[$o][0] = 'RunWait'
					$RunWait = $_options[$o][1]
				Case $_options[$o][0] = 'RunAfterStopOnFailure'
					$RunAfterStopOnFailure = $_options[$o][1]
				Case $_options[$o][0] = 'ShowSplash'
					$ShowSplash = $_options[$o][1]
				Case $_options[$o][0] = 'WriteLog'
					$WriteLog = $_options[$o][1]
				Case $_options[$o][0] = 'HideShellWindow'
					$HideShellWindow = $_options[$o][1]
				Case $_options[$o][0] = 'FirstRun'
					$FirstRun = $_options[$o][1]
				Case $_options[$o][0] = 'ShowTrayTip'
					$ShowTrayTip = $_options[$o][1]
			EndSelect
		EndIf
	Next
	_DebugWrite("[Options] : executed")
EndIf
$MultipleInstances = _ResolveMultipleInstancesOption($ScriptIni, 'true')

; ------------------------------------------------------------------------------
; Built-in diagnostic mode selection (INI and command-line entry points)
; ------------------------------------------------------------------------------
If $TestRunCommandLineCount > 1 Then
	Local $sTestRunMultiple
	Select
		Case $Lang = 'it'
			$sTestRunMultiple = 'Usare una sola opzione --x-launcher-test.'
		Case Else
			$sTestRunMultiple = 'Use only one --x-launcher-test option.'
	EndSelect
	_DebugWrite('[FAIL] [TestRun] Multiple command-line selections')
	MsgBox(48, $ScriptName, $sTestRunMultiple)
	_DebugSessionEnd('multiple-test-run-options')
	Exit(9)
EndIf

If $TestRunCommandLineCount = 1 Then
	If $TestRunShowSelector Then
		$TestRun = _TestRunSelectionWindow($ScriptName, $Lang)
		If $TestRun = 'cancel' Then
			_DebugWrite('[SKIP] [TestRun] Selection cancelled')
			_DebugSessionEnd('test-run-selection-cancelled')
			Exit
		EndIf
	Else
		$TestRun = StringLower(StringStripWS($TestRunCommandLine, 3))
		If $TestRun <> 'probe' And $TestRun <> 'trace' And $TestRun <> 'full' Then
			Local $sTestRunCommandInvalid
			Select
				Case $Lang = 'it'
					$sTestRunCommandInvalid = 'Valore --x-launcher-test non valido: "' & $TestRun & '".' & @CRLF & _
							'Usare probe, trace o full.'
				Case Else
					$sTestRunCommandInvalid = 'Invalid --x-launcher-test value: "' & $TestRun & '".' & @CRLF & _
							'Use probe, trace or full.'
			EndSelect
			_DebugWrite('[FAIL] [TestRun] Invalid command-line value=' & $TestRun)
			MsgBox(48, $ScriptName, $sTestRunCommandInvalid)
			_DebugSessionEnd('invalid-test-run-command-line')
			Exit(9)
		EndIf
	EndIf
Else
	$TestRun = StringLower(StringStripWS(IniRead($ScriptIni, 'Options', 'TestRun', 'false'), 3))
	If $TestRun = '' Then $TestRun = 'false'
EndIf

; Full Test is independent of the configured application and may run even when
; the selected INI does not exist. All other modes preserve the historical
; first-run INI installation behaviour.
If Not FileExists($ScriptIni) And $TestRun <> 'full' Then
	MsgBox(48, $ScriptName, $NoIni)
	MsgBox(48, $ScriptName, $PleaseCheck)
	DirCreate($ScriptIniDir)
	FileInstall('x-launcher.ini', $ScriptIni)
	FileChangeDir($ScriptIniDir)
	RunWait(@ComSpec & ' /c "' & $ScriptIni & '"', '', @SW_HIDE)
	Exit (1)
EndIf

; The non-interactive switch exists only for permanent Probe and isolated Full
; regressions. It cannot suppress confirmation for INI, selector or Trace.
If $TestRunAutomated And ($TestRunCommandLineCount <> 1 Or $TestRunShowSelector Or _
        ($TestRun <> 'probe' And $TestRun <> 'full')) Then
    _DebugWrite('[FAIL] [TestRun] Invalid automated diagnostic command line')
	_DebugSessionEnd('invalid-automated-test-run')
	Exit(9)
EndIf

Switch $TestRun
	Case 'false'
		; Missing, blank and false retain the historical normal-launch path.
	Case 'probe'
		If Not $TestRunAutomated Then
			If Not _TestRunConfirm($TestRun, $ScriptName, $Lang) Then
				_DebugWrite('[SKIP] [TestRun] Mode=' & $TestRun & ' (reason=user cancelled confirmation)')
				_DebugSessionEnd('test-run-confirmation-cancelled')
				Exit
			EndIf
		EndIf

		Local $sProbeReport = ''
		Local $iProbePass = 0, $iProbeFail = 0, $iProbeWarn = 0, $iProbeNotUsed = 0
		Local $bProbeReportCreated = _ConfigurationProbe($ScriptIni, $GlobalConfig, _
				$sProbeReport, $iProbePass, $iProbeFail, $iProbeWarn, $iProbeNotUsed)

		If Not $bProbeReportCreated Then
			_DebugWrite('[FAIL] [TestRun] Configuration Probe report could not be created')
			If Not $TestRunAutomated Then
				MsgBox(48, $ScriptName, 'Configuration Probe could not create its report.')
			EndIf
			_DebugSessionEnd('configuration-probe-report-failure')
			Exit(11)
		EndIf

		_DebugWrite('[PASS] [TestRun] Configuration Probe report=' & $sProbeReport)
		If Not $TestRunAutomated Then
			Local $sProbeComplete
			If $Lang = 'it' Then
				$sProbeComplete = 'Analisi configurazione completata.'
			Else
				$sProbeComplete = 'Configuration Probe completed.'
			EndIf
			$sProbeComplete &= @CRLF & @CRLF & _
					'PASS=' & $iProbePass & @CRLF & _
					'FAIL=' & $iProbeFail & @CRLF & _
					'WARN=' & $iProbeWarn & @CRLF & _
					'NOT USED=' & $iProbeNotUsed & @CRLF & @CRLF & $sProbeReport
			MsgBox(64, $ScriptName, $sProbeComplete)
			ShellExecute($sProbeReport)
		EndIf

		_DebugSessionEnd('configuration-probe-complete')
		If $iProbeFail > 0 Then Exit(10)
		Exit

	Case 'trace'
		If Not _TestRunConfirm($TestRun, $ScriptName, $Lang) Then
			_DebugWrite('[SKIP] [TestRun] Mode=' & $TestRun & ' (reason=user cancelled confirmation)')
			_DebugSessionEnd('test-run-confirmation-cancelled')
			Exit
		EndIf

		Local $bTracePrepared = _TracePrepare($ScriptName, $Lang)
		Local $iTracePrepareError = @error
		If Not $bTracePrepared Then
			If $iTracePrepareError = 1 Then
				_DebugWrite('[SKIP] [TestRun] Mode=trace (reason=Process Monitor unavailable and user cancelled)')
				_DebugSessionEnd('trace-without-procmon-cancelled')
				Exit
			EndIf

			Local $sTracePrepareFailure
			Select
				Case $Lang = 'it'
					$sTracePrepareFailure = 'Impossibile creare la cartella o il registro della Traccia applicazione.'
				Case Else
					$sTracePrepareFailure = 'Application Trace could not create its session folder or debug log.'
			EndSelect
			MsgBox(48, $ScriptName, $sTracePrepareFailure)
			_DebugSessionEnd('trace-prepare-failure')
			Exit(12)
		EndIf

	Case 'full'
		If Not $TestRunAutomated And Not _TestRunConfirm($TestRun, $ScriptName, $Lang) Then
			_DebugWrite('[SKIP] [TestRun] Mode=' & $TestRun & ' (reason=user cancelled confirmation)')
			_DebugSessionEnd('test-run-confirmation-cancelled')
			Exit
		EndIf

		Local $sFullReport = '', $sFullWorkspace = ''
		Local $iFullPass = 0, $iFullFail = 0, $iFullWarn = 0
		Local $iFullSkip = 0, $iFullNotUsed = 0
		Local $bFullCompleted = _FullTestRun($ScriptIni, $sFullReport, $sFullWorkspace, _
				$iFullPass, $iFullFail, $iFullWarn, $iFullSkip, $iFullNotUsed)

		If Not $TestRunAutomated Then
			Local $sFullComplete
			If $Lang = 'it' Then
				$sFullComplete = 'Test completo X-Launcher terminato.'
			Else
				$sFullComplete = 'Full X-Launcher Test completed.'
			EndIf
			$sFullComplete &= @CRLF & @CRLF & _
					'PASS=' & $iFullPass & @CRLF & _
					'FAIL=' & $iFullFail & @CRLF & _
					'WARN=' & $iFullWarn & @CRLF & _
					'SKIP=' & $iFullSkip & @CRLF & _
					'NOT USED=' & $iFullNotUsed & @CRLF
			If $iFullFail > 0 And $sFullWorkspace <> '' Then
				$sFullComplete &= @CRLF & 'Preserved workspace: ' & $sFullWorkspace & @CRLF
			EndIf
			$sFullComplete &= @CRLF & $sFullReport
			MsgBox(64, $ScriptName, $sFullComplete)
			If FileExists($sFullReport) Then ShellExecute($sFullReport)
		EndIf

		_DebugSessionEnd('full-test-complete')
		If Not $bFullCompleted Or $iFullFail > 0 Then Exit(13)
		Exit
	Case Else
		Local $sTestRunInvalid
		Select
			Case $Lang = 'it'
				$sTestRunInvalid = 'Valore TestRun non valido: "' & $TestRun & '".' & @CRLF & _
						'Usare false, Probe, Trace o Full.'
			Case Else
				$sTestRunInvalid = 'Invalid TestRun value: "' & $TestRun & '".' & @CRLF & _
						'Use false, Probe, Trace or Full.'
		EndSelect
		_DebugWrite('[FAIL] [TestRun] Invalid value=' & $TestRun)
		MsgBox(48, $ScriptName, $sTestRunInvalid)
		_DebugSessionEnd('invalid-test-run')
		Exit(9)
EndSwitch

; Registry view
$RegView = IniRead($GlobalConfig, 'Options', 'RegView', 'Native')
$RegView = IniRead($ScriptIni, 'Options', 'RegView', $RegView)
$RegView = StringUpper(StringStripWS($RegView, 3))
Switch $RegView
	Case '32'
	Case '64'
	Case 'AUTO'
	Case Else
		$RegView = 'Native'
EndSwitch
_DebugWrite("--> RegView=" & $RegView)

; Recover any registry transaction left unfinished by a crash, forced
; termination or power loss before allowing a new transaction to begin.
Local $vRegistryRecoveryResult = _RegRecoverPending($Temp & '\Regedit')
Local $iRegistryRecoveryError = @error
Local $iRegistryRecoveryExtended = @extended
_DebugOperationResult('Startup', 'RegistryRecovery', $Temp & '\Regedit', _
		$vRegistryRecoveryResult, $iRegistryRecoveryError, $iRegistryRecoveryExtended)
If Not $vRegistryRecoveryResult Then
	_DebugWrite(">>>>>> Registry recovery failed - launcher stopped")
	_DebugSessionEnd('registry-recovery-failure')
	Exit(7)
EndIf

; Force RunWait only when end-of-run cleanup is required
If $RunWait <> 'true' And _RunWaitCleanupRequired($ScriptIni) Then
	$RunWait = 'true'
	_DebugWrite("===== RunWait forced true: end-of-run cleanup is required =====")
EndIf

; An explicitly confirmed Trace must remain active through application exit and
; all configured cleanup so its report represents the complete launcher session.
If $TraceActive And $RunWait <> 'true' Then
	$RunWait = 'true'
	_DebugWrite('[INFO] [Trace] RunWait forced true for complete lifecycle logging')
EndIf

; force Log if debug status is on
If $Debug = 'true' and $WriteLog = 'false' Then $WriteLog = 'true'

; ------------------------------------------------------------------------------
; Merge Global and User Preferences
; ------------------------------------------------------------------------------
If  $ShowSplash='true' and $PackShowSplash='false' Then
    $ShowSplash='false'
EndIf	
If  $ShowTrayTip='true' and $PackShowTrayTip='false' Then
    $ShowTrayTip='false'
EndIf     

; ------------------------------------------------------------------------------
; First Run Operations
; ------------------------------------------------------------------------------
Local $_errfirstrun
If $FirstRun = 'true' Then
	_FirstRun()
	If @error <> 0 Then
		_DebugWrite("[FirstRunOperations] : error")
		Select
			Case $Lang = 'it'
				$_errfirstrun = '"' & @ScriptName & '"' & @CRLF & 'Errore durante la prima esecuzione' & @CRLF & 'Si prega di riprovare'
			Case Else
				$_errfirstrun = '"' & @ScriptName & '"' & @CRLF & 'Error during first run operations' & @CRLF & 'Please retry'
		EndSelect
		MsgBox(48, $ScriptName, $_errfirstrun)
		_DebugSessionEnd('first-run-failure')
		Exit (3)
	EndIf
EndIf

; ------------------------------------------------------------------------------
; FileToRun
; ------------------------------------------------------------------------------
$sJBak = $Lib & "\Java\old_java"
Local $sJavaMode = IniRead($ScriptIni, 'Options', 'Java', 'false')
$Java = _JavaCheck($AppName, $ScriptIni, $Lib, $Root)
Local $iJavaCheckError = @error
Local $iJavaCheckExtended = @extended
_DebugJavaSelectionResult($sJavaMode, $Java, $Lib & '\Java', $iJavaCheckError, $iJavaCheckExtended)
If $iJavaCheckError <> 0 Then
	_DebugWrite("[JavaGet] : result code=" & $iJavaCheckError)
	If IniRead($ScriptIni, 'Options', 'Java', 'false') = 'true' Then
		If $iJavaCheckError = 5 Then
			Local $_javaMissing
			Select
				Case $Lang = 'it'
					$_javaMissing = "Java richiesto non trovato." & @CRLF & _
							"Controllare JavaPath=<runtime Java esistente>, aggiungere JavaURL=<URL diretto del pacchetto> in [Options]," & @CRLF & _
							"oppure inserire un pacchetto Java in Lib\Java\setup."
				Case Else
					$_javaMissing = "Required Java was not found." & @CRLF & _
							"Check JavaPath=<existing Java runtime>, add JavaURL=<direct package URL> under [Options]," & @CRLF & _
							"or place a Java package in Lib\Java\setup."
			EndSelect
			MsgBox(48, $ScriptName, $_javaMissing)
		ElseIf $iJavaCheckError = 6 Then
			Local $_javaURLInvalid
			Select
				Case $Lang = 'it'
					$_javaURLInvalid = "JavaURL non valido. Usare un URL diretto HTTP o HTTPS del pacchetto Java."
				Case Else
					$_javaURLInvalid = "Invalid JavaURL. Use a direct HTTP or HTTPS Java package URL."
			EndSelect
			MsgBox(48, $ScriptName, $_javaURLInvalid)
		EndIf
		_DebugSessionEnd('java-failure')
		Exit(8)
	EndIf
EndIf
$WorkingDir = _FullPath(IniRead($ScriptIni, 'FileToRun', 'WorkingDir', ''), $Root)
$PathToExe = _ResolvePathToExe(IniRead($ScriptIni, 'FileToRun', 'PathToExe', ''), _
		$WorkingDir, $Root, @ScriptDir)

; Resolve automatic registry view from the application executable.
; Nothing is written back to the INI, so application architecture changes
; are detected automatically on later launches.
If $RegView = 'AUTO' Then
	Local $sDetectedRegView = _RegViewDetectExecutable($PathToExe)

	Switch $sDetectedRegView
		Case '32', '64'
			$RegView = $sDetectedRegView
			_DebugWrite("===== RegView Auto detected " & $RegView & "-bit application: " & $PathToExe & " =====")

		Case Else
			$RegView = 'Native'
			_DebugWrite("===== RegView Auto could not determine application bitness - using Native: " & $PathToExe & " =====")
	EndSwitch
EndIf

; Exe's details
$ExeDir = _FileInfo($PathToExe, 0)
$ExeName = _FileInfo($PathToExe, 1)
_DebugSessionMetadata()

; Virtual Machine
$VirtualMachine = False
If $ExeName = "javaw.exe" Then $VirtualMachine = True

; Register exit handler for modern AutoIt. Trace registers it earlier so that
; preparation and startup failures still receive a final report.
If Not $ExitHandlerRegistered Then
	OnAutoItExitRegister("OnAutoItExit")
	$ExitHandlerRegistered = True
EndIf

; ------------------------------------------------------------------------------
; Status
; ------------------------------------------------------------------------------
$IsClosing = IniRead($TempLog, 'Status', 'IsClosing', '')
$IsRunning = IniRead($TempLog, 'Status', 'IsRunning', '')
If ProcessExists($ExeName) = 0 Then $IsRunning = 'false'

; Warning messages
Select
	Case $Lang = 'it'
		$CheckIni = 'Si prega di controllare le opzioni in ' & '"' & $ScriptIni & '".'
		$FileNotFound = 'ERRORE! "' & $PathToExe & '"' & ' non trovato!'
		$AlreadyRunning = '"' & $AppName & '" è già in esecuzione.'
		$StillClosing = '"' & $AppName & '" è ancora in chiusura.'
	Case Else
		$CheckIni = 'Please check options in ' & '"' & $ScriptIni & '".'
		$FileNotFound = 'ERROR! "' & $PathToExe & '"' & ' not found!'
		$AlreadyRunning = '"' & $AppName & '" is already running.'
		$StillClosing = '"' & $AppName & '" is still closing.'
EndSelect

; Check File To Run
If Not FileExists($PathToExe) And Not $VirtualMachine Then
	_DebugWrite(">>>>>> Stopped - File To Run Error=" & $PathToExe)
	MsgBox(48, $ScriptName, $FileNotFound)
	MsgBox(48, $ScriptName, $CheckIni)
	RunWait(@ComSpec & ' /c "' & $ScriptIni & '"', '', @SW_HIDE)
	Exit (2)
EndIf

; Previous istance still performing closing operations
If $IsClosing = 'true' and _ProcessExistsOther() Then
	_DebugWrite(">>>>>>  Stopped - Previous istance still Closing")
	MsgBox(48, $ScriptName, $StillClosing)
	Exit (3)
EndIf

; Multiple instances for Virtual Machine
If $VirtualMachine Then
	If $Cmd1 = 2 Then $MultipleInstances = 'false'
	If $IsRunning = 'true' And $MultipleInstances = 'false' Then
		_DebugWrite("===== " & $ScriptName & " === secondary running stopped - MultipleInstances not allowed (Virtual Machine) =====")
		MsgBox(48, $ScriptName, $AlreadyRunning)
		Exit (4)
	EndIf

	; Multiple instances
ElseIf $MultipleInstances = 'false' Then
	AutoItSetOption('WinTitleMatchMode', 2)
	$WinGetProcess = IniRead($ScriptIni, 'FileToRun', 'WinGetProcess', '')
	Select
		Case $WinGetProcess = ''
			If ProcessExists($ExeName) Then
				_DebugWrite("===== " & $ScriptName & " === secondary running stopped - MultipleInstances not allowed =====")
				MsgBox(48, $ScriptName, $AlreadyRunning)
				Exit (4)
			EndIf
		Case Else
			If WinGetProcess($WinGetProcess) <> -1 Then
				_DebugWrite("=====  " & $ScriptName & " === secondary running stopped - MultipleInstances not allowed (WinGetProcess) =====")
				MsgBox(48, $ScriptName, $AlreadyRunning)
				Exit (4)
			EndIf
	EndSelect
EndIf

; ------------------------------------------------------------------------------
;  Working files
; ------------------------------------------------------------------------------
; Create working dir
DirCreate($Root)
DirCreate($Temp)

; Install default files
_DebugWrite("Installing default files")
_DefaultInstall($Temp, $Lang)

; ------------------------------------------------------------------------------
; Log
; ------------------------------------------------------------------------------
If $TraceActive Then
	$Log = $TraceSettingsPath
Else
	$Log = @ScriptDir & '\' & $ScriptName & '.log'
EndIf

If $WriteLog = 'true' Then
	IniWrite($Log, 'Setup', 'AppName', $AppName)
	IniWrite($Log, 'Setup', 'AppVer', $AppVer)
	IniWrite($Log, 'Setup', 'UserName', $UserName)
	IniWrite($Log, 'Setup', 'Profile', $Profile)
	IniWrite($Log, 'Setup', 'ScriptName', $ScriptName)
	IniWrite($Log, 'Setup', 'Lang', $Lang)
	IniWrite($Log, 'FileSystem', 'Root', $Root)
	IniWrite($Log, 'FileSystem', 'Temp', $Temp)
	IniWrite($Log, 'FileSystem', 'Cache', $Cache)
	IniWrite($Log, 'FileSystem', 'Home', $Home)
	IniWrite($Log, 'FileSystem', 'Bin', $Bin)
	IniWrite($Log, 'FileSystem', 'Lib', $Lib)
	IniWrite($Log, 'FileSystem', 'Doc', $Doc)
	IniWrite($Log, 'FileSystem', 'Backup', $Backup)
	IniWrite($Log, 'FileSystem', 'Download', $Download)
	IniWrite($Log, 'FileToRun', 'WorkingDir', $WorkingDir)
	IniWrite($Log, 'FileToRun', 'PathToExe', $PathToExe)
	IniWrite($Log, 'FileToRun', 'ExeDir', $ExeDir)
	IniWrite($Log, 'FileToRun', 'ExeName', $ExeName)
	IniWrite($Log, 'Environment', 'DRIVE', $Drive)
	IniWrite($Log, 'Environment', 'TEMP', $Temp)
	IniWrite($Log, 'Environment', 'LANG', $Lang)
	IniWrite($Log, 'Local', 'AppData', $LocalAppData)
	IniWrite($Log, 'Local', 'Settings', $LocalSettings)
	IniWrite($Log, 'Appl', 'Java', $Java)
	If FileExists($Java & "\bin\javaw.exe") Then
		IniWrite($Log, 'Appl', 'JavaVer', FileGetVersion($Java & "\bin\javaw.exe"))
	Else	
		IniWrite($Log, 'Appl', 'JavaVer', '')
	EndIf
EndIf

; ------------------------------------------------------------------------------
; SplashScreen
; ------------------------------------------------------------------------------

; Image
$Image = _IniReadPlus($ScriptIni, 'SplashScreen', 'Image', '')
$Image = _FullPath($Image, $Root)

; Title
$Title_SS = _IniReadPlus($ScriptIni, 'SplashScreen', 'Title', '')

; Timeout
$TimeOut_SS = _IniReadPlus($ScriptIni, 'SplashScreen', 'TimeOut', '')

Select
	Case StringIsDigit($TimeOut_SS)
	Case Else
		$TimeOut_SS = '3000'
EndSelect

Local $Width_SS = _IniReadPlus($ScriptIni, 'SplashScreen', 'Width', '')
Local $Height_SS = _IniReadPlus($ScriptIni, 'SplashScreen', 'Height', '')

; ------------------------------------------------------------------------------
; TrayTip
; ------------------------------------------------------------------------------

; Title
$Title_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'Title', $ScriptName)

; Timeout
$TimeOut_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'Timeout', '')
If $TimeOut_TT = '' Then $TimeOut_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'TimeOut ', '')
Select
	Case StringIsDigit($TimeOut_TT)
	Case Else
		$TimeOut_TT = '5000'
EndSelect

; ------------------------------------------------------------------------------
; Get Environmental Variables
; ------------------------------------------------------------------------------
Local $vEnvironmentResult, $iEnvironmentError, $iEnvironmentExtended
Local $sFixedAppDataName = '', $sFixedDesktopName = ''
Local $sFixedDocumentsName = '', $sFixedFavoritesName = ''

; FixAppData uses the host shell-folder leaf names. Capture them before the
; portable LOCALAPPDATA, TEMP and TMP variables can affect AutoIt's macros.
If $FixAppData = 'true' Then
	$sFixedAppDataName = _DirName(@AppDataDir)
	$sFixedDesktopName = _DirName(@DesktopDir)
	$sFixedDocumentsName = _DirName(@MyDocumentsDir)
	$sFixedFavoritesName = _DirName(@FavoritesDir)
EndIf

; Apply the simple portable defaults first. Any matching value explicitly
; configured in [Environment] is processed below and therefore takes priority.
If $FixLocalAppData = 'true' Or $FixTemp = 'true' Then _
		_SetPortableEnvironmentDefaults($FixLocalAppData, $FixTemp, $Lib, $WriteLog, $Log)

$_environment = IniReadSection($ScriptIni, 'Environment')
If Not @error Then
	_DebugWrite("[Environment] : about to execute")
	For $e = 1 To $_environment[0][0]
		_DebugWrite("--> " & $_environment[$e][0] & "=" & $_environment[$e][1])
		Select
			Case $_environment[$e][0] = 'USERPROFILE'
				$UserProfile = _FullPath($_environment[$e][1], $Root)
				$vEnvironmentResult = EnvSet('USERPROFILE', $UserProfile)
				$iEnvironmentError = @error
				$iEnvironmentExtended = @extended
				_DebugEnvironmentResult('USERPROFILE', $_environment[$e][1], $UserProfile, _
						$vEnvironmentResult, $iEnvironmentError, $iEnvironmentExtended)
				If $WriteLog = 'true' Then IniWrite($Log, 'Environment', 'USERPROFILE', $UserProfile)
				If $FixAppData = 'true' Then

					; Fix AppData
					$AppData = $sFixedAppDataName
					$vEnvironmentResult = _FixUserProfile($UserProfile, $AppData, 'AppData')
					$iEnvironmentError = @error
					$iEnvironmentExtended = @extended
					_DebugOperationResult('Environment', 'FixUserProfile', _
							$UserProfile & '\' & $AppData, $vEnvironmentResult, _
							$iEnvironmentError, $iEnvironmentExtended)
					If $iEnvironmentError = 0 And $vEnvironmentResult = 1 Then
						$vEnvironmentResult = EnvSet('APPDATA', $UserProfile & '\' & $AppData)
						$iEnvironmentError = @error
						$iEnvironmentExtended = @extended
						_DebugEnvironmentResult('APPDATA', $UserProfile & '\' & $AppData, _
								$UserProfile & '\' & $AppData, $vEnvironmentResult, _
								$iEnvironmentError, $iEnvironmentExtended)
						If $WriteLog = 'true' Then _
								IniWrite($Log, 'Environment', 'APPDATA', $UserProfile & '\' & $AppData)
					EndIf

					; Fix Desktop
					$Desktop = $sFixedDesktopName
					$vEnvironmentResult = _FixUserProfile($UserProfile, $Desktop, 'Desktop')
					$iEnvironmentError = @error
					$iEnvironmentExtended = @extended
					_DebugOperationResult('Environment', 'FixUserProfile', _
							$UserProfile & '\' & $Desktop, $vEnvironmentResult, _
							$iEnvironmentError, $iEnvironmentExtended)
					If $iEnvironmentError = 0 And $vEnvironmentResult = 1 Then _
							DirCreate($UserProfile & '\' & $Desktop)

					; Fix Documents
					$Documents = $sFixedDocumentsName
					$vEnvironmentResult = _FixUserProfile($UserProfile, $Documents, 'Documents')
					$iEnvironmentError = @error
					$iEnvironmentExtended = @extended
					_DebugOperationResult('Environment', 'FixUserProfile', _
							$UserProfile & '\' & $Documents, $vEnvironmentResult, _
							$iEnvironmentError, $iEnvironmentExtended)
					If $iEnvironmentError = 0 And $vEnvironmentResult = 1 Then _
							DirCreate($UserProfile & '\' & $Documents)

					; Fix Favorites
					$Favorites = $sFixedFavoritesName
					$vEnvironmentResult = _FixUserProfile($UserProfile, $Favorites, 'Favorites')
					$iEnvironmentError = @error
					$iEnvironmentExtended = @extended
					_DebugOperationResult('Environment', 'FixUserProfile', _
							$UserProfile & '\' & $Favorites, $vEnvironmentResult, _
							$iEnvironmentError, $iEnvironmentExtended)

				EndIf
			Case $_environment[$e][0] = 'PATH'
				$vEnvironmentResult = _SetPath($_environment[$e][1], $WriteLog, $Log)
				$iEnvironmentError = @error
				$iEnvironmentExtended = @extended
				_DebugEnvironmentResult('PATH', $_environment[$e][1], EnvGet('PATH'), _
						$vEnvironmentResult, $iEnvironmentError, $iEnvironmentExtended)
			Case Else
				$vEnvironmentResult = _SetEnv($_environment[$e][0], $_environment[$e][1], $WriteLog, $Log)
				$iEnvironmentError = @error
				$iEnvironmentExtended = @extended
				_DebugEnvironmentResult($_environment[$e][0], $_environment[$e][1], _
						EnvGet($_environment[$e][0]), $vEnvironmentResult, _
						$iEnvironmentError, $iEnvironmentExtended)
		EndSelect
	Next
	_DebugWrite("[Environment] : executed")
EndIf

; ------------------------------------------------------------------------------
; Functions
; ------------------------------------------------------------------------------
Local $vFunctionResult, $iFunctionError, $iFunctionExtended
$_functions = IniReadSection($ScriptIni, 'Functions')
If Not @error Then
	_DebugWrite("[Functions] : about to execute")
	For $f = 1 To $_functions[0][0]
		_DebugWrite("--> " & $_functions[$f][0] & "=" & $_functions[$f][1])
		$vFunctionResult = 0
		$iFunctionError = 0
		$iFunctionExtended = 0
		Select
			Case $_functions[$f][1] = ''
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'DirCopy'
				$vFunctionResult = _DirCopy($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'DirCreate'
				$vFunctionResult = _DirCreate($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'DirMove'
				$vFunctionResult = _DirMove($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'DirRemove'
				$vFunctionResult = _DirRemove($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'FileCopy'
				$vFunctionResult = _FileCopy($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'FileCreate'
				$vFunctionResult = _FileCreatePlus($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'FileDelete'
				$vFunctionResult = _FileDelete($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'FileMove'
				$vFunctionResult = _FileMove($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'AddFonts'
				$vFunctionResult = _AddFonts($_functions[$f][1])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case $_functions[$f][0] = 'Junctions' Or $_functions[$f][0] = 'SymLinks'
				$vFunctionResult = _LinkCreate($_functions[$f][1], $_functions[$f][0])
				$iFunctionError = @error
				$iFunctionExtended = @extended
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
			Case Else
				_DebugOperationResult('Functions', $_functions[$f][0], $_functions[$f][1], _
						$vFunctionResult, $iFunctionError, $iFunctionExtended)
		EndSelect
	Next
	_DebugWrite("[Functions] : executed")
EndIf

; ------------------------------------------------------------------------------
; Sections
; ------------------------------------------------------------------------------
Local $vSectionResult, $iSectionError, $iSectionExtended, $iSectionReadError
_DebugWrite("[Sections] : about to execute")
$_sections = IniReadSectionNames($ScriptIni)
For $i = 1 To $_sections[0]
	$_file = StringSplit($_sections[$i], '=')
	If Not @error Then
		_DebugWrite("--> " & $_file[1] & "=" & $_file[2])
		AutoItSetOption('ExpandEnvStrings', 0)
		AutoItSetOption('ExpandVarStrings', 0)
		$_values = IniReadSection($ScriptIni, $_sections[$i])
		$iSectionReadError = @error
		AutoItSetOption('ExpandEnvStrings', 1)
		AutoItSetOption('ExpandVarStrings', 1)
		Select
			Case $_file[1] = 'StringReplace'
				If $iSectionReadError = 0 Then
					Local $FileList
					$FileList=_ExpandMultiPath($_file[2], True)
					If $FileList[0] > 0 Then
						For $IxElem = 1 To $FileList[0]
							Local $FileToRewrite, $_delimiters, $overwrite = False
							$FileToRewrite = $FileList[$IxElem]
							For $k = 1 To $_values[0][0]
								$_delimiters = StringSplit($_values[$k][0], '|')
								If $_delimiters[0] = 3 And $_delimiters[3] = 'o' Then $overwrite = True
								$vSectionResult = _StringReplace($FileToRewrite, $_delimiters[1], $_delimiters[2], _
										_FullPathPlus($_values[$k][1]), $overwrite)
								$iSectionError = @error
								$iSectionExtended = @extended
								_DebugOperationResult('Sections', 'StringReplace', _
										$FileToRewrite & '|' & $_values[$k][0], _
										$vSectionResult, $iSectionError, $iSectionExtended)
							Next
						Next
					Else
						_DebugOperationResult('Sections', 'StringReplace', $_file[2], 0, 0, 0)
					EndIf
				Else
					_DebugOperationResult('Sections', 'StringReplace', $_file[2], 0, $iSectionReadError, 0)
				EndIf
			Case $_file[1] = 'StringRegExpReplace'
				If $iSectionReadError = 0 Then
					Local $FileList
					$FileList=_ExpandMultiPath($_file[2], True)
					If $FileList[0] > 0 Then
						AutoItSetOption('ExpandEnvStrings', 0)
						AutoItSetOption('ExpandVarStrings', 0)
						For $IxElem = 1 To $FileList[0]
							Local $FileToRewrite
							$FileToRewrite = $FileList[$IxElem]
							For $k = 1 To $_values[0][0]
								$vSectionResult = _StringRegExpReplace($FileToRewrite, $_values[$k][1], $_values[$k][0])
								$iSectionError = @error
								$iSectionExtended = @extended
								_DebugOperationResult('Sections', 'StringRegExpReplace', _
										$FileToRewrite & '|' & $_values[$k][0], _
										$vSectionResult, $iSectionError, $iSectionExtended)
							Next
						Next
						AutoItSetOption('ExpandEnvStrings', 1)
						AutoItSetOption('ExpandVarStrings', 1)
					Else
						_DebugOperationResult('Sections', 'StringRegExpReplace', $_file[2], 0, 0, 0)
					EndIf
				Else
					_DebugOperationResult('Sections', 'StringRegExpReplace', $_file[2], 0, $iSectionReadError, 0)
				EndIf
			Case $_file[1] = 'WriteToFile'
				If $iSectionReadError = 0 Then
					Local $FileToWrite
					$FileToWrite = _FullPath($_file[2], $Root)
					For $k = 1 To $_values[0][0]
						$vSectionResult = _WriteToFile($FileToWrite, $_values[$k][0], $_values[$k][1])
						$iSectionError = @error
						$iSectionExtended = @extended
						_DebugOperationResult('Sections', 'WriteToFile', _
								$FileToWrite & '|' & $_values[$k][0], _
								$vSectionResult, $iSectionError, $iSectionExtended)
					Next
				Else
					_DebugOperationResult('Sections', 'WriteToFile', $_file[2], 0, $iSectionReadError, 0)
				EndIf
			Case $_file[1] = 'WriteToIni'
				If $iSectionReadError = 0 Then
					Local $IniFile, $_stw
					$IniFile = _FullPath($_file[2], $Root)
					For $k = 1 To $_values[0][0]
						$_stw = StringSplit($_values[$k][0], '|')
						$vSectionResult = IniWrite($IniFile, $_stw[1], $_stw[2], _FullPathPlus($_values[$k][1]))
						$iSectionError = @error
						$iSectionExtended = @extended
						_DebugOperationResult('Sections', 'WriteToIni', _
								$IniFile & '|' & $_values[$k][0], _
								$vSectionResult, $iSectionError, $iSectionExtended)
					Next
				Else
					_DebugOperationResult('Sections', 'WriteToIni', $_file[2], 0, $iSectionReadError, 0)
				EndIf
			Case $_file[1] = 'WriteToPref'
				If $iSectionReadError = 0 Then
					Local $PrefsFile, $Format, $_begin, $_mid, $_end, $Begin, $Mid, $End
					$PrefsFile = _FullPath($_file[2], $Root)
					$Format = $_values[1][1]
					$_begin = StringSplit($Format, '[PREF]', 1)
					$_mid = StringSplit($_begin[2], '[VALUE]', 1)
					$_end = StringSplit($Format, '[VALUE]', 1)
					$Begin = $_begin[1]
					$Mid = $_mid[1]
					If $_end[0] = 2 Then
						$End = $_end[2]
					Else
						$End = ''
					EndIf
					For $k = 2 To $_values[0][0]
						$vSectionResult = _WriteToPref($PrefsFile, $Begin, $Mid, $End, _
								$_values[$k][0], _FullPathPlus($_values[$k][1]))
						$iSectionError = @error
						$iSectionExtended = @extended
						_DebugOperationResult('Sections', 'WriteToPref', _
								$PrefsFile & '|' & $_values[$k][0], _
								$vSectionResult, $iSectionError, $iSectionExtended)
					Next
				Else
					_DebugOperationResult('Sections', 'WriteToPref', $_file[2], 0, $iSectionReadError, 0)
				EndIf
			Case $_file[1] = 'WriteToReg'
				If $iSectionReadError = 0 Then
					Local $RegFile, $MainKey, $_stw
					$RegFile = _FullPath($_file[2], $Root)
					$MainKey = $_values[1][1]
					$vSectionResult = _WriteToReg($RegFile, $MainKey, '', '', '')
					$iSectionError = @error
					$iSectionExtended = @extended
					_DebugOperationResult('Sections', 'WriteToReg', $RegFile & '|header', _
							$vSectionResult, $iSectionError, $iSectionExtended)
					For $k = 2 To $_values[0][0]
						$_stw = StringSplit($_values[$k][0], '|')
						Select
							Case $_stw[0] = 1
								$vSectionResult = _WriteToReg($RegFile, $MainKey, '', $_stw[1], $_values[$k][1])
								$iSectionError = @error
								$iSectionExtended = @extended
								_DebugOperationResult('Sections', 'WriteToReg', _
										$RegFile & '|' & $_values[$k][0], _
										$vSectionResult, $iSectionError, $iSectionExtended)
							Case $_stw[0] = 2
								$vSectionResult = _WriteToReg($RegFile, $MainKey, $_stw[1], $_stw[2], $_values[$k][1])
								$iSectionError = @error
								$iSectionExtended = @extended
								_DebugOperationResult('Sections', 'WriteToReg', _
										$RegFile & '|' & $_values[$k][0], _
										$vSectionResult, $iSectionError, $iSectionExtended)
							Case Else
								_DebugOperationResult('Sections', 'WriteToReg', _
										$RegFile & '|' & $_values[$k][0], 0, 4, 0)
						EndSelect
					Next
				Else
					_DebugOperationResult('Sections', 'WriteToReg', $_file[2], 0, $iSectionReadError, 0)
				EndIf
			Case Else
				_DebugOperationResult('Sections', $_file[1], $_file[2], 0, 0, 0)
		EndSelect
	EndIf
Next
_DebugWrite("[Sections] : executed")

; ------------------------------------------------------------------------------
; RunBefore
; ------------------------------------------------------------------------------
Local $vRunBeforeResult, $iRunBeforeError, $iRunBeforeExtended
$_runbefore = IniReadSection($ScriptIni, 'RunBefore')
If Not @error Then
	_DebugWrite("[RunBefore] : about to execute")
	For $rb = 1 To $_runbefore[0][0]
		_DebugWrite("--> " & $_runbefore[$rb][0] & "=" & $_runbefore[$rb][1])
		$vRunBeforeResult = 0
		$iRunBeforeError = 0
		$iRunBeforeExtended = 0
		Select
			Case $_runbefore[$rb][1] = ''
				_DebugOperationResult('RunBefore', $_runbefore[$rb][0], $_runbefore[$rb][1], _
						$vRunBeforeResult, $iRunBeforeError, $iRunBeforeExtended)
			Case $_runbefore[$rb][0] = 'FixDriveLetter'
				$vRunBeforeResult = _FixDriveLetter($_runbefore[$rb][1], $Root)
				$iRunBeforeError = @error
				$iRunBeforeExtended = @extended
				_DebugOperationResult('RunBefore', $_runbefore[$rb][0], $_runbefore[$rb][1], _
						$vRunBeforeResult, $iRunBeforeError, $iRunBeforeExtended)
			Case $_runbefore[$rb][0] = 'Regedit'
				If $IsRunning <> 'true' Then
					$vRunBeforeResult = _RegFileInstall($_runbefore[$rb][1], $Temp & '\Regedit\backup' & $rb)
					$iRunBeforeError = @error
					$iRunBeforeExtended = @extended
					_DebugOperationResult('RunBefore', $_runbefore[$rb][0], $_runbefore[$rb][1], _
							$vRunBeforeResult, $iRunBeforeError, $iRunBeforeExtended)
					If Not $vRunBeforeResult Then
						_DebugWrite(">>>>>> Registry installation aborted - host backup failed")
						Exit(6)
					EndIf
				Else
					_DebugWrite("[SKIP] [RunBefore] Regedit=" & $_runbefore[$rb][1] & _
							" (reason=portable registry already active)")
				EndIf
			Case $_runbefore[$rb][0] = 'RunFile'
				$vRunBeforeResult = _RunWait($_runbefore[$rb][1], $Root)
				$iRunBeforeError = @error
				$iRunBeforeExtended = @extended
				_DebugOperationResult('RunBefore', $_runbefore[$rb][0], $_runbefore[$rb][1], _
						$vRunBeforeResult, $iRunBeforeError, $iRunBeforeExtended)
			Case Else
				_DebugOperationResult('RunBefore', $_runbefore[$rb][0], $_runbefore[$rb][1], _
						$vRunBeforeResult, $iRunBeforeError, $iRunBeforeExtended)
		EndSelect
	Next
	_DebugWrite("[RunBefore] : executed")
EndIf

; ------------------------------------------------------------------------------
; FileToRun
; ------------------------------------------------------------------------------

; Parameters
$Parameters = IniRead($ScriptIni, 'FileToRun', 'Parameters', '')
If $Parameters <> '' Then
	Select
		Case StringLeft($Parameters, 1) = '-' Or StringLeft($Parameters, 1) = '/'
			$Parameters = ' ' & $Parameters
		Case Else
			$Parameters = ' "' & $Parameters & '"'
	EndSelect
EndIf

; CommandLine
$Cmd = ''
If $CmdLine[0] >= $Cmd1 Then
	For $i = $Cmd1 To $CmdLine[0]
		Local $sForwardArgument = StringLower($CmdLine[$i])
		If $sForwardArgument = '--x-launcher-test' Or _
				StringLeft($sForwardArgument, 18) = '--x-launcher-test=' Or _
				$sForwardArgument = '--x-launcher-test-automated' Or _
				StringLeft($sForwardArgument, StringLen('--x-launcher-selftest-helper=')) = _
				'--x-launcher-selftest-helper=' Then ContinueLoop
		$Cmd &= ' ' & _CommandLineQuoteArgument($CmdLine[$i])
	Next
EndIf

; ChangeDir
$StringToExe = '"' & $PathToExe & '"' & $Parameters & $Cmd
If $WorkingDir <> '' And FileExists($WorkingDir) Then
	FileChangeDir($WorkingDir)
Else
	FileChangeDir($ExeDir)
EndIf

; Write Log
If $WriteLog = 'true' Then
	IniWrite($Log, 'FileToRun', 'StringToExe', $StringToExe)
EndIf

; Remember same-name processes that existed before this portable session.
If Not $VirtualMachine And $IsRunning <> 'true' Then
	$ExistingProcessPIDs = _ProcessGetPIDs($ExeName)
EndIf

IniWrite($TempLog, 'Status', 'IsRunning', 'true')

; Show TrayTip - default timeout 3 seconds
If $ShowTrayTip = 'true' And $IsRunning <> 'true' Then
	_DebugWrite("[TrayTip] : executing")
	$TrayTipOn = _TrayTipOn($Title_TT, $TimeOut_TT)
EndIf

; Show Splash Screen
If $ShowSplash = 'true' And $IsRunning <> 'true' Then
	_DebugWrite("[SplashScreen] : executing")
	_SplashScreen($Title_SS, $Image, $TimeOut_SS, $Temp, $Root, $Width_SS, $Height_SS)
EndIf

Local $vApplicationRunResult, $iApplicationRunError, $iApplicationRunExtended

; RunWait false
If $RunWait <> 'true' Then
	;Run($StringToExe)
	$vApplicationRunResult = _Run($PathToExe, $Parameters & $Cmd, $RunWait, $HideShellWindow)
	$iApplicationRunError = @error
	$iApplicationRunExtended = @extended
	_DebugApplicationLaunchResult($PathToExe, $RunWait, $vApplicationRunResult, _
			$iApplicationRunError, $iApplicationRunExtended)
	If $iApplicationRunError Then
		IniWrite($TempLog, 'Status', 'IsRunning', 'false')
		IniWrite($TempLog, 'Status', 'IsClosing', 'false')
		_DebugWrite(">>>>>> Stopped - File To Run Launch Error=" & $PathToExe)
		Exit (5)
	EndIf
	IniWrite($TempLog, 'Status', 'IsRunning', 'false')
	IniWrite($TempLog, 'Status', 'IsClosing', 'false')
	Local $vTempCleanupResult = 0, $iTempCleanupError = 0, $iTempCleanupExtended = 0
	If $DeleteTemp = 'true' Then
		$vTempCleanupResult = _DeleteTempSafe()
		$iTempCleanupError = @error
		$iTempCleanupExtended = @extended
	EndIf
	_DebugTempCleanupResult($DeleteTemp, $Temp, $vTempCleanupResult, _
			$iTempCleanupError, $iTempCleanupExtended)
	_DebugWrite("===== " & $ScriptName & " === exit RunWait false =====")
	_DebugWrite("================ " & $ScriptName & " === application ended ================")
	_DebugSessionEnd('runwait=false')
	Exit
EndIf

; Run Virtual Machine
If $VirtualMachine Then
	;RunWait($StringToExe)
	$vApplicationRunResult = _Run($PathToExe, $Parameters & $Cmd, $RunWait, $HideShellWindow)
	$iApplicationRunError = @error
	$iApplicationRunExtended = @extended
	_DebugApplicationLaunchResult($PathToExe, $RunWait, $vApplicationRunResult, _
			$iApplicationRunError, $iApplicationRunExtended)
	If $iApplicationRunError Then
		IniWrite($TempLog, 'Status', 'IsRunning', 'false')
		IniWrite($TempLog, 'Status', 'IsClosing', 'false')
		_DebugWrite(">>>>>> Stopped - File To Run Launch Error=" & $PathToExe)
		Exit (5)
	EndIf
	If $MultipleInstances <> 'false' Then
		If _ProcessExistsOther() Then
			_DebugWrite("===== " & $ScriptName & " === secondary running exit (Virtual Machine) =====")
			Exit
		EndIf
		_DebugWrite("===== " & $ScriptName & " === primary running exit (Virtual Machine) =====")
	EndIf

	; RunFile
ElseIf $IsRunning <> 'true' Then
	;RunWait($StringToExe)
	$vApplicationRunResult = _Run($PathToExe, $Parameters & $Cmd, $RunWait, $HideShellWindow)
	$iApplicationRunError = @error
	$iApplicationRunExtended = @extended
	_DebugApplicationLaunchResult($PathToExe, $RunWait, $vApplicationRunResult, _
			$iApplicationRunError, $iApplicationRunExtended)
	If $iApplicationRunError Then
		IniWrite($TempLog, 'Status', 'IsRunning', 'false')
		IniWrite($TempLog, 'Status', 'IsClosing', 'false')
		_DebugWrite(">>>>>> Stopped - File To Run Launch Error=" & $PathToExe)
		Exit (5)
	EndIf
	_DebugWrite("===== " & $ScriptName & " === primary running waiting for multiple program closing =====")
	While _ProcessExistsExcept($ExeName, $ExistingProcessPIDs)
		Sleep(250)
	WEnd
	_DebugWrite("===== " & $ScriptName & " === primary running exit =====")
Else
	;Run($StringToExe)
	$RunWait = 'false'
	$vApplicationRunResult = _Run($PathToExe, $Parameters & $Cmd, $RunWait, $HideShellWindow)
	$iApplicationRunError = @error
	$iApplicationRunExtended = @extended
	_DebugApplicationLaunchResult($PathToExe, $RunWait, $vApplicationRunResult, _
			$iApplicationRunError, $iApplicationRunExtended)
	If $iApplicationRunError Then
		IniWrite($TempLog, 'Status', 'IsRunning', 'false')
		IniWrite($TempLog, 'Status', 'IsClosing', 'false')
		_DebugWrite(">>>>>> Stopped - File To Run Launch Error=" & $PathToExe)
		Exit (5)
	EndIf
	_DebugWrite("===== " & $ScriptName & " === secondary running exit =====")
	Exit
EndIf


; ------------------------------------------------------------------------------
; RunAfter
; ------------------------------------------------------------------------------
_DebugWrite("===== closing application =====")

; Start closing operations
IniWrite($TempLog, 'Status', 'IsClosing', 'true')

; RunAfter Function
_XClose()

Func _CleanupCanonicalPath($sPath)
	Local $tBuffer, $aResult

	If $sPath = '' Then Return ''

	$sPath = StringStripWS(StringReplace($sPath, '/', '\'), 3)
	If $sPath = '' Then Return ''

	; Remove the Windows extended-path prefix so protected-path comparisons
	; cannot be bypassed by using an alternate spelling of the same path.
	If StringLeft($sPath, 8) = '\\?\UNC\' Then
		$sPath = '\\' & StringTrimLeft($sPath, 8)
	ElseIf StringLeft($sPath, 4) = '\\?\' Then
		$sPath = StringTrimLeft($sPath, 4)
	EndIf

	; Resolve "." and ".." before making any safety comparison.
	$tBuffer = DllStructCreate('wchar[32768]')
	$aResult = DllCall('kernel32.dll', 'dword', 'GetFullPathNameW', _
			'wstr', $sPath, _
			'dword', 32768, _
			'ptr', DllStructGetPtr($tBuffer), _
			'ptr', 0)

	If @error Or Not IsArray($aResult) Then Return ''
	If $aResult[0] = 0 Or $aResult[0] >= 32768 Then Return ''

	$sPath = StringReplace(DllStructGetData($tBuffer, 1), '/', '\')

	While StringLen($sPath) > 0 And StringRight($sPath, 1) = '\'
		$sPath = StringTrimRight($sPath, 1)
	WEnd

	Return StringLower($sPath)
EndFunc   ;==>_CleanupCanonicalPath

Func _CleanupPathProtects($sDeletePath, $sProtectedPath)
	Local $sProtected = _CleanupCanonicalPath($sProtectedPath)

	If $sDeletePath = '' Or $sProtected = '' Then Return False

	If $sDeletePath = $sProtected Then Return True

	; Also refuse to delete a parent directory containing a protected path.
	If StringLeft($sProtected, StringLen($sDeletePath) + 1) = $sDeletePath & '\' Then Return True

	Return False
EndFunc   ;==>_CleanupPathProtects

Func _TempCleanupSafetyReason($sTempPath)
	Local $sDeletePath = _CleanupCanonicalPath($sTempPath)
	Local $i
	Local $aProtected[16] = [ _
			$Root, _
			@ScriptDir, _
			@WindowsDir, _
			@SystemDir, _
			@UserProfileDir, _
			@DesktopDir, _
			@MyDocumentsDir, _
			@AppDataDir, _
			@LocalAppDataDir, _
			@ProgramFilesDir, _
			@CommonFilesDir, _
			@TempDir, _
			$Home, _
			$Bin, _
			$Lib, _
			$Backup]

	If $sDeletePath = '' Then Return 'blank or invalid path'

	; Never recursively remove a drive root.
	If StringRegExp($sDeletePath, '^[a-z]:$') Then Return 'drive root'

	; Never recursively remove the root of a UNC share.
	If StringRegExp($sDeletePath, '^\\\\[^\\]+\\[^\\]+$') Then Return 'UNC share root'

	For $i = 0 To UBound($aProtected) - 1
		If _CleanupPathProtects($sDeletePath, $aProtected[$i]) Then
			Return 'protected path'
		EndIf
	Next

	Return ''
EndFunc   ;==>_TempCleanupSafetyReason

Func _DeleteTempSafe()
	Local $sSafetyReason = _TempCleanupSafetyReason($Temp)
	If $sSafetyReason <> '' Then
		If $sSafetyReason = 'blank or invalid path' Then
			_DebugWrite(">>>>>> Temp cleanup blocked - " & $sSafetyReason)
		Else
			_DebugWrite(">>>>>> Temp cleanup blocked - " & $sSafetyReason & ': ' & $Temp)
		EndIf
		Return SetError(1, 0, 0)
	EndIf

	If Not FileExists($Temp) Then Return SetError(0, 1, 1)

	If DirRemove($Temp, 1) <> 1 Then
		_DebugWrite(">>>>>> Temp cleanup failed: " & $Temp)
		Return SetError(2, 0, 0)
	EndIf

	Return SetError(0, 2, 1)
EndFunc   ;==>_DeleteTempSafe

Func _RunAfterOperationFailed($sOperation, $sValue, $vResult, $iError, $iExtended)
	If $sValue = '' Then Return False

	Switch $sOperation
		; These legacy helpers report failure through @error.
		Case 'DirCopy', 'RunFile'
			Return $iError <> 0

		; FileMove wildcard no-match is a legitimate no-op. Exact missing sources
		; and failed moves retain a nonzero @error.
		Case 'FileMove'
			If $iError = 0 And $vResult = 0 And $iExtended = 4 Then Return False
			Return $iError <> 0

		; These helpers have an explicit Boolean success return.
		Case 'DirMove', 'FileCopy', 'FileDelete'
			Return $iError <> 0 Or $vResult <> 1

		; Empty-only removal can legitimately make no change. Ordinary removal
		; must either remove the directory or confirm that it was already absent.
		Case 'DirRemove'
			If $iError <> 0 Then Return True
			If $vResult <> 0 Then Return False
			Local $aDirRemove = StringSplit($sValue, '|')
			Return Not ($aDirRemove[0] > 1 And StringInStr($aDirRemove[2], 'e', 1) > 0)
	EndSwitch

	; Blank and unsupported entries are already reported as SKIP or WARN and
	; are not treated as a failed configured operation.
	Return False
EndFunc   ;==>_RunAfterOperationFailed

Func _XClose($bInteractiveTraceReport = True)
	; Close Splash Screen
	_SplashScreenOff()

	; Close TrayTip
	_TrayTipOff()

	; RunAfter
	Local $vRunAfterResult, $iRunAfterError, $iRunAfterExtended
	Local $_runafter = IniReadSection($ScriptIni, 'RunAfter')
	If Not @error Then
		_DebugWrite("[RunAfter] : about to execute ")
		For $ra = 1 To $_runafter[0][0]
			_DebugWrite("--> " & $_runafter[$ra][0] & "=" & $_runafter[$ra][1])
			$vRunAfterResult = 0
			$iRunAfterError = 0
			$iRunAfterExtended = 0
			Select
				Case $_runafter[$ra][1] = ''
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'DirCopy'
					$vRunAfterResult = _DirCopy($_runafter[$ra][1])
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'DirMove'
					$vRunAfterResult = _DirMove($_runafter[$ra][1])
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'DirRemove'
					$vRunAfterResult = _DirRemove($_runafter[$ra][1])
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'FileCopy'
					$vRunAfterResult = _FileCopy($_runafter[$ra][1])
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'FileDelete'
					$vRunAfterResult = _FileDelete($_runafter[$ra][1])
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'FileMove'
					$vRunAfterResult = _FileMove($_runafter[$ra][1])
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case $_runafter[$ra][0] = 'RunFile'
					$vRunAfterResult = _RunWait($_runafter[$ra][1], $Root)
					$iRunAfterError = @error
					$iRunAfterExtended = @extended
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
				Case Else
					_DebugOperationResult('RunAfter', $_runafter[$ra][0], $_runafter[$ra][1], _
							$vRunAfterResult, $iRunAfterError, $iRunAfterExtended)
			EndSelect
			If $RunAfterStopOnFailure = 'true' And _
					_RunAfterOperationFailed($_runafter[$ra][0], $_runafter[$ra][1], _
					$vRunAfterResult, $iRunAfterError, $iRunAfterExtended) Then
				If $ra < $_runafter[0][0] Then
					_DebugWrite('[SKIP] [RunAfter] Remaining configured operations stopped ' & _
							'(reason=RunAfterStopOnFailure=true; failed=' & $_runafter[$ra][0] & ')')
				EndIf
				ExitLoop
			EndIf
		Next
		_DebugWrite("[RunAfter] : executed")
	EndIf

	; Remove only temporary links created and tracked by this launcher process.
	; Persistent entries ending in |* are never added to this cleanup list.
	_TemporaryLinksCleanup()

	; Restore Regkeys
	Local $vRegistryRestoreResult, $iRegistryRestoreError, $iRegistryRestoreExtended
	Local $_restorekeys = IniReadSection($ScriptIni, 'RunBefore')
	If Not @error Then
		For $rk = 1 To $_restorekeys[0][0]
			Select
				Case $_restorekeys[$rk][0] = 'Regedit'
					_DebugWrite("executing: restore RegEdit=" & $_restorekeys[$rk][1])
					$vRegistryRestoreResult = _RegFileRestore($_restorekeys[$rk][1], _
							$Temp & '\Regedit\backup' & $rk)
					$iRegistryRestoreError = @error
					$iRegistryRestoreExtended = @extended
					_DebugOperationResult('RunAfter', 'RestoreRegedit', $_restorekeys[$rk][1], _
							$vRegistryRestoreResult, $iRegistryRestoreError, $iRegistryRestoreExtended)
			EndSelect
		Next
	EndIf

	; Remove Fonts
	Local $vRemoveFontsResult, $iRemoveFontsError, $iRemoveFontsExtended
	Local $_removefonts = IniReadSection($ScriptIni, 'Functions')
	If Not @error Then
		For $rf = 1 To $_removefonts[0][0]
			Select
				Case $_removefonts[$rf][0] = 'AddFonts'
					_DebugWrite("executing: remove AddFonts=" & $_removefonts[$rf][1])
					$vRemoveFontsResult = _RemoveFonts($_removefonts[$rf][1])
					$iRemoveFontsError = @error
					$iRemoveFontsExtended = @extended
					_DebugOperationResult('RunAfter', 'RemoveFonts', $_removefonts[$rf][1], _
							$vRemoveFontsResult, $iRemoveFontsError, $iRemoveFontsExtended)
			EndSelect
		Next
	EndIf	
	
	; Exit
	IniWrite($TempLog, 'Status', 'IsRunning', 'false')
	IniWrite($TempLog, 'Status', 'IsClosing', 'false')
	Local $vTempCleanupResult = 0, $iTempCleanupError = 0, $iTempCleanupExtended = 0
	If $DeleteTemp = 'true' Then
		$vTempCleanupResult = _DeleteTempSafe()
		$iTempCleanupError = @error
		$iTempCleanupExtended = @extended
	EndIf
	_DebugTempCleanupResult($DeleteTemp, $Temp, $vTempCleanupResult, _
			$iTempCleanupError, $iTempCleanupExtended)
	
	_DebugWrite("================ " & $ScriptName & " === application ended ================")
	If $TraceActive Then
		_TraceFinalize($bInteractiveTraceReport)
	Else
		_DebugSessionEnd('normal-close')
	EndIf
	
EndFunc   ;==>_XClose

; Exit Function
Func OnAutoItExit()
	Switch @exitMethod
		Case 2 To 4 ;Tray exit, user logoff or Windows shutdown
			; Only the primary launcher closes processes belonging to this session.
			; Trace registers this handler before application metadata is complete;
			; do not run close operations until the executable has been resolved.
			If $ExeName <> '' And $IsRunning <> 'true' Then
				If Not _ProcessCloseExcept($ExeName, $ExistingProcessPIDs, 3000) Then
					_DebugWrite(">>>>>> Process close timeout=" & $ExeName)
				EndIf
				_XClose(False)
			EndIf

		Case 1 ;Exit function
			; Covers launch failures and other explicit exits after [Functions].
			_TemporaryLinksCleanup()
			If FileExists($TempLog) Then IniWrite($TempLog, 'Status', 'IsClosing', 'false')

		Case 0 ;Natural closing

	EndSwitch

	If $TraceActive Then
		_TraceFinalize(False)
	Else
		_DebugSessionEnd('exit-method=' & @exitMethod)
	EndIf

EndFunc   ;==>OnAutoItExit

;
; ==> End of X-Launcher's code
; ------------------------------------------------------------------------------
