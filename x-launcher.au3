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
Global $ScriptName, $ProcName, $VirtualMachine
Global $Cmd1, $_xcmd
Global $ScriptIniDir
Global $NoIni, $PleaseCheck
Global $Lang, $AppName, $AppVer, $Profile, $UserName
Global $Cache, $Home, $Bin, $Lib, $Doc, $Backup, $Download
Global $Drive, $DefaultFile, $WorkingDir
Global $PathToExe, $ExeDir
Global $FixAppData, $MultipleIstances, $RunWait, $ShowSplash, $WriteLog
Global $_options, $Log, $IsRunning, $IsClosing
Global $CheckIni, $FileNotFound, $AlreadyRunning, $StillClosing, $WinGetProcess, $Image, $Title_SS, $Title_TT
Global $TimeOut_SS, $TimeOut_TT, $_environment, $UserProfile, $AppData, $Desktop, $Documents, $Favorites
Global $_functions, $_sections, $_file, $_values, $_runbefore, $Parameters, $Cmd, $StringToExe
Global $ProcList
Global $PreRoot, $TempDir, $HomeDir, $BinDir, $LibDir, $DocDir, $BackupDir, $DownloadDir
Global $HideShellWindow, $Java
Global $TrayTipOn, $ShowTrayTip
Global $FirstRun, $_firstrunoperations
Global $PackShowSplash, $PackShowTrayTip
Global $Debug, $DebugFile

; ------------------------------------------------------------------------------
; System Variables
; ------------------------------------------------------------------------------
Global $LocalAppData = RegRead('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Local AppData')
Global $LocalSettings = RegRead('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Local Settings')

; ------------------------------------------------------------------------------
; JavaGet Variables
; ------------------------------------------------------------------------------
Global $sJGAppName = "winPenPack Java Installer"
Global $sJavaURL = "http://www.winpenpack.com/main/request.php?956"
;~ $sJavaURL = "http://javadl.sun.com/webapps/download/AutoDL?BundleId=35684"
Global $iMsgBoxAnswer
Global $sJBak

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

; Install ScriptIni if doesn't exists
$ScriptIniDir = _FileInfo($ScriptIni, 0)

; Warning messages
_SystemLanguage($Lang)
Select
	Case $Lang = 'it'
		$NoIni = 'Il file di configurazione "' & $ScriptIni & '" non esiste.' & @CRLF & @CRLF & 'Ne verrà creato uno con le opzioni predefinite.'
		$PleaseCheck = 'Si prega di controllare le impostazioni prima di proseguire.'
	Case Else
		$NoIni = 'The configuration file "' & $ScriptIni & '" does not exist.' & @CRLF & @CRLF & 'One with the default options will be created.'
		$PleaseCheck = 'Please check the settings before continue.'
EndSelect

; Install configuration file
If Not FileExists($ScriptIni) Then
	MsgBox(48, $ScriptName, $NoIni)
	MsgBox(48, $ScriptName, $PleaseCheck)
	DirCreate($ScriptIniDir)
	FileInstall('x-launcher.ini', $ScriptIni)
	FileChangeDir($ScriptIniDir)
	RunWait(@ComSpec & ' /c "' & $ScriptIni & '"', '', @SW_HIDE)
	Exit (1)
EndIf

_DebugWrite("================ " & $ScriptName & " === application started ================")
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
$MultipleIstances = 'true'
$RunWait = 'true'
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
				Case $_options[$o][0] = 'MultipleIstances'
					$MultipleIstances = $_options[$o][1]
				Case $_options[$o][0] = 'RunWait'
					$RunWait = $_options[$o][1]
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
		Exit (3)
	EndIf
EndIf

; ------------------------------------------------------------------------------
; FileToRun
; ------------------------------------------------------------------------------
$sJBak = $Lib & "\Java\old_java"
$Java = _JavaCheck($AppName, $ScriptIni, $Lib, $Root)
$WorkingDir = _FullPath(IniRead($ScriptIni, 'FileToRun', 'WorkingDir', ''), $Root)
$PathToExe = _FullPath(IniRead($ScriptIni, 'FileToRun', 'PathToExe', ''), $Root)

