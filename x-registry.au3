#include-once
#include "x-udf.au3"
#AutoIt3Wrapper_au3check_parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6

;~ Global $Root = @ScriptDir, $GlobalConfig = @ScriptDir & '\X-Launcher.cfg', $ScriptIni = @ScriptDir & '\x-launcher.ini'

; ------------------------------------------------------------------------------
;
;					_Registry (Registry Functions)
;
; ------------------------------------------------------------------------------
;
; AutoIt Version:	3.2.12.1
; Language:			English
; Description:		Functions used in X-Launcher
; Author:			winPenPack Developer Team
; Contributors:		winPenPack Team and winPenPack community
;
; ------------------------------------------------------------------------------
;
;
;
;===============================================================================
;
; Function Name:	_RegKeyGet()
; Description:		Returns the main key contained in a *.reg file
;
;===============================================================================
Func _RegKeyGet($file)
	Local $_keys
	$_keys = IniReadSectionNames($file)
	If Not @error Then Return($_keys[1])
EndFunc   ;==>_RegKeyGet

;===============================================================================
;
; Function Name:	_RegFileInstall()
; Description:		Installs *.reg file(s). If the key already exists, it will
;					backuped in folder to be restored with _RegFileRestore()
; Syntax:			_RegFileInstall(Path\File1.reg;File2|Path2\File3.reg, Backup dir)
; Requirements:		_FileInfo, _FullPath & _RegKeyLoad
;
;===============================================================================
Func _RegFileInstall($string, $backupdir)
	Local $_files, $_regs, $reg1, $path, $regfile
	DirCreate($backupdir)
	$_files = StringSplit($string, '|')
	For $i = 1 To $_files[0]
		$_regs = StringSplit($_files[$i], ';')
		$reg1 = _FullPath($_regs[1])
		$path = _FileInfo($reg1, 0)
		_RegKeyLoad($reg1, $backupdir & '\backup-' & $i & 1 & '.reg')
		For $r = 2 To $_regs[0]
			$regfile = $path & '\' & $_regs[$r]
			_RegKeyLoad($regfile, $backupdir & '\backup-' & $i & $r & '.reg')
		Next
	Next
EndFunc   ;==>_RegFileInstall

;===============================================================================
;
; Function Name:	_RegKeyLoad()
; Description:		Installs a single *.reg file. If the key already exists, it
;					will backuped in folder to be restored with _RegFileRestore()
;
;===============================================================================
Func _RegKeyLoad($regfile, $backupfile)
	Local $_keys
	$_keys = IniReadSectionNames($regfile)
	If Not @error Then
		_RegEdit($backupfile, 'EXPORT', $_keys[1])
		RegDelete($_keys[1])
		_RegEdit($regfile)
	EndIf
EndFunc   ;==>_RegKeyLoad

