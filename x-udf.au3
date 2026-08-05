#include-once
#include 'image_get_size.au3'
#Include <File.au3>
#AutoIt3Wrapper_au3check_parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6

; ------------------------------------------------------------------------------
;
;					X-UDF (User Defined Functions)
;
; ------------------------------------------------------------------------------
;
; AutoIt Version:	3.2.12.1
; Language:			English
; Description:		Functions used in X-Launcher
; Author:			Gabriele Tittonel <tittoproject@gmail.com>
; Contributors:		winPenPack Team and winPenPack community
;
; ------------------------------------------------------------------------------
;
;
;
;===============================================================================
;
; Function Name:	_DirCopy()
; Description:		Copies a directory and all sub-directories and files
; Syntax:			_DirCopy(SourcePath|DestinationPath)
; Requirements:		_FullPath
;
;===============================================================================
Func _DirCopy($string)
	Local $_dircopy, $source, $destination, $iError
	$_dircopy = StringSplit($string, '|')
	$source = _FullPath($_dircopy[1])
	$destination = _FullPath($_dircopy[2])
	Select
		Case $_dircopy[0] = 3 And $_dircopy[3] = 'o'
			$iError = DirCopy($source, $destination, 1)
		Case Else
			$iError = DirCopy($source, $destination)
	EndSelect
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 1 Then Return SetError(4, 0, 0)
EndFunc   ;==>_DirCopy