; Search PathToExe
If Not StringInStr($PathToExe, '\') Then
	If FileExists($WorkingDir & '\' & $PathToExe) Then
		$PathToExe = $WorkingDir & '\' & $PathToExe
	ElseIf FileExists(@ScriptDir & '\' & $PathToExe) Then
		$PathToExe = @ScriptDir & '\' & $PathToExe
	ElseIf FileExists(@WindowsDir & '\' & $PathToExe) Then
		$PathToExe = @WindowsDir & '\' & $PathToExe
	ElseIf FileExists(@SystemDir & '\' & $PathToExe) Then
		$PathToExe = @SystemDir & '\' & $PathToExe
	EndIf
EndIf

; Exe's details
$ExeDir = _FileInfo($PathToExe, 0)
$ExeName = _FileInfo($PathToExe, 1)

; Virtual Machine
$VirtualMachine = False
If $ExeName = "javaw.exe" Then $VirtualMachine = True

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

; Multiple istances for Virtual Machine
If $VirtualMachine Then
	If $Cmd1 = 2 Then $MultipleIstances = 'false'
	If $IsRunning = 'true' And $MultipleIstances = 'false' Then
		_DebugWrite("===== " & $ScriptName & " === secondary running stopped - MultipleIstances not allowed (Virtual Machine) =====")
		MsgBox(48, $ScriptName, $AlreadyRunning)
		Exit (4)
	EndIf

	; Multiple istances
ElseIf $MultipleIstances = 'false' Then
	AutoItSetOption('WinTitleMatchMode', 2)
	$WinGetProcess = IniRead($ScriptIni, 'FileToRun', 'WinGetProcess', '')
	Select
		Case $WinGetProcess = ''
			If ProcessExists($ExeName) Then
				_DebugWrite("===== " & $ScriptName & " === secondary running stopped - MultipleIstances not allowed =====")
				MsgBox(48, $ScriptName, $AlreadyRunning)
				Exit (4)
			EndIf
		Case Else
			If WinGetProcess($WinGetProcess) <> -1 Then
				_DebugWrite("=====  " & $ScriptName & " === secondary running stopped - MultipleIstances not allowed (WinGetProcess) =====")
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
$Log = @ScriptDir & '\' & $ScriptName & '.log'

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

Local $Width_SS = _IniReadPlus($ScriptIni, 'SplashScreen', 'Width', 307)
Local $Height_SS = _IniReadPlus($ScriptIni, 'SplashScreen', 'Height', 213)

; ------------------------------------------------------------------------------
; TrayTip
; ------------------------------------------------------------------------------

; Title
$Title_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'Title', $ScriptName)

; Timeout
$TimeOut_TT = _IniReadPlus($ScriptIni, 'TrayTip', 'TimeOut ', '')
Select
	Case StringIsDigit($TimeOut_TT)
	Case Else
		$TimeOut_TT = '5000'
EndSelect

; ------------------------------------------------------------------------------
; Get Environmental Variables
; ------------------------------------------------------------------------------
$_environment = IniReadSection($ScriptIni, 'Environment')
If Not @error Then
	_DebugWrite("[Environment] : about to execute")
	For $e = 1 To $_environment[0][0]
		_DebugWrite("--> " & $_environment[$e][0] & "=" & $_environment[$e][1])
		Select
			Case $_environment[$e][0] = 'USERPROFILE'
				$UserProfile = _FullPath($_environment[$e][1], $Root)
				EnvSet('USERPROFILE', $UserProfile)
				If $WriteLog = 'true' Then IniWrite($Log, 'Environment', 'USERPROFILE', $UserProfile)
				If $FixAppData = 'true' Then

					; Fix AppData
					$AppData = _DirName(@AppDataDir)
					_FixUserProfile($UserProfile, $AppData, 'AppData')
					EnvSet('APPDATA', $UserProfile & '\' & $AppData)
					If $WriteLog = 'true' Then IniWrite($Log, 'Environment', 'APPDATA', $AppData)

					; Fix Desktop
					$Desktop = _DirName(@DesktopDir)
					_FixUserProfile($UserProfile, $Desktop, 'Desktop')
					DirCreate($UserProfile & '\' & $Desktop)

					; Fix Documents
					$Documents = _DirName(@MyDocumentsDir)
					_FixUserProfile($UserProfile, $Documents, 'Documents')
					DirCreate($UserProfile & '\' & $Documents)

					; Fix Favorites
					$Favorites = _DirName(@FavoritesDir)
					_FixUserProfile($UserProfile, $Favorites, 'Favorites')

				EndIf
			Case $_environment[$e][0] = 'PATH'
				_SetPath($_environment[$e][1], $WriteLog, $Log)
			Case Else
				_SetEnv($_environment[$e][0], $_environment[$e][1], $WriteLog, $Log)
		EndSelect
	Next
	_DebugWrite("[Environment] : executed")
EndIf

; ------------------------------------------------------------------------------
; Functions
; ------------------------------------------------------------------------------
$_functions = IniReadSection($ScriptIni, 'Functions')
If Not @error Then
	_DebugWrite("[Functions] : about to execute")
	For $f = 1 To $_functions[0][0]
		_DebugWrite("--> " & $_functions[$f][0] & "=" & $_functions[$f][1])
		Select
			Case $_functions[$f][1] = ''
			Case $_functions[$f][0] = 'DirCopy'
				_DirCopy($_functions[$f][1])
			Case $_functions[$f][0] = 'DirCreate'
				_DirCreate($_functions[$f][1])
			Case $_functions[$f][0] = 'DirMove'
				_DirMove($_functions[$f][1])
			Case $_functions[$f][0] = 'DirRemove'
				_DirRemove($_functions[$f][1])
			Case $_functions[$f][0] = 'FileCopy'
				_FileCopy($_functions[$f][1])
			Case $_functions[$f][0] = 'FileCreate'
				_FileCreatePlus($_functions[$f][1])
			Case $_functions[$f][0] = 'FileDelete'
				_FileDelete($_functions[$f][1])
			Case $_functions[$f][0] = 'FileMove'
				_FileMove($_functions[$f][1])
			Case $_functions[$f][0] = 'AddFonts'
				_AddFonts($_functions[$f][1])
		EndSelect
	Next
	_DebugWrite("[Functions] : executed")
EndIf

; ------------------------------------------------------------------------------
; Sections
; ------------------------------------------------------------------------------
_DebugWrite("[Sections] : about to execute")
$_sections = IniReadSectionNames($ScriptIni)
For $i = 1 To $_sections[0]
	$_file = StringSplit($_sections[$i], '=')
	If Not @error Then
		_DebugWrite("--> " & $_file[1] & "=" & $_file[2])
		AutoItSetOption('ExpandEnvStrings', 0)
		AutoItSetOption('ExpandVarStrings', 0)
		$_values = IniReadSection($ScriptIni, $_sections[$i])
		AutoItSetOption('ExpandEnvStrings', 1)
		AutoItSetOption('ExpandVarStrings', 1)
		Select
			Case $_file[1] = 'StringReplace'
				If Not @error Then
					Local $FileList
					$FileList=_ExpandMultiPath($_file[2], True)
					If $FileList[0] > 0 Then
						For $IxElem = 1 To $FileList[0]
							Local $FileToRewrite, $_delimiters, $overwrite = False
							$FileToRewrite = $FileList[$IxElem]
							For $k = 1 To $_values[0][0]
								$_delimiters = StringSplit($_values[$k][0], '|')
								If $_delimiters[0] = 3 And $_delimiters[3] = 'o' Then $overwrite = True
								_StringReplace($FileToRewrite, $_delimiters[1], $_delimiters[2], _FullPathPlus($_values[$k][1]), $overwrite)
							Next
						Next
					EndIf
				EndIf
			Case $_file[1] = 'StringRegExpReplace'
				If Not @error Then
					Local $FileList
					$FileList=_ExpandMultiPath($_file[2], True)
					If $FileList[0] > 0 Then
						AutoItSetOption('ExpandEnvStrings', 0)
						AutoItSetOption('ExpandVarStrings', 0)
						For $IxElem = 1 To $FileList[0]
							Local $FileToRewrite
							$FileToRewrite = $FileList[$IxElem]
							For $k = 1 To $_values[0][0]
								_StringRegExpReplace ($FileToRewrite, $_values[$k][1], $_values[$k][0])
							Next
						Next
						AutoItSetOption('ExpandEnvStrings', 1)
						AutoItSetOption('ExpandVarStrings', 1)
					EndIf
				EndIf
			Case $_file[1] = 'WriteToFile'
				If Not @error Then
					Local $FileToWrite
					$FileToWrite = _FullPath($_file[2], $Root)
					For $k = 1 To $_values[0][0]
						_WriteToFile($FileToWrite, $_values[$k][0], $_values[$k][1])
					Next
				EndIf
			Case $_file[1] = 'WriteToIni'
				If Not @error Then
					Local $IniFile, $_stw
					$IniFile = _FullPath($_file[2], $Root)
					For $k = 1 To $_values[0][0]
						$_stw = StringSplit($_values[$k][0], '|')
						IniWrite($IniFile, $_stw[1], $_stw[2], _FullPathPlus($_values[$k][1]))
					Next
				EndIf
			Case $_file[1] = 'WriteToPref'
				If Not @error Then
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
						_WriteToPref($PrefsFile, $Begin, $Mid, $End, $_values[$k][0], _FullPathPlus($_values[$k][1]))
					Next
				EndIf
			Case $_file[1] = 'WriteToReg'
				If Not @error Then
					Local $RegFile, $MainKey, $_stw
					$RegFile = _FullPath($_file[2], $Root)
					$MainKey = $_values[1][1]
					_WriteToReg($RegFile, $MainKey, '', '', '')
					For $k = 2 To $_values[0][0]
						$_stw = StringSplit($_values[$k][0], '|')
						Select
							Case $_stw[0] = 1
								_WriteToReg($RegFile, $MainKey, '', $_stw[1], $_values[$k][1])
							Case $_stw[0] = 2
								_WriteToReg($RegFile, $MainKey, $_stw[1], $_stw[2], $_values[$k][1])
						EndSelect
					Next
				EndIf
		EndSelect
	EndIf
Next
_DebugWrite("[Sections] : executed")

; ------------------------------------------------------------------------------
; RunBefore
; ------------------------------------------------------------------------------
$_runbefore = IniReadSection($ScriptIni, 'RunBefore')
If Not @error Then
	_DebugWrite("[RunBefore] : about to execute")
	For $rb = 1 To $_runbefore[0][0]
		_DebugWrite("--> " & $_runbefore[$rb][0] & "=" & $_runbefore[$rb][1])
		Select
			Case $_runbefore[$rb][1] = ''
			Case $_runbefore[$rb][0] = 'FixDriveLetter'
				_FixDriveLetter($_runbefore[$rb][1], $Root)
			Case $_runbefore[$rb][0] = 'Regedit'
				If $IsRunning <> 'true' Then _RegFileInstall($_runbefore[$rb][1], $Temp & '\Regedit\backup' & $rb)
			Case $_runbefore[$rb][0] = 'RunFile'
				_RunWait($_runbefore[$rb][1], $Root)
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
		Switch StringLeft($CmdLine[$i], 1)
			Case '-', '/'
				$Cmd &= ' ' & $CmdLine[$i]
			Case Else
				$Cmd &= ' "' & $CmdLine[$i] & '"'
		EndSwitch
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

; RunWait false
If $RunWait <> 'true' Then
	;Run($StringToExe)
	_Run($StringToExe,$RunWait,$HideShellWindow)
	IniWrite($TempLog, 'Status', 'IsRunning', 'false')
	IniWrite($TempLog, 'Status', 'IsClosing', 'false')
	If $DeleteTemp = 'true' Then DirRemove($Temp, 1)
	_DebugWrite("===== " & $ScriptName & " === exit RunWait false =====")
	_DebugWrite("================ " & $ScriptName & " === application ended ================")
	Exit
EndIf

; Run Virtual Machine
If $VirtualMachine Then
	;RunWait($StringToExe)
	_Run($StringToExe,$RunWait,$HideShellWindow)
	If $MultipleIstances <> 'false' Then
		If _ProcessExistsOther() Then 
			_DebugWrite("===== " & $ScriptName & " === secondary running exit (Virtual Machine) =====")
			Exit
		EndIf
		_DebugWrite("===== " & $ScriptName & " === primary running exit (Virtual Machine) =====")
	EndIf

	; RunFile
ElseIf $IsRunning <> 'true' Then
	;RunWait($StringToExe)
	_Run($StringToExe,$RunWait,$HideShellWindow)
	_DebugWrite("===== " & $ScriptName & " === primary running waiting for multiple program closing =====")
	While ProcessExists($ExeName) <> 0
		Sleep(250)
	WEnd
	_DebugWrite("===== " & $ScriptName & " === primary running exit =====")
Else
	;Run($StringToExe)
	$RunWait = 'false'	
	_Run($StringToExe,$RunWait,$HideShellWindow)
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

Func _XClose()
	; Close Splash Screen
	_SplashScreenOff()

	; Close TrayTip
	_TrayTipOff()

	; RunAfter
	Local $_runafter = IniReadSection($ScriptIni, 'RunAfter')
	If Not @error Then
		_DebugWrite("[RunAfter] : about to execute ")
		For $ra = 1 To $_runafter[0][0]
			_DebugWrite("--> " & $_runafter[$ra][0] & "=" & $_runafter[$ra][1])
			Select
				Case $_runafter[$ra][1] = ''			
				Case $_runafter[$ra][0] = 'DirCopy'
					_DirCopy($_runafter[$ra][1])
				Case $_runafter[$ra][0] = 'DirMove'
					_DirMove($_runafter[$ra][1])
				Case $_runafter[$ra][0] = 'DirRemove'
					_DirRemove($_runafter[$ra][1])
				Case $_runafter[$ra][0] = 'FileCopy'
					_FileCopy($_runafter[$ra][1])
				Case $_runafter[$ra][0] = 'FileDelete'
					_FileDelete($_runafter[$ra][1])
				Case $_runafter[$ra][0] = 'FileMove'
					_FileMove($_runafter[$ra][1])
				Case $_runafter[$ra][0] = 'RunFile'
					_RunWait($_runafter[$ra][1], $Root)
			EndSelect
		Next
		_DebugWrite("[RunAfter] : executed")
	EndIf

	; Restore Regkeys
	Local $_restorekeys = IniReadSection($ScriptIni, 'RunBefore')
	If Not @error Then
		For $rk = 1 To $_restorekeys[0][0]
			Select
				Case $_restorekeys[$rk][0] = 'Regedit'
					_DebugWrite("executing: restore RegEdit=" & $_restorekeys[$rk][1])
					_RegFileRestore($_restorekeys[$rk][1], $Temp & '\Regedit\backup' & $rk)
			EndSelect
		Next
	EndIf

	; Remove Fonts
	Local $_removefonts = IniReadSection($ScriptIni, 'Functions')
	If Not @error Then
		For $rf = 1 To $_removefonts[0][0]
			Select
				Case $_removefonts[$rf][0] = 'AddFonts'
					_DebugWrite("executing: remove AddFonts=" & $_removefonts[$rf][1])
					_RemoveFonts($_removefonts[$rf][1])
			EndSelect
		Next
	EndIf	
	
	; Exit
	IniWrite($TempLog, 'Status', 'IsRunning', 'false')
	IniWrite($TempLog, 'Status', 'IsClosing', 'false')
	If $DeleteTemp = 'true' Then DirRemove($Temp, 1)
	
	_DebugWrite("================ " & $ScriptName & " === application ended ================")
	
EndFunc   ;==>_XClose

; Exit Function
Func OnAutoItExit()
	Switch @exitMethod
		Case 2 To 4 ;Windows shutdown
			While ProcessExists($ExeName) <> 0
				ProcessClose($ExeName)
			WEnd
			_XClose()
		Case 1 ;Exit function
			If FileExists($TempLog) Then IniWrite($TempLog, 'Status', 'IsClosing', 'false')
		Case 0 ;Natural closing

	EndSwitch

EndFunc   ;==>OnAutoItExit
;
; ==> End of X-Launcher's code
; ------------------------------------------------------------------------------