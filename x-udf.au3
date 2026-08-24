#include-once
#include 'image_get_size.au3'
#Include <File.au3>
#Include <Misc.au3>
#AutoIt3Wrapper_au3check_parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6

Global $bJGCancel = False

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
	Local $_paths, $_dirs, $path1, $path, $iResult
	Local $bCallError = False
	Local $bResultError = False

	$_paths = StringSplit($string, '|')

	For $i = 1 To $_paths[0]
		$_dirs = StringSplit($_paths[$i], ';')
		$path1 = _FullPath($_dirs[1])
		$path = _FileInfo($path1, 0)

		$iResult = DirCreate($path1)
		If @error Then $bCallError = True
		If $iResult <> 1 Then $bResultError = True

		For $d = 2 To $_dirs[0]
			$iResult = DirCreate($path & '\' & $_dirs[$d])
			If @error Then $bCallError = True
			If $iResult <> 1 Then $bResultError = True
		Next
	Next

	If $bCallError Then Return SetError(3, 0, 0)
	If $bResultError Then Return SetError(4, 0, 0)

	Return SetError(0, 0, 1)
EndFunc   ;==>_DirCreate

;===============================================================================
;
; Function Name:    _LinkCreate(), _TemporaryLinksCleanup()
; Description:      Creates directory junctions or file/directory symbolic links.
; Syntax:           Junctions=ExistingDirectory|LinkPath|*
;                   SymLinks=ExistingFileOrDirectory|LinkPath|*
;                   The optional final * keeps the link after application exit.
;
;===============================================================================
Func _LinkCreate($sValue, $sOperation)
	If StringRight(StringStripWS($sValue, 3), 1) = '|' Then Return SetError(1, 0, 0)
	Local $aParts = StringSplit($sValue, '|')
	If @error Or $aParts[0] < 2 Or $aParts[0] > 3 Then Return SetError(1, 0, 0)
	If $aParts[1] = '' Or $aParts[2] = '' Then Return SetError(1, 0, 0)
	If $aParts[0] = 3 And $aParts[3] <> '*' Then Return SetError(2, 0, 0)
	If $sOperation <> 'Junctions' And $sOperation <> 'SymLinks' Then _
			Return SetError(3, 0, 0)

	Local $bPersistent = ($aParts[0] = 3 And $aParts[3] = '*')
	Local $sSource = _FullPath(StringStripWS($aParts[1], 3))
	Local $sDestination = _FullPath(StringStripWS($aParts[2], 3))
	If $sSource = '' Or $sDestination = '' Then Return SetError(1, 0, 0)
	If _LinkCanonicalPath($sSource) = _LinkCanonicalPath($sDestination) Then _
			Return SetError(4, 0, 0)

	Local $iSourceAttributes = _LinkPathAttributes($sSource)
	If @error Then Return SetError(5, 0, 0)
	Local $bDirectory = BitAND($iSourceAttributes, 0x10) <> 0
	If $sOperation = 'Junctions' And Not $bDirectory Then Return SetError(6, 0, 0)
	If $sOperation = 'Junctions' And StringLeft($sSource, 2) = '\\' Then _
			Return SetError(6, 0, 0)
	Local $iExpectedTag = 0xA000000C
	If $sOperation = 'Junctions' Then $iExpectedTag = 0xA0000003

	Local $iDestinationAttributes = _LinkPathAttributes($sDestination)
	Local $iDestinationError = @error
	If $iDestinationError = 0 Then
		If BitAND($iDestinationAttributes, 0x400) = 0 Then Return SetError(7, 0, 0)
		If _LinkReparseTag($sDestination) <> $iExpectedTag Then Return SetError(8, 0, 0)
		If Not _LinkTargetsMatch($sSource, $sDestination) Then Return SetError(8, 0, 0)
		; A matching pre-existing link is safe and idempotent, but it is not
		; tracked because this launcher instance did not create it.
		Return SetError(0, 3, 1)
	EndIf

	Local $sParent = _LinkParentPath($sDestination)
	If $sParent = '' Then Return SetError(9, 0, 0)
	If Not FileExists($sParent) And DirCreate($sParent) <> 1 Then Return SetError(9, 0, 0)

	Local $bCreated
	If $sOperation = 'Junctions' Then
		$bCreated = _JunctionCreate($sSource, $sDestination)
	Else
		$bCreated = _SymbolicLinkCreate($sSource, $sDestination, $bDirectory)
	EndIf
	Local $iCreateError = @error
	Local $iCreateExtended = @extended
	If Not $bCreated Then Return SetError(10 + $iCreateError, $iCreateExtended, 0)

	; The creation call has just created this previously absent destination from
	; the exact source supplied above. Confirm that Windows exposed a reparse
	; point, but do not reject that new link through a second path-resolution
	; round trip. Some valid links return a different normalized path spelling.
	$iDestinationAttributes = _LinkPathAttributes($sDestination)
	If @error Or BitAND($iDestinationAttributes, 0x400) = 0 Then
		_LinkRemove($sDestination, $bDirectory)
		Return SetError(20, 0, 0)
	EndIf

	If Not $bPersistent Then _TemporaryLinkTrack($sDestination, $bDirectory, $sOperation, $sSource)
	If $bPersistent Then Return SetError(0, 2, 1)
	Return SetError(0, 1, 1)
EndFunc   ;==>_LinkCreate

Func _LinkPathAttributes($sPath)
	Local $aResult = DllCall('kernel32.dll', 'dword', 'GetFileAttributesW', 'wstr', $sPath)
	If @error Or Not IsArray($aResult) Then Return SetError(1, 0, 0)
	; DllCall's unsigned DWORD return represents INVALID_FILE_ATTRIBUTES
	; (0xFFFFFFFF) as decimal 4294967295 on x64 AutoIt.
	If $aResult[0] = 4294967295 Then Return SetError(1, 0, 0)
	Return SetError(0, 0, $aResult[0])
EndFunc   ;==>_LinkPathAttributes

Func _LinkReparseTag($sPath)
	Local $aHandle = DllCall('kernel32.dll', 'handle', 'CreateFileW', _
			'wstr', $sPath, 'dword', 0, 'dword', 7, 'ptr', 0, 'dword', 3, _
			'dword', 0x02200000, 'ptr', 0)
	If @error Or Not IsArray($aHandle) Or $aHandle[0] = Ptr(-1) Then Return SetError(1, 0, 0)
	Local $tInformation = DllStructCreate('dword Attributes;dword ReparseTag')
	Local $aResult = DllCall('kernel32.dll', 'bool', 'GetFileInformationByHandleEx', _
			'handle', $aHandle[0], 'int', 9, 'ptr', DllStructGetPtr($tInformation), 'dword', 8)
	Local $iCallError = @error
	DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $aHandle[0])
	If $iCallError Or Not IsArray($aResult) Or Not $aResult[0] Then Return SetError(1, 0, 0)
	Return SetError(0, 0, DllStructGetData($tInformation, 'ReparseTag'))
EndFunc   ;==>_LinkReparseTag

Func _LinkParentPath($sPath)
	Local $sParent = _FileInfo($sPath, 0)
	If StringRegExp($sParent, '^[A-Za-z]:$') Then $sParent &= '\'
	Return $sParent
EndFunc   ;==>_LinkParentPath

Func _LinkCanonicalPath($sPath)
	If $sPath = '' Then Return ''
	Local $tBuffer = DllStructCreate('wchar[32768]')
	Local $aResult = DllCall('kernel32.dll', 'dword', 'GetFullPathNameW', _
			'wstr', StringReplace($sPath, '/', '\'), 'dword', 32768, _
			'ptr', DllStructGetPtr($tBuffer), 'ptr', 0)
	If @error Or Not IsArray($aResult) Or $aResult[0] = 0 Or $aResult[0] >= 32768 Then Return ''
	$sPath = StringReplace(DllStructGetData($tBuffer, 1), '/', '\')
	If StringLeft($sPath, 8) = '\\?\UNC\' Then
		$sPath = '\\' & StringTrimLeft($sPath, 8)
	ElseIf StringLeft($sPath, 4) = '\\?\' Then
		$sPath = StringTrimLeft($sPath, 4)
	EndIf
	While StringLen($sPath) > 3 And StringRight($sPath, 1) = '\'
		$sPath = StringTrimRight($sPath, 1)
	WEnd
	Return StringLower($sPath)
EndFunc   ;==>_LinkCanonicalPath

Func _LinkResolvedFinalPath($sPath)
	Local $aHandle = DllCall('kernel32.dll', 'handle', 'CreateFileW', _
			'wstr', $sPath, 'dword', 0, 'dword', 7, 'ptr', 0, 'dword', 3, _
			'dword', 0x02000000, 'ptr', 0)
	If @error Or Not IsArray($aHandle) Or $aHandle[0] = Ptr(-1) Then Return ''

	Local $tBuffer = DllStructCreate('wchar[32768]')
	Local $aResult = DllCall('kernel32.dll', 'dword', 'GetFinalPathNameByHandleW', _
			'handle', $aHandle[0], 'ptr', DllStructGetPtr($tBuffer), 'dword', 32768, 'dword', 0)
	Local $iResultError = @error
	DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $aHandle[0])
	If $iResultError Or Not IsArray($aResult) Or $aResult[0] = 0 Or $aResult[0] >= 32768 Then Return ''
	Return _LinkCanonicalPath(DllStructGetData($tBuffer, 1))
EndFunc   ;==>_LinkResolvedFinalPath

Func _LinkTargetsMatch($sSource, $sDestination)
	Local $sSourceFinal = _LinkResolvedFinalPath($sSource)
	Local $sDestinationFinal = _LinkResolvedFinalPath($sDestination)
	If $sSourceFinal = '' Or $sDestinationFinal = '' Then Return False
	Return $sSourceFinal = $sDestinationFinal
EndFunc   ;==>_LinkTargetsMatch

Func _JunctionCreate($sSource, $sDestination)
	; For a directory source AutoIt's native NTFS-link function creates a
	; directory junction. This avoids cmd.exe quoting and requires no temporary
	; script or external utility.
	Local $iResult = FileCreateNTFSLink($sSource, $sDestination, 0)
	Local $iCreateError = @error
	If $iCreateError Or $iResult <> 1 Then Return SetError(2, $iCreateError, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_JunctionCreate

Func _SymbolicLinkCreate($sSource, $sDestination, $bDirectory)
	Local $iFlags = 0
	If $bDirectory Then $iFlags = 1
	Local $aResult, $aLastError, $iNativeError = 0

	; Windows 10 Developer Mode can permit this without elevation. Retry without
	; the opt-in flag for elevated and older Windows configurations.
	DllCall('kernel32.dll', 'none', 'SetLastError', 'dword', 0)
	$aResult = DllCall('kernel32.dll', 'boolean', 'CreateSymbolicLinkW', _
			'wstr', $sDestination, 'wstr', $sSource, 'dword', BitOR($iFlags, 2))
	If Not @error And IsArray($aResult) And $aResult[0] Then Return SetError(0, 0, 1)
	$aLastError = DllCall('kernel32.dll', 'dword', 'GetLastError')
	If IsArray($aLastError) Then $iNativeError = $aLastError[0]

	DllCall('kernel32.dll', 'none', 'SetLastError', 'dword', 0)
	$aResult = DllCall('kernel32.dll', 'boolean', 'CreateSymbolicLinkW', _
			'wstr', $sDestination, 'wstr', $sSource, 'dword', $iFlags)
	If Not @error And IsArray($aResult) And $aResult[0] Then Return SetError(0, 0, 1)
	$aLastError = DllCall('kernel32.dll', 'dword', 'GetLastError')
	If IsArray($aLastError) Then $iNativeError = $aLastError[0]
	Return SetError(1, $iNativeError, 0)
EndFunc   ;==>_SymbolicLinkCreate

Func _TemporaryLinkTrack($sDestination, $bDirectory, $sOperation, $sSource)
	$TemporaryLinkCount += 1
	ReDim $TemporaryLinks[$TemporaryLinkCount + 1][4]
	$TemporaryLinks[$TemporaryLinkCount][0] = $sDestination
	$TemporaryLinks[$TemporaryLinkCount][1] = $bDirectory
	$TemporaryLinks[$TemporaryLinkCount][2] = $sOperation
	$TemporaryLinks[$TemporaryLinkCount][3] = $sSource
EndFunc   ;==>_TemporaryLinkTrack

Func _LinkRemove($sDestination, $bDirectory, $sExpectedSource = '', $iExpectedTag = 0)
	Local $iAttributes = _LinkPathAttributes($sDestination)
	If @error Then Return SetError(0, 4, 1)
	If BitAND($iAttributes, 0x400) = 0 Then Return SetError(1, 0, 0)
	If $iExpectedTag <> 0 And _LinkReparseTag($sDestination) <> $iExpectedTag Then _
			Return SetError(3, 0, 0)
	If $sExpectedSource <> '' And Not _LinkTargetsMatch($sExpectedSource, $sDestination) Then _
			Return SetError(4, 0, 0)

	DllCall('kernel32.dll', 'none', 'SetLastError', 'dword', 0)
	Local $aResult
	If $bDirectory Then
		$aResult = DllCall('kernel32.dll', 'bool', 'RemoveDirectoryW', 'wstr', $sDestination)
	Else
		$aResult = DllCall('kernel32.dll', 'bool', 'DeleteFileW', 'wstr', $sDestination)
	EndIf
	If Not @error And IsArray($aResult) And $aResult[0] Then Return SetError(0, 1, 1)
	Local $aLastError = DllCall('kernel32.dll', 'dword', 'GetLastError')
	Local $iNativeError = 0
	If IsArray($aLastError) Then $iNativeError = $aLastError[0]
	Return SetError(2, $iNativeError, 0)
EndFunc   ;==>_LinkRemove

Func _TemporaryLinksCleanup()
	Local $bAllSucceeded = True
	Local $vResult, $iError, $iExtended, $sCleanupOperation
	For $i = $TemporaryLinkCount To 1 Step -1
		; Only links created and tracked by this launcher instance reach this
		; cleanup. _LinkRemove still requires the path to remain a reparse point
		; and uses DeleteFileW/RemoveDirectoryW, which remove only the link.
		$vResult = _LinkRemove($TemporaryLinks[$i][0], $TemporaryLinks[$i][1])
		$iError = @error
		$iExtended = @extended
		If $TemporaryLinks[$i][2] = 'Junctions' Then
			$sCleanupOperation = 'RemoveJunction'
		Else
			$sCleanupOperation = 'RemoveSymLink'
		EndIf
		_DebugOperationResult('RunAfter', $sCleanupOperation, $TemporaryLinks[$i][0], _
				$vResult, $iError, $iExtended)
		If Not $vResult Then $bAllSucceeded = False
	Next
	$TemporaryLinkCount = 0
	ReDim $TemporaryLinks[1][4]
	If Not $bAllSucceeded Then Return SetError(1, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_TemporaryLinksCleanup

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
	Local $bEmptyOnly = $aPath[0] > 1 And StringInStr($aPath[2], 'e', 1) > 0
	Local $bContentsOnly = _DirRemoveContentsOnlyRequested($aPath[1])
	Local $sPath = _FullPath($aPath[1])
	If @error Or $sPath = '' Then Return SetError(2, 0, 0)
	; Directory cleanup is idempotent: if the target is already absent, the
	; requested end state has been achieved. Extended value 4 distinguishes this
	; successful no-op from a directory that was removed during this call.
	If Not FileExists($sPath) Then Return SetError(0, 4, 1)
	Local $sSafetyReason = _TempCleanupSafetyReason($sPath)
	If $sSafetyReason <> '' Then
		; Lib is a protected persistent-data root. Empty-only cleanup or an
		; explicit trailing separator may clean below it, but must preserve Lib.
		If $sSafetyReason = 'protected path' And _
				_DirRemoveProtectedBaseCanBePreserved($sPath, $bEmptyOnly, $bContentsOnly) Then
			Local $iProtectedContentsResult = _DirRemoveContents($sPath, $bEmptyOnly)
			Return SetError(@error, @extended, $iProtectedContentsResult)
		EndIf
		Return SetError(5, 0, 0)
	EndIf
	If $bContentsOnly Then
		Local $iContentsResult = _DirRemoveContents($sPath, $bEmptyOnly)
		Return SetError(@error, @extended, $iContentsResult)
	EndIf
	Local $iReturn = 0
	; Historical contract: no flag recursively removes the populated directory.
	; The optional e flag changes the operation to empty-directory-only cleanup.
	If $bEmptyOnly Then
		$iReturn = _DirRemoveEmpty($sPath)
	Else
		$iReturn = DirRemove($sPath, 1)
	EndIf
	Return SetError(@error, 0, $iReturn)
EndFunc   ;==>_DirRemove

Func _DirRemoveContentsOnlyRequested($sConfiguredPath)
	$sConfiguredPath = StringStripWS($sConfiguredPath, 3)
	If $sConfiguredPath = '' Then Return False
	Local $sLastCharacter = StringRight($sConfiguredPath, 1)
	Return $sLastCharacter = '\' Or $sLastCharacter = '/'
EndFunc   ;==>_DirRemoveContentsOnlyRequested

Func _DirRemoveProtectedBaseCanBePreserved($sPath, $bEmptyOnly, $bContentsOnly)
	If Not $bEmptyOnly And Not $bContentsOnly Then Return False
	Local $sDeletePath = _CleanupCanonicalPath($sPath)
	Local $sLibPath = _CleanupCanonicalPath($Lib)
	Return $sDeletePath <> '' And $sDeletePath = $sLibPath
EndFunc   ;==>_DirRemoveProtectedBaseCanBePreserved

Func _DirRemoveContents($sDirPath, $bEmptyOnly = False)
	$sDirPath = StringRegExpReplace($sDirPath, '[\\/ ]+$', '')
	If $sDirPath = '' Then Return SetError(1, 0, 0)
	If Not FileExists($sDirPath) Then Return SetError(0, 4, 1)
	If StringInStr(FileGetAttrib($sDirPath), 'D', 2) = 0 Then Return SetError(3, 0, 0)

	Local $hSearch = FileFindFirstFile($sDirPath & '\*')
	If $hSearch = -1 Then Return SetError(0, 0, 1)

	Local $iErrors = 0, $iChanged = 0
	Local $sName, $sChild, $iResult, $iChildError
	While 1
		$sName = FileFindNextFile($hSearch)
		If @error Then ExitLoop
		$sChild = $sDirPath & '\' & $sName
		If StringInStr(FileGetAttrib($sChild), 'D', 2) Then
			If $bEmptyOnly Then
				$iResult = _DirRemoveEmpty($sChild)
				$iChildError = @error
				If $iChildError <> 0 Then
					$iErrors += 1
				ElseIf $iResult <> 0 Then
					$iChanged += 1
				EndIf
			ElseIf DirRemove($sChild, 1) = 1 Then
				$iChanged += 1
			Else
				$iErrors += 1
			EndIf
		ElseIf Not $bEmptyOnly Then
			If FileDelete($sChild) = 1 Then
				$iChanged += 1
			Else
				$iErrors += 1
			EndIf
		EndIf
	WEnd
	FileClose($hSearch)

	If $iErrors > 0 Then Return SetError(6, $iChanged, 0)
	Return SetError(0, $iChanged, 1)
EndFunc   ;==>_DirRemoveContents

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
	Local $_split, $source, $destination, $iError, $iExtended, $iResult

	$_split = StringSplit($string, '|')
	$source = _FullPath($_split[1])
	$destination = _FullPath($_split[2])

	If $_split[0] = 2 Then
		$iResult = DirMove($source, $destination, 0)
		If @error Then Return SetError(3, 0, 0)
		If $iResult <> 1 Then Return SetError(4, 0, 0)
		Return SetError(0, 0, 1)
	EndIf

	Switch $_split[3]
		Case 'o'
			$iResult = _DirMoveEx($source, $destination, 1)
		Case Else
			$iResult = _DirMoveEx($source, $destination, 0)
	EndSwitch

	$iError = @error
	$iExtended = @extended

	; _DirMoveEx removes only directories that are proven empty.
	; Never recursively delete the source after a partial/failed move.
	If $iError Then Return SetError($iError, $iExtended, 0)

	Return SetError(0, $iExtended, $iResult)
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
	Local $fInside = False
	Local $iResult, $iMoveError = 0
	Local $hSource, $sEntry, $sNextSource, $sNextDest
	Local $iChildResult, $iChildError

	If $sSource = '' Or $sDest = '' Then Return SetError(1, 0, 0)
	If Not FileExists($sSource) Then Return SetError(2, 0, 0)
	If StringInStr(FileGetAttrib($sSource), 'D', 2) = 0 Then Return SetError(3, 0, 0)

	$sDest = StringRegExpReplace($sDest, '[\\/]+$', '')
	If Not @error And @extended = 1 Then $fInside = True

	$sSource = StringRegExpReplace($sSource, '[\\/]+$', '')
	If Not @error And @extended = 1 Then $fInside = False

	If $fInside Then
		Local $sDestDir = StringRegExpReplace($sSource, '.*?[\\/]([^\\/]+)[\\/]*$', '\1')
		If @error Or @extended <> 1 Then Return SetError(4, 0, 0)
		$sDest &= '\' & $sDestDir
	EndIf

	; If there is no existing destination, let Windows perform the complete
	; directory move directly.
	If Not FileExists($sDest) Then
		$iResult = DirMove($sSource, $sDest, $iFlag)
		If $iResult = 1 Then Return SetError(0, 0, 1)

		_DebugWrite(">>>>>> Directory move failed - source preserved: " & $sSource)
		Return SetError(5, 0, 0)
	EndIf

	If DirCreate($sDest) = 0 Then
		_DebugWrite(">>>>>> Directory move failed - cannot create destination: " & $sDest)
		Return SetError(5, 0, 0)
	EndIf

	; Move each entry separately so every failure is known. In no-overwrite
	; mode a conflicting file remains safely at its original source path.
	$hSource = FileFindFirstFile($sSource & '\*')

	If $hSource = -1 Then
		If DirRemove($sSource, 0) = 1 Then Return SetError(0, 0, 1)

		_DebugWrite(">>>>>> Directory move failed - source directory preserved: " & $sSource)
		Return SetError(6, 0, 0)
	EndIf

	While 1
		$sEntry = FileFindNextFile($hSource)
		If @error Then ExitLoop

		$sNextSource = $sSource & '\' & $sEntry
		$sNextDest = $sDest & '\' & $sEntry

		If StringInStr(FileGetAttrib($sNextSource), 'D', 2) Then
			$iChildResult = _DirMoveEx($sNextSource, $sNextDest, $iFlag)
			$iChildError = @error

			If $iChildError Or $iChildResult = 0 Then
				$iMoveError += 1
				_DebugWrite(">>>>>> Directory move incomplete - source preserved: " & $sNextSource)
			EndIf
		Else
			$iResult = FileMove($sNextSource, $sNextDest, $iFlag)

			If @error Or $iResult <> 1 Then
				$iMoveError += 1
				_DebugWrite(">>>>>> File move failed - source preserved: " & $sNextSource)
			EndIf
		EndIf
	WEnd

	FileClose($hSource)

	If $iMoveError > 0 Then
		_DebugWrite(">>>>>> Directory move incomplete - remaining source preserved: " & $sSource)
		Return SetError(7, $iMoveError, 0)
	EndIf

	; Non-recursive removal is safe: it succeeds only when every source entry
	; has actually been moved.
	If DirRemove($sSource, 0) <> 1 Then
		_DebugWrite(">>>>>> Directory move incomplete - source directory not empty: " & $sSource)
		Return SetError(8, 0, 0)
	EndIf

	Return SetError(0, 0, 1)
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
	Local $_paths, $destination, $_source, $source, $source_dir, $flag, $iResult
	Local $bCallError = False
	Local $bResultError = False

	$_paths = StringSplit($string, '|')
	If @error Then Return SetError(3, 0, 0)

	$destination = _FullPath($_paths[2])
	$_source = StringSplit($_paths[1], ';')
	$source = _FullPath($_source[1])

	If $_paths[0] = 3 And $_paths[3] = 'o' Then
		$flag = 9
	Else
		$flag = 8
	EndIf

	If $_source[0] <> 1 Then
		$source_dir = _FileInfo($source, 0)

		For $f = 1 To $_source[0]
			$iResult = FileCopy($source_dir & '\' & $_source[$f], $destination, $flag)
			If @error Then $bCallError = True
			If $iResult <> 1 Then $bResultError = True
		Next
	Else
		$iResult = FileCopy($source, $destination, $flag)
		If @error Then $bCallError = True
		If $iResult <> 1 Then $bResultError = True
	EndIf

	If $bCallError Then Return SetError(3, 0, 0)
	If $bResultError Then Return SetError(4, 0, 0)

	Return SetError(0, 0, 1)
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
	Local $_paths, $files, $path, $iResult
	Local $bCallError = False
	Local $bResultError = False

	$_paths = StringSplit($string, '|')

	For $i = 1 To $_paths[0]
		$files = StringSplit($_paths[$i], ';')
		$path = _FileInfo($files[1], 0)

		$iResult = FileDelete(_FullPath($files[1]))
		If @error Then $bCallError = True
		If $iResult <> 1 Then $bResultError = True

		For $f = 2 To $files[0]
			$iResult = FileDelete(_FullPath($path & '\' & $files[$f]))
			If @error Then $bCallError = True
			If $iResult <> 1 Then $bResultError = True
		Next
	Next

	If $bCallError Then Return SetError(3, 0, 0)
	If $bResultError Then Return SetError(4, 0, 0)

	Return SetError(0, 0, 1)
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
	Local $_split, $source, $destination, $iError, $aMatches
	$_split = StringSplit($string, '|')
	$source = _FullPath($_split[1])
	$destination = _FullPath($_split[2])
	; A wildcard source can legitimately match no files, such as an updater that
	; was not downloaded during this run. Extended value 4 identifies this
	; successful no-op without weakening exact-source failure handling.
	If StringRegExp($source, '\*|\?') = 1 Then
		$aMatches = _ExpandMultiPath($source, True)
		If $aMatches[0] = 0 Then Return SetError(0, 4, 0)
	EndIf
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
	If Not StringRegExp($sBase, '(?i)^[a-z]:(?:[\\/]|$)') Then Return SetError(1, 0, 0)
	Local $_string, $file, $casesense, $driveletter, $skip, $_letters[26], $do, $_replace[27], $read, $_read, $lines, $replaces, $write, $_write
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
	If Not FileExists($file) Then Return SetError(0, 0, 0)

	$read = FileOpen($file, 0)
	If $read = -1 Then Return SetError(2, 0, 0)
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
			Local $pattern = '(?<![A-Za-z0-9_:/\\])' & $_replace[$d] & ':([\\/])'
			If $casesense = 0 Then $pattern = '(?i)' & $pattern
			If StringRegExp($_read[$l], $pattern) Then
				$_read[$l] = StringRegExpReplace($_read[$l], $pattern, $driveletter & ':$1')
				$replaces = 1
			EndIf
		Next
		$_write[$l] = $_read[$l]
	Next
	If $replaces = 1 Then
		$write = FileOpen($file, 2)
		If $write = -1 Then Return SetError(3, 0, 0)

		Local $bWriteOK = True
		For $l = 1 To $lines
			If FileWriteLine($write, $_write[$l]) = 0 Then $bWriteOK = False
		Next
		FileClose($write)

		If Not $bWriteOK Then Return SetError(4, 0, 0)
		Return SetError(0, 0, 1)
	EndIf

	Return SetError(0, 0, 0)
EndFunc   ;==>_FixDriveLetter

;===============================================================================
;
; Function Name:	_FixUserProfile()
; Description:		Once %USERPROFILE% is defined, renames a directory if its name
;					change when switching OS Lang.
;
;===============================================================================
Func _UserProfileChildNameIsSafe($sName)
	If $sName = '' Or $sName = '.' Or $sName = '..' Then Return False
	If StringStripWS($sName, 3) <> $sName Then Return False
	If StringRight($sName, 1) = '.' Then Return False
	If StringRegExp($sName, '[\x00-\x1F\\/:*?"<>|]') Then Return False
	Return True
EndFunc   ;==>_UserProfileChildNameIsSafe

Func _FixUserProfile($userprofile, $dir, $name)
	Local $cfgfile, $old, $source
	If Not _UserProfileChildNameIsSafe($dir) Then Return SetError(1, 0, 0)

	$cfgfile = $userprofile & '\x-launcher.cfg'
	If FileExists($cfgfile) Then
		$old = IniRead($cfgfile, 'UserProfile', $name, '')
		If $dir <> $old Then
			If _UserProfileChildNameIsSafe($old) Then
				$source = $userprofile & '\' & $old
				If FileExists($source) And DirMove($source, $userprofile & '\' & $dir) <> 1 Then _
						Return SetError(2, 0, 0)
			EndIf
			If IniWrite($cfgfile, 'UserProfile', $name, $dir) <> 1 Then _
					Return SetError(3, 0, 0)
		EndIf
	Else
		If DirCreate($userprofile) <> 1 Then Return SetError(4, 0, 0)
		If IniWrite($cfgfile, 'UserProfile', $name, $dir) <> 1 Then _
				Return SetError(3, 0, 0)
	EndIf
	Return SetError(0, 0, 1)
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
			If $diff <= 0 Then Return SetError(10, 0, '')
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
; Function Name:	_ResolveProcMonPath()
; Description:		Resolves an optional Process Monitor executable or directory.
; Return Value:		True when a supported executable is found. @error identifies
;					why an optional configured/default location was not usable.
;
;===============================================================================
Func _ResolveProcMonPath($sConfigured, ByRef $sResolved, ByRef $sResolution, _
		$sRootPath = $Root, $sLibPath = '')
	Local $sValue = StringStripWS($sConfigured, 3)
	Local $bDefault = False
	Local $sAttributes
	Local $aNames[3]
	Local $sCandidate
	Local $i

	$sResolved = ''
	$sResolution = ''

	If StringLen($sValue) >= 2 And StringLeft($sValue, 1) = '"' And _
			StringRight($sValue, 1) = '"' Then
		$sValue = StringMid($sValue, 2, StringLen($sValue) - 2)
		$sValue = StringStripWS($sValue, 3)
	EndIf

	If $sValue = '' Then
		$bDefault = True
		If $sLibPath = '' Then $sLibPath = $sRootPath & '\Lib'
		$sValue = $sLibPath & '\Tools\ProcessMonitor\Procmon64.exe'
	EndIf

	$sValue = _NormalPath($sValue)
	If $sValue = '' Then Return SetError(1, 0, False)

	If StringLeft($sValue, 2) = '\\' Or StringRegExp($sValue, '^[A-Za-z]:\\') Then
		$sResolved = $sValue
	ElseIf StringLeft($sValue, 1) = '\' Or StringLeft($sValue, 1) = '.' Then
		$sResolved = _FullPath($sValue, $sRootPath)
	Else
		$sResolved = _FullPath('.\' & $sValue, $sRootPath)
	EndIf
	If @error Or $sResolved = '' Then Return SetError(1, 0, False)
	$sResolved = _NormalPath($sResolved)

	If Not FileExists($sResolved) Then
		If $bDefault Then
			$sResolution = 'default-missing'
			Return SetError(2, 0, False)
		EndIf
		$sResolution = 'configured-missing'
		Return SetError(3, 0, False)
	EndIf

	$sAttributes = FileGetAttrib($sResolved)
	If StringInStr($sAttributes, 'D') Then
		Switch @OSArch
			Case 'ARM64'
				$aNames[0] = 'Procmon64a.exe'
				$aNames[1] = 'Procmon64.exe'
				$aNames[2] = 'Procmon.exe'
			Case 'X86'
				$aNames[0] = 'Procmon.exe'
				$aNames[1] = 'Procmon64.exe'
				$aNames[2] = 'Procmon64a.exe'
			Case Else
				$aNames[0] = 'Procmon64.exe'
				$aNames[1] = 'Procmon.exe'
				$aNames[2] = 'Procmon64a.exe'
		EndSwitch

		For $i = 0 To UBound($aNames) - 1
			$sCandidate = $sResolved & '\' & $aNames[$i]
			If FileExists($sCandidate) And Not StringInStr(FileGetAttrib($sCandidate), 'D') Then
				$sResolved = $sCandidate
				$sResolution = 'configured-folder'
				Return SetError(0, 0, True)
			EndIf
		Next

		$sResolution = 'configured-folder-empty'
		Return SetError(5, 0, False)
	EndIf

	Switch StringLower(_FileInfo($sResolved, 1))
		Case 'procmon.exe', 'procmon64.exe', 'procmon64a.exe'
			If $bDefault Then
				$sResolution = 'default-file'
			Else
				$sResolution = 'configured-file'
			EndIf
			Return SetError(0, 0, True)
	EndSwitch

	$sResolution = 'configured-file-name'
	Return SetError(4, 0, False)
EndFunc   ;==>_ResolveProcMonPath

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
; Function Name:	_ResolveMultipleInstancesOption()
; Description:		Reads and validates the correctly spelled MultipleInstances option.
;
;===============================================================================
Func _ResolveMultipleInstancesOption($filename, $default = 'true')
	Local $sValue = IniRead($filename, 'Options', 'MultipleInstances', $default)
	If $sValue = '' Then Return $default
	If ($sValue == 'true') Or ($sValue == 'false') Then Return $sValue
	Return $default
EndFunc   ;==>_ResolveMultipleInstancesOption

;===============================================================================
;
; Function Name:	_JavaCheck()
; Description:		Uses a valid configured JavaPath read-only. Otherwise searches
;					the more updated Java installation path between installed (Win)
;					and \Lib\Java (Pack), retaining JavaURL/setup fallback behavior.
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
Func _DebugJavaResult($sStatus, $sOperation, $sTarget, $vResult, $iError, $iExtended, $sDetail = '')
	If $Debug <> 'true' Then Return

	If $sTarget = '' Then $sTarget = '<none>'
	Local $sRecord = '[' & $sStatus & '] [Java] ' & $sOperation & '=' & $sTarget & _
			' (result=' & $vResult & '; error=' & $iError & '; extended=' & $iExtended
	If $sDetail <> '' Then $sRecord &= '; ' & $sDetail
	$sRecord &= ')'
	_DebugWrite($sRecord)
EndFunc   ;==>_DebugJavaResult

Func _DebugJavaSelectionResult($sMode, $sPath, $sPortablePath, $iError, $iExtended)
	If $Debug <> 'true' Then Return

	Local $sStatus = 'FAIL'
	Local $sSource = 'none'
	Local $bRuntimeValid = False
	Local $sComparePath = StringLower(StringRegExpReplace($sPath, '[\\/]+$', ''))
	Local $sComparePortable = StringLower(StringRegExpReplace($sPortablePath, '[\\/]+$', ''))
	If $sPath <> '' Then $bRuntimeValid = _JavaRuntimeValid($sPath)

	If $bRuntimeValid Then
		If $iExtended = 10 Then
			$sSource = 'configured'
		ElseIf $sComparePath = $sComparePortable Then
			$sSource = 'portable'
		Else
			$sSource = 'system'
		EndIf

		If $iError = 0 Then
			$sStatus = 'PASS'
		ElseIf $iError = 1 Then
			$sStatus = 'SKIP'
		EndIf
	ElseIf $iError = 0 And $sMode = 'false' Then
		$sStatus = 'SKIP'
	ElseIf $iError = 1 And $sMode = 'optional' Then
		$sStatus = 'SKIP'
	EndIf

	_DebugJavaResult($sStatus, 'Selection', $sPath, $sPath, $iError, $iExtended, _
			'mode=' & $sMode & '; source=' & $sSource)
EndFunc   ;==>_DebugJavaSelectionResult

Func _JavaURLValid($sURL)
	$sURL = StringStripWS($sURL, 3)
	If $sURL = "" Then Return False
	Return StringRegExp($sURL, "(?i)^https?://[^\s]+$") = 1
EndFunc   ;==>_JavaURLValid

Func _JavaFindSystemJava()
	Local $sCandidate = _JavaCandidateRoot(EnvGet("JAVA_HOME"))
	If @error = 0 Then Return SetError(0, 0, $sCandidate)

	Local $aPath = StringSplit(EnvGet("PATH"), ";", 2)
	If IsArray($aPath) Then
		For $i = 0 To UBound($aPath) - 1
			$sCandidate = _JavaCandidateRoot($aPath[$i])
			If @error = 0 Then Return SetError(0, 0, $sCandidate)
		Next
	EndIf

	; HKLM32 fallback uses WOW6432Node in this x64 launcher.
	Local $sReg32Root = "HKLM\SOFTWARE\WOW6432Node\JavaSoft"
	If Not @AutoItX64 Then $sReg32Root = "HKLM\SOFTWARE\JavaSoft"
	Local $aRegKeys[8]
	$aRegKeys[0] = "HKLM64\SOFTWARE\JavaSoft\Java Runtime Environment"
	$aRegKeys[1] = $sReg32Root & "\Java Runtime Environment"
	$aRegKeys[2] = "HKLM64\SOFTWARE\JavaSoft\Java Development Kit"
	$aRegKeys[3] = $sReg32Root & "\Java Development Kit"
	$aRegKeys[4] = "HKLM64\SOFTWARE\JavaSoft\JRE"
	$aRegKeys[5] = $sReg32Root & "\JRE"
	$aRegKeys[6] = "HKLM64\SOFTWARE\JavaSoft\JDK"
	$aRegKeys[7] = $sReg32Root & "\JDK"
	For $i = 0 To UBound($aRegKeys) - 1
		$sCandidate = _JavaRegistryPath($aRegKeys[$i])
		If @error = 0 Then Return SetError(0, 0, $sCandidate)
	Next
	Return SetError(1, 0, "")
EndFunc   ;==>_JavaFindSystemJava

Func _JavaCandidateRoot($sPath)
	$sPath = StringStripWS($sPath, 3)
	If StringLen($sPath) >= 2 And StringLeft($sPath, 1) = Chr(34) And StringRight($sPath, 1) = Chr(34) Then
		$sPath = StringTrimLeft(StringTrimRight($sPath, 1), 1)
	EndIf
	$sPath = StringRegExpReplace($sPath, "[\\/]+$", "")
	If $sPath = "" Then Return SetError(1, 0, "")
	If _JavaRuntimeValid($sPath) Then Return SetError(0, 0, $sPath)
	If StringRegExp($sPath, "(?i)[\\/]bin$") Then
		Local $sRoot = StringRegExpReplace($sPath, "(?i)[\\/]bin$", "")
		If _JavaRuntimeValid($sRoot) Then Return SetError(0, 0, $sRoot)
	EndIf
	Return SetError(1, 0, "")
EndFunc   ;==>_JavaCandidateRoot

Func _JavaPathResolve($sPath, $sRootPath)
	$sPath = StringStripWS($sPath, 3)
	If StringLen($sPath) >= 2 And StringLeft($sPath, 1) = Chr(34) And _
			StringRight($sPath, 1) = Chr(34) Then
		$sPath = StringTrimLeft(StringTrimRight($sPath, 1), 1)
	EndIf
	If $sPath = '' Then Return SetError(1, 0, '')

	$sPath = _NormalPath($sPath)
	Local $sResolved
	If StringLeft($sPath, 2) = '\\' Or StringRegExp($sPath, '^[A-Za-z]:\\') Then
		$sResolved = $sPath
	ElseIf StringLeft($sPath, 1) = '\' Or StringLeft($sPath, 1) = '.' Then
		$sResolved = _FullPath($sPath, $sRootPath)
	Else
		$sResolved = _FullPath('.\' & $sPath, $sRootPath)
	EndIf
	Local $iResolveError = @error
	If $iResolveError Or $sResolved = '' Then Return SetError(2, $iResolveError, '')
	$sResolved = StringRegExpReplace($sResolved, '[\\/]+$', '')

	If StringRegExp($sResolved, '(?i)[\\/]bin[\\/]javaw?\.exe$') Then
		$sResolved = StringRegExpReplace($sResolved, _
				'(?i)[\\/]bin[\\/]javaw?\.exe$', '')
	EndIf

	Local $sRuntime = _JavaCandidateRoot($sResolved)
	If @error Then Return SetError(3, 0, '')
	Return SetError(0, 0, $sRuntime)
EndFunc   ;==>_JavaPathResolve

Func _JavaRegistryPath($sKey)
	Local $sCandidate = _JavaCandidateRoot(RegRead($sKey, "JavaHome"))
	If @error = 0 Then Return SetError(0, 0, $sCandidate)

	Local $sVersion = RegRead($sKey, "CurrentVersion")
	If $sVersion <> "" Then
		$sCandidate = _JavaCandidateRoot(RegRead($sKey & "\" & $sVersion, "JavaHome"))
		If @error = 0 Then Return SetError(0, 0, $sCandidate)
	EndIf

	For $i = 1 To 100
		Local $sSubKey = RegEnumKey($sKey, $i)
		If @error Then ExitLoop
		$sCandidate = _JavaCandidateRoot(RegRead($sKey & "\" & $sSubKey, "JavaHome"))
		If @error = 0 Then Return SetError(0, 0, $sCandidate)
	Next
	Return SetError(1, 0, "")
EndFunc   ;==>_JavaRegistryPath

Func _JavaLegacyPackage($sPath)
	Local $hFile = FileOpen($sPath, 16)
	If $hFile = -1 Then Return False
	Local $bHeader = FileRead($hFile, 2)
	FileClose($hFile)
	Return BinaryToString($bHeader) = "MZ"
EndFunc   ;==>_JavaLegacyPackage

Func _JavaCheck($AppName, $ScriptIni, $LibPath, $RootPath)
	Local $JavaNeeded
	Local $sJavaPath
	Local $sJavaURL
	Local $iLang = _Language()
	Local $s_JavaWinPath, $s_JavaWinVer
	Local $s_JavaPackPath, $s_JavaPackVer
	Local $iJavaGetResult = 0

	_DebugWrite("Javacheck : executing")
	$s_JavaWinPath = ""
	$s_JavaWinVer = "0"
	$s_JavaPackPath = ""
	$s_JavaPackVer = "0"

	$JavaNeeded = IniRead($ScriptIni, 'Options', 'Java', 'false')
	$sJavaPath = IniRead($ScriptIni, 'Options', 'JavaPath', '')
	$sJavaURL = IniRead($ScriptIni, 'Options', 'JavaURL', '')
	$s_JavaPackPath = "$Lib$\Java"

	; A configured runtime is used in place and never passed to JavaGet.
	; Java=false deliberately retains but ignores JavaPath for compatibility.
	If ($JavaNeeded = 'true' Or $JavaNeeded = 'optional') And _
			StringStripWS($sJavaPath, 3) <> '' Then
		Local $sConfiguredRuntime = _JavaPathResolve($sJavaPath, $RootPath)
		Local $iConfiguredError = @error
		If $iConfiguredError = 0 Then
			_DebugJavaResult('PASS', 'JavaPath', $sConfiguredRuntime, _
					$sConfiguredRuntime, 0, 10, 'source=configured; access=read-only')
			Return SetError(0, 10, $sConfiguredRuntime)
		EndIf
		_DebugJavaResult('WARN', 'JavaPath', $sJavaPath, '', $iConfiguredError, 0, _
				'reason=missing or incomplete runtime; continuing fallback search')
	EndIf

	; Portable Java remains application-specific and always takes priority.
	; System Java is a fallback discovered from JAVA_HOME, PATH, then JavaSoft.
	$s_JavaWinPath = _JavaFindSystemJava()
	If @error Then $s_JavaWinPath = ""

	;Java not required and Java installed not found, return generic local path, 
	;else returns the more updated version between "WIN" and "PACK"
	;This allows that also programs like Firefox (requiring Java for some operations) 
	;to use installed Java, if not present into the pack
	If $JavaNeeded = 'false' and $s_JavaWinPath = "" Then
		Return $s_JavaPackPath
	EndIf
	
	;Java required, activate JavaGet
	If $JavaNeeded = 'true' or $JavaNeeded = 'optional' Then
		$iJavaGetResult = _JavaGet($AppName, $ScriptIni, $LibPath, $RootPath, $iLang, $s_JavaWinPath, $sJavaURL)
	EndIf

	;Java optional and installation refused, disable next Java installations and return generic local path
	If $JavaNeeded = 'optional' and $s_JavaWinPath = "" and not FileExists($s_JavaPackPath & "\bin\javaw.exe") Then
		IniWrite($ScriptIni, 'Options', 'Java', 'false')
		Return SetError($iJavaGetResult, 0, $s_JavaPackPath)
	EndIf

	If FileExists($s_JavaPackPath & "\bin\javaw.exe") Then
		Return SetError($iJavaGetResult, 0, $s_JavaPackPath)
	EndIf
	
	;Both Java installed and Java local found
	If FileExists($s_JavaWinPath & "\bin\javaw.exe") Then
		$s_JavaWinVer = FileGetVersion($s_JavaWinPath & "\bin\javaw.exe")
	EndIf
	If FileExists($s_JavaPackPath & "\bin\javaw.exe") Then
		$s_JavaPackVer = FileGetVersion($s_JavaPackPath & "\bin\javaw.exe")
	EndIf

	;Return more updated version. If both exists with same version, use installed one (theorically quicker)
	If _VersionCompare($s_JavaWinVer, $s_JavaPackVer) >= 0 Then
		Return SetError($iJavaGetResult, 0, $s_JavaWinPath)
	Else
		Return SetError($iJavaGetResult, 0, $s_JavaPackPath)
	EndIf

EndFunc   ;==>_JavaCheck

;===============================================================================
;
; Function Name:	_JavaGet()
; Description:		Gets Java from repository and install it under $Lib$\Java
;
;===============================================================================
Func _JavaGet($AppName, $ScriptIni, $LibPath, $RootPath, $iLang, $s_JavaWinPath, $sJavaURL)
	$bJGCancel = False
	$iMsgBoxAnswer = 0
	$iJGAction = -1
	$sJGTarget = $LibPath & "\Java"
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
	Local $sSetup = "setup\*.zip|setup\*.exe"
	Local $sSetupDown = "setup\java-download.package"
	If FileExists($sSetupDown) Then $sSetup = $sSetupDown & "|" & $sSetup
	Local $sStage = $LibPath & "\Java\.java-stage"

	_DebugWrite("Javaget : executing")

	If Not FileExists($LibPath & "\Java") Then _DirCreate($LibPath & "\Java")

	FileChangeDir($LibPath & "\Java")
	If FileExists($sJBak) Then
		If _JavaResume($sJBak) <> 1 Then Return _CloseJG(4)
	EndIf
;Msgbox(0,"Current path",$LibPath & "\Java")
	; Test processo multiplo
	;If _ProcessExistsOther() Then Exit 1

	; Selezione operazioni
	$iJGAction = _JavaSearch($sJava, $sJavaw, $sSetup, $s_JavaWinPath)
	Switch $iJGAction
		Case 0 ; Niente
			;Msgbox(0,"Case 0","Case 0")
			Return _CloseJG(0)

		Case 1 ; Download
			;Msgbox(0,"Case 1","Case 1")
			$sJGTarget = $sJavaURL
			If $sJavaURL = "" Then Return _CloseJG(5)
			If Not _JavaURLValid($sJavaURL) Then Return _CloseJG(6)
			$iMsgBoxAnswer = MsgBox(49, $AppName, $aMessage[2][$iLang])
			If $bJGCancel Then Return _CloseJG(1)
			If $iMsgBoxAnswer = 2 Then Return _CloseJG(1)
			Local $vJavaDownloadResult = _Download($sJavaURL, $sSetupDown, $iLang)
			Local $iJavaDownloadError = @error
			Local $iJavaDownloadExtended = @extended
			If $bJGCancel Or $iJavaDownloadError = 7 Then
				_DebugJavaResult('SKIP', 'Download', $sJavaURL, $vJavaDownloadResult, _
						$iJavaDownloadError, $iJavaDownloadExtended, _
						'reason=user cancelled; destination=' & $sSetupDown)
			ElseIf $iJavaDownloadError = 0 And FileExists($sSetupDown) Then
				_DebugJavaResult('PASS', 'Download', $sJavaURL, $vJavaDownloadResult, _
						$iJavaDownloadError, $iJavaDownloadExtended, 'destination=' & $sSetupDown)
			Else
				_DebugJavaResult('FAIL', 'Download', $sJavaURL, $vJavaDownloadResult, _
						$iJavaDownloadError, $iJavaDownloadExtended, 'destination=' & $sSetupDown)
			EndIf
			If $bJGCancel Then Return _CloseJG(1)
			If $iJavaDownloadError Or Not FileExists($sSetupDown) Then
				MsgBox(262160, $AppName & ": Error", $aMessage[5][$iLang])
				Return _CloseJG(1)
			EndIf
			$sSetup = $sSetupDown

		Case 2 ; Aggiornamento
			;Msgbox(0,"Case 2","Case 2")
			$iMsgBoxAnswer = MsgBox(49, $AppName, $aMessage[3][$iLang])
			If $bJGCancel Then Return _CloseJG(1)
			If $iMsgBoxAnswer = 2 Then Return _CloseJG(1)

		Case 3 ; Installazione

	EndSwitch

	If StringInStr($sSetup, "*", 1) Or StringInStr($sSetup, "|", 1) Then
		$sSetup = _SearchSetup($sSetup)
		If @error Or $sSetup = "" Then Return _Error_Msg(1, $iLang)
	EndIf
	$sJGTarget = $sSetup

	; Operazioni preliminari
	If _JavaRunning() <> 0 Then
		$iMsgBoxAnswer = MsgBox(1 + 48 + 262144, $AppName, $aMessage[7][$iLang])
		If $bJGCancel Then Return _CloseJG(1)
		If $iMsgBoxAnswer = 2 Then Return _CloseJG(2)
	EndIf
	If $bJGCancel Then Return _CloseJG(1)
	If _JavaRunning() <> 0 Then Return _CloseJG(2)
	TrayTip($AppName, $aMessage[4][$iLang], 10, 1)
	If $bJGCancel Then Return _CloseJG(1)

	; Modern ZIP packages are staged and validated before the live runtime is touched.
	Local $sRuntimeRoot = _JavaPreparePackage($sSetup, $sStage, $s7Zip)
	Local $iPrepareError = @error
	If $bJGCancel Then
		DirRemove($sStage, 1)
		Return _CloseJG(1)
	EndIf
	If $iPrepareError = 0 Then
		Local $iModernBackup = _JavaBackup($sJBak)
		If $iModernBackup <> 1 Then
			DirRemove($sStage, 1)
			If $bJGCancel Then Return _CloseJG(1)
			Return _Error_Msg(1, $iLang)
		EndIf
		If $bJGCancel Then Return _JavaCancelTransaction()
		Local $iModernInstall = _JavaInstallPrepared($sRuntimeRoot, @WorkingDir)
		If $iModernInstall <> 1 Then
			If $bJGCancel Then Return _JavaCancelTransaction()
			Return _Error_Msg(1, $iLang)
		EndIf
		DirRemove($sStage, 1)
		If DirRemove($sJBak, 1) = 0 And FileExists($sJBak) Then Return _Error_Msg(1, $iLang)
		FileDelete("setup\*.*")
		Return _CloseJG(0)
	EndIf

	DirRemove($sStage, 1)
	If StringRegExp($sSetup, "(?i)\.zip$") Or Not _JavaLegacyPackage($sSetup) Then Return _Error_Msg(1, $iLang)

	; Legacy EXE extraction remains available for existing packages.
	Local $iLegacyBackup = _JavaBackup($sJBak)
	If $iLegacyBackup <> 1 Then
		If $bJGCancel Then Return _JavaCancelTransaction()
		Return _Error_Msg(1, $iLang)
	EndIf
	If $bJGCancel Then Return _JavaCancelTransaction()

;Msgbox(0,"Backup Java on",$sJBak)
	; Estrazione Setup
;Msgbox(0,"_UnZip 1 ",$sSetup & ' ' & $LibPath & "\Java\" & ' ' & $s7Zip )
	_UnZip($sSetup, ".\", $s7Zip)
	If $bJGCancel Then Return _JavaCancelTransaction()
	If @error Then Return _Error_Msg(1, $iLang)
;Msgbox(0,"FileDelete 1 ","FileDelete 1 ")
	FileDelete("patchjre.exe")
	If $bJGCancel Then Return _JavaCancelTransaction()
	If @error Then Return _Error_Msg(1, $iLang)
;Msgbox(0,"FileDelete 2 ","FileDelete 2 ")
	FileDelete("zipper.exe")
	If $bJGCancel Then Return _JavaCancelTransaction()
	If @error Then Return _Error_Msg(1, $iLang)
;Msgbox(0,"_UnZip 2 ","")
	_UnZip("core.zip", ".\", $s7Zip)
	If $bJGCancel Then Return _JavaCancelTransaction()
	If @error Then Return _Error_Msg(1, $iLang)
	FileDelete("core.zip")
	If $bJGCancel Then Return _JavaCancelTransaction()
;Msgbox(0,"_UnZip 3 ","")

	; Creazione file mancanti
	FileMove("regutils.dll", "bin\regutils.dll", 1)
	FileCopy("bin\msvcr71.dll", "bin\new_plugin\msvcr71.dll", 1)
	FileCopy("bin\npdeploytk.dll", "bin\new_plugin\npdeploytk.dll", 1)
	If $bJGCancel Then Return _JavaCancelTransaction()
;Msgbox(0,"Filecopy done ","")
	_UnPack("lib\*.pack", $sUnPack)
	If $bJGCancel Then Return _JavaCancelTransaction()
	_UnPack("lib\ext\*.pack", $sUnPack)
	If $bJGCancel Then Return _JavaCancelTransaction()
	_UnPack("lib\servicetag\*.pack", $sUnPack)
	If $bJGCancel Then Return _JavaCancelTransaction()
;Msgbox(0,"_UnPack done ","")
	RunWait($sJava & ' -Xshare:dump', @WorkingDir, @SW_HIDE)
	If $bJGCancel Then Return _JavaCancelTransaction()

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
	$bJGCancel = True
	Return 1
EndFunc   ;==>_ExitJG

;===============================================================================
;
; Function Name:	_CloseJG()
; Description:		JavaGet procedure aborted by user
;
;===============================================================================
Func _CloseJG($retCode)
	Local $sStatus = 'FAIL'
	Local $sAction = 'unknown'
	Local $sDetail = ''

	Switch $iJGAction
		Case 0
			$sAction = 'none'
		Case 1
			$sAction = 'download-install'
		Case 2
			$sAction = 'update'
		Case 3
			$sAction = 'local-install'
	EndSwitch

	Switch $retCode
		Case 0
			If $iJGAction = 0 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=no setup action needed'
			Else
				$sStatus = 'PASS'
			EndIf
		Case 1
			If $bJGCancel Or $iMsgBoxAnswer = 2 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=user cancelled'
			Else
				$sDetail = 'reason=download or setup failed'
			EndIf
		Case 2
			If $bJGCancel Or $iMsgBoxAnswer = 2 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=user cancelled while Java was running'
			Else
				$sDetail = 'reason=Java process still running'
			EndIf
		Case 4
			$sDetail = 'reason=installation transaction failed'
		Case 5
			$sDetail = 'reason=JavaURL missing'
		Case 6
			$sDetail = 'reason=JavaURL invalid'
		Case Else
			$sDetail = 'reason=unknown JavaGet result'
	EndSwitch

	If $sDetail <> '' Then $sDetail &= '; '
	$sDetail &= 'action=' & $sAction
	_DebugJavaResult($sStatus, 'JavaGet', $sJGTarget, $retCode, 0, 0, $sDetail)
	TraySetState(2)
	Return $retCode
EndFunc   ;==>_CloseJG

Func _JavaCancelTransaction()
	_JavaResume($sJBak)
	Return _CloseJG(1)
EndFunc   ;==>_JavaCancelTransaction

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
	Return _CloseJG(4)
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
	Local $aSearch = StringSplit($sSearch, "|", 2)
	For $i = 0 To UBound($aSearch) - 1
		Local $hPath = FileFindFirstFile($aSearch[$i])
		If $hPath = -1 Then ContinueLoop
		Local $sPath = FileFindNextFile($hPath)
		Local $iFindError = @error
		FileClose($hPath)
		If $iFindError Or $sPath = "" Then ContinueLoop
		Local $sDir = StringRegExpReplace($aSearch[$i], "[^\\/]+$", "", 1)
		Return SetError(0, 0, $sDir & $sPath)
	Next
	Return SetError(1, 0, "")
EndFunc   ;==>_SearchSetup

;===============================================================================
;
; Function Name:	_JavaBackup()
; Description:		For JavaGet: backups original Java into another folder for eventual resume
;
;===============================================================================
Func _JavaBackup($sBackup)
	Local $sLivePath = StringRegExpReplace(@WorkingDir, "[\\/]+$", "")
	If Not _JavaTransactionPathValid($sBackup, $sLivePath) Then Return SetError(1, 0, 0)
	If FileExists($sBackup) Then Return SetError(2, 0, 0)
	If DirCreate($sBackup) <> 1 Then Return SetError(3, 0, 0)

	If _JavaCopyContents($sLivePath, $sBackup, "setup|old_java|.java-stage", True) <> 1 Then
		DirRemove($sBackup, 1)
		Return SetError(4, 0, 0)
	EndIf
	If _JavaRemoveContents($sLivePath, "setup|old_java|.java-stage") <> 1 Then
		_JavaResume($sBackup)
		Return SetError(5, 0, 0)
	EndIf
	Return SetError(0, 0, 1)
EndFunc   ;==>_JavaBackup

;===============================================================================
;
; Function Name:	_JavaResume()
; Description:		For JavaGet: resumes a complete Java runtime backup
;===============================================================================
Func _JavaResume($sBackup)
	Local $sLivePath = StringRegExpReplace(@WorkingDir, "[\\/]+$", "")
	If Not _JavaTransactionPathValid($sBackup, $sLivePath) Then Return SetError(1, 0, 0)
	If Not FileExists($sBackup) Then Return SetError(2, 0, 0)
	If _JavaRemoveContents($sLivePath, "setup|old_java") <> 1 Then Return SetError(3, 0, 0)
	If _JavaCopyContents($sBackup, $sLivePath) <> 1 Then Return SetError(4, 0, 0)
	If DirRemove($sBackup, 1) = 0 And FileExists($sBackup) Then Return SetError(5, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_JavaResume

;===============================================================================
;
; Function Name:	_JavaPreparePackage()
; Description:		Extracts a Java package into an isolated staging directory
;===============================================================================
Func _JavaPreparePackage($sSetup, $sStage, $s7Zip)
	DirRemove($sStage, 1)
	If FileExists($sStage) Then Return SetError(1, 0, "")
	If DirCreate($sStage) <> 1 Then Return SetError(1, 0, "")
	_UnZip($sSetup, $sStage, $s7Zip)
	Local $iExtractError = @error
	If $iExtractError Then
		DirRemove($sStage, 1)
		Return SetError(2, $iExtractError, "")
	EndIf
	Local $sRuntimeRoot = _JavaFindRuntimeRoot($sStage)
	Local $iRootError = @error
	If $iRootError Then
		DirRemove($sStage, 1)
		Return SetError(3, $iRootError, "")
	EndIf
	Return SetError(0, 0, $sRuntimeRoot)
EndFunc   ;==>_JavaPreparePackage

;===============================================================================
;
; Function Name:	_JavaFindRuntimeRoot()
; Description:		Finds a direct or single-wrapper Windows Java runtime
;===============================================================================
Func _JavaFindRuntimeRoot($sStage)
	$sStage = StringRegExpReplace($sStage, "[\\/]+$", "")
	If Not FileExists($sStage) Then Return SetError(1, 0, "")
	If _JavaRuntimeValid($sStage) Then Return SetError(0, 0, $sStage)

	Local $hPath = FileFindFirstFile($sStage & "\*")
	If $hPath = -1 Then Return SetError(1, 0, "")
	Local $sRuntimeRoot = ""
	Local $iRuntimeCount = 0
	While 1
		Local $sName = FileFindNextFile($hPath)
		If @error Then ExitLoop
		Local $sPath = $sStage & "\" & $sName
		If StringInStr(FileGetAttrib($sPath), "D", 2) = 0 Then ContinueLoop
		If _JavaRuntimeValid($sPath) Then
			$iRuntimeCount += 1
			$sRuntimeRoot = $sPath
		EndIf
	WEnd
	FileClose($hPath)
	If $iRuntimeCount = 0 Then Return SetError(1, 0, "")
	If $iRuntimeCount > 1 Then Return SetError(2, 0, "")
	Return SetError(0, 0, $sRuntimeRoot)
EndFunc   ;==>_JavaFindRuntimeRoot

Func _JavaRuntimeValid($sPath)
	Return FileExists($sPath & "\bin\java.exe") And FileExists($sPath & "\bin\javaw.exe")
EndFunc   ;==>_JavaRuntimeValid

Func _JavaInstallPrepared($sRuntimeRoot, $sLivePath)
	If Not _JavaRuntimeValid($sRuntimeRoot) Then Return SetError(1, 0, 0)
	If _JavaCopyContents($sRuntimeRoot, $sLivePath, "", True) <> 1 Then Return SetError(2, 0, 0)
	If Not _JavaRuntimeValid($sLivePath) Then Return SetError(3, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_JavaInstallPrepared

Func _JavaTransactionPathValid($sBackup, $sLivePath)
	$sBackup = StringRegExpReplace($sBackup, "[\\/]+$", "")
	$sLivePath = StringRegExpReplace($sLivePath, "[\\/]+$", "")
	Local $sPrefix = $sLivePath & "\"
	If StringLeft(StringLower($sBackup), StringLen($sPrefix)) <> StringLower($sPrefix) Then Return False
	Local $sChild = StringTrimLeft($sBackup, StringLen($sPrefix))
	If $sChild = "" Or StringInStr($sChild, "\") Or StringInStr($sChild, "/") Then Return False
	Return True
EndFunc   ;==>_JavaTransactionPathValid

Func _JavaCopyContents($sSource, $sDest, $sExclude = "", $bAllowCancel = False)
	If Not FileExists($sSource) Then Return SetError(1, 0, 0)
	If Not FileExists($sDest) And DirCreate($sDest) <> 1 Then Return SetError(2, 0, 0)
	Local $hPath = FileFindFirstFile($sSource & "\*")
	If $hPath = -1 Then Return SetError(0, 0, 1)
	While 1
		Local $sName = FileFindNextFile($hPath)
		If @error Then ExitLoop
		If $bAllowCancel And $bJGCancel Then
			FileClose($hPath)
			Return SetError(4, 0, 0)
		EndIf
		If _JavaNameExcluded($sName, $sExclude) Then ContinueLoop
		Local $sSourcePath = $sSource & "\" & $sName
		Local $sDestPath = $sDest & "\" & $sName
		Local $iResult
		If StringInStr(FileGetAttrib($sSourcePath), "D", 2) Then
			$iResult = DirCopy($sSourcePath, $sDestPath, 1)
		Else
			$iResult = FileCopy($sSourcePath, $sDestPath, 1)
		EndIf
		If $bAllowCancel And $bJGCancel Then
			FileClose($hPath)
			Return SetError(4, 0, 0)
		EndIf
		If $iResult <> 1 Then
			FileClose($hPath)
			Return SetError(3, 0, 0)
		EndIf
	WEnd
	FileClose($hPath)
	Return SetError(0, 0, 1)
EndFunc   ;==>_JavaCopyContents

Func _JavaRemoveContents($sPath, $sExclude = "")
	If Not FileExists($sPath) Then Return SetError(1, 0, 0)
	Local $hPath = FileFindFirstFile($sPath & "\*")
	If $hPath = -1 Then Return SetError(0, 0, 1)
	Local $aNames[1]
	$aNames[0] = 0
	While 1
		Local $sName = FileFindNextFile($hPath)
		If @error Then ExitLoop
		If _JavaNameExcluded($sName, $sExclude) Then ContinueLoop
		$aNames[0] += 1
		ReDim $aNames[$aNames[0] + 1]
		$aNames[$aNames[0]] = $sName
	WEnd
	FileClose($hPath)

	For $i = 1 To $aNames[0]
		Local $sItemPath = $sPath & "\" & $aNames[$i]
		Local $iResult
		If StringInStr(FileGetAttrib($sItemPath), "D", 2) Then
			$iResult = DirRemove($sItemPath, 1)
		Else
			$iResult = FileDelete($sItemPath)
		EndIf
		If $iResult <> 1 Then Return SetError(2, 0, 0)
	Next
	Return SetError(0, 0, 1)
EndFunc   ;==>_JavaRemoveContents

Func _JavaNameExcluded($sName, $sExclude)
	If $sExclude = "" Then Return False
	Local $aExclude = StringSplit($sExclude, "|", 2)
	For $i = 0 To UBound($aExclude) - 1
		If StringLower($sName) = StringLower($aExclude[$i]) Then Return True
	Next
	Return False
EndFunc   ;==>_JavaNameExcluded

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
    If @error Or $hDownload = 0 Then Return SetError(5, @error, 0)
    Local $iCount = 0
    While Not InetGetInfo($hDownload, 2) ; 2 = complete
        If $bJGCancel Then
            InetClose($hDownload)
            FileDelete($sDest & '.part')
            Return SetError(7, 0, 0)
        EndIf
        Local $iBytesRead = InetGetInfo($hDownload, 0)
        $iCount = Round($iBytesRead / $iSize * 100, 0)
        TrayTip($aMessage[6][$iLang], $iCount & "%", 10, 16)
        Sleep(250)
    WEnd
    If $bJGCancel Then
        InetClose($hDownload)
        FileDelete($sDest & '.part')
        Return SetError(7, 0, 0)
    EndIf
    Local $iBytesRead = InetGetInfo($hDownload, 0)
    Local $bSuccess = InetGetInfo($hDownload, 3)
    InetClose($hDownload)
    If Not $bSuccess Or $iBytesRead = -1 Then Return SetError(5, 0, 0)
    If $iBytesRead <> $iSize Then Return SetError(6, 0, 0)
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
; Function Name:	_TextFileReadPreserved()
; Description:		Reads an existing text file with its detected encoding
;
;===============================================================================
Func _TextFileReadPreserved($file, ByRef $content, ByRef $encoding)
	$encoding = FileGetEncoding($file)
	If @error Then Return SetError(1, 0, False)
	If $encoding = 0 Then $encoding = 512

	Local $hFile = FileOpen($file, $encoding)
	If $hFile = -1 Then Return SetError(2, 0, False)
	$content = FileRead($hFile)
	Local $iError = @error
	FileClose($hFile)
	If $iError Then Return SetError(3, 0, False)
	Return SetError(0, 0, True)
EndFunc   ;==>_TextFileReadPreserved

;===============================================================================
;
; Function Name:	_TextFileWritePreserved()
; Description:		Writes text using the original file encoding
;
;===============================================================================
Func _TextFileWritePreserved($file, $content, $encoding)
	Local $hFile = FileOpen($file, 2 + $encoding)
	If $hFile = -1 Then Return SetError(1, 0, False)
	FileWrite($hFile, $content)
	Local $iError = @error
	FileClose($hFile)
	If $iError Then Return SetError(2, 0, False)
	Return SetError(0, 0, True)
EndFunc   ;==>_TextFileWritePreserved

;===============================================================================
;
; Function Name:	_TextFileSplitLines()
; Description:		Splits text while retaining its line-ending convention
;
;===============================================================================
Func _TextFileSplitLines($content, ByRef $lines, ByRef $eol)
	$eol = @CRLF
	If StringInStr($content, @CRLF) Then
		$eol = @CRLF
	ElseIf StringInStr($content, @LF) Then
		$eol = @LF
	ElseIf StringInStr($content, @CR) Then
		$eol = @CR
	EndIf

	Local $normalized = StringReplace($content, @CRLF, @LF)
	$normalized = StringReplace($normalized, @CR, @LF)
	$lines = StringSplit($normalized, @LF, 1)
EndFunc   ;==>_TextFileSplitLines

;===============================================================================
;
; Function Name:	_TextFileJoinLines()
; Description:		Reassembles lines without discarding trailing empty lines
;
;===============================================================================
Func _TextFileJoinLines(ByRef $lines, $eol)
	Local $content = $lines[1]
	For $i = 2 To $lines[0]
		$content &= $eol & $lines[$i]
	Next
	Return $content
EndFunc   ;==>_TextFileJoinLines

;===============================================================================
;
; Function Name:	_TextFileAppendLine()
; Description:		Appends one complete line using the existing EOL style
;
;===============================================================================
Func _TextFileAppendLine($content, $line, $eol)
	If $content = '' Then Return $line & $eol
	If StringRight($content, StringLen($eol)) = $eol Then Return $content & $line & $eol
	Return $content & $eol & $line & $eol
EndFunc   ;==>_TextFileAppendLine

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
	Local $begin, $function, $replaces = 0, $exists = 0
	Select
		Case $mode = 'Global'
			$begin = 'pref("'
			$function = 'pref'
		Case $mode = 'User'
			$begin = 'user_pref("'
			$function = 'user_pref'
	EndSelect
	If FileExists($file) Then
		Local $read, $encoding, $eol, $_read, $lines
		If Not _TextFileReadPreserved($file, $read, $encoding) Then Return SetError(1, 0, 0)
		_TextFileSplitLines($read, $_read, $eol)
		$lines = $_read[0]
		Local $_write[$lines + 1]
		$_write[0] = $lines
		For $l = 1 To $lines
			If _MozPrefsLineMatches($_read[$l], $function, $pref) Then
				$_write[$l] = $begin & $pref & '", ' & $value & ');'
				If $_write[$l] <> $_read[$l] Then $replaces = 1
				$exists = 1
			Else
				$_write[$l] = $_read[$l]
			EndIf
		Next
		If $replaces = 1 Then
			Local $updated = _TextFileJoinLines($_write, $eol)
			If Not _TextFileWritePreserved($file, $updated, $encoding) Then Return SetError(2, 0, 0)
		EndIf
		If $exists = 0 Then
			Local $appended = _TextFileAppendLine($read, $begin & $pref & '", ' & $value & ');', $eol)
			If Not _TextFileWritePreserved($file, $appended, $encoding) Then Return SetError(2, 0, 0)
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
; Function Name:	_MozPrefsLineMatches()
; Description:		Checks for an exact Mozilla preference declaration
;
;===============================================================================
Func _MozPrefsLineMatches($line, $function, $pref)
	Local $candidate = StringStripWS($line, 1)
	If Not (StringLeft($candidate, StringLen($function)) == $function) Then Return False
	$candidate = StringStripWS(StringTrimLeft($candidate, StringLen($function)), 1)
	If StringLeft($candidate, 1) <> '(' Then Return False
	$candidate = StringStripWS(StringTrimLeft($candidate, 1), 1)
	Local $quotedPref = '"' & $pref & '"'
	If Not (StringLeft($candidate, StringLen($quotedPref)) == $quotedPref) Then Return False
	$candidate = StringStripWS(StringTrimLeft($candidate, StringLen($quotedPref)), 1)
	Return StringLeft($candidate, 1) = ','
EndFunc   ;==>_MozPrefsLineMatches


;===============================================================================
;
; Function Name:	_NormalPath()
; Description:		Returns a standard path string with only singles backslash
;
;===============================================================================
Func _NormalPath($path)
	Local $_normalpath, $normalpath, $normalized
	$normalized = StringReplace($path, '/', '\')
	Local $isUNC = StringLeft($normalized, 2) = '\\'
	$_normalpath = StringSplit($normalized, '\')
	$normalpath = $_normalpath[1]
	For $n = 2 To $_normalpath[0]
		If $_normalpath[$n] <> '' Then $normalpath = $normalpath & '\' & $_normalpath[$n]
	Next
	If $isUNC Then
		If $normalpath = '' Then Return '\\'
		Return '\' & $normalpath
	EndIf
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
Func _ProcessGetPIDs($sProcessName)
	Local $aProcesses = ProcessList($sProcessName)
	Local $sPIDs = "|"

	If @error Then Return $sPIDs

	For $i = 1 To $aProcesses[0][0]
		$sPIDs &= $aProcesses[$i][1] & "|"
	Next

	Return $sPIDs
EndFunc   ;==>_ProcessGetPIDs

Func _ProcessExistsExcept($sProcessName, $sIgnoredPIDs)
	Local $aProcesses = ProcessList($sProcessName)

	If @error Then Return False

	For $i = 1 To $aProcesses[0][0]
		If StringInStr($sIgnoredPIDs, "|" & $aProcesses[$i][1] & "|") = 0 Then
			Return True
		EndIf
	Next

	Return False
EndFunc   ;==>_ProcessExistsExcept

Func _ProcessCloseExcept($sProcessName, $sIgnoredPIDs, $iTimeout = 3000)
	Local $hTimer = TimerInit()
	Local $aProcesses
	Local $bFound

	Do
		$bFound = False
		$aProcesses = ProcessList($sProcessName)

		If Not @error Then
			For $i = 1 To $aProcesses[0][0]
				If StringInStr($sIgnoredPIDs, "|" & $aProcesses[$i][1] & "|") = 0 Then
					$bFound = True
					ProcessClose($aProcesses[$i][1])
				EndIf
			Next
		EndIf

		If Not $bFound Then Return True

		Sleep(100)
	Until TimerDiff($hTimer) >= $iTimeout

	Return Not _ProcessExistsExcept($sProcessName, $sIgnoredPIDs)
EndFunc   ;==>_ProcessCloseExcept

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
; Function Name:	_CommandLineQuoteArgument()
; Description:		Quotes one argument using Windows command-line parsing rules
;
;===============================================================================
Func _CommandLineQuoteArgument($sArgument)
	Local $sQuoted = '"', $iBackslashes = 0, $sCharacter, $j

	For $i = 1 To StringLen($sArgument)
		$sCharacter = StringMid($sArgument, $i, 1)

		If $sCharacter = '\' Then
			$iBackslashes += 1
		ElseIf $sCharacter = '"' Then
			For $j = 1 To ($iBackslashes * 2) + 1
				$sQuoted &= '\'
			Next
			$sQuoted &= '"'
			$iBackslashes = 0
		Else
			If $iBackslashes > 0 Then
				For $j = 1 To $iBackslashes
					$sQuoted &= '\'
				Next
			EndIf
			$sQuoted &= $sCharacter
			$iBackslashes = 0
		EndIf
	Next

	If $iBackslashes > 0 Then
		For $j = 1 To $iBackslashes * 2
			$sQuoted &= '\'
		Next
	EndIf
	Return $sQuoted & '"'
EndFunc   ;==>_CommandLineQuoteArgument

;===============================================================================
;
; Function Name:	_Run()
; Description:		Run the portable program
; Syntax:			_Run(ExecutablePath,Arguments,RunWait,HideShellWindow)
;
;===============================================================================
Func _Run($executablePath, $arguments, $runWait, $hideShellWindow)
	Local $iResult, $iRunError
	Local $iShowFlag = @SW_SHOW
	Local $commandLine = '"' & $executablePath & '"' & $arguments
	Local $extension = StringLower(_FileInfo($executablePath, 3))
	Local $bUseShell = False

	If $hideShellWindow = 'true' Then $iShowFlag = @SW_HIDE

	; Batch files require the command processor. Preserve the historical shell
	; path for other hidden, non-executable targets that may use file associations.
	If $extension = 'bat' Or $extension = 'cmd' Then
		$bUseShell = True
	ElseIf $hideShellWindow = 'true' And $extension <> 'exe' And $extension <> 'com' And $extension <> 'pif' Then
		$bUseShell = True
	EndIf

	; Executable targets bypass the shell so metacharacters remain literal.
	If $bUseShell Then
		$commandLine = _CommandLineQuoteArgument(@ComSpec) & ' /d /s /c ""' & $executablePath & '"' & $arguments & '"'
	EndIf

	If $runWait = 'true' Then
		If $TraceActive Then
			_DebugWrite("===== Trace RunWait program : " & $commandLine)
			$iResult = _TraceRunAndWait($commandLine, $iShowFlag)
			$iRunError = @error
		Else
			_DebugWrite("===== RunWait program : " & $commandLine)
			$iResult = RunWait($commandLine, '', $iShowFlag)
			$iRunError = @error
		EndIf
	Else
		_DebugWrite("===== Run program : " & $commandLine)
		$iResult = Run($commandLine, '', $iShowFlag)
		$iRunError = @error
		If $TraceActive And $iRunError = 0 Then
			$TraceApplicationPID = $iResult
			$TraceApplicationExitCode = 'not waited'
			_DebugWrite('[PASS] [Process] Application launch PID=' & $TraceApplicationPID & _
					' (command=' & $commandLine & ')')
		EndIf
	EndIf

	If $iRunError Then
		_DebugWrite(">>>>>> Run Error=" & $iRunError & " : " & $commandLine)
		Return SetError($iRunError, 0, 0)
	EndIf

	Return SetError(0, 0, $iResult)
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
	Local $_paths, $path, $iEnvResult, $iEnvError
	If $string = '' Then Return SetError(0, 0, 0)

	$_paths = StringSplit($string, ';')
	$path = _FullPath($_paths[1])
	For $i = 2 To $_paths[0]
		$path = $path & ';' & _FullPath($_paths[$i])
	Next

	$iEnvResult = EnvSet('PATH', $path)
	$iEnvError = @error
	If $log = 'true' Then IniWrite($logfile, 'Environment', 'PATH', $path)
	If $iEnvError Or $iEnvResult = 0 Or EnvGet('PATH') <> $path Then Return SetError(1, $iEnvError, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_SetPath

;===============================================================================
;
; Function Name:	_SetEnv()
; Description:		Sets an environmental variable
; Requirements:		_FullPathPlus
;
;===============================================================================
Func _SetEnv($var, $value, $log, $logfile)
	Local $iEnvResult, $iEnvError
	$value = _FullPathPlus($value)
	$iEnvResult = EnvSet($var, $value)
	$iEnvError = @error
	If $log = 'true' Then IniWrite($logfile, 'Environment', $var, $value)
	If $iEnvError Or $iEnvResult = 0 Or EnvGet($var) <> $value Then Return SetError(1, $iEnvError, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_SetEnv

;===============================================================================
;
; Function Name:	_SetPortableEnvironmentDefaults()
; Description:		Provides simple portable LOCALAPPDATA, TEMP and TMP defaults.
; Notes:			Call before the configured [Environment] section so explicit
;                   values retain priority. FixTemp intentionally controls both
;                   Windows temporary-directory variables.
;
;===============================================================================
Func _SetPortableEnvironmentDefaults($sFixLocalAppData, $sFixTemp, $sLibPath, _
		$sLog, $sLogFile)
	Local $sLocalAppData = $sLibPath & '\AppData\Local'
	Local $sPortableTemp = $sLocalAppData & '\Temp'
	Local $vResult, $iError, $iExtended
	Local $bFailed = False

	If $sFixLocalAppData = 'true' Then
		$vResult = DirCreate($sLocalAppData)
		$iError = @error
		$iExtended = @extended
		_DebugOperationResult('Environment', 'DirCreate', $sLocalAppData, _
				$vResult, $iError, $iExtended)
		If $iError Or $vResult <> 1 Or Not FileExists($sLocalAppData) Then
			$bFailed = True
		Else
			$vResult = _SetEnv('LOCALAPPDATA', $sLocalAppData, $sLog, $sLogFile)
			$iError = @error
			$iExtended = @extended
			_DebugEnvironmentResult('LOCALAPPDATA', $sLocalAppData, _
					$sLocalAppData, $vResult, $iError, $iExtended)
			If $iError Or $vResult <> 1 Then $bFailed = True
		EndIf
	EndIf

	If $sFixTemp = 'true' Then
		$vResult = DirCreate($sPortableTemp)
		$iError = @error
		$iExtended = @extended
		_DebugOperationResult('Environment', 'DirCreate', $sPortableTemp, _
				$vResult, $iError, $iExtended)
		If $iError Or $vResult <> 1 Or Not FileExists($sPortableTemp) Then
			$bFailed = True
		Else
			$vResult = _SetEnv('TEMP', $sPortableTemp, $sLog, $sLogFile)
			$iError = @error
			$iExtended = @extended
			_DebugEnvironmentResult('TEMP', $sPortableTemp, $sPortableTemp, _
					$vResult, $iError, $iExtended)
			If $iError Or $vResult <> 1 Then $bFailed = True

			$vResult = _SetEnv('TMP', $sPortableTemp, $sLog, $sLogFile)
			$iError = @error
			$iExtended = @extended
			_DebugEnvironmentResult('TMP', $sPortableTemp, $sPortableTemp, _
					$vResult, $iError, $iExtended)
			If $iError Or $vResult <> 1 Then $bFailed = True
		EndIf
	EndIf

	If $bFailed Then Return SetError(1, 0, 0)
	Return SetError(0, 0, 1)
EndFunc   ;==>_SetPortableEnvironmentDefaults

Func _DebugEnvironmentResult($sVariable, $sConfigured, $sResolved, $vResult, $iError, $iExtended)
	If $Debug <> 'true' Then Return

	Local $sStatus = 'FAIL'
	Local $sDetail = 'resolved=' & $sResolved
	If $iError = 0 And $vResult = 1 And EnvGet($sVariable) = $sResolved Then
		$sStatus = 'PASS'
	ElseIf $iError = 0 And $vResult = 0 And $sConfigured = '' Then
		$sStatus = 'SKIP'
		$sDetail &= '; reason=blank value'
	EndIf

	_DebugWrite('[' & $sStatus & '] [Environment] ' & $sVariable & '=' & $sConfigured & _
			' (result=' & $vResult & '; error=' & $iError & '; extended=' & $iExtended & _
			'; ' & $sDetail & ')')
EndFunc   ;==>_DebugEnvironmentResult

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
        $Image = $Temp & "\x-splash.jpg"
        FileInstall('graphics\x-splash.jpg', $Image, 1)
    EndIf
    If Not FileExists($Image) Then
        Return SetError(1, 0, False)
    EndIf

    Local $width = Int(Number($Width_SS)), $height = Int(Number($Height_SS))
	Local $aImageSize = _ImageGetSize($Image)
	If IsArray($aImageSize) And $aImageSize[0] > 0 And $aImageSize[1] > 0 Then
		If $width < 1 And $height < 1 Then
			$width = $aImageSize[0]
			$height = $aImageSize[1]
		ElseIf $width < 1 Then
			$width = Round($aImageSize[0] * $height / $aImageSize[1])
		ElseIf $height < 1 Then
			$height = Round($aImageSize[1] * $width / $aImageSize[0])
		EndIf
	EndIf
    If $width < 1 Then $width = 307
    If $height < 1 Then $height = 213

    $TimeOut_SS = Number($TimeOut_SS)
    If $TimeOut_SS < 500 Then $TimeOut_SS = 3000

    Local $opt = 1
    If $Title_SS <> '' Then $opt = -1

    SplashImageOn($Title_SS, $Image, $width, $height, -1, -1, $opt)

    If @error Then
    EndIf
    AdlibRegister("_SplashScreenOff", $TimeOut_SS)
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
	AdlibUnRegister("_SplashScreenOff")
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
    Local $iTrayTipSeconds = Ceiling(Number($TimeOut_SS) / 1000)
    TrayTip($title, "Software made portable with winPenPack Technology" & @CRLF & "http://www.winpenpack.com", $iTrayTipSeconds, 1+16)
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
	Local $read, $encoding, $eol, $_read, $lines, $_begin, $_end, $replaces = 0
	If Not FileExists($file) Then Return SetError(1, 0, 0)
	If Not _TextFileReadPreserved($file, $read, $encoding) Then Return SetError(1, 0, 0)
	_TextFileSplitLines($read, $_read, $eol)
	$lines = $_read[0]
	Local $_write[$lines + 1]
	$_write[0] = $lines
	For $l = 1 To $lines
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
		Local $updated = _TextFileJoinLines($_write, $eol)
		If Not _TextFileWritePreserved($file, $updated, $encoding) Then Return SetError(2, 0, 0)
		Return SetError(0, 0, 1)
	EndIf

	Return SetError(0, 0, 0)
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
	If $delimiter[0] > 1 And StringIsInt($delimiter[2]) Then $count = Int($delimiter[2])
	If $delimiter[0] > 2 And $delimiter[3] <> '' Then $modifier = $delimiter[3]
	Local $pattern = StringSplit($string, $delimiter[1], 1)
	If @error Or $pattern[0] <> 2 Then Return SetError(1, 0, 0)
	$pattern[1] = _RegExpProtector($pattern[1], 1)
	$pattern[2] = _RegExpProtector($pattern[2], 2, $modifier)
	If FileExists($file) = 0 Then Return SetError(1, 0, 0)
	Local $read, $encoding
	If Not _TextFileReadPreserved($file, $read, $encoding) Then Return SetError(2, 0, 0)
	Local $write = StringRegExpReplace($read, $pattern[1], $pattern[2], $count)
	If @error Then Return SetError(2, 0, 0)
	If $write = $read Then Return SetError(0, 0, 0)
	If Not _TextFileWritePreserved($file, $write, $encoding) Then Return SetError(2, 0, 0)
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
	Local $ftw, $lineNum, $read, $encoding, $eol, $_read, $lines, $write
	Select
		Case $line = 'EOF'
			If FileExists($file) Then
				If Not _TextFileReadPreserved($file, $read, $encoding) Then Return SetError(1, 0, 0)
				_TextFileSplitLines($read, $_read, $eol)
				$write = _TextFileAppendLine($read, $content, $eol)
				If Not _TextFileWritePreserved($file, $write, $encoding) Then Return SetError(2, 0, 0)
			Else
				$ftw = FileOpen($file, 9)
				If $ftw = -1 Then Return SetError(2, 0, 0)
				Local $iWriteResult = FileWriteLine($ftw, $content)
				FileClose($ftw)
				If $iWriteResult = 0 Then Return SetError(2, 0, 0)
			EndIf
			Return SetError(0, 0, 1)
		Case StringInStr($line, 'Line')
			$lineNum = StringTrimLeft($line, 4)
			If StringIsInt($lineNum) And Int($lineNum) > 0 Then
				$lineNum = Int($lineNum)
				If FileExists($file) Then
					If Not _TextFileReadPreserved($file, $read, $encoding) Then Return SetError(1, 0, 0)
					_TextFileSplitLines($read, $_read, $eol)
					$lines = $_read[0]
					If $lineNum > $lines Then
						ReDim $_read[$lineNum + 1]
						$_read[0] = $lineNum
					EndIf
					$_read[$lineNum] = $content
					$write = _TextFileJoinLines($_read, $eol)
					If $write <> $read Then
						If Not _TextFileWritePreserved($file, $write, $encoding) Then Return SetError(2, 0, 0)
						Return SetError(0, 0, 1)
					EndIf
					Return SetError(0, 0, 0)
				Else
					$ftw = FileOpen($file, 9)
					If $ftw = -1 Then Return SetError(2, 0, 0)
					Local $bWriteOK = True
					For $l = 1 To $lineNum - 1
						If FileWriteLine($ftw, '') = 0 Then $bWriteOK = False
					Next
					If FileWriteLine($ftw, $content) = 0 Then $bWriteOK = False
					FileClose($ftw)
					If Not $bWriteOK Then Return SetError(2, 0, 0)
					Return SetError(0, 0, 1)
				EndIf
			EndIf
	EndSelect

	Return SetError(3, 0, 0)
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
		Local $read, $encoding, $eol, $_read, $lines
		If Not _TextFileReadPreserved($file, $read, $encoding) Then Return SetError(1, 0, 0)
		_TextFileSplitLines($read, $_read, $eol)
		$lines = $_read[0]
		Local $_write[$lines + 1]
		$_write[0] = $lines
		For $l = 1 To $lines
			If StringInStr($_read[$l], $begin & $pref & $mid) <> 0 Then
				$_write[$l] = $begin & $pref & $mid & $value & $end
				If $_write[$l] <> $_read[$l] Then $replaces = 1
				$exists = 1
			Else
				$_write[$l] = $_read[$l]
			EndIf
		Next
		If $replaces = 1 Then
			Local $updated = _TextFileJoinLines($_write, $eol)
			If Not _TextFileWritePreserved($file, $updated, $encoding) Then Return SetError(2, 0, 0)
			Return SetError(0, 0, 1)
		EndIf
		If $exists = 0 Then
			Local $appended = _TextFileAppendLine($read, $begin & $pref & $mid & $value & $end, $eol)
			If Not _TextFileWritePreserved($file, $appended, $encoding) Then Return SetError(2, 0, 0)
			Return SetError(0, 0, 1)
		EndIf
		Return SetError(0, 0, 0)
	Else
		Local $newfile
		$newfile = FileOpen($file, 9)
		If $newfile = -1 Then Return SetError(2, 0, 0)
		Local $iWriteResult = FileWriteLine($newfile, $begin & $pref & $mid & $value & $end)
		FileClose($newfile)
		If $iWriteResult = 0 Then Return SetError(2, 0, 0)
		Return SetError(0, 0, 1)
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
		$FileToRewrite = _FullPath($paths[$ixPath])
		If StringRegExp ( $FileToRewrite, "\*|\?", 0 ) = 1 then
			; Sono state specificate wildcard
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
			If $bOnlyIfExist = False Or FileExists($FileToRewrite) Then
				ReDim $array[$array[0] + 2]
				$array[$array[0] + 1] = $FileToRewrite
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
	Local $vResult, $iError, $iExtended

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

			$vResult = 0
			$iError = 0
			$iExtended = 0

			Select
				Case $_firstrunoperations[$fr][1] = ''
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'DirCopy'
					$vResult = _DirCopy($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'DirCreate'
					$vResult = _DirCreate($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'DirMove'
					$vResult = _DirMove($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'DirRemove'
					$vResult = _DirRemove($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'FileCopy'
					$vResult = _FileCopy($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'FileCreate'
					$vResult = _FileCreatePlus($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'FileDelete'
					$vResult = _FileDelete($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'FileMove'
					$vResult = _FileMove($_firstrunoperations[$fr][1])
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case $_firstrunoperations[$fr][0] = 'RunFile'
					$vResult = _RunWait($_firstrunoperations[$fr][1], $Root)
					$iError = @error
					$iExtended = @extended
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)

				Case Else
					_DebugOperationResult('FirstRunOperations', $_firstrunoperations[$fr][0], _
							$_firstrunoperations[$fr][1], $vResult, $iError, $iExtended)
			EndSelect

			If $iError <> 0 Then
				_DebugWrite(">>>>>> FirstRun operation failed: " & _
						$_firstrunoperations[$fr][0] & "=" & _
						$_firstrunoperations[$fr][1] & _
						" (error " & $iError & ")")
				Return SetError(3, $fr, 0)
			EndIf
		Next
	EndIf

	; FirstRun is cleared only after every required operation has completed
	; without reporting an error.
	If IniWrite($ScriptIni, 'Options', 'FirstRun', 'false') = 0 Then
		_DebugWrite(">>>>>> FirstRun completed but FirstRun=false could not be saved")
		Return SetError(4, 0, 0)
	EndIf

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
	Local $FileList, $aFontResult, $iFontError
	Local $iFontSuccess = 0, $iFontFailure = 0

	_DebugWrite("AddFonts : about to execute")

	$FileList = _ExpandMultiPath($string, True)
	If $FileList[0] > 0 Then
		For $IxElem = 1 To $FileList[0]
			Local $FontName
			$FontName = $FileList[$IxElem]
			_DebugWrite("AddFonts : adding " & $FontName)
			$aFontResult = DllCall("gdi32.dll","Int","AddFontResource","str",$FontName)
			$iFontError = @error
			If $iFontError Or Not IsArray($aFontResult) Then
				$iFontFailure += 1
			ElseIf $aFontResult[0] = 0 Then
				$iFontFailure += 1
			Else
				$iFontSuccess += 1
			EndIf
		Next
	EndIf	
	
	; announce fonts added to running applications
	_DebugWrite("AddFonts : announcing")
	DllCall("user32.dll", "lresult", "SendMessageTimeoutW", "hwnd", $HWND_BROADCAST, "uint", $WM_FONTCHANGE, _
			"wparam", 0, "lparam", 0, "uint", BitOR($SMTO_ABORTIFHUNG, $SMTO_NOTIMEOUTIFNOTHUNG), _
			"uint", 50, "dword_ptr*", 0)
	
	_DebugWrite("AddFonts : executed")

	If $iFontFailure > 0 Then Return SetError(1, $iFontSuccess, 0)
	If $FileList[0] = 0 Then Return SetError(0, 0, 0)
	Return SetError(0, $iFontSuccess, 1)
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
	Local $FileList, $aFontResult, $iFontError
	Local $iFontSuccess = 0, $iFontFailure = 0
	
	_DebugWrite("RemoveFonts : about to execute")
	
	$FileList=_ExpandMultiPath($string, True)
	If $FileList[0] > 0 Then
		For $IxElem = 1 To $FileList[0]
			Local $FontName
			$FontName = $FileList[$IxElem]
			_DebugWrite("RemoveFonts : removing " & $FontName)
			$aFontResult = DllCall("gdi32.dll","Int","RemoveFontResource","str",$FontName)
			$iFontError = @error
			If $iFontError Or Not IsArray($aFontResult) Then
				$iFontFailure += 1
			ElseIf $aFontResult[0] = 0 Then
				$iFontFailure += 1
			Else
				$iFontSuccess += 1
			EndIf
		Next
	EndIf	
	
	; announce fonts removed to running applications
	_DebugWrite("RemoveFonts : announcing")
	DllCall("user32.dll", "lresult", "SendMessageTimeoutW", "hwnd", $HWND_BROADCAST, "uint", $WM_FONTCHANGE, _
			"wparam", 0, "lparam", 0, "uint", BitOR($SMTO_ABORTIFHUNG, $SMTO_NOTIMEOUTIFNOTHUNG), _
			"uint", 100, "dword_ptr*", 0)
	
	_DebugWrite("RemoveFonts : executed")

	If $iFontFailure > 0 Then Return SetError(1, $iFontSuccess, 0)
	If $FileList[0] = 0 Then Return SetError(0, 0, 0)
	Return SetError(0, $iFontSuccess, 1)
EndFunc   ;==>_RemoveFonts

;===============================================================================
;
; Function Name:	_DebugOperationResult()
; Description:		Write a reliable diagnostic result for a configured operation.
; Syntax:			_DebugOperationResult(Section, Operation, Value, Result, Error, Extended)
; Requirements:		_DebugWrite & _DebugFileCreateEffectVerified
;
;===============================================================================
Func _DebugOperationResult($sSection, $sOperation, $sValue, $vResult, $iError, $iExtended)
	If $Debug <> 'true' Then Return

	Local $sStatus = 'FAIL'
	Local $sDetail = ''

	If $sValue = '' Then
		_DebugWrite("[SKIP] [" & $sSection & "] " & $sOperation & "= (reason=blank value)")
		Return
	EndIf

	Switch $sOperation
		; These legacy helpers return zero on success but set a nonzero @error
		; whenever their required operation fails.
		Case 'DirCopy', 'RunFile'
			If $iError = 0 Then $sStatus = 'PASS'
			$sDetail = 'contract=legacy zero-success'

		; FileMove uses extended value 4 for a wildcard source with no matches.
		; Exact missing sources and failed moves retain their failure result.
		Case 'FileMove'
			If $iError = 0 And $vResult = 0 And $iExtended = 4 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=no matching wildcard source'
			ElseIf $iError = 0 Then
				$sStatus = 'PASS'
				$sDetail = 'contract=legacy zero-success'
			EndIf

		; These helpers have an explicit Boolean success return.
		Case 'DirCreate', 'DirMove', 'FileCopy', 'FileDelete', 'FixUserProfile', 'Regedit', _
				'RegistryRecovery', 'RestoreRegedit', 'Junctions', 'SymLinks', _
				'RemoveJunction', 'RemoveSymLink'
			If $iError = 0 And $vResult = 1 Then $sStatus = 'PASS'
			If ($sOperation = 'Junctions' Or $sOperation = 'SymLinks') And $iError = 0 Then
				Switch $iExtended
					Case 1
						$sDetail = 'lifetime=temporary; cleanup=tracked'
					Case 2
						$sDetail = 'lifetime=persistent'
					Case 3
						$sDetail = 'reason=matching link already exists; cleanup=not-owned'
				EndSwitch
			ElseIf ($sOperation = 'RemoveJunction' Or $sOperation = 'RemoveSymLink') And _
					$iError = 0 And $iExtended = 4 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=link already absent'
			EndIf

		; FixDriveLetter returns one when it rewrites the file and zero when the
		; configured file needs no change or does not yet exist.
		Case 'FixDriveLetter'
			If $iError = 0 And $vResult = 1 Then
				$sStatus = 'PASS'
			ElseIf $iError = 0 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=no drive-letter change needed'
			EndIf

		; Text rewrite helpers return one when content changed, zero for a
		; legitimate no-change result, and set @error on failure.
		Case 'StringReplace', 'StringRegExpReplace', 'WriteToFile', 'WriteToPref', 'WriteToReg'
			If $iError = 0 And $vResult = 1 Then
				$sStatus = 'PASS'
			ElseIf $iError = 0 And $vResult = 0 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=no text change needed'
			EndIf

		; AutoIt's IniWrite has a Boolean write-success return.
		Case 'WriteToIni'
			If $iError = 0 And $vResult = 1 Then $sStatus = 'PASS'

		; Font helpers return one when every matched font was processed, zero when
		; no font matched, and set @error when at least one font operation failed.
		Case 'AddFonts', 'RemoveFonts'
			If $iError = 0 And $vResult = 1 Then
				$sStatus = 'PASS'
			ElseIf $iError = 0 And $vResult = 0 Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=no matching font file'
			EndIf

		; Recursive empty-directory removal can legitimately leave a non-empty
		; parent in place. A zero result with no error is therefore no-change.
		Case 'DirRemove'
			Local $aDirRemove = StringSplit($sValue, '|')
			Local $bEmptyOnly = False
			If $aDirRemove[0] > 1 Then $bEmptyOnly = StringInStr($aDirRemove[2], 'e', 1) > 0
			If $iError = 5 Then
				$sDetail = 'reason=protected target blocked'
			ElseIf $iError = 0 And $vResult = 1 And $iExtended = 4 Then
				$sStatus = 'PASS'
				$sDetail = 'reason=target already absent'
			ElseIf $iError = 0 And $vResult <> 0 Then
				$sStatus = 'PASS'
			ElseIf $iError = 0 And $bEmptyOnly Then
				$sStatus = 'SKIP'
				$sDetail = 'reason=no empty directory removed'
			EndIf

		; The historic FileCreate helper has no dependable return value. Verify
		; its promised effect without changing the helper's normal behaviour.
		Case 'FileCreate'
			If $iError = 0 And _DebugFileCreateEffectVerified($sValue) Then
				$sStatus = 'PASS'
				$sDetail = 'effect=verified'
			Else
				$sDetail = 'effect=not achieved'
			EndIf

		Case Else
			_DebugWrite("[WARN] [" & $sSection & "] Unknown operation=" & $sOperation & _
					" (value=" & $sValue & "; result=" & $vResult & "; error=" & $iError & _
					"; extended=" & $iExtended & ")")
			Return
	EndSwitch

	Local $sRecord = "[" & $sStatus & "] [" & $sSection & "] " & $sOperation & "=" & $sValue & _
			" (result=" & $vResult & "; error=" & $iError & "; extended=" & $iExtended
	If $sDetail <> '' Then $sRecord &= '; ' & $sDetail
	$sRecord &= ')'
	_DebugWrite($sRecord)
EndFunc   ;==>_DebugOperationResult

;===============================================================================
;
; Function Name:	_DebugApplicationLaunchResult()
; Description:		Write a reliable diagnostic result for the application launch.
; Syntax:			_DebugApplicationLaunchResult(PathToExe, RunWait, Result, Error, Extended)
; Requirements:		_DebugWrite
;
;===============================================================================
Func _DebugApplicationLaunchResult($sPathToExe, $sRunWait, $vResult, $iError, $iExtended)
	If $Debug <> 'true' Then Return

	Local $sStatus = 'FAIL'
	Local $sMode = 'Run'
	Local $sResultName = 'pid'

	If $sRunWait = 'true' Then
		$sMode = 'RunWait'
		$sResultName = 'exitcode'
		; Any exit code is a completed waited launch. @error reports launch failure.
		If $iError = 0 Then $sStatus = 'PASS'
	ElseIf $iError = 0 And $vResult > 0 Then
		; A non-waiting launch succeeds only when AutoIt returns a process ID.
		$sStatus = 'PASS'
	EndIf

	_DebugWrite("[" & $sStatus & "] [FileToRun] Launch=" & $sPathToExe & _
			" (mode=" & $sMode & "; " & $sResultName & "=" & $vResult & _
			"; error=" & $iError & "; extended=" & $iExtended & ")")
EndFunc   ;==>_DebugApplicationLaunchResult

;===============================================================================
;
; Function Name:	_DebugTempCleanupResult()
; Description:		Distinguish deleted, absent, disabled, and failed Temp cleanup.
;
;===============================================================================
Func _DebugTempCleanupResult($sDeleteTemp, $sPath, $vResult, $iError, $iExtended)
	If $Debug <> 'true' Then Return

	Local $sStatus = 'FAIL'
	Local $sDetail = 'reason=cleanup failed or was blocked'
	If $sDeleteTemp <> 'true' Then
		$sStatus = 'SKIP'
		$sDetail = 'reason=DeleteTemp disabled'
	ElseIf $iError = 0 And $vResult = 1 And $iExtended = 1 Then
		$sStatus = 'SKIP'
		$sDetail = 'reason=Temp path not present'
	ElseIf $iError = 0 And $vResult = 1 And $iExtended = 2 Then
		$sStatus = 'PASS'
		$sDetail = 'effect=directory removed'
	EndIf

	_DebugWrite('[' & $sStatus & '] [Cleanup] Temp=' & $sPath & _
			' (result=' & $vResult & '; error=' & $iError & '; extended=' & $iExtended & _
			'; ' & $sDetail & ')')
EndFunc   ;==>_DebugTempCleanupResult

;===============================================================================
;
; Function Name:	_DebugFileCreateEffectVerified()
; Description:		Verify that every configured FileCreate target exists as an empty file.
; Syntax:			_DebugFileCreateEffectVerified(Path1\File1;File2|Path2\File3)
; Requirements:		_FileInfo & _FullPath
;
;===============================================================================
Func _DebugFileCreateEffectVerified($sValue)
	Local $aPaths = StringSplit($sValue, '|')
	If $aPaths[0] = 0 Then Return False

	For $iPath = 1 To $aPaths[0]
		Local $aFiles = StringSplit($aPaths[$iPath], ';')
		If $aFiles[0] = 0 Or $aFiles[1] = '' Then Return False

		Local $sFirstFile = _FullPath($aFiles[1])
		If @error Or $sFirstFile = '' Then Return False
		Local $sParent = _FileInfo($sFirstFile, 0)

		If Not _DebugEmptyFileEffectVerified($sFirstFile) Then Return False

		For $iFile = 2 To $aFiles[0]
			If Not _DebugEmptyFileEffectVerified($sParent & '\' & $aFiles[$iFile]) Then Return False
		Next
	Next

	Return True
EndFunc   ;==>_DebugFileCreateEffectVerified

Func _DebugEmptyFileEffectVerified($sPath)
	If Not FileExists($sPath) Then Return False

	Local $sAttributes = FileGetAttrib($sPath)
	If @error Or StringInStr($sAttributes, 'D', 2) Then Return False

	Local $iSize = FileGetSize($sPath)
	If @error Or $iSize <> 0 Then Return False

	Return True
EndFunc   ;==>_DebugEmptyFileEffectVerified

;===============================================================================
;
; Function Name:	_TracePrepare(), _TraceRunAndWait(), _TraceFinalize()
; Description:		Run the explicitly confirmed Application Trace, with an
;					optional native Process Monitor backing-file capture.
;
;===============================================================================
Func _TracePrepare($sTitle, $sLang)
	Local $sConfigured = IniRead($ScriptIni, 'Options', 'ProcMonPath', '')
	Local $sResolution = ''
	Local $bProcMonAvailable = _ResolveProcMonPath($sConfigured, $TraceProcMonPath, _
			$sResolution, $Root, $Lib)
	Local $iResolveError = @error

	If Not $bProcMonAvailable Then
		If Not _TraceConfirmWithoutProcMon($sTitle, $sLang, $TraceProcMonPath, $iResolveError) Then
			Return SetError(1, $iResolveError, False)
		EndIf
		$TraceProcMonState = 'not available; continued with X-Launcher-only logging'
	Else
		$TraceProcMonState = 'available; capture preparation pending'
	EndIf

	Local $sSafeAppName = _TraceSafeFolderName($AppName)
	If $sSafeAppName = '' Then $sSafeAppName = _TraceSafeFolderName($ScriptName)
	If $sSafeAppName = '' Then $sSafeAppName = 'Application'

	Local $sSessionName = @YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC & _
			'_' & @MSEC & '_' & @AutoItPID
	Local $sSessionBase = @ScriptDir & '\Diagnostics\' & $sSafeAppName & '\' & $sSessionName
	Local $sCandidate = $sSessionBase
	Local $iSuffix = 1
	While FileExists($sCandidate)
		$sCandidate = $sSessionBase & '-' & $iSuffix
		$iSuffix += 1
	WEnd

	If DirCreate($sCandidate) <> 1 Then Return SetError(2, 0, False)

	; Close an INI-enabled historical debug session before redirecting the
	; explicitly requested Trace into its unique session folder.
	If $Debug = 'true' And $DebugSessionStarted And Not $DebugSessionEnded Then
		_DebugSessionEnd('switch-to-application-trace')
	EndIf

	$TraceActive = True
	$TraceFinalized = False
	$TraceSessionDir = $sCandidate
	$TraceSummaryPath = $TraceSessionDir & '\Application_Trace_Summary.log'
	$TraceSettingsPath = $TraceSessionDir & '\X-Launcher_Settings.log'
	$TraceProcMonCapturePath = $TraceSessionDir & '\Application_Trace.pml'
	$TraceProcMonCSVPath = $TraceSessionDir & '\Application_Trace.csv'
	$TraceProcMonXMLPath = $TraceSessionDir & '\Application_Trace.xml'
	$TraceProcMonConfigPath = $TraceSessionDir & '\Application_Trace_Filter.pmc'
	$TraceResultsPath = $TraceSessionDir & '\Application_Trace_Results.log'
	$TracePortabilityReportPath = $TraceSessionDir & '\Application_Portability_Report.log'
	$TracePortabilityState = 'not attempted'
	$TraceProcMonPID = 0
	$TraceProcMonCaptureActive = False
	$TraceProcMonCaptureSaved = False
	$TraceProcMonMaxMB = 512
	$TraceProcMonReserveMB = 1024
	$TraceProcMonCaptureBytes = 0
	$TraceProcMonCaptureTimer = 0
	$TraceProcMonCaptureDurationMs = 0
	$TraceProcMonFreeStartMB = -1
	$TraceProcMonCapturePartial = False
	$TraceProcMonPartialReason = ''
	$TraceProcMonLimitStopAttempted = False
	$TraceProcMonSpaceCheckWarned = False
	$TraceProcMonDetailAvailable = True
	$TraceStartTime = _DebugSessionTimestamp()
	$TraceApplicationPID = 0
	$TraceApplicationExitCode = 'not started'
	$TraceObservedPIDs = '|'
	$TraceObservedProcesses = ''
	$TraceProcessObservation = 'not started'

	$Debug = 'true'
	$DebugFile = $TraceSessionDir & '\X-Launcher_Debug.dbg'
	$DebugSessionID = $sSessionName
	$DebugSessionStarted = False
	$DebugSessionEnded = False
	$DebugPassCount = 0
	$DebugFailCount = 0
	$DebugWarnCount = 0
	$DebugSkipCount = 0
	$DebugNotUsedCount = 0
	$WriteLog = 'true'

	If Not $ExitHandlerRegistered Then
		OnAutoItExitRegister('OnAutoItExit')
		$ExitHandlerRegistered = True
	EndIf

	_DebugSessionStart()
	_DebugWrite('[PASS] [Trace] Application Trace started (session=' & _
			$TraceSessionDir & ')')
	_DebugWrite('[INFO] [Process] Launcher PID=' & @AutoItPID & ' (command=' & $CmdLineRaw & ')')
	_TraceConfigureProcMonSafeguards()
	If $bProcMonAvailable Then
		_DebugWrite('[PASS] [Process Monitor] ProcMonPath resolved=' & $TraceProcMonPath)
		_TraceStartProcMonCapture()
	Else
		_DebugWrite('[NOT USED] [Process Monitor] ProcMonPath unavailable (resolution=' & _
				$sResolution & '; error=' & $iResolveError & ')')
		_DebugWrite('[NOT USED] [Process Monitor] Capture was not started; X-Launcher-only logging is active')
	EndIf

	If Not FileExists($DebugFile) Then Return SetError(3, 0, False)
	If IniWrite($TraceSettingsPath, 'Trace', 'SessionID', $DebugSessionID) <> 1 Then
		Return SetError(4, 0, False)
	EndIf
	Local $sTraceMode = 'X-Launcher-only'
	If $TraceProcMonCaptureActive Then $sTraceMode = 'Process Monitor capture'
	IniWrite($TraceSettingsPath, 'Trace', 'Mode', $sTraceMode)
	IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitor', $TraceProcMonState)
	IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCapture', $TraceProcMonCapturePath)
	IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorFilter', $TraceProcMonConfigPath)
	IniWrite($TraceSettingsPath, 'Trace', 'TraceResults', $TraceResultsPath)
	IniWrite($TraceSettingsPath, 'Trace', 'PortabilityReport', $TracePortabilityReportPath)
	IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysis', $TracePortabilityState)
	IniWrite($TraceSettingsPath, 'Trace', 'ProcMonMaxMB', $TraceProcMonMaxMB)
	IniWrite($TraceSettingsPath, 'Trace', 'ProcMonReserveMB', $TraceProcMonReserveMB)
	IniWrite($TraceSettingsPath, 'Trace', 'ProcMonFreeStartMB', $TraceProcMonFreeStartMB)
	If $TraceProcMonCaptureActive Then
		IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCaptureStatus', 'active')
	Else
		IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCaptureStatus', 'not active')
	EndIf

	_TraceInitialiseProcessObservation()
	Return SetError(0, 0, True)
EndFunc   ;==>_TracePrepare

Func _TraceConfirmWithoutProcMon($sTitle, $sLang, $sResolved, $iResolveError)
	Local $sMessage
	If $sLang = 'it' Then
		$sMessage = 'Process Monitor non e stato trovato.' & @CRLF & _
				'Percorso controllato: ' & $sResolved & @CRLF & _
				'Errore di risoluzione: ' & $iResolveError & @CRLF & @CRLF & _
				'Fare clic su OK per continuare con il solo registro X-Launcher.' & @CRLF & _
				'Process Monitor non verra avviato.' & @CRLF & @CRLF & _
				"Fare clic su Annulla per non avviare l'applicazione."
	Else
		$sMessage = 'Process Monitor was not found.' & @CRLF & _
				'Path checked: ' & $sResolved & @CRLF & _
				'Resolution error: ' & $iResolveError & @CRLF & @CRLF & _
				'Click OK to continue with X-Launcher-only logging.' & @CRLF & _
				'Process Monitor will not be started.' & @CRLF & @CRLF & _
				'Click Cancel to stop without launching the application.'
	EndIf
	Return MsgBox(49, $sTitle, $sMessage) = 1
EndFunc   ;==>_TraceConfirmWithoutProcMon

Func _TraceProcMonStartArguments($sCapturePath, $sConfigPath = '')
	Local $sArguments = '/Quiet /Minimized'
	If $sConfigPath <> '' Then $sArguments &= ' /LoadConfig ' & _CommandLineQuoteArgument($sConfigPath)
	Return $sArguments & ' /BackingFile ' & _CommandLineQuoteArgument($sCapturePath)
EndFunc   ;==>_TraceProcMonStartArguments

Func _TraceProcMonStopArguments()
	Return '/Terminate /Quiet'
EndFunc   ;==>_TraceProcMonStopArguments

Func _TraceProcMonAnyRunning()
	Return ProcessExists('Procmon.exe') Or ProcessExists('Procmon64.exe') Or _
			ProcessExists('Procmon64a.exe')
EndFunc   ;==>_TraceProcMonAnyRunning

Func _TraceConfigureProcMonSafeguards()
	Local $bMaxValid = True, $bReserveValid = True
	$TraceProcMonMaxMB = _TraceReadProcMonMBOption('ProcMonMaxMB', 512, 64, 102400, $bMaxValid)
	$TraceProcMonReserveMB = _TraceReadProcMonMBOption('ProcMonReserveMB', 1024, 256, 102400, $bReserveValid)

	If Not $bMaxValid Then
		_DebugWrite('[WARN] [Process Monitor] ProcMonMaxMB is invalid; using safe default 512 MB')
	EndIf
	If Not $bReserveValid Then
		_DebugWrite('[WARN] [Process Monitor] ProcMonReserveMB is invalid; using safe default 1024 MB')
	EndIf
	_DebugWrite('[INFO] [Process Monitor] Capture safeguards (maximum=' & _
			$TraceProcMonMaxMB & ' MB; reserved-free-space=' & $TraceProcMonReserveMB & ' MB)')
EndFunc   ;==>_TraceConfigureProcMonSafeguards

Func _TraceReadProcMonMBOption($sKey, $iDefault, $iMinimum, $iMaximum, ByRef $bValid)
	Local $sValue = StringStripWS(IniRead($ScriptIni, 'Options', $sKey, '__x_trace_missing__'), 3)
	$bValid = True
	If $sValue = '__x_trace_missing__' Or $sValue = '' Then Return $iDefault
	If Not StringRegExp($sValue, '^\d+$') Then
		$bValid = False
		Return $iDefault
	EndIf

	Local $iValue = Number($sValue)
	If $iValue < $iMinimum Or $iValue > $iMaximum Then
		$bValid = False
		Return $iDefault
	EndIf
	Return $iValue
EndFunc   ;==>_TraceReadProcMonMBOption

Func _TraceProcMonPreflightReason($nFreeMB, $iMaxMB, $iReserveMB)
	If $nFreeMB < ($iMaxMB + $iReserveMB) Then
		Return 'available space is below maximum capture plus reserved free space'
	EndIf
	Return ''
EndFunc   ;==>_TraceProcMonPreflightReason

Func _TraceProcMonLimitReason($iCaptureBytes, $nFreeMB, $iMaxMB, $iReserveMB)
	If $iCaptureBytes >= ($iMaxMB * 1024 * 1024) Then
		Return 'maximum PML size of ' & $iMaxMB & ' MB reached'
	EndIf
	If $nFreeMB >= 0 And $nFreeMB <= $iReserveMB Then
		Return 'reserved free-space minimum of ' & $iReserveMB & ' MB reached'
	EndIf
	Return ''
EndFunc   ;==>_TraceProcMonLimitReason

Func _TracePMCHexInt32($iValue)
	Local $sHex = Hex($iValue, 8)
	Return StringMid($sHex, 7, 2) & StringMid($sHex, 5, 2) & _
			StringMid($sHex, 3, 2) & StringMid($sHex, 1, 2)
EndFunc   ;==>_TracePMCHexInt32

Func _TracePMCHexUTF16($sValue)
	Return StringTrimLeft(String(StringToBinary($sValue & Chr(0), 2)), 2)
EndFunc   ;==>_TracePMCHexUTF16

Func _TracePMCRecord($sName, $sDataHex)
	Local $sNameHex = _TracePMCHexUTF16($sName)
	Local $iNameBytes = Int(StringLen($sNameHex) / 2)
	Local $iDataBytes = Int(StringLen($sDataHex) / 2)
	Local $iHeaderAndName = 16 + $iNameBytes
	Return _TracePMCHexInt32($iHeaderAndName + $iDataBytes) & _
			_TracePMCHexInt32(16) & _TracePMCHexInt32($iHeaderAndName) & _
			_TracePMCHexInt32($iDataBytes) & $sNameHex & $sDataHex
EndFunc   ;==>_TracePMCRecord

Func _TracePMCAddRule(ByRef $sRulesHex, ByRef $iRuleCount, $iColumn, _
		$iRelation, $sValue, $iAction = 1)
	Local $sValueHex = _TracePMCHexUTF16($sValue)
	Local $iValueBytes = Int(StringLen($sValueHex) / 2)
	$sRulesHex &= _TracePMCHexInt32($iColumn) & _TracePMCHexInt32($iRelation) & _
			Hex($iAction, 2) & _TracePMCHexInt32($iValueBytes) & $sValueHex & _
			_TracePMCHexInt32(0) & _TracePMCHexInt32(0)
	$iRuleCount += 1
EndFunc   ;==>_TracePMCAddRule

Func _TraceWriteProcMonPortabilityConfig($sPath, $sRootPath)
	$sRootPath = StringRegExpReplace(_NormalPath($sRootPath), '[\\]+$', '')
	If $sPath = '' Or $sRootPath = '' Then Return SetError(1, 0, False)

	; ProcMon has no command-line syntax for constructing filters. Build its
	; supported LoadConfig input per session so the user's saved ProcMon setup
	; is not required. DestructiveFilter is ProcMon's "Drop Filtered Events"
	; option: excluded reads and unrelated activity never fill the backing PML.
	Local $sRulesHex = '', $iRuleCount = 0
	; ProcMon combines Include filters from different columns restrictively. Keep
	; every Include on its Category column so Write, Write Metadata and Process
	; remain alternatives. The report performs Root, INI and process-tree
	; attribution after export. This also retains writes from external child
	; executables whose image and command line are outside the portable Root.
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40082, 0, 'Network', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40082, 0, 'Profiling', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'Thread Create', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'Thread Exit', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'Process Profiling', 0)
	; These metadata operations duplicate a target already exposed by its create,
	; write, rename or delete operation and can dominate browser-style workloads.
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'RegSetInfoKey', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'RegFlushKey', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'RegSetKeySecurity', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetEndOfFileInformationFile', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetAllocationInformationFile', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetBasicInformationFile', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'FlushBuffersFile', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetStorageReservedIdInformation', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetSecurityFile', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetEAFile', 0)
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40055, 0, 'SetInformationFile', 0)
	; Windows BAM is execution-history bookkeeping, not application settings.
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40071, 4, _
			'HKLM\System\CurrentControlSet\Services\bam\State\UserSettings', 0)

	; Category column identifier. Same-column Include values are alternatives.
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40086, 0, 'Write')
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40086, 0, 'Write Metadata')
	_TracePMCAddRule($sRulesHex, $iRuleCount, 40086, 0, 'Process')

	Local $sConfigHex = ''
	$sConfigHex &= _TracePMCRecord('AdvancedMode', _TracePMCHexInt32(0))
	$sConfigHex &= _TracePMCRecord('Autoscroll', _TracePMCHexInt32(0))
	$sConfigHex &= _TracePMCRecord('Profiling', _TracePMCHexInt32(0))
	$sConfigHex &= _TracePMCRecord('DestructiveFilter', _TracePMCHexInt32(1))
	$sConfigHex &= _TracePMCRecord('FilterRules', '01' & _
			_TracePMCHexInt32($iRuleCount) & $sRulesHex)
	$sConfigHex &= _TracePMCRecord('HighlightRules', '01' & _TracePMCHexInt32(0))

	Local $hFile = FileOpen($sPath, 2 + 16)
	If $hFile = -1 Then Return SetError(2, 0, False)
	Local $vWrite = FileWrite($hFile, Binary('0x' & $sConfigHex))
	Local $iWriteError = @error
	FileClose($hFile)
	If $vWrite = 0 Or $iWriteError Or FileGetSize($sPath) < 512 Then _
			Return SetError(3, $iWriteError, False)
	Return SetError(0, $iRuleCount, True)
EndFunc   ;==>_TraceWriteProcMonPortabilityConfig

Func _TraceStartProcMonCapture()
	If $TraceProcMonPath = '' Or Not FileExists($TraceProcMonPath) Then
		$TraceProcMonState = 'not available; continued with X-Launcher-only logging'
		Return SetError(1, 0, False)
	EndIf

	; /Terminate controls every ProcMon instance. Never start a managed capture
	; when an existing user session could later be stopped accidentally.
	If _TraceProcMonAnyRunning() Then
		$TraceProcMonState = 'available; existing Process Monitor session detected; capture not started'
		_DebugWrite('[WARN] [Process Monitor] Existing ProcMon session detected; ' & _
				'X-Launcher will not control or terminate it')
		Return SetError(2, 0, False)
	EndIf

	Local $nFreeMB = DriveSpaceFree($TraceSessionDir)
	Local $iFreeError = @error
	If $iFreeError Then
		$TraceProcMonState = 'available; capture storage could not be measured; capture not started'
		_DebugWrite('[WARN] [Process Monitor] Capture was not started because available storage ' & _
				'could not be measured (error=' & $iFreeError & ')')
		Return SetError(5, $iFreeError, False)
	EndIf
	$TraceProcMonFreeStartMB = Round($nFreeMB, 1)
	Local $sPreflightReason = _TraceProcMonPreflightReason($nFreeMB, _
			$TraceProcMonMaxMB, $TraceProcMonReserveMB)
	If $sPreflightReason <> '' Then
		$TraceProcMonState = 'available; capture storage safeguard blocked startup; capture not started'
		_DebugWrite('[WARN] [Process Monitor] Capture storage preflight blocked startup (' & _
				'reason=' & $sPreflightReason & '; free=' & Round($nFreeMB, 1) & _
				' MB; required=' & ($TraceProcMonMaxMB + $TraceProcMonReserveMB) & ' MB)')
		Return SetError(6, 0, False)
	EndIf
	_DebugWrite('[PASS] [Process Monitor] Capture storage preflight passed (free=' & _
			Round($nFreeMB, 1) & ' MB; maximum=' & $TraceProcMonMaxMB & _
			' MB; reserve=' & $TraceProcMonReserveMB & ' MB)')

	If FileExists($TraceProcMonConfigPath) Then FileDelete($TraceProcMonConfigPath)
	Local $bConfigWritten = _TraceWriteProcMonPortabilityConfig($TraceProcMonConfigPath, $Root)
	Local $iConfigError = @error
	Local $iConfigRules = @extended
	If Not $bConfigWritten Then
		$TraceProcMonState = 'available; write-focused capture filter could not be created; capture not started'
		_DebugWrite('[WARN] [Process Monitor] Capture was not started because the ' & _
				'write-focused filter could not be created (error=' & $iConfigError & ')')
		Return SetError(7, $iConfigError, False)
	EndIf
	_DebugWrite('[PASS] [Process Monitor] Automatic write-focused filter created ' & _
			'(rules=' & $iConfigRules & '; drop-filtered-events=True; file=' & _
			$TraceProcMonConfigPath & ')')

	If FileExists($TraceProcMonCapturePath) Then FileDelete($TraceProcMonCapturePath)
	Local $sArguments = _TraceProcMonStartArguments($TraceProcMonCapturePath, _
			$TraceProcMonConfigPath)
	Local $vLaunchResult = ShellExecute($TraceProcMonPath, $sArguments, _
			_FileInfo($TraceProcMonPath, 0), 'runas', @SW_MINIMIZE)
	Local $iLaunchError = @error
	Local $iLaunchExtended = @extended
	If $iLaunchError Or $vLaunchResult <= 0 Then
		$TraceProcMonState = 'available; capture launch failed; continued with X-Launcher-only logging'
		_DebugWrite('[WARN] [Process Monitor] Capture could not be started (result=' & _
				$vLaunchResult & '; error=' & $iLaunchError & '; extended=' & $iLaunchExtended & ')')
		Return SetError(3, $iLaunchExtended, False)
	EndIf

	$TraceProcMonPID = $vLaunchResult
	$TraceProcMonCaptureActive = True
	_DebugWrite('[INFO] [Process Monitor] Capture launch accepted (pid=' & _
			$TraceProcMonPID & '); waiting up to 60 seconds for the native PML backing file')
	Local $hReadyTimer = TimerInit()
	Do
		If FileExists($TraceProcMonCapturePath) Then
			Local $iCaptureSize = FileGetSize($TraceProcMonCapturePath)
			If @error = 0 And $iCaptureSize > 0 Then
				$TraceProcMonCaptureBytes = $iCaptureSize
				$TraceProcMonCaptureTimer = TimerInit()
				$TraceProcMonState = 'capture active; automatic write-focused drop filter; native PML backing file=' & $TraceProcMonCapturePath
				_DebugWrite('[PASS] [Process Monitor] Capture started (pid=' & $TraceProcMonPID & _
						'; backing=' & $TraceProcMonCapturePath & ')')
				Return SetError(0, 0, True)
			EndIf
		EndIf

		Sleep(250)
	Until TimerDiff($hReadyTimer) >= 60000

	; A launched but unconfirmed instance belongs to this Trace because the
	; pre-existing-process guard passed. Stop it before running the application.
	Local $vStopResult = ShellExecuteWait($TraceProcMonPath, _TraceProcMonStopArguments(), _
			_FileInfo($TraceProcMonPath, 0), 'runas', @SW_HIDE)
	Local $iStopError = @error
	Local $hAbortTimer = TimerInit()
	While _TraceProcMonAnyRunning() And TimerDiff($hAbortTimer) < 15000
		Sleep(250)
	WEnd
	$TraceProcMonCaptureActive = _TraceProcMonAnyRunning()
	$TraceProcMonState = 'available; capture readiness was not confirmed; continued with X-Launcher-only logging'
	_DebugWrite('[WARN] [Process Monitor] Capture readiness was not confirmed; ' & _
			'terminate result=' & $vStopResult & '; error=' & $iStopError & _
			'; running=' & $TraceProcMonCaptureActive)
	Return SetError(4, $iStopError, False)
EndFunc   ;==>_TraceStartProcMonCapture

Func _TraceStopProcMonCapture($sPartialReason = '')
	If Not $TraceProcMonCaptureActive Then Return True
	If $sPartialReason <> '' Then
		$TraceProcMonCapturePartial = True
		$TraceProcMonPartialReason = $sPartialReason
	EndIf

	Local $vStopResult = ShellExecuteWait($TraceProcMonPath, _TraceProcMonStopArguments(), _
			_FileInfo($TraceProcMonPath, 0), 'runas', @SW_HIDE)
	Local $iStopError = @error
	Local $iStopExtended = @extended
	Local $hStopTimer = TimerInit()
	While _TraceProcMonAnyRunning() And TimerDiff($hStopTimer) < 15000
		Sleep(250)
	WEnd

	$TraceProcMonCaptureActive = _TraceProcMonAnyRunning()
	Local $iCaptureSize = 0
	If FileExists($TraceProcMonCapturePath) Then $iCaptureSize = FileGetSize($TraceProcMonCapturePath)
	$TraceProcMonCaptureBytes = $iCaptureSize
	If $TraceProcMonCaptureTimer <> 0 Then
		$TraceProcMonCaptureDurationMs = TimerDiff($TraceProcMonCaptureTimer)
	EndIf

	If Not $TraceProcMonCaptureActive And $iStopError = 0 And $iCaptureSize > 0 Then
		$TraceProcMonCaptureSaved = True
		If $TraceProcMonCapturePartial Then
			$TraceProcMonState = 'partial capture saved; reason=' & $TraceProcMonPartialReason & _
					'; automatic write-focused drop filter; native PML=' & $TraceProcMonCapturePath
		Else
			$TraceProcMonState = 'capture saved; automatic write-focused drop filter; native PML=' & $TraceProcMonCapturePath
		EndIf
		_DebugWrite('[PASS] [Process Monitor] Capture stopped and saved (result=' & _
				$vStopResult & '; bytes=' & $iCaptureSize & '; partial=' & _
				$TraceProcMonCapturePartial & '; file=' & $TraceProcMonCapturePath & ')')
		If FileExists($TraceSettingsPath) Then
			IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitor', $TraceProcMonState)
			If $TraceProcMonCapturePartial Then
				IniWrite($TraceSettingsPath, 'Trace', 'Mode', 'Process Monitor partial capture')
				IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCaptureStatus', 'partial')
				IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorPartialReason', $TraceProcMonPartialReason)
			Else
				IniWrite($TraceSettingsPath, 'Trace', 'Mode', 'Process Monitor capture')
				IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCaptureStatus', 'complete')
			EndIf
			IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCaptureBytes', $TraceProcMonCaptureBytes)
			IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitorCaptureSeconds', _
					Round($TraceProcMonCaptureDurationMs / 1000, 2))
		EndIf
		Return SetError(0, $iCaptureSize, True)
	EndIf

	$TraceProcMonCaptureSaved = False
	$TraceProcMonState = 'capture stop or preservation could not be confirmed; review Process Monitor manually'
	_DebugWrite('[WARN] [Process Monitor] Capture stop/preservation was not confirmed (result=' & _
			$vStopResult & '; error=' & $iStopError & '; extended=' & $iStopExtended & _
			'; running=' & $TraceProcMonCaptureActive & '; bytes=' & $iCaptureSize & ')')
	If FileExists($TraceSettingsPath) Then IniWrite($TraceSettingsPath, 'Trace', 'ProcessMonitor', $TraceProcMonState)
	Return SetError(1, $iStopError, False)
EndFunc   ;==>_TraceStopProcMonCapture

Func _TraceProcMonExportArguments($sPMLPath, $sExportPath, $sConfigPath = '')
	Local $sArguments = '/NoConnect /Quiet /OpenLog ' & _CommandLineQuoteArgument($sPMLPath)
	If $sConfigPath <> '' Then $sArguments &= ' /LoadConfig ' & _CommandLineQuoteArgument($sConfigPath) & _
			' /SaveApplyFilter'
	Return $sArguments & ' /SaveAs ' & _CommandLineQuoteArgument($sExportPath)
EndFunc   ;==>_TraceProcMonExportArguments

Func _TraceCreatePortabilityReport()
	If $TracePortabilityReportPath = '' Then Return SetError(1, 0, False)
	Local $hTotalTimer = TimerInit()

	If Not $TraceProcMonCaptureSaved Or Not FileExists($TraceProcMonCapturePath) Then
		$TracePortabilityState = 'not available; native Process Monitor capture was not saved'
		_TraceWritePortabilityUnavailableReport($TracePortabilityState)
		_DebugWrite('[NOT USED] [Portability] Native application-write analysis was not available')
		If FileExists($TraceSettingsPath) Then
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysis', $TracePortabilityState)
		EndIf
		Return SetError(2, 0, False)
	EndIf

	If FileExists($TraceProcMonXMLPath) Then FileDelete($TraceProcMonXMLPath)
	If FileExists($TraceProcMonCSVPath) Then FileDelete($TraceProcMonCSVPath)
	_TracePortabilityProgress('Exporting the filtered Process Monitor capture...')
	Local $hExportTimer = TimerInit()
	Local $sArguments = _TraceProcMonExportArguments($TraceProcMonCapturePath, _
			$TraceProcMonXMLPath, $TraceProcMonConfigPath)
	Local $vExportResult = ShellExecuteWait($TraceProcMonPath, $sArguments, _
			_FileInfo($TraceProcMonPath, 0), 'runas', @SW_HIDE)
	Local $iExportError = @error
	Local $iExportExtended = @extended
	Local $iXMLSize = 0
	If FileExists($TraceProcMonXMLPath) Then $iXMLSize = FileGetSize($TraceProcMonXMLPath)

	If $iExportError Or $vExportResult <> 0 Or $iXMLSize <= 0 Then
		$TracePortabilityState = 'not available; Process Monitor XML export failed'
		_TraceWritePortabilityUnavailableReport($TracePortabilityState & _
				' (result=' & $vExportResult & '; error=' & $iExportError & _
				'; extended=' & $iExportExtended & ')')
		_DebugWrite('[WARN] [Portability] Process Monitor XML export failed (result=' & _
				$vExportResult & '; error=' & $iExportError & '; extended=' & _
				$iExportExtended & '; bytes=' & $iXMLSize & ')')
		If FileExists($TraceSettingsPath) Then
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysis', $TracePortabilityState)
		EndIf
		Return SetError(3, $iExportError, False)
	EndIf
	Local $nExportSeconds = Round(TimerDiff($hExportTimer) / 1000, 2)
	_DebugWrite('[PASS] [Portability] XML export completed (seconds=' & _
			$nExportSeconds & '; bytes=' & $iXMLSize & ')')
	If FileExists($TraceSettingsPath) Then _
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityExportSeconds', $nExportSeconds)

	_TracePortabilityProgress('Converting the captured events...')
	Local $hConvertTimer = TimerInit()
	If Not _TraceConvertProcMonXMLToCSV($TraceProcMonXMLPath, $TraceProcMonCSVPath) Then
		Local $iConvertError = @error
		$TracePortabilityState = 'not available; Process Monitor XML data could not be converted'
		_TraceWritePortabilityUnavailableReport($TracePortabilityState & _
				' (converter error=' & $iConvertError & ')')
		_DebugWrite('[WARN] [Portability] Process Monitor XML data could not be converted ' & _
				'(error=' & $iConvertError & '; XML retained=' & $TraceProcMonXMLPath & ')')
		If FileExists($TraceSettingsPath) Then
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysis', $TracePortabilityState)
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityXML', $TraceProcMonXMLPath)
		EndIf
		Return SetError(4, $iConvertError, False)
	EndIf
	Local $nConvertSeconds = Round(TimerDiff($hConvertTimer) / 1000, 2)
	_DebugWrite('[PASS] [Portability] XML conversion completed (seconds=' & _
			$nConvertSeconds & '; CSV-bytes=' & FileGetSize($TraceProcMonCSVPath) & ')')
	If FileExists($TraceSettingsPath) Then _
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityConvertSeconds', $nConvertSeconds)
	; The XML is no longer needed once its fixed event fields have been converted
	; to the canonical private CSV consumed by the established report builder.
	FileDelete($TraceProcMonXMLPath)

	_TracePortabilityProgress('Classifying application writes and current INI coverage...')
	Local $hAnalysisTimer = TimerInit()
	Local $sSimpleDebugContent = ''
	If FileExists($DebugFile) Then $sSimpleDebugContent = FileRead($DebugFile)
	Local $bBuilt = _TraceBuildPortabilityReportFromCSV($TraceProcMonCSVPath, _
			$TracePortabilityReportPath, $ScriptIni, $TraceApplicationPID, _
			$TraceObservedPIDs, @AutoItPID, $Root, $TraceObservedProcesses, _
			$TraceResultsPath, $sSimpleDebugContent, $DebugFailCount)
	Local $iBuildError = @error
	Local $iUnmanagedTargets = @extended
	If Not $bBuilt Then
		$TracePortabilityState = 'not available; exported Process Monitor data could not be analysed'
		_TraceWritePortabilityUnavailableReport($TracePortabilityState & _
				' (parser error=' & $iBuildError & ')')
		_DebugWrite('[WARN] [Portability] Exported Process Monitor data could not be analysed ' & _
				'(error=' & $iBuildError & '; CSV retained=' & $TraceProcMonCSVPath & ')')
		If FileExists($TraceSettingsPath) Then
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysis', $TracePortabilityState)
			IniWrite($TraceSettingsPath, 'Trace', 'PortabilityCSV', $TraceProcMonCSVPath)
		EndIf
		Return SetError(5, $iBuildError, False)
	EndIf
	Local $nAnalysisSeconds = Round(TimerDiff($hAnalysisTimer) / 1000, 2)
	Local $nTotalSeconds = Round(TimerDiff($hTotalTimer) / 1000, 2)
	_DebugWrite('[PASS] [Portability] Target classification completed (seconds=' & _
			$nAnalysisSeconds & '; total-seconds=' & $nTotalSeconds & ')')
	If FileExists($TraceResultsPath) Then
		_DebugWrite('[PASS] [Portability] Plain-language Trace results created=' & _
				$TraceResultsPath)
	Else
		_DebugWrite('[WARN] [Portability] Plain-language Trace results could not be created=' & _
				$TraceResultsPath)
	EndIf

	$TracePortabilityState = 'complete; readable application-write report created; ' & _
			'unmanaged targets=' & $iUnmanagedTargets
	If $iUnmanagedTargets > 0 Then
		_DebugWrite('[WARN] [Portability] Readable portability report created; ' & _
				'unmanaged targets require review=' & $iUnmanagedTargets & '; report=' & _
				$TracePortabilityReportPath)
	Else
		_DebugWrite('[PASS] [Portability] Readable portability report created=' & _
				$TracePortabilityReportPath)
	EndIf
	If FileExists($TraceSettingsPath) Then
		IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysis', $TracePortabilityState)
		IniWrite($TraceSettingsPath, 'Trace', 'TraceResults', $TraceResultsPath)
		IniWrite($TraceSettingsPath, 'Trace', 'PortabilityReport', $TracePortabilityReportPath)
		IniWrite($TraceSettingsPath, 'Trace', 'PortabilityAnalysisSeconds', $nAnalysisSeconds)
		IniWrite($TraceSettingsPath, 'Trace', 'PortabilityTotalSeconds', $nTotalSeconds)
	EndIf
	; The canonical CSV is an intermediate duplicate of the preserved PML. Remove
	; it after successful analysis to reduce private diagnostic data and session size.
	FileDelete($TraceProcMonCSVPath)
	; The per-session ProcMon filter contains the portable Root path. It is no
	; longer needed after successful export and analysis.
	FileDelete($TraceProcMonConfigPath)
	_TracePortabilityProgress('Application Trace reports completed.', True)
	Return SetError(0, 0, True)
EndFunc   ;==>_TraceCreatePortabilityReport

Func _TracePortabilityProgress($sMessage, $bComplete = False)
	Local $iSeconds = 30
	If $bComplete Then $iSeconds = 5
	TraySetState()
	TrayTip($AppName & ' Application Trace', $sMessage, $iSeconds, 1)
	_DebugWrite('[INFO] [Portability Progress] ' & $sMessage)
EndFunc   ;==>_TracePortabilityProgress

Func _TraceWritePortabilityUnavailableReport($sReason)
	Local $sReport = 'X-LAUNCHER APPLICATION PORTABILITY REPORT' & @CRLF & _
			'=========================================' & @CRLF & @CRLF & _
			'ANALYSIS STATUS=NOT AVAILABLE' & @CRLF & _
			'Reason=' & $sReason & @CRLF & @CRLF & _
			'Application=' & $AppName & ' ' & $AppVer & @CRLF & _
			'INI=' & $ScriptIni & @CRLF & _
			'Root=' & $Root & @CRLF & _
			'Application PID=' & $TraceApplicationPID & @CRLF & @CRLF & _
			'A native Process Monitor capture is required to distinguish application ' & _
			'writes from X-Launcher actions.' & @CRLF & _
			'Use Application_Trace_Summary.log for X-Launcher-owned diagnostic results.' & _
			@CRLF & @CRLF & _
			'Privacy=Diagnostic files can contain usernames, paths, command lines, ' & _
			'document names and registry data. Review them before sharing.' & @CRLF
	Local $bAdvancedWritten = _TraceWriteUTF8File($TracePortabilityReportPath, $sReport)
	Local $sSimpleDebugContent = ''
	If FileExists($DebugFile) Then $sSimpleDebugContent = FileRead($DebugFile)
	_TraceWriteSimplePortabilityUnavailableReport($TraceResultsPath, $sReason, _
			$TracePortabilityReportPath, $TraceSummaryPath, $sSimpleDebugContent, _
			$DebugFailCount)
	Return $bAdvancedWritten
EndFunc   ;==>_TraceWritePortabilityUnavailableReport

Func _TraceConvertProcMonXMLToCSV($sXMLPath, $sCSVPath)
	Local $hXML = FileOpen($sXMLPath, 0)
	If $hXML = -1 Then Return SetError(1, 0, False)
	Local $hCSV = FileOpen($sCSVPath, 2 + 128)
	If $hCSV = -1 Then
		FileClose($hXML)
		Return SetError(2, 0, False)
	EndIf

	FileWriteLine($hCSV, '"Process Name","PID","Operation","Path","Result","Detail"')
	Local $aProcesses[2048][4], $iMaximumProcessIndex = -1
	Local $sLine, $sProcessBlock = '', $sEvent = ''
	Local $bInProcess = False, $bInEvent = False, $bProcessRowsWritten = False
	Local $iEventCount = 0, $iSourceEventCount = 0
	Local $iProcessIndex, $i, $sProcessIndex, $sParentPID, $sCommandLine
	Local $sProcess, $sPID, $sOperation, $sPath, $sResult, $sDetail
	$TraceProcMonDetailAvailable = False
	While True
		$sLine = FileReadLine($hXML)
		If @error Then ExitLoop

		If Not $bInEvent And Not $bInProcess And _
				StringInStr($sLine, '<process>', 1) > 0 Then
			$bInProcess = True
			$sProcessBlock = $sLine & @LF
		ElseIf $bInProcess Then
			$sProcessBlock &= $sLine & @LF
		EndIf
		If $bInProcess And StringInStr($sLine, '</process>', 1) > 0 Then
			$bInProcess = False
			$sProcessIndex = _TraceXMLReadElement($sProcessBlock, 'ProcessIndex')
			$iProcessIndex = Number($sProcessIndex)
			$sPID = _TraceXMLReadElement($sProcessBlock, 'ProcessId')
			$sParentPID = _TraceXMLReadElement($sProcessBlock, 'ParentProcessId')
			$sProcess = _TraceXMLReadElement($sProcessBlock, 'ProcessName')
			$sCommandLine = _TraceXMLReadElement($sProcessBlock, 'CommandLine')
			$sProcessBlock = ''
			If Not StringIsDigit($sProcessIndex) Or $iProcessIndex > 1048576 Or _
					Not StringIsDigit($sPID) Then ContinueLoop
			If $iProcessIndex >= UBound($aProcesses) Then _
					ReDim $aProcesses[$iProcessIndex + 256][4]
			$aProcesses[$iProcessIndex][0] = $sPID
			$aProcesses[$iProcessIndex][1] = $sParentPID
			$aProcesses[$iProcessIndex][2] = $sProcess
			$aProcesses[$iProcessIndex][3] = $sCommandLine
			If $iProcessIndex > $iMaximumProcessIndex Then _
					$iMaximumProcessIndex = $iProcessIndex
			ContinueLoop
		EndIf
		If $bInProcess Then ContinueLoop

		If Not $bInEvent Then
			If StringInStr($sLine, '<event>', 1) = 0 Then ContinueLoop
			If Not $bProcessRowsWritten Then
				For $i = 0 To $iMaximumProcessIndex
					If $aProcesses[$i][0] = '' Then ContinueLoop
					$sDetail = 'Parent PID: ' & $aProcesses[$i][1] & _
							', Command line: ' & $aProcesses[$i][3]
					FileWriteLine($hCSV, _TraceCSVQuote($aProcesses[$i][2]) & ',' & _
							_TraceCSVQuote($aProcesses[$i][0]) & ',' & _
							_TraceCSVQuote('Process Start') & ',' & _TraceCSVQuote('') & ',' & _
							_TraceCSVQuote('SUCCESS') & ',' & _TraceCSVQuote($sDetail))
				Next
				$bProcessRowsWritten = True
			EndIf
			$bInEvent = True
			$sEvent = $sLine & @LF
		Else
			$sEvent &= $sLine & @LF
		EndIf
		If StringInStr($sLine, '</event>', 1) = 0 Then ContinueLoop

		$bInEvent = False
		$iSourceEventCount += 1
		$sOperation = _TraceXMLReadElement($sEvent, 'Operation')
		; The capture deliberately retains Process category events so the fixed XML
		; process list is complete. They do not describe portable targets. Reject
		; them and low-value metadata before extracting the remaining event fields.
		If Not _TraceOperationMayReport($sOperation) Then
			$sEvent = ''
			ContinueLoop
		EndIf
		$sProcessIndex = _TraceXMLReadElement($sEvent, 'ProcessIndex')
		$iProcessIndex = Number($sProcessIndex)
		$sPID = ''
		$sProcess = ''
		If StringIsDigit($sProcessIndex) And $iProcessIndex < UBound($aProcesses) Then
			$sPID = $aProcesses[$iProcessIndex][0]
			$sProcess = $aProcesses[$iProcessIndex][2]
		EndIf
		If $sProcess = '' Then $sProcess = _TraceXMLReadElement($sEvent, 'Process_Name')
		$sPath = _TraceXMLReadElement($sEvent, 'Path')
		$sResult = _TraceXMLReadElement($sEvent, 'Result')
		$sDetail = _TraceXMLReadElement($sEvent, 'Detail')
		If StringInStr($sEvent, '<Detail>', 1) > 0 Then _
				$TraceProcMonDetailAvailable = True
		$sEvent = ''
		If $sProcess = '' Or Not StringIsDigit($sPID) Or $sOperation = '' Then ContinueLoop
		FileWriteLine($hCSV, _TraceCSVQuote($sProcess) & ',' & _TraceCSVQuote($sPID) & _
				',' & _TraceCSVQuote($sOperation) & ',' & _TraceCSVQuote($sPath) & ',' & _
				_TraceCSVQuote($sResult) & ',' & _TraceCSVQuote($sDetail))
		If @error Then
			FileClose($hXML)
			FileClose($hCSV)
			Return SetError(3, 0, False)
		EndIf
		$iEventCount += 1
	WEnd
	FileClose($hXML)
	FileClose($hCSV)
	If $bInProcess Or $bInEvent Or $iSourceEventCount = 0 Then _
		Return SetError(4, $iSourceEventCount, False)
	Return SetError(0, $iEventCount, True)
EndFunc   ;==>_TraceConvertProcMonXMLToCSV

Func _TraceXMLReadElement($sBlock, $sName)
	; ProcMon uses exact fixed element names. Direct bounds lookup avoids compiling
	; and executing a regular expression several times for every captured event.
	Local $sOpen = '<' & $sName & '>', $sClose = '</' & $sName & '>'
	Local $iStart = StringInStr($sBlock, $sOpen, 1)
	If $iStart = 0 Then Return ''
	$iStart += StringLen($sOpen)
	Local $iEnd = StringInStr($sBlock, $sClose, 1, 1, $iStart)
	If $iEnd = 0 Or $iEnd < $iStart Then Return ''
	Return _TraceXMLDecode(StringStripWS(StringMid($sBlock, $iStart, _
			$iEnd - $iStart), 3))
EndFunc   ;==>_TraceXMLReadElement

Func _TraceXMLDecode($sValue)
	$sValue = StringReplace($sValue, '&lt;', '<', 0, 1)
	$sValue = StringReplace($sValue, '&gt;', '>', 0, 1)
	$sValue = StringReplace($sValue, '&quot;', '"', 0, 1)
	$sValue = StringReplace($sValue, '&apos;', "'", 0, 1)
	Return StringReplace($sValue, '&amp;', '&', 0, 1)
EndFunc   ;==>_TraceXMLDecode

Func _TraceCSVQuote($sValue)
	Return '"' & StringReplace($sValue, '"', '""') & '"'
EndFunc   ;==>_TraceCSVQuote

Func _TraceBuildPortabilityReportFromCSV($sCSVPath, $sReportPath, $sIni, _
		$iApplicationPID, $sObservedPIDs, $iLauncherPID, $sRootPath, _
		$sObservedProcesses = '', $sSimpleReportPath = '', _
		$sSimpleDebugContent = '', $iSimpleFailureCount = 0)
	Local $iProcess = -1, $iPID = -1, $iOperation = -1, $iPath = -1
	Local $iResult = -1, $iDetail = -1
	If Not _TraceCSVReadHeader($sCSVPath, $iProcess, $iPID, $iOperation, _
			$iPath, $iResult, $iDetail) Then Return SetError(1, 0, False)

	Local $aRelations[64][4], $iRelationCount = 0
	If Not _TraceCSVCollectProcessRelations($sCSVPath, $iProcess, $iPID, _
			$iOperation, $iPath, $iDetail, $aRelations, $iRelationCount, True) Then
		Return SetError(2, 0, False)
	EndIf

	Local $sApplicationPIDs = '|', $sLauncherPIDs = '|'
	_TracePIDAdd($sApplicationPIDs, $iApplicationPID)
	_TracePIDMerge($sApplicationPIDs, $sObservedPIDs)
	_TracePIDAdd($sLauncherPIDs, $iLauncherPID)
	_TracePIDResolveDescendants($sApplicationPIDs, $aRelations, $iRelationCount)
	_TracePIDResolveDescendants($sLauncherPIDs, $aRelations, $iRelationCount)

	Local $aFileCoverage[64][3], $iFileCoverageCount = 0
	Local $aRegCoverage[32][2], $iRegCoverageCount = 0
	_TraceBuildCoverageMap($sIni, $aFileCoverage, $iFileCoverageCount, _
			$aRegCoverage, $iRegCoverageCount)

	Local $aRecords[128][10], $iRecordCount = 0
	Local $aErrors[32][10], $iErrorCount = 0
	Local $oRecordIndex = ObjCreate('Scripting.Dictionary')
	Local $oErrorIndex = ObjCreate('Scripting.Dictionary')
	Local $hCSV = FileOpen($sCSVPath, 0)
	If $hCSV = -1 Then Return SetError(3, 0, False)
	FileReadLine($hCSV)
	Local $sLine, $aFields[1], $sActor, $sEventType, $sCoverage, $sClass
	Local $sProcess, $sOperation, $sPath, $sResult, $sDetail, $iEventPID
	While True
		$sLine = FileReadLine($hCSV)
		If @error Then ExitLoop
		If Not _TraceCSVParseLine($sLine, $aFields) Then ContinueLoop
		If UBound($aFields) <= $iProcess Or UBound($aFields) <= $iPID Or _
				UBound($aFields) <= $iOperation Or UBound($aFields) <= $iPath Or _
				UBound($aFields) <= $iResult Then ContinueLoop

		$iEventPID = Number($aFields[$iPID])
		$sActor = ''
		If _TracePIDContains($sApplicationPIDs, $iEventPID) Then
			$sActor = 'APPLICATION'
		ElseIf _TracePIDContains($sLauncherPIDs, $iEventPID) Then
			$sActor = 'X-LAUNCHER'
		EndIf
		If $sActor = '' Then ContinueLoop

		$sProcess = $aFields[$iProcess]
		$sOperation = $aFields[$iOperation]
		$sPath = $aFields[$iPath]
		$sResult = $aFields[$iResult]
		$sDetail = ''
		If $iDetail >= 0 And UBound($aFields) > $iDetail Then $sDetail = $aFields[$iDetail]
		If $sPath = '' Then ContinueLoop

		If _TraceResultNeedsReview($sResult) Then
			$sEventType = _TraceEventType($sOperation, $sDetail)
			; Read-only discovery failures such as ordinary NAME NOT FOUND probes
			; are common application behaviour. Report only failed operations that
			; were attempting a write-like action.
			If $sEventType = '' Then ContinueLoop
			_TraceRecordAddIndexed($aErrors, $iErrorCount, $oErrorIndex, _
					$sActor, $sEventType, $sPath, _
					'RELEVANT ERROR', $sOperation, $sProcess, $sResult)
			ContinueLoop
		EndIf
		If StringUpper($sResult) <> 'SUCCESS' Then ContinueLoop

		$sEventType = _TraceEventType($sOperation, $sDetail)
		If $sEventType = '' Then ContinueLoop
		$sCoverage = ''
		If $sActor = 'X-LAUNCHER' Then
			$sClass = 'X-LAUNCHER ACTION'
			$sCoverage = 'Performed by the launcher or its helper process'
		ElseIf $sEventType <> 'REGISTRY' And _TraceIsNTFSVolumeMetadataPath($sPath) Then
			$sClass = 'SYSTEM METADATA'
			$sCoverage = 'Windows-managed NTFS volume metadata; not an application portability target'
		ElseIf $sEventType = 'REGISTRY' Then
			If _TraceRegistryCoverageMatch($sPath, $aRegCoverage, _
					$iRegCoverageCount, $sCoverage) Then
				$sClass = 'MANAGED'
			Else
				$sClass = 'UNMANAGED'
				$sCoverage = 'No matching portable registry root was found in the current INI'
			EndIf
		ElseIf _TracePathWithin($sPath, $sRootPath) Then
			$sClass = 'CONTAINED'
			If Not _TraceFileCoverageMatch($sPath, $aFileCoverage, _
					$iFileCoverageCount, $sCoverage) Then _
					$sCoverage = '[FileSystem] Root (' & _TraceCanonicalPath($sRootPath) & ')'
		ElseIf _TraceFileCoverageMatch($sPath, $aFileCoverage, _
				$iFileCoverageCount, $sCoverage) Then
			$sClass = 'MANAGED'
		ElseIf _TraceIsWindowsSystemFilePath($sPath) Then
			$sClass = 'SYSTEM CHANGE'
			$sCoverage = 'Windows-owned file or folder; normally not portable application data'
		Else
			$sClass = 'UNMANAGED'
			$sCoverage = 'Outside Root with no matching current INI path handling'
		EndIf

		_TraceRecordAddIndexed($aRecords, $iRecordCount, $oRecordIndex, _
				$sActor, $sEventType, $sPath, _
				$sClass, $sOperation, $sProcess, $sCoverage)

		If StringLower($sOperation) = 'setrenameinformationfile' Or _
				StringLower($sOperation) = 'setrenameinformationex' Then
			Local $sRenameTarget = _TraceDetailValue($sDetail, 'NewName')
			If $sRenameTarget <> '' And $sRenameTarget <> $sPath Then
				Local $sRenameClass, $sRenameCoverage = ''
				If $sActor = 'X-LAUNCHER' Then
					$sRenameClass = 'X-LAUNCHER ACTION'
					$sRenameCoverage = 'Performed by the launcher or its helper process'
				ElseIf _TraceIsNTFSVolumeMetadataPath($sRenameTarget) Then
					$sRenameClass = 'SYSTEM METADATA'
					$sRenameCoverage = 'Windows-managed NTFS volume metadata; not an application portability target'
				ElseIf _TracePathWithin($sRenameTarget, $sRootPath) Then
					$sRenameClass = 'CONTAINED'
					If Not _TraceFileCoverageMatch($sRenameTarget, $aFileCoverage, _
							$iFileCoverageCount, $sRenameCoverage) Then _
							$sRenameCoverage = '[FileSystem] Root (' & _TraceCanonicalPath($sRootPath) & ')'
				ElseIf _TraceFileCoverageMatch($sRenameTarget, $aFileCoverage, _
						$iFileCoverageCount, $sRenameCoverage) Then
					$sRenameClass = 'MANAGED'
				ElseIf _TraceIsWindowsSystemFilePath($sRenameTarget) Then
					$sRenameClass = 'SYSTEM CHANGE'
					$sRenameCoverage = 'Windows-owned file or folder; normally not portable application data'
				Else
					$sRenameClass = 'UNMANAGED'
					$sRenameCoverage = 'Outside Root with no matching current INI path handling'
				EndIf
				_TraceRecordAddIndexed($aRecords, $iRecordCount, $oRecordIndex, _
						$sActor, $sEventType, _
						$sRenameTarget, $sRenameClass, $sOperation & ' destination', _
						$sProcess, $sRenameCoverage)
			EndIf
		EndIf
	WEnd
	FileClose($hCSV)
	_TraceClassifyInstallationClusters($aRecords, $iRecordCount)

	Local $iContained = _TraceRecordClassCount($aRecords, $iRecordCount, 'CONTAINED')
	Local $iManaged = _TraceRecordClassCount($aRecords, $iRecordCount, 'MANAGED')
	Local $iUnmanaged = _TraceRecordClassCount($aRecords, $iRecordCount, 'UNMANAGED')
	Local $iSystemMetadata = _TraceRecordClassCount($aRecords, $iRecordCount, 'SYSTEM METADATA')
	Local $iSystemChange = _TraceRecordClassCount($aRecords, $iRecordCount, 'SYSTEM CHANGE')
	Local $iInstallation = _TraceRecordClassCount($aRecords, $iRecordCount, 'INSTALLATION ACTIVITY')
	Local $iLauncher = _TraceRecordClassCount($aRecords, $iRecordCount, 'X-LAUNCHER ACTION')
	Local $sCaptureStatus = 'complete native capture'
	If $TraceProcMonCapturePartial Then $sCaptureStatus = 'partial native capture; results may be incomplete'
	Local $sDetailStatus = 'present in the Process Monitor export'
	Local $sDetailLimitation = ''
	If Not $TraceProcMonDetailAvailable Then
		$sDetailStatus = 'not present in the Process Monitor export'
		$sDetailLimitation = '- ProcMon Detail was not exported. Ambiguous CreateFile ' & _
				'events are excluded to avoid reporting ordinary reads as writes.' & @CRLF
	EndIf

	Local $sReport = 'X-LAUNCHER APPLICATION PORTABILITY REPORT' & @CRLF & _
			'=========================================' & @CRLF & @CRLF & _
			'ANALYSIS STATUS=COMPLETE' & @CRLF & _
			'Capture=' & $sCaptureStatus & @CRLF & _
			'Capture Filter=automatic write-focused filtering with dropped unrelated events' & @CRLF & _
			'Event Detail=' & $sDetailStatus & @CRLF & _
			'Application=' & $AppName & ' ' & $AppVer & @CRLF & _
			'INI=' & $sIni & @CRLF & _
			'Root=' & $sRootPath & @CRLF & _
			'Application PID tree=' & $sApplicationPIDs & @CRLF & _
			'Launcher PID tree=' & $sLauncherPIDs & @CRLF & @CRLF & _
			_TraceRenderProcessSection($iApplicationPID, $iLauncherPID, _
					$sApplicationPIDs, $sLauncherPIDs, $aRelations, $iRelationCount, _
					$sObservedProcesses) & _
			'SUMMARY' & @CRLF & _
			'-------' & @CRLF & _
			'UNMANAGED application write targets=' & $iUnmanaged & @CRLF & _
			'MANAGED application write targets=' & $iManaged & @CRLF & _
			'CONTAINED application write targets=' & $iContained & @CRLF & _
			'SYSTEM METADATA write targets=' & $iSystemMetadata & @CRLF & _
			'SYSTEM CHANGE targets=' & $iSystemChange & @CRLF & _
			'INSTALLATION ACTIVITY targets=' & $iInstallation & @CRLF & _
			'X-LAUNCHER action targets=' & $iLauncher & @CRLF & _
			'Relevant failed operations=' & $iErrorCount & @CRLF & @CRLF & _
			'UNMANAGED means review is recommended; it is not automatic proof of a ' & _
			'portability failure.' & @CRLF & @CRLF

	$sReport &= _TraceRenderRecordSection('UNMANAGED APPLICATION WRITES - REVIEW', _
			'UNMANAGED', $aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection( _
			'WINDOWS NTFS METADATA - NOT A PORTABILITY TARGET', _
			'SYSTEM METADATA', $aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection( _
			'WINDOWS SYSTEM CHANGES - REVIEW IF UNEXPECTED', _
			'SYSTEM CHANGE', $aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection( _
			'INSTALLATION ACTIVITY - REVIEW IF UNEXPECTED OR LEFT BEHIND', _
			'INSTALLATION ACTIVITY', $aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection('MANAGED BY CURRENT INI', 'MANAGED', _
			$aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection('CONTAINED INSIDE ROOT', 'CONTAINED', _
			$aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection('X-LAUNCHER ACTIONS', 'X-LAUNCHER ACTION', _
			$aRecords, $iRecordCount)
	$sReport &= _TraceRenderRecordSection('RELEVANT FAILED OPERATIONS', _
			'RELEVANT ERROR', $aErrors, $iErrorCount)
	$sReport &= 'LIMITATIONS' & @CRLF & _
			'-----------' & @CRLF & _
			'- Capture is intentionally limited to Process Monitor Process, Write and ' & _
			'Write Metadata categories. The report then attributes application and launcher ' & _
			'process trees and compares their targets with Root and the current INI.' & @CRLF & _
			'- Duplicate timestamp, allocation, flush, security metadata and Windows BAM ' & _
			'bookkeeping events are omitted to keep capture and report processing bounded.' & @CRLF & _
			'- NTFS volume metadata such as C:\$LogFile is retained only in the dedicated ' & _
			'advanced section and is not treated as an application portability warning.' & @CRLF & _
			'- Generic installer staging detection requires an unmanaged directory with at ' & _
			'least two INF, CAT, SYS, CAB, MSI or MSP package files beneath it.' & @CRLF & _
			'- Only successful write-like file and registry operations from attributed ' & _
			'application or launcher process trees are classified.' & @CRLF & _
			'- Services, brokers, elevated helpers and very short-lived processes may not ' & _
			'be attributed completely.' & @CRLF & _
			$sDetailLimitation & _
			'- File existence is checked after X-Launcher cleanup. Registry presence is ' & _
			'not inferred beyond the last captured registry action.' & @CRLF & _
			'- A managed match means the target is covered by a resolved current INI path ' & _
			'or portable REG root; it does not prove the rule is semantically correct.' & @CRLF & _
			'- The preserved Application_Trace.pml remains the detailed source evidence.' & _
			@CRLF & @CRLF & _
			'Privacy=This report can contain usernames, paths, process names and registry ' & _
			'data. Review it before sharing.' & @CRLF

	If Not _TraceWriteUTF8File($sReportPath, $sReport) Then Return SetError(4, 0, False)
	If $sSimpleReportPath <> '' Then
		_TraceWriteSimplePortabilityReport($sSimpleReportPath, $sReportPath, _
				$sCaptureStatus, $sIni, $sRootPath, $aRecords, $iRecordCount, _
				$aErrors, $iErrorCount, $iContained, $iManaged, $iUnmanaged, _
				$sSimpleDebugContent, $iSimpleFailureCount)
	EndIf
	Return SetError(0, $iUnmanaged, True)
EndFunc   ;==>_TraceBuildPortabilityReportFromCSV

Func _TraceWriteSimplePortabilityReport($sPath, $sAdvancedReportPath, _
		$sCaptureStatus, $sIni, $sRootPath, ByRef $aRecords, $iRecordCount, _
		ByRef $aErrors, $iErrorCount, $iContained, $iManaged, $iUnmanaged, _
		$sDebugContent = '', $iFailureCount = 0)
	; Blocked requests wrote no data and have their own section/count. Keep the
	; warning total for successful unmanaged writes and incomplete capture only.
	Local $iWarningCount = $iUnmanaged
	If $TraceProcMonCapturePartial Then $iWarningCount += 1
	Local $iPassCount = $iContained + $iManaged
	Local $iSystemChangeCount = _TraceRecordClassCount($aRecords, $iRecordCount, 'SYSTEM CHANGE')
	Local $iInstallationCount = _TraceRecordClassCount($aRecords, $iRecordCount, 'INSTALLATION ACTIVITY')
	Local $iSystemInstallationCount = $iSystemChangeCount + $iInstallationCount
	Local $sOverall = 'PASS'
	If $iFailureCount > 0 Then
		$sOverall = 'FAIL'
	ElseIf $iWarningCount > 0 Then
		$sOverall = 'REVIEW REQUIRED'
	ElseIf $iSystemInstallationCount > 0 Then
		$sOverall = 'SYSTEM CHANGES OBSERVED'
	ElseIf $iErrorCount > 0 Then
		$sOverall = 'PASS WITH BLOCKED ATTEMPTS'
	EndIf

	Local $sReport = 'X-LAUNCHER APPLICATION TRACE RESULTS' & @CRLF & _
			'====================================' & @CRLF & @CRLF & _
			'This is the short, plain-language Trace report.' & @CRLF & _
			'OVERALL=' & $sOverall & @CRLF & _
			'Failures=' & $iFailureCount & @CRLF & _
			'Warnings=' & $iWarningCount & @CRLF & _
			'Passes=' & $iPassCount & @CRLF & _
			'System/installation changes=' & $iSystemInstallationCount & @CRLF & _
			'Blocked write attempts=' & $iErrorCount & @CRLF & _
			'Capture=' & $sCaptureStatus & @CRLF & _
			'Application=' & $AppName & ' ' & $AppVer & @CRLF & _
			'INI=' & $sIni & @CRLF & _
			'Root=' & $sRootPath & @CRLF & @CRLF & _
			'WHAT THE RESULTS MEAN' & @CRLF & _
			'---------------------' & @CRLF & _
			'FAIL=An X-Launcher configuration or runtime operation failed.' & @CRLF & _
			'WARN=The application wrote outside current portable coverage; resolve or restore it for full stealth.' & @CRLF & _
			'SYSTEM=Windows files/folders or installer staging changed; this is normally not portable application data, but review it if unexpected.' & @CRLF & _
			'BLOCKED=Windows rejected a write-capable request, so no data was written and it is not counted as a warning.' & @CRLF & _
			'PASS=The application write is inside Root or is handled by the current INI.' & @CRLF & @CRLF & _
			'FAILURES' & @CRLF & _
			'--------' & @CRLF & _
			_TraceRenderSimpleLauncherFailureLines($sDebugContent, $iFailureCount) & @CRLF & _
			'BLOCKED WRITE ATTEMPTS' & @CRLF & _
			'----------------------' & @CRLF & _
			'Meaning=Windows rejected these requests; no data was written. Do not add protected Windows paths to the INI.' & @CRLF & _
			_TraceRenderSimpleBlockedLines($aErrors, $iErrorCount) & @CRLF & _
			'SYSTEM/INSTALLATION CHANGES' & @CRLF & _
			'---------------------------' & @CRLF & _
			'Meaning=These are normally Windows file/folder changes or installer staging. Review unexpected activity in the advanced report.' & @CRLF & _
			_TraceRenderSimpleSystemChangeLines($aRecords, $iRecordCount) & @CRLF & _
			'WARNINGS' & @CRLF & _
			'--------' & @CRLF
	If $TraceProcMonCapturePartial Then
		$sReport &= '[WARN] The Process Monitor capture was partial, so later activity may be missing.' & @CRLF
	EndIf
	$sReport &= _TraceRenderSimpleRecordLines('UNMANAGED', $aRecords, $iRecordCount) & _
			@CRLF & 'PASSES' & @CRLF & _
			'------' & @CRLF & _
			_TraceRenderSimpleRecordLines('PASS', $aRecords, $iRecordCount) & _
			@CRLF & 'NEXT STEP' & @CRLF & _
			'---------' & @CRLF
	If $iFailureCount > 0 Then
		$sReport &= 'Review each FAIL first; its section and key identify the related INI operation where available.' & @CRLF
	ElseIf $iUnmanaged > 0 Then
		$sReport &= 'Review each WARN; make the target portable or restore its original host state for full stealth.' & @CRLF
	ElseIf $TraceProcMonCapturePartial Then
		$sReport &= 'Repeat the Trace with a complete capture before treating the result as conclusive.' & @CRLF
	ElseIf $iSystemInstallationCount > 0 Then
		$sReport &= 'Review SYSTEM entries only if the operating-system or installation activity was unexpected.' & @CRLF
	ElseIf $iErrorCount > 0 Then
		$sReport &= 'No INI change is required for blocked attempts unless the application malfunctioned.' & @CRLF
	Else
		$sReport &= 'No captured application write target requires attention.' & @CRLF
	EndIf
	$sReport &= @CRLF & 'Advanced report=' & $sAdvancedReportPath & @CRLF & _
			'Privacy=This report can contain usernames, paths, process names and registry data. Review it before sharing.' & @CRLF
	Return _TraceWriteUTF8File($sPath, $sReport)
EndFunc   ;==>_TraceWriteSimplePortabilityReport

Func _TraceWriteSimplePortabilityUnavailableReport($sPath, $sReason, _
		$sAdvancedReportPath, $sTraceSummaryPath, $sDebugContent = '', _
		$iFailureCount = 0)
	If $sPath = '' Then Return False
	Local $sOverall = 'NOT AVAILABLE'
	If $iFailureCount > 0 Then $sOverall = 'FAIL'
	Local $sReport = 'X-LAUNCHER APPLICATION TRACE RESULTS' & @CRLF & _
			'====================================' & @CRLF & @CRLF & _
			'This is the short, plain-language Trace report.' & @CRLF & _
			'OVERALL=' & $sOverall & @CRLF & _
			'Failures=' & $iFailureCount & @CRLF & _
			'Warnings=1' & @CRLF & _
			'Passes=0' & @CRLF & _
			'Application=' & $AppName & ' ' & $AppVer & @CRLF & _
			'INI=' & $ScriptIni & @CRLF & _
			'Root=' & $Root & @CRLF & @CRLF & _
			'FAILURES' & @CRLF & _
			'--------' & @CRLF & _
			_TraceRenderSimpleLauncherFailureLines($sDebugContent, $iFailureCount) & @CRLF & _
			'WARNINGS' & @CRLF & _
			'--------' & @CRLF & _
			'[WARN] Portability analysis was not available because ' & $sReason & '.' & @CRLF & @CRLF & _
			'PASSES' & @CRLF & _
			'------' & @CRLF & _
			'[NOT USED] No application write locations could be confirmed as portable.' & @CRLF & @CRLF & _
			'NEXT STEP' & @CRLF & _
			'---------' & @CRLF & _
			'Run Trace with Microsoft Process Monitor available and allow its native capture to complete.' & @CRLF & @CRLF & _
			'Advanced report=' & $sAdvancedReportPath & @CRLF & _
			'Trace summary=' & $sTraceSummaryPath & @CRLF & _
			'Privacy=Diagnostic files can contain usernames, paths, command lines, document names and registry data. Review them before sharing.' & @CRLF
	Return _TraceWriteUTF8File($sPath, $sReport)
EndFunc   ;==>_TraceWriteSimplePortabilityUnavailableReport

Func _TraceRenderSimpleLauncherFailureLines($sContent, $iCount)
	If $iCount = 0 Then Return '[NONE] No X-Launcher configuration or runtime failure was reported.' & @CRLF
	Local $sText = '', $sNormalised = StringReplace($sContent, @CR, '')
	Local $aLines = StringSplit($sNormalised, @LF, 1)
	Local $i, $iMarker
	For $i = 1 To $aLines[0]
		$iMarker = StringInStr($aLines[$i], '[FAIL]', 1)
		If $iMarker > 0 Then $sText &= StringMid($aLines[$i], $iMarker) & @CRLF
	Next
	If $sText = '' Then Return '[FAIL] X-Launcher reported a failure; see Application_Trace_Summary.log for its section and key.' & @CRLF
	Return $sText
EndFunc   ;==>_TraceRenderSimpleLauncherFailureLines

Func _TraceRenderSimpleBlockedLines(ByRef $aRecords, $iCount)
	If $iCount = 0 Then Return '[NONE] No blocked write-capable request was observed.' & @CRLF
	Local $sText = '', $i
	Local $sDriverStoreRoot = @WindowsDir & '\System32\DriverStore\FileRepository'
	Local $iDriverStoreTargets = 0
	Local $sDriverStoreActions = '', $sDriverStoreProcesses = ''
	For $i = 0 To $iCount - 1
		If StringUpper($aRecords[$i][8]) = 'ACCESS DENIED' And _
				_TracePathWithin($aRecords[$i][2], $sDriverStoreRoot) Then
			$iDriverStoreTargets += 1
			$sDriverStoreActions = _TraceListMergeUnique($sDriverStoreActions, _
					$aRecords[$i][4])
			$sDriverStoreProcesses = _TraceListMergeUnique($sDriverStoreProcesses, _
					$aRecords[$i][5])
			ContinueLoop
		EndIf
		$sText &= '[BLOCKED] Result=' & $aRecords[$i][8] & ' | Action=' & _
				$aRecords[$i][4] & ' | Process=' & $aRecords[$i][5] & ' | Target=' & _
				_TraceSimpleTargetDescription($aRecords[$i][1], $aRecords[$i][2]) & @CRLF
	Next
	If $iDriverStoreTargets > 0 Then
		$sText = '[BLOCKED] Result=ACCESS DENIED | Action=' & $sDriverStoreActions & _
				' | Process=' & $sDriverStoreProcesses & ' | Targets=' & _
				$iDriverStoreTargets & ' | Location=' & $sDriverStoreRoot & _
				' | No data was written.' & @CRLF & $sText
	EndIf
	Return $sText
EndFunc   ;==>_TraceRenderSimpleBlockedLines

Func _TraceRenderSimpleSystemChangeLines(ByRef $aRecords, $iCount)
	Local $sText = '', $i, $j
	Local $iSystemFiles = 0
	Local $sSystemFileProcesses = ''
	Local $aInstall[16][3], $iInstallCount = 0, $iMatch
	For $i = 0 To $iCount - 1
		Switch $aRecords[$i][3]
			Case 'SYSTEM CHANGE'
				$iSystemFiles += 1
				$sSystemFileProcesses = _TraceListMergeUnique( _
						$sSystemFileProcesses, $aRecords[$i][5])
			Case 'INSTALLATION ACTIVITY'
				$iMatch = -1
				For $j = 0 To $iInstallCount - 1
					If StringLower($aInstall[$j][0]) = StringLower($aRecords[$i][8]) Then
						$iMatch = $j
						ExitLoop
					EndIf
				Next
				If $iMatch < 0 Then
					If $iInstallCount >= UBound($aInstall) Then _
							ReDim $aInstall[UBound($aInstall) + 16][3]
					$iMatch = $iInstallCount
					$aInstall[$iMatch][0] = $aRecords[$i][8]
					$iInstallCount += 1
				EndIf
				$aInstall[$iMatch][1] = Number($aInstall[$iMatch][1]) + 1
				$aInstall[$iMatch][2] = _TraceListMergeUnique( _
						$aInstall[$iMatch][2], $aRecords[$i][5])
		EndSwitch
	Next
	If $iSystemFiles > 0 Then
		$sText &= '[SYSTEM] Windows files/folders changed | Targets=' & $iSystemFiles & _
				' | Processes=' & $sSystemFileProcesses & _
				' | Review only if unexpected.' & @CRLF
	EndIf
	For $i = 0 To $iInstallCount - 1
		$sText &= '[INSTALLATION] Package staging folder=' & $aInstall[$i][0] & _
				' | Targets=' & $aInstall[$i][1] & ' | Processes=' & _
				$aInstall[$i][2] & ' | Review only if unexpected or left behind.' & @CRLF
	Next
	If $sText = '' Then Return '[NONE] No Windows system change or installer staging target was observed.' & @CRLF
	Return $sText
EndFunc   ;==>_TraceRenderSimpleSystemChangeLines

Func _TraceListMergeUnique($sList, $sValues)
	Local $aValues = StringSplit($sValues, ', ', 1)
	Local $i
	For $i = 1 To $aValues[0]
		$sList = _TraceListAddUnique($sList, $aValues[$i])
	Next
	Return $sList
EndFunc   ;==>_TraceListMergeUnique

Func _TraceRenderSimpleRecordLines($sMode, ByRef $aRecords, $iCount)
	Local $sText = '', $i, $sClass
	For $i = 0 To $iCount - 1
		$sClass = $aRecords[$i][3]
		If $sMode = 'UNMANAGED' And $sClass = 'UNMANAGED' Then
			$sText &= '[WARN] ' & $aRecords[$i][5] & ' wrote to ' & _
					_TraceSimpleTargetDescription($aRecords[$i][1], $aRecords[$i][2]) & _
					', but the current INI does not make this location portable.' & @CRLF
		ElseIf $sMode = 'PASS' And ($sClass = 'MANAGED' Or $sClass = 'CONTAINED') Then
			$sText &= '[PASS] Process=' & $aRecords[$i][5] & ' | Target=' & _
					_TraceSimpleTargetDescription($aRecords[$i][1], $aRecords[$i][2]) & _
					' | INI=' & _TraceSimpleINILabel($aRecords[$i][8]) & @CRLF
		EndIf
	Next
	If $sText <> '' Then Return $sText
	If $sMode = 'UNMANAGED' Then Return '[NONE] No unmanaged application write targets were observed.' & @CRLF
	Return '[NONE] No application write target was confirmed as portable.' & @CRLF
EndFunc   ;==>_TraceRenderSimpleRecordLines

Func _TraceSimpleINILabel($sCoverage)
	; The advanced report retains the resolved REG filename as evidence. The
	; plain-language report only needs the INI section and key.
	Local $iRegedit = StringInStr($sCoverage, '] Regedit=', 1)
	If $iRegedit > 0 Then _
			Return StringLeft($sCoverage, $iRegedit + StringLen('] Regedit') - 1)
	Local $iResolvedPath = StringInStr($sCoverage, ' (', 0, -1)
	If $iResolvedPath > 0 And StringRight($sCoverage, 1) = ')' Then _
			Return StringLeft($sCoverage, $iResolvedPath - 1)
	If $sCoverage = '' Then Return '[FileSystem] Root'
	Return $sCoverage
EndFunc   ;==>_TraceSimpleINILabel

Func _TraceSimpleTargetDescription($sType, $sPath)
	Switch $sType
		Case 'FILE'
			Return 'file ' & $sPath
		Case 'DIRECTORY'
			Return 'folder ' & $sPath
		Case 'REGISTRY'
			Return 'registry location ' & $sPath
	EndSwitch
	Return StringLower($sType) & ' target ' & $sPath
EndFunc   ;==>_TraceSimpleTargetDescription

Func _TraceWriteUTF8File($sPath, $sText)
	Local $hFile = FileOpen($sPath, 2 + 128)
	If $hFile = -1 Then Return False
	FileWrite($hFile, $sText)
	Local $iWriteError = @error
	FileClose($hFile)
	Return $iWriteError = 0
EndFunc   ;==>_TraceWriteUTF8File

Func _TraceCSVReadHeader($sCSVPath, ByRef $iProcess, ByRef $iPID, _
		ByRef $iOperation, ByRef $iPath, ByRef $iResult, ByRef $iDetail)
	Local $hFile = FileOpen($sCSVPath, 0)
	If $hFile = -1 Then Return False
	Local $sHeader = FileReadLine($hFile)
	Local $iReadError = @error
	FileClose($hFile)
	If $iReadError Then Return False
	Local $aHeader[1]
	If Not _TraceCSVParseLine($sHeader, $aHeader) Then Return False
	Local $i, $sName
	For $i = 0 To UBound($aHeader) - 1
		$sName = StringLower(StringStripWS(StringReplace($aHeader[$i], ChrW(0xFEFF), ''), 3))
		Switch $sName
			Case 'process name'
				$iProcess = $i
			Case 'pid'
				$iPID = $i
			Case 'operation'
				$iOperation = $i
			Case 'path'
				$iPath = $i
			Case 'result'
				$iResult = $i
			Case 'detail'
				$iDetail = $i
		EndSwitch
	Next
	Return $iProcess >= 0 And $iPID >= 0 And $iOperation >= 0 And _
			$iPath >= 0 And $iResult >= 0
EndFunc   ;==>_TraceCSVReadHeader

Func _TraceCSVParseLine($sLine, ByRef $aFields)
	; Canonical ProcMon CSV rows quote every field. Let PCRE split that common
	; form in native code; retain the character parser for malformed or legacy
	; input so compatibility and defensive validation are unchanged.
	If StringRegExp($sLine, '^"(?:[^"]|"")*"(?:,"(?:[^"]|"")*")*$') Then
		Local $aFast = StringRegExp($sLine, '(?:^|,)"((?:[^"]|"")*)"', 3)
		If Not @error And IsArray($aFast) Then
			ReDim $aFields[UBound($aFast)]
			Local $f
			For $f = 0 To UBound($aFast) - 1
				$aFields[$f] = StringReplace($aFast[$f], '""', '"')
			Next
			Return True
		EndIf
	EndIf
	Return _TraceCSVParseLineLegacy($sLine, $aFields)
EndFunc   ;==>_TraceCSVParseLine

Func _TraceCSVParseLineLegacy($sLine, ByRef $aFields)
	Local $aResult[8]
	Local $iCount = 0, $sField = '', $bQuoted = False
	Local $i = 1, $iLength = StringLen($sLine), $sChar
	While $i <= $iLength
		$sChar = StringMid($sLine, $i, 1)
		If $sChar = '"' Then
			If $bQuoted And $i < $iLength And StringMid($sLine, $i + 1, 1) = '"' Then
				$sField &= '"'
				$i += 1
			Else
				$bQuoted = Not $bQuoted
			EndIf
		ElseIf $sChar = ',' And Not $bQuoted Then
			If $iCount >= UBound($aResult) Then ReDim $aResult[UBound($aResult) + 8]
			$aResult[$iCount] = $sField
			$iCount += 1
			$sField = ''
		Else
			$sField &= $sChar
		EndIf
		$i += 1
	WEnd
	If $bQuoted Then Return False
	If $iCount >= UBound($aResult) Then ReDim $aResult[UBound($aResult) + 1]
	$aResult[$iCount] = $sField
	$iCount += 1
	ReDim $aResult[$iCount]
	$aFields = $aResult
	Return True
EndFunc   ;==>_TraceCSVParseLineLegacy

Func _TraceCSVCollectProcessRelations($sCSVPath, $iProcess, $iPID, $iOperation, _
		$iPath, $iDetail, ByRef $aRelations, ByRef $iRelationCount, _
		$bInitialBlockOnly = False)
	Local $hFile = FileOpen($sCSVPath, 0)
	If $hFile = -1 Then Return False
	FileReadLine($hFile)
	Local $sLine, $aFields[1], $sOperation, $sDetail, $iChild, $iParent
	Local $bRelationBlockStarted = False
	While True
		$sLine = FileReadLine($hFile)
		If @error Then ExitLoop
		If Not _TraceCSVParseLine($sLine, $aFields) Then ContinueLoop
		If UBound($aFields) <= $iOperation Or UBound($aFields) <= $iPID Then ContinueLoop
		$sOperation = StringLower($aFields[$iOperation])
		If $sOperation <> 'process start' And $sOperation <> 'process create' Then
			If $bInitialBlockOnly And $bRelationBlockStarted Then ExitLoop
			ContinueLoop
		EndIf
		$bRelationBlockStarted = True
		$sDetail = ''
		If $iDetail >= 0 And UBound($aFields) > $iDetail Then $sDetail = $aFields[$iDetail]
		If $sOperation = 'process start' Then
			$iChild = Number($aFields[$iPID])
			$iParent = _TraceDetailNumber($sDetail, 'Parent PID')
		Else
			$iParent = Number($aFields[$iPID])
			$iChild = _TraceDetailNumber($sDetail, 'PID')
		EndIf
		If $iChild <= 0 Or $iParent <= 0 Then ContinueLoop
		Local $sName = '', $sCommandLine = ''
		If $sOperation = 'process create' And UBound($aFields) > $iPath Then
			$sName = _FileInfo($aFields[$iPath], 1)
		ElseIf UBound($aFields) > $iProcess Then
			$sName = $aFields[$iProcess]
		EndIf
		$sCommandLine = _TraceDetailValue($sDetail, 'Command line')
		_TraceRelationAdd($aRelations, $iRelationCount, $iChild, $iParent, _
				$sName, $sCommandLine)
	WEnd
	FileClose($hFile)
	Return True
EndFunc   ;==>_TraceCSVCollectProcessRelations

Func _TraceRelationAdd(ByRef $aRelations, ByRef $iCount, $iChild, $iParent, _
		$sName, $sCommandLine)
	Local $i
	For $i = 0 To $iCount - 1
		If $aRelations[$i][0] = $iChild Then
			If $iParent > 0 Then $aRelations[$i][1] = $iParent
			If $sName <> '' Then $aRelations[$i][2] = $sName
			If $sCommandLine <> '' Then $aRelations[$i][3] = $sCommandLine
			Return
		EndIf
	Next
	If $iCount >= UBound($aRelations) Then ReDim $aRelations[UBound($aRelations) + 64][4]
	$aRelations[$iCount][0] = $iChild
	$aRelations[$iCount][1] = $iParent
	$aRelations[$iCount][2] = $sName
	$aRelations[$iCount][3] = $sCommandLine
	$iCount += 1
EndFunc   ;==>_TraceRelationAdd

Func _TracePIDAdd(ByRef $sPIDs, $iPID)
	$iPID = Number($iPID)
	If $iPID <= 0 Or _TracePIDContains($sPIDs, $iPID) Then Return False
	$sPIDs &= $iPID & '|'
	Return True
EndFunc   ;==>_TracePIDAdd

Func _TracePIDContains($sPIDs, $iPID)
	Return StringInStr($sPIDs, '|' & Number($iPID) & '|', 1) > 0
EndFunc   ;==>_TracePIDContains

Func _TracePIDMerge(ByRef $sTarget, $sSource)
	Local $aPIDs = StringSplit($sSource, '|')
	Local $i
	For $i = 1 To $aPIDs[0]
		If StringIsDigit($aPIDs[$i]) Then _TracePIDAdd($sTarget, Number($aPIDs[$i]))
	Next
EndFunc   ;==>_TracePIDMerge

Func _TracePIDResolveDescendants(ByRef $sPIDs, ByRef $aRelations, $iRelationCount)
	Local $bChanged, $i, $iPass = 0
	Do
		$bChanged = False
		For $i = 0 To $iRelationCount - 1
			If _TracePIDContains($sPIDs, $aRelations[$i][1]) Then
				If _TracePIDAdd($sPIDs, $aRelations[$i][0]) Then $bChanged = True
			EndIf
		Next
		$iPass += 1
	Until Not $bChanged Or $iPass > $iRelationCount + 1
EndFunc   ;==>_TracePIDResolveDescendants

Func _TraceDetailNumber($sDetail, $sName)
	Local $aMatch = StringRegExp($sDetail, '(?i)(?:^|,\s*)' & $sName & '\s*[:=]\s*(\d+)', 1)
	If @error Or Not IsArray($aMatch) Then Return 0
	Return Number($aMatch[0])
EndFunc   ;==>_TraceDetailNumber

Func _TraceDetailValue($sDetail, $sName)
	Local $aMatch = StringRegExp($sDetail, '(?i)(?:^|,\s*)' & $sName & '\s*[:=]\s*([^,]+)', 1)
	If @error Or Not IsArray($aMatch) Then Return ''
	Return StringStripWS($aMatch[0], 3)
EndFunc   ;==>_TraceDetailValue

Func _TraceEventType($sOperation, $sDetail)
	Local $sLower = StringLower($sOperation)
	Switch $sLower
		Case 'regcreatekey', 'regsetvalue', 'regdeletevalue', 'regdeletekey', _
				'regrenamekey', 'regloadkey', 'regunloadkey'
			Return 'REGISTRY'
		Case 'writefile', 'setrenameinformationfile', _
				'setdispositioninformationfile', 'setrenameinformationex', _
				'setdispositioninformationex'
			Return 'FILE'
		Case 'createfile'
			Local $sDetailLower = StringLower($sDetail)
			If StringInStr($sDetailLower, 'options: directory', 1) And _
					_TraceCreateFileMayWrite($sDetailLower) Then Return 'DIRECTORY'
			If _TraceCreateFileMayWrite($sDetailLower) Then Return 'FILE'
	EndSwitch
	Return ''
EndFunc   ;==>_TraceEventType

Func _TraceOperationMayReport($sOperation)
	Switch StringLower($sOperation)
		Case 'regcreatekey', 'regsetvalue', 'regdeletevalue', 'regdeletekey', _
				'regrenamekey', 'regloadkey', 'regunloadkey', 'writefile', _
				'setrenameinformationfile', 'setdispositioninformationfile', _
				'setrenameinformationex', 'setdispositioninformationex', 'createfile'
			Return True
	EndSwitch
	Return False
EndFunc   ;==>_TraceOperationMayReport

Func _TraceCreateFileMayWrite($sDetailLower)
	Return StringRegExp($sDetailLower, 'desired access:[^,]*write') Or _
			StringInStr($sDetailLower, 'write data', 1) Or _
			StringInStr($sDetailLower, 'append data', 1) Or _
			StringInStr($sDetailLower, 'generic write', 1) Or _
			StringInStr($sDetailLower, 'delete', 1) Or _
			StringInStr($sDetailLower, 'disposition: create', 1) Or _
			StringInStr($sDetailLower, 'disposition: openif', 1) Or _
			StringInStr($sDetailLower, 'disposition: overwrite', 1) Or _
			StringInStr($sDetailLower, 'disposition: supersede', 1)
EndFunc   ;==>_TraceCreateFileMayWrite

Func _TraceResultNeedsReview($sResult)
	Switch StringUpper($sResult)
		Case 'ACCESS DENIED', 'NAME NOT FOUND', 'PATH NOT FOUND', 'SHARING VIOLATION'
			Return True
	EndSwitch
	Return False
EndFunc   ;==>_TraceResultNeedsReview

Func _TraceBuildCoverageMap($sIni, ByRef $aFileCoverage, ByRef $iFileCount, _
		ByRef $aRegCoverage, ByRef $iRegCount)
	; Resolved runtime destinations are the strongest description of the paths
	; that the current configuration intentionally makes portable.
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Temp, 'PREFIX', _
			'[FileSystem] Temp')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Cache, 'PREFIX', _
			'[FileSystem] Cache')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Home, 'PREFIX', _
			'[FileSystem] Home')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Bin, 'PREFIX', _
			'[FileSystem] Bin')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Lib, 'PREFIX', _
			'[FileSystem] Lib')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Doc, 'PREFIX', _
			'[FileSystem] Doc')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Backup, 'PREFIX', _
			'[FileSystem] Backup')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Download, 'PREFIX', _
			'[FileSystem] Download')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $UserProfile, 'PREFIX', _
			'[FileSystem] UserProfile')
	_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Root, 'PREFIX', _
			'[FileSystem] Root')

	Local $aEnvironment = IniReadSection($sIni, 'Environment')
	Local $i, $bUserProfile = False, $bAppData = False
	Local $bLocalAppData = False, $bTemp = False, $bTmp = False
	If Not @error Then
		For $i = 1 To $aEnvironment[0][0]
			; PATH controls executable discovery; it is not a promise that files
			; written anywhere on PATH are made portable by this INI.
			If StringUpper($aEnvironment[$i][0]) = 'PATH' Then ContinueLoop
			Local $aEnvironmentParts = StringSplit($aEnvironment[$i][1], '|')
			Local $sEnvironmentPath = $aEnvironmentParts[1]
			_TraceCoverageAddEnvironmentPaths($aFileCoverage, $iFileCount, _
					$sEnvironmentPath, '[Environment] ' & $aEnvironment[$i][0])
			Switch StringUpper($aEnvironment[$i][0])
				Case 'USERPROFILE'
					$bUserProfile = True
				Case 'APPDATA'
					$bAppData = True
				Case 'LOCALAPPDATA'
					$bLocalAppData = True
				Case 'TEMP'
					$bTemp = True
				Case 'TMP'
					$bTmp = True
			EndSwitch
		Next
	EndIf

	If StringLower(IniRead($sIni, 'Options', 'FixAppData', 'false')) = 'true' And _
			$bUserProfile And Not $bAppData Then
		_TraceCoverageAddFile($aFileCoverage, $iFileCount, EnvGet('APPDATA'), _
				'PREFIX', '[Options] FixAppData=true + [Environment] USERPROFILE')
	EndIf
	If StringLower(IniRead($sIni, 'Options', 'FixLocalAppData', 'false')) = 'true' And _
			Not $bLocalAppData Then
		_TraceCoverageAddFile($aFileCoverage, $iFileCount, $Lib & '\AppData\Local', _
				'PREFIX', '[Options] FixLocalAppData=true')
	EndIf
	If StringLower(IniRead($sIni, 'Options', 'FixTemp', 'false')) = 'true' And _
			(Not $bTemp Or Not $bTmp) Then
		_TraceCoverageAddFile($aFileCoverage, $iFileCount, _
				$Lib & '\AppData\Local\Temp', 'PREFIX', '[Options] FixTemp=true')
	EndIf

	Local $aOperationSections[4] = ['Functions', 'FirstRunOperations', _
			'RunBefore', 'RunAfter']
	Local $aValues, $sOperation, $sValue, $iSection
	For $iSection = 0 To UBound($aOperationSections) - 1
		$aValues = IniReadSection($sIni, $aOperationSections[$iSection])
		If @error Then ContinueLoop
		For $i = 1 To $aValues[0][0]
			$sOperation = $aValues[$i][0]
			$sValue = $aValues[$i][1]
			_TraceCoverageAddOperation($aFileCoverage, $iFileCount, _
					$aOperationSections[$iSection], $sOperation, $sValue)
			If $sOperation = 'Regedit' Then
				_TraceCoverageAddRegedit($aRegCoverage, $iRegCount, $sValue, _
						'[' & $aOperationSections[$iSection] & '] Regedit')
			EndIf
		Next
	Next

	Local $aSections = IniReadSectionNames($sIni)
	If Not @error Then
		For $i = 1 To $aSections[0]
			Local $iEquals = StringInStr($aSections[$i], '=')
			If $iEquals = 0 Then ContinueLoop
			Local $sType = StringLeft($aSections[$i], $iEquals - 1)
			Switch $sType
				Case 'StringReplace', 'StringRegExpReplace', 'WriteToFile', _
						'WriteToIni', 'WriteToPref', 'WriteToReg'
					_TraceCoverageAddFile($aFileCoverage, $iFileCount, _
							_FullPath(StringTrimLeft($aSections[$i], $iEquals), $Root), _
							'EXACT', '[' & $aSections[$i] & ']')
			EndSwitch
		Next
	EndIf
EndFunc   ;==>_TraceBuildCoverageMap

Func _TraceCoverageAddEnvironmentPaths(ByRef $aCoverage, ByRef $iCount, _
		$sValue, $sSource)
	Local $aPaths = StringSplit($sValue, ';')
	Local $i, $sPath
	For $i = 1 To $aPaths[0]
		$sPath = StringStripWS($aPaths[$i], 3)
		If StringRegExp($sPath, '^[A-Za-z][A-Za-z0-9+.-]*://') Then ContinueLoop
		If Not _TraceCoverageLooksLikePath($sPath) Then ContinueLoop
		_TraceCoverageAddFile($aCoverage, $iCount, _FullPath($sPath, $Root), _
				'PREFIX', $sSource)
	Next
EndFunc   ;==>_TraceCoverageAddEnvironmentPaths

Func _TraceCoverageLooksLikePath($sValue)
	$sValue = StringStripWS($sValue, 3)
	If $sValue = '' Then Return False
	Return StringInStr($sValue, '\') Or StringInStr($sValue, '/') Or _
			StringLeft($sValue, 1) = '.' Or StringLeft($sValue, 1) = '$' Or _
			StringLeft($sValue, 1) = '@' Or StringInStr($sValue, '%') Or _
			StringRegExp($sValue, '^[A-Za-z]:')
EndFunc   ;==>_TraceCoverageLooksLikePath

Func _TraceCoverageAddOperation(ByRef $aCoverage, ByRef $iCount, $sSection, _
		$sOperation, $sValue)
	Local $aParts = StringSplit($sValue, '|')
	Local $sSource = '[' & $sSection & '] ' & $sOperation
	Switch $sOperation
		Case 'DirCopy', 'DirMove', 'Junctions', 'SymLinks'
			If $aParts[0] >= 1 Then _TraceCoverageAddPathList($aCoverage, $iCount, _
					$aParts[1], 'PREFIX', $sSource & ' source')
			If $aParts[0] >= 2 Then _TraceCoverageAddPathList($aCoverage, $iCount, _
					$aParts[2], 'PREFIX', $sSource & ' destination')
		Case 'FileCopy', 'FileMove'
			If $aParts[0] >= 1 Then _TraceCoverageAddPathList($aCoverage, $iCount, _
					$aParts[1], 'EXACT', $sSource & ' source')
			If $aParts[0] >= 2 Then _TraceCoverageAddPathList($aCoverage, $iCount, _
					$aParts[2], 'PREFIX', $sSource & ' destination')
		Case 'DirCreate', 'DirRemove'
			_TraceCoverageAddPathList($aCoverage, $iCount, $aParts[1], 'PREFIX', $sSource)
		Case 'FileCreate', 'FileDelete', 'FixDriveLetter', 'AddFonts', 'RemoveFonts'
			_TraceCoverageAddPathList($aCoverage, $iCount, $aParts[1], 'EXACT', $sSource)
	EndSwitch
EndFunc   ;==>_TraceCoverageAddOperation

Func _TraceCoverageAddPathList(ByRef $aCoverage, ByRef $iCount, $sValue, _
		$sMode, $sSource)
	Local $aItems = StringSplit($sValue, ';')
	Local $sFirst = '', $sBase = '', $sPath
	Local $i
	For $i = 1 To $aItems[0]
		If $aItems[$i] = '' Then ContinueLoop
		If $i = 1 Or StringInStr($aItems[$i], '\') Or StringInStr($aItems[$i], '/') Or _
				StringRegExp($aItems[$i], '^[A-Za-z]:') Then
			$sPath = _FullPath($aItems[$i], $Root)
			If $sFirst = '' Then
				$sFirst = $sPath
				$sBase = _FileInfo($sFirst, 0)
			EndIf
		Else
			$sPath = $sBase & '\' & $aItems[$i]
		EndIf
		_TraceCoverageAddFile($aCoverage, $iCount, $sPath, $sMode, $sSource)
	Next
EndFunc   ;==>_TraceCoverageAddPathList

Func _TraceCoverageAddFile(ByRef $aCoverage, ByRef $iCount, $sPath, $sMode, $sSource)
	$sPath = StringStripWS($sPath, 3)
	If $sPath = '' Then Return False
	Local $iWildcard = StringInStr($sPath, '*')
	Local $iQuestion = StringInStr($sPath, '?')
	If $iWildcard = 0 Or ($iQuestion > 0 And $iQuestion < $iWildcard) Then $iWildcard = $iQuestion
	If $iWildcard > 0 Then
		Local $sBefore = StringLeft($sPath, $iWildcard - 1)
		Local $iSlash = StringInStr($sBefore, '\', 0, -1)
		If $iSlash > 0 Then $sPath = StringLeft($sBefore, $iSlash - 1)
		$sMode = 'PREFIX'
	EndIf
	Local $sCanonical = _TraceCanonicalPath($sPath)
	If $sCanonical = '' Then Return False
	Local $i
	For $i = 0 To $iCount - 1
		If $aCoverage[$i][0] = $sCanonical And $aCoverage[$i][1] = $sMode Then
			If _TraceCoverageSourcePriority($sSource) > _
					_TraceCoverageSourcePriority($aCoverage[$i][2]) Then _
					$aCoverage[$i][2] = $sSource
			Return True
		EndIf
	Next
	If $iCount >= UBound($aCoverage) Then ReDim $aCoverage[UBound($aCoverage) + 64][3]
	$aCoverage[$iCount][0] = $sCanonical
	$aCoverage[$iCount][1] = $sMode
	$aCoverage[$iCount][2] = $sSource
	$iCount += 1
	Return True
EndFunc   ;==>_TraceCoverageAddFile

Func _TraceCoverageSourcePriority($sSource)
	If StringInStr($sSource, 'Junctions', 1) Or _
			StringInStr($sSource, 'SymLinks', 1) Then Return 100
	If StringLeft($sSource, 9) = '[Options]' Then Return 90
	If StringLeft($sSource, 1) = '[' And StringInStr($sSource, '=') Then Return 95
	If StringLeft($sSource, 13) = '[Environment]' Then Return 80
	If StringInStr($sSource, 'DirCreate', 1) Or _
			StringInStr($sSource, 'DirRemove', 1) Then Return 60
	If StringLeft($sSource, 12) = '[FileSystem]' Then Return 40
	Return 70
EndFunc   ;==>_TraceCoverageSourcePriority

Func _TraceFileCoverageMatch($sPath, ByRef $aCoverage, $iCount, ByRef $sSource)
	Local $sCanonical = _TraceCanonicalPath($sPath)
	Local $i, $iBest = -1, $iBestLength = -1, $bMatches
	For $i = 0 To $iCount - 1
		$bMatches = ($aCoverage[$i][1] = 'EXACT' And $sCanonical = $aCoverage[$i][0]) Or _
				($aCoverage[$i][1] = 'PREFIX' And _TracePathWithin($sCanonical, $aCoverage[$i][0]))
		If $bMatches And (StringLen($aCoverage[$i][0]) > $iBestLength Or _
				(StringLen($aCoverage[$i][0]) = $iBestLength And _
				$aCoverage[$i][1] = 'EXACT')) Then
			$iBest = $i
			$iBestLength = StringLen($aCoverage[$i][0])
		EndIf
	Next
	If $iBest < 0 Then Return False
	$sSource = $aCoverage[$iBest][2] & ' (' & $aCoverage[$iBest][0] & ')'
	Return True
EndFunc   ;==>_TraceFileCoverageMatch

Func _TraceCanonicalPath($sPath)
	Local $sValue = StringStripWS(StringReplace($sPath, '/', '\'), 3)
	If StringLeft($sValue, 1) = '"' And StringRight($sValue, 1) = '"' Then
		$sValue = StringTrimLeft(StringTrimRight($sValue, 1), 1)
	EndIf
	If StringLeft($sValue, 4) = '\\?\' Then $sValue = StringTrimLeft($sValue, 4)
	While StringInStr($sValue, '\\') And StringLeft($sValue, 2) <> '\\'
		$sValue = StringReplace($sValue, '\\', '\')
	WEnd
	While StringLen($sValue) > 3 And StringRight($sValue, 1) = '\'
		$sValue = StringTrimRight($sValue, 1)
	WEnd
	Return StringLower($sValue)
EndFunc   ;==>_TraceCanonicalPath

Func _TracePathWithin($sCandidate, $sParent)
	Local $sChild = _TraceCanonicalPath($sCandidate)
	Local $sRoot = _TraceCanonicalPath($sParent)
	If $sChild = '' Or $sRoot = '' Then Return False
	Return $sChild = $sRoot Or StringLeft($sChild, StringLen($sRoot) + 1) = $sRoot & '\'
EndFunc   ;==>_TracePathWithin

Func _TraceIsNTFSVolumeMetadataPath($sPath)
	Local $sCanonical = _TraceCanonicalPath($sPath)
	If StringLen($sCanonical) < 4 Or StringMid($sCanonical, 2, 2) <> ':\' Then Return False
	Local $sRootName = StringMid($sCanonical, 4)
	If StringLeft($sRootName, 1) <> '$' Then Return False
	Local $iSlash = StringInStr($sRootName, '\')
	Local $iStream = StringInStr($sRootName, ':')
	Local $iBoundary = $iSlash
	If $iBoundary = 0 Or ($iStream > 0 And $iStream < $iBoundary) Then $iBoundary = $iStream
	If $iBoundary > 0 Then $sRootName = StringLeft($sRootName, $iBoundary - 1)
	Switch $sRootName
		Case '$mft', '$mftmirr', '$logfile', '$volume', '$attrdef', '$bitmap', _
				'$boot', '$badclus', '$secure', '$upcase', '$extend'
			Return True
	EndSwitch
	Return False
EndFunc   ;==>_TraceIsNTFSVolumeMetadataPath

Func _TraceIsWindowsSystemFilePath($sPath)
	Return _TracePathWithin($sPath, @WindowsDir)
EndFunc   ;==>_TraceIsWindowsSystemFilePath

Func _TraceIsInstallerPackageFile($sPath)
	Local $sLower = StringLower($sPath)
	Return StringRight($sLower, 4) = '.inf' Or _
			StringRight($sLower, 4) = '.cat' Or _
			StringRight($sLower, 4) = '.sys' Or _
			StringRight($sLower, 4) = '.cab' Or _
			StringRight($sLower, 4) = '.msi' Or _
			StringRight($sLower, 4) = '.msp'
EndFunc   ;==>_TraceIsInstallerPackageFile

Func _TraceClassifyInstallationClusters(ByRef $aRecords, $iCount)
	Local $aRoots[16], $iRootCount = 0
	Local $i, $j, $iPackageCount, $sBestRoot
	For $i = 0 To $iCount - 1
		If $aRecords[$i][3] <> 'UNMANAGED' Or $aRecords[$i][1] <> 'DIRECTORY' Then ContinueLoop
		$iPackageCount = 0
		For $j = 0 To $iCount - 1
			If $aRecords[$j][3] = 'UNMANAGED' And $aRecords[$j][1] = 'FILE' And _
					_TraceIsInstallerPackageFile($aRecords[$j][2]) And _
					_TracePathWithin($aRecords[$j][2], $aRecords[$i][2]) Then _
					$iPackageCount += 1
		Next
		If $iPackageCount < 2 Then ContinueLoop
		If $iRootCount >= UBound($aRoots) Then ReDim $aRoots[UBound($aRoots) + 16]
		$aRoots[$iRootCount] = $aRecords[$i][2]
		$iRootCount += 1
	Next
	If $iRootCount = 0 Then Return 0

	For $i = 0 To $iCount - 1
		If $aRecords[$i][3] <> 'UNMANAGED' Or $aRecords[$i][1] = 'REGISTRY' Then ContinueLoop
		$sBestRoot = ''
		For $j = 0 To $iRootCount - 1
			If _TracePathWithin($aRecords[$i][2], $aRoots[$j]) And _
					($sBestRoot = '' Or StringLen($aRoots[$j]) < StringLen($sBestRoot)) Then _
					$sBestRoot = $aRoots[$j]
		Next
		If $sBestRoot = '' Then ContinueLoop
		$aRecords[$i][3] = 'INSTALLATION ACTIVITY'
		$aRecords[$i][8] = $sBestRoot
	Next
	Return $iRootCount
EndFunc   ;==>_TraceClassifyInstallationClusters

Func _TraceCoverageAddRegedit(ByRef $aCoverage, ByRef $iCount, $sValue, $sSource)
	Local $aGroups = StringSplit($sValue, '|')
	Local $aFiles, $sFirst, $sBase, $sPath
	Local $i, $f
	For $i = 1 To $aGroups[0]
		If $aGroups[$i] = '' Or $aGroups[$i] = '*' Then ContinueLoop
		$aFiles = StringSplit($aGroups[$i], ';')
		$sFirst = _FullPath($aFiles[1], $Root)
		$sBase = _FileInfo($sFirst, 0)
		For $f = 1 To $aFiles[0]
			If $f = 1 Then
				$sPath = $sFirst
			Else
				$sPath = $sBase & '\' & $aFiles[$f]
			EndIf
			If Not FileExists($sPath) Then ContinueLoop
			; REG files are only INI-like, so read their bracketed registry roots
			; directly. Retain the historical reader only as a compatibility
			; fallback for an unusual file the direct parser cannot enumerate.
			Local $aRoots = _TraceRegFileGetRoots($sPath)
			If $aRoots[0] = 0 Then $aRoots = _RegFileGetRoots($sPath)
			Local $r
			For $r = 1 To $aRoots[0]
				_TraceCoverageAddRegistry($aCoverage, $iCount, $aRoots[$r], _
						$sSource & '=' & $sPath)
			Next
		Next
	Next
EndFunc   ;==>_TraceCoverageAddRegedit

Func _TraceRegFileGetRoots($sRegFile)
	Local $aRoots[16]
	$aRoots[0] = 0
	Local $sContent = FileRead($sRegFile)
	If @error Or $sContent = '' Then Return $aRoots
	Local $aLines = StringSplit(StringReplace($sContent, @CR, ''), @LF, 1)
	Local $sLine, $sSection, $sUpper
	Local $i, $r, $o, $bDuplicate, $bChild
	For $i = 1 To $aLines[0]
		$sLine = StringStripWS($aLines[$i], 3)
		If StringLen($sLine) < 3 Or StringLeft($sLine, 1) <> '[' Or _
				StringRight($sLine, 1) <> ']' Then ContinueLoop
		$sSection = StringStripWS(StringTrimLeft(StringTrimRight($sLine, 1), 1), 3)
		If StringLeft($sSection, 1) = '-' Then
			$sSection = StringStripWS(StringTrimLeft($sSection, 1), 3)
		EndIf
		$sUpper = StringUpper($sSection)
		If Not _TraceRegistryRootSupported($sUpper) Then ContinueLoop
		$bDuplicate = False
		For $r = 1 To $aRoots[0]
			If StringLower($aRoots[$r]) = StringLower($sSection) Then
				$bDuplicate = True
				ExitLoop
			EndIf
		Next
		If $bDuplicate Then ContinueLoop
		If $aRoots[0] + 1 >= UBound($aRoots) Then ReDim $aRoots[UBound($aRoots) + 16]
		$aRoots[0] += 1
		$aRoots[$aRoots[0]] = $sSection
	Next

	; Keep only independent top-level sections. A captured child is already
	; covered when its parent root is portable.
	Local $aTop[16]
	$aTop[0] = 0
	For $r = 1 To $aRoots[0]
		$bChild = False
		For $o = 1 To $aRoots[0]
			If $r = $o Then ContinueLoop
			If StringLen($aRoots[$o]) < StringLen($aRoots[$r]) And _
					StringLower(StringLeft($aRoots[$r], StringLen($aRoots[$o]) + 1)) = _
					StringLower($aRoots[$o] & '\') Then
				$bChild = True
				ExitLoop
			EndIf
		Next
		If $bChild Then ContinueLoop
		If $aTop[0] + 1 >= UBound($aTop) Then ReDim $aTop[UBound($aTop) + 16]
		$aTop[0] += 1
		$aTop[$aTop[0]] = $aRoots[$r]
	Next
	ReDim $aTop[$aTop[0] + 1]
	Return $aTop
EndFunc   ;==>_TraceRegFileGetRoots

Func _TraceRegistryRootSupported($sRoot)
	Local $aPrefixes[5] = ['HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE', _
			'HKEY_CLASSES_ROOT', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG']
	Local $i
	For $i = 0 To UBound($aPrefixes) - 1
		If $sRoot = $aPrefixes[$i] Or _
				StringLeft($sRoot, StringLen($aPrefixes[$i]) + 1) = _
				$aPrefixes[$i] & '\' Then Return True
	Next
	Return False
EndFunc   ;==>_TraceRegistryRootSupported

Func _TraceCoverageAddRegistry(ByRef $aCoverage, ByRef $iCount, $sRoot, $sSource)
	Local $sCanonical = _TraceCanonicalRegistry($sRoot)
	If $sCanonical = '' Then Return False
	Local $i
	For $i = 0 To $iCount - 1
		If $aCoverage[$i][0] = $sCanonical Then Return True
	Next
	If $iCount >= UBound($aCoverage) Then ReDim $aCoverage[UBound($aCoverage) + 32][2]
	$aCoverage[$iCount][0] = $sCanonical
	$aCoverage[$iCount][1] = $sSource
	$iCount += 1
	Return True
EndFunc   ;==>_TraceCoverageAddRegistry

Func _TraceCanonicalRegistry($sPath)
	Local $sValue = StringUpper(StringStripWS(StringReplace($sPath, '/', '\'), 3))
	$sValue = StringRegExpReplace($sValue, '^HKEY_CURRENT_USER(?=\\|$)', 'HKCU')
	$sValue = StringRegExpReplace($sValue, '^HKEY_LOCAL_MACHINE(?=\\|$)', 'HKLM')
	$sValue = StringRegExpReplace($sValue, '^HKEY_CLASSES_ROOT(?=\\|$)', 'HKCR')
	$sValue = StringRegExpReplace($sValue, '^HKEY_USERS(?=\\|$)', 'HKU')
	$sValue = StringRegExpReplace($sValue, '^HKEY_CURRENT_CONFIG(?=\\|$)', 'HKCC')
	$sValue = StringRegExpReplace($sValue, '^HKLM(?:32|64)(?=\\|$)', 'HKLM')
	While StringRight($sValue, 1) = '\'
		$sValue = StringTrimRight($sValue, 1)
	WEnd
	Return $sValue
EndFunc   ;==>_TraceCanonicalRegistry

Func _TraceRegistryCoverageMatch($sPath, ByRef $aCoverage, $iCount, ByRef $sSource)
	Local $sCanonical = _TraceCanonicalRegistryViewPath($sPath)
	Local $i, $iBest = -1, $iBestLength = -1, $sCoverageRoot
	For $i = 0 To $iCount - 1
		$sCoverageRoot = _TraceCanonicalRegistryViewPath($aCoverage[$i][0])
		If $sCanonical = $sCoverageRoot Or _
				StringLeft($sCanonical, StringLen($sCoverageRoot) + 1) = _
				$sCoverageRoot & '\' Then
			If StringLen($sCoverageRoot) > $iBestLength Then
				$iBest = $i
				$iBestLength = StringLen($sCoverageRoot)
			EndIf
		EndIf
	Next
	If $iBest < 0 Then Return False
	$sSource = $aCoverage[$iBest][1] & ' (' & $aCoverage[$iBest][0] & ')'
	Return True
EndFunc   ;==>_TraceRegistryCoverageMatch

Func _TraceCanonicalRegistryViewPath($sPath)
	Local $sValue = _TraceCanonicalRegistry($sPath)
	If StringUpper($RegView) <> '32' Then Return $sValue
	$sValue = _TraceRegistryRemoveViewNode($sValue, _
			'HKLM\SOFTWARE\WOW6432NODE', 'HKLM\SOFTWARE')
	$sValue = _TraceRegistryRemoveViewNode($sValue, _
			'HKCU\SOFTWARE\CLASSES\WOW6432NODE', 'HKCU\SOFTWARE\CLASSES')
	$sValue = _TraceRegistryRemoveViewNode($sValue, 'HKCR\WOW6432NODE', 'HKCR')
	Return $sValue
EndFunc   ;==>_TraceCanonicalRegistryViewPath

Func _TraceRegistryRemoveViewNode($sPath, $sViewPrefix, $sLogicalPrefix)
	If $sPath = $sViewPrefix Then Return $sLogicalPrefix
	If StringLeft($sPath, StringLen($sViewPrefix) + 1) = $sViewPrefix & '\' Then
		Return $sLogicalPrefix & StringTrimLeft($sPath, StringLen($sViewPrefix))
	EndIf
	Return $sPath
EndFunc   ;==>_TraceRegistryRemoveViewNode

Func _TraceRecordAddIndexed(ByRef $aRecords, ByRef $iCount, ByRef $oIndex, _
		$sActor, $sType, $sPath, $sClass, $sOperation, $sProcess, $sCoverage)
	If Not IsObj($oIndex) Then Return _TraceRecordAdd($aRecords, $iCount, _
			$sActor, $sType, $sPath, $sClass, $sOperation, $sProcess, $sCoverage)

	Local $sKey = $sActor & Chr(1) & $sType & Chr(1) & StringLower($sPath) & _
			Chr(1) & $sClass
	Local $i
	If $oIndex.Exists($sKey) Then
		$i = Number($oIndex.Item($sKey))
		$aRecords[$i][4] = _TraceListAddUnique($aRecords[$i][4], $sOperation)
		$aRecords[$i][5] = _TraceListAddUnique($aRecords[$i][5], $sProcess)
		$aRecords[$i][6] = Number($aRecords[$i][6]) + 1
		$aRecords[$i][7] = $sOperation
		If $sCoverage <> '' Then $aRecords[$i][8] = $sCoverage
		Return True
	EndIf

	If $iCount >= UBound($aRecords) Then ReDim $aRecords[UBound($aRecords) + 128][10]
	$aRecords[$iCount][0] = $sActor
	$aRecords[$iCount][1] = $sType
	$aRecords[$iCount][2] = $sPath
	$aRecords[$iCount][3] = $sClass
	$aRecords[$iCount][4] = $sOperation
	$aRecords[$iCount][5] = $sProcess
	$aRecords[$iCount][6] = 1
	$aRecords[$iCount][7] = $sOperation
	$aRecords[$iCount][8] = $sCoverage
	$oIndex.Add($sKey, $iCount)
	$iCount += 1
	Return True
EndFunc   ;==>_TraceRecordAddIndexed

Func _TraceRecordAdd(ByRef $aRecords, ByRef $iCount, $sActor, $sType, $sPath, _
		$sClass, $sOperation, $sProcess, $sCoverage)
	Local $sKeyPath = StringLower($sPath)
	Local $i
	For $i = 0 To $iCount - 1
		If $aRecords[$i][0] = $sActor And $aRecords[$i][1] = $sType And _
				StringLower($aRecords[$i][2]) = $sKeyPath And $aRecords[$i][3] = $sClass Then
			$aRecords[$i][4] = _TraceListAddUnique($aRecords[$i][4], $sOperation)
			$aRecords[$i][5] = _TraceListAddUnique($aRecords[$i][5], $sProcess)
			$aRecords[$i][6] = Number($aRecords[$i][6]) + 1
			$aRecords[$i][7] = $sOperation
			If $sCoverage <> '' Then $aRecords[$i][8] = $sCoverage
			Return True
		EndIf
	Next
	If $iCount >= UBound($aRecords) Then ReDim $aRecords[UBound($aRecords) + 128][10]
	$aRecords[$iCount][0] = $sActor
	$aRecords[$iCount][1] = $sType
	$aRecords[$iCount][2] = $sPath
	$aRecords[$iCount][3] = $sClass
	$aRecords[$iCount][4] = $sOperation
	$aRecords[$iCount][5] = $sProcess
	$aRecords[$iCount][6] = 1
	$aRecords[$iCount][7] = $sOperation
	$aRecords[$iCount][8] = $sCoverage
	$iCount += 1
	Return True
EndFunc   ;==>_TraceRecordAdd

Func _TraceListAddUnique($sList, $sValue)
	If $sValue = '' Then Return $sList
	Local $aItems = StringSplit($sList, ', ', 1)
	Local $i
	For $i = 1 To $aItems[0]
		If $aItems[$i] = $sValue Then Return $sList
	Next
	If $sList = '' Then Return $sValue
	Return $sList & ', ' & $sValue
EndFunc   ;==>_TraceListAddUnique

Func _TraceRecordClassCount(ByRef $aRecords, $iCount, $sClass)
	Local $iResult = 0, $i
	For $i = 0 To $iCount - 1
		If $aRecords[$i][3] = $sClass Then $iResult += 1
	Next
	Return $iResult
EndFunc   ;==>_TraceRecordClassCount

Func _TraceRenderProcessSection($iApplicationPID, $iLauncherPID, $sApplicationPIDs, _
		$sLauncherPIDs, ByRef $aRelations, $iRelationCount, $sObservedProcesses)
	Local $sText = 'ATTRIBUTED PROCESSES AND COMMAND LINES' & @CRLF & _
			'--------------------------------------' & @CRLF & _
			'Application Root PID= ' & $iApplicationPID & @CRLF & _
			'Launcher Root PID= ' & $iLauncherPID & @CRLF
	Local $i, $sActor, $iShown = 0
	For $i = 0 To $iRelationCount - 1
		$sActor = ''
		If _TracePIDContains($sApplicationPIDs, $aRelations[$i][0]) Then
			$sActor = 'APPLICATION'
		ElseIf _TracePIDContains($sLauncherPIDs, $aRelations[$i][0]) Then
			$sActor = 'X-LAUNCHER'
		EndIf
		If $sActor = '' Then ContinueLoop
		$iShown += 1
		$sText &= @CRLF & 'Actor= ' & $sActor & @CRLF & _
				'PID= ' & $aRelations[$i][0] & @CRLF & _
				'ParentPID= ' & $aRelations[$i][1] & @CRLF & _
				'Process= ' & $aRelations[$i][2] & @CRLF
		If $aRelations[$i][3] <> '' Then
			$sText &= 'CommandLine= ' & $aRelations[$i][3] & @CRLF
		Else
			$sText &= 'CommandLine= not available in exported relation' & @CRLF
		EndIf
	Next
	If $iShown = 0 Then $sText &= 'Process-start relations= none attributed' & @CRLF
	If $sObservedProcesses <> '' Then
		$sText &= @CRLF & 'WMI-OBSERVED APPLICATION CHILDREN' & @CRLF & _
				$sObservedProcesses
		If StringRight($sText, 2) <> @CRLF Then $sText &= @CRLF
	EndIf
	Return $sText & @CRLF
EndFunc   ;==>_TraceRenderProcessSection

Func _TraceRenderRecordSection($sTitle, $sClass, ByRef $aRecords, $iCount)
	Local $sText = $sTitle & @CRLF & _TraceRepeat('-', StringLen($sTitle)) & @CRLF
	Local $iMatches = 0, $i, $sState
	For $i = 0 To $iCount - 1
		If $aRecords[$i][3] <> $sClass Then ContinueLoop
		$iMatches += 1
		If $sClass = 'RELEVANT ERROR' Then
			$sState = 'FAILED OPERATION'
		ElseIf $sClass = 'SYSTEM METADATA' Then
			$sState = 'WINDOWS-MANAGED METADATA'
		ElseIf $sClass = 'SYSTEM CHANGE' Then
			$sState = 'OPERATING-SYSTEM CHANGE'
		ElseIf $sClass = 'INSTALLATION ACTIVITY' Then
			$sState = 'INSTALLER STAGING ACTIVITY'
		Else
			$sState = _TraceRecordState($aRecords[$i][1], $aRecords[$i][2], _
					$aRecords[$i][7])
		EndIf
		$sText &= @CRLF & '[' & $aRecords[$i][1] & '] ' & $sState & @CRLF & _
				'Actor= ' & $aRecords[$i][0] & @CRLF & _
				'Process= ' & $aRecords[$i][5] & @CRLF & _
				'Actions= ' & $aRecords[$i][4] & ' (' & $aRecords[$i][6] & _
				' captured events)' & @CRLF & _
				'Path= ' & $aRecords[$i][2] & @CRLF
		If $sClass = 'RELEVANT ERROR' Then
			$sText &= 'Result= ' & $aRecords[$i][8] & @CRLF
		ElseIf $sClass = 'SYSTEM METADATA' Then
			$sText &= 'Classification= ' & $aRecords[$i][8] & @CRLF
		ElseIf $sClass = 'SYSTEM CHANGE' Then
			$sText &= 'Classification= ' & $aRecords[$i][8] & @CRLF
		ElseIf $sClass = 'INSTALLATION ACTIVITY' Then
			$sText &= 'Classification= Installer or driver-package staging cluster' & @CRLF & _
					'Staging Root= ' & $aRecords[$i][8] & @CRLF
		Else
			$sText &= 'INIcoverage= ' & $aRecords[$i][8] & @CRLF
		EndIf
		If $sClass = 'UNMANAGED' Then
			$sText &= 'Review= Decide whether this target contains user settings or data; ' & _
					'if it does, add an appropriate INI rule.' & @CRLF
		EndIf
	Next
	If $iMatches = 0 Then $sText &= '[NONE]' & @CRLF
	Return $sText & @CRLF
EndFunc   ;==>_TraceRenderRecordSection

Func _TraceRecordState($sType, $sPath, $sLastOperation)
	If $sType = 'REGISTRY' Then
		If StringInStr(StringLower($sLastOperation), 'delete') Then Return 'DELETE OBSERVED'
		Return 'LAST ACTION= ' & $sLastOperation
	EndIf
	If $sType = 'FILE' Or $sType = 'DIRECTORY' Then
		If FileExists($sPath) Then Return 'PRESENT AFTER EXIT'
		Return 'NOT PRESENT AFTER EXIT'
	EndIf
	Return 'REVIEW'
EndFunc   ;==>_TraceRecordState

Func _TraceRepeat($sCharacter, $iCount)
	Local $sResult = '', $i
	For $i = 1 To $iCount
		$sResult &= $sCharacter
	Next
	Return $sResult
EndFunc   ;==>_TraceRepeat

Func _TraceCheckProcMonCaptureLimits()
	If Not $TraceProcMonCaptureActive Or $TraceProcMonLimitStopAttempted Then Return True

	Local $iCaptureSize = FileGetSize($TraceProcMonCapturePath)
	Local $iSizeError = @error
	If $iSizeError = 0 And $iCaptureSize >= 0 Then $TraceProcMonCaptureBytes = $iCaptureSize

	Local $nFreeMB = DriveSpaceFree($TraceSessionDir)
	Local $iFreeError = @error
	If $iFreeError Then
		$nFreeMB = -1
		If Not $TraceProcMonSpaceCheckWarned Then
			$TraceProcMonSpaceCheckWarned = True
			_DebugWrite('[WARN] [Process Monitor] Available storage could not be rechecked; ' & _
					'the PML size limit remains active (error=' & $iFreeError & ')')
		EndIf
	EndIf

	Local $sReason = _TraceProcMonLimitReason($TraceProcMonCaptureBytes, $nFreeMB, _
			$TraceProcMonMaxMB, $TraceProcMonReserveMB)
	If $sReason = '' Then Return True

	$TraceProcMonCapturePartial = True
	$TraceProcMonPartialReason = $sReason
	$TraceProcMonLimitStopAttempted = True
	_DebugWrite('[WARN] [Process Monitor] Capture safeguard stopped collection early (' & _
			'reason=' & $sReason & '; bytes=' & $TraceProcMonCaptureBytes & _
			'; free=' & Round($nFreeMB, 1) & ' MB)')
	Local $bStopped = _TraceStopProcMonCapture($sReason)
	Local $iStopError = @error
	Return SetError(1, $iStopError, $bStopped)
EndFunc   ;==>_TraceCheckProcMonCaptureLimits

Func _TraceFormatProcMonBytes($iBytes)
	If $iBytes < 0 Then Return 'unknown'
	Return $iBytes & ' bytes (' & Round($iBytes / 1048576, 2) & ' MiB)'
EndFunc   ;==>_TraceFormatProcMonBytes

Func _TraceFormatProcMonDuration($nMilliseconds)
	If $nMilliseconds <= 0 Then Return 'not available'
	Return Round($nMilliseconds / 1000, 2) & ' seconds'
EndFunc   ;==>_TraceFormatProcMonDuration

Func _TraceSafeFolderName($sName)
	Local $sSafe = StringRegExpReplace(StringStripWS($sName, 3), '[\\/:*?"<>|]', '_')
	While StringLen($sSafe) > 0 And (StringRight($sSafe, 1) = '.' Or StringRight($sSafe, 1) = ' ')
		$sSafe = StringTrimRight($sSafe, 1)
	WEnd
	Return $sSafe
EndFunc   ;==>_TraceSafeFolderName

Func _TraceInitialiseProcessObservation()
	$TraceCOMError = False
	$TraceCOMErrorObject = ObjEvent('AutoIt.Error', '_TraceCOMErrorHandler')
	$TraceWMI = ObjGet('winmgmts:\\.\root\cimv2')
	If @error Or $TraceCOMError Or Not IsObj($TraceWMI) Then
		$TraceProcessObservation = 'unavailable'
		_DebugWrite('[NOT USED] [Process] Child-process observation is unavailable through WMI')
		Return False
	EndIf

	$TraceProcessObservation = 'available'
	_DebugWrite('[INFO] [Process] Child-process observation is available through WMI')
	Return True
EndFunc   ;==>_TraceInitialiseProcessObservation

Func _TraceCOMErrorHandler()
	$TraceCOMError = True
EndFunc   ;==>_TraceCOMErrorHandler

Func _TraceRunAndWait($sCommandLine, $iShowFlag)
	Local $iPID = Run($sCommandLine, '', $iShowFlag)
	Local $iRunError = @error
	If $iRunError Then Return SetError($iRunError, 0, 0)

	$TraceApplicationPID = $iPID
	$TraceApplicationExitCode = 'running'
	_DebugWrite('[PASS] [Process] Application launch PID=' & $iPID & _
			' (command=' & $sCommandLine & ')')

	; Retain a process handle across the timed observation loop. Repeated
	; ProcessWaitClose calls can lose the real exit code when the process exits
	; between calls and return AutoIt's 0xCCCCCCCC sentinel instead.
	Local $vExitCode = 'unavailable'
	Local $bWaitComplete = False
	Local $aOpenProcess = DllCall('kernel32.dll', 'handle', 'OpenProcess', _
			'dword', 0x00100400, 'bool', False, 'dword', $iPID)
	Local $iOpenProcessError = @error

	Local $bProcessHandleAvailable = False
	If $iOpenProcessError = 0 And IsArray($aOpenProcess) Then
		If $aOpenProcess[0] <> 0 Then $bProcessHandleAvailable = True
	EndIf

	If $bProcessHandleAvailable Then
		Local $hProcess = $aOpenProcess[0]
		Local $aWaitResult

		Do
			_TraceObserveChildProcesses()
			_TraceCheckProcMonCaptureLimits()
			$aWaitResult = DllCall('kernel32.dll', 'dword', 'WaitForSingleObject', _
					'handle', $hProcess, 'dword', 1000)
			If @error Or Not IsArray($aWaitResult) Then ExitLoop

			Switch $aWaitResult[0]
				Case 0
					$bWaitComplete = True
				Case 258
					ContinueLoop
				Case Else
					ExitLoop
			EndSwitch
		Until $bWaitComplete
		_TraceObserveChildProcesses()

		If $bWaitComplete Then
			Local $aExitCode = DllCall('kernel32.dll', 'bool', 'GetExitCodeProcess', _
					'handle', $hProcess, 'dword*', 0)
			Local $iExitCodeError = @error
			If $iExitCodeError = 0 And IsArray($aExitCode) Then
				If $aExitCode[0] <> 0 Then $vExitCode = $aExitCode[2]
			EndIf
		EndIf

		DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $hProcess)
	EndIf

	; Retain complete lifecycle waiting if the process handle could not be used.
	If Not $bWaitComplete Then
		Local $iClosed = 0
		Local $vFallbackExitCode = 0
		Do
			_TraceObserveChildProcesses()
			_TraceCheckProcMonCaptureLimits()
			$iClosed = ProcessWaitClose($iPID, 1)
			$vFallbackExitCode = @extended
			If $iClosed = 1 And Hex($vFallbackExitCode, 8) <> 'CCCCCCCC' Then
				$vExitCode = $vFallbackExitCode
			EndIf
		Until $iClosed = 1
		_TraceObserveChildProcesses()
	EndIf

	$TraceApplicationExitCode = $vExitCode
	If $vExitCode == 'unavailable' Then
		_DebugWrite('[WARN] [Process] Application PID=' & $iPID & _
				' closed after waited completion; exit code was unavailable')
	Else
		_DebugWrite('[INFO] [Process] Application PID=' & $iPID & _
				' closed (exitcode=' & $vExitCode & ')')
	EndIf
	Return SetError(0, 0, $vExitCode)
EndFunc   ;==>_TraceRunAndWait

Func _TraceObserveChildProcesses()
	If Not $TraceActive Or $TraceApplicationPID <= 0 Or _
			$TraceProcessObservation <> 'available' Or Not IsObj($TraceWMI) Then Return

	$TraceCOMError = False
	Local $oProcesses = $TraceWMI.ExecQuery('SELECT ProcessId, ParentProcessId, Name, CommandLine ' & _
			'FROM Win32_Process WHERE ParentProcessId=' & $TraceApplicationPID)
	If $TraceCOMError Or Not IsObj($oProcesses) Then
		$TraceProcessObservation = 'unavailable after query failure'
		_DebugWrite('[NOT USED] [Process] Child-process observation stopped after a WMI query failure')
		Return
	EndIf

	Local $oProcess, $iPID, $iParentPID, $sName, $sCommandLine
	For $oProcess In $oProcesses
		$iPID = Number($oProcess.ProcessId)
		If $iPID <= 0 Or StringInStr($TraceObservedPIDs, '|' & $iPID & '|', 1) Then ContinueLoop
		$iParentPID = Number($oProcess.ParentProcessId)
		$sName = _TraceSingleLine(String($oProcess.Name))
		$sCommandLine = _TraceSingleLine(String($oProcess.CommandLine))
		$TraceObservedPIDs &= $iPID & '|'
		$TraceObservedProcesses &= 'PID= ' & $iPID & '; ParentPID= ' & $iParentPID & _
				'; Name= ' & $sName & '; CommandLine= ' & $sCommandLine & @CRLF
		_DebugWrite('[INFO] [Process] Child observed PID=' & $iPID & '; parent=' & $iParentPID & _
				'; name=' & $sName & '; command=' & $sCommandLine)
	Next
EndFunc   ;==>_TraceObserveChildProcesses

Func _TraceSingleLine($sValue)
	$sValue = StringReplace($sValue, @CR, ' ')
	$sValue = StringReplace($sValue, @LF, ' ')
	Return StringStripWS($sValue, 3)
EndFunc   ;==>_TraceSingleLine

Func _TraceFinalize($bInteractive = False)
	If Not $TraceActive Or $TraceFinalized Then Return True
	$TraceFinalized = True

	; _XClose calls Trace finalization only after RunAfter, registry restoration,
	; font removal and Temp cleanup, so the native capture includes that work.
	_TraceCheckProcMonCaptureLimits()
	_TraceStopProcMonCapture()
	_TraceCreatePortabilityReport()
	If Not $DebugSessionEnded Then _DebugSessionEnd('trace-finalize')

	Local $sDebugContent = ''
	If FileExists($DebugFile) Then $sDebugContent = FileRead($DebugFile)
	Local $sLauncherVersion = FileGetVersion(@ScriptFullPath)
	If $sLauncherVersion = '' Then $sLauncherVersion = 'source'
	Local $sOverall = 'PASS'
	If $DebugFailCount > 0 Then
		$sOverall = 'FAIL'
	ElseIf $DebugWarnCount > 0 Then
		$sOverall = 'PASS WITH WARNINGS'
	EndIf

	Local $sChildren
	If $TraceObservedProcesses <> '' Then
		$sChildren = $TraceObservedProcesses
	ElseIf StringLeft($TraceProcessObservation, 11) = 'unavailable' Then
		$sChildren = '[NOT USED] Child-process observation was unavailable.' & @CRLF
	Else
		$sChildren = '[NOT USED] No child process was observed during polling.' & @CRLF
	EndIf

	Local $sTraceModeLine = 'X-Launcher-only Application Trace (Process Monitor was not started)'
	Local $sCompleteMode = 'X-Launcher-only'
	Local $sCaptureLine = '[NOT USED] Native Process Monitor capture was not available.'
	Local $sSafeguardLine = 'Capture safeguards=maximum ' & $TraceProcMonMaxMB & _
			' MiB; reserved free space ' & $TraceProcMonReserveMB & ' MiB'
	Local $sCaptureResultLine = '[NOT USED] Capture result=no native PML was saved.'
	Local $sBoundaryDetails = _
			'Inside Root=X-Launcher-recorded configured operations are listed above and in ordered detail.' & @CRLF & _
			'[NOT USED] Outside Root=application filesystem activity requires Process Monitor capture.' & @CRLF & _
			'[NOT USED] File residue=application-created residue requires Process Monitor capture and comparison.' & @CRLF & _
			'[NOT USED] Registry residue=application-created residue requires Process Monitor capture and comparison.' & @CRLF & _
			'Outside-Root writes are warnings, not automatic failures, when capture is added later.'
	Local $sCaptureLimitation = '- Process Monitor capture was not available or was not completed.'
	Local $sObservationLimitation = '- Without native capture, this summary records X-Launcher operations and process information only.'

	If $TraceProcMonCaptureSaved And $TraceProcMonCapturePartial Then
		$sTraceModeLine = 'Application Trace with partial native Process Monitor capture'
		$sCompleteMode = 'Process Monitor partial capture'
		$sCaptureLine = '[WARN] Partial native Process Monitor capture=' & $TraceProcMonCapturePath
		$sCaptureResultLine = 'Capture result=partial; reason=' & $TraceProcMonPartialReason & _
				'; size=' & _TraceFormatProcMonBytes($TraceProcMonCaptureBytes) & _
				'; duration=' & _TraceFormatProcMonDuration($TraceProcMonCaptureDurationMs)
		$sBoundaryDetails = _
				'Inside Root=see CONTAINED entries in Application_Portability_Report.log.' & @CRLF & _
				'[WARN] Outside Root=review MANAGED and UNMANAGED entries; the partial capture may omit later activity.' & @CRLF & _
				'[WARN] File residue=after-exit presence is reported only for captured targets.' & @CRLF & _
				'[WARN] Registry residue=the readable report states the last captured action only.' & @CRLF & _
				'Outside-Root writes are warnings, not automatic failures.'
		$sCaptureLimitation = '- Application_Trace.pml is partial because a storage safeguard stopped collection.'
		$sObservationLimitation = '- The readable report classifies only activity present before the partial capture stopped.'
	ElseIf $TraceProcMonCaptureSaved Then
		$sTraceModeLine = 'Application Trace with native Process Monitor capture'
		$sCompleteMode = 'Process Monitor capture'
		$sCaptureLine = 'Native Process Monitor capture=' & $TraceProcMonCapturePath
		$sCaptureResultLine = 'Capture result=complete; size=' & _
				_TraceFormatProcMonBytes($TraceProcMonCaptureBytes) & '; duration=' & _
				_TraceFormatProcMonDuration($TraceProcMonCaptureDurationMs)
		$sBoundaryDetails = _
				'Inside Root=see CONTAINED entries in Application_Portability_Report.log.' & @CRLF & _
				'Outside Root=review MANAGED and UNMANAGED entries in Application_Portability_Report.log.' & @CRLF & _
				'File residue=the readable report states whether each captured file target exists after cleanup.' & @CRLF & _
				'Registry residue=the readable report states the last captured registry action only.' & @CRLF & _
				'Outside-Root writes are warnings, not automatic failures.'
		$sCaptureLimitation = '- Application_Trace.pml requires Process Monitor for detailed inspection and may contain private information.'
		$sObservationLimitation = '- The readable report classifies captured write-like activity; it cannot prove that every application action was observed.'
	ElseIf FileExists($TraceProcMonCapturePath) Then
		$TraceProcMonCaptureBytes = FileGetSize($TraceProcMonCapturePath)
		$sCaptureLine = '[WARN] Native Process Monitor capture was not confirmed complete=' & _
				$TraceProcMonCapturePath
		$sCaptureResultLine = '[WARN] Capture result=unconfirmed; size=' & _
				_TraceFormatProcMonBytes($TraceProcMonCaptureBytes)
	EndIf

	Local $sReport = 'X-LAUNCHER APPLICATION TRACE' & @CRLF & _
			'============================' & @CRLF & _
			'Mode=' & $sTraceModeLine & @CRLF & _
			'Start=' & $TraceStartTime & @CRLF & _
			'End=' & _DebugSessionTimestamp() & @CRLF & _
			'Session=' & $DebugSessionID & @CRLF & _
			'Launcher version=' & $sLauncherVersion & @CRLF & _
			'INI=' & $ScriptIni & @CRLF & _
			'Application=' & $AppName & ' ' & $AppVer & @CRLF & _
			'Root=' & $Root & @CRLF & _
			'Executable=' & $PathToExe & @CRLF & _
			'Windows=' & @OSVersion & ' ' & @OSServicePack & ' (build ' & @OSBuild & _
			'; ' & @OSArch & ')' & @CRLF & _
			'Process Monitor=' & $TraceProcMonState & @CRLF & _
			'Plain-language Trace results=' & $TraceResultsPath & @CRLF & _
			'Advanced portability report=' & $TracePortabilityReportPath & _
					' (state=' & $TracePortabilityState & ')' & @CRLF & _
			$sSafeguardLine & @CRLF & _
			$sCaptureLine & @CRLF & _
			$sCaptureResultLine & @CRLF & _
			'Privacy=Review usernames, paths, command lines and document names before sharing.' & _
			@CRLF & @CRLF & _
			'FILE AND DIRECTORY OPERATIONS (X-LAUNCHER-RECORDED)' & @CRLF & _
			'---------------------------------------------------' & @CRLF & _
			_TraceSelectDebugLines($sDebugContent, 'file') & @CRLF & _
			'REGISTRY OPERATIONS (X-LAUNCHER-RECORDED)' & @CRLF & _
			'------------------------------------------' & @CRLF & _
			_TraceSelectDebugLines($sDebugContent, 'registry') & @CRLF & _
			'PROCESS ACTIVITY' & @CRLF & _
			'----------------' & @CRLF & _
			'Launcher PID=' & @AutoItPID & @CRLF & _
			'Launcher command line=' & $CmdLineRaw & @CRLF & _
			'Application launch PID=' & $TraceApplicationPID & @CRLF & _
			'Application exit code=' & $TraceApplicationExitCode & @CRLF & _
			'Observed child processes=' & @CRLF & $sChildren & _
			_TraceSelectDebugLines($sDebugContent, 'process') & @CRLF & _
			'ERRORS AND WARNINGS' & @CRLF & _
			'-------------------' & @CRLF & _
			_TraceSelectDebugLines($sDebugContent, 'errors') & @CRLF & _
			'ROOT BOUNDARY AND RESIDUE' & @CRLF & _
			'-------------------------' & @CRLF & _
			$sBoundaryDetails & @CRLF & @CRLF & _
			'LIMITATIONS' & @CRLF & _
			'-----------' & @CRLF & _
			$sObservationLimitation & @CRLF & _
			'- X-Launcher cannot infer whether an application action was intended.' & @CRLF & _
			'- Services, brokers, elevated children and very short-lived child processes may not be attributed completely.' & @CRLF & _
			$sCaptureLimitation & @CRLF & _
			'- X-Launcher never accepts the Process Monitor licence/EULA automatically.' & @CRLF & @CRLF & _
			'SUMMARY' & @CRLF & _
			'-------' & @CRLF & _
			'PASS=' & $DebugPassCount & @CRLF & _
			'FAIL=' & $DebugFailCount & @CRLF & _
			'WARN=' & $DebugWarnCount & @CRLF & _
			'SKIP=' & $DebugSkipCount & @CRLF & _
			'NOT USED=' & $DebugNotUsedCount & @CRLF & _
			'OVERALL=' & $sOverall & @CRLF & @CRLF & _
			'ORDERED DIAGNOSTIC DETAIL' & @CRLF & _
			'-------------------------' & @CRLF
	If $sDebugContent = '' Then
		$sReport &= '[NOT USED] X-Launcher debug detail was not available.' & @CRLF
	Else
		$sReport &= $sDebugContent
		If StringRight($sReport, 2) <> @CRLF Then $sReport &= @CRLF
	EndIf

	Local $hReport = FileOpen($TraceSummaryPath, 2 + 128)
	If $hReport = -1 Then
		If $bInteractive Then MsgBox(48, $ScriptName, 'Application Trace could not create its summary report.')
		Return SetError(1, 0, False)
	EndIf
	FileWrite($hReport, $sReport)
	Local $iWriteError = @error
	FileClose($hReport)
	If $iWriteError Then
		If $bInteractive Then MsgBox(48, $ScriptName, 'Application Trace could not complete its summary report.')
		Return SetError(2, 0, False)
	EndIf

	If $bInteractive Then
		Local $sComplete
		If $Lang = 'it' Then
			$sComplete = 'Traccia applicazione completata.'
		Else
			$sComplete = 'Application Trace completed.'
		EndIf
		$sComplete &= @CRLF & @CRLF & 'Mode=' & $sCompleteMode & @CRLF & _
				'PASS=' & $DebugPassCount & @CRLF & _
				'FAIL=' & $DebugFailCount & @CRLF & _
				'WARN=' & $DebugWarnCount & @CRLF & _
				'SKIP=' & $DebugSkipCount & @CRLF & _
				'NOT USED=' & $DebugNotUsedCount
		If $TraceProcMonCaptureSaved Then
			$sComplete &= @CRLF & 'PML=' & $TraceProcMonCapturePath & @CRLF & _
					'Size=' & _TraceFormatProcMonBytes($TraceProcMonCaptureBytes)
			If $TraceProcMonCapturePartial Then $sComplete &= @CRLF & _
					'Partial=' & $TraceProcMonPartialReason
		EndIf
		Local $sOpenReport = $TraceSummaryPath
		If StringLeft($TracePortabilityState, 9) = 'complete;' And _
				FileExists($TracePortabilityReportPath) Then
			$sOpenReport = $TracePortabilityReportPath
		EndIf
		If FileExists($TraceResultsPath) Then $sOpenReport = $TraceResultsPath
		$sComplete &= @CRLF & 'Trace results=' & $TraceResultsPath
		$sComplete &= @CRLF & 'Advanced portability report=' & $TracePortabilityReportPath
		$sComplete &= @CRLF & 'Trace summary=' & $TraceSummaryPath
		$sComplete &= @CRLF & @CRLF & 'Opened report=' & $sOpenReport
		MsgBox(64, $ScriptName, $sComplete)
		ShellExecute($sOpenReport)
	EndIf

	Return SetError(0, $DebugFailCount, True)
EndFunc   ;==>_TraceFinalize

Func _TraceSelectDebugLines($sContent, $sCategory)
	Local $sResult = ''
	Local $sNormalised = StringReplace($sContent, @CR, '')
	Local $aLines = StringSplit($sNormalised, @LF, 1)
	Local $sLine, $bInclude, $i
	For $i = 1 To $aLines[0]
		$sLine = $aLines[$i]
		If $sLine = '' Then ContinueLoop
		$bInclude = False
		Switch $sCategory
			Case 'file'
				$bInclude = StringInStr($sLine, '] DirCreate=', 1) Or _
						StringInStr($sLine, '] DirCopy=', 1) Or _
						StringInStr($sLine, '] DirMove=', 1) Or _
						StringInStr($sLine, '] DirRemove=', 1) Or _
						StringInStr($sLine, '] FileCopy=', 1) Or _
						StringInStr($sLine, '] FileCreate=', 1) Or _
						StringInStr($sLine, '] FileDelete=', 1) Or _
						StringInStr($sLine, '] FileMove=', 1) Or _
						StringInStr($sLine, '] FixDriveLetter=', 1) Or _
						StringInStr($sLine, '] StringReplace=', 1) Or _
						StringInStr($sLine, '] StringRegExpReplace=', 1) Or _
						StringInStr($sLine, '] WriteToFile=', 1) Or _
						StringInStr($sLine, '] WriteToIni=', 1) Or _
						StringInStr($sLine, '] WriteToPref=', 1) Or _
						StringInStr($sLine, '] AddFonts=', 1) Or _
						StringInStr($sLine, '] RemoveFonts=', 1) Or _
						StringInStr($sLine, '] EmptyFile=', 1) Or _
						StringInStr($sLine, '] Temp=', 1)
			Case 'registry'
				$bInclude = StringInStr($sLine, 'Regedit=', 1) Or _
						StringInStr($sLine, 'RestoreRegedit=', 1) Or _
						StringInStr($sLine, 'WriteToReg=', 1) Or _
						StringInStr($sLine, 'RegistryRecovery=', 1)
			Case 'process'
				$bInclude = StringInStr($sLine, '[Process]', 1) Or _
						StringInStr($sLine, '[FileToRun] Launch=', 1) Or _
						StringInStr($sLine, '] RunFile=', 1)
			Case 'errors'
				$bInclude = StringInStr($sLine, '[FAIL]', 1) Or _
						StringInStr($sLine, '[WARN]', 1) Or _
						StringInStr($sLine, '>>>>>>', 1)
		EndSwitch
		If $bInclude Then $sResult &= $sLine & @CRLF
	Next

	If $sResult = '' Then
		Switch $sCategory
			Case 'file'
				$sResult = '[NOT USED] No file or directory operation result was recorded by X-Launcher.' & @CRLF
			Case 'registry'
				$sResult = '[NOT USED] No registry operation result was recorded by X-Launcher.' & @CRLF
			Case 'process'
				$sResult = '[NOT USED] No additional process operation result was recorded.' & @CRLF
			Case 'errors'
				$sResult = '[PASS] No X-Launcher failure or warning was recorded.' & @CRLF
		EndSwitch
	EndIf
	Return $sResult
EndFunc   ;==>_TraceSelectDebugLines

;===============================================================================
;
; Function Name:	_TestRunSelectionWindow(), _TestRunConfirm()
; Description:		Select and confirm a built-in diagnostic mode without
;					falling through into a normal application launch.
;
;===============================================================================
Func _TestRunSelectionWindow($sTitle, $sLang)
	Local $sPrompt, $sProbe, $sTrace, $sFull, $sCancel
	If $sLang = 'it' Then
		$sPrompt = 'Selezionare una modalita diagnostica:'
		$sProbe = 'Analisi configurazione'
		$sTrace = 'Traccia applicazione'
		$sFull = 'Test completo X-Launcher'
		$sCancel = 'Annulla'
	Else
		$sPrompt = 'Select a diagnostic mode:'
		$sProbe = 'Configuration Probe'
		$sTrace = 'Application Trace'
		$sFull = 'Full X-Launcher Test'
		$sCancel = 'Cancel'
	EndIf

	Local $hSelectionGUI = GUICreate($sTitle, 360, 250)
	If $hSelectionGUI = 0 Then Return 'cancel'

	GUICtrlCreateLabel($sPrompt, 25, 18, 310, 25)
	Local $idProbe = GUICtrlCreateButton($sProbe, 50, 50, 260, 32)
	Local $idTrace = GUICtrlCreateButton($sTrace, 50, 92, 260, 32)
	Local $idFull = GUICtrlCreateButton($sFull, 50, 134, 260, 32)
	Local $idCancel = GUICtrlCreateButton($sCancel, 50, 188, 260, 32)
	GUISetState(@SW_SHOW, $hSelectionGUI)

	While 1
		Local $iSelectionMessage = GUIGetMsg()
		Switch $iSelectionMessage
			Case -3, $idCancel ; -3 is the GUI close event.
				GUIDelete($hSelectionGUI)
				Return 'cancel'
			Case $idProbe
				GUIDelete($hSelectionGUI)
				Return 'probe'
			Case $idTrace
				GUIDelete($hSelectionGUI)
				Return 'trace'
			Case $idFull
				GUIDelete($hSelectionGUI)
				Return 'full'
		EndSwitch
	WEnd
EndFunc   ;==>_TestRunSelectionWindow

Func _TestRunConfirm($sMode, $sTitle, $sLang)
	Local $sMessage = ''
	Switch $sMode
		Case 'probe'
			If $sLang = 'it' Then
				$sMessage = 'Analisi configurazione e di sola lettura.' & @CRLF & _
						"Non avviera l'applicazione configurata o le operazioni configurate." & @CRLF & @CRLF & _
						'Continuare?'
			Else
				$sMessage = 'Configuration Probe is read-only.' & @CRLF & _
						'It will not launch the configured application or configured operations.' & @CRLF & @CRLF & _
						'Continue?'
			EndIf
		Case 'trace'
			If $sLang = 'it' Then
				$sMessage = 'Traccia applicazione non e di sola lettura.' & @CRLF & _
						"Avviera l'applicazione reale e tutte le operazioni X-Launcher configurate." & @CRLF & _
						'Se Process Monitor e disponibile, avviera anche una cattura nativa.' & @CRLF & _
						'Windows o Process Monitor possono mostrare richieste di elevazione o licenza.' & @CRLF & _
						'X-Launcher non accettera automaticamente tali richieste.' & @CRLF & @CRLF & _
						'Continuare?'
			Else
				$sMessage = 'Application Trace is not read-only.' & @CRLF & _
						'It will launch the real application and all configured X-Launcher operations.' & @CRLF & _
						'If Process Monitor is available, it will also start a native capture.' & @CRLF & _
						'Windows or Process Monitor may show elevation or licence prompts.' & @CRLF & _
						'X-Launcher will not accept those prompts automatically.' & @CRLF & @CRLF & _
						'Continue?'
			EndIf
		Case 'full'
			If $sLang = 'it' Then
				$sMessage = 'Il test completo usera dati temporanei isolati.' & @CRLF & _
						"Non usera le destinazioni configurate dell'applicazione." & @CRLF & @CRLF & _
						'Continuare?'
			Else
				$sMessage = 'Full X-Launcher Test will use isolated temporary data.' & @CRLF & _
						"It will not use the application's configured targets." & @CRLF & @CRLF & _
						'Continue?'
			EndIf
		Case Else
			Return False
	EndSwitch

	Return MsgBox(36, $sTitle, $sMessage) = 6
EndFunc   ;==>_TestRunConfirm

;===============================================================================
;
; Function Name:    _FullTestHelperEntry(), _FullTestRun()
; Description:      Isolated Full Test and private self-helper.
;
;===============================================================================
Func _FullTestHelperEntry()
	Local Const $sPrefix = '--x-launcher-selftest-helper='
	If $CmdLine[0] < 1 Then Return SetExtended(0, 0)
	If StringLeft(StringLower($CmdLine[1]), StringLen($sPrefix)) <> $sPrefix Then _
			Return SetExtended(0, 0)

	Local $sRequest = StringTrimLeft($CmdLine[1], StringLen($sPrefix))
	If Not _FullTestPathIsInside($sRequest, @TempDir & '\X-Launcher-SelfTest') Or _
			Not FileExists($sRequest) Then Return SetExtended(1, 64)

	Local $sSessionDir = _FileInfo($sRequest, 0)
	Local $sResult = IniRead($sRequest, 'Helper', 'ResultFile', '')
	If Not _FullTestPathIsInside($sResult, $sSessionDir) Then Return SetExtended(1, 64)

	Local $sExpectedWorking = IniRead($sRequest, 'Helper', 'WorkingDir', '')
	Local $sExpectedEnvironment = IniRead($sRequest, 'Helper', 'Environment', '')
	Local $sExpectedArgument1 = IniRead($sRequest, 'Helper', 'Argument1', '')
	Local $sExpectedArgument2 = IniRead($sRequest, 'Helper', 'Argument2', '')
	Local $sExpectedArgument3 = IniRead($sRequest, 'Helper', 'Argument3', '')
	Local $sExitCode = IniRead($sRequest, 'Helper', 'ExitCode', '')
	Local $sDelayMS = IniRead($sRequest, 'Helper', 'DelayMS', '')
	If Not StringRegExp($sExitCode, '^\d{1,3}$') Or Number($sExitCode) > 255 Or _
			Not StringRegExp($sDelayMS, '^\d{1,4}$') Or Number($sDelayMS) > 5000 Then _
			Return SetExtended(1, 64)

	Local $sActualArgument1 = '', $sActualArgument2 = '', $sActualArgument3 = ''
	If $CmdLine[0] >= 2 Then $sActualArgument1 = $CmdLine[2]
	If $CmdLine[0] >= 3 Then $sActualArgument2 = $CmdLine[3]
	If $CmdLine[0] >= 4 Then $sActualArgument3 = $CmdLine[4]
	Local $bWorking = StringLower(@WorkingDir) = StringLower($sExpectedWorking)
	Local $bEnvironment = EnvGet('XLAUNCHER_SELFTEST_SESSION') == $sExpectedEnvironment
	Local $bArguments = False
	If $CmdLine[0] = 4 Then
		$bArguments = ($sActualArgument1 == $sExpectedArgument1 And _
				$sActualArgument2 == $sExpectedArgument2 And _
				$sActualArgument3 == $sExpectedArgument3)
	EndIf
	Local $sStatus = 'FAIL'
	If $bWorking And $bEnvironment And $bArguments Then $sStatus = 'PASS'

	Local $bWritten = IniWrite($sResult, 'Result', 'Status', $sStatus) = 1
	$bWritten = IniWrite($sResult, 'Result', 'WorkingDir', @WorkingDir) = 1 And $bWritten
	$bWritten = IniWrite($sResult, 'Result', 'Environment', _
			EnvGet('XLAUNCHER_SELFTEST_SESSION')) = 1 And $bWritten
	$bWritten = IniWrite($sResult, 'Result', 'ArgumentCount', $CmdLine[0] - 1) = 1 And $bWritten
	$bWritten = IniWrite($sResult, 'Result', 'Argument1', $sActualArgument1) = 1 And $bWritten
	$bWritten = IniWrite($sResult, 'Result', 'Argument2', $sActualArgument2) = 1 And $bWritten
	$bWritten = IniWrite($sResult, 'Result', 'Argument3', $sActualArgument3) = 1 And $bWritten
	If Not $bWritten Then Return SetExtended(1, 66)

	Sleep(Number($sDelayMS))
	If IniWrite($sResult, 'Result', 'Completed', '1') <> 1 Then Return SetExtended(1, 66)
	If $sStatus <> 'PASS' Then Return SetExtended(1, 65)
	Return SetExtended(1, Number($sExitCode))
EndFunc   ;==>_FullTestHelperEntry

Func _FullTestPathIsInside($sCandidate, $sParent)
	Local $sChild = StringStripWS(StringReplace($sCandidate, '/', '\'), 3)
	Local $sBase = StringStripWS(StringReplace($sParent, '/', '\'), 3)
	If $sChild = '' Or $sBase = '' Then Return False
	If StringRegExp($sChild, '(?i)(^|\\)\.\.?($|\\)') Then Return False
	If Not StringRegExp($sChild, '(?i)^([a-z]:\\|\\\\)') Then Return False
	While StringRight($sBase, 1) = '\'
		$sBase = StringTrimRight($sBase, 1)
	WEnd
	Return StringLeft(StringLower($sChild), StringLen($sBase) + 1) = _
			StringLower($sBase) & '\'
EndFunc   ;==>_FullTestPathIsInside

Func _FullTestWriteHelperRequest($sRequest, $sResult, $sWorkspace, $sSession, _
		$iExitCode, $iDelayMS)
	Local $bWritten = IniWrite($sRequest, 'Helper', 'ResultFile', $sResult) = 1
	$bWritten = IniWrite($sRequest, 'Helper', 'WorkingDir', $sWorkspace) = 1 And $bWritten
	$bWritten = IniWrite($sRequest, 'Helper', 'Environment', $sSession) = 1 And $bWritten
	$bWritten = IniWrite($sRequest, 'Helper', 'Argument1', 'plain') = 1 And $bWritten
	$bWritten = IniWrite($sRequest, 'Helper', 'Argument2', 'value with spaces') = 1 And $bWritten
	$bWritten = IniWrite($sRequest, 'Helper', 'Argument3', 'two spaces  between') = 1 And $bWritten
	$bWritten = IniWrite($sRequest, 'Helper', 'ExitCode', $iExitCode) = 1 And $bWritten
	$bWritten = IniWrite($sRequest, 'Helper', 'DelayMS', $iDelayMS) = 1 And $bWritten
	Return $bWritten
EndFunc   ;==>_FullTestWriteHelperRequest

Func _FullTestHelperCommand($sRequest)
	Return _CommandLineQuoteArgument(@ScriptFullPath) & ' ' & _
			_CommandLineQuoteArgument('--x-launcher-selftest-helper=' & $sRequest) & ' ' & _
			_CommandLineQuoteArgument('plain') & ' ' & _
			_CommandLineQuoteArgument('value with spaces') & ' ' & _
			_CommandLineQuoteArgument('two spaces  between')
EndFunc   ;==>_FullTestHelperCommand

Func _FullTestAddResult(ByRef $sDetails, ByRef $iPass, ByRef $iFail, ByRef $iWarn, _
		ByRef $iSkip, ByRef $iNotUsed, $sStatus, $sCategory, $sMessage, $sDetail = '')
	Switch $sStatus
		Case 'PASS'
			$iPass += 1
		Case 'FAIL'
			$iFail += 1
		Case 'WARN'
			$iWarn += 1
		Case 'SKIP'
			$iSkip += 1
		Case 'NOT USED'
			$iNotUsed += 1
	EndSwitch
	$sDetails &= '[' & $sStatus & '] [' & $sCategory & '] ' & $sMessage
	If $sDetail <> '' Then $sDetails &= '=' & $sDetail
	$sDetails &= @CRLF
EndFunc   ;==>_FullTestAddResult

Func _FullTestStatus($bPass)
	If $bPass Then Return 'PASS'
	Return 'FAIL'
EndFunc   ;==>_FullTestStatus

Func _FullTestWriteFixture($sPath, $sContent)
	Local $hFile = FileOpen($sPath, 2 + 8)
	If $hFile = -1 Then Return False
	Local $iWritten = FileWrite($hFile, $sContent)
	Local $iWriteError = @error
	FileClose($hFile)
	Return $iWritten = 1 And $iWriteError = 0
EndFunc   ;==>_FullTestWriteFixture

Func _FullTestReadFixture($sPath)
	Local $hFile = FileOpen($sPath, 0)
	If $hFile = -1 Then Return SetError(1, 0, '')
	Local $sContent = FileRead($hFile)
	Local $iReadError = @error
	FileClose($hFile)
	Return SetError($iReadError, 0, $sContent)
EndFunc   ;==>_FullTestReadFixture

Func _FullTestWriteBinaryHex($sPath, $sHex)
	Local $hFile = FileOpen($sPath, 2 + 8 + 16)
	If $hFile = -1 Then Return False
	Local $iWritten = FileWrite($hFile, Binary('0x' & $sHex))
	Local $iWriteError = @error
	FileClose($hFile)
	Return $iWritten = 1 And $iWriteError = 0
EndFunc   ;==>_FullTestWriteBinaryHex

Func _FullTestBinaryEquals($sPath, $sExpectedHex)
	Local $hFile = FileOpen($sPath, 16)
	If $hFile = -1 Then Return False
	Local $bActual = FileRead($hFile)
	FileClose($hFile)
	Return $bActual = Binary('0x' & $sExpectedHex)
EndFunc   ;==>_FullTestBinaryEquals

Func _FullTestFileSystemRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sFileSystemRoot = $sWorkspace & '\FileSystem'
	Local $sSentinel = $sWorkspace & '\FileSystemSafetySentinel.txt'
	Local $sSource = $sFileSystemRoot & '\Source'
	Local $sSourceNested = $sSource & '\Nested'
	Local $sSourceFile = $sSourceNested & '\Original.txt'
	Local $sCreatedMain = $sFileSystemRoot & '\Created\Main'
	Local $sCreatedSibling = $sFileSystemRoot & '\Created\Sibling'
	Local $sCreatedSecond = $sFileSystemRoot & '\CreatedSecond'

	Local $bBoundary = _FullTestPathIsInside($sFileSystemRoot, $sWorkspace) And _
			_FullTestPathIsInside($sSentinel, $sWorkspace) And _
			_FullTestPathIsInside($sSourceFile, $sWorkspace) And _
			_FullTestPathIsInside($sCreatedMain, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'File System', _
			'Every operation target passed the isolated workspace boundary check')

	Local $bFixtures = False
	If $bBoundary Then
		$bFixtures = DirCreate($sSourceNested) = 1
		$bFixtures = _FullTestWriteFixture($sSourceFile, 'ORIGINAL-CONTENT') And $bFixtures
		$bFixtures = _FullTestWriteFixture($sSentinel, 'KEEP-SENTINEL') And $bFixtures
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'File System', _
			'Isolated file and directory fixtures were created')

	Local $iDirCreateError = -1, $iFileCreateError = -1
	If $bFixtures Then
		_DirCreate($sCreatedMain & ';Sibling|' & $sCreatedSecond)
		$iDirCreateError = @error
		_FileCreatePlus($sCreatedMain & '\One.txt;Two.txt')
		$iFileCreateError = @error
	EndIf
	Local $bCreate = ($iDirCreateError = 0 And $iFileCreateError = 0 And _
			FileExists($sCreatedMain) And FileExists($sCreatedSibling) And _
			FileExists($sCreatedSecond) And FileExists($sCreatedMain & '\One.txt') And _
			FileExists($sCreatedMain & '\Two.txt') And _
			FileGetSize($sCreatedMain & '\One.txt') = 0 And _
			FileGetSize($sCreatedMain & '\Two.txt') = 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bCreate), 'File System', _
			'Directory and empty-file creation operations succeeded')

	Local $sCopiedFile = $sFileSystemRoot & '\FileFlow\Copied.txt'
	Local $sMovedFile = $sFileSystemRoot & '\FileFlow\Moved\Moved.txt'
	Local $iFileCopy = 0, $iFileCopyError = -1, $iFileMoveError = -1
	If $bFixtures Then
		$iFileCopy = _FileCopy($sSourceFile & '|' & $sCopiedFile & '|o')
		$iFileCopyError = @error
		_FileMove($sCopiedFile & '|' & $sMovedFile & '|o')
		$iFileMoveError = @error
	EndIf
	Local $bFileFlow = ($iFileCopy = 1 And $iFileCopyError = 0 And _
			$iFileMoveError = 0 And FileExists($sSourceFile) And _
			Not FileExists($sCopiedFile) And FileExists($sMovedFile) And _
			_FullTestReadFixture($sMovedFile) == 'ORIGINAL-CONTENT')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFileFlow), 'File System', _
			'File copy and move operations preserved exact content')

	Local $sCollisionDir = $sFileSystemRoot & '\Collision'
	Local $sCollisionSource = $sCollisionDir & '\Source.txt'
	Local $sCollisionDestination = $sCollisionDir & '\Destination.txt'
	Local $iCollisionCopy = 0, $iCollisionError = -1
	Local $bCollisionFixtures = False
	If $bFixtures Then
		$bCollisionFixtures = DirCreate($sCollisionDir) = 1
		$bCollisionFixtures = _FullTestWriteFixture($sCollisionSource, 'SOURCE-KEEP') And _
				$bCollisionFixtures
		$bCollisionFixtures = _FullTestWriteFixture($sCollisionDestination, _
				'DESTINATION-KEEP') And $bCollisionFixtures
		$iCollisionCopy = _FileCopy($sCollisionSource & '|' & $sCollisionDestination)
		$iCollisionError = @error
	EndIf
	Local $bCollisionSafe = ($bCollisionFixtures And $iCollisionCopy = 0 And _
			$iCollisionError = 4 And _
			_FullTestReadFixture($sCollisionSource) == 'SOURCE-KEEP' And _
			_FullTestReadFixture($sCollisionDestination) == 'DESTINATION-KEEP')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bCollisionSafe), 'Safety', _
			'Non-overwrite file-copy failure preserved source and destination')

	Local $sCopiedDirectory = $sFileSystemRoot & '\DirectoryFlow\Copied'
	Local $sMovedDirectory = $sFileSystemRoot & '\DirectoryFlow\Moved'
	Local $iDirCopyError = -1, $iDirMove = 0, $iDirMoveError = -1
	If $bFixtures Then
		_DirCopy($sSource & '|' & $sCopiedDirectory & '|o')
		$iDirCopyError = @error
		$iDirMove = _DirMove($sCopiedDirectory & '|' & $sMovedDirectory & '|o')
		$iDirMoveError = @error
	EndIf
	Local $bDirectoryFlow = ($iDirCopyError = 0 And $iDirMove = 1 And _
			$iDirMoveError = 0 And FileExists($sSourceFile) And _
			Not FileExists($sCopiedDirectory) And _
			_FullTestReadFixture($sMovedDirectory & '\Nested\Original.txt') == _
			'ORIGINAL-CONTENT')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDirectoryFlow), 'File System', _
			'Directory copy and move operations preserved nested content')

	Local $sDeleteFile = $sFileSystemRoot & '\DeleteFile.txt'
	Local $sDeleteDirectory = $sFileSystemRoot & '\DeleteDirectory'
	Local $sDeleteNestedFile = $sDeleteDirectory & '\Nested.txt'
	Local $iFileDelete = 0, $iFileDeleteError = -1
	Local $iDirDelete = 0, $iDirDeleteError = -1
	Local $bDeleteFixtures = False
	If $bFixtures Then
		$bDeleteFixtures = DirCreate($sDeleteDirectory) = 1
		$bDeleteFixtures = _FullTestWriteFixture($sDeleteFile, 'DELETE-FILE') And _
				$bDeleteFixtures
		$bDeleteFixtures = _FullTestWriteFixture($sDeleteNestedFile, 'DELETE-DIRECTORY') And _
				$bDeleteFixtures
		$iFileDelete = _FileDelete($sDeleteFile)
		$iFileDeleteError = @error
		$iDirDelete = _DirRemove($sDeleteDirectory)
		$iDirDeleteError = @error
	EndIf
	Local $bDelete = ($bDeleteFixtures And $iFileDelete = 1 And _
			$iFileDeleteError = 0 And $iDirDelete = 1 And $iDirDeleteError = 0 And _
			Not FileExists($sDeleteFile) And Not FileExists($sDeleteDirectory) And _
			_FullTestReadFixture($sSentinel) == 'KEEP-SENTINEL')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDelete), 'File System', _
			'File and directory deletion removed only isolated targets')

	Local $sNonEmptyDirectory = $sFileSystemRoot & '\NonEmptySafety'
	Local $sNonEmptyFile = $sNonEmptyDirectory & '\Keep.txt'
	Local $iEmptyRemove = -1, $iEmptyRemoveError = -1
	Local $bNonEmptyFixtures = False
	If $bFixtures Then
		$bNonEmptyFixtures = DirCreate($sNonEmptyDirectory) = 1
		$bNonEmptyFixtures = _FullTestWriteFixture($sNonEmptyFile, 'KEEP-NONEMPTY') And _
				$bNonEmptyFixtures
		$iEmptyRemove = _DirRemove($sNonEmptyDirectory & '|e')
		$iEmptyRemoveError = @error
	EndIf
	Local $bEmptyRemoveSafe = ($bNonEmptyFixtures And $iEmptyRemove = 0 And _
			$iEmptyRemoveError = 0 And FileExists($sNonEmptyDirectory) And _
			_FullTestReadFixture($sNonEmptyFile) == 'KEEP-NONEMPTY' And _
			_FullTestReadFixture($sSentinel) == 'KEEP-SENTINEL')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bEmptyRemoveSafe), 'Safety', _
			'Empty-only directory removal preserved non-empty data')

	Local $sMissingDirectory = $sFileSystemRoot & '\AlreadyAbsent'
	Local $sNonDirectoryTarget = $sFileSystemRoot & '\NotADirectory.txt'
	Local $iMissingRemove = -1, $iMissingRemoveError = -1, $iMissingRemoveExtended = -1
	Local $iMissingEmpty = -1, $iMissingEmptyError = -1, $iMissingEmptyExtended = -1
	Local $iNonDirectoryRemove = -1
	If $bFixtures And Not FileExists($sMissingDirectory) And _
			_FullTestWriteFixture($sNonDirectoryTarget, 'KEEP-FILE-TARGET') Then
		$iMissingRemove = _DirRemove($sMissingDirectory)
		$iMissingRemoveError = @error
		$iMissingRemoveExtended = @extended
		$iMissingEmpty = _DirRemove($sMissingDirectory & '|e')
		$iMissingEmptyError = @error
		$iMissingEmptyExtended = @extended
		$iNonDirectoryRemove = _DirRemove($sNonDirectoryTarget)
	EndIf
	Local $bMissingRemove = ($iMissingRemove = 1 And $iMissingRemoveError = 0 And _
			$iMissingRemoveExtended = 4 And $iMissingEmpty = 1 And _
			$iMissingEmptyError = 0 And $iMissingEmptyExtended = 4 And _
			Not FileExists($sMissingDirectory) And $iNonDirectoryRemove = 0 And _
			_FullTestReadFixture($sNonDirectoryTarget) == 'KEEP-FILE-TARGET')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bMissingRemove), 'File System', _
			'Missing directory removal succeeded as no-op while a file target failed')
EndFunc   ;==>_FullTestFileSystemRun

Func _FullTestTextFormatRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sTextRoot = $sWorkspace & '\TextFormat'
	Local $sStringFile = $sTextRoot & '\StringReplace.txt'
	Local $sRegExpFile = $sTextRoot & '\StringRegExpReplace.txt'
	Local $sWriteFile = $sTextRoot & '\WriteToFile.txt'
	Local $sPrefFile = $sTextRoot & '\WriteToPref.txt'
	Local $sMozFile = $sTextRoot & '\MozPrefs.txt'

	Local $bBoundary = _FullTestPathIsInside($sTextRoot, $sWorkspace) And _
			_FullTestPathIsInside($sStringFile, $sWorkspace) And _
			_FullTestPathIsInside($sMozFile, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Text Format', _
			'Every text fixture passed the isolated workspace boundary check')

	Local $bFixtures = False
	If $bBoundary Then
		$bFixtures = DirCreate($sTextRoot) = 1
		$bFixtures = _FullTestWriteBinaryHex($sStringFile, _
				'EFBBBF616C7068613D3C6F6C643E0A776F72643D636166C3A90A0A') And $bFixtures
		$bFixtures = _FullTestWriteBinaryHex($sRegExpFile, _
				'EFBBBF746F6B656E3D6F6C640A776F72643D636166C3A90A0A') And $bFixtures
		$bFixtures = _FullTestWriteBinaryHex($sWriteFile, _
				'EFBBBF616C7068613D6F6C640A776F72643D636166C3A90A0A') And $bFixtures
		$bFixtures = _FullTestWriteBinaryHex($sPrefFile, _
				'EFBBBF6B65795B6E616D655D3D6F6C643B0A776F72643D636166C3A90A0A') And _
				$bFixtures
		$bFixtures = _FullTestWriteBinaryHex($sMozFile, _
				'EFBBBF757365725F70726566282273616D706C652E6E616D65222C20226F6C6422293B0A776F72643D636166C3A90A0A') And _
				$bFixtures
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Text Format', _
			'UTF-8 BOM and LF fixtures with trailing blank lines were created')

	Local $iStringReplace = 0, $iStringReplaceError = -1
	If $bFixtures Then
		$iStringReplace = _StringReplace($sStringFile, '<', '>', 'new')
		$iStringReplaceError = @error
	EndIf
	Local $bStringReplace = ($iStringReplace = 1 And $iStringReplaceError = 0 And _
			_FullTestBinaryEquals($sStringFile, _
			'EFBBBF616C7068613D3C6E65773E0A776F72643D636166C3A90A0A'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bStringReplace), 'Text Format', _
			'StringReplace preserved UTF-8 BOM, LF and trailing blank line')

	Local $iRegExpReplace = 0, $iRegExpReplaceError = -1
	If $bFixtures Then
		$iRegExpReplace = _StringRegExpReplace($sRegExpFile, 'old~new', '~|1')
		$iRegExpReplaceError = @error
	EndIf
	Local $bRegExpReplace = ($iRegExpReplace = 1 And $iRegExpReplaceError = 0 And _
			_FullTestBinaryEquals($sRegExpFile, _
			'EFBBBF746F6B656E3D6E65770A776F72643D636166C3A90A0A'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegExpReplace), 'Text Format', _
			'StringRegExpReplace preserved UTF-8 BOM, LF and trailing blank line')

	Local $iWriteToFile = 0, $iWriteToFileError = -1
	If $bFixtures Then
		$iWriteToFile = _WriteToFile($sWriteFile, 'Line1', 'alpha=new')
		$iWriteToFileError = @error
	EndIf
	Local $bWriteToFile = ($iWriteToFile = 1 And $iWriteToFileError = 0 And _
			_FullTestBinaryEquals($sWriteFile, _
			'EFBBBF616C7068613D6E65770A776F72643D636166C3A90A0A'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bWriteToFile), 'Text Format', _
			'WriteToFile preserved UTF-8 BOM, LF and trailing blank line')

	Local $iWriteToPref = 0, $iWriteToPrefError = -1
	If $bFixtures Then
		$iWriteToPref = _WriteToPref($sPrefFile, 'key[', ']=', ';', 'name', 'new')
		$iWriteToPrefError = @error
	EndIf
	Local $bWriteToPref = ($iWriteToPref = 1 And $iWriteToPrefError = 0 And _
			_FullTestBinaryEquals($sPrefFile, _
			'EFBBBF6B65795B6E616D655D3D6E65773B0A776F72643D636166C3A90A0A'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bWriteToPref), 'Text Format', _
			'WriteToPref preserved UTF-8 BOM, LF and trailing blank line')

	If $bFixtures Then
		_MozPrefs($sMozFile, 'sample.name', '"new"', 'User')
	EndIf
	Local $bMozPrefs = ($bFixtures And _
			_FullTestBinaryEquals($sMozFile, _
			'EFBBBF757365725F70726566282273616D706C652E6E616D65222C20226E657722293B0A776F72643D636166C3A90A0A'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bMozPrefs), 'Text Format', _
			'MozPrefs preserved UTF-8 BOM, LF and trailing blank line')
EndFunc   ;==>_FullTestTextFormatRun

Func _FullTestWriterSemanticsRun($sWorkspace, $sRegistryRoot, ByRef $sDetails, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sWriterRoot = $sWorkspace & '\WriterSemantics'
	Local $sIniFile = $sWriterRoot & '\Writer.ini'
	Local $sPrefFile = $sWriterRoot & '\Writer.pref'
	Local $sRegFile = $sWriterRoot & '\Writer.reg'
	Local $sRegMainKey = $sRegistryRoot & '\GeneratedWriter'

	Local $bBoundary = _FullTestPathIsInside($sWriterRoot, $sWorkspace) And _
			_FullTestPathIsInside($sIniFile, $sWorkspace) And _
			_FullTestPathIsInside($sPrefFile, $sWorkspace) And _
			_FullTestPathIsInside($sRegFile, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Writer Semantics', _
			'Every writer output passed the isolated workspace boundary check')

	Local $bWriterRoot = False
	If $bBoundary Then $bWriterRoot = DirCreate($sWriterRoot) = 1
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bWriterRoot), 'Writer Semantics', _
			'Isolated writer fixture directory was created')

	Local $iIniCreate = 0, $iIniCreateError = -1
	Local $iIniSentinel = 0, $iIniSentinelError = -1
	If $bWriterRoot Then
		$iIniCreate = IniWrite($sIniFile, 'Writer', 'Value', 'created')
		$iIniCreateError = @error
		$iIniSentinel = IniWrite($sIniFile, 'Writer', 'Sentinel', 'keep')
		$iIniSentinelError = @error
	EndIf
	Local $bIniCreate = ($iIniCreate = 1 And $iIniCreateError = 0 And _
			$iIniSentinel = 1 And $iIniSentinelError = 0 And FileExists($sIniFile) And _
			IniRead($sIniFile, 'Writer', 'Value', '') == 'created' And _
			IniRead($sIniFile, 'Writer', 'Sentinel', '') == 'keep')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bIniCreate), 'Writer Semantics', _
			'WriteToIni created a new INI value inside the workspace')

	Local $iIniUpdate = 0, $iIniUpdateError = -1
	If $bIniCreate Then
		$iIniUpdate = IniWrite($sIniFile, 'Writer', 'Value', 'updated')
		$iIniUpdateError = @error
	EndIf
	Local $bIniUpdate = ($iIniUpdate = 1 And $iIniUpdateError = 0 And _
			IniRead($sIniFile, 'Writer', 'Value', '') == 'updated' And _
			IniRead($sIniFile, 'Writer', 'Sentinel', '') == 'keep')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bIniUpdate), 'Writer Semantics', _
			'WriteToIni updated one value while preserving another')

	Local $iPrefCreate = 0, $iPrefCreateError = -1
	If $bWriterRoot Then
		$iPrefCreate = _WriteToPref($sPrefFile, 'pref[', ']=', ';', 'Name', 'created')
		$iPrefCreateError = @error
	EndIf
	Local $bPrefCreate = ($iPrefCreate = 1 And $iPrefCreateError = 0 And _
			_FullTestReadFixture($sPrefFile) == ('pref[Name]=created;' & @CRLF))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPrefCreate), 'Writer Semantics', _
			'WriteToPref created a new preference file')

	Local $iPrefUpdate = 0, $iPrefUpdateError = -1
	Local $iPrefAppend = 0, $iPrefAppendError = -1
	Local $iPrefNoChange = -1, $iPrefNoChangeError = -1
	If $bPrefCreate Then
		$iPrefUpdate = _WriteToPref($sPrefFile, 'pref[', ']=', ';', 'Name', 'updated')
		$iPrefUpdateError = @error
		$iPrefAppend = _WriteToPref($sPrefFile, 'pref[', ']=', ';', 'Second', 'added')
		$iPrefAppendError = @error
		$iPrefNoChange = _WriteToPref($sPrefFile, 'pref[', ']=', ';', 'Second', 'added')
		$iPrefNoChangeError = @error
	EndIf
	Local $bPrefUpdate = ($iPrefUpdate = 1 And $iPrefUpdateError = 0 And _
			$iPrefAppend = 1 And $iPrefAppendError = 0 And _
			$iPrefNoChange = 0 And $iPrefNoChangeError = 0 And _
			_FullTestReadFixture($sPrefFile) == ('pref[Name]=updated;' & @CRLF & _
			'pref[Second]=added;' & @CRLF))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPrefUpdate), 'Writer Semantics', _
			'WriteToPref updated, appended and recognized an unchanged value')

	Local $iRegHeader = 0, $iRegHeaderError = -1
	Local $iRegRoot = 0, $iRegRootError = -1
	Local $iRegChild = 0, $iRegChildError = -1
	If $bWriterRoot Then
		$iRegHeader = _WriteToReg($sRegFile, $sRegMainKey, '', '', '')
		$iRegHeaderError = @error
		$iRegRoot = _WriteToReg($sRegFile, $sRegMainKey, '', 'RootName', 'RootValue|=')
		$iRegRootError = @error
		$iRegChild = _WriteToReg($sRegFile, $sRegMainKey, 'Child', 'ChildName', 'ChildValue|=')
		$iRegChildError = @error
	EndIf

	Local $sRegText = ''
	If FileExists($sRegFile) Then $sRegText = _FullTestReadFixture($sRegFile)
	Local $aRegLines = StringSplit(StringStripCR($sRegText), @LF, 1)
	Local $aRegExpected[5]
	$aRegExpected[0] = 'REGEDIT4'
	$aRegExpected[1] = '[' & $sRegMainKey & ']'
	$aRegExpected[2] = '"RootName"="RootValue"'
	$aRegExpected[3] = '[' & $sRegMainKey & '\Child]'
	$aRegExpected[4] = '"ChildName"="ChildValue"'
	Local $iRegExpected = 0
	Local $bRegStructure = True
	For $i = 1 To $aRegLines[0]
		If $aRegLines[$i] = '' Then ContinueLoop
		If $iRegExpected >= UBound($aRegExpected) Or _
				Not ($aRegLines[$i] == $aRegExpected[$iRegExpected]) Then
			$bRegStructure = False
			ExitLoop
		EndIf
		$iRegExpected += 1
	Next
	$bRegStructure = ($bRegStructure And $iRegExpected = UBound($aRegExpected) And _
			$iRegHeader = 1 And $iRegHeaderError = 0 And _
			$iRegRoot = 1 And $iRegRootError = 0 And _
			$iRegChild = 1 And $iRegChildError = 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegStructure), 'Writer Semantics', _
			'WriteToReg generated the exact header, key and value structure')

	RegRead($sRegMainKey, 'RootName')
	Local $bRegNotImported = @error <> 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegNotImported), 'Writer Semantics', _
			'Generated REG file was not imported into the registry')
EndFunc   ;==>_FullTestWriterSemanticsRun

Func _FullTestRegistryRun($sWorkspace, $sRegistryRoot, $sRegistryViewRoot, _
		ByRef $sDetails, ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iSkip, _
		ByRef $iNotUsed)
	Local $sRegistryWorkspace = $sWorkspace & '\Registry'
	Local $sTestIni = $sRegistryWorkspace & '\RegistryTest.ini'
	Local $sView32Reg = $sRegistryWorkspace & '\View32.reg'
	Local $sView64Reg = $sRegistryWorkspace & '\View64.reg'
	Local $sView32Export = $sRegistryWorkspace & '\View32Export.reg'
	Local $sView64Export = $sRegistryWorkspace & '\View64Export.reg'
	Local $sNormalOneReg = $sRegistryWorkspace & '\NormalOne.reg'
	Local $sNormalTwoReg = $sRegistryWorkspace & '\NormalTwo.reg'
	Local $sRecoveryReg = $sRegistryWorkspace & '\Recovery.reg'
	Local $sNormalBackup = $sRegistryWorkspace & '\NormalBackup'
	Local $sRecoveryBackup = $sRegistryWorkspace & '\RecoveryBackup'
	Local $sNormalRootA = $sRegistryRoot & '\TransactionA'
	Local $sNormalRootB = $sRegistryRoot & '\TransactionB'
	Local $sRecoveryRoot = $sRegistryRoot & '\Recovery'
	Local $sNormalFiles = $sNormalOneReg & ';NormalTwo.reg'

	Local $bBoundary = _FullTestPathIsInside($sRegistryWorkspace, $sWorkspace) And _
			_FullTestPathIsInside($sTestIni, $sWorkspace) And _
			_FullTestPathIsInside($sView32Reg, $sWorkspace) And _
			_FullTestPathIsInside($sView64Reg, $sWorkspace) And _
			_FullTestPathIsInside($sView32Export, $sWorkspace) And _
			_FullTestPathIsInside($sView64Export, $sWorkspace) And _
			_FullTestPathIsInside($sNormalOneReg, $sWorkspace) And _
			_FullTestPathIsInside($sNormalTwoReg, $sWorkspace) And _
			_FullTestPathIsInside($sRecoveryReg, $sWorkspace) And _
			_FullTestPathIsInside($sNormalBackup, $sWorkspace) And _
			_FullTestPathIsInside($sRecoveryBackup, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Registry', _
			'Every fixture and transaction path passed the isolated workspace boundary check')

	Local $bRegistryWorkspace = False
	Local $bFixtures = False
	If $bBoundary Then
		$bRegistryWorkspace = DirCreate($sRegistryWorkspace) = 1
		If $bRegistryWorkspace Then
			$bFixtures = _FullTestWriteFixture($sTestIni, _
					'[Options]' & @CRLF & 'RegView=Native' & @CRLF) And _
					_FullTestWriteFixture($sView32Reg, 'REGEDIT4' & @CRLF & @CRLF & _
					'[' & $sRegistryViewRoot & ']' & @CRLF & _
					'"State"="VIEW32"' & @CRLF) And _
					_FullTestWriteFixture($sView64Reg, 'REGEDIT4' & @CRLF & @CRLF & _
					'[' & $sRegistryViewRoot & ']' & @CRLF & _
					'"State"="VIEW64"' & @CRLF) And _
					_FullTestWriteFixture($sNormalOneReg, 'REGEDIT4' & @CRLF & @CRLF & _
					'[' & $sNormalRootA & ']' & @CRLF & _
					'"State"="PORTABLE_A"' & @CRLF & _
					'"PortableOnly"="ONE"' & @CRLF) And _
					_FullTestWriteFixture($sNormalTwoReg, 'REGEDIT4' & @CRLF & @CRLF & _
					'[' & $sNormalRootB & ']' & @CRLF & _
					'"State"="PORTABLE_B"' & @CRLF & _
					'"PortableOnly"="TWO"' & @CRLF) And _
					_FullTestWriteFixture($sRecoveryReg, 'REGEDIT4' & @CRLF & @CRLF & _
					'[' & $sRecoveryRoot & ']' & @CRLF & _
					'"State"="PORTABLE_RECOVERY"' & @CRLF & _
					'"PortableOnly"="RECOVERY"' & @CRLF)
		EndIf
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegistryWorkspace And $bFixtures), 'Registry', _
			'Isolated registry fixtures were created')

	; A configured external registry manager must not participate in Full Test.
	; The selected application INI remains report context only.
	Local $sOriginalScriptIni = $ScriptIni
	Local $sOriginalRegView = $RegView
	$ScriptIni = $sTestIni

	Local $sView32Option = '', $sView64Option = ''
	Local $sView32Tool = '', $sView64Tool = ''
	$RegView = '32'
	$sView32Option = _RegViewOption()
	$sView32Tool = _RegExePath(True)
	$RegView = '64'
	$sView64Option = _RegViewOption()
	$sView64Tool = _RegExePath(True)
	Local $bViewRouting = (@OSArch = 'X64' And $sView32Option = ' /reg:32' And _
			$sView64Option = ' /reg:64' And _
			StringInStr(StringLower($sView32Tool), '\syswow64\reg.exe') > 0 And _
			(StringInStr(StringLower($sView64Tool), '\system32\reg.exe') > 0 Or _
			StringInStr(StringLower($sView64Tool), '\sysnative\reg.exe') > 0))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bViewRouting), 'Registry View', _
			'32-bit and 64-bit registry commands selected the requested views')

	Local $iView32Import = 0, $iView32ImportError = -1
	Local $iView64Import = 0, $iView64ImportError = -1
	Local $iView32Export = 0, $iView32ExportError = -1
	Local $iView64Export = 0, $iView64ExportError = -1
	If $bFixtures And $bViewRouting Then
		$RegView = '32'
		$iView32Import = _RegEdit($sView32Reg)
		$iView32ImportError = @error
		$RegView = '64'
		$iView64Import = _RegEdit($sView64Reg)
		$iView64ImportError = @error
		$RegView = '32'
		$iView32Export = _RegEdit($sView32Export, 'EXPORT', $sRegistryViewRoot)
		$iView32ExportError = @error
		$RegView = '64'
		$iView64Export = _RegEdit($sView64Export, 'EXPORT', $sRegistryViewRoot)
		$iView64ExportError = @error
	EndIf
	Local $sView32Text = _FullTestReadFixture($sView32Export)
	Local $sView64Text = _FullTestReadFixture($sView64Export)
	Local $bViewIsolation = ($iView32Import = 1 And $iView32ImportError = 0 And _
			$iView64Import = 1 And $iView64ImportError = 0 And _
			$iView32Export = 1 And $iView32ExportError = 0 And _
			$iView64Export = 1 And $iView64ExportError = 0 And _
			StringInStr($sView32Text, 'VIEW32', 1) > 0 And _
			StringInStr($sView32Text, 'VIEW64', 1) = 0 And _
			StringInStr($sView64Text, 'VIEW64', 1) > 0 And _
			StringInStr($sView64Text, 'VIEW32', 1) = 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bViewIsolation), 'Registry View', _
			'32-bit and 64-bit values remained isolated in separate registry views')

	Local $bViewCleanup = True
	$RegView = '32'
	If _RegKeyExists($sRegistryViewRoot) Then $bViewCleanup = _RegKeyDelete($sRegistryViewRoot)
	If _RegKeyExists($sRegistryViewRoot) Then $bViewCleanup = False
	$RegView = '64'
	If _RegKeyExists($sRegistryViewRoot) Then _
			$bViewCleanup = _RegKeyDelete($sRegistryViewRoot) And $bViewCleanup
	If _RegKeyExists($sRegistryViewRoot) Then $bViewCleanup = False
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bViewCleanup), 'Registry View', _
			'View-isolation keys were removed from both registry views')

	$RegView = 'Native'
	Local $bHostRoots = (RegWrite($sNormalRootA, 'State', 'REG_SZ', 'HOST_A') = 1 And _
			RegWrite($sNormalRootA, 'HostOnly', 'REG_SZ', 'KEEP_A') = 1 And _
			RegWrite($sNormalRootB, 'State', 'REG_SZ', 'HOST_B') = 1 And _
			RegWrite($sNormalRootB, 'HostOnly', 'REG_SZ', 'KEEP_B') = 1)
	Local $iNormalInstall = 0, $iNormalInstallError = -1
	If $bFixtures And $bHostRoots Then
		$iNormalInstall = _RegFileInstall($sNormalFiles, $sNormalBackup)
		$iNormalInstallError = @error
	EndIf
	Local $sNormalAState = RegRead($sNormalRootA, 'State')
	Local $iNormalAError = @error
	Local $sNormalBState = RegRead($sNormalRootB, 'State')
	Local $iNormalBError = @error
	Local $sPortableA = RegRead($sNormalRootA, 'PortableOnly')
	Local $iPortableAInstallError = @error
	Local $sPortableB = RegRead($sNormalRootB, 'PortableOnly')
	Local $iPortableBInstallError = @error
	Local $bNormalInstalled = ($iNormalInstall = 1 And $iNormalInstallError = 0 And _
			$iNormalAError = 0 And $sNormalAState == 'PORTABLE_A' And _
			$iNormalBError = 0 And $sNormalBState == 'PORTABLE_B' And _
			$iPortableAInstallError = 0 And $sPortableA == 'ONE' And _
			$iPortableBInstallError = 0 And $sPortableB == 'TWO')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bNormalInstalled), 'Registry Transaction', _
			'Portable values replaced both protected host roots')

	Local $sNormalManifest = $sNormalBackup & '\transaction.ini'
	Local $sBackupOneName = IniRead($sNormalManifest, 'Backups', 'Backup1', '')
	Local $sBackupTwoName = IniRead($sNormalManifest, 'Backups', 'Backup2', '')
	Local $sBackupOne = $sNormalBackup & '\' & $sBackupOneName
	Local $sBackupTwo = $sNormalBackup & '\' & $sBackupTwoName
	Local $sBackupOneText = _FullTestReadFixture($sBackupOne)
	Local $sBackupTwoText = _FullTestReadFixture($sBackupTwo)
	Local $bManifestOrder = (FileExists($sNormalManifest) And _
			IniRead($sNormalManifest, 'Transaction', 'Pending', '') = 'true' And _
			IniRead($sNormalManifest, 'Transaction', 'RegView', '') = 'Native' And _
			IniRead($sNormalManifest, 'Transaction', 'BackupCount', '') = '2' And _
			IniRead($sNormalManifest, 'Keys', 'Key1', '') == $sNormalRootA And _
			IniRead($sNormalManifest, 'Keys', 'Key2', '') == $sNormalRootB And _
			$sBackupOneName <> '' And $sBackupTwoName <> '' And _
			StringLower($sBackupOneName) <> StringLower($sBackupTwoName) And _
			FileExists($sBackupOne) And FileExists($sBackupTwo) And _
			StringInStr($sBackupOneText, 'HOST_A', 1) > 0 And _
			StringInStr($sBackupTwoText, 'HOST_B', 1) > 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bManifestOrder), 'Registry Transaction', _
			'Transaction manifest recorded Native view and ordered distinct backups')

	Local $bRuntimeValues = False
	If $bNormalInstalled Then
		$bRuntimeValues = (RegWrite($sNormalRootA, 'State', 'REG_SZ', 'RUNTIME_A') = 1 And _
				RegWrite($sNormalRootB, 'State', 'REG_SZ', 'RUNTIME_B') = 1)
	EndIf
	Local $iNormalRestore = 0, $iNormalRestoreError = -1
	If $bRuntimeValues Then
		$iNormalRestore = _RegFileRestore($sNormalFiles, $sNormalBackup)
		$iNormalRestoreError = @error
	EndIf
	Local $sRestoredA = RegRead($sNormalRootA, 'State')
	Local $iRestoredAError = @error
	Local $sRestoredB = RegRead($sNormalRootB, 'State')
	Local $iRestoredBError = @error
	RegRead($sNormalRootA, 'PortableOnly')
	Local $iPortableAError = @error
	RegRead($sNormalRootB, 'PortableOnly')
	Local $iPortableBError = @error
	Local $sHostOnlyA = RegRead($sNormalRootA, 'HostOnly')
	Local $iHostOnlyAError = @error
	Local $sHostOnlyB = RegRead($sNormalRootB, 'HostOnly')
	Local $iHostOnlyBError = @error
	Local $bNormalRestored = ($iNormalRestore = 1 And $iNormalRestoreError = 0 And _
			$iRestoredAError = 0 And $sRestoredA == 'HOST_A' And _
			$iRestoredBError = 0 And $sRestoredB == 'HOST_B' And _
			$iPortableAError <> 0 And $iPortableBError <> 0 And _
			$iHostOnlyAError = 0 And $sHostOnlyA == 'KEEP_A' And _
			$iHostOnlyBError = 0 And $sHostOnlyB == 'KEEP_B')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bNormalRestored), 'Registry Restore', _
			'Normal close restored both host roots in manifest order')

	Local $sSavedNormalOne = _FullTestReadFixture($sNormalOneReg)
	Local $sSavedNormalTwo = _FullTestReadFixture($sNormalTwoReg)
	Local $bPortableSaved = (StringInStr($sSavedNormalOne, 'RUNTIME_A', 1) > 0 And _
			StringInStr($sSavedNormalTwo, 'RUNTIME_B', 1) > 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPortableSaved), 'Registry Restore', _
			'Normal close saved current portable values back to both REG files')
	Local $bNormalCleanup = Not FileExists($sNormalBackup)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bNormalCleanup), 'Registry Restore', _
			'Normal transaction data was removed after successful restore')

	Local $bRecoveryHost = RegWrite($sRecoveryRoot, 'State', 'REG_SZ', 'HOST_RECOVERY') = 1
	Local $iRecoveryInstall = 0, $iRecoveryInstallError = -1
	If $bFixtures And $bRecoveryHost Then
		$iRecoveryInstall = _RegFileInstall($sRecoveryReg, $sRecoveryBackup)
		$iRecoveryInstallError = @error
	EndIf
	Local $sRecoveryPortable = RegRead($sRecoveryRoot, 'State')
	Local $iRecoveryPortableError = @error
	Local $bRecoveryPending = ($iRecoveryInstall = 1 And $iRecoveryInstallError = 0 And _
			$iRecoveryPortableError = 0 And $sRecoveryPortable == 'PORTABLE_RECOVERY' And _
			IniRead($sRecoveryBackup & '\transaction.ini', 'Transaction', 'Pending', '') = 'true')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRecoveryPending), 'Registry Recovery', _
			'Interrupted transaction fixture installed portable state with a pending marker')

	Local $iRecoveryResult = 0, $iRecoveryError = -1
	$RegView = '64'
	If $bRecoveryPending Then
		$iRecoveryResult = _RegTransactionRecover($sRecoveryBackup)
		$iRecoveryError = @error
	EndIf
	Local $bCallerViewRestored = $RegView = '64'
	$RegView = 'Native'
	Local $sRecoveredState = RegRead($sRecoveryRoot, 'State')
	Local $iRecoveredStateError = @error
	RegRead($sRecoveryRoot, 'PortableOnly')
	Local $iRecoveredPortableError = @error
	Local $bRecoveryRestored = ($iRecoveryResult = 1 And $iRecoveryError = 0 And _
			$bCallerViewRestored And $iRecoveredStateError = 0 And _
			$sRecoveredState == 'HOST_RECOVERY' And $iRecoveredPortableError <> 0 And _
			Not FileExists($sRecoveryBackup))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRecoveryRestored), 'Registry Recovery', _
			'Recovery used the saved view, restored the caller view and removed transaction data')

	; Best-effort cleanup remains scoped to this unique Full Test session.
	If FileExists($sNormalBackup & '\transaction.ini') Then _RegTransactionRecover($sNormalBackup)
	If FileExists($sRecoveryBackup & '\transaction.ini') Then _RegTransactionRecover($sRecoveryBackup)
	$RegView = '32'
	If _RegKeyExists($sRegistryViewRoot) Then _RegKeyDelete($sRegistryViewRoot)
	$RegView = '64'
	If _RegKeyExists($sRegistryViewRoot) Then _RegKeyDelete($sRegistryViewRoot)
	$RegView = $sOriginalRegView
	$ScriptIni = $sOriginalScriptIni
EndFunc   ;==>_FullTestRegistryRun

Func _FullTestEnvironmentPathRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sPathRoot = $sWorkspace & '\EnvironmentPath'
	Local $sIniFile = $sPathRoot & '\Expansion.ini'
	Local $sOrdinaryDir = $sPathRoot & '\Ordinary'
	Local $sWildcardDir = $sPathRoot & '\Wildcard'
	Local $sOtherDir = $sPathRoot & '\Other'
	Local $sOrdinaryFile = $sOrdinaryDir & '\Plain.txt'
	Local $sWildcardFile = $sWildcardDir & '\Wild.txt'
	Local $sEnvironmentName = 'XLAUNCHER_SELFTEST_PATH_ENV'
	Local $sSetEnvironmentName = 'XLAUNCHER_SELFTEST_SET_ENV'

	Local $bBoundary = _FullTestPathIsInside($sPathRoot, $sWorkspace) And _
			_FullTestPathIsInside($sIniFile, $sWorkspace) And _
			_FullTestPathIsInside($sOrdinaryFile, $sWorkspace) And _
			_FullTestPathIsInside($sWildcardFile, $sWorkspace) And _
			_FullTestPathIsInside($sOtherDir, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Environment Path', _
			'Every fixture passed the isolated workspace boundary check')

	Local $sOriginalRoot = $Root
	Local $sOriginalLib = $Lib
	Local $sOriginalWorkingDir = @WorkingDir
	Local $sOriginalPath = EnvGet('PATH')
	Local $sOriginalEnvironment = EnvGet($sEnvironmentName)
	Local $sOriginalSetEnvironment = EnvGet($sSetEnvironmentName)
	Local $sOriginalLocalAppData = EnvGet('LOCALAPPDATA')
	Local $sOriginalTempEnvironment = EnvGet('TEMP')
	Local $sOriginalTmpEnvironment = EnvGet('TMP')
	Local $iOriginalExpandEnv = AutoItSetOption('ExpandEnvStrings', 0)
	Local $iOriginalExpandVar = AutoItSetOption('ExpandVarStrings', 0)

	Local $bFixtures = False
	If $bBoundary Then
		Local $bDirectories = (DirCreate($sOrdinaryDir) = 1 And _
				DirCreate($sWildcardDir) = 1 And DirCreate($sOtherDir) = 1)
		If $bDirectories Then
			$bFixtures = _FullTestWriteFixture($sOrdinaryFile, 'ordinary') And _
					_FullTestWriteFixture($sWildcardFile, 'wildcard') And _
					_FullTestWriteFixture($sIniFile, '[Expansion]' & @CRLF & _
					'Environment=%XLAUNCHER_SELFTEST_PATH_ENV%\EnvChild' & @CRLF & _
					'Root=$Root$\RootChild' & @CRLF & _
					'Lib=$Lib$\LibChild' & @CRLF)
		EndIf
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Environment Path', _
			'Isolated environment and path fixtures were created')

	$Root = $sPathRoot
	$Lib = $sPathRoot & '\LibraryRoot'
	EnvSet($sEnvironmentName, $sPathRoot)
	AutoItSetOption('ExpandEnvStrings', 1)
	AutoItSetOption('ExpandVarStrings', 1)

	Local $sExpandedEnvironment = IniRead($sIniFile, 'Expansion', 'Environment', '')
	Local $bEnvironmentExpansion = $sExpandedEnvironment == $sPathRoot & '\EnvChild'
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bEnvironmentExpansion), 'Environment Path', _
			'Environment-variable text expanded to the isolated workspace')

	Local $sExpandedRoot = IniRead($sIniFile, 'Expansion', 'Root', '')
	Local $sExpandedLib = IniRead($sIniFile, 'Expansion', 'Lib', '')
	Local $bLauncherExpansion = ($sExpandedRoot == $sPathRoot & '\RootChild' And _
			$sExpandedLib == $Lib & '\LibChild')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bLauncherExpansion), 'Environment Path', _
			'Root and Lib launcher variables expanded inside INI values')

	Local $sRelativePath = _FullPath('.\Relative\File.txt', $sPathRoot)
	Local $iRelativeError = @error
	Local $sAbsoluteExpected = $sPathRoot & '\Absolute\File.txt'
	Local $sAbsolutePath = _FullPath($sAbsoluteExpected, $sPathRoot)
	Local $iAbsoluteError = @error
	Local $sParentPath = _FullPath('..\Sibling\File.txt', $sPathRoot & '\Child')
	Local $iParentError = @error
	Local $bFullPath = ($iRelativeError = 0 And _
			$sRelativePath == $sPathRoot & '\Relative\File.txt' And _
			$iAbsoluteError = 0 And $sAbsolutePath == $sAbsoluteExpected And _
			$iParentError = 0 And $sParentPath == $sPathRoot & '\Sibling\File.txt')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFullPath), 'Environment Path', _
			'FullPath resolved relative, absolute and valid parent paths against the supplied root')

	Local $sForwardPath = _FullPathPlus('.\Option Folder\File.txt|/')
	Local $sLiteralValue = _FullPathPlus('Literal Value|=')
	Local $sQuotedPath = _FullPathPlus('.\Quoted\File.txt|"')
	Local $bFullPathPlus = ($sForwardPath == _
			StringReplace($sPathRoot & '\Option Folder\File.txt', '\', '/') And _
			$sLiteralValue == 'Literal Value' And _
			$sQuotedPath == '"' & $sPathRoot & '\Quoted\File.txt' & '"')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFullPathPlus), 'Environment Path', _
			'FullPathPlus preserved literal mode and applied slash and quote options')

	Local $bChangedDir = FileChangeDir($sOtherDir) = 1
	Local $aAllPaths = _ExpandMultiPath( _
			'.\Ordinary\Plain.txt|.\Wildcard\*.txt', False)
	Local $aExistingPaths = _ExpandMultiPath( _
			'.\Ordinary\Plain.txt|.\Wildcard\*.txt', True)
	FileChangeDir($sOriginalWorkingDir)
	Local $bMultiPath = False
	If $bChangedDir And $aAllPaths[0] = 2 And $aExistingPaths[0] = 2 Then
		$bMultiPath = ($aAllPaths[1] == $sOrdinaryFile And _
				$aAllPaths[2] == $sWildcardFile And _
				$aExistingPaths[1] == $sOrdinaryFile And _
				$aExistingPaths[2] == $sWildcardFile)
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bMultiPath), 'Environment Path', _
			'MultiPath resolved ordinary and wildcard entries against Root instead of the working directory')

	Local $iSetEnvironment = _SetEnv($sSetEnvironmentName, '.\EnvTarget', 'false', '')
	Local $iSetEnvironmentError = @error
	Local $bSetEnvironment = ($iSetEnvironment = 1 And $iSetEnvironmentError = 0 And _
			EnvGet($sSetEnvironmentName) == $sPathRoot & '\EnvTarget')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bSetEnvironment), 'Environment Path', _
			'SetEnv resolved and assigned a process-local path value')

	Local $iBlankEnvironment = _SetEnv('', '.\BlankTarget', 'false', '')
	Local $iBlankEnvironmentError = @error
	Local $bBlankEnvironment = ($iBlankEnvironment = 0 And $iBlankEnvironmentError <> 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBlankEnvironment), 'Environment Path', _
			'Blank environment-variable name was rejected')

	Local $sExpectedPath = $sPathRoot & '\PathOne;' & $sPathRoot & '\PathTwo'
	Local $iSetPath = _SetPath('.\PathOne;.\PathTwo', 'false', '')
	Local $iSetPathError = @error
	Local $bSetPath = ($iSetPath = 1 And $iSetPathError = 0 And _
			EnvGet('PATH') == $sExpectedPath)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bSetPath), 'Environment Path', _
			'SetPath resolved multiple entries and assigned the exact process PATH')

	Local $sExpectedLocalAppData = $Lib & '\AppData\Local'
	Local $sExpectedPortableTemp = $sExpectedLocalAppData & '\Temp'
	EnvSet('LOCALAPPDATA', 'XLAUNCHER_SELFTEST_LOCALAPPDATA')
	EnvSet('TEMP', 'XLAUNCHER_SELFTEST_TEMP')
	EnvSet('TMP', 'XLAUNCHER_SELFTEST_TMP')
	Local $iFixLocalResult = _SetPortableEnvironmentDefaults('true', 'false', _
			$Lib, 'false', '')
	Local $iFixLocalError = @error
	Local $bFixLocal = ($iFixLocalResult = 1 And $iFixLocalError = 0 And _
			EnvGet('LOCALAPPDATA') == $sExpectedLocalAppData And _
			EnvGet('TEMP') == 'XLAUNCHER_SELFTEST_TEMP' And _
			EnvGet('TMP') == 'XLAUNCHER_SELFTEST_TMP' And _
			FileExists($sExpectedLocalAppData))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixLocal), 'Environment Path', _
			'FixLocalAppData redirected only LOCALAPPDATA and created its directory')

	EnvSet('LOCALAPPDATA', 'XLAUNCHER_SELFTEST_LOCALAPPDATA')
	Local $iFixTempResult = _SetPortableEnvironmentDefaults('false', 'true', _
			$Lib, 'false', '')
	Local $iFixTempError = @error
	Local $bFixTemp = ($iFixTempResult = 1 And $iFixTempError = 0 And _
			EnvGet('LOCALAPPDATA') == 'XLAUNCHER_SELFTEST_LOCALAPPDATA' And _
			EnvGet('TEMP') == $sExpectedPortableTemp And _
			EnvGet('TMP') == $sExpectedPortableTemp And _
			FileExists($sExpectedPortableTemp))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixTemp), 'Environment Path', _
			'FixTemp redirected both TEMP and TMP independently and created its directory')

	Local $iFixBothResult = _SetPortableEnvironmentDefaults('true', 'true', _
			$Lib, 'false', '')
	Local $iFixBothError = @error
	Local $iOverrideLocal = _SetEnv('LOCALAPPDATA', '.\Override\Local', 'false', '')
	Local $iOverrideLocalError = @error
	Local $iOverrideTemp = _SetEnv('TEMP', '.\Override\Temp', 'false', '')
	Local $iOverrideTempError = @error
	Local $iOverrideTmp = _SetEnv('TMP', '.\Override\Tmp', 'false', '')
	Local $iOverrideTmpError = @error
	Local $bEnvironmentOverride = ($iFixBothResult = 1 And $iFixBothError = 0 And _
			$iOverrideLocal = 1 And $iOverrideLocalError = 0 And _
			$iOverrideTemp = 1 And $iOverrideTempError = 0 And _
			$iOverrideTmp = 1 And $iOverrideTmpError = 0 And _
			EnvGet('LOCALAPPDATA') == $Root & '\Override\Local' And _
			EnvGet('TEMP') == $Root & '\Override\Temp' And _
			EnvGet('TMP') == $Root & '\Override\Tmp')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bEnvironmentOverride), 'Environment Path', _
			'Explicit Environment values overrode portable convenience defaults')

	; Restore every process-local setting before returning to Full Test.
	FileChangeDir($sOriginalWorkingDir)
	EnvSet('PATH', $sOriginalPath)
	EnvSet($sEnvironmentName, $sOriginalEnvironment)
	EnvSet($sSetEnvironmentName, $sOriginalSetEnvironment)
	EnvSet('LOCALAPPDATA', $sOriginalLocalAppData)
	EnvSet('TEMP', $sOriginalTempEnvironment)
	EnvSet('TMP', $sOriginalTmpEnvironment)
	$Root = $sOriginalRoot
	$Lib = $sOriginalLib
	AutoItSetOption('ExpandEnvStrings', $iOriginalExpandEnv)
	AutoItSetOption('ExpandVarStrings', $iOriginalExpandVar)
	Local $iRestoredExpandEnv = AutoItSetOption('ExpandEnvStrings', $iOriginalExpandEnv)
	Local $iRestoredExpandVar = AutoItSetOption('ExpandVarStrings', $iOriginalExpandVar)
	Local $bRestored = (@WorkingDir == $sOriginalWorkingDir And _
			EnvGet('PATH') == $sOriginalPath And _
			EnvGet($sEnvironmentName) == $sOriginalEnvironment And _
			EnvGet($sSetEnvironmentName) == $sOriginalSetEnvironment And _
			EnvGet('LOCALAPPDATA') == $sOriginalLocalAppData And _
			EnvGet('TEMP') == $sOriginalTempEnvironment And _
			EnvGet('TMP') == $sOriginalTmpEnvironment And _
			$Root == $sOriginalRoot And $Lib == $sOriginalLib And _
			$iRestoredExpandEnv = $iOriginalExpandEnv And _
			$iRestoredExpandVar = $iOriginalExpandVar)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRestored), 'Environment Path', _
			'Process environment, working directory and launcher path globals were restored')
EndFunc   ;==>_FullTestEnvironmentPathRun

Func _FullTestPathSafetyRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sSafetyRoot = $sWorkspace & '\PathSafety'
	Local $sDriveFile = $sSafetyRoot & '\DriveScope.txt'
	Local $sNonDriveFile = $sSafetyRoot & '\NonDriveScope.txt'
	Local $sValidProfile = $sSafetyRoot & '\ValidProfile'
	Local $sBlankProfile = $sSafetyRoot & '\BlankProfile'
	Local $sTraversalProfile = $sSafetyRoot & '\TraversalProfile'
	Local $sTraversalVictim = $sSafetyRoot & '\TraversalVictim'
	Local $sNestedProfile = $sSafetyRoot & '\NestedProfile'
	Local $sNestedOld = $sNestedProfile & '\Nested\OldDesktop'
	Local $sUnsafeDestinationProfile = $sSafetyRoot & '\UnsafeDestinationProfile'
	Local $sCleanupRoot = $sSafetyRoot & '\CleanupRoot'
	Local $sCleanupTemp = $sCleanupRoot & '\DisposableTemp'
	Local $sCleanupSentinel = $sCleanupRoot & '\RootSentinel.txt'
	Local $sTempSentinel = $sCleanupTemp & '\TempSentinel.txt'

	Local $bBoundary = _FullTestPathIsInside($sSafetyRoot, $sWorkspace) And _
			_FullTestPathIsInside($sDriveFile, $sWorkspace) And _
			_FullTestPathIsInside($sNonDriveFile, $sWorkspace) And _
			_FullTestPathIsInside($sValidProfile, $sWorkspace) And _
			_FullTestPathIsInside($sTraversalVictim, $sWorkspace) And _
			_FullTestPathIsInside($sUnsafeDestinationProfile, $sWorkspace) And _
			_FullTestPathIsInside($sCleanupSentinel, $sWorkspace) And _
			_FullTestPathIsInside($sTempSentinel, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Path Safety', _
			'Every mutable target passed the isolated workspace boundary check')

	Local $sBaseDrive = StringUpper(StringLeft($sSafetyRoot, 1))
	Local $sFixtureDrive = 'Z'
	If $sBaseDrive = 'Z' Then $sFixtureDrive = 'C'
	Local $sDriveFixture = 'valid=' & $sFixtureDrive & ':\Portable\Data' & @CRLF & _
			'embedded=ABC:\NotAPath' & @CRLF & _
			'url=https://example.test/C:/docs' & @CRLF
	Local $bFixtures = False
	If $bBoundary Then
		$bFixtures = DirCreate($sValidProfile & '\OldDesktop') = 1 And _
				DirCreate($sBlankProfile) = 1 And _
				DirCreate($sTraversalProfile) = 1 And _
				DirCreate($sTraversalVictim) = 1 And _
				DirCreate($sNestedOld) = 1 And _
				DirCreate($sUnsafeDestinationProfile & '\OldDesktop') = 1 And _
				DirCreate($sCleanupTemp) = 1
		$bFixtures = _FullTestWriteFixture($sDriveFile, $sDriveFixture) And $bFixtures
		$bFixtures = _FullTestWriteFixture($sNonDriveFile, 'sentinel') And $bFixtures
		$bFixtures = _FullTestWriteFixture($sValidProfile & '\OldDesktop\Sentinel.txt', _
				'valid') And $bFixtures
		$bFixtures = IniWrite($sValidProfile & '\x-launcher.cfg', 'UserProfile', _
				'Desktop', 'OldDesktop') = 1 And $bFixtures
		$bFixtures = _FullTestWriteFixture($sBlankProfile & '\RootSentinel.txt', _
				'blank') And $bFixtures
		$bFixtures = IniWrite($sBlankProfile & '\x-launcher.cfg', 'UserProfile', _
				'Desktop', '') = 1 And $bFixtures
		$bFixtures = _FullTestWriteFixture($sTraversalVictim & '\Sentinel.txt', _
				'traversal') And $bFixtures
		$bFixtures = IniWrite($sTraversalProfile & '\x-launcher.cfg', 'UserProfile', _
				'Desktop', '..\TraversalVictim') = 1 And $bFixtures
		$bFixtures = _FullTestWriteFixture($sNestedOld & '\Sentinel.txt', _
				'nested') And $bFixtures
		$bFixtures = IniWrite($sNestedProfile & '\x-launcher.cfg', 'UserProfile', _
				'Desktop', 'Nested\OldDesktop') = 1 And $bFixtures
		$bFixtures = _FullTestWriteFixture($sUnsafeDestinationProfile & _
				'\OldDesktop\Sentinel.txt', 'unsafe-destination') And $bFixtures
		$bFixtures = IniWrite($sUnsafeDestinationProfile & '\x-launcher.cfg', _
				'UserProfile', 'Desktop', 'OldDesktop') = 1 And $bFixtures
		$bFixtures = _FullTestWriteFixture($sCleanupSentinel, 'root') And $bFixtures
		$bFixtures = _FullTestWriteFixture($sTempSentinel, 'temp') And $bFixtures
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Path Safety', _
			'Isolated path and cleanup fixtures were created')

	Local $sUNCFile = '\\server\share\folder\file.txt'
	Local $sUNCResult = _FullPath($sUNCFile, $sSafetyRoot)
	Local $iUNCError = @error
	Local $bUNCFullPath = ($sUNCResult == $sUNCFile And $iUNCError = 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bUNCFullPath), 'Path Safety', _
			'FullPath preserved a direct UNC path without accessing the network')

	Local $bUNCParts = (_NormalPath('//server/share//folder/file.txt') == $sUNCFile And _
			_FileInfo($sUNCFile, 0) == '\\server\share\folder')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bUNCParts), 'Path Safety', _
			'NormalPath and FileInfo retained the UNC prefix and parent')

	Local $sValidParent = _FullPath('..\Target', 'C:\Base\Child')
	Local $iValidParentError = @error
	Local $sExcessiveParent = _FullPath('..\..\..\Target', 'C:\Base')
	Local $iExcessiveParentError = @error
	Local $bTraversal = ($sValidParent == 'C:\Base\Target' And _
			$iValidParentError = 0 And $sExcessiveParent = '' And _
			$iExcessiveParentError = 10)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bTraversal), 'Path Safety', _
			'Valid parent traversal resolved and excessive traversal returned a nonfatal error')

	Local $iDriveResult = 0, $iDriveError = 0, $sDriveResult = ''
	If $bFixtures Then
		$iDriveResult = _FixDriveLetter($sDriveFile, $sSafetyRoot)
		$iDriveError = @error
		$sDriveResult = _FullTestReadFixture($sDriveFile)
	EndIf
	Local $bDriveRewrite = ($bFixtures And $iDriveResult = 1 And $iDriveError = 0 And _
			StringInStr($sDriveResult, 'valid=' & $sBaseDrive & ':\Portable\Data', 1) > 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDriveRewrite), 'Path Safety', _
			'FixDriveLetter rewrote an absolute drive path to the current isolated drive')

	Local $bDriveScope = ($bFixtures And _
			StringInStr($sDriveResult, 'embedded=ABC:\NotAPath', 1) > 0 And _
			StringInStr($sDriveResult, 'url=https://example.test/C:/docs', 1) > 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDriveScope), 'Path Safety', _
			'FixDriveLetter preserved embedded drive-like text and URL segments')

	Local $iNonDriveResult = 0, $iNonDriveError = 0
	If $bFixtures Then
		$iNonDriveResult = _FixDriveLetter($sNonDriveFile, '\\server\share')
		$iNonDriveError = @error
	EndIf
	Local $bNonDrive = ($bFixtures And $iNonDriveResult = 0 And $iNonDriveError = 1 And _
			_FullTestReadFixture($sNonDriveFile) == 'sentinel')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bNonDrive), 'Path Safety', _
			'FixDriveLetter rejected a non-drive base without changing the file')

	If $bFixtures Then _FixUserProfile($sValidProfile, 'NewDesktop', 'Desktop')
	Local $bValidProfile = ($bFixtures And Not FileExists($sValidProfile & '\OldDesktop') And _
			_FullTestReadFixture($sValidProfile & '\NewDesktop\Sentinel.txt') == 'valid' And _
			IniRead($sValidProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', '') = _
			'NewDesktop')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bValidProfile), 'Path Safety', _
			'FixUserProfile renamed one valid direct child and updated its preference')

	If $bFixtures Then _FixUserProfile($sBlankProfile, 'NewDesktop', 'Desktop')
	Local $bBlankProfile = ($bFixtures And FileExists($sBlankProfile) And _
			_FullTestReadFixture($sBlankProfile & '\RootSentinel.txt') == 'blank' And _
			Not FileExists($sBlankProfile & '\NewDesktop') And _
			IniRead($sBlankProfile & '\x-launcher.cfg', 'UserProfile', 'Desktop', '') = _
			'NewDesktop')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBlankProfile), 'Path Safety', _
			'FixUserProfile preserved the profile root when the old child was blank')

	If $bFixtures Then
		_FixUserProfile($sTraversalProfile, 'NewDesktop', 'Desktop')
		_FixUserProfile($sNestedProfile, 'NewDesktop', 'Desktop')
	EndIf
	Local $bUnsafeProfiles = ($bFixtures And _
			_FullTestReadFixture($sTraversalVictim & '\Sentinel.txt') == 'traversal' And _
			Not FileExists($sTraversalProfile & '\NewDesktop') And _
			_FullTestReadFixture($sNestedOld & '\Sentinel.txt') == 'nested' And _
			Not FileExists($sNestedProfile & '\NewDesktop'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bUnsafeProfiles), 'Path Safety', _
			'FixUserProfile rejected parent traversal and nested old-source names')

	Local $iUnsafeDestinationResult = 0, $iUnsafeDestinationError = 0
	If $bFixtures Then
		$iUnsafeDestinationResult = _FixUserProfile($sUnsafeDestinationProfile, _
				'Bad' & Chr(21) & 'Desktop', 'Desktop')
		$iUnsafeDestinationError = @error
	EndIf
	Local $bUnsafeDestination = ($bFixtures And $iUnsafeDestinationResult = 0 And _
			$iUnsafeDestinationError = 1 And _
			_FullTestReadFixture($sUnsafeDestinationProfile & _
			'\OldDesktop\Sentinel.txt') == 'unsafe-destination' And _
			IniRead($sUnsafeDestinationProfile & '\x-launcher.cfg', 'UserProfile', _
			'Desktop', '') == 'OldDesktop')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bUnsafeDestination), 'Path Safety', _
			'FixUserProfile rejected a control-character destination without renaming data')

	Local $sOriginalRoot = $Root
	Local $sOriginalTemp = $Temp
	Local $sOriginalHome = $Home
	Local $sOriginalBackup = $Backup
	Local $iProtectedResult = 0, $iProtectedError = 0
	Local $iDisposableResult = 0, $iDisposableError = 0, $iDisposableExtended = 0
	If $bFixtures Then
		$Root = $sCleanupRoot
		$Temp = $sCleanupRoot
		$Home = $sSafetyRoot & '\UnrelatedHome'
		$Backup = $sSafetyRoot & '\UnrelatedBackup'
		$iProtectedResult = _DeleteTempSafe()
		$iProtectedError = @error
		$Temp = $sCleanupTemp
		$iDisposableResult = _DeleteTempSafe()
		$iDisposableError = @error
		$iDisposableExtended = @extended
	EndIf
	Local $bProtectedCleanup = ($bFixtures And $iProtectedResult = 0 And _
			$iProtectedError = 1 And FileExists($sCleanupRoot) And _
			_FullTestReadFixture($sCleanupSentinel) == 'root')
	Local $bDisposableCleanup = ($bFixtures And $iDisposableResult = 1 And _
			$iDisposableError = 0 And $iDisposableExtended = 2 And _
			Not FileExists($sCleanupTemp) And _
			_FullTestReadFixture($sCleanupSentinel) == 'root')

	$Root = $sOriginalRoot
	$Temp = $sOriginalTemp
	$Home = $sOriginalHome
	$Backup = $sOriginalBackup
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bProtectedCleanup), 'Path Safety', _
			'Temp cleanup refused to remove the isolated protected Root')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDisposableCleanup), 'Path Safety', _
			'Temp cleanup removed only the isolated disposable child')

	Local $bGlobalsRestored = ($Root == $sOriginalRoot And $Temp == $sOriginalTemp And _
			$Home == $sOriginalHome And $Backup == $sOriginalBackup)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bGlobalsRestored), 'Path Safety', _
			'Launcher path globals were restored after cleanup checks')
EndFunc   ;==>_FullTestPathSafetyRun

Func _FullTestSplashTrayRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sVisualRoot = $sWorkspace & '\SplashTray'
	Local $sSplashTemp = $sVisualRoot & '\Temp'
	Local $sFallbackImage = $sSplashTemp & '\x-splash.jpg'
	Local $sConfiguredTitle = 'X-Launcher Full Test Splash Configured'
	Local $sDefaultTitle = 'X-Launcher Full Test Splash Defaults'
	Local $sTrayTitle = 'X-Launcher Full Test TrayTip'

	Local $bBoundary = _FullTestPathIsInside($sVisualRoot, $sWorkspace) And _
			_FullTestPathIsInside($sSplashTemp, $sWorkspace) And _
			_FullTestPathIsInside($sFallbackImage, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Splash Tray', _
			'Every mutable visual fixture passed the isolated workspace boundary check')

	Local $bFixtures = False
	If $bBoundary Then $bFixtures = DirCreate($sSplashTemp) = 1
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Splash Tray', _
			'Isolated splash fallback directory was created')

	Local $nConfiguredElapsed = 999999
	Local $hConfiguredSplash = 0
	Local $aConfiguredSize = 0
	If $bFixtures Then
		Local $hConfiguredTimer = TimerInit()
		_SplashScreen($sConfiguredTitle, '', 5000, $sSplashTemp, $sVisualRoot, 421, 257)
		$nConfiguredElapsed = TimerDiff($hConfiguredTimer)
		$hConfiguredSplash = WinGetHandle($sConfiguredTitle)
		If $hConfiguredSplash <> 0 Then $aConfiguredSize = WinGetClientSize($hConfiguredSplash)
	EndIf

	Local $bFallback = ($bFixtures And FileExists($sFallbackImage) And _
			_FullTestPathIsInside($sFallbackImage, $sWorkspace))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFallback), 'Splash Tray', _
			'Splash fallback image was extracted only to the supplied isolated Temp')

	Local $bNonBlocking = ($bFixtures And $nConfiguredElapsed < 2000)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bNonBlocking), 'Splash Tray', _
			'Splash creation returned without waiting for its configured timeout', _
			'elapsed-ms=' & Int($nConfiguredElapsed))

	Local $bConfiguredTitle = ($hConfiguredSplash <> 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bConfiguredTitle), 'Splash Tray', _
			'Splash used the configured window title')

	Local $bConfiguredSize = False
	If IsArray($aConfiguredSize) Then
		$bConfiguredSize = ($aConfiguredSize[0] = 421 And $aConfiguredSize[1] = 257)
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bConfiguredSize), 'Splash Tray', _
			'Splash used the configured client width and height')
	_SplashScreenOff()

	Local $hDefaultSplash = 0
	Local $aDefaultSize = 0
	If $bFallback Then
		_SplashScreen($sDefaultTitle, $sFallbackImage, 5000, $sSplashTemp, _
				$sVisualRoot, '', '')
		$hDefaultSplash = WinGetHandle($sDefaultTitle)
		If $hDefaultSplash <> 0 Then $aDefaultSize = WinGetClientSize($hDefaultSplash)
	EndIf
	Local $bDefaultSize = False
	If IsArray($aDefaultSize) Then
		$bDefaultSize = ($aDefaultSize[0] = 307 And $aDefaultSize[1] = 213)
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDefaultSize), 'Splash Tray', _
			'Blank splash dimensions used the image''s natural size')
	_SplashScreenOff()
	Sleep(50)

	Local $bSplashClosed = (WinGetHandle($sConfiguredTitle) = 0 And _
			WinGetHandle($sDefaultTitle) = 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bSplashClosed), 'Splash Tray', _
			'Splash windows and timeout callbacks were closed after inspection')

	Local $hTrayTimer = TimerInit()
	Local $bTrayResult = _TrayTipOn($sTrayTitle, 2500)
	Local $nTrayElapsed = TimerDiff($hTrayTimer)
	_TrayTipOff()
	Local $bTrayNonBlocking = ($bTrayResult And $nTrayElapsed < 2000)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bTrayNonBlocking), 'Splash Tray', _
			'TrayTip accepted a millisecond duration and returned without blocking', _
			'elapsed-ms=' & Int($nTrayElapsed))
EndFunc   ;==>_FullTestSplashTrayRun

Func _FullTestBuildJavaRuntime($sPath, $sMarker)
	If DirCreate($sPath & '\bin') <> 1 Then Return False
	Local $bCreated = _FullTestWriteFixture($sPath & '\bin\java.exe', _
			'java-' & $sMarker)
	$bCreated = _FullTestWriteFixture($sPath & '\bin\javaw.exe', _
			'javaw-' & $sMarker) And $bCreated
	Return $bCreated
EndFunc   ;==>_FullTestBuildJavaRuntime

Func _FullTestJavaPathRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sJavaRoot = $sWorkspace & '\JavaPath'
	Local $sExternal64 = $sJavaRoot & '\External\Java64'
	Local $sRelativeRoot = $sJavaRoot & '\RelativeRoot'
	Local $sExternal32 = $sRelativeRoot & '\CommonFiles\Java'
	Local $sIncomplete = $sJavaRoot & '\Incomplete'
	Local $sFakeLauncher = $sJavaRoot & '\JavaPortableLauncher.exe'
	Local $sSelectionRoot = $sJavaRoot & '\SelectionRoot'
	Local $sSelectionLib = $sJavaRoot & '\SelectionLib'
	Local $sPackRuntime = $sSelectionLib & '\Java'
	Local $sSystemRuntime = $sJavaRoot & '\SystemRuntime'
	Local $sSelectionIni = $sJavaRoot & '\JavaPathSelection.ini'

	Local $bBoundary = _FullTestPathIsInside($sJavaRoot, $sWorkspace) And _
			_FullTestPathIsInside($sExternal64, $sWorkspace) And _
			_FullTestPathIsInside($sExternal32, $sWorkspace) And _
			_FullTestPathIsInside($sIncomplete, $sWorkspace) And _
			_FullTestPathIsInside($sFakeLauncher, $sWorkspace) And _
			_FullTestPathIsInside($sPackRuntime, $sWorkspace) And _
			_FullTestPathIsInside($sSystemRuntime, $sWorkspace) And _
			_FullTestPathIsInside($sSelectionIni, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Java Path', _
			'Every JavaPath fixture passed the isolated workspace boundary check')

	Local $bFixtures = False
	If $bBoundary Then
		$bFixtures = _FullTestBuildJavaRuntime($sExternal64, 'external64') And _
				_FullTestBuildJavaRuntime($sExternal32, 'external32') And _
				_FullTestBuildJavaRuntime($sSystemRuntime, 'system')
		$bFixtures = DirCreate($sIncomplete & '\bin') = 1 And $bFixtures
		$bFixtures = _FullTestWriteFixture($sIncomplete & '\bin\java.exe', _
				'incomplete') And $bFixtures
		$bFixtures = _FullTestWriteFixture($sFakeLauncher, 'launcher') And $bFixtures
		$bFixtures = IniWrite($sSelectionIni, 'Options', 'Java', 'true') = 1 And _
				$bFixtures
		$bFixtures = IniWrite($sSelectionIni, 'Options', 'JavaPath', _
				$sExternal64 & '\bin\javaw.exe') = 1 And $bFixtures
		$bFixtures = IniWrite($sSelectionIni, 'Options', 'JavaURL', _
				'https://example.invalid/java-runtime.zip') = 1 And $bFixtures
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Java Path', _
			'Isolated JavaPath runtime and configuration fixtures were created')

	Local $sAbsolute = _JavaPathResolve($sExternal64, $sJavaRoot)
	Local $iAbsoluteError = @error
	Local $sQuoted = _JavaPathResolve('"' & $sExternal64 & '"', $sJavaRoot)
	Local $iQuotedError = @error
	Local $bAbsolute = ($bFixtures And $iAbsoluteError = 0 And $iQuotedError = 0 And _
			StringLower($sAbsolute) = StringLower($sExternal64) And _
			StringLower($sQuoted) = StringLower($sExternal64))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bAbsolute), 'Java Path', _
			'Absolute and quoted Java64 runtime roots resolved as usable JavaPath values')

	Local $sBin = _JavaPathResolve($sExternal64 & '\bin', $sJavaRoot)
	Local $iBinError = @error
	Local $sJavaExe = _JavaPathResolve($sExternal64 & '\bin\java.exe', $sJavaRoot)
	Local $iJavaExeError = @error
	Local $sJavawExe = _JavaPathResolve($sExternal64 & '\bin\javaw.exe', $sJavaRoot)
	Local $iJavawExeError = @error
	Local $bExecutables = ($bFixtures And $iBinError = 0 And $iJavaExeError = 0 And _
			$iJavawExeError = 0 And StringLower($sJavaExe) = StringLower($sExternal64) And _
			StringLower($sJavawExe) = StringLower($sExternal64) And _
			StringLower($sBin) = StringLower($sExternal64))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bExecutables), 'Java Path', _
			'bin, java.exe and javaw.exe paths normalized to their runtime root')

	Local $sRelative = _JavaPathResolve('CommonFiles\Java', $sRelativeRoot)
	Local $iRelativeError = @error
	Local $sDotRelative = _JavaPathResolve('.\CommonFiles\Java', $sRelativeRoot)
	Local $iDotRelativeError = @error
	Local $bRelative = ($bFixtures And $iRelativeError = 0 And _
			$iDotRelativeError = 0 And StringLower($sRelative) = StringLower($sExternal32) And _
			StringLower($sDotRelative) = StringLower($sExternal32))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRelative), 'Java Path', _
			'Relative Java runtime path resolved against Root')

	_JavaPathResolve($sIncomplete, $sJavaRoot)
	Local $iIncompleteError = @error
	_JavaPathResolve($sFakeLauncher, $sJavaRoot)
	Local $iLauncherError = @error
	Local $bRejected = ($bFixtures And $iIncompleteError <> 0 And $iLauncherError <> 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRejected), 'Java Path', _
			'Incomplete runtime and JavaPortableLauncher executable were rejected')

	Local $sOriginalRoot = $Root
	Local $sOriginalLib = $Lib
	Local $sOriginalJavaHome = EnvGet('JAVA_HOME')
	Local $sOriginalPath = EnvGet('PATH')
	Local $sExternalJavaBefore = _FullTestReadFixture($sExternal64 & '\bin\java.exe')
	Local $sExternalJavawBefore = _FullTestReadFixture($sExternal64 & '\bin\javaw.exe')
	Local $sSelected = '', $iSelectedError = 99, $iSelectedExtended = 0
	If $bFixtures Then
		$Root = $sSelectionRoot
		$Lib = $sSelectionLib
		EnvSet('JAVA_HOME', $sSystemRuntime)
		EnvSet('PATH', '')
		$sSelected = _JavaCheck('X-Launcher Full Self-Test', $sSelectionIni, $Lib, $Root)
		$iSelectedError = @error
		$iSelectedExtended = @extended
	EndIf
	Local $sConfiguredProbe = ''
	Local $iConfiguredProbePass = 0, $iConfiguredProbeFail = 0
	Local $iConfiguredProbeWarn = 0, $iConfiguredProbeNotUsed = 0
	If $bFixtures Then _ProbeValidateJava($sSelectionIni, $sConfiguredProbe, _
			$iConfiguredProbePass, $iConfiguredProbeFail, $iConfiguredProbeWarn, _
			$iConfiguredProbeNotUsed)
	Local $bConfiguredProbe = ($iConfiguredProbeFail = 0 And _
			StringInStr($sConfiguredProbe, _
			'[PASS] [Java] JavaPath resolves to a usable read-only runtime') > 0 And _
			StringInStr($sConfiguredProbe, _
			'[NOT USED] [Java] JavaURL is retained as fallback but not used because JavaPath is usable') > 0)
	Local $bPriority = ($bFixtures And $iSelectedError = 0 And _
			$iSelectedExtended = 10 And StringLower($sSelected) = StringLower($sExternal64) And _
			$bConfiguredProbe)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPriority), 'Java Path', _
			'Configured JavaPath took priority over bundled system and URL sources')

	Local $bBypassed = ($bFixtures And Not FileExists($sPackRuntime) And _
			Not FileExists($sPackRuntime & '\setup\java-download.package'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBypassed), 'Java Path', _
			'Usable JavaPath bypassed JavaURL download staging and JavaGet writes')

	Local $bPackCreated = False
	If $bFixtures Then $bPackCreated = _FullTestBuildJavaRuntime($sPackRuntime, 'pack')
	If $bPackCreated Then IniWrite($sSelectionIni, 'Options', 'Java', 'false')
	Local $sDisabledSelected = ''
	If $bPackCreated Then _
			$sDisabledSelected = _JavaCheck('X-Launcher Full Self-Test', $sSelectionIni, $Lib, $Root)
	Local $sDisabledProbe = ''
	Local $iDisabledProbePass = 0, $iDisabledProbeFail = 0
	Local $iDisabledProbeWarn = 0, $iDisabledProbeNotUsed = 0
	If $bPackCreated Then _ProbeValidateJava($sSelectionIni, $sDisabledProbe, _
			$iDisabledProbePass, $iDisabledProbeFail, $iDisabledProbeWarn, _
			$iDisabledProbeNotUsed)
	Local $bDisabledProbe = ($iDisabledProbeFail = 0 And _
			StringInStr($sDisabledProbe, _
			'[NOT USED] [Java] JavaPath is retained but ignored while Java=false') > 0)
	Local $bDisabled = ($bPackCreated And _
			StringLower($sDisabledSelected) = StringLower($sPackRuntime) And _
			IniRead($sSelectionIni, 'Options', 'JavaPath', '') = _
			$sExternal64 & '\bin\javaw.exe' And $bDisabledProbe)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDisabled), 'Java Path', _
			'Java false ignored but retained the configured JavaPath')

	Local $bReadOnly = ($bFixtures And _
			_FullTestReadFixture($sExternal64 & '\bin\java.exe') = $sExternalJavaBefore And _
			_FullTestReadFixture($sExternal64 & '\bin\javaw.exe') = $sExternalJavawBefore)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bReadOnly), 'Java Path', _
			'External JavaPath runtime files remained byte-identical')

	$Root = $sOriginalRoot
	$Lib = $sOriginalLib
	EnvSet('JAVA_HOME', $sOriginalJavaHome)
	EnvSet('PATH', $sOriginalPath)
	Local $bRestored = ($Root = $sOriginalRoot And $Lib = $sOriginalLib And _
			EnvGet('JAVA_HOME') = $sOriginalJavaHome And EnvGet('PATH') = $sOriginalPath)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRestored), 'Java Path', _
			'JavaPath test globals and process environment were restored')
EndFunc   ;==>_FullTestJavaPathRun

Func _FullTestBuildJavaTransactionRuntime($sPath, $sMarker, $bSetup = False)
	Local $bCreated = _FullTestWriteFixture($sPath & '\release', _
			'release-' & $sMarker)
	$bCreated = _FullTestWriteFixture($sPath & '\bin\java.exe', _
			'java-' & $sMarker) And $bCreated
	$bCreated = _FullTestWriteFixture($sPath & '\bin\javaw.exe', _
			'javaw-' & $sMarker) And $bCreated
	$bCreated = _FullTestWriteFixture($sPath & '\lib\runtime.txt', _
			'lib-' & $sMarker) And $bCreated
	$bCreated = _FullTestWriteFixture($sPath & '\conf\settings.txt', _
			'conf-' & $sMarker) And $bCreated
	$bCreated = _FullTestWriteFixture($sPath & '\legal\notice.txt', _
			'legal-' & $sMarker) And $bCreated
	$bCreated = _FullTestWriteFixture($sPath & '\jmods\module.txt', _
			'jmods-' & $sMarker) And $bCreated
	If $bSetup Then
		$bCreated = _FullTestWriteFixture($sPath & '\setup\package.zip', _
				'setup-' & $sMarker) And $bCreated
		$bCreated = _FullTestWriteFixture($sPath & '\.java-stage\stage.txt', _
				'stage-' & $sMarker) And $bCreated
	EndIf
	Return $bCreated
EndFunc   ;==>_FullTestBuildJavaTransactionRuntime

Func _FullTestJavaTransactionRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sJavaRoot = $sWorkspace & '\JavaTransaction'
	Local $sDirect = $sJavaRoot & '\DirectStage'
	Local $sWrappedStage = $sJavaRoot & '\WrappedStage'
	Local $sWrapped = $sWrappedStage & '\jdk-portable'
	Local $sAmbiguous = $sJavaRoot & '\AmbiguousStage'
	Local $sIncomplete = $sJavaRoot & '\IncompleteStage'
	Local $sPackageDir = $sJavaRoot & '\Packages'
	Local $sZipPackage = $sPackageDir & '\runtime.zip'
	Local $sLegacyPackage = $sPackageDir & '\legacy.exe'
	Local $sInvalidLegacy = $sPackageDir & '\invalid.exe'
	Local $sFailedStage = $sJavaRoot & '\FailedStage'
	Local $sMissing7Zip = $sJavaRoot & '\Missing7z.exe'
	Local $sLive = $sJavaRoot & '\LiveJava'
	Local $sBackup = $sLive & '\old_java'
	Local $sPrepared = $sJavaRoot & '\PreparedRuntime'
	Local $sCancelDest = $sJavaRoot & '\CancelledInstall'
	Local $sOutsideBackup = $sJavaRoot & '\OutsideBackup'

	Local $bBoundary = _FullTestPathIsInside($sJavaRoot, $sWorkspace) And _
			_FullTestPathIsInside($sDirect, $sWorkspace) And _
			_FullTestPathIsInside($sWrapped, $sWorkspace) And _
			_FullTestPathIsInside($sAmbiguous, $sWorkspace) And _
			_FullTestPathIsInside($sIncomplete, $sWorkspace) And _
			_FullTestPathIsInside($sZipPackage, $sWorkspace) And _
			_FullTestPathIsInside($sLegacyPackage, $sWorkspace) And _
			_FullTestPathIsInside($sFailedStage, $sWorkspace) And _
			_FullTestPathIsInside($sLive, $sWorkspace) And _
			_FullTestPathIsInside($sBackup, $sWorkspace) And _
			_FullTestPathIsInside($sPrepared, $sWorkspace) And _
			_FullTestPathIsInside($sCancelDest, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Java Transaction', _
			'Every Java transaction fixture passed the isolated workspace boundary check')

	Local $bFixtures = False
	If $bBoundary Then
		$bFixtures = _FullTestBuildJavaTransactionRuntime($sDirect, 'direct') And _
				_FullTestBuildJavaTransactionRuntime($sWrapped, 'wrapped') And _
				_FullTestBuildJavaTransactionRuntime($sAmbiguous & '\jdk-one', 'one') And _
				_FullTestBuildJavaTransactionRuntime($sAmbiguous & '\jdk-two', 'two') And _
				_FullTestBuildJavaTransactionRuntime($sLive, 'old', True) And _
				_FullTestBuildJavaTransactionRuntime($sPrepared, 'new')
		$bFixtures = _FullTestWriteFixture($sIncomplete & '\bin\java.exe', _
				'incomplete') And $bFixtures
		$bFixtures = _FullTestWriteFixture($sZipPackage, 'zip-package') And $bFixtures
		$bFixtures = _FullTestWriteBinaryHex($sLegacyPackage, '4D5A900003000000') And _
				$bFixtures
		$bFixtures = _FullTestWriteFixture($sInvalidLegacy, 'not-an-executable') And _
				$bFixtures
		$bFixtures = _FullTestWriteFixture($sFailedStage & '\stale.txt', 'stale') And _
				$bFixtures
		$bFixtures = _FullTestWriteFixture($sCancelDest & '\sentinel.txt', _
				'cancel-destination') And $bFixtures
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Java Transaction', _
			'Isolated runtime package staging backup and rollback fixtures were created')

	Local $bURLs = (_JavaURLValid('http://example.invalid/java.zip') And _
			_JavaURLValid('https://example.invalid/java.zip') And _
			Not _JavaURLValid('ftp://example.invalid/java.zip') And _
			Not _JavaURLValid('file:///C:/java.zip') And Not _JavaURLValid(''))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bURLs), 'Java Transaction', _
			'JavaURL accepted only direct HTTP and HTTPS values without network access')

	Local $sFoundPackage = _SearchSetup($sPackageDir & '\*.zip')
	Local $iPackageError = @error
	Local $bPackages = ($bFixtures And $iPackageError = 0 And _
			StringLower($sFoundPackage) = StringLower($sZipPackage) And _
			_JavaLegacyPackage($sLegacyPackage) And Not _JavaLegacyPackage($sInvalidLegacy))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPackages), 'Java Transaction', _
			'Local ZIP and MZ legacy setup packages were recognized without execution')

	Local $sDirectResult = _JavaFindRuntimeRoot($sDirect)
	Local $iDirectError = @error
	Local $sWrappedResult = _JavaFindRuntimeRoot($sWrappedStage)
	Local $iWrappedError = @error
	Local $bLayouts = ($bFixtures And $iDirectError = 0 And $iWrappedError = 0 And _
			StringLower($sDirectResult) = StringLower($sDirect) And _
			StringLower($sWrappedResult) = StringLower($sWrapped))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bLayouts), 'Java Transaction', _
			'Direct and single-wrapper staged runtime layouts were accepted')

	_JavaFindRuntimeRoot($sAmbiguous)
	Local $iAmbiguousError = @error
	_JavaFindRuntimeRoot($sIncomplete)
	Local $iIncompleteError = @error
	Local $bRejected = ($bFixtures And $iAmbiguousError = 2 And _
			$iIncompleteError = 1)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRejected), 'Java Transaction', _
			'Ambiguous and incomplete staged runtime layouts were rejected')

	Local $sPrepareResult = _JavaPreparePackage($sZipPackage, $sFailedStage, _
			$sMissing7Zip)
	Local $iPrepareError = @error
	Local $bStageFailure = ($bFixtures And $iPrepareError = 2 And _
			$sPrepareResult = '' And Not FileExists($sFailedStage) And _
			_FullTestReadFixture($sLive & '\release') = 'release-old')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bStageFailure), 'Java Transaction', _
			'Failed package extraction removed staging before the live runtime was touched')

	Local $bPathSafety = (_JavaTransactionPathValid($sBackup, $sLive) And _
			Not _JavaTransactionPathValid($sLive, $sLive) And _
			Not _JavaTransactionPathValid($sLive & '\nested\old_java', $sLive) And _
			Not _JavaTransactionPathValid($sOutsideBackup, $sLive))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPathSafety), 'Java Transaction', _
			'Backup path validation allowed only one direct child of the live runtime')

	Local $sOriginalWorkingDir = @WorkingDir
	Local $bOriginalCancel = $bJGCancel
	$bJGCancel = False
	Local $bChangedDir = FileChangeDir($sLive) = 1
	Local $iBackupResult = 0
	If $bChangedDir Then $iBackupResult = _JavaBackup($sBackup)
	Local $bBackup = ($bFixtures And $bChangedDir And $iBackupResult = 1 And _
			_FullTestReadFixture($sBackup & '\release') = 'release-old' And _
			_FullTestReadFixture($sBackup & '\bin\java.exe') = 'java-old' And _
			_FullTestReadFixture($sBackup & '\lib\runtime.txt') = 'lib-old' And _
			_FullTestReadFixture($sBackup & '\conf\settings.txt') = 'conf-old' And _
			_FullTestReadFixture($sBackup & '\legal\notice.txt') = 'legal-old' And _
			Not FileExists($sLive & '\bin') And Not FileExists($sLive & '\jmods'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBackup), 'Java Transaction', _
			'Complete runtime content was backed up before live replacement')

	Local $bPreserved = ($bFixtures And _
			_FullTestReadFixture($sLive & '\setup\package.zip') = 'setup-old' And _
			_FullTestReadFixture($sLive & '\.java-stage\stage.txt') = 'stage-old' And _
			Not FileExists($sBackup & '\setup') And Not FileExists($sBackup & '\.java-stage'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPreserved), 'Java Transaction', _
			'Setup and staging data stayed outside the portable runtime backup')

	Local $iInstallResult = 0
	If $iBackupResult = 1 Then $iInstallResult = _JavaInstallPrepared($sPrepared, $sLive)
	Local $bInstalled = ($iInstallResult = 1 And _JavaRuntimeValid($sLive) And _
			_FullTestReadFixture($sLive & '\release') = 'release-new' And _
			_FullTestReadFixture($sLive & '\jmods\module.txt') = 'jmods-new' And _
			_FullTestReadFixture($sLive & '\setup\package.zip') = 'setup-old')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bInstalled), 'Java Transaction', _
			'Prepared runtime installation copied the complete new runtime into place')

	$bJGCancel = True
	Local $iCancelResult = _JavaInstallPrepared($sPrepared, $sCancelDest)
	Local $iCancelError = @error
	$bJGCancel = False
	Local $bCancelled = ($iCancelResult = 0 And $iCancelError = 2 And _
			_FullTestReadFixture($sCancelDest & '\sentinel.txt') = 'cancel-destination' And _
			Not FileExists($sCancelDest & '\bin'))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bCancelled), 'Java Transaction', _
			'Cancellation stopped prepared installation before destination mutation')

	_FullTestWriteFixture($sLive & '\partial.txt', 'partial')
	Local $iResumeResult = 0
	If FileExists($sBackup) Then $iResumeResult = _JavaResume($sBackup)
	Local $bRollback = ($iResumeResult = 1 And _JavaRuntimeValid($sLive) And _
			_FullTestReadFixture($sLive & '\release') = 'release-old' And _
			_FullTestReadFixture($sLive & '\bin\java.exe') = 'java-old' And _
			_FullTestReadFixture($sLive & '\lib\runtime.txt') = 'lib-old' And _
			_FullTestReadFixture($sLive & '\conf\settings.txt') = 'conf-old' And _
			_FullTestReadFixture($sLive & '\legal\notice.txt') = 'legal-old' And _
			_FullTestReadFixture($sLive & '\setup\package.zip') = 'setup-old' And _
			Not FileExists($sLive & '\partial.txt') And _
			Not FileExists($sLive & '\.java-stage') And Not FileExists($sBackup))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRollback), 'Java Transaction', _
			'Rollback removed partial content and restored the complete original runtime')

	FileChangeDir($sOriginalWorkingDir)
	$bJGCancel = $bOriginalCancel
	Local $bRestored = (@WorkingDir = $sOriginalWorkingDir And _
			$bJGCancel = $bOriginalCancel)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRestored), 'Java Transaction', _
			'Java transaction working directory and cancellation state were restored')
EndFunc   ;==>_FullTestJavaTransactionRun

Func _FullTestDebugReportingRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sDebugRoot = $sWorkspace & '\DebugReporting'
	Local $sDebugLog = $sDebugRoot & '\DebugClassification.dbg'
	Local $sEnvironmentName = 'XLAUNCHER_SELFTEST_DEBUG_ENV'
	Local $bBoundary = _FullTestPathIsInside($sDebugRoot, $sWorkspace) And _
			_FullTestPathIsInside($sDebugLog, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Debug Reporting', _
			'Debug classification log passed the isolated workspace boundary check')
	If Not $bBoundary Then Return

	Local $sOriginalDebug = $Debug
	Local $sOriginalDebugFile = $DebugFile
	Local $sOriginalSessionID = $DebugSessionID
	Local $bOriginalSessionStarted = $DebugSessionStarted
	Local $bOriginalSessionEnded = $DebugSessionEnded
	Local $iOriginalPass = $DebugPassCount
	Local $iOriginalFail = $DebugFailCount
	Local $iOriginalWarn = $DebugWarnCount
	Local $iOriginalSkip = $DebugSkipCount
	Local $iOriginalNotUsed = $DebugNotUsedCount
	Local $sOriginalEnvironment = EnvGet($sEnvironmentName)

	DirCreate($sDebugRoot)
	If FileExists($sDebugLog) Then FileDelete($sDebugLog)
	$Debug = 'false'
	$DebugFile = $sDebugLog
	_DebugOperationResult('FullTestDebug', 'DirCreate', $sDebugRoot, 1, 0, 0)
	_DebugApplicationLaunchResult($sDebugRoot & '\Disabled.exe', 'true', 0, 0, 0)
	Local $bDisabled = Not FileExists($sDebugLog)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bDisabled), 'Debug Reporting', _
			'Debug false produced no diagnostic result output')

	$Debug = 'true'
	$DebugFile = $sDebugLog
	$DebugSessionID = 'full-test-debug-classification'
	$DebugSessionStarted = False
	$DebugSessionEnded = False
	$DebugPassCount = 0
	$DebugFailCount = 0
	$DebugWarnCount = 0
	$DebugSkipCount = 0
	$DebugNotUsedCount = 0
	_DebugSessionStart()

	_DebugOperationResult('FullTestDebug', 'DirCreate', $sDebugRoot, 1, 0, 0)
	_DebugOperationResult('FullTestDebug', 'DirCreate', $sDebugRoot & '\Missing', 0, 1, 0)
	_DebugOperationResult('FullTestDebug', 'StringReplace', $sDebugRoot & '\Unchanged.txt', 0, 0, 0)
	_DebugOperationResult('FullTestDebug', 'FileCopy', $sDebugRoot & '\Source.txt|' & _
			$sDebugRoot & '\Destination.txt', 0, 0, 0)
	_DebugOperationResult('FullTestDebug', 'DirRemove', _
			$sDebugRoot & '\AlreadyAbsent', 1, 0, 4)
	_DebugOperationResult('FullTestDebug', 'UnknownOperation', 'compatibility-value', 0, 0, 0)
	_DebugApplicationLaunchResult($sDebugRoot & '\Waited.exe', 'true', 0, 0, 0)
	_DebugApplicationLaunchResult($sDebugRoot & '\Missing.exe', 'false', 0, 1, 0)
	_DebugOperationResult('Startup', 'RegistryRecovery', $sDebugRoot & '\Regedit', 1, 0, 0)

	EnvSet($sEnvironmentName, $sDebugRoot)
	_DebugEnvironmentResult($sEnvironmentName, $sDebugRoot, $sDebugRoot, 1, 0, 0)
	_DebugEnvironmentResult($sEnvironmentName, '', '', 0, 0, 0)
	_DebugEnvironmentResult($sEnvironmentName, 'invalid', 'expected', 0, 1, 0)
	_DebugTempCleanupResult('true', $sDebugRoot & '\RemovedTemp', 1, 0, 2)
	_DebugTempCleanupResult('false', $sDebugRoot & '\DisabledTemp', 0, 0, 0)
	_DebugTempCleanupResult('true', $sDebugRoot & '\BlockedTemp', 0, 1, 0)
	_DebugSessionEnd('full-test-classification')

	Local $sLogText = ''
	If FileExists($sDebugLog) Then $sLogText = FileRead($sDebugLog)
	Local $bPassResult = StringInStr($sLogText, _
			'[PASS] [FullTestDebug] DirCreate=' & $sDebugRoot, 1) > 0
	Local $bFailResult = StringInStr($sLogText, _
			'[FAIL] [FullTestDebug] DirCreate=' & $sDebugRoot & '\Missing', 1) > 0
	Local $bNoChange = StringInStr($sLogText, _
			'[SKIP] [FullTestDebug] StringReplace=' & $sDebugRoot & '\Unchanged.txt', 1) > 0 And _
			StringInStr($sLogText, 'reason=no text change needed', 1) > 0
	Local $bZeroNotPass = StringInStr($sLogText, _
			'[FAIL] [FullTestDebug] FileCopy=', 1) > 0 And _
			StringInStr($sLogText, '[PASS] [FullTestDebug] FileCopy=', 1) = 0
	Local $bMissingRemove = StringInStr($sLogText, _
			'[PASS] [FullTestDebug] DirRemove=' & $sDebugRoot & '\AlreadyAbsent', 1) > 0 And _
			StringInStr($sLogText, 'reason=target already absent', 1) > 0
	Local $bUnknownWarn = StringInStr($sLogText, _
			'[WARN] [FullTestDebug] Unknown operation=UnknownOperation', 1) > 0
	Local $bLaunchResults = StringInStr($sLogText, _
			'[PASS] [FileToRun] Launch=' & $sDebugRoot & '\Waited.exe', 1) > 0 And _
			StringInStr($sLogText, 'mode=RunWait; exitcode=0; error=0', 1) > 0 And _
			StringInStr($sLogText, '[FAIL] [FileToRun] Launch=' & _
			$sDebugRoot & '\Missing.exe', 1) > 0 And _
			StringInStr($sLogText, 'mode=Run; pid=0; error=1', 1) > 0
	Local $bRegistryResult = StringInStr($sLogText, _
			'[PASS] [Startup] RegistryRecovery=' & $sDebugRoot & '\Regedit', 1) > 0
	Local $bEnvironmentResults = StringInStr($sLogText, _
			'[PASS] [Environment] ' & $sEnvironmentName & '=' & $sDebugRoot, 1) > 0 And _
			StringInStr($sLogText, '[SKIP] [Environment] ' & $sEnvironmentName & '=', 1) > 0 And _
			StringInStr($sLogText, '[FAIL] [Environment] ' & $sEnvironmentName & '=invalid', 1) > 0
	Local $bCleanupResults = StringInStr($sLogText, _
			'[PASS] [Cleanup] Temp=' & $sDebugRoot & '\RemovedTemp', 1) > 0 And _
			StringInStr($sLogText, '[SKIP] [Cleanup] Temp=' & _
			$sDebugRoot & '\DisabledTemp', 1) > 0 And _
			StringInStr($sLogText, '[FAIL] [Cleanup] Temp=' & _
			$sDebugRoot & '\BlockedTemp', 1) > 0
	Local $bSession = StringInStr($sLogText, _
			'[SESSION START] id=full-test-debug-classification', 1) > 0 And _
			StringInStr($sLogText, '[SUMMARY] id=full-test-debug-classification; pass=6; fail=5; warn=1; skip=3; not-used=0', 1) > 0 And _
			StringInStr($sLogText, _
			'[SESSION END] id=full-test-debug-classification;', 1) > 0 And _
			StringInStr($sLogText, 'reason=full-test-classification', 1) > 0
	Local $bCounters = ($DebugPassCount = 6 And $DebugFailCount = 5 And _
			$DebugWarnCount = 1 And $DebugSkipCount = 3 And $DebugNotUsedCount = 0)

	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPassResult), 'Debug Reporting', _
			'Successful Boolean operation was classified PASS')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFailResult), 'Debug Reporting', _
			'Failed Boolean operation was classified FAIL')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bNoChange), 'Debug Reporting', _
			'Legitimate text no-change result was classified SKIP')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bZeroNotPass), 'Debug Reporting', _
			'Zero without error was not blindly classified PASS')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bMissingRemove), 'Debug Reporting', _
			'Missing directory removal was classified as successful no-op')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bUnknownWarn), 'Debug Reporting', _
			'Unknown operation name remained compatible and was classified WARN')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bLaunchResults), 'Debug Reporting', _
			'Application launch success and failure were distinguished')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegistryResult), 'Debug Reporting', _
			'Registry recovery success was recorded')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bEnvironmentResults), 'Debug Reporting', _
			'Environment PASS SKIP and FAIL results were distinguished')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bCleanupResults), 'Debug Reporting', _
			'Temp cleanup removed disabled and failed results were distinguished')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bSession), 'Debug Reporting', _
			'Debug session boundaries and summary totals were exact')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bCounters), 'Debug Reporting', _
			'Debug counters matched the emitted result classifications')

	$Debug = $sOriginalDebug
	$DebugFile = $sOriginalDebugFile
	$DebugSessionID = $sOriginalSessionID
	$DebugSessionStarted = $bOriginalSessionStarted
	$DebugSessionEnded = $bOriginalSessionEnded
	$DebugPassCount = $iOriginalPass
	$DebugFailCount = $iOriginalFail
	$DebugWarnCount = $iOriginalWarn
	$DebugSkipCount = $iOriginalSkip
	$DebugNotUsedCount = $iOriginalNotUsed
	EnvSet($sEnvironmentName, $sOriginalEnvironment)
	Local $bRestored = ($Debug = $sOriginalDebug And $DebugFile = $sOriginalDebugFile And _
			$DebugSessionID = $sOriginalSessionID And _
			$DebugSessionStarted = $bOriginalSessionStarted And _
			$DebugSessionEnded = $bOriginalSessionEnded And _
			$DebugPassCount = $iOriginalPass And $DebugFailCount = $iOriginalFail And _
			$DebugWarnCount = $iOriginalWarn And $DebugSkipCount = $iOriginalSkip And _
			$DebugNotUsedCount = $iOriginalNotUsed And _
			EnvGet($sEnvironmentName) = $sOriginalEnvironment)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRestored), 'Debug Reporting', _
			'Debug globals counters session and environment were restored')
EndFunc   ;==>_FullTestDebugReportingRun

Func _FullTestProbeParserRun($sWorkspace, ByRef $sDetails, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	Local $sProbeRoot = $sWorkspace & '\ProbeParser'
	Local $sValidRoot = $sProbeRoot & '\Valid'
	Local $sInvalidRoot = $sProbeRoot & '\Invalid'
	Local $sValidIni = $sValidRoot & '\Valid.ini'
	Local $sInvalidIni = $sInvalidRoot & '\Invalid.ini'
	Local $sValidTarget = $sValidRoot & '\Target.txt'
	Local $sValidSource = $sValidRoot & '\Source.txt'
	Local $sValidReg = $sValidRoot & '\Portable.reg'
	Local $sValidJava = $sValidRoot & '\Java64'
	Local $sInvalidTarget = $sInvalidRoot & '\InvalidTarget.txt'
	Local $sInvalidSetup = $sInvalidRoot & '\Lib\Java\setup\Broken.exe'
	Local $sProbeRegistry = 'HKEY_CURRENT_USER\Software\X-Launcher\SelfTest\ProbeParser-' & _
			@YEAR & @MON & @MDAY & '-' & @HOUR & @MIN & @SEC & '-' & @MSEC & '-' & @AutoItPID

	Local $bBoundary = _FullTestPathIsInside($sProbeRoot, $sWorkspace) And _
			_FullTestPathIsInside($sValidIni, $sWorkspace) And _
			_FullTestPathIsInside($sInvalidIni, $sWorkspace) And _
			_FullTestPathIsInside($sValidTarget, $sWorkspace) And _
			_FullTestPathIsInside($sValidJava & '\bin\java.exe', $sWorkspace) And _
			_FullTestPathIsInside($sInvalidSetup, $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bBoundary), 'Probe Parser', _
			'Every parser fixture passed the isolated workspace boundary check')
	If Not $bBoundary Then Return

	Local $sOriginalRoot = $Root
	Local $sOriginalTemp = $Temp
	Local $sOriginalLib = $Lib
	Local $sOriginalRunWait = $RunWait
	Local $sOriginalDeleteTemp = $DeleteTemp
	Local $sOriginalWorkingDir = @WorkingDir
	Local $iOriginalExpandEnv = AutoItSetOption('ExpandEnvStrings', 0)
	Local $iOriginalExpandVar = AutoItSetOption('ExpandVarStrings', 0)

	Local $bDirectories = DirCreate($sValidRoot & '\Disposable') = 1 And _
			DirCreate($sValidRoot & '\LinkSource') = 1 And _
			DirCreate($sValidJava & '\bin') = 1 And _
			DirCreate($sInvalidRoot & '\Lib\Java\setup') = 1
	Local $sValidContent = '[Options]' & @CRLF & _
			'DeleteTemp=false' & @CRLF & _
			'MultipleInstances=true' & @CRLF & _
			'FixLocalAppData=true' & @CRLF & _
			'FixTemp=false' & @CRLF & _
			'RegView=Native' & @CRLF & _
			'TestRun=full' & @CRLF & _
			'ProcMonMaxMB=2048' & @CRLF & _
			'Java=true' & @CRLF & _
			'JavaPath=.\Java64' & @CRLF & _
			'JavaURL=https://example.invalid/fallback.zip' & @CRLF & @CRLF & _
			'[Environment]' & @CRLF & _
			'PROBE_VALID=value' & @CRLF & _
			'PROGRAMFILES(x86)=.\ProgramFiles32' & @CRLF & _
			'USERPROFILE=.\Profile' & @CRLF & @CRLF & _
			'[Functions]' & @CRLF & _
			'FileCopy=.\Source.txt|.\WouldCopy.txt' & @CRLF & _
			'Junctions=.\LinkSource|.\WouldLink|*' & @CRLF & _
			'DirRemove=.\Disposable' & @CRLF & @CRLF & _
			'[RunBefore]' & @CRLF & _
			'Regedit=.\Portable.reg' & @CRLF & @CRLF & _
			'[StringReplace=.\Target.txt]' & @CRLF & _
			'BEGIN|END=changed' & @CRLF & @CRLF & _
			'[StringRegExpReplace=.\Target.txt]' & @CRLF & _
			'~|1=old~new' & @CRLF & @CRLF & _
			'[WriteToFile=.\WouldWrite.txt]' & @CRLF & _
			'EOF=value' & @CRLF & @CRLF & _
			'[WriteToIni=.\WouldWrite.ini]' & @CRLF & _
			'Section|Key=value' & @CRLF & @CRLF & _
			'[WriteToPref=.\WouldWrite.js]' & @CRLF & _
			'Format=user_pref("[PREF]", [VALUE]);' & @CRLF & _
			'probe.preference=true' & @CRLF & @CRLF & _
			'[WriteToReg=.\WouldWrite.reg]' & @CRLF & _
			'MainKey=' & $sProbeRegistry & @CRLF & _
			'ValueName=value' & @CRLF
	Local $sInvalidContent = '[Options]' & @CRLF & _
			'DeleteTemp=maybe' & @CRLF & _
			'MultipleInstances=maybe' & @CRLF & _
			'FixLocalAppData=maybe' & @CRLF & _
			'FixTemp=1' & @CRLF & _
			'RegView=Sideways' & @CRLF & _
			'TestRun=Unexpected' & @CRLF & _
			'ProcMonMaxMB=tiny' & @CRLF & _
			'Java=required' & @CRLF & _
			'JavaPath=.\MissingJava' & @CRLF & _
			'JavaURL=ftp://example.invalid/runtime.zip' & @CRLF & @CRLF & _
			'[UnknownSection]' & @CRLF & _
			'Example=value' & @CRLF & @CRLF & _
			'[Environment]' & @CRLF & _
			'BAD NAME=value' & @CRLF & _
			'EMPTY_VALUE=' & @CRLF & @CRLF & _
			'[Functions]' & @CRLF & _
			'FileCoppy=.\Missing.txt|.\Destination.txt' & @CRLF & _
			'DirCopy=.\OnlyOneArgument' & @CRLF & _
			'SymLinks=.\Source.txt|.\WouldLink|' & @CRLF & @CRLF & _
			'[StringReplace=.\Missing*.txt]' & @CRLF & _
			'OnlyBegin=value' & @CRLF & @CRLF & _
			'[StringRegExpReplace=.\InvalidTarget.txt]' & @CRLF & _
			'~|bad=([~replacement' & @CRLF & @CRLF & _
			'[WriteToFile=.\WouldWrite.txt]' & @CRLF & _
			'Line0=value' & @CRLF & @CRLF & _
			'[WriteToIni=.\WouldWrite.ini]' & @CRLF & _
			'OnlySection=value' & @CRLF & @CRLF & _
			'[WriteToPref=.\WouldWrite.js]' & @CRLF & _
			'Format=missing markers' & @CRLF & @CRLF & _
			'[WriteToReg=.\WouldWrite.reg]' & @CRLF & _
			'WrongFirstEntry=HKZZ\Software\Invalid' & @CRLF

	Local $bFixtures = $bDirectories And _
			_FullTestWriteFixture($sValidIni, $sValidContent) And _
			_FullTestWriteFixture($sInvalidIni, $sInvalidContent) And _
			_FullTestWriteFixture($sValidTarget, 'BEGIN old END') And _
			_FullTestWriteFixture($sValidSource, 'SOURCE') And _
			_FullTestWriteFixture($sValidReg, _
			'Windows Registry Editor Version 5.00' & @CRLF & @CRLF & _
			'[' & $sProbeRegistry & ']' & @CRLF & '"State"="PORTABLE"' & @CRLF) And _
			_FullTestWriteFixture($sValidJava & '\bin\java.exe', 'FAKE_JAVA') And _
			_FullTestWriteFixture($sValidJava & '\bin\javaw.exe', 'FAKE_JAVAW') And _
			_FullTestWriteFixture($sInvalidTarget, 'INVALID_PATTERN_SOURCE') And _
			_FullTestWriteFixture($sInvalidSetup, 'NOT_AN_MZ_EXECUTABLE')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bFixtures), 'Probe Parser', _
			'Controlled valid invalid operation dynamic and Java fixtures were created')

	Local $sBeforeValidIni = _FullTestReadFixture($sValidIni)
	Local $sBeforeInvalidIni = _FullTestReadFixture($sInvalidIni)
	Local $sBeforeValidTarget = _FullTestReadFixture($sValidTarget)
	Local $sBeforeValidSource = _FullTestReadFixture($sValidSource)
	Local $sBeforeValidReg = _FullTestReadFixture($sValidReg)
	Local $sBeforeJava = _FullTestReadFixture($sValidJava & '\bin\java.exe')
	Local $sBeforeJavaW = _FullTestReadFixture($sValidJava & '\bin\javaw.exe')
	Local $sBeforeInvalidTarget = _FullTestReadFixture($sInvalidTarget)
	Local $sBeforeInvalidSetup = _FullTestReadFixture($sInvalidSetup)
	RegRead($sProbeRegistry, 'State')
	Local $bRegistryAbsentBefore = @error <> 0

	Local $sValidResults = '', $sInvalidResults = ''
	Local $iValidPass = 0, $iValidFail = 0, $iValidWarn = 0, $iValidNotUsed = 0
	Local $iInvalidPass = 0, $iInvalidFail = 0, $iInvalidWarn = 0, $iInvalidNotUsed = 0

	Local $bSections = _ProbeSectionIsKnown('Options') And _
			_ProbeSectionIsKnown('StringReplace=.\Target.txt') And _
			Not _ProbeSectionIsKnown('UnknownSection')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bSections), 'Probe Parser', _
			'Known fixed and dynamic sections were accepted while an unknown section was rejected')

	_ProbeValidateKnownKeys($sValidIni, 'Options', _
			'|DeleteTemp|MultipleInstances|FixLocalAppData|FixTemp|RegView|TestRun|ProcMonMaxMB|Java|JavaPath|JavaURL|', _
			$sValidResults, $iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeValidateKnownKeys($sInvalidIni, 'Options', _
			'|DeleteTemp|MultipleInstances|FixLocalAppData|FixTemp|RegView|TestRun|ProcMonMaxMB|Java|JavaPath|JavaURL|', _
			$sInvalidResults, $iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	Local $bKeys = StringInStr($sValidResults, _
			'[PASS] [Options] Recognized key=MultipleInstances', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Options] Recognized key=FixLocalAppData', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Options] Recognized key=FixTemp', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[PASS] [Options] Recognized key=MultipleInstances', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bKeys), 'Probe Parser', _
			'The correctly spelled MultipleInstances option key was recognized')

	_ProbeValidateBooleanOption($sValidIni, 'DeleteTemp', 'true', $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeValidateMultipleInstancesOption($sValidIni, $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeValidateBooleanOption($sValidIni, 'FixLocalAppData', 'false', $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeValidateBooleanOption($sValidIni, 'FixTemp', 'false', $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeValidateRegViewOption($sValidIni, $sValidResults, $iValidPass, $iValidFail, _
			$iValidWarn, $iValidNotUsed)
	_ProbeValidateTestRunOption($sValidIni, $sValidResults, $iValidPass, $iValidFail, _
			$iValidWarn, $iValidNotUsed)
	_ProbeValidateIntegerOption($sValidIni, 'ProcMonMaxMB', 512, 64, 102400, _
			$sValidResults, $iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	Local $bValidOptions = StringInStr($sValidResults, _
			'[PASS] [Options] DeleteTemp is a valid Boolean=false', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Options] MultipleInstances is a valid Boolean=true', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Options] FixLocalAppData is a valid Boolean=true', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Options] FixTemp is a valid Boolean=false', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [Options] RegView is valid=Native', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [Options] TestRun is valid=full', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [Options] ProcMonMaxMB is valid=2048', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bValidOptions), 'Probe Parser', _
			'Valid Boolean RegView TestRun and integer options were accepted')

	_ProbeValidateBooleanOption($sInvalidIni, 'DeleteTemp', 'true', $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeValidateMultipleInstancesOption($sInvalidIni, $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeValidateBooleanOption($sInvalidIni, 'FixLocalAppData', 'false', $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeValidateBooleanOption($sInvalidIni, 'FixTemp', 'false', $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeValidateRegViewOption($sInvalidIni, $sInvalidResults, $iInvalidPass, _
			$iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeValidateTestRunOption($sInvalidIni, $sInvalidResults, $iInvalidPass, _
			$iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeValidateIntegerOption($sInvalidIni, 'ProcMonMaxMB', 512, 64, 102400, _
			$sInvalidResults, $iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	Local $bInvalidOptions = StringInStr($sInvalidResults, _
			'[FAIL] [Options] DeleteTemp must be true or false=maybe', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[FAIL] [Options] MultipleInstances must be true or false=maybe', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[FAIL] [Options] FixLocalAppData must be true or false=maybe', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[FAIL] [Options] FixTemp must be true or false=1', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [Options] RegView is invalid;', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [Options] TestRun is invalid;', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [Options] ProcMonMaxMB must be an integer', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bInvalidOptions), 'Probe Parser', _
			'Invalid Boolean RegView TestRun and integer options produced findings')

	$Root = $sValidRoot
	$Temp = $sValidRoot & '\Disposable'
	$Lib = $sValidRoot & '\Lib'
	$RunWait = 'true'
	$DeleteTemp = 'true'
	AutoItSetOption('ExpandEnvStrings', 1)
	AutoItSetOption('ExpandVarStrings', 1)
	_ProbeCheckResolvedPath('Root', $sValidRoot, $sValidRoot, $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeCheckResolvedPath('Temp', 'invalid', '', $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	_ProbeCheckResolvedPath('UNC', '\\server\share', 'C:\Mismatch', $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	Local $bPaths = _ProbePathIsWithinRoot($sValidRoot & '\Child', $sValidRoot) And _
			Not _ProbePathIsWithinRoot($sProbeRoot & '\Sibling', $sValidRoot) And _
			StringInStr($sValidResults, '[PASS] [FileSystem] Root resolved=', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [FileSystem] Temp could not be resolved=', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [FileSystem] UNC did not preserve its UNC prefix=', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bPaths), 'Probe Parser', _
			'Resolved path root boundary and UNC-prefix contracts were classified without access')

	_ProbeValidateEnvironment($sValidIni, $sValidResults, $iValidPass, $iValidFail, _
			$iValidWarn, $iValidNotUsed)
	Local $bValidEnvironment = StringInStr($sValidResults, _
			'[PASS] [Environment] Variable name is accepted by Windows=PROBE_VALID', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Environment] Variable name is accepted by Windows=PROGRAMFILES(x86)', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Environment] USERPROFILE resolves without being applied=', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bValidEnvironment), 'Probe Parser', _
			'Windows environment names including parentheses and USERPROFILE paths were accepted read-only')

	_ProbeValidateOperationSection($sValidIni, 'Functions', $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	_ProbeValidateOperationSection($sValidIni, 'RunBefore', $sValidResults, _
			$iValidPass, $iValidFail, $iValidWarn, $iValidNotUsed)
	Local $bValidOperations = StringInStr($sValidResults, _
			'[PASS] [Functions] FileCopy argument structure is valid', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Functions] Junctions argument structure is valid', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Functions] DirRemove target passed the protected-path check=', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [RunBefore] REG file is readable and contains supported roots=', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bValidOperations), 'Probe Parser', _
			'Valid operation arguments sources destinations and REG files were recognized read-only')

	_ProbeValidateDynamicSections($sValidIni, $sValidResults, $iValidPass, $iValidFail, _
			$iValidWarn, $iValidNotUsed)
	Local $bValidDynamic = StringInStr($sValidResults, _
			'[PASS] [StringReplace] Delimiter structure is valid=BEGIN|END', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [StringRegExpReplace] Regular expression pattern compiles without changing files=', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [WriteToFile] Line selector is valid=EOF', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [WriteToIni] Section and key names are valid=', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [WriteToPref] Format contains [PREF]', 1) > 0 And _
			StringInStr($sValidResults, '[PASS] [WriteToReg] MainKey uses a supported registry root=', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bValidDynamic), 'Probe Parser', _
			'Valid dynamic delimiters regex and write selectors were accepted without writes')

	_ProbeValidateJava($sValidIni, $sValidResults, $iValidPass, $iValidFail, _
			$iValidWarn, $iValidNotUsed, False)
	Local $bValidJava = StringInStr($sValidResults, _
			'[PASS] [Java] Java policy is valid=true', 1) > 0 And _
			StringInStr($sValidResults, _
			'[PASS] [Java] JavaPath resolves to a usable read-only runtime=', 1) > 0 And _
			StringInStr($sValidResults, _
			'[NOT USED] [Java] JavaURL is retained as fallback but not used because JavaPath is usable=', 1) > 0 And _
			StringInStr($sValidResults, _
			'[NOT USED] [Java] System Java fallback inspection was skipped for the isolated parser test', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bValidJava), 'Probe Parser', _
			'Valid Java policy JavaPath and unused JavaURL fallback were reported without execution')

	Local $sSafeReason = _TempCleanupSafetyReason($sValidRoot & '\Disposable')
	Local $sProtectedReason = _TempCleanupSafetyReason($sValidRoot)
	Local $bCleanupHazards = ($sSafeReason = '' And $sProtectedReason <> '')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bCleanupHazards), 'Probe Parser', _
			'Safe disposable and protected Root cleanup targets were distinguished')

	$Root = $sInvalidRoot
	$Temp = $sInvalidRoot
	$Lib = $sInvalidRoot & '\Lib'
	_ProbeValidateEnvironment($sInvalidIni, $sInvalidResults, $iInvalidPass, _
			$iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	Local $bEnvironmentEdgeCases = StringInStr($sInvalidResults, _
			'[PASS] [Environment] Variable name is accepted by Windows=BAD NAME', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[WARN] [Environment] EMPTY_VALUE has a blank value', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bEnvironmentEdgeCases), 'Probe Parser', _
			'Windows-valid spaced names and blank environment values produced the expected findings')

	_ProbeValidateOperationSection($sInvalidIni, 'Functions', $sInvalidResults, _
			$iInvalidPass, $iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	Local $bInvalidOperations = StringInStr($sInvalidResults, _
			'[WARN] [Functions] Unknown operation FileCoppy; did you mean FileCopy?', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[FAIL] [Functions] DirCopy requires source and destination', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[FAIL] [Functions] SymLinks must not end with a trailing pipe', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bInvalidOperations), 'Probe Parser', _
			'Unknown operation spelling and invalid argument count produced findings')

	_ProbeValidateDynamicSections($sInvalidIni, $sInvalidResults, $iInvalidPass, _
			$iInvalidFail, $iInvalidWarn, $iInvalidNotUsed)
	Local $bInvalidDynamic = StringInStr($sInvalidResults, _
			'[FAIL] [StringReplace] Key must contain nonblank begin and end delimiters=', 1) > 0 And _
			StringInStr($sInvalidResults, _
			'[FAIL] [StringRegExpReplace] Counter must be an integer=bad', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [WriteToFile] Line selector must be EOF', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [WriteToIni] Key must contain nonblank', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [WriteToPref] Format must contain [PREF]', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [WriteToReg] First entry must be MainKey', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bInvalidDynamic), 'Probe Parser', _
			'Invalid dynamic delimiters regex and write selectors produced findings')

	_ProbeValidateJava($sInvalidIni, $sInvalidResults, $iInvalidPass, $iInvalidFail, _
			$iInvalidWarn, $iInvalidNotUsed, False)
	Local $bInvalidJava = StringInStr($sInvalidResults, _
			'[FAIL] [Java] Java must be false, true or optional=required', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [Java] JavaPath must identify a runtime root', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [Java] Legacy Java EXE setup package does not have an MZ header=', 1) > 0 And _
			StringInStr($sInvalidResults, '[FAIL] [Java] JavaURL must be a direct HTTP or HTTPS package URL=', 1) > 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bInvalidJava), 'Probe Parser', _
			'Invalid Java policy path package and URL produced findings without installation')

	RegRead($sProbeRegistry, 'State')
	Local $bRegistryAbsentAfter = @error <> 0
	If Not $bRegistryAbsentAfter Then RegDelete($sProbeRegistry)
	Local $bReadOnly = $bRegistryAbsentBefore And $bRegistryAbsentAfter And _
			_FullTestReadFixture($sValidIni) == $sBeforeValidIni And _
			_FullTestReadFixture($sInvalidIni) == $sBeforeInvalidIni And _
			_FullTestReadFixture($sValidTarget) == $sBeforeValidTarget And _
			_FullTestReadFixture($sValidSource) == $sBeforeValidSource And _
			_FullTestReadFixture($sValidReg) == $sBeforeValidReg And _
			_FullTestReadFixture($sValidJava & '\bin\java.exe') == $sBeforeJava And _
			_FullTestReadFixture($sValidJava & '\bin\javaw.exe') == $sBeforeJavaW And _
			_FullTestReadFixture($sInvalidTarget) == $sBeforeInvalidTarget And _
			_FullTestReadFixture($sInvalidSetup) == $sBeforeInvalidSetup And _
			Not FileExists($sValidRoot & '\WouldCopy.txt') And _
			Not FileExists($sValidRoot & '\WouldWrite.txt') And _
			Not FileExists($sValidRoot & '\WouldWrite.ini') And _
			Not FileExists($sValidRoot & '\WouldWrite.js') And _
			Not FileExists($sValidRoot & '\WouldWrite.reg') And _
			Not FileExists($sValidRoot & '\WouldLink') And _
			FileExists($sValidRoot & '\Disposable') And _
			FileExists($sValidRoot & '\LinkSource')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bReadOnly), 'Probe Parser', _
			'Parser cross-checks left INIs targets Java sources directories and registry unchanged')

	FileChangeDir($sOriginalWorkingDir)
	$Root = $sOriginalRoot
	$Temp = $sOriginalTemp
	$Lib = $sOriginalLib
	$RunWait = $sOriginalRunWait
	$DeleteTemp = $sOriginalDeleteTemp
	AutoItSetOption('ExpandEnvStrings', $iOriginalExpandEnv)
	AutoItSetOption('ExpandVarStrings', $iOriginalExpandVar)
	Local $iRestoredExpandEnv = AutoItSetOption('ExpandEnvStrings', $iOriginalExpandEnv)
	Local $iRestoredExpandVar = AutoItSetOption('ExpandVarStrings', $iOriginalExpandVar)
	Local $bRestored = (@WorkingDir == $sOriginalWorkingDir And _
			$Root == $sOriginalRoot And $Temp == $sOriginalTemp And $Lib == $sOriginalLib And _
			$RunWait == $sOriginalRunWait And $DeleteTemp == $sOriginalDeleteTemp And _
			$iRestoredExpandEnv = $iOriginalExpandEnv And _
			$iRestoredExpandVar = $iOriginalExpandVar)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRestored), 'Probe Parser', _
			'Parser globals working directory and expansion options were restored')
EndFunc   ;==>_FullTestProbeParserRun

Func _FullTestRun($sIni, ByRef $sReportPath, ByRef $sWorkspace, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iSkip, ByRef $iNotUsed)
	$iPass = 0
	$iFail = 0
	$iWarn = 0
	$iSkip = 0
	$iNotUsed = 0
	Local $sDetails = ''
	Local $sSessionBase = @YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC & '_' & _
			@MSEC & '_' & @AutoItPID
	Local $sSession = $sSessionBase
	Local $sWorkspaceBase = @TempDir & '\X-Launcher-SelfTest'
	Local $sReportDir = @ScriptDir & '\Diagnostics\X-Launcher-SelfTest\' & $sSession
	$sWorkspace = $sWorkspaceBase & '\' & $sSession
	$sReportPath = $sReportDir & '\Full_Test_Report.log'

	Local $iSuffix = 1
	While FileExists($sWorkspace) Or FileExists($sReportDir)
		$sSession = $sSessionBase & '-' & $iSuffix
		$sWorkspace = $sWorkspaceBase & '\' & $sSession
		$sReportDir = @ScriptDir & '\Diagnostics\X-Launcher-SelfTest\' & _
				$sSession
		$sReportPath = $sReportDir & '\Full_Test_Report.log'
		$iSuffix += 1
	WEnd
	Local $sRegistryRoot = 'HKEY_CURRENT_USER\Software\X-Launcher\SelfTest\' & $sSession
	Local $sRegistryViewRoot = _
			'HKEY_CURRENT_USER\Software\Classes\CLSID\X-Launcher-SelfTest-' & $sSession

	Local $bReportDir = DirCreate($sReportDir) = 1
	Local $bWorkspace = DirCreate($sWorkspace) = 1
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bWorkspace), 'Isolation', _
			'Unique workspace created beneath current-user Temp', $sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bReportDir), 'Report', _
			'Unique diagnostic report folder created', $sReportDir)

	Local $bRegistryCreated = False
	If $bWorkspace Then
		$bRegistryCreated = RegWrite($sRegistryRoot, 'Session', 'REG_SZ', $sSession) = 1
		If $bRegistryCreated Then
			$bRegistryCreated = RegRead($sRegistryRoot, 'Session') == $sSession And @error = 0
		EndIf
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegistryCreated), 'Isolation', _
			'Dedicated HKCU self-test root created and verified', $sRegistryRoot)

	Local $sRequest1 = $sWorkspace & '\HelperSuccess.ini'
	Local $sResult1 = $sWorkspace & '\HelperSuccessResult.ini'
	Local $sRequest2 = $sWorkspace & '\HelperExit23.ini'
	Local $sResult2 = $sWorkspace & '\HelperExit23Result.ini'
	Local $sRequest3 = $sWorkspace & '\HelperConcurrent1.ini'
	Local $sResult3 = $sWorkspace & '\HelperConcurrent1Result.ini'
	Local $sRequest4 = $sWorkspace & '\HelperConcurrent2.ini'
	Local $sResult4 = $sWorkspace & '\HelperConcurrent2Result.ini'
	Local $bRequests = False
	If $bWorkspace Then
		$bRequests = _FullTestWriteHelperRequest($sRequest1, $sResult1, $sWorkspace, _
				$sSession, 0, 750)
		$bRequests = _FullTestWriteHelperRequest($sRequest2, $sResult2, $sWorkspace, _
				$sSession, 23, 0) And $bRequests
		$bRequests = _FullTestWriteHelperRequest($sRequest3, $sResult3, $sWorkspace, _
				$sSession, 0, 3000) And $bRequests
		$bRequests = _FullTestWriteHelperRequest($sRequest4, $sResult4, $sWorkspace, _
				$sSession, 0, 3000) And $bRequests
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRequests), 'Fixtures', _
			'Private helper requests created inside isolated workspace')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			'NOT USED', 'Isolation', _
			'Configured application, Functions, RunBefore and RunAfter were not executed')

	Local $sOldEnvironment = EnvGet('XLAUNCHER_SELFTEST_SESSION')
	Local $bEnvironmentSet = EnvSet('XLAUNCHER_SELFTEST_SESSION', $sSession) = 1
	Local $iSuccessExit = -1, $iSuccessError = 0, $nWaitMS = 0
	If $bRequests And $bEnvironmentSet Then
		Local $hWaitTimer = TimerInit()
		$iSuccessExit = RunWait(_FullTestHelperCommand($sRequest1), $sWorkspace, @SW_HIDE)
		$iSuccessError = @error
		$nWaitMS = TimerDiff($hWaitTimer)
	EndIf

	Local $bHelperSuccess = ($iSuccessError = 0 And $iSuccessExit = 0 And _
			IniRead($sResult1, 'Result', 'Status', '') = 'PASS' And _
			IniRead($sResult1, 'Result', 'Completed', '') = '1')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bHelperSuccess), 'Self Helper', _
			'Private helper completed with success exit code', _
			'exit=' & $iSuccessExit & '; error=' & $iSuccessError)

	Local $bArguments = (IniRead($sResult1, 'Result', 'ArgumentCount', '') = '3' And _
			IniRead($sResult1, 'Result', 'Argument1', '') == 'plain' And _
			IniRead($sResult1, 'Result', 'Argument2', '') == 'value with spaces' And _
			IniRead($sResult1, 'Result', 'Argument3', '') == 'two spaces  between')
	Local $sArgumentDetail = ''
	If Not $bArguments Then
		$sArgumentDetail = 'count=' & IniRead($sResult1, 'Result', 'ArgumentCount', '') & _
				'; arg1=' & IniRead($sResult1, 'Result', 'Argument1', '') & _
				'; arg2=' & IniRead($sResult1, 'Result', 'Argument2', '') & _
				'; arg3=' & IniRead($sResult1, 'Result', 'Argument3', '')
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bArguments), 'Command Line', _
			'Exact arguments and quoted spacing were preserved', $sArgumentDetail)

	Local $bWorking = StringLower(IniRead($sResult1, 'Result', 'WorkingDir', '')) = _
			StringLower($sWorkspace)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bWorking), 'Process', _
			'Private helper received the isolated working directory')

	Local $bEnvironment = IniRead($sResult1, 'Result', 'Environment', '') == $sSession
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bEnvironment), 'Environment', _
			'Private helper inherited the isolated session variable')

	Local $bWaited = $nWaitMS >= 650
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bWaited), 'Process', _
			'RunWait retained complete helper lifecycle', Round($nWaitMS, 1) & ' ms')

	Local $iControlledExit = -1, $iControlledError = 0
	If $bRequests And $bEnvironmentSet Then
		$iControlledExit = RunWait(_FullTestHelperCommand($sRequest2), $sWorkspace, @SW_HIDE)
		$iControlledError = @error
	EndIf
	Local $bControlledExit = ($iControlledError = 0 And $iControlledExit = 23 And _
			IniRead($sResult2, 'Result', 'Status', '') = 'PASS' And _
			IniRead($sResult2, 'Result', 'Completed', '') = '1')
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bControlledExit), 'Process', _
			'Controlled nonzero helper exit code was observed', _
			'exit=' & $iControlledExit & '; error=' & $iControlledError)

	Local $vMissingLaunch = 0, $iMissingLaunchError = 0
	If $bWorkspace Then
		$vMissingLaunch = _Run($sWorkspace & '\MissingExecutable.exe', '', 'true', 'true')
		$iMissingLaunchError = @error
	EndIf
	Local $bMissingLaunch = ($bWorkspace And $vMissingLaunch = 0 And _
			$iMissingLaunchError <> 0)
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bMissingLaunch), 'Process', _
			'Missing executable launch failure was detected', _
			'error=' & $iMissingLaunchError)

	Local $iConcurrentPID1 = 0, $iConcurrentPID2 = 0
	Local $iConcurrentError1 = 0, $iConcurrentError2 = 0
	If $bRequests And $bEnvironmentSet Then
		$iConcurrentPID1 = Run(_FullTestHelperCommand($sRequest3), $sWorkspace, @SW_HIDE)
		$iConcurrentError1 = @error
		$iConcurrentPID2 = Run(_FullTestHelperCommand($sRequest4), $sWorkspace, @SW_HIDE)
		$iConcurrentError2 = @error
	EndIf

	Local $hConcurrentTimer = TimerInit()
	Do
		If FileExists($sResult3) And FileExists($sResult4) Then ExitLoop
		Sleep(25)
	Until TimerDiff($hConcurrentTimer) >= 2000

	Local $bConcurrent = ($iConcurrentError1 = 0 And $iConcurrentError2 = 0 And _
			$iConcurrentPID1 > 0 And $iConcurrentPID2 > 0 And _
			$iConcurrentPID1 <> $iConcurrentPID2 And _
			IniRead($sResult3, 'Result', 'Status', '') = 'PASS' And _
			IniRead($sResult4, 'Result', 'Status', '') = 'PASS' And _
			ProcessExists($iConcurrentPID1) And ProcessExists($iConcurrentPID2))
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bConcurrent), 'Process', _
			'Two isolated self-helper instances ran concurrently', _
			'pid1=' & $iConcurrentPID1 & '; pid2=' & $iConcurrentPID2)

	Local $hCloseTimer = TimerInit()
	Do
		If Not ProcessExists($iConcurrentPID1) And Not ProcessExists($iConcurrentPID2) Then _
				ExitLoop
		Sleep(25)
	Until TimerDiff($hCloseTimer) >= 6000
	Local $bConcurrentClosed = ($iConcurrentPID1 > 0 And $iConcurrentPID2 > 0 And _
			Not ProcessExists($iConcurrentPID1) And Not ProcessExists($iConcurrentPID2) And _
			IniRead($sResult3, 'Result', 'Completed', '') = '1' And _
			IniRead($sResult4, 'Result', 'Completed', '') = '1')
	If Not $bConcurrentClosed Then
		If $iConcurrentPID1 > 0 And ProcessExists($iConcurrentPID1) Then _
				ProcessClose($iConcurrentPID1)
		If $iConcurrentPID2 > 0 And ProcessExists($iConcurrentPID2) Then _
				ProcessClose($iConcurrentPID2)
	EndIf
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bConcurrentClosed), 'Process', _
			'Both isolated self-helper instances closed normally')
	EnvSet('XLAUNCHER_SELFTEST_SESSION', $sOldEnvironment)

	_FullTestFileSystemRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestTextFormatRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestWriterSemanticsRun($sWorkspace, $sRegistryRoot, $sDetails, $iPass, _
			$iFail, $iWarn, $iSkip, $iNotUsed)
	_FullTestRegistryRun($sWorkspace, $sRegistryRoot, $sRegistryViewRoot, $sDetails, _
			$iPass, $iFail, $iWarn, $iSkip, $iNotUsed)
	_FullTestEnvironmentPathRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestPathSafetyRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestSplashTrayRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestJavaPathRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestJavaTransactionRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestDebugReportingRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)
	_FullTestProbeParserRun($sWorkspace, $sDetails, $iPass, $iFail, $iWarn, _
			$iSkip, $iNotUsed)

	Local $iRegistryDelete = RegDelete($sRegistryRoot)
	RegRead($sRegistryRoot, 'Session')
	Local $bRegistryRemoved = $iRegistryDelete = 1 And @error <> 0
	_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
			_FullTestStatus($bRegistryRemoved), 'Cleanup', _
			'Dedicated HKCU self-test root was removed', $sRegistryRoot)

	If $iFail = 0 Then
		Local $bWorkspaceRemoved = DirRemove($sWorkspace, 1) = 1 And Not FileExists($sWorkspace)
		_FullTestAddResult($sDetails, $iPass, $iFail, $iWarn, $iSkip, $iNotUsed, _
				_FullTestStatus($bWorkspaceRemoved), 'Cleanup', _
				'Isolated successful-test workspace was removed', $sWorkspace)
		If Not $bWorkspaceRemoved Then _
				$sDetails &= '[INFO] [Cleanup] Failed-test workspace preserved: ' & _
				$sWorkspace & @CRLF
		DirRemove($sWorkspaceBase, 0)
	Else
		$sDetails &= '[INFO] [Cleanup] Failed-test workspace preserved: ' & $sWorkspace & @CRLF
	EndIf

	Local $sOverall = 'PASS'
	If $iFail > 0 Then
		$sOverall = 'FAIL'
	ElseIf $iWarn > 0 Then
		$sOverall = 'PASS WITH WARNINGS'
	EndIf
	Local $sLauncherVersion = FileGetVersion(@ScriptFullPath)
	If $sLauncherVersion = '' Then $sLauncherVersion = 'source'
	Local $sReport = 'FULL X-LAUNCHER TEST' & @CRLF & _
			'====================' & @CRLF & _
			'Mode=isolated built-in integrity test' & @CRLF & _
			'Time=' & _DebugSessionTimestamp() & @CRLF & _
			'Session=' & $sSession & @CRLF & _
			'Launcher version=' & $sLauncherVersion & @CRLF & _
			'Application=X-Launcher Full Self-Test' & @CRLF & _
			'INI context only (configured targets were not used)=' & $sIni & @CRLF & _
			'Root=' & $sWorkspace & @CRLF & _
			'Executable=' & @ScriptFullPath & @CRLF & _
			'Workspace=' & $sWorkspace & @CRLF & _
			'Registry root=' & $sRegistryRoot & @CRLF & _
			'Registry view root=' & $sRegistryViewRoot & @CRLF & _
			'Windows=' & @OSVersion & ' ' & @OSServicePack & ' (build ' & @OSBuild & _
			'; ' & @OSArch & ')' & @CRLF & _
			'Privacy=Review paths and diagnostic details before sharing.' & @CRLF & @CRLF & _
			'SUMMARY' & @CRLF & _
			'-------' & @CRLF & _
			'PASS=' & $iPass & @CRLF & _
			'FAIL=' & $iFail & @CRLF & _
			'WARN=' & $iWarn & @CRLF & _
			'SKIP=' & $iSkip & @CRLF & _
			'NOT USED=' & $iNotUsed & @CRLF & _
			'OVERALL=' & $sOverall & @CRLF & @CRLF & _
			'ORDERED TEST DETAIL' & @CRLF & _
			'-------------------' & @CRLF & $sDetails

	If Not $bReportDir Then Return SetError(1, 0, False)
	Local $hReport = FileOpen($sReportPath, 2 + 128)
	If $hReport = -1 Then Return SetError(2, 0, False)
	FileWrite($hReport, $sReport)
	Local $iWriteError = @error
	FileClose($hReport)
	If $iWriteError Then Return SetError(3, 0, False)
	Return SetError(0, $iFail, $iFail = 0)
EndFunc   ;==>_FullTestRun

;===============================================================================
;
; Function Name:	_ConfigurationProbe()
; Description:		Creates a read-only assessment of the selected INI. The only
;					filesystem write is the X-Launcher-owned report below @ScriptDir.
;
;===============================================================================
Func _ConfigurationProbe($sIni, $sGlobalIni, ByRef $sReportPath, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $sResults = ''
	Local $sIniContent = ''
	Local $hIni = -1
	Local $iReadError = 0
	Local $aSections
	Local $sConfigured, $sResolved
	Local $sWorkingConfigured, $sWorkingResolved
	Local $sExeConfigured, $sExeResolved
	Local $sSafetyReason
	Local $i

	$iPass = 0
	$iFail = 0
	$iWarn = 0
	$iNotUsed = 0
	$sReportPath = ''

	$hIni = FileOpen($sIni, 0)
	If $hIni = -1 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'General', 'INI file is not readable', $sIni)
	Else
		$sIniContent = FileRead($hIni)
		$iReadError = @error
		FileClose($hIni)
		If $iReadError Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'General', 'INI file could not be read completely', $sIni)
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'General', 'INI file is readable', _
					$sIni & ' (' & StringLen($sIniContent) & ' characters)')
		EndIf
	EndIf

	$aSections = IniReadSectionNames($sIni)
	If @error Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'General', 'No readable INI sections were found')
	Else
		For $i = 1 To $aSections[0]
			If _ProbeSectionIsKnown($aSections[$i]) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'General', 'Recognized section', '[' & $aSections[$i] & ']')
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'WARN', 'General', 'Unknown section', '[' & $aSections[$i] & ']')
			EndIf
		Next
	EndIf

	_ProbeValidateKnownKeys($sIni, 'Setup', _
			'|AppName|AppVer|UserName|Profile|Lang|', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateKnownKeys($sIni, 'FileSystem', _
			'|Root|Temp|Cache|Home|Bin|Lib|Doc|Backup|Download|', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateKnownKeys($sIni, 'FileToRun', _
			'|PathToExe|Parameters|WorkingDir|WinGetProcess|', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateKnownKeys($sIni, 'Options', _
			'|DeleteTemp|MultipleInstances|FixAppData|FixLocalAppData|FixTemp|RunWait|RunAfterStopOnFailure|ShowSplash|ShowTrayTip|WriteLog|HideShellWindow|RegView|FirstRun|Java|JavaPath|JavaURL|Debug|TestRun|ProcMonPath|ProcMonMaxMB|ProcMonReserveMB|', _
			$sResults, $iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateKnownKeys($sIni, 'SplashScreen', _
			'|Image|Title|TimeOut|Width|Height|', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateKnownKeys($sIni, 'TrayTip', _
			'|Title|Timeout|TimeOut |', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Root', @ScriptDir)
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Root', $sConfigured)
	_ProbeCheckResolvedPath('Root', $sConfigured, $Root, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Temp', @TempDir & '\' & $ScriptName)
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Temp', $sConfigured)
	_ProbeCheckResolvedPath('Temp', $sConfigured, $Temp, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Cache', @TempDir & '\' & $ScriptName & '\Cache')
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Cache', $sConfigured)
	_ProbeCheckResolvedPath('Cache', $sConfigured, $Cache, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Home', '.\' & $UserName)
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Home', $sConfigured)
	_ProbeCheckResolvedPath('Home', $sConfigured, $Home, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Bin', '.\Bin')
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Bin', $sConfigured)
	_ProbeCheckResolvedPath('Bin', $sConfigured, $Bin, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Lib', '.\Lib')
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Lib', $sConfigured)
	_ProbeCheckResolvedPath('Lib', $sConfigured, $Lib, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Doc', '.\Documents')
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Doc', $sConfigured)
	_ProbeCheckResolvedPath('Documents (Doc)', $sConfigured, $Doc, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Backup', '.\Backups')
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Backup', $sConfigured)
	_ProbeCheckResolvedPath('Backup', $sConfigured, $Backup, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sConfigured = _IniReadPlus($sGlobalIni, 'FileSystem', 'Download', '.\Downloads')
	$sConfigured = _IniReadPlus($sIni, 'FileSystem', 'Download', $sConfigured)
	_ProbeCheckResolvedPath('Download', $sConfigured, $Download, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	$sWorkingConfigured = IniRead($sIni, 'FileToRun', 'WorkingDir', '')
	$sWorkingResolved = _FullPath($sWorkingConfigured, $Root)
	$sExeConfigured = IniRead($sIni, 'FileToRun', 'PathToExe', '')
	$sExeResolved = _ResolvePathToExe($sExeConfigured, $sWorkingResolved, $Root, @ScriptDir)

	If $sExeConfigured = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'FileToRun', 'PathToExe is missing')
	ElseIf $sExeResolved = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'FileToRun', 'PathToExe could not be resolved', $sExeConfigured)
	ElseIf FileExists($sExeResolved) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'FileToRun', 'PathToExe exists', $sExeResolved)
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'FileToRun', 'PathToExe does not exist', $sExeResolved)
	EndIf

	If $sExeResolved <> '' And Not _ProbePathIsWithinRoot($sExeResolved, $Root) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', 'FileToRun', 'PathToExe is outside Root', $sExeResolved)
	EndIf

	If $sWorkingConfigured = '' Then
		$sResolved = _FileInfo($sExeResolved, 0)
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'FileToRun', 'WorkingDir is blank; executable directory will be used', $sResolved)
	ElseIf $sWorkingResolved = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'FileToRun', 'WorkingDir could not be resolved', $sWorkingConfigured)
	ElseIf FileExists($sWorkingResolved) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'FileToRun', 'WorkingDir exists', $sWorkingResolved)
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', 'FileToRun', 'WorkingDir does not exist; executable directory will be used', $sWorkingResolved)
	EndIf

	If $sWorkingResolved <> '' And Not _ProbePathIsWithinRoot($sWorkingResolved, $Root) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', 'FileToRun', 'WorkingDir is outside Root', $sWorkingResolved)
	EndIf

	If $sExeResolved <> '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'FileToRun', 'Command line can be constructed without execution')
	EndIf

	_ProbeValidateBooleanOption($sIni, 'DeleteTemp', 'true', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateMultipleInstancesOption($sIni, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'FixAppData', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'FixLocalAppData', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'FixTemp', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'RunWait', 'true', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'RunAfterStopOnFailure', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'ShowSplash', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'ShowTrayTip', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'WriteLog', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'HideShellWindow', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'FirstRun', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'Debug', 'false', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)

	_ProbeValidateRegViewOption($sIni, $sResults, $iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateTestRunOption($sIni, $sResults, $iPass, $iFail, $iWarn, $iNotUsed)

	_ProbeValidateIntegerOption($sIni, 'ProcMonMaxMB', 512, 64, 102400, _
			$sResults, $iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateIntegerOption($sIni, 'ProcMonReserveMB', 1024, 256, 102400, _
			$sResults, $iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateProcMonPath(IniRead($sIni, 'Options', 'ProcMonPath', ''), _
			$sResults, $iPass, $iFail, $iWarn, $iNotUsed)

	If $RunWait <> 'true' And _RunWaitCleanupRequired($sIni) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', 'Options', 'RunWait=false will be forced true because cleanup is required')
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'Options', 'RunWait cleanup requirement is consistent')
	EndIf

	If $DeleteTemp = 'true' Then
		$sSafetyReason = _TempCleanupSafetyReason($Temp)
		If $sSafetyReason = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'Options', 'Temp cleanup target passed the protected-path check', $Temp)
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', 'Options', 'Temp cleanup would be blocked: ' & $sSafetyReason, $Temp)
		EndIf
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Options', 'Temp cleanup is disabled')
	EndIf

	_ProbeValidateEnvironment($sIni, $sResults, $iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateOperationSection($sIni, 'Functions', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateOperationSection($sIni, 'FirstRunOperations', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateOperationSection($sIni, 'RunBefore', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateOperationSection($sIni, 'RunAfter', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateDynamicSections($sIni, $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
	_ProbeValidateJava($sIni, $sResults, $iPass, $iFail, $iWarn, $iNotUsed)

	Local $sReportDir = @ScriptDir & '\Diagnostics'
	If Not FileExists($sReportDir) And DirCreate($sReportDir) <> 1 Then Return SetError(1, 0, False)

	$sReportPath = $sReportDir & '\' & $ScriptName & '_Configuration_Probe_' & _
			@YEAR & @MON & @MDAY & '_' & @HOUR & @MIN & @SEC & '_' & @AutoItPID & '.log'

	Local $sHeader = 'X-LAUNCHER CONFIGURATION PROBE' & @CRLF & _
			'==================================' & @CRLF & _
			'Time=' & _DebugSessionTimestamp() & @CRLF & _
			'INI=' & $sIni & @CRLF & _
			'Root=' & $Root & @CRLF & _
			'Mode=READ-ONLY - configured application and operations were not executed.' & @CRLF & _
			'Privacy=Review paths and configuration details before sharing this report.' & @CRLF & @CRLF
	Local $sSummary = @CRLF & 'SUMMARY' & @CRLF & _
			'-------' & @CRLF & _
			'PASS=' & $iPass & @CRLF & _
			'FAIL=' & $iFail & @CRLF & _
			'WARN=' & $iWarn & @CRLF & _
			'NOT USED=' & $iNotUsed & @CRLF
	Local $sAttention = ''
	Local $aAttention = StringRegExp($sResults, '(?m)^\[(?:FAIL|WARN)\][^\r\n]*', 3)
	If IsArray($aAttention) Then
		$sAttention = @CRLF & 'FINDINGS REQUIRING ATTENTION' & @CRLF & _
				'------------------------------' & @CRLF
		For $i = 0 To UBound($aAttention) - 1
			$sAttention &= $aAttention[$i] & @CRLF
		Next
	EndIf

	Local $hReport = FileOpen($sReportPath, 2 + 128)
	If $hReport = -1 Then Return SetError(2, 0, False)
	FileWrite($hReport, $sHeader & $sResults & $sSummary & $sAttention)
	Local $iWriteError = @error
	FileClose($hReport)
	If $iWriteError Then Return SetError(3, 0, False)

	Return SetError(0, $iFail, True)
EndFunc   ;==>_ConfigurationProbe

Func _ProbeAddResult(ByRef $sResults, ByRef $iPass, ByRef $iFail, ByRef $iWarn, _
		ByRef $iNotUsed, $sStatus, $sSection, $sMessage, $sDetail = '')
	$sStatus = StringUpper($sStatus)
	Switch $sStatus
		Case 'PASS'
			$iPass += 1
		Case 'FAIL'
			$iFail += 1
		Case 'WARN'
			$iWarn += 1
		Case 'NOT USED'
			$iNotUsed += 1
	EndSwitch

	$sResults &= '[' & $sStatus & '] [' & $sSection & '] ' & $sMessage
	If $sDetail <> '' Then $sResults &= '=' & _ProbeSafeText($sDetail)
	$sResults &= @CRLF
EndFunc   ;==>_ProbeAddResult

Func _ProbeValidateIntegerOption($sIni, $sKey, $iDefault, $iMinimum, $iMaximum, _
		ByRef $sResults, ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $sValue = StringStripWS(IniRead($sIni, 'Options', $sKey, '__x_probe_missing__'), 3)
	If $sValue = '__x_probe_missing__' Or $sValue = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Options', $sKey & ' is not configured; default applies', $iDefault)
		Return
	EndIf

	If Not StringRegExp($sValue, '^\d+$') Or Number($sValue) < $iMinimum Or _
			Number($sValue) > $iMaximum Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'Options', $sKey & ' must be an integer from ' & $iMinimum & _
				' to ' & $iMaximum & ' MB', $sValue)
		Return
	EndIf

	_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
			'PASS', 'Options', $sKey & ' is valid', $sValue)
EndFunc   ;==>_ProbeValidateIntegerOption

Func _ProbeValidateProcMonPath($sConfigured, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $sResolved = ''
	Local $sResolution = ''
	Local $bResolved = _ResolveProcMonPath($sConfigured, $sResolved, $sResolution, $Root, $Lib)
	Local $iResolveError = @error

	If $bResolved Then
		Switch $sResolution
			Case 'default-file'
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Process Monitor', 'Default ProcMon executable was found', $sResolved)
			Case 'configured-folder'
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Process Monitor', 'ProcMonPath resolved from the configured folder', $sResolved)
			Case Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Process Monitor', 'ProcMonPath resolved to an executable', $sResolved)
		EndSwitch
		Return
	EndIf

	Switch $iResolveError
		Case 2
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'NOT USED', 'Process Monitor', _
					'Application Trace is optional; ProcMonPath is blank and the default was not found', $sResolved)
		Case 3
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', 'Process Monitor', _
					'ProcMonPath does not exist; Application Trace will be unavailable', $sResolved)
		Case 4
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', 'Process Monitor', _
					'ProcMonPath file name is not supported; use Procmon.exe, Procmon64.exe or Procmon64a.exe', _
					$sResolved)
		Case 5
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', 'Process Monitor', _
					'ProcMonPath folder does not contain a supported executable', $sResolved)
		Case Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', 'Process Monitor', _
					'ProcMonPath could not be resolved; Application Trace will be unavailable', $sConfigured)
	EndSwitch
EndFunc   ;==>_ProbeValidateProcMonPath

Func _ProbeSafeText($sText)
	$sText = StringReplace($sText, @CR, ' ')
	$sText = StringReplace($sText, @LF, ' ')
	Return $sText
EndFunc   ;==>_ProbeSafeText

Func _ProbeSectionIsKnown($sSection)
	Switch $sSection
		Case 'Setup', 'FileSystem', 'FileToRun', 'Options', 'SplashScreen', 'TrayTip', _
				'Environment', 'Functions', 'FirstRunOperations', 'RunBefore', 'RunAfter'
			Return True
	EndSwitch

	Local $iEquals = StringInStr($sSection, '=')
	If $iEquals = 0 Then Return False
	Local $sType = StringLeft($sSection, $iEquals - 1)
	Switch $sType
		Case 'StringReplace', 'StringRegExpReplace', 'WriteToFile', 'WriteToIni', _
				'WriteToPref', 'WriteToReg'
			Return True
	EndSwitch
	Return False
EndFunc   ;==>_ProbeSectionIsKnown

Func _ProbeValidateKnownKeys($sIni, $sSection, $sKnownKeys, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aValues = IniReadSection($sIni, $sSection)
	Local $i
	If @error Then Return

	For $i = 1 To $aValues[0][0]
		If StringInStr($sKnownKeys, '|' & $aValues[$i][0] & '|', 1) Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', $sSection, 'Recognized key', $aValues[$i][0])
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', $sSection, 'Unknown key', $aValues[$i][0])
		EndIf
	Next
EndFunc   ;==>_ProbeValidateKnownKeys

Func _ProbeCheckResolvedPath($sName, $sConfigured, $sResolved, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	If $sResolved = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'FileSystem', $sName & ' could not be resolved', $sConfigured)
		Return
	EndIf

	_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
			'PASS', 'FileSystem', $sName & ' resolved', $sResolved)

	If StringLeft(StringReplace($sConfigured, '/', '\'), 2) = '\\' And _
			StringLeft($sResolved, 2) <> '\\' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'FileSystem', $sName & ' did not preserve its UNC prefix', $sResolved)
	EndIf
EndFunc   ;==>_ProbeCheckResolvedPath

Func _ProbeValidateBooleanOption($sIni, $sKey, $sDefault, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $sValue = IniRead($sIni, 'Options', $sKey, '__x_probe_missing__')
	If $sValue = '__x_probe_missing__' Or $sValue = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Options', $sKey & ' is not configured; default applies', $sDefault)
	ElseIf $sValue = 'true' Or $sValue = 'false' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'Options', $sKey & ' is a valid Boolean', $sValue)
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'Options', $sKey & ' must be true or false', $sValue)
	EndIf
EndFunc   ;==>_ProbeValidateBooleanOption

Func _ProbeValidateMultipleInstancesOption($sIni, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	_ProbeValidateBooleanOption($sIni, 'MultipleInstances', 'true', $sResults, _
			$iPass, $iFail, $iWarn, $iNotUsed)
EndFunc   ;==>_ProbeValidateMultipleInstancesOption

Func _ProbeValidateRegViewOption($sIni, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $sValue = IniRead($sIni, 'Options', 'RegView', '__x_probe_missing__')
	If $sValue = '__x_probe_missing__' Or $sValue = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Options', 'RegView is not configured; default applies', 'Native')
		Return
	EndIf

	Switch StringUpper(StringStripWS($sValue, 3))
		Case '32', '64', 'AUTO', 'NATIVE'
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'Options', 'RegView is valid', $sValue)
		Case Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'Options', 'RegView is invalid; use Auto, Native, 32 or 64', $sValue)
	EndSwitch
EndFunc   ;==>_ProbeValidateRegViewOption

Func _ProbeValidateTestRunOption($sIni, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $sValue = IniRead($sIni, 'Options', 'TestRun', '__x_probe_missing__')
	If $sValue = '__x_probe_missing__' Or $sValue = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Options', _
				'TestRun is not configured; normal launch is the default', 'false')
		Return
	EndIf

	Switch StringLower(StringStripWS($sValue, 3))
		Case 'false', 'probe', 'trace', 'full'
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'Options', 'TestRun is valid', $sValue)
		Case Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'Options', _
					'TestRun is invalid; use false, Probe, Trace or Full', $sValue)
	EndSwitch
EndFunc   ;==>_ProbeValidateTestRunOption

Func _ProbeValidateDynamicSections($sIni, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aSections = IniReadSectionNames($sIni)
	Local $aSection, $aValues
	Local $sType, $sTarget
	Local $i, $iReadError
	Local $bFound = False
	If @error Then Return

	For $i = 1 To $aSections[0]
		$aSection = StringSplit($aSections[$i], '=')
		If @error Or $aSection[0] < 2 Then ContinueLoop
		$sType = $aSection[1]
		If Not _ProbeDynamicTypeSupported($sType) Then ContinueLoop

		$bFound = True
		$sTarget = $aSection[2]
		AutoItSetOption('ExpandEnvStrings', 0)
		AutoItSetOption('ExpandVarStrings', 0)
		$aValues = IniReadSection($sIni, $aSections[$i])
		$iReadError = @error
		AutoItSetOption('ExpandEnvStrings', 1)
		AutoItSetOption('ExpandVarStrings', 1)

		If $iReadError Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', $sType, 'Dynamic section could not be read', '[' & $aSections[$i] & ']')
			ContinueLoop
		EndIf

		_ProbeValidateDynamicSection($sType, $sTarget, $aValues, $sResults, _
				$iPass, $iFail, $iWarn, $iNotUsed)
	Next

	If Not $bFound Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Dynamic Sections', 'No dynamic rewrite or write sections are configured')
	EndIf
EndFunc   ;==>_ProbeValidateDynamicSections

Func _ProbeDynamicTypeSupported($sType)
	Return StringInStr('|StringReplace|StringRegExpReplace|WriteToFile|WriteToIni|WriteToPref|WriteToReg|', _
			'|' & $sType & '|', 1) > 0
EndFunc   ;==>_ProbeDynamicTypeSupported

Func _ProbeValidateDynamicSection($sType, $sTarget, ByRef $aValues, _
		ByRef $sResults, ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aMatches
	Local $sResolved = ''
	Local $i

	If $sTarget = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sType, 'Dynamic section target is blank')
	ElseIf $sType = 'StringReplace' Or $sType = 'StringRegExpReplace' Then
		$aMatches = _ExpandMultiPath($sTarget, True)
		If $aMatches[0] = 0 Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', $sType, 'Target pattern did not match an existing file', $sTarget)
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', $sType, 'Target pattern matched existing files', $aMatches[0])
			For $i = 1 To $aMatches[0]
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sType, 'Matched target (not changed)', $aMatches[$i])
			Next
		EndIf
	Else
		$sResolved = _FullPath($sTarget, $Root)
		If $sResolved = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', $sType, 'Target could not be resolved', $sTarget)
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', $sType, 'Target resolves without being changed', $sResolved)
		EndIf
	EndIf

	Switch $sType
		Case 'StringReplace'
			_ProbeValidateStringReplaceEntries($aValues, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
		Case 'StringRegExpReplace'
			_ProbeValidateRegExpEntries($aValues, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
		Case 'WriteToFile'
			_ProbeValidateWriteToFileEntries($aValues, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
		Case 'WriteToIni'
			_ProbeValidateWriteToIniEntries($aValues, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
		Case 'WriteToPref'
			_ProbeValidateWriteToPrefEntries($aValues, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
		Case 'WriteToReg'
			_ProbeValidateWriteToRegEntries($aValues, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
	EndSwitch
EndFunc   ;==>_ProbeValidateDynamicSection

Func _ProbeValidateStringReplaceEntries(ByRef $aValues, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aParts
	Local $i
	For $i = 1 To $aValues[0][0]
		$aParts = StringSplit($aValues[$i][0], '|')
		If $aParts[0] <> 2 And $aParts[0] <> 3 Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringReplace', 'Key must contain nonblank begin and end delimiters', $aValues[$i][0])
		ElseIf $aParts[1] = '' Or $aParts[2] = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringReplace', 'Key must contain nonblank begin and end delimiters', $aValues[$i][0])
		ElseIf $aParts[0] = 3 Then
			If $aParts[3] <> 'o' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', 'StringReplace', 'Optional third delimiter argument must be o', $aValues[$i][0])
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'StringReplace', 'Delimiter structure is valid', $aValues[$i][0])
			EndIf
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'StringReplace', 'Delimiter structure is valid', $aValues[$i][0])
		EndIf
	Next
EndFunc   ;==>_ProbeValidateStringReplaceEntries

Func _ProbeValidateRegExpEntries(ByRef $aValues, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aFlag, $aPattern
	Local $sPattern, $sReplacement
	Local $i, $iCount, $iRegexError
	For $i = 1 To $aValues[0][0]
		$aFlag = StringSplit($aValues[$i][0], '|')
		If $aFlag[0] < 1 Or $aFlag[0] > 3 Or $aFlag[1] = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringRegExpReplace', 'Key must contain a nonblank spacer and optional counter/modifier', $aValues[$i][0])
			ContinueLoop
		EndIf

		$iCount = 0
		If $aFlag[0] > 1 Then
			If $aFlag[2] <> '' Then
				If Not StringIsInt($aFlag[2]) Then
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'FAIL', 'StringRegExpReplace', 'Counter must be an integer', $aFlag[2])
				Else
					$iCount = Int($aFlag[2])
				EndIf
			EndIf
		EndIf

		$aPattern = StringSplit($aValues[$i][1], $aFlag[1], 1)
		If @error Or $aPattern[0] <> 2 Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringRegExpReplace', 'Value must contain exactly one spacer', $aValues[$i][0])
			ContinueLoop
		EndIf

		$sPattern = _RegExpProtector($aPattern[1], 1)
		If @error Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringRegExpReplace', 'Pattern variable expansion is invalid', $aValues[$i][0])
			ContinueLoop
		EndIf
		$sReplacement = _RegExpProtector($aPattern[2], 2, _
				_ProbeRegExpModifier($aFlag))
		If @error Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringRegExpReplace', 'Replacement variable expansion is invalid', $aValues[$i][0])
			ContinueLoop
		EndIf

		StringRegExpReplace('', $sPattern, $sReplacement, $iCount)
		$iRegexError = @error
		If $iRegexError Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'StringRegExpReplace', 'Regular expression pattern does not compile', $aValues[$i][0])
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'StringRegExpReplace', 'Regular expression pattern compiles without changing files', $aValues[$i][0])
		EndIf
	Next
EndFunc   ;==>_ProbeValidateRegExpEntries

Func _ProbeRegExpModifier(ByRef $aFlag)
	If $aFlag[0] > 2 Then Return $aFlag[3]
	Return ''
EndFunc   ;==>_ProbeRegExpModifier

Func _ProbeValidateWriteToFileEntries(ByRef $aValues, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $i
	For $i = 1 To $aValues[0][0]
		If $aValues[$i][0] = 'EOF' Or StringRegExp($aValues[$i][0], '^Line[1-9][0-9]*$') Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'WriteToFile', 'Line selector is valid', $aValues[$i][0])
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'WriteToFile', 'Line selector must be EOF or Line followed by a positive integer', $aValues[$i][0])
		EndIf
	Next
EndFunc   ;==>_ProbeValidateWriteToFileEntries

Func _ProbeValidateWriteToIniEntries(ByRef $aValues, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aParts
	Local $i
	For $i = 1 To $aValues[0][0]
		$aParts = StringSplit($aValues[$i][0], '|')
		If $aParts[0] <> 2 Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'WriteToIni', 'Key must contain nonblank section and key names', $aValues[$i][0])
		ElseIf $aParts[1] <> '' And $aParts[2] <> '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'WriteToIni', 'Section and key names are valid', $aValues[$i][0])
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'WriteToIni', 'Key must contain nonblank section and key names', $aValues[$i][0])
		EndIf
	Next
EndFunc   ;==>_ProbeValidateWriteToIniEntries

Func _ProbeValidateWriteToPrefEntries(ByRef $aValues, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	If $aValues[0][0] < 1 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'WriteToPref', 'First entry must be Format')
		Return
	EndIf
	If $aValues[1][0] <> 'Format' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'WriteToPref', 'First entry must be Format')
		Return
	EndIf

	Local $iPref = StringInStr($aValues[1][1], '[PREF]', 1)
	Local $iValue = StringInStr($aValues[1][1], '[VALUE]', 1)
	If $iPref = 0 Or $iValue = 0 Or $iPref > $iValue Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'WriteToPref', 'Format must contain [PREF] followed by [VALUE]', $aValues[1][1])
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'WriteToPref', 'Format contains [PREF] and [VALUE] in the required order')
	EndIf

	If $aValues[0][0] = 1 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', 'WriteToPref', 'No preference entries follow Format')
	EndIf
EndFunc   ;==>_ProbeValidateWriteToPrefEntries

Func _ProbeValidateWriteToRegEntries(ByRef $aValues, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aParts
	Local $i, $bValid
	If $aValues[0][0] < 1 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'WriteToReg', 'First entry must be MainKey')
		Return
	EndIf
	If $aValues[1][0] <> 'MainKey' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'WriteToReg', 'First entry must be MainKey')
		Return
	EndIf

	If Not StringRegExp($aValues[1][1], _
			'(?i)^(HKEY_CURRENT_USER|HKEY_LOCAL_MACHINE|HKEY_CLASSES_ROOT|HKEY_USERS|HKEY_CURRENT_CONFIG)(\\|$)') Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'WriteToReg', 'MainKey uses an unsupported registry root', $aValues[1][1])
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'WriteToReg', 'MainKey uses a supported registry root', $aValues[1][1])
	EndIf

	For $i = 2 To $aValues[0][0]
		$aParts = StringSplit($aValues[$i][0], '|')
		$bValid = False
		If $aParts[0] = 1 Then
			If $aParts[1] <> '' Then $bValid = True
		ElseIf $aParts[0] = 2 Then
			If $aParts[1] <> '' And $aParts[2] <> '' Then $bValid = True
		EndIf
		If $bValid Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'WriteToReg', 'Value name structure is valid', $aValues[$i][0])
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'WriteToReg', 'Value key must be ValueName or SubKey|ValueName', $aValues[$i][0])
		EndIf
	Next
EndFunc   ;==>_ProbeValidateWriteToRegEntries

Func _ProbeValidateJava($sIni, ByRef $sResults, ByRef $iPass, ByRef $iFail, _
		ByRef $iWarn, ByRef $iNotUsed, $bCheckSystem = True)
	Local $sMissing = '__x_probe_missing__'
	Local $sMode = IniRead($sIni, 'Options', 'Java', $sMissing)
	Local $sConfigured = StringStripWS(IniRead($sIni, 'Options', 'JavaPath', ''), 3)
	Local $sURL = StringStripWS(IniRead($sIni, 'Options', 'JavaURL', ''), 3)
	Local $sPortable = $Lib & '\Java'
	Local $sSystem = ''
	Local $aSetup
	Local $i, $iSystemError
	Local $bModeValid = True
	Local $bConfigured = False
	Local $bPortable = False
	Local $bSetup = False
	Local $bURL = False
	Local $bSystem = False

	If $sMode = $sMissing Or $sMode = '' Then
		$sMode = 'false'
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'Java is not configured; default applies', 'false')
	Else
		Switch $sMode
			Case 'false', 'true', 'optional'
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', 'Java policy is valid', $sMode)
			Case Else
				$bModeValid = False
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', 'Java', 'Java must be false, true or optional', $sMode)
		EndSwitch
	EndIf

	If $sConfigured = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'JavaPath is not configured')
	ElseIf $sMode = 'false' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'JavaPath is retained but ignored while Java=false', _
				$sConfigured)
	Else
		Local $sConfiguredRuntime = _JavaPathResolve($sConfigured, $Root)
		Local $iConfiguredError = @error
		If $iConfiguredError = 0 Then
			$bConfigured = True
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'Java', 'JavaPath resolves to a usable read-only runtime', _
					$sConfiguredRuntime)
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'Java', _
					'JavaPath must identify a runtime root, bin folder, java.exe or javaw.exe', _
					$sConfigured)
		EndIf
	EndIf

	If _JavaRuntimeValid($sPortable) Then
		$bPortable = True
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'Java', 'Portable Java runtime is usable and has first priority', $sPortable)
	ElseIf FileExists($sPortable) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', 'Java', 'Portable Java folder is incomplete; bin\\java.exe and bin\\javaw.exe are required', $sPortable)
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'Portable Java runtime is not present', $sPortable)
	EndIf

	$aSetup = _ExpandMultiPath($sPortable & '\setup\*.zip|' & $sPortable & '\setup\*.exe', True)
	If $aSetup[0] = 0 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'No supported Java setup package is present')
	Else
		For $i = 1 To $aSetup[0]
			If StringRegExp($aSetup[$i], '(?i)\.zip$') Then
				$bSetup = True
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', 'Java ZIP setup package is recognized without installation', $aSetup[$i])
			ElseIf _JavaLegacyPackage($aSetup[$i]) Then
				$bSetup = True
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', 'Legacy Java EXE setup package is recognized without execution', $aSetup[$i])
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', 'Java', 'Legacy Java EXE setup package does not have an MZ header', $aSetup[$i])
			EndIf
		Next
	EndIf

	If $bConfigured And $sURL <> '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'JavaURL is retained as fallback but not used because JavaPath is usable', _
				$sURL)
	ElseIf $sURL = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', 'JavaURL is not configured')
	ElseIf _JavaURLValid($sURL) Then
		$bURL = True
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'Java', 'JavaURL is a valid direct HTTP or HTTPS source; no download was performed', $sURL)
	Else
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', 'Java', 'JavaURL must be a direct HTTP or HTTPS package URL', $sURL)
	EndIf

	If Not $bCheckSystem Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Java', _
				'System Java fallback inspection was skipped for the isolated parser test')
	Else
		$sSystem = _JavaFindSystemJava()
		$iSystemError = @error
		If $iSystemError = 0 And _JavaRuntimeValid($sSystem) Then
			$bSystem = True
			If $bPortable Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', _
						'System Java fallback is usable but portable Java remains preferred', _
						$sSystem)
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', 'System Java fallback is usable', $sSystem)
			EndIf
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'NOT USED', 'Java', 'No usable system Java fallback was found')
		EndIf
	EndIf

	If Not $bModeValid Then Return
	Switch $sMode
		Case 'false'
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'NOT USED', 'Java', 'Java is disabled; discovered sources will not be selected')
		Case 'true'
			If $bConfigured Or $bPortable Or $bSetup Or $bURL Or $bSystem Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', 'Required Java has an available source; no download or installation was performed')
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', 'Java', 'Required Java has no usable source; add JavaPath, Lib\\Java, Lib\\Java\\setup package, JavaURL, or system Java')
			EndIf
		Case 'optional'
			If $bConfigured Or $bPortable Or $bSetup Or $bURL Or $bSystem Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Java', 'Optional Java has an available source; no download or installation was performed')
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'WARN', 'Java', 'Optional Java has no usable source; the launcher will continue without Java')
			EndIf
	EndSwitch
EndFunc   ;==>_ProbeValidateJava

Func _ProbeValidateEnvironment($sIni, ByRef $sResults, ByRef $iPass, ByRef $iFail, _
		ByRef $iWarn, ByRef $iNotUsed)
	Local $aValues = IniReadSection($sIni, 'Environment')
	Local $i, $sName, $sValue, $sResolved
	If @error Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', 'Environment', 'No environment variables are configured')
		Return
	EndIf

	For $i = 1 To $aValues[0][0]
		$sName = $aValues[$i][0]
		$sValue = $aValues[$i][1]

		If $sName = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'Environment', _
					'Environment variable name is blank; Windows requires a name')
			ContinueLoop
		EndIf

		If StringInStr($sName, '=') Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', 'Environment', _
					'Environment variable name contains =; Windows does not allow = in variable names', _
					$sName)
			ContinueLoop
		EndIf

		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', 'Environment', 'Variable name is accepted by Windows', $sName)

		If $sValue = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'WARN', 'Environment', $sName & ' has a blank value')
		ElseIf $sName = 'USERPROFILE' Then
			$sResolved = _FullPath($sValue, $Root)
			If $sResolved = '' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', 'Environment', 'USERPROFILE could not be resolved', $sValue)
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', 'Environment', 'USERPROFILE resolves without being applied', $sResolved)
			EndIf
		ElseIf $sName = 'PATH' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'Environment', 'PATH value expands without being applied')
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', 'Environment', $sName & ' value expands without being applied')
		EndIf
	Next
EndFunc   ;==>_ProbeValidateEnvironment

Func _ProbeValidateOperationSection($sIni, $sSection, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aValues = IniReadSection($sIni, $sSection)
	Local $i, $sOperation, $sValue
	If @error Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'NOT USED', $sSection, 'No operations are configured')
		Return
	EndIf

	For $i = 1 To $aValues[0][0]
		$sOperation = $aValues[$i][0]
		$sValue = $aValues[$i][1]

		If Not _ProbeOperationIsSupported($sSection, $sOperation) Then
			Switch $sOperation
				Case 'FileCoppy'
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'WARN', $sSection, 'Unknown operation FileCoppy; did you mean FileCopy?')
				Case 'RunFiel'
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'WARN', $sSection, 'Unknown operation RunFiel; did you mean RunFile?')
				Case Else
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'WARN', $sSection, 'Unknown operation', $sOperation)
			EndSwitch
			ContinueLoop
		EndIf

		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'PASS', $sSection, 'Recognized operation', $sOperation)

		If $sValue = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'NOT USED', $sSection, $sOperation & ' has a blank value and will be skipped')
			ContinueLoop
		EndIf

		_ProbeValidateOperationValue($sSection, $sOperation, $sValue, $sResults, _
				$iPass, $iFail, $iWarn, $iNotUsed)
	Next
EndFunc   ;==>_ProbeValidateOperationSection

Func _ProbeOperationIsSupported($sSection, $sOperation)
	Switch $sSection
		Case 'Functions'
			Return StringInStr('|DirCopy|DirCreate|DirMove|DirRemove|FileCopy|FileCreate|FileDelete|FileMove|AddFonts|Junctions|SymLinks|', _
					'|' & $sOperation & '|', 1) > 0
		Case 'FirstRunOperations'
			Return StringInStr('|DirCopy|DirCreate|DirMove|DirRemove|FileCopy|FileCreate|FileDelete|FileMove|RunFile|', _
					'|' & $sOperation & '|', 1) > 0
		Case 'RunBefore'
			Return StringInStr('|FixDriveLetter|Regedit|RunFile|', '|' & $sOperation & '|', 1) > 0
		Case 'RunAfter'
			Return StringInStr('|DirCopy|DirMove|DirRemove|FileCopy|FileDelete|FileMove|RunFile|', _
					'|' & $sOperation & '|', 1) > 0
	EndSwitch
	Return False
EndFunc   ;==>_ProbeOperationIsSupported

Func _ProbeValidateOperationValue($sSection, $sOperation, $sValue, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aParts = StringSplit($sValue, '|')
	Local $sSource = '', $sDestination = '', $sResolved, $sSafetyReason
	Local $aMatches

	Switch $sOperation
		Case 'Junctions', 'SymLinks'
			If StringRight(StringStripWS($sValue, 3), 1) = '|' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' must not end with a trailing pipe')
				Return
			EndIf
			If $aParts[0] < 2 Or $aParts[0] > 3 Or $aParts[1] = '' Or $aParts[2] = '' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' requires nonblank source and destination')
				Return
			EndIf
			If $aParts[0] = 3 And $aParts[3] <> '*' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' optional third argument must be *', $aParts[3])
				Return
			EndIf
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', $sSection, $sOperation & ' argument structure is valid')
			$sSource = _FullPath($aParts[1], $Root)
			$sDestination = _FullPath($aParts[2], $Root)
			Local $iLinkSourceAttributes = _LinkPathAttributes($sSource)
			Local $iLinkSourceError = @error
			If $iLinkSourceError Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' source does not exist', $sSource)
			ElseIf $sOperation = 'Junctions' And _
					BitAND($iLinkSourceAttributes, 0x10) = 0 Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, 'Junctions source is not a directory', $sSource)
			ElseIf $sOperation = 'Junctions' And StringLeft($sSource, 2) = '\\' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, 'Junctions source cannot be a UNC path', $sSource)
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sSection, $sOperation & ' source exists', $sSource)
			EndIf

			If $sSource = '' Or $sDestination = '' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' path could not be resolved')
				Return
			EndIf
			If _LinkCanonicalPath($sSource) = _LinkCanonicalPath($sDestination) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' source and destination are the same path', _
						$sDestination)
				Return
			EndIf

			Local $iLinkDestinationAttributes = _LinkPathAttributes($sDestination)
			Local $iLinkDestinationError = @error
			Local $iLinkExpectedTag = 0xA000000C
			If $sOperation = 'Junctions' Then $iLinkExpectedTag = 0xA0000003
			If $iLinkDestinationError Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sSection, $sOperation & ' destination is available', $sDestination)
			ElseIf BitAND($iLinkDestinationAttributes, 0x400) = 0 Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' destination already exists and is not a link', _
						$sDestination)
			ElseIf _LinkReparseTag($sDestination) <> $iLinkExpectedTag Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' destination has the wrong link type', _
						$sDestination)
			ElseIf _LinkTargetsMatch($sSource, $sDestination) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sSection, $sOperation & ' destination is an existing matching link', _
						$sDestination)
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' destination is an existing link to another target', _
						$sDestination)
			EndIf
			If Not _ProbePathIsWithinRoot($sDestination, $Root) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'WARN', $sSection, $sOperation & ' destination is outside Root', $sDestination)
			EndIf
			If $sOperation = 'SymLinks' And Not IsAdmin() Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'WARN', $sSection, _
						'SymLinks may require Windows Developer Mode or Run as administrator')
			EndIf

		Case 'DirCopy', 'DirMove', 'FileCopy', 'FileMove'
			If $aParts[0] < 2 Or $aParts[0] > 3 Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' requires source and destination')
				Return
			EndIf
			If $aParts[0] = 3 And $aParts[3] <> 'o' Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' optional third argument must be o', $aParts[3])
				Return
			EndIf
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'PASS', $sSection, $sOperation & ' argument structure is valid')
			$sSource = _ProbeFirstListedPath($aParts[1])
			$sDestination = _FullPath($aParts[2], $Root)
			If $sOperation = 'FileMove' And StringRegExp($sSource, '\*|\?') = 1 Then
				$aMatches = _ExpandMultiPath($aParts[1], True)
				If $aMatches[0] = 0 Then
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'NOT USED', $sSection, _
							'FileMove wildcard source matched no files; runtime will skip this operation', _
							$sSource)
				Else
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'PASS', $sSection, 'FileMove wildcard source matched existing files', _
							$aMatches[0])
				EndIf
			Else
				_ProbeCheckOperationSource($sSection, $sOperation, $sSource, $sResults, _
						$iPass, $iFail, $iWarn, $iNotUsed)
			EndIf
			_ProbeCheckOperationDestination($sSection, $sOperation, $sDestination, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)

		Case 'DirCreate', 'FileCreate'
			$sDestination = _ProbeFirstListedPath($aParts[1])
			_ProbeCheckOperationDestination($sSection, $sOperation, $sDestination, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)

		Case 'DirRemove', 'FileDelete'
			Local $bDirRemoveEmptyOnly = False
			Local $bDirRemoveContentsOnly = False
			If $sOperation = 'DirRemove' And $aParts[0] > 2 Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, _
						'DirRemove syntax is Path or Path|e; omit the flag to recursively remove populated directories')
				Return
			EndIf
			If $sOperation = 'DirRemove' And $aParts[0] = 2 And _
					Not StringInStr($aParts[2], 'e', 1) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, _
						'DirRemove flag is invalid; omit it to recursively remove populated directories or use e to remove only empty directories', _
						$aParts[2])
				Return
			EndIf
			If $sOperation = 'DirRemove' Then
				$bDirRemoveEmptyOnly = $aParts[0] = 2 And _
						StringInStr($aParts[2], 'e', 1) > 0
				$bDirRemoveContentsOnly = _DirRemoveContentsOnlyRequested($aParts[1])
				If $aParts[0] = 1 Then
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'PASS', $sSection, _
							'DirRemove has no flag and will recursively remove populated directories')
				Else
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'PASS', $sSection, _
							'DirRemove e flag will remove only empty directories recursively')
				EndIf
			EndIf
			$sSource = _ProbeFirstListedPath($aParts[1])
			_ProbeCheckOperationSource($sSection, $sOperation, $sSource, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
			$sSafetyReason = _TempCleanupSafetyReason($sSource)
			If $sSafetyReason <> '' Then
				If $sOperation = 'DirRemove' And $sSafetyReason = 'protected path' And _
						_DirRemoveProtectedBaseCanBePreserved($sSource, _
						$bDirRemoveEmptyOnly, $bDirRemoveContentsOnly) Then
					Local $sProtectedCleanupMode = _
							'trailing separator will remove contents while preserving Lib'
					If $bDirRemoveEmptyOnly Then $sProtectedCleanupMode = _
							'e flag will remove empty descendant directories while preserving Lib'
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'PASS', $sSection, 'DirRemove protected-base cleanup is safe: ' & _
							$sProtectedCleanupMode, $sSource)
				Else
					_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
							'FAIL', $sSection, $sOperation & ' has a dangerous target: ' & _
							$sSafetyReason, $sSource)
				EndIf
			ElseIf Not _ProbePathIsWithinRoot($sSource, $Root) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'WARN', $sSection, $sOperation & ' target is outside Root', $sSource)
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sSection, $sOperation & ' target passed the protected-path check', $sSource)
			EndIf

		Case 'RunFile', 'FixDriveLetter'
			If $aParts[0] > 2 Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' accepts only a target and optional parameters')
				Return
			EndIf
			$sResolved = _FullPath($aParts[1], $Root)
			If $sResolved <> '' And FileExists($sResolved) Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sSection, $sOperation & ' target exists', $sResolved)
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, $sOperation & ' target does not exist', $sResolved)
			EndIf

		Case 'Regedit'
			_ProbeValidateRegeditValue($sSection, $sValue, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)

		Case 'AddFonts'
			$aMatches = _ExpandMultiPath($sValue, True)
			If $aMatches[0] > 0 Then
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'PASS', $sSection, 'AddFonts matched existing font files', $aMatches[0])
			Else
				_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
						'FAIL', $sSection, 'AddFonts did not match an existing font file', $sValue)
			EndIf
	EndSwitch
EndFunc   ;==>_ProbeValidateOperationValue

Func _ProbeFirstListedPath($sValue)
	Local $aList = StringSplit($sValue, ';')
	Return _FullPath($aList[1], $Root)
EndFunc   ;==>_ProbeFirstListedPath

Func _ProbeCheckOperationSource($sSection, $sOperation, $sSource, ByRef $sResults, _
		ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	If $sSource = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, $sOperation & ' source does not exist', $sSource)
		Return
	EndIf
	If Not FileExists($sSource) Then
		If $sOperation = 'DirRemove' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'NOT USED', $sSection, _
					'DirRemove target is already absent; runtime cleanup is not needed', _
					$sSource)
		Else
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', $sSection, $sOperation & ' source does not exist', $sSource)
		EndIf
		Return
	EndIf

	If StringLeft($sOperation, 3) = 'Dir' And _
			StringInStr(FileGetAttrib($sSource), 'D', 2) = 0 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, $sOperation & ' source is not a directory', $sSource)
		Return
	EndIf

	_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
			'PASS', $sSection, $sOperation & ' source exists', $sSource)
EndFunc   ;==>_ProbeCheckOperationSource

Func _ProbeCheckOperationDestination($sSection, $sOperation, $sDestination, _
		ByRef $sResults, ByRef $iPass, ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	If $sDestination = '' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, $sOperation & ' destination could not be resolved')
		Return
	EndIf

	_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
			'PASS', $sSection, $sOperation & ' destination resolves without being changed', $sDestination)
	If Not _ProbePathIsWithinRoot($sDestination, $Root) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'WARN', $sSection, $sOperation & ' destination is outside Root', $sDestination)
	EndIf
EndFunc   ;==>_ProbeCheckOperationDestination

Func _ProbeValidateRegeditValue($sSection, $sValue, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	Local $aGroups = StringSplit($sValue, '|')
	Local $aFiles, $sFirstPath, $sBase, $sPath
	Local $i, $f, $iFileCount = 0

	For $i = 1 To $aGroups[0]
		If $aGroups[$i] = '*' Then ContinueLoop
		If $aGroups[$i] = '' Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', $sSection, 'Regedit contains a blank path group')
			ContinueLoop
		EndIf

		$aFiles = StringSplit($aGroups[$i], ';')
		$sFirstPath = _FullPath($aFiles[1], $Root)
		$sBase = _FileInfo($sFirstPath, 0)
		For $f = 1 To $aFiles[0]
			If $f = 1 Then
				$sPath = $sFirstPath
			Else
				$sPath = $sBase & '\' & $aFiles[$f]
			EndIf
			$iFileCount += 1
			_ProbeValidateRegFile($sSection, $sPath, $sResults, _
					$iPass, $iFail, $iWarn, $iNotUsed)
		Next
	Next

	If $iFileCount = 0 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, 'Regedit does not contain a REG file path')
	EndIf
EndFunc   ;==>_ProbeValidateRegeditValue

Func _ProbeValidateRegFile($sSection, $sPath, ByRef $sResults, ByRef $iPass, _
		ByRef $iFail, ByRef $iWarn, ByRef $iNotUsed)
	If $sPath = '' Or Not FileExists($sPath) Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, 'REG file does not exist', $sPath)
		Return
	EndIf

	Local $sHeader = StringStripWS(FileReadLine($sPath, 1), 3)
	If $sHeader <> 'Windows Registry Editor Version 5.00' And $sHeader <> 'REGEDIT4' Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, 'REG file header is not recognized', $sPath)
		Return
	EndIf

	Local $aRoots = _RegFileGetRoots($sPath)
	Local $i
	If $aRoots[0] = 0 Then
		_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
				'FAIL', $sSection, 'REG file does not contain a registry root', $sPath)
		Return
	EndIf

	For $i = 1 To $aRoots[0]
		If Not StringRegExp($aRoots[$i], _
				'^(HKEY_CURRENT_USER|HKEY_LOCAL_MACHINE|HKEY_CLASSES_ROOT|HKEY_USERS|HKEY_CURRENT_CONFIG)(\\|$)') Then
			_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
					'FAIL', $sSection, 'REG file contains an unsupported root', $aRoots[$i])
			Return
		EndIf
	Next

	_ProbeAddResult($sResults, $iPass, $iFail, $iWarn, $iNotUsed, _
			'PASS', $sSection, 'REG file is readable and contains supported roots', $sPath)
EndFunc   ;==>_ProbeValidateRegFile

Func _ProbePathIsWithinRoot($sPath, $sRootPath)
	Local $sCanonicalPath = _CleanupCanonicalPath($sPath)
	Local $sCanonicalRoot = _CleanupCanonicalPath($sRootPath)
	If $sCanonicalPath = '' Or $sCanonicalRoot = '' Then Return False
	If $sCanonicalPath = $sCanonicalRoot Then Return True
	Return StringLeft($sCanonicalPath, StringLen($sCanonicalRoot) + 1) = $sCanonicalRoot & '\'
EndFunc   ;==>_ProbePathIsWithinRoot

Func _ResolvePathToExe($sConfigured, $sWorkingDir, $sRootPath, $sLauncherDir)
	Local $sResolved = _FullPath($sConfigured, $sRootPath)
	If $sResolved = '' Then Return ''
	If Not StringInStr($sResolved, '\') Then
		If FileExists($sWorkingDir & '\' & $sResolved) Then
			$sResolved = $sWorkingDir & '\' & $sResolved
		ElseIf FileExists($sLauncherDir & '\' & $sResolved) Then
			$sResolved = $sLauncherDir & '\' & $sResolved
		ElseIf FileExists(@WindowsDir & '\' & $sResolved) Then
			$sResolved = @WindowsDir & '\' & $sResolved
		ElseIf FileExists(@SystemDir & '\' & $sResolved) Then
			$sResolved = @SystemDir & '\' & $sResolved
		EndIf
	EndIf
	Return $sResolved
EndFunc   ;==>_ResolvePathToExe

Func _RunWaitCleanupRequired($sIni)
	Local $aValues = IniReadSection($sIni, 'RunAfter')
	Local $i
	If Not @error Then
		For $i = 1 To $aValues[0][0]
			If $aValues[$i][1] <> '' Then Return True
		Next
	EndIf

	$aValues = IniReadSection($sIni, 'Functions')
	If Not @error Then
		For $i = 1 To $aValues[0][0]
			If $aValues[$i][0] = 'AddFonts' And $aValues[$i][1] <> '' Then Return True
			If ($aValues[$i][0] = 'Junctions' Or $aValues[$i][0] = 'SymLinks') And _
					$aValues[$i][1] <> '' And _
					StringRight(StringStripWS($aValues[$i][1], 3), 2) <> '|*' Then Return True
		Next
	EndIf

	$aValues = IniReadSection($sIni, 'RunBefore')
	If Not @error Then
		For $i = 1 To $aValues[0][0]
			If $aValues[$i][0] = 'Regedit' And $aValues[$i][1] <> '' And _
					StringRight(StringStripWS($aValues[$i][1], 3), 2) <> '|*' Then Return True
		Next
	EndIf

	Return False
EndFunc   ;==>_RunWaitCleanupRequired

;===============================================================================
;
; Function Name:	_DebugSessionStart(), _DebugSessionMetadata(), _DebugSessionEnd()
; Description:		Write session boundaries, diagnostic context, and result totals.
;
;===============================================================================
Func _DebugSessionStart()
	If $Debug <> 'true' Or $DebugSessionStarted Then Return
	If $DebugSessionID = '' Then
		$DebugSessionID = @YEAR & @MON & @MDAY & '-' & @HOUR & @MIN & @SEC & @MSEC & '-' & @AutoItPID
	EndIf

	$DebugSessionStarted = True
	_DebugWrite('[SESSION START] id=' & $DebugSessionID & '; time=' & _DebugSessionTimestamp())
EndFunc   ;==>_DebugSessionStart

Func _DebugSessionMetadata()
	If $Debug <> 'true' Or Not $DebugSessionStarted Then Return

	Local $sLauncherVersion = FileGetVersion(@ScriptFullPath)
	If $sLauncherVersion = '' Then $sLauncherVersion = 'source'

	_DebugWrite('[INFO] [Session] id=' & $DebugSessionID & '; launcher=' & $sLauncherVersion & _
			'; ini=' & $ScriptIni)
	_DebugWrite('[INFO] [System] windows=' & @OSVersion & ' ' & @OSServicePack & _
			'; build=' & @OSBuild & '; osarch=' & @OSArch & '; autoit-x64=' & @AutoItX64 & _
			'; regview=' & $RegView)
	_DebugWrite('[INFO] [Paths] root=' & $Root & '; temp=' & $Temp & '; bin=' & $Bin & _
			'; lib=' & $Lib & '; home=' & $Home)
	_DebugWrite('[INFO] [Application] name=' & $AppName & '; version=' & $AppVer & _
			'; java=' & $Java & '; executable=' & $PathToExe)
EndFunc   ;==>_DebugSessionMetadata

Func _DebugSessionEnd($sReason = 'normal')
	If $Debug <> 'true' Or $DebugSessionEnded Then Return
	If Not $DebugSessionStarted Then _DebugSessionStart()

	$DebugSessionEnded = True
	_DebugWrite('[SUMMARY] id=' & $DebugSessionID & '; pass=' & $DebugPassCount & _
			'; fail=' & $DebugFailCount & '; warn=' & $DebugWarnCount & '; skip=' & $DebugSkipCount & _
			'; not-used=' & $DebugNotUsedCount)
	_DebugWrite('[SESSION END] id=' & $DebugSessionID & '; time=' & _DebugSessionTimestamp() & _
			'; reason=' & $sReason)
EndFunc   ;==>_DebugSessionEnd

Func _DebugSessionTimestamp()
	Return @YEAR & '-' & @MON & '-' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC & '.' & @MSEC
EndFunc   ;==>_DebugSessionTimestamp

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
	If $Debug <> 'true' Then Return

	If $DebugSessionID = '' Then
		$DebugSessionID = @YEAR & @MON & @MDAY & '-' & @HOUR & @MIN & @SEC & @MSEC & '-' & @AutoItPID
	EndIf

	Switch StringLeft($string, 6)
		Case '[PASS]'
			$DebugPassCount += 1
		Case '[FAIL]'
			$DebugFailCount += 1
		Case '[WARN]'
			$DebugWarnCount += 1
		Case '[SKIP]'
			$DebugSkipCount += 1
		Case '[NOT U'
			$DebugNotUsedCount += 1
	EndSwitch

	Local $hDebugFile = FileOpen($DebugFile, 1)
	If $hDebugFile <> -1 Then
		FileWriteLine($hDebugFile, StringLeft(_DebugSessionTimestamp(), 19) & ' = ' & $string)
		FileClose($hDebugFile)
	EndIf

EndFunc   ;==>_DebugWrite