;===============================================================================
;
; Function Name:	_DirCreate()
; Description:		Creates a directory/folder
; Syntax:			_DirCreate(Path1\SubPath1;SubPath2|Path2|Path3\SubPath3)
; Requirements:		_FileInfo & _FullPath
;
;===============================================================================
Func _DirCreate($string)
	Local $_paths, $_dirs, $path1, $path, $iError
	$_paths = StringSplit($string, '|')
	For $i = 1 To $_paths[0]
		$_dirs = StringSplit($_paths[$i], ';')
		$path1 = _FullPath($_dirs[1])
		$path = _FileInfo($path1, 0)
		DirCreate($path1)
		For $d = 2 To $_dirs[0]
			$iError = DirCreate($path & '\' & $_dirs[$d])
		Next
	Next
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 1 Then Return SetError(4, 0, 0)
EndFunc   ;==>_DirCreate

;===============================================================================
;
; Function Name:	_DirRemove()
; Description:		Deletes a directory/folder
; Syntax:			_DirRemove(Path\File|Options)
; Requirements:		_FullPath
;
;===============================================================================
Func _DirRemove($sPathPlus)
	If $sPathPlus = '' Then Return SetError(1, 0, 0)
	Local $aPath = StringSplit($sPathPlus, '|')
	Local $sPath = _FullPath($aPath[1])
	If @error Or $sPath = '' Then Return SetError(2, 0, 0)
	Local $iReturn = 0
	If $aPath[0] > 1 And StringInStr($aPath[2], 'e', 1) Then
		$iReturn = _DirRemoveEmpty($sPath)
	Else
		$iReturn = DirRemove($sPath, 1)
	EndIf
	Return SetError(@error, 0, $iReturn)
EndFunc   ;==>_DirRemove

;===============================================================================
;
; Function Name:	_DirRemoveEmpty()
; Description:		Remove Empty directory
; Syntax:			_DirRemoveEmpty(Directory Path)
; Requirements:
;
;===============================================================================
Func _DirRemoveEmpty($sDirPath)
	$sDirPath = StringRegExpReplace($sDirPath, '[\\/ ]+$', '')
	If $sDirPath = '' Then  Return SetError(1,0,0)
	If Not FileExists($sDirPath) Then Return SetError(2,0,0)
	If StringInStr(FileGetAttrib($sDirPath), 'D', 2) = 0 Then Return SetError(3,0,0)
	If DirRemove($sDirPath, 0) = 1 Then Return SetError(0,1,1)
	Local $hDirPath = FileFindFirstFile($sDirPath & '\*')
	If $hDirPath = -1 Then Return SetError(4,0,0)
	Local $iError = 0, $iDir = 0
	While 1
		Local $sDir = FileFindNextFile($hDirPath)
		If @error Then ExitLoop
		Local $sNextDir = $sDirPath & '\' & $sDir
		If StringInStr(FileGetAttrib($sNextDir), 'D', 2) Then
			_DirRemoveEmpty($sNextDir)
			$iError += @error
			$iDir += @extended
		EndIf
	WEnd
	FileClose($hDirPath)
	If DirRemove($sDirPath, 0) = 1 Then Return SetError($iError, $iDir+1, 2)
	If $iDir > 0 Then Return SetError($iError, $iDir, 3)
	Return SetError($iError, $iDir, 0)
EndFunc   ;==>_DirRemoveEmpty

;===============================================================================
;
; Function Name:	_DirMove()
; Description:		Renames a file
; Syntax:			_DirMove(Path\File|NewName)
; Requirements:		_FullPath
;
;===============================================================================
Func _DirMove($string)
	Local $_split, $source, $destination, $iError
	$_split = StringSplit($string, '|')
	$source = _FullPath($_split[1])
	$destination = _FullPath($_split[2])
	If $_split[0] = 2 Then
		$iError = DirMove($source, $destination, 0)
		if @error Then Return SetError(3, 0, 0)
		If $iError <> 1 Then Return SetError(4, 0, 0)
		Return $iError
	EndIf
	Switch $_split[3]
		Case 'o'
			_DirMoveEx($source, $destination, 1)
		Case Else
			_DirMoveEx($source, $destination, 0)
	EndSwitch
	$iError = DirRemove($source, 1)
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 1 Then Return SetError(4, 0, 0)
EndFunc   ;==>_DirMove

;===============================================================================
;
; Function Name:	_DirMoveEx()
; Description:		Move a directory and all sub-directories and files
; Syntax:			_DirMoveEx(SourcePath, DestinationPath, Flag)
; Requirements:
;
;===============================================================================
Func _DirMoveEx($sSource, $sDest, $iFlag = 0)
	If $sSource = '' Or $sDest = '' Then Return SetError(1, 0, 0)
	If Not FileExists($sSource) Then Return SetError(2, 0, 0)
	If StringInStr(FileGetAttrib($sSource), 'D', 2) = 0 Then Return SetError(3, 0, 0)
	Local $fInside = False
	$sDest = StringRegExpReplace($sDest, '[\\/]+$', '')
	If Not @error And @extended = 1 Then $fInside = True
	$sSource = StringRegExpReplace($sSource, '[\\/]+$', '')
	If Not @error And @extended = 1 Then $fInside = False
	If $fInside Then
		Local $sDestDir = StringRegExpReplace($sSource, '.*?[\\/]([^\\/]+)[\\/]*$', '\1')
		If @error Or @extended <> 1 Then Return SetError(4, 0, 0)
		$sDest &= '\' & $sDestDir
	EndIf
	Local $iError = 0
	If Not FileExists($sDest) Then $iError = DirMove($sSource, $sDest)
	If $iError = 1 Then Return SetError(0, 1, 1)
	If DirCreate($sDest) = 0 Then Return SetError(5, 0, 0)
	FileMove($sSource & '\*', $sDest, $iFlag)
	Local $hSource = FileFindFirstFile($sSource & '\*')
	If $hSource = -1 Then Return SetError(0, DirRemove($sSource), 2)
	While 1
		Local $sDir = FileFindNextFile($hSource)
		If @error Then ExitLoop
		Local $sNextSource = $sSource & '\' & $sDir
		Local $sNextDest = $sDest & '\' & $sDir
		If StringInStr(FileGetAttrib($sNextSource), 'D', 2) Then
			_DirMoveEx($sNextSource, $sNextDest, $iFlag)
			$iError += @error
		EndIf
	WEnd
	FileClose($hSource)
	Return SetError($iError, DirRemove($sSource), 3)
EndFunc   ;==>_DirMoveEx

;===============================================================================
;
; Function Name:	_DirName()
; Description:		Returns the name of a directory
; Syntax:			_DirName(X:\Dir\Full\Path)
;
;===============================================================================
Func _DirName($path)
	Local $_path = StringSplit(_NormalPath($path), '\')
	Return $_path[$_path[0]]
EndFunc   ;==>_DirName

;===============================================================================
;
; Function Name:	_FileCreatePlus()
; Description:      Creates or zero's out the length of the file specified.
; Syntax:			_FileCreatePlus(Path1\File1;File2|File2|Path2\File3)
; Requirements:		_FileInfo , _FullPath & _EmptyFileCreate
;
;===============================================================================
Func _FileCreatePlus($string)
	Local $_paths, $_files, $file1, $path
	$_paths = StringSplit($string, '|')
	For $i = 1 To $_paths[0]
		$_files = StringSplit($_paths[$i], ';')
		$file1 = _FullPath($_files[1])
		$path = _FileInfo($file1, 0)
		_EmptyFileCreate($file1)
		For $d = 2 To $_files[0]
			_EmptyFileCreate($path & '\' & $_files[$d])
		Next
	Next
EndFunc   ;==>_FileCreatePlus

Func _EmptyFileCreate($filepath)
	Local $write
	$write = FileOpen($filepath, 10)
	If Not $write = -1 Then FileWrite($write, '')
	FileClose($write)
EndFunc   ;==>_EmptyFileCreate

;===============================================================================
;
; Function Name:	_FileCopy()
; Description:		Copy file(s) from source to destination
; Syntax:			_FileCopy(source|destination)
;					source = Path\file1;file2;file3 | destination = Path
;					source = Path\file | destination = Path or File
; Requirements:		_FileInfo & _FullPath
;
;===============================================================================
Func _FileCopy($string)
	Local $_paths, $destination, $_source, $source, $source_dir, $flag, $iError
	$_paths = StringSplit($string, '|')
	If Not @error Then
		$destination = _FullPath($_paths[2])
		$_source = StringSplit($_paths[1], ';')
		$source = _FullPath($_source[1])
		If $_paths[0] = 3 And $_paths[3] = 'o' Then
			$flag = 9
		Else
			$flag = 8
		EndIf
		If $_source[0] <> 1 Then
			For $f = 1 To $_source[0]
				$source_dir = _FileInfo($source, 0)
				$iError = FileCopy($source_dir & '\' & $_source[$f], $destination, $flag)
			Next
		Else
			$iError = FileCopy($source, $destination, $flag)
		EndIf
	EndIf
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 1 Then Return SetError(4, 0, 0)
EndFunc   ;==>_FileCopy

;===============================================================================
;
; Function Name:	_FileDelete()
; Description:		Deletes files
; Syntax:			_FileDelete(Path1\file1;file2|Path2\file3)
; Requirements:		_FileInfo & _FullPath
;
;===============================================================================
Func _FileDelete($string)
	Local $_paths, $files, $path, $iError
	$_paths = StringSplit($string, '|')
	For $i = 1 To $_paths[0]
		$files = StringSplit($_paths[$i], ';')
		$path = _FileInfo($files[1], 0)
		FileDelete(_FullPath($files[1]))
		For $f = 2 To $files[0]
			$iError = FileDelete(_FullPath($path & '\' & $files[$f]))
		Next
	Next
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 1 Then Return SetError(4, 0, 0)
EndFunc   ;==>_FileDelete

;===============================================================================
;
; Function Name:	_FileInfo()
; Description:		Returns path, name or extension of a gived file full-path.
; Paremeters:		flag = 0 --> returns "Path"
; 					flag = 1 --> returns "Name+Extension"
; 					flag = 2 --> returns "Name"
; 					flag = 3 --> returns "Extension"
;
;===============================================================================
Func _FileInfo($filepath, $flag)
	Local $path, $file, $dot, $name, $ext
	$filepath = _NormalPath($filepath)
	$path = StringLeft($filepath, StringInStr($filepath, '\', 0, -1) - 1)
	$file = StringTrimLeft($filepath, StringInStr($filepath, '\', 0, -1))
	$dot = StringInStr($file, '.', 0, -1)
	Select
		Case $dot = 0
			$name = $file
			$ext = ''
		Case Else
			$name = StringLeft($file, $dot - 1)
			$ext = StringTrimLeft($file, $dot)
	EndSelect
	Select
		Case $flag = 0
			Return $path
		Case $flag = 1
			Return $file
		Case $flag = 2
			Return $name
		Case $flag = 3
			Return $ext
	EndSelect
EndFunc   ;==>_FileInfo

;===============================================================================
;
; Function Name:	_FileMove()
; Description:		Renames a file
; Syntax:			_FileRename(Path\File|NewName)
; Requirements:		_FullPath
;
;===============================================================================
Func _FileMove($string)
	Local $_split, $source, $destination, $iError
	$_split = StringSplit($string, '|')
	$source = _FullPath($_split[1])
	$destination = _FullPath($_split[2])
	If $_split[0] = 3 And $_split[3] = 'o' Then
		$iError = FileMove($source, $destination, 9)
	Else
		$iError = FileMove($source, $destination, 8)
	EndIf
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 1 Then Return SetError(4, 0, 0)
EndFunc   ;==>_FileMove

;===============================================================================
;
; Function Name:	_FixDriveLetter()
; Description:		If current drive is X:\, then replaces all other drive letters (C:\, D:\, ecc...) in a file.
; Syntax:			_FixDriveLetter(Path\File|skip*)
;					skip=LETTER(S) --> skip letters are not replaced
;					* --> not casesensitive
; Requirements:		_FullPath
;
;===============================================================================
Func _FixDriveLetter($string, $sBase)
	Local $_string, $file, $casesense, $driveletter, $skip, $_letters[26], $do, $_replace[26], $read, $_read, $lines, $replaces, $write, $_write
	$_string = StringSplit($string, '|')
	$file = _FullPath($_string[1], $sBase)
	$casesense = 1
	$driveletter = StringLeft($sBase, 1)
	If $_string[0] > 1 Then
		$skip = $driveletter & $_string[2]
		If StringInStr($skip, '*') Then $casesense = 0
	Else
		$skip = $driveletter
	EndIf
	$_letters[0] = 'A'
	$_letters[1] = 'B'
	$_letters[2] = 'C'
	$_letters[3] = 'D'
	$_letters[4] = 'E'
	$_letters[5] = 'F'
	$_letters[6] = 'G'
	$_letters[7] = 'H'
	$_letters[8] = 'I'
	$_letters[9] = 'J'
	$_letters[10] = 'K'
	$_letters[11] = 'L'
	$_letters[12] = 'M'
	$_letters[13] = 'N'
	$_letters[14] = 'O'
	$_letters[15] = 'P'
	$_letters[16] = 'Q'
	$_letters[17] = 'R'
	$_letters[18] = 'S'
	$_letters[19] = 'T'
	$_letters[20] = 'U'
	$_letters[21] = 'V'
	$_letters[22] = 'W'
	$_letters[23] = 'X'
	$_letters[24] = 'Y'
	$_letters[25] = 'Z'
	$do = 0
	For $s = 0 To 25
		If Not StringInStr($skip, $_letters[$s], $casesense) Then
			$do = $do + 1
			$_replace[$do] = $_letters[$s]
		EndIf
	Next
	If FileExists($file) Then
		$read = FileOpen($file, 0)
		$_read = StringSplit(StringStripCR(FileRead($read, FileGetSize($file))), @LF)
		FileClose($read)
		$lines = $_read[0]
		While 1
			If $_read[$lines] = '' Then
				$lines = $lines - 1
			Else
				ExitLoop
			EndIf
		WEnd
		Local $_write[$lines + 1]
		For $l = 0 To $lines
			For $d = 1 To $do
				If StringInStr($_read[$l], $_replace[$d] & ':\', $casesense) Then
					$_read[$l] = StringReplace($_read[$l], $_replace[$d] & ':\', $driveletter & ':\', '', $casesense)
					$replaces = 1
				EndIf
				If StringInStr($_read[$l], $_replace[$d] & ':/', $casesense) Then
					$_read[$l] = StringReplace($_read[$l], $_replace[$d] & ':/', $driveletter & ':/', '', $casesense)
					$replaces = 1
				EndIf
			Next
			$_write[$l] = $_read[$l]
		Next
		If $replaces = 1 Then
			$write = FileOpen($file, 2)
			For $l = 1 To $lines
				FileWriteLine($write, $_write[$l])
			Next
			FileClose($write)
		EndIf
	EndIf
EndFunc   ;==>_FixDriveLetter

;===============================================================================
;
; Function Name:	_FixUserProfile()
; Description:		Once %USERPROFILE% is defined, renames a directory if its name
;					change when switching OS Lang.
;
;===============================================================================
Func _FixUserProfile($userprofile, $dir, $name)
	Local $cfgfile, $old
	$cfgfile = $userprofile & '\x-launcher.cfg'
	If FileExists($cfgfile) Then
		$old = IniRead($cfgfile, 'UserProfile', $name, '')
		If $dir <> $old Then
			DirMove($userprofile & '\' & $old, $userprofile & '\' & $dir)
			IniWrite($cfgfile, 'UserProfile', $name, $dir)
		EndIf
	Else
		DirCreate($userprofile)
		IniWrite($cfgfile, 'UserProfile', $name, $dir)
	EndIf
EndFunc   ;==>_FixUserProfile

;===============================================================================
;
; Function Name:	_FullPath()
; Description:		Returns the full path from a relative path.
;					\path --> path's relative to current drive's root
;					.\path --> path's relative to root
;					..\path --> path's relative to up level
;					..\..\path --> up two leves, and go on
;
;===============================================================================
Func _FullPath($string, $sBase = $Root)
	Local $_slash, $fullpath, $up, $cd, $diff
	If $string = '' Then Return ($string)
	If StringLeft($string, 2) = '\\' Then Return ($string)
	$_slash = StringSplit(_NormalPath($string), '\')
	Select
		Case $_slash[1] = ''
			$fullpath = StringLeft($sBase, 2) & $string
		Case $_slash[1] = '.'
			$fullpath = $sBase & StringTrimLeft($string, 1)
		Case $_slash[1] = '..'
			$up = StringSplit($string, '..', 1)
			$cd = StringSplit($sBase, '\')
			$diff = $cd[0] - $up[0] + 1
			If $diff <= 0 Then Exit (10)
			$fullpath = $cd[1]
			For $i = 2 To $diff
				$fullpath = $fullpath & '\' & $cd[$i]
			Next
			$fullpath = $fullpath & $up[$up[0]]
		Case Else
			$fullpath = $string
	EndSelect
	Return ($fullpath)
EndFunc   ;==>_FullPath

;===============================================================================
;
; Function Name:	_FullPathPlus()
; Description:		Convers a string in a fullpath transformend
; Syntax:			_FullPathPlus(String|Options):
;					~ --> returns the 8.3 short path+name of the string passed
;					%20 --> URI encodes the string
;					\\ --> replaces '\' with '\\'
;					/ --> replaces '\' with '/'
;					" --> return string enclosed between apexes: "String"
;					= --> the string isn't interpreted as a path
; Requirements:		_FullPath
;
;===============================================================================
Func _FullPathPlus($string)
	Local $_string, $newstring, $options
	$_string = StringSplit($string, '|')
	If @error Then Return (_FullPath($string))
	$options = $_string[$_string[0]]
	If StringInStr($options, '=') Then
		$newstring = $_string[1]
		For $_s = 2 To $_string[0] - 1
			$newstring = $newstring & '|' & $_string[$_s]
		Next
		Return ($newstring)
	EndIf
	$newstring = _FullPath($_string[1])
	If StringInStr($options, '~') Then $newstring = FileGetShortName($newstring)
	If StringInStr($options, '%20') Then $newstring = _PathEncode($newstring)
	If StringInStr($options, '\\') Then $newstring = StringReplace($newstring, '\', '\\')
	If StringInStr($options, '/') Then $newstring = StringReplace($newstring, '\', '/')
	If StringInStr($options, '"') Then $newstring = '"' & $newstring & '"'
	Return ($newstring)
EndFunc   ;==>_FullPathPlus

;===============================================================================
;
; Function Name:	_IniReadPlus()
; Description:		Reads a value from a .ini file, only if it's <> ''
;
;===============================================================================
Func _IniReadPlus($filename, $section, $key, $default)
	Local $var
	$var = IniRead($filename, $section, $key, $default)
	Select
		Case $var = ''
			Return $default
		Case Else
			Return $var
	EndSelect
EndFunc   ;==>_IniReadPlus

;===============================================================================
;
; Function Name:	_JavaCheck()
; Description:		Searches the more updated Java installation path 
;					between installed (Win) and \Lib\Java (Pack)
;
; The procedures follow this schema:
;WIN	PACK		SETUP		RUN_JG		JG_ACTIONS			RETURN
;no		no			no			yes			download+install	PACK_JAVA_PATH
;no		no			yes			yes			install				PACK_JAVA_PATH
;no		yes			no			no			-					PACK_JAVA_PATH
;no		yes			yes			yes			update				PACK_JAVA_PATH
;yes	no			no			no			-					WIN_JAVA_PATH
;yes	no			yes			yes			install				MAX_VERSION(PACK_JAVA_PATH,WIN_JAVA_PACK)
;yes	yes			no			no			-					MAX_VERSION(PACK_JAVA_PATH,WIN_JAVA_PACK)
;yes	yes			yes			yes			update				MAX_VERSION(PACK_JAVA_PATH,WIN_JAVA_PACK)
;
;LEGENDA:
;WIN --> Java installed into host PC
;PACK --> Java present into \Lib\Java folder
;SETUP --> Java setup present into \Lib\Java\setup folder
;RUN_JG --> JavaGet routines execution
;JG_ACTIONS --> actions performed by JavaGet routines, if executed
;RETURN --> Java path returned by _JavaCheck
;===============================================================================
Func _JavaCheck($AppName, $ScriptIni, $LibPath, $RootPath)
	Local $s_version
	Local $JavaNeeded
	Local $iLang = _Language()
	Local $s_JavaWinPath, $s_JavaWinVer
	Local $s_JavaPackPath, $s_JavaPackVer

	_DebugWrite("Javacheck : executing")
	$s_JavaWinPath = ""
	$s_JavaWinVer = "0"
	$s_JavaPackPath = ""
	$s_JavaPackVer = "0"

	$JavaNeeded = IniRead($ScriptIni, 'Options', 'Java', 'false')
	$s_JavaPackPath = "$Lib$\Java"

	;Search into the registry if is already installed on the Guest PC
	$s_version = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment","CurrentVersion")
	If $s_version <> "" Then
		$s_JavaWinPath = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Runtime Environment\" & $s_version,"JavaHome")
		;(Nonsense) JavaPath present in the registry, but folder does not exist --> switch to JavaGet
		If Not FileExists($s_JavaWinPath) Then
			$s_JavaWinPath = ""
		EndIf
	EndIf

	;Java not required and Java installed not found, return generic local path, 
	;else returns the more updated version between "WIN" and "PACK"
	;This allows that also programs like Firefox (requiring Java for some operations) 
	;to use installed Java, if not present into the pack
	If $JavaNeeded = 'false' and $s_JavaWinPath = "" Then
		Return $s_JavaPackPath
	EndIf
	
	;Java required, activate JavaGet
	If $JavaNeeded = 'true' or $JavaNeeded = 'optional' Then
		_JavaGet($AppName, $ScriptIni, $LibPath, $RootPath, $iLang, $s_JavaWinPath)
	EndIf

	;Java optional and installation refused, disable next Java installations and return generic local path
	If $JavaNeeded = 'optional' and $s_JavaWinPath = "" and not FileExists($s_JavaPackPath & "\bin\javaw.exe") Then
		IniWrite($ScriptIni, 'Options', 'Java', 'false')
		Return $s_JavaPackPath
	EndIf
	
	;Both Java installed and Java local found
	If FileExists($s_JavaWinPath & "\bin\javaw.exe") Then
		$s_JavaWinVer = FileGetVersion($s_JavaWinPath & "\bin\javaw.exe")
	EndIf
	If FileExists($s_JavaPackPath & "\bin\javaw.exe") Then
		$s_JavaPackVer = FileGetVersion($s_JavaPackPath & "\bin\javaw.exe")
	EndIf

	;Return more updated version. If both exists with same version, use installed one (theorically quicker)
	If $s_JavaWinVer >= $s_JavaPackVer Then
		Return $s_JavaWinPath
	Else
		Return $s_JavaPackPath
	EndIf

EndFunc   ;==>_JavaCheck

;===============================================================================
;
; Function Name:	_JavaGet()
; Description:		Gets Java from repository and install it under $Lib$\Java
;
;===============================================================================
Func _JavaGet($AppName, $ScriptIni, $LibPath, $RootPath, $iLang, $s_JavaWinPath)
	Opt("TrayAutoPause", 0)
	Opt("TrayOnEventMode", 1)
	Opt("TrayMenuMode", 1)
	TrayCreateItem("Exit")
	TrayItemSetOnEvent(-1, "_ExitJg")
	TraySetState()
	TraySetToolTip($sJGAppName)

	;Local $s7Zip = "..\7za\7za.exe"
	Local $s7Zip = "..\7za\7z.exe"
	Local $sJava = "bin\java.exe"
	Local $sJavaw = "bin\javaw.exe"
	Local $sUnPack = "bin\unpack200.exe"
	Local $sSetup = "setup\*.exe"
	Local $sSetupDown = "setup\java-setup.exe"

	_DebugWrite("Javaget : executing")

	If Not FileExists($LibPath & "\Java") Then _DirCreate($LibPath & "\Java")

	FileChangeDir($LibPath & "\Java")
;Msgbox(0,"Current path",$LibPath & "\Java")
	; Test processo multiplo
	;If _ProcessExistsOther() Then Exit 1

	; Selezione operazioni
	Switch _JavaSearch($sJava, $sJavaw, $sSetup, $s_JavaWinPath)
		Case 0 ; Niente
			;Msgbox(0,"Case 0","Case 0")
			Return _CloseJG(0)

		Case 1 ; Download
			;Msgbox(0,"Case 1","Case 1")
			$iMsgBoxAnswer = MsgBox(49, $AppName, $aMessage[2][$iLang])
			If $iMsgBoxAnswer = 2 Then Return _CloseJG(0)
			_Download($sJavaURL, $sSetupDown, $iLang)
			If @error Or Not FileExists($sSetupDown) Then
				MsgBox(262160, $AppName & ": Error", $aMessage[5][$iLang])
				Return _CloseJG(1)
			EndIf
			$sSetup = $sSetupDown

		Case 2 ; Aggiornamento
			;Msgbox(0,"Case 2","Case 2")
			$iMsgBoxAnswer = MsgBox(49, $AppName, $aMessage[3][$iLang])
			If $iMsgBoxAnswer = 2 Then Return _CloseJG(1)

		Case 3 ; Installazione

	EndSwitch

	; Operazioni preliminari
	If _JavaRunning() <> 0 Then
		$iMsgBoxAnswer = MsgBox(1 + 48 + 262144, $AppName, $aMessage[7][$iLang])
		If $iMsgBoxAnswer = 2 Then Return _CloseJG(2)
	EndIf
	If _JavaRunning() <> 0 Then Return _CloseJG(2)
	TrayTip($AppName, $aMessage[4][$iLang], 10, 1)
	_JavaBackup($sJBak)

;Msgbox(0,"Backup Java on",$sJBak)
	; Estrazione Setup
;Msgbox(0,"_UnZip 1 ",$sSetup & ' ' & $LibPath & "\Java\" & ' ' & $s7Zip )
	_UnZip($sSetup, ".\", $s7Zip)
	If @error Then _Error_Msg(1, $iLang)
;Msgbox(0,"FileDelete 1 ","FileDelete 1 ")
	FileDelete("patchjre.exe")
	If @error Then _Error_Msg(1, $iLang)
;Msgbox(0,"FileDelete 2 ","FileDelete 2 ")
	FileDelete("zipper.exe")
	If @error Then _Error_Msg(1, $iLang)
;Msgbox(0,"_UnZip 2 ","")
	_UnZip("core.zip", ".\", $s7Zip)
	If @error Then _Error_Msg(1, $iLang)
	FileDelete("core.zip")
;Msgbox(0,"_UnZip 3 ","")

	; Creazione file mancanti
	FileMove("regutils.dll", "bin\regutils.dll", 1)
	FileCopy("bin\msvcr71.dll", "bin\new_plugin\msvcr71.dll", 1)
	FileCopy("bin\npdeploytk.dll", "bin\new_plugin\npdeploytk.dll", 1)
;Msgbox(0,"Filecopy done ","")
	_UnPack("lib\*.pack", $sUnPack)
	_UnPack("lib\ext\*.pack", $sUnPack)
	_UnPack("lib\servicetag\*.pack", $sUnPack)
;Msgbox(0,"_UnPack done ","")
	RunWait($sJava & ' -Xshare:dump', @WorkingDir, @SW_HIDE)

	; Operazioni finali
	FileDelete("setup\*.*")
	DirRemove($sJBak, 1)
	Return _CloseJG(0)
EndFunc

;===============================================================================
;
; Function Name:	_Language()
; Description:		Returns System language
;
;===============================================================================
Func _Language()
	Switch @OSLang
		Case "0410", "0810"
			Return 0
		Case Else
			Return 1
	EndSwitch
	Return 0
EndFunc   ;==>_Language

;===============================================================================
;
; Function Name:	_ExitJG()
; Description:		Aborts JavaGet
;
;===============================================================================
Func _ExitJG()
	;MsgBox(262192, $sJGAppName, $aMessage[0][$iLang])
	_JavaResume($sJBak)
	Return _CloseJG(1)
EndFunc   ;==>_ExitJG

;===============================================================================
;
; Function Name:	_CloseJG()
; Description:		JavaGet procedure aborted by user
;
;===============================================================================
Func _CloseJG($retCode)
	TraySetState(2)
	Return $retCode
EndFunc   ;==>_CloseJG

;===============================================================================
;
; Function Name:	_Error_Msg()
; Description:		For JavaGet: show error message and resume old Java backup
;
;===============================================================================
Func _Error_Msg($iMsg, $iLang)
	; Global $sAppName, $aMessage, $iLang
	MsgBox(16 + 262144, $sJGAppName, $aMessage[$iMsg][$iLang])
	_JavaResume($sJBak)
	_CloseJG(4)
EndFunc   ;==>_Error_Msg

;===============================================================================
;
; Function Name:	_JavaSearch()
; Description:		For JavaGet: check various cases for Java
;					0 = No Java
;					1 = Download Java
;					2 = Upgrade Java
;					3 = Install Java from \Lib\Java\setup
;
;===============================================================================
Func _JavaSearch($sJava, $sJavaw, $sSetup, $s_JavaWinPath)
	; Global $sSetup, $sJava, $sJavaw
	Local $iAction = 2
	If Not FileExists($sJava) Or FileGetSize($sJavaw) < 1000 Then $iAction += 1
	Local $sPath = _SearchSetup($sSetup)
	If @error Or $sPath = "" Or Not FileExists($sPath) Then $iAction -= 2
	If $s_JavaWinPath <> "" And $iAction = 1 Then $iAction = 0
	; 0 Nothing to do (Java=Y Setup=N), 1 Download (Java=N Setup=N), 2 Update (Java=Y Setup=Y), 3 Install (Java=N Setup=Y)
	Return $iAction
EndFunc   ;==>_JavaSearch

;===============================================================================
;
; Function Name:	_SearchSetup()
; Description:		For JavaGet: searches the setup file and fixes path
;
;===============================================================================
Func _SearchSetup($sSearch)
	Local $hPath = FileFindFirstFile($sSearch)
	If $hPath = -1 Then Return SetError(1, 0, "")
	Local $sPath = FileFindNextFile($hPath)
	If @error Then Return SetError(1, 0, "")
	FileClose($hPath)
	Local $sDir = StringRegExpReplace($sSearch, "[^\\/]+$", "", 1)
	Return $sDir & $sPath
EndFunc   ;==>_SearchSetup

;===============================================================================
;
; Function Name:	_JavaBackup()
; Description:		For JavaGet: backups original Java into another folder for eventual resume
;
;===============================================================================
Func _JavaBackup($sBackup)
	If Not FileExists("bin") Then Return SetError(1, 0, 0)
	DirRemove($sBackup, 1)
	DirCreate($sBackup)
	FileMove("*", $sBackup & "\*", 0)
	DirMove("bin", $sBackup & "\bin", 0)
	DirMove("lib", $sBackup & "\lib", 0)
	Return 1
EndFunc   ;==>_JavaBackup

;===============================================================================
;
; Function Name:	_JavaResume()
; Description:		For JavaGet: resumes backups of original Java into Java folder
;					Called in case of error during installation of new Java
;
;===============================================================================
Func _JavaResume($sBackup)
	If Not FileExists($sBackup) Then Return SetError(1, 0, 0)
	FileDelete("*.*")
	FileMove($sBackup & "\*", "*", 0)
	DirMove($sBackup & "\bin", "bin", 0)
	DirMove($sBackup & "\lib", "lib", 0)
	DirRemove($sBackup, 1)
	Return 1
EndFunc   ;==>_JavaResume

;===============================================================================
;
; Function Name:	_UnPack()
; Description:		For JavaGet: unpacks all *.pack files
;
;===============================================================================
Func _UnPack($sSearch, $sUnPack)
	; Global $sUnPack
	If Not FileExists($sUnPack) Then Return SetError(1, 0, 0)
	Local $hPath = FileFindFirstFile($sSearch)
	If $hPath = -1 Then Return SetError(2, 0, 0)
	Local $sDir = StringRegExpReplace($sSearch, "[^\\/]+$", "", 1)
	Local $sPath, $sDest, $sParam, $iError, $iCount = 0
	While 1
		$sPath = FileFindNextFile($hPath)
		If @error Then ExitLoop
		If StringInStr(FileGetAttrib($sPath), 'D', 2) <> 0 Then ContinueLoop
		$sDest = StringRegExpReplace($sPath, "\.pack$", ".jar", 1)
		$sParam = ' -r -q ' & $sDir & $sPath & ' ' & $sDir & $sDest
		$iError = RunWait($sUnPack & $sParam, @WorkingDir, @SW_HIDE)
		If @error Then ContinueLoop
		If $iError > 1 Then ContinueLoop
		$iCount += 1
	WEnd
	FileClose($hPath)
	Return $iCount
EndFunc   ;==>_UnPack

;===============================================================================
;
; Function Name:	_UnZip()
; Description:		For JavaGet: unzip Java setup and core.zip
;
;===============================================================================
Func _UnZip($sZipPath, $sDestDir, $s7Zip, $fFile = "", $fOverwrite = True, $sBasePath = @WorkingDir, $s7ZipPath = "", $fExcludePath = "")
	; Global $s7Zip
	If $s7ZipPath = "" Then $s7ZipPath = $s7Zip
	If Not FileExists($s7ZipPath) Then Return SetError(1, 0, 0)
	If $sBasePath = "" Then $sBasePath = @WorkingDir
	If Not FileExists($sBasePath) Then Return SetError(2, 0, 0)
	Local $sOverwrite = ' -aoa'
	If Not $fOverwrite Then $sOverwrite = ' -aos'
	Local $sExcludePath = ''
	If $fExcludePath Then $sExcludePath = ' -x!' & $fExcludePath
	Local $sParam = ' x "' & $sZipPath & '" -o"' & $sDestDir & '"' & $sExcludePath & $sOverwrite
	If $fFile Then
		$sParam = ' e "' & $sZipPath & '" -o"' & $sDestDir & '" "' & $fFile & '"' & $sOverwrite
	EndIf
	Local $iError = RunWait($s7ZipPath & $sParam, $sBasePath, @SW_HIDE)
	If @error Then Return SetError(1, 0, 0)
	If $iError = 1 Then Return SetError(3, 0, 0)
	If $iError = 2 Then Return SetError(4, 0, 0)
	If $iError > 2 Then Return SetError(5, $iError, 0)
	Return 1
EndFunc   ;==>_UnZip

;===============================================================================
;
; Function Name:	_Download()
; Description:		For JavaGet: downloads Java setup into predefined folder
;
;===============================================================================
Func _Download($sURL, $sDest, $iLang, $iMinByte = 1)
    ; Global $aMessage, $iLang
    If StringInStr(FileGetAttrib($sDest), 'D', 2) <> 0 Then Return SetError(1, 0, 0)
    Local $aPath = StringRegExp($sDest, "^(.*?)[\\/]?([^\\/]+)$", 1)
    If @error Then Return SetError(2, 0, 0)
    If Not FileExists($aPath[0]) Then DirCreate($aPath[0])
    Local $iSize = InetGetSize($sURL)
    If @error Then Return SetError(3, 0, 0)
    If $iSize < $iMinByte Then Return SetError(4, 0, 0)
    Local $hDownload = InetGet($sURL, $sDest & '.part', 1, 1)
    Local $iCount = 0
    While InetGetInfo($hDownload, 2) ; 2 = active
        Local $iBytesRead = InetGetInfo($hDownload, 0)
        $iCount = Round($iBytesRead / $iSize * 100, 0)
        TrayTip($aMessage[6][$iLang], $iCount & "%", 10, 16)
        Sleep(250)
    WEnd
    Local $iBytesRead = InetGetInfo($hDownload, 0)
    If $iBytesRead = -1 Then Return SetError(5, 0, 0)
    If $iBytesRead <> $iSize Then Return SetError(6, 0, 0)
    InetClose($hDownload)
    FileMove($sDest & '.part', $sDest, 1)
    Return 0
EndFunc   ;==>_Download

;===============================================================================
;
; Function Name:	_JavaRunning()
; Description:		For JavaGet: intercept other Java program running through
;					existance of javaw.exe process active
;
;===============================================================================
Func _JavaRunning()
	Local $i_PID = ProcessExists("javaw.exe")
	If $i_PID <> 0 Then Return $i_PID
	$i_PID = ProcessExists("java.exe")
	Return $i_PID
EndFunc   ;==>_JavaRunning

;===============================================================================
;
; Function Name:	_MozPrefs()
; Description:		Writes to Mozilla's configuration files
; Syntax:			_MozPrefs(File, Preference, Value, User)
;					Mode = Global --> global preference
;					Mode = User --> user preference
; Requirements:		_FileInfo, _FullPath & _RegKeyLoad
;
;===============================================================================
Func _MozPrefs($file, $pref, $value, $mode)
	Local $begin, $replaces = 0, $exists = 0
	Select
		Case $mode = 'Global'
			$begin = 'pref("'
		Case $mode = 'User'
			$begin = 'user_pref("'
	EndSelect
	If FileExists($file) Then
		Local $read, $_read, $lines
		$read = FileOpen($file, 0)
		$_read = StringSplit(StringStripCR(FileRead($read, FileGetSize($file))), @LF)
		FileClose($read)
		$lines = $_read[0]
		While 1
			If $_read[$lines] = '' Then
				$lines = $lines - 1
			Else
				ExitLoop
			EndIf
		WEnd
		Local $_write[$lines + 1]
		For $l = 0 To $lines
			If StringInStr($_read[$l], $pref) <> 0 Then
				$_write[$l] = $begin & $pref & '", ' & $value & ');'
				If $_write[$l] <> $_read[$l] Then $replaces = 1
				$exists = 1
			Else
				$_write[$l] = $_read[$l]
			EndIf
		Next
		If $replaces = 1 Then
			Local $write = FileOpen($file, 2)
			For $l = 1 To $lines
				FileWriteLine($write, $_write[$l])
			Next
			FileClose($write)
		EndIf
		If $exists = 0 Then
			Local $wfile
			$wfile = FileOpen($file, 1)
			FileWriteLine($wfile, $begin & $pref & '", ' & $value & ');')
			FileClose($wfile)
		EndIf
	EndIf
	If Not FileExists($file) Then
		Local $newfile
		$newfile = FileOpen($file, 9)
		FileWriteLine($newfile, $begin & $pref & '", ' & $value & ');')
		FileClose($newfile)
	EndIf
EndFunc   ;==>_MozPrefs

;===============================================================================
;
; Function Name:	_NormalPath()
; Description:		Returns a standard path string with only singles backslash
;
;===============================================================================
Func _NormalPath($path)
	Local $_normalpath, $normalpath
	$_normalpath = StringSplit(StringReplace($path, '/', '\'), '\')
	$normalpath = $_normalpath[1]
	For $n = 2 To $_normalpath[0]
		If $_normalpath[$n] <> '' Then $normalpath = $normalpath & '\' & $_normalpath[$n]
	Next
	Return $normalpath
EndFunc   ;==>_NormalPath

;===============================================================================
;
; Function Name:	_PathEncode()
; Description:		Returns a URI Encoding of the path
;					Special path characters (/\ are not encoded)
;
;===============================================================================
Func _PathEncode($path)
    Local $aData = StringSplit(BinaryToString(StringToBinary($path,4),1),"")
    Local $nChar
    $path=""
    For $i = 1 To $aData[0]
        ;ConsoleWrite($aData[$i] & @CRLF)
        $nChar = Asc($aData[$i])
		;ConsoleWrite($aData[$i] & ' ---> ' & $nChar & @CRLF)
        Switch $nChar
            Case 45 To 58, 65 To 90, 92, 95, 97 To 122, 126
                $path &= $aData[$i]
            ;Case 32
            ;    $sData &= "%20"
            Case Else
                $path &= "%" & Hex($nChar,2)
        EndSwitch
    Next
    Return $path
EndFunc

;===============================================================================
;
; Function Name:	_ProcessExistsOther()
; Description:		Returns True if Process > 1
; Syntax:			_ProcessExistsOther(Process)
; Return:			True if Process > 1
;
;===============================================================================
Func _ProcessExistsOther($sProcessName = "")
	Local $a_Processes
	If @OSVersion = "WIN_2000" Or @OSVersion = "WIN_NT4" Then
		Local $i_PID = @AutoItPID
		If $sProcessName <> "" Then $i_PID = ProcessExists($sProcessName)
		If $i_PID = 0 Then Return SetError(1, 0, False)
		$a_Processes = ProcessList()
		If @error Then Return SetError(2, 0, False)
		For $i = 1 To $a_Processes[0][0]
			If $a_Processes[$i][1] = $i_PID Then
				$sProcessName = $a_Processes[$i][0]
				ExitLoop
			EndIf
		Next
	EndIf
	If $sProcessName = "" Then $sProcessName = @ScriptName
	$a_Processes = ProcessList($sProcessName)
	If @error Then Return SetError(2, 0, False)
	If $a_Processes[0][0] < 2 Then Return SetError(0, 0, False)
	Return SetError(0, 0, True)
EndFunc   ;==>_ProcessExistsOther

;===============================================================================
;
; Function Name:	_Run()
; Description:		Run the portable program
; Syntax:			_Run(Commandline,RunWait,HideShellWindow)
;
;===============================================================================
Func _Run($commandLine, $runWait, $hideShellWindow)
	If $hideShellWindow = 'true' Then
		If $runWait = 'true' Then
			_DebugWrite("===== RunWait program : " & $commandLine)
			RunWait(@ComSpec & ' /c ' & $commandLine, '', @SW_HIDE)
		Else
			_DebugWrite("===== Run program : " & $commandLine)
			Run(@ComSpec & ' /c ' & $commandLine, '', @SW_HIDE)
		EndIf
	Else
		If $runWait = 'true' Then
			_DebugWrite("===== RunWait program : " & $commandLine)
			RunWait($commandLine)
		Else
			_DebugWrite("===== Run program : " & $commandLine)
			Run($commandLine)
		EndIf
	EndIf
EndFunc   ;==>_Run

;===============================================================================
;
; Function Name:	_RunWait()
; Description:		Runs an external program
; Syntax:			_RunWait(Path\File|Parameters)
; Requirements:		_FileInfo & _FullPath
;
;===============================================================================
Func _RunWait($string, $sBase)
	Local $_split, $filepath, $ext, $parameters, $ste, $iError
	$_split = StringSplit($string, '|')
	$filepath = _FullPath($_split[1], $sBase)
	$ext = _FileInfo($filepath, 3)
	If $_split[0] = 2 And $_split[2] <> '' Then
		Select
			Case StringLeft($_split[2], 1) = '-' Or StringLeft($_split[2], 1) = '/'
				$parameters = ' ' & $_split[2]
			Case Else
				$parameters = ' "' & $_split[2] & '"'
		EndSelect
	Else
		$parameters = ''
	EndIf
	$ste = '"' & $filepath & '"' & $parameters
	Select
		Case $ext = 'exe' Or $ext = 'bat' Or $ext = 'com' Or $ext = 'pif'
			$iError = RunWait($ste)
		Case Else
			$iError = RunWait(@ComSpec & ' /c ' & $ste, '', @SW_HIDE)
	EndSelect
	if @error Then Return SetError(3, 0, 0)
	If $iError <> 0 Then Return SetError(4, 0, 0)
EndFunc   ;==>_RunWait

;===============================================================================
;
; Function Name:	_SetPath()
; Description:		Sets the environmental variable %PATH%
; Syntax:			_SetPath(%PATH%;Path1;Path2)
; Requirements:		_FullPath
;
;===============================================================================
Func _SetPath($string, $log, $logfile)
	Local $_paths, $path
	If $string <> '' Then
		$_paths = StringSplit($string, ';')
		$path = _FullPath($_paths[1])
		For $i = 2 To $_paths[0]
			$path = $path & ';' & _FullPath($_paths[$i])
		Next
		EnvSet('PATH', $path)
		If $log = 'true' Then IniWrite($logfile, 'Environment', 'PATH', $path)
	EndIf
EndFunc   ;==>_SetPath

;===============================================================================
;
; Function Name:	_SetEnv()
; Description:		Sets an environmental variable
; Requirements:		_FullPathPlus
;
;===============================================================================
Func _SetEnv($var, $value, $log, $logfile)
	$value = _FullPathPlus($value)
	EnvSet($var, $value)
	If $log = 'true' Then IniWrite($logfile, 'Environment', $var, $value)
EndFunc   ;==>_SetEnv

;===============================================================================
;
; Function Name:	_SplashScreen()
; Description:		Shows a nice splash screen while starting the file to run
; Requirements:		_FullPath
;
;===============================================================================
Func _SplashScreen($Title_SS, $Image, $TimeOut_SS, $Temp, $Root, $Width_SS, $Height_SS)
    If $Image <> '' Then $Image = _FullPath($Image, $Root)
    If $Image = '' Or Not FileExists($Image) Then
        $Image = $tempdir & "\x-splash.jpg"
        FileInstall('graphics\x-splash.jpg', $Image, 1)
    EndIf
    If Not FileExists($Image) Then
        Return SetError(1, 0, False)
    EndIf
	
    Local $width = 307, $height = 213

    $TimeOut_SS = Number($TimeOut_SS)
    If $TimeOut_SS < 500 Then $TimeOut_SS = 3000

    Local $opt = 1
    If $Title_SS <> '' Then $opt = -1

    SplashImageOn("", $Image, $width, $height, -1, -1, 1)

    If @error Then
    EndIf
    Sleep($TimeOut_SS)
    SplashOff()
EndFunc

Func _DebugLog($msg)
    Local $logfile = @ScriptDir & "\launcher_debug.log"
    Local $fh = FileOpen($logfile, 1)
    If $fh <> -1 Then
        FileWriteLine($fh, @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " - " & $msg)
        FileClose($fh)
    EndIf
EndFunc   ;==>_SplashScreen

;===============================================================================
;
; Function Name:	_SplashScreenOff()
; Description:		Turn Splash Screen Off
; Requirements:
;
;===============================================================================
Func _SplashScreenOff()
	SplashOff()
EndFunc   ;==>_SplashScreenOff

;===============================================================================
;
; Function Name:	_TrayTipOn()
; Description:		Shows a nice tray tip while starting the file to run
; Requirements:
;
;===============================================================================
Func _TrayTipOn($title, $TimeOut_SS)
    TraySetState()
    TrayTip($title, "Software made portable with winPenPack Technology" & @CRLF & "http://www.winpenpack.com", 3, 1+16)
    AdlibRegister("_TrayTipOff", $TimeOut_SS)
    Return True
EndFunc   ;==>_SplashScreen

;===============================================================================
;
; Function Name:	_TrayTipOff()
; Description:		Turn TrayTip Off
; Requirements:
;
;===============================================================================
Func _TrayTipOff()
    TraySetState(2)
    AdlibUnRegister()
EndFunc   ;==>_SplashScreenOff

;===============================================================================
;
; Function Name:	_StringReplace()
; Description:		Replaces a string between two others one in a file
;
;===============================================================================
Func _StringReplace($file, $begin, $end, $replace, $overwrite = False)
	Local $read, $_read, $lines, $_begin, $_end, $replaces = 0, $write, $_write
	If FileExists($file) Then
		$read = FileOpen($file, 0)
		$_read = StringSplit(StringStripCR(FileRead($read, FileGetSize($file))), @LF)
		FileClose($read)
		$lines = $_read[0]
		While 1
			If $_read[$lines] = '' Then
				$lines = $lines - 1
			Else
				ExitLoop
			EndIf
		WEnd
		Local $_write[$lines + 1]
		For $l = 0 To $lines
			If StringInStr($_read[$l], $begin) <> 0 And StringInStr($_read[$l], $end) <> 0 Then
				$_begin = StringSplit($_read[$l], $begin, 1)
				$_end = StringSplit($_read[$l], $end, 1)
				If $overwrite Then
					$_write[$l] = $_begin[1] & $replace & $_end[2]
				Else
					$_write[$l] = $_begin[1] & $begin & $replace & $end & $_end[2]
				EndIf
				If $_write[$l] <> $_read[$l] Then $replaces = 1
			Else
				$_write[$l] = $_read[$l]
			EndIf
		Next
		If $replaces = 1 Then
			$write = FileOpen($file, 2)
			For $l = 1 To $lines
				FileWriteLine($write, $_write[$l])
			Next
			FileClose($write)
		EndIf
	EndIf
EndFunc   ;==>_StringReplace

;===============================================================================
;
; Function Name:	_StringRegExpReplace()
; Description:		Replaces a string between two others one in a file
;
;===============================================================================
Func _StringRegExpReplace($file, $string, $flag)
	Local $count = 0, $modifier = ''
	Local $delimiter = StringSplit($flag, '|')
	If $delimiter[0] > 1 And IsInt($delimiter[2]) Then $count = $delimiter[2]
	If $delimiter[0] > 2 And $delimiter[3] <> '' Then $modifier = $delimiter[3]
	Local $pattern = StringSplit($string, $delimiter[1], 1)
	If @error Or $pattern[0] <> 2 Then Return SetError(1, 0, 0)
	$pattern[1] = _RegExpProtector($pattern[1], 1)
	$pattern[2] = _RegExpProtector($pattern[2], 2, $modifier)
	If FileExists($file) = 0 Then Return SetError(1, 0, 0)
	Local $read = FileRead($file)
	If @error Then Return SetError(2, 0, 0)
	Local $write = StringRegExpReplace($read, $pattern[1], $pattern[2], $count)
	If @error Then Return SetError(2, 0, 0)
	If $write = $read Then Return SetError(0, 0, 0)
	Local $hWrite = FileOpen($file, 2)
	FileWrite($hWrite, $write)
	FileClose($hWrite)
	Return SetError(0, 0, 1)
EndFunc   ;==>_StringRegExpReplace

;===============================================================================
;
; Function Name:	_RegExpProtector()
; Description:		Regular Expression Protector and Variable Expansion
;
;===============================================================================
Func _RegExpProtector($pattern, $type = 1, $modifier = '')
	Local $aVariable = StringRegExp($pattern, '(.*?)(\{([$@%])([a-zA-Z_]+\w*)\3\})', 3)
	If @error = 1 Then Return SetError(0, 0, $pattern)
	If @error = 2 Then Return SetError(1, @extended, $pattern)
	Local $result = '', $length = 0
	For $i = 1 To UBound($aVariable) Step 4
		Local $sValue = ''
		Switch $aVariable[$i + 1]
			Case '@'
				$sValue = Execute('@' & $aVariable[$i + 2])
			Case '$'
				$sValue = Eval($aVariable[$i + 2])
			Case '%'
				$sValue = EnvGet($aVariable[$i + 2])
		EndSwitch
		If $modifier <> '' Then $sValue = _FullPathPlus($sValue & '|' & $modifier)
		Local $protect = '[\\$]'
		If $type = 1 Then $protect = '[\\$\^\[\](){}*+?.|]'
		$sValue = StringRegExpReplace($sValue, $protect, '\\\0')
		$result &= $aVariable[$i - 1] & $sValue
		$length += StringLen($aVariable[$i - 1]) + StringLen($aVariable[$i])
	Next
	$result &= StringRight($pattern, StringLen($pattern) - $length)
	Return $result
EndFunc   ;==>_RegExpProtector

;===============================================================================
;
; Function Name:	_WriteToFile()
; Description:		Writes text to a specific line in a file
; Syntax:			_WriteLine(File, LineX or EOF, String)
;
;===============================================================================
Func _WriteToFile($file, $line, $content)
	Local $ftw, $lineNum, $read, $_read, $lines, $write
	Select
		Case $line = 'EOF'
			$ftw = FileOpen($file, 9)
			FileWriteLine($ftw, $content)
			FileClose($ftw)
		Case StringInStr($line, 'Line')
			$lineNum = StringTrimLeft($line, 4)
			If StringIsInt($lineNum) Then
				If FileExists($file) Then
					$read = FileOpen($file, 0)
					$_read = StringSplit(StringStripCR(FileRead($read, FileGetSize($file))), @LF)
					FileClose($read)
					$lines = $_read[0]
					While 1
						If $_read[$lines] = '' Then
							$lines = $lines - 1
						Else
							ExitLoop
						EndIf
					WEnd
					$write = FileOpen($file, 2)
					If $lineNum <= $lines Then $_read[$lineNum] = $content
					For $l = 1 To $lines
						FileWriteLine($write, $_read[$l])
					Next
					If $lineNum > $lines Then
						For $l = $lines + 1 To $lineNum - 1
							FileWriteLine($write, '')
						Next
						FileWriteLine($write, $content)
					EndIf
					FileClose($write)
				Else
					$ftw = FileOpen($file, 9)
					For $l = 1 To $lineNum - 1
						FileWriteLine($ftw, '')
					Next
					FileWriteLine($ftw, $content)
					FileClose($ftw)
				EndIf
			EndIf
	EndSelect
EndFunc   ;==>_WriteToFile

;===============================================================================
;
; Function Name:	_WriteToPref()
; Description:		Writes to Mozilla's configuration files
; Syntax:			_WriteToPrefs(File, Format, Pref, Value)
; Requirements:		_FileInfo, _FullPath & _RegKeyLoad
;
;===============================================================================
Func _WriteToPref($file, $begin, $mid, $end, $pref, $value)
	Local $replaces = 0, $exists = 0
	If FileExists($file) Then
		Local $read, $_read, $lines
		$read = FileOpen($file, 0)
		$_read = StringSplit(StringStripCR(FileRead($read, FileGetSize($file))), @LF)
		FileClose($read)
		$lines = $_read[0]
		While 1
			If $_read[$lines] = '' Then
				$lines = $lines - 1
			Else
				ExitLoop
			EndIf
		WEnd
		Local $_write[$lines + 1]
		For $l = 0 To $lines
			If StringInStr($_read[$l], $begin & $pref & $mid) <> 0 Then
				$_write[$l] = $begin & $pref & $mid & $value & $end
				If $_write[$l] <> $_read[$l] Then $replaces = 1
				$exists = 1
			Else
				$_write[$l] = $_read[$l]
			EndIf
		Next
		If $replaces = 1 Then
			Local $write = FileOpen($file, 2)
			For $l = 1 To $lines
				FileWriteLine($write, $_write[$l])
			Next
			FileClose($write)
		EndIf
		If $exists = 0 Then
			Local $wfile
			$wfile = FileOpen($file, 1)
			FileWriteLine($wfile, $begin & $pref & $mid & $value & $end)
			FileClose($wfile)
		EndIf
	Else
		Local $newfile
		$newfile = FileOpen($file, 9)
		FileWriteLine($newfile, $begin & $pref & $mid & $value & $end)
		FileClose($newfile)
	EndIf
EndFunc   ;==>_WriteToPref

;=================================================================================================================
;
; Function Name:	_ExpandMultiPath
; Description:		Lists all files in a specified multi path with wildcard - i.e. "c:\dir1\*.txt|F:\dir2\cs*.dat"
; Syntax:			_ExpandWildCard($szMultiPath)
; Parameters:		$szMultiPath  - More path with wildcard separated by "|"
; Return values:	Success - Returns an array with more than 1 elements where 0 = number of element
;                  	The array returned is one-dimensional and is made up as follows:
;                  	$array[0] = Number of Files returned
;                  	$array[1] = 1st File
;                  	$array[2] = 2nd File
;                  	$array[3] = 3rd File
;                  	$array[n] = nth File
; Author:			Roberto Bragaglia
; Modified:
; Remarks:			1) all files returned have the path
;					2) You cannot specify wildcard for directory (only in the filename part)
;
;=================================================================================================================
Func _ExpandMultiPath($szMultiPath, $bOnlyIfExist = False)
	Local $array[1]
	Local $szDrive, $szDir, $szFName, $szExt
	Local $FileList, $FileToRewrite
	$array[0] = 0
	; Separo prima i vari path
	Local $paths = StringSplit($szMultiPath, "|")
	For $ixPath = 1 to $paths[0]
		If StringRegExp ( $paths[$ixPath], "\*|\?", 0 ) = 1 then
			; Sono state specificate wildcard
			$FileToRewrite = _FullPath ($paths[$ixPath])
			_PathSplit($FileToRewrite, $szDrive, $szDir, $szFName, $szExt)
			$FileList=_FileListToArray($szDrive & $szDir, $szFName & $szExt, 1 )
			If @Error = 0 And $FileList[0] > 0 Then
				ReDim $array[$array[0] + $FileList[0] + 1]
				For $ixFile = 1 To $FileList[0]
					$array[$array[0] + $ixFile] = $szDrive & $szDir & $FileList[$ixFile]
				Next
				$array[0] = $array[0] + $FileList[0]
			EndIf
		Else
			If $bOnlyIfExist = False Or FileExists($paths[$ixPath]) Then
				ReDim $array[$array[0] + 2]
				$array[$array[0] + 1] = $paths[$ixPath]
				$array[0] = $array[0] + 1
			EndIf
		EndIf
	Next
	Return $array
EndFunc	;==>_ExpandMultiPath

;===============================================================================
;
; Function Name:	_FirstRun()
; Description:		Execute commands at first run only
; Syntax:			_FirstRun()
; Requirements:		_ProcessExistsOther, _DirCopy, _DirCreate, _DirMove, _DirRemove,
;				    _FileCopy, _FileCreatePlus, _FileDelete, _FileMove, _RunWait
;
;===============================================================================
Func _FirstRun()
	Local $_statusfirstrun, $_stillfirstrun, $_errfirstrun
	Local $iError

	_DebugWrite("[FirstRunOperations] : about to execute ")

	$_statusfirstrun = IniRead($TempLog, 'Status', 'FirstRun', 'false')

	; another first run process in execution
	If $_statusfirstrun = 'true' and _ProcessExistsOther() Then
		Select
			Case $Lang = 'it'
				$_stillfirstrun = '"' & @ScriptName & '"' & @CRLF & 'sta già eseguendo operazioni per la prima esecuzione'
			Case Else
				$_stillfirstrun = '"' & @ScriptName & '"' & @CRLF & 'already executing first run operations'
		EndSelect
		MsgBox(48, $ScriptName, $_stillfirstrun)
		Exit (3)
	EndIf

	DirCreate($Temp)
	IniWrite($TempLog, 'Status', 'FirstRun', 'true')

	$_firstrunoperations = IniReadSection($ScriptIni, 'FirstRunOperations')
	If Not @error Then
		For $fr = 1 To $_firstrunoperations[0][0]
			_DebugWrite("--> " & $_firstrunoperations[$fr][0] & "=" & $_firstrunoperations[$fr][1])
			Select
				Case $_firstrunoperations[$fr][1] = ''
				Case $_firstrunoperations[$fr][0] = 'DirCopy'
					_DirCopy($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'DirCreate'
					_DirCreate($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'DirMove'
					_DirMove($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'DirRemove'
					_DirRemove($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'FileCopy'
					_FileCopy($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'FileCreate'
					_FileCreatePlus($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'FileDelete'
					_FileDelete($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'FileMove'
					_FileMove($_firstrunoperations[$fr][1])
					;If @error Then Return SetError(3, 0, 0)
				Case $_firstrunoperations[$fr][0] = 'RunFile'
					$iError = _RunWait($_firstrunoperations[$fr][1], $Root)
					If @error Then Return SetError(3, 0, 0)
			EndSelect
		Next
	EndIf

	If $iError <> 0 Then Return SetError(3, 0, 0)

	IniWrite($ScriptIni, 'Options', 'FirstRun', 'false')
	IniWrite($TempLog, 'Status', 'FirstRun', 'false')
	
	_DebugWrite("[FirstRunOperations] : executed ")

EndFunc   ;==>_FirstRunSection

;===============================================================================
;
; Function Name:	_SystemLanguage()
; Description:		Identification System language
; Syntax:			_SystemLanguage()
;
;===============================================================================
Func _SystemLanguage($sLang)
	$sLang = EnvGet('LANG')
	If  $sLang='' Then
		Switch @OSLang
			Case "0410", "0810"
				$sLang = 'it'
			Case Else
				$sLang = 'en'
		EndSwitch
	EndIf
	Return $slang
EndFunc   ;==>_SystemLanguage

;===============================================================================
;
; Function Name:	_AddFonts()
; Description:		Add Fonts to system
; Syntax:			_AddFonts(path\file)
; Requirements:		_ExpandMultiPath
;
;===============================================================================
Func _AddFonts($string)
    Local Const $HWND_BROADCAST = 0xFFFF
    Local Const $WM_FONTCHANGE = 0x001D
	Local Const $SMTO_ABORTIFHUNG = 0x0002 
	Local Const $SMTO_NOTIMEOUTIFNOTHUNG = 0x0008 
	Local $FileList

	_DebugWrite("AddFonts : about to execute")

	$FileList = _ExpandMultiPath($string, True)
	If $FileList[0] > 0 Then
		For $IxElem = 1 To $FileList[0]
			Local $FontName
			$FontName = $FileList[$IxElem]
			_DebugWrite("AddFonts : adding " & $FontName)
			DllCall("gdi32.dll","Int","AddFontResource","str",$FontName)
		Next
	EndIf	
	
	; announce fonts added to running applications
	_DebugWrite("AddFonts : announcing")
	DllCall("user32.dll", "int", "SendMessageTimeout", "hwnd", $HWND_BROADCAST, "int", $WM_FONTCHANGE, "int", 0, "int", 0, _
			"int", BitOR ($SMTO_ABORTIFHUNG, $SMTO_NOTIMEOUTIFNOTHUNG ), "int", 50, "dword_ptr*", 0)
	
	_DebugWrite("AddFonts : executed")
	
EndFunc   ;==>_AddFonts

;===============================================================================
;
; Function Name:	_RemoveFonts()
; Description:		Remove Fonts to system
; Syntax:			_RemoveFonts(path\file)
; Requirements:		_ExpandMultiPath
;
;===============================================================================
Func _RemoveFonts($string)
    Local Const $HWND_BROADCAST = 0xFFFF
    Local Const $WM_FONTCHANGE = 0x001D
	Local Const $SMTO_ABORTIFHUNG = 0x0002 
	Local Const $SMTO_NOTIMEOUTIFNOTHUNG = 0x0008 
	Local $FileList
	
	_DebugWrite("RemoveFonts : about to execute")
	
	$FileList=_ExpandMultiPath($string, True)
	If $FileList[0] > 0 Then
		For $IxElem = 1 To $FileList[0]
			Local $FontName
			$FontName = $FileList[$IxElem]
			_DebugWrite("RemoveFonts : removing " & $FontName)
			DllCall("gdi32.dll","Int","RemoveFontResource","str",$FontName)
		Next
	EndIf	
	
	; announce fonts removed to running applications
	_DebugWrite("RemoveFonts : announcing")
	DllCall("user32.dll", "int", "SendMessageTimeout", "hwnd", $HWND_BROADCAST, "int", $WM_FONTCHANGE, "int", 0, "int", 0, _
			"int", BitOR ($SMTO_ABORTIFHUNG, $SMTO_NOTIMEOUTIFNOTHUNG ), "int", 100, "dword_ptr*", 0)
	
	_DebugWrite("RemoveFonts : executed")
	
EndFunc   ;==>_RemoveFonts

;===============================================================================
;
; Function Name:	_DebugWrite()
; Description:		Write informations into debug file 
; Syntax:			_DebugWrite(string)
; Requirements:		
;
;===============================================================================
Func _DebugWrite($string)

	; setting up debug status
	If Not ($Debug = 'true' or $Debug = 'false') Then
		If FileExists($ScriptIni) Then
			$Debug = _IniReadPlus($ScriptIni, 'Options', 'Debug', 'false')
			If $Debug = 'true' Then 
				$DebugFile = @ScriptDir & '\' & $ScriptName & '.dbg'
			EndIf
		Else	
			$Debug = 'false'
		EndIf
	EndIf
	
	; write informations
	If $Debug = 'true' Then 
		_FileWriteLog($DebugFile, $string)
	EndIf

EndFunc   ;==>_DebugWrite