;===============================================================================
;
; Function Name:	_RegFileRestore()
; Description:		Restores the original reg keys previously backuped from _RegFileInstall()
; Requirements:		_FullPath, _FileInfo, _RegKeyGet, _RegEdit
;
;===============================================================================
Func _RegFileRestore($string, $backupdir)
	Local $_files, $_f, $_regs, $reg1, $key1, $path, $reg, $key, $_backups, $backup
	$_files = StringSplit($string, '|')
	If $_files[$_files[0]] = '*' Then
		$_f = $_files[0] - 1
	Else
		$_f = $_files[0]
	EndIf
	For $i = 1 To $_f
		$_regs = StringSplit($_files[$i], ';')
		$reg1 = _FullPath($_regs[1])
		$key1 = _RegKeyGet($reg1)
		_RegEdit($reg1, 'EXPORT', $key1)
		$path = _FileInfo($reg1, 0)
		If $_files[$_files[0]] <> '*' Then RegDelete($key1)
		For $r = 2 To $_regs[0]
			$reg = $path & '\' & $_regs[$r]
			$key = _RegKeyGet($reg)
			_RegEdit($reg, 'EXPORT', $key)
			If $_files[$_files[0]] <> '*' Then RegDelete($key)
		Next
	Next
	If $_files[$_files[0]] <> '*' Then
		$_backups = FileFindFirstFile($backupdir & '\*.reg')
		If $_backups <> -1 Then
			While 1
				$backup = FileFindNextFile($_backups)
				If @error Then ExitLoop
				_RegEdit($backupdir & '\' & $backup)
			WEnd
		EndIf
		FileClose($_backups)
	EndIf
	DirRemove($backupdir, 1)
EndFunc   ;==>_RegFileRestore

;===============================================================================
;
; Function Name:	_WriteToReg()
; Description:		Writes text to a specific line in a file
; Syntax:			_WriteLine(File, LineX or EOF, String)
;
;===============================================================================
Func _WriteToReg($file, $mainkey, $subkey, $name, $value)
	Local $write, $key
	AutoItSetOption('ExpandEnvStrings', 0)
	AutoItSetOption('ExpandVarStrings', 0)
	Local $sRegVersion = ''
	If FileExists($file) And _RegKeyGet($file) = $mainkey Then $sRegVersion = FileReadLine($file, 1)
	Switch $sRegVersion
		Case 'REGEDIT4'
		Case 'Windows Registry Editor Version 5.00'
		Case Else
			$write = FileOpen($file, 10)
			FileWriteLine($write, 'REGEDIT4')
			FileWriteLine($write, '[' & $mainkey & ']')
			FileClose($write)
	EndSwitch
	Select
		Case $subkey = '' And $name = '' And $value = ''
		Case Else
			If $subkey = '' Then
				$key = $mainkey
			Else
				$key = $mainkey & '\' & $subkey
			EndIf
			If $value <> '' Then $value = _FullPathPlus($value)
			IniWrite($file, $key, $name, $value)
	EndSelect
	AutoItSetOption('ExpandEnvStrings', 1)
	AutoItSetOption('ExpandVarStrings', 1)
EndFunc   ;==>_WriteToReg

;=================================================================================================================
;
; Function Name:	_RegEdit
; Description:		select the editor for the Registry in accordance with the operating system and operates
; Syntax:			_RegEdit($sFile, $sOperation, $sKey)
; Parameters:
; Return values:
; Author:			Energy
; Modified:
; Remarks:
;
;=================================================================================================================
Func _RegEdit($sFile = "", $sOperation = "IMPORT", $sKey = "")
	Local $sExePath = @WindowsDir
	Local $sExeName = 'regedit.exe'
	Local $sOption = ' /s'
	Local $sPostOpt = ''
	Switch $sOperation
		Case 'IMPORT'
		Case 'EXPORT'
			$sOption &= ' /e'
		Case Else
			Return SetError(1, 0, 0)
	EndSwitch
	Local $sCommand = $sExePath & '\' & $sExeName & $sOption
	Switch _OSVersion('version')
		Case "WIN_ME", "WIN_98", "WIN_95"
			$sCommand &= ' "' & $sFile & '"'
			Switch $sOperation
				Case "EXPORT"
					$sCommand &= ' "' & $sKey
			EndSwitch
		Case "WIN_2003", "WIN_XP", "WIN_XPe", "WIN_2000", "WIN_NT4"
			Switch $sOperation
				Case "IMPORT"
					$sCommand &= ' "' & $sFile & '"'
				Case "EXPORT"
					$sCommand &= ' /a "' & $sFile & '" "' & $sKey & '"'
			EndSwitch
		Case Else
			$sExePath = @SystemDir
			$sExeName = 'reg.exe'
			$sOption = 'IMPORT'
			$sPostOpt = ' /y'
			$sCommand = $sExePath & '\' & $sExeName
			Local $sRegManager = _RegManager()
			If Not @error And $sRegManager <> '' Then
				$sCommand = $sRegManager
				$sPostOpt = ''
			EndIf
			Switch $sOperation
				Case "IMPORT"
					$sCommand &= ' IMPORT "' & $sFile & '"'
				Case "EXPORT"
					FileDelete($sFile)
					$sCommand &= ' EXPORT "' & $sKey & '" "' & $sFile & '"' & $sPostOpt
			EndSwitch
	EndSwitch
	Local $sRegTest = RunWait($sCommand, $sExePath, @SW_HIDE)
	If Not @error Then Return SetError(0, 0, 1)
	_Debug('Error: ' & $sRegTest & ' Command: ' & $sCommand & @CRLF)
	Return SetError(2, 0, 0)
EndFunc   ;==>_RegEdit

;=================================================================================================================
;
; Function Name:	_RegManager
; Description:		verify the need for administrative permits to operate with an external editor of the Registry
; Syntax:			_RegManager()
; Parameters:
; Return values:	path of external registry editor
; Author:			Energy
; Modified:
; Remarks:
;
;=================================================================================================================
Func _RegManager()
	Local $sRequireAdmin = ''
	$sRequireAdmin = IniRead($ScriptIni, 'Options', 'RegEdit', 'RequireAdmin')
	Switch $sRequireAdmin
		Case "True", "request"
			Local $sRegManager = _RegManagerExt()
			If Not @error And $sRegManager <> '' Then Return $sRegManager
		Case Else
			Return SetError(1, 0, '')
	EndSwitch
EndFunc   ;==>_RegManager

;=================================================================================================================
;
; Function Name:	_RegManagerExt
; Description:		Returns the path of external registry editor
; Syntax:			_RegManagerExt()
; Parameters:
; Return values:	path of external registry editor
; Author:			Energy
; Modified:
; Remarks:
;
;=================================================================================================================
Func _RegManagerExt()
	Local $sRegManager = ''
	$sRegManager = IniRead($GlobalConfig, 'FileToRun', 'RegEdit', '')
	If $sRegManager = '' Then $sRegManager = IniRead($ScriptIni, 'FileToRun', 'RegEdit', '')
	If $sRegManager = '' Then Return SetError(1, 0, '')
	$sRegManager = _FullPath($sRegManager, $Root)
	If FileExists($sRegManager) = 0 Then Return SetError(2, 0, '')
	If StringInStr(FileGetAttrib($sRegManager), 'D', 2) <> 0 Then Return SetError(3, 0, '')
	Return $sRegManager
EndFunc   ;==>_RegManagerExt

;=================================================================================================================
;
; Function Name:	_OSVersion
; Description:		Returns the OS Version for debug
; Syntax:			_OSVersion($sQuery)
; Parameters:		$sQuery  - Type of query
; Return values:	@OSVersion
; Author:			ZioZione
; Modified:			Energy
; Remarks:
;
;=================================================================================================================
Func _OSVersion($sQuery = 'version')
	; Version:  "WIN_2008R2", "WIN_7", "WIN_2008", "WIN_VISTA", "WIN_2003", "WIN_XP", "WIN_XPe", "WIN_2000"
	; Old Version: "WIN_NT4", "WIN_ME", "WIN_98", "WIN_95"
	; Type: "WIN32_NT" for NT/2000/XP/2003/Vista/2008/Win7/2008R2
	; Old Type: "WIN32_WINDOWS" for 95/98/Me
	Switch $sQuery
		Case 'type'
			Return @OSTYPE
		Case Else
			Return @OSVersion
	EndSwitch
EndFunc   ;==>_OSVersion

;=================================================================================================================
;
; Function Name:	_Debug
; Description:		sends error messages
; Syntax:			_Debug($sMsg)
; Parameters:		$sMsg  - Messages
; Return values:
; Author:			Energy
; Modified:
; Remarks:
;
;=================================================================================================================
Func _Debug($sMsg = '')
;~ 	ConsoleWrite($sMsg)
EndFunc   ;==>_Debug
