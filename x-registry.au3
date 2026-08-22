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
; AutoIt Version:	3.3.18.0
; Language:			English
; Description:		Functions used in X-Launcher
; Author:			winPenPack Developer Team
; Contributors:		winPenPack Team and winPenPack community
; v2.x.x Update:	sl23 https://github.com/sl2365/X-Launcher64
;
; ------------------------------------------------------------------------------
;
;
;
;===============================================================================
;
; Function Name:	_DebugRegistryResult()
; Description:		Write a consistent diagnostic result for a registry transaction step.
; Syntax:			_DebugRegistryResult(Status, Operation, Target, Detail)
; Requirements:		_DebugWrite
;
;===============================================================================
Func _DebugRegistryResult($sStatus, $sOperation, $sTarget, $sDetail = '')
	If $Debug <> 'true' Then Return

	Local $sRecord = '[' & $sStatus & '] [Registry] ' & $sOperation & '=' & $sTarget
	If $sDetail <> '' Then $sRecord &= ' (' & $sDetail & ')'
	_DebugWrite($sRecord)
EndFunc   ;==>_DebugRegistryResult

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

Func _RegViewOption()
	Switch $RegView
		Case '32'
			Return ' /reg:32'
		Case '64'
			Return ' /reg:64'
	EndSwitch

	Return ''
EndFunc   ;==>_RegViewOption

Func _RegViewDetectExecutable($sFile)
	Local $aBinaryType

	If Not FileExists($sFile) Then Return ''

	$aBinaryType = DllCall('kernel32.dll', 'bool', 'GetBinaryTypeW', _
			'wstr', $sFile, _
			'dword*', 0)

	If @error Or Not IsArray($aBinaryType) Then Return ''
	If $aBinaryType[0] = 0 Then Return ''

	Switch $aBinaryType[2]
		Case 0 ; SCS_32BIT_BINARY
			Return '32'
		Case 6 ; SCS_64BIT_BINARY
			Return '64'
	EndSwitch

	Return ''
EndFunc   ;==>_RegViewDetectExecutable

Func _RegExePath($bExport = False)
	Local $sRegExe = @SystemDir & '\reg.exe'

	If Not $bExport Or @OSArch <> 'X64' Then Return $sRegExe

	Switch $RegView
		Case '32'
			Return @WindowsDir & '\SysWOW64\reg.exe'
		Case '64'
			If @AutoItX64 Then Return @WindowsDir & '\System32\reg.exe'
			Return @WindowsDir & '\Sysnative\reg.exe'
	EndSwitch

	Return $sRegExe
EndFunc   ;==>_RegExePath

Func _RegKeyExists($sKey)
	Local $sCommand = _RegExePath() & ' QUERY "' & $sKey & '"' & _RegViewOption()
	Local $iResult = RunWait($sCommand, @SystemDir, @SW_HIDE)

	If @error Then Return False
	Return $iResult = 0
EndFunc   ;==>_RegKeyExists

Func _RegKeyDelete($sKey)
	Local $sCommand = _RegExePath() & ' DELETE "' & $sKey & '" /f' & _RegViewOption()
	Local $iResult = RunWait($sCommand, @SystemDir, @SW_HIDE)

	If @error Then Return False
	Return $iResult = 0
EndFunc   ;==>_RegKeyDelete

Func _RegFileGetRoots($regfile)
	Local $_sections = IniReadSectionNames($regfile)
	Local $_roots[1]
	Local $bChild, $sSection, $sOther

	$_roots[0] = 0
	If @error Then Return $_roots

	ReDim $_roots[$_sections[0] + 1]

	; Keep only independent top-level roots. Child sections are already included
	; when REG.EXE exports their parent root.
	For $i = 1 To $_sections[0]
		$sSection = $_sections[$i]
		$bChild = False

		For $r = 1 To $_sections[0]
			If $i = $r Then ContinueLoop

			$sOther = $_sections[$r]
			If StringLen($sOther) < StringLen($sSection) Then
				If StringLower(StringLeft($sSection, StringLen($sOther) + 1)) = StringLower($sOther & '\') Then
					$bChild = True
					ExitLoop
				EndIf
			EndIf
		Next

		If Not $bChild Then
			$_roots[0] += 1
			$_roots[$_roots[0]] = $sSection
		EndIf
	Next

	Return $_roots
EndFunc   ;==>_RegFileGetRoots

Func _RegBackupFileForRoot($backupfile, $iRoot)
	If $iRoot = 1 Then Return $backupfile

	If StringLower(StringRight($backupfile, 4)) = '.reg' Then
		Return StringTrimRight($backupfile, 4) & '-root' & $iRoot & '.reg'
	EndIf

	Return $backupfile & '-root' & $iRoot & '.reg'
EndFunc   ;==>_RegBackupFileForRoot

Func _RegBackupBaseFile($backupdir, $iFile, $iReg)
	; Keep both indexes explicitly separated. Concatenating them directly makes
	; pairs such as 1/11 and 11/1 produce the same backup filename.
	Return $backupdir & '\backup-' & $iFile & '-' & $iReg & '.reg'
EndFunc   ;==>_RegBackupBaseFile

Func _RegFileAppendExport($sTarget, $sSource)
	Local $hSource = FileOpen($sSource, 0)
	Local $hTarget, $sData

	If $hSource = -1 Then Return SetError(1, 0, 0)

	; Every REG.EXE export has its own header. Keep the first file's header and
	; append only the registry content from subsequent exports.
	FileReadLine($hSource)
	If @error Then
		FileClose($hSource)
		Return SetError(1, 0, 0)
	EndIf

	$sData = FileRead($hSource)
	FileClose($hSource)

	$hTarget = FileOpen($sTarget, 1)
	If $hTarget = -1 Then Return SetError(1, 0, 0)

	If FileWrite($hTarget, $sData) = 0 Then
		FileClose($hTarget)
		Return SetError(1, 0, 0)
	EndIf

	FileClose($hTarget)
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegFileAppendExport

Func _RegFileSaveRoots($regfile)
	Local $_roots = _RegFileGetRoots($regfile)
	Local $sMerged = $regfile & '.xlauncher-export.tmp'
	Local $sPart = $regfile & '.xlauncher-root.tmp'

	If $_roots[0] = 0 Then
		_DebugRegistryResult('SKIP', 'PortableStateSave', $regfile, 'reason=no registry roots')
		Return SetError(0, 0, 1)
	EndIf

	FileDelete($sMerged)
	FileDelete($sPart)

	; Build the complete replacement in temporary files first. The user's
	; portable REG file is replaced only after every root exported successfully.
	If _RegEdit($sMerged, 'EXPORT', $_roots[1]) = 0 Then
		FileDelete($sMerged)
		_DebugRegistryResult('FAIL', 'PortableStateSave', $regfile, 'root=' & $_roots[1])
		Return SetError(1, 0, 0)
	EndIf

	For $i = 2 To $_roots[0]
		FileDelete($sPart)

		If _RegEdit($sPart, 'EXPORT', $_roots[$i]) = 0 Then
			FileDelete($sMerged)
			FileDelete($sPart)
			_DebugRegistryResult('FAIL', 'PortableStateSave', $regfile, 'root=' & $_roots[$i])
			Return SetError(1, 0, 0)
		EndIf

		If Not _RegFileAppendExport($sMerged, $sPart) Then
			FileDelete($sMerged)
			FileDelete($sPart)
			_DebugRegistryResult('FAIL', 'PortableStateSave', $regfile, _
					'reason=temporary export merge failed; root=' & $_roots[$i])
			Return SetError(1, 0, 0)
		EndIf
	Next

	FileDelete($sPart)

	If FileMove($sMerged, $regfile, 1) = 0 Then
		FileDelete($sMerged)
		_DebugRegistryResult('FAIL', 'PortableStateSave', $regfile, 'reason=final file replacement failed')
		Return SetError(1, 0, 0)
	EndIf

	_DebugRegistryResult('PASS', 'PortableStateSave', $regfile, 'roots=' & $_roots[0])
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegFileSaveRoots

Func _RegTransactionBegin($string, $backupdir)
	Local $sManifest = $backupdir & '\transaction.ini'
	Local $_files, $_regs, $regfile, $path, $_roots
	Local $sBackupFile, $sBackupName
	Local $iKey = 0
	Local $iBackup = 0

	; Never overwrite recovery information from an unfinished transaction.
	If FileExists($sManifest) Then
		_DebugWrite(">>>>>> Registry transaction marker already exists: " & $sManifest)
		Return SetError(1, 0, 0)
	EndIf

	$_files = StringSplit($string, '|')

	For $i = 1 To $_files[0]
		If $_files[$i] = '*' Then ContinueLoop

		$_regs = StringSplit($_files[$i], ';')
		$path = _FileInfo(_FullPath($_regs[1]), 0)

		For $r = 1 To $_regs[0]
			If $r = 1 Then
				$regfile = _FullPath($_regs[$r])
			Else
				$regfile = $path & '\' & $_regs[$r]
			EndIf

			$_roots = _RegFileGetRoots($regfile)

			For $k = 1 To $_roots[0]
				$iKey += 1

				If IniWrite($sManifest, 'Keys', 'Key' & $iKey, $_roots[$k]) = 0 Then
					FileDelete($sManifest)
					Return SetError(2, 0, 0)
				EndIf

				; Backups were created immediately before this manifest.
				; Record every backup that actually exists in transaction order.
				$sBackupFile = _RegBackupFileForRoot(_RegBackupBaseFile($backupdir, $i, $r), $k)

				If FileExists($sBackupFile) Then
					$iBackup += 1
					$sBackupName = StringTrimLeft($sBackupFile, StringLen($backupdir) + 1)

					If IniWrite($sManifest, 'Backups', 'Backup' & $iBackup, $sBackupName) = 0 Then
						FileDelete($sManifest)
						Return SetError(2, 0, 0)
					EndIf
				EndIf
			Next
		Next
	Next

	; No registry keys means there is no transaction to recover.
	If $iKey = 0 Then
		FileDelete($sManifest)
		Return SetError(0, 0, 1)
	EndIf

	If IniWrite($sManifest, 'Transaction', 'RegView', $RegView) = 0 Then
		FileDelete($sManifest)
		Return SetError(2, 0, 0)
	EndIf

	If IniWrite($sManifest, 'Transaction', 'BackupCount', $iBackup) = 0 Then
		FileDelete($sManifest)
		Return SetError(2, 0, 0)
	EndIf

	If IniWrite($sManifest, 'Transaction', 'Pending', 'true') = 0 Then
		FileDelete($sManifest)
		Return SetError(2, 0, 0)
	EndIf

	If Not FileExists($sManifest) Then Return SetError(2, 0, 0)

	_DebugWrite("===== Registry transaction started: " & $sManifest & " =====")
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegTransactionBegin

Func _RegRestoreBackups($backupdir)
	Local $sManifest = $backupdir & '\transaction.ini'
	Local $sBackupCount, $sBackupName, $sBackupFile
	Local $_backups, $backup
	Local $iRestoreCount = 0

	; New transactions record an explicit ordered backup list.
	$sBackupCount = IniRead($sManifest, 'Transaction', 'BackupCount', '')

	If $sBackupCount <> '' Then
		If Not StringIsInt($sBackupCount) Then
			_DebugRegistryResult('FAIL', 'HostRestore', $sManifest, 'reason=invalid backup count')
			_DebugWrite(">>>>>> Registry restore failed - invalid backup count in transaction manifest")
			Return SetError(1, 0, 0)
		EndIf

		For $i = 1 To Int($sBackupCount)
			$sBackupName = IniRead($sManifest, 'Backups', 'Backup' & $i, '')

			If $sBackupName = '' Then
				_DebugRegistryResult('FAIL', 'HostRestore', $sManifest, _
						'reason=missing ordered entry Backup' & $i)
				_DebugWrite(">>>>>> Registry restore failed - ordered backup entry is missing: Backup" & $i)
				Return SetError(1, 0, 0)
			EndIf

			$sBackupFile = $backupdir & '\' & $sBackupName

			If Not FileExists($sBackupFile) Then
				_DebugRegistryResult('FAIL', 'HostRestore', $sBackupFile, 'reason=backup file missing')
				_DebugWrite(">>>>>> Registry restore failed - ordered backup is missing: " & $sBackupFile)
				Return SetError(1, 0, 0)
			EndIf

			If _RegEdit($sBackupFile) = 0 Then
				_DebugRegistryResult('FAIL', 'HostRestore', $sBackupFile, 'reason=import failed')
				_DebugWrite(">>>>>> Registry restore failed - backup preserved: " & $sBackupFile)
				Return SetError(1, 0, 0)
			EndIf

			$iRestoreCount += 1
			_DebugRegistryResult('PASS', 'HostRestore', $sBackupFile, 'order=' & $i)
		Next

		If $iRestoreCount = 0 Then
			_DebugRegistryResult('SKIP', 'HostRestore', $backupdir, 'reason=no host backups recorded')
		EndIf
		Return SetError(0, 0, 1)
	EndIf

	; Compatibility fallback for unfinished transactions created by an older
	; X-Launcher version before ordered backup manifests existed.
	$_backups = FileFindFirstFile($backupdir & '\*.reg')

	If $_backups <> -1 Then
		While 1
			$backup = FileFindNextFile($_backups)
			If @error Then ExitLoop

			If _RegEdit($backupdir & '\' & $backup) = 0 Then
				FileClose($_backups)
				_DebugRegistryResult('FAIL', 'HostRestore', $backupdir & '\' & $backup, _
						'reason=legacy backup import failed')
				_DebugWrite(">>>>>> Registry restore failed - legacy backup preserved: " & $backupdir & '\' & $backup)
				Return SetError(1, 0, 0)
			EndIf

			$iRestoreCount += 1
			_DebugRegistryResult('PASS', 'HostRestore', $backupdir & '\' & $backup, 'source=legacy backup')
		WEnd

		FileClose($_backups)
	EndIf

	If $iRestoreCount = 0 Then
		_DebugRegistryResult('SKIP', 'HostRestore', $backupdir, 'reason=no host backups found')
	EndIf
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegRestoreBackups

Func _RegTransactionRecover($backupdir)
	Local $sManifest = $backupdir & '\transaction.ini'
	Local $sCurrentRegView, $sSavedRegView
	Local $_keys, $_backups, $backup
	Local $bRecoveryOK = True

	If Not FileExists($sManifest) Then Return SetError(0, 0, 1)

	If IniRead($sManifest, 'Transaction', 'Pending', 'false') <> 'true' Then
		Return SetError(0, 0, 1)
	EndIf

	$sCurrentRegView = $RegView
	$sSavedRegView = StringUpper(StringStripWS(IniRead($sManifest, 'Transaction', 'RegView', 'Native'), 3))

	Switch $sSavedRegView
		Case '32'
		Case '64'
		Case Else
			$sSavedRegView = 'Native'
	EndSwitch

	; Recovery must use the same registry view as the interrupted transaction.
	$RegView = $sSavedRegView

	_DebugWrite("===== Recovering interrupted registry transaction: " & $backupdir & " =====")

	$_keys = IniReadSection($sManifest, 'Keys')
	If @error Then
		$RegView = $sCurrentRegView
		_DebugWrite(">>>>>> Registry recovery failed - transaction manifest is invalid")
		Return SetError(1, 0, 0)
	EndIf

	; Remove portable keys left behind by the interrupted transaction.
	For $i = 1 To $_keys[0][0]
		If _RegKeyExists($_keys[$i][1]) Then
			If Not _RegKeyDelete($_keys[$i][1]) Then
				$bRecoveryOK = False
				_DebugWrite(">>>>>> Registry recovery failed - cannot delete key: " & $_keys[$i][1])
				ExitLoop
			EndIf
		EndIf
	Next

	; Restore original-host backups in the recorded transaction order.
	If $bRecoveryOK Then
		If Not _RegRestoreBackups($backupdir) Then
			$bRecoveryOK = False
			_DebugWrite(">>>>>> Registry recovery failed - transaction backups preserved")
		EndIf
	EndIf

	$RegView = $sCurrentRegView

	If Not $bRecoveryOK Then
		Return SetError(1, 0, 0)
	EndIf

	; Recovery is complete only when the pending transaction can be removed.
	If Not DirRemove($backupdir, 1) Then
		_DebugRegistryResult('FAIL', 'TransactionCleanup', $backupdir, 'context=recovery')
		_DebugWrite(">>>>>> Registry recovery failed - transaction data could not be cleared: " & $backupdir)
		Return SetError(1, 0, 0)
	EndIf

	_DebugRegistryResult('PASS', 'TransactionCleanup', $backupdir, 'context=recovery')
	_DebugWrite("===== Interrupted registry transaction recovered successfully =====")
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegTransactionRecover

Func _RegRecoverPending($sRegeditRoot)
	Local $_backups, $backupdir

	If Not FileExists($sRegeditRoot) Then Return SetError(0, 0, 1)

	$_backups = FileFindFirstFile($sRegeditRoot & '\backup*')
	If $_backups = -1 Then Return SetError(0, 0, 1)

	While 1
		$backupdir = FileFindNextFile($_backups)
		If @error Then ExitLoop

		$backupdir = $sRegeditRoot & '\' & $backupdir

		If StringInStr(FileGetAttrib($backupdir), 'D') Then
			If FileExists($backupdir & '\transaction.ini') Then
				If Not _RegTransactionRecover($backupdir) Then
					FileClose($_backups)
					Return SetError(1, 0, 0)
				EndIf
			EndIf
		EndIf
	WEnd

	FileClose($_backups)
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegRecoverPending

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

	; Pass 1: verify every required backup before changing any registry key.
	For $i = 1 To $_files[0]
		If $_files[$i] = '*' Then ContinueLoop

		$_regs = StringSplit($_files[$i], ';')
		$reg1 = _FullPath($_regs[1])
		$path = _FileInfo($reg1, 0)

		If Not _RegKeyBackup($reg1, _RegBackupBaseFile($backupdir, $i, 1)) Then
			Return SetError(1, 0, 0)
		EndIf

		For $r = 2 To $_regs[0]
			$regfile = $path & '\' & $_regs[$r]

			If Not _RegKeyBackup($regfile, _RegBackupBaseFile($backupdir, $i, $r)) Then
				Return SetError(1, 0, 0)
			EndIf
		Next
	Next

	; All required backups now exist. Record the pending transaction before
	; making the first registry change.
	If Not _RegTransactionBegin($string, $backupdir) Then
		_DebugWrite(">>>>>> Registry installation aborted - transaction marker could not be created")
		Return SetError(2, 0, 0)
	EndIf

	; Pass 2: all required backups are safe, so install the portable keys.
	For $i = 1 To $_files[0]
		If $_files[$i] = '*' Then ContinueLoop

		$_regs = StringSplit($_files[$i], ';')
		$reg1 = _FullPath($_regs[1])
		$path = _FileInfo($reg1, 0)

		If Not _RegKeyLoad($reg1, _RegBackupBaseFile($backupdir, $i, 1), True) Then
			Local $iInstallError = @error
			_DebugWrite(">>>>>> Registry installation failed - attempting transaction recovery")

			If Not _RegTransactionRecover($backupdir) Then
				_DebugWrite(">>>>>> Registry recovery failed - transaction data preserved")
			EndIf

			Return SetError(3, $iInstallError, 0)
		EndIf

		For $r = 2 To $_regs[0]
			$regfile = $path & '\' & $_regs[$r]

			If Not _RegKeyLoad($regfile, _RegBackupBaseFile($backupdir, $i, $r), True) Then
				Local $iInstallError = @error
				_DebugWrite(">>>>>> Registry installation failed - attempting transaction recovery")

				If Not _RegTransactionRecover($backupdir) Then
					_DebugWrite(">>>>>> Registry recovery failed - transaction data preserved")
				EndIf

				Return SetError(3, $iInstallError, 0)
			EndIf
		Next
	Next

	Return SetError(0, 0, 1)
EndFunc   ;==>_RegFileInstall

Func _RegKeyBackup($regfile, $backupfile)
	Local $_roots = _RegFileGetRoots($regfile)
	Local $iBackupResult, $sBackupFile
	If $_roots[0] = 0 Then
		_DebugRegistryResult('SKIP', 'HostBackup', $regfile, 'reason=no registry roots')
		Return SetError(0, 0, 1)
	EndIf

	For $i = 1 To $_roots[0]
		$sBackupFile = _RegBackupFileForRoot($backupfile, $i)
		$iBackupResult = _RegEdit($sBackupFile, 'EXPORT', $_roots[$i])

		If $iBackupResult = 0 Then
			; An export failure is harmless only when the selected-view host key did not exist.
			If _RegKeyExists($_roots[$i]) Then
				_DebugRegistryResult('FAIL', 'HostBackup', $_roots[$i], 'file=' & $sBackupFile)
				_DebugWrite(">>>>>> Registry backup failed - original key preserved: " & $_roots[$i])
				Return SetError(1, 0, 0)
			EndIf
			_DebugRegistryResult('SKIP', 'HostBackup', $_roots[$i], 'reason=host key not present')
		Else
			; Successful export must have created a real non-empty backup file.
			If Not FileExists($sBackupFile) Or FileGetSize($sBackupFile) <= 0 Then
				_DebugRegistryResult('FAIL', 'HostBackup', $_roots[$i], _
						'reason=backup file missing or empty; file=' & $sBackupFile)
				_DebugWrite(">>>>>> Registry backup invalid - original key preserved: " & $_roots[$i])
				Return SetError(1, 0, 0)
			EndIf
			_DebugRegistryResult('PASS', 'HostBackup', $_roots[$i], 'file=' & $sBackupFile)
		EndIf
	Next

	Return SetError(0, 0, 1)
EndFunc   ;==>_RegKeyBackup

;===============================================================================
;
; Function Name:	_RegKeyLoad()
; Description:		Installs a single *.reg file. If the key already exists, it
;					will backuped in folder to be restored with _RegFileRestore()
;
;===============================================================================
Func _RegKeyLoad($regfile, $backupfile, $bBackupDone = False)
	Local $_roots

	If Not $bBackupDone Then
		If Not _RegKeyBackup($regfile, $backupfile) Then
			Return SetError(1, 0, 0)
		EndIf
	EndIf

	$_roots = _RegFileGetRoots($regfile)
	If $_roots[0] = 0 Then
		_DebugRegistryResult('SKIP', 'PortableImport', $regfile, 'reason=no registry roots')
		Return SetError(0, 0, 1)
	EndIf

	; Every independent root imported by this REG file must be removed first.
	; Otherwise a second root can merge with unprotected host data.
	For $i = 1 To $_roots[0]
		If _RegKeyExists($_roots[$i]) Then
			If Not _RegKeyDelete($_roots[$i]) Then
				_DebugRegistryResult('FAIL', 'PortableImport', $regfile, _
						'reason=cannot clear key; root=' & $_roots[$i])
				_DebugWrite(">>>>>> Registry installation failed - cannot delete protected key: " & $_roots[$i])
				Return SetError(2, 0, 0)
			EndIf
		EndIf
	Next

	If $_roots[0] > 0 Then
		; A failed import must stop the transaction.
		If _RegEdit($regfile) = 0 Then
			_DebugRegistryResult('FAIL', 'PortableImport', $regfile, 'roots=' & $_roots[0])
			_DebugWrite(">>>>>> Registry installation failed - cannot import: " & $regfile)
			Return SetError(3, 0, 0)
		EndIf
	EndIf

	_DebugRegistryResult('PASS', 'PortableImport', $regfile, 'roots=' & $_roots[0])
	Return SetError(0, 0, 1)
EndFunc   ;==>_RegKeyLoad

;===============================================================================
;
; Function Name:	_RegFileRestore()
; Description:		Restores the original reg keys previously backuped from _RegFileInstall()
; Requirements:		_FullPath, _FileInfo, _RegKeyGet, _RegEdit
;
;===============================================================================
Func _RegFileRestore($string, $backupdir)
	Local $_files, $_f, $_regs, $regfile, $path, $_roots, $_backups, $backup
	Local $bRestoreOK = True
	Local $bResultOK = True
	Local $bPortableKeyDeleteResult, $bTransactionCleanupResult

	$_files = StringSplit($string, '|')
	If $_files[$_files[0]] = '*' Then
		$_f = $_files[0] - 1
	Else
		$_f = $_files[0]
	EndIf

	For $i = 1 To $_f
		$_regs = StringSplit($_files[$i], ';')
		$path = _FileInfo(_FullPath($_regs[1]), 0)

		For $r = 1 To $_regs[0]
			If $r = 1 Then
				$regfile = _FullPath($_regs[$r])
			Else
				$regfile = $path & '\' & $_regs[$r]
			EndIf

			; Save the current portable registry state from every independent root.
			If Not _RegFileSaveRoots($regfile) Then
				$bRestoreOK = False
				_DebugWrite(">>>>>> Registry portable-state export failed: " & $regfile)
			EndIf

			If $_files[$_files[0]] <> '*' Then
				$_roots = _RegFileGetRoots($regfile)

				For $k = 1 To $_roots[0]
					$bPortableKeyDeleteResult = _RegKeyDelete($_roots[$k])

					If $bPortableKeyDeleteResult Then
						_DebugRegistryResult('PASS', 'PortableKeyRemoval', $_roots[$k])
					ElseIf Not _RegKeyExists($_roots[$k]) Then
						_DebugRegistryResult('SKIP', 'PortableKeyRemoval', $_roots[$k], _
								'reason=portable key not present after delete attempt')
					Else
						$bResultOK = False
						_DebugRegistryResult('FAIL', 'PortableKeyRemoval', $_roots[$k])
					EndIf
				Next
			EndIf
		Next
	Next

	If $_files[$_files[0]] = '*' Then
		_DebugRegistryResult('SKIP', 'PortableKeyRemoval', $string, 'reason=asterisk retention configured')
	EndIf

	If $_files[$_files[0]] <> '*' Then
		If Not _RegRestoreBackups($backupdir) Then
			$bRestoreOK = False
			_DebugWrite(">>>>>> Registry restore failed - transaction backups preserved")
		EndIf
	Else
		_DebugRegistryResult('SKIP', 'HostRestore', $backupdir, 'reason=asterisk retention configured')
	EndIf

	If $bRestoreOK Then
		$bTransactionCleanupResult = DirRemove($backupdir, 1)
		If $bTransactionCleanupResult Then
			_DebugRegistryResult('PASS', 'TransactionCleanup', $backupdir, 'context=normal close')
		ElseIf Not FileExists($backupdir) Then
			_DebugRegistryResult('SKIP', 'TransactionCleanup', $backupdir, 'reason=transaction data not present')
		Else
			$bResultOK = False
			_DebugRegistryResult('FAIL', 'TransactionCleanup', $backupdir, 'context=normal close')
		EndIf

		; The historic caller ignores this return. Normalise it so Debug can report
		; deletion or cleanup failures without changing the restoration sequence.
		If $bResultOK Then Return SetError(0, 0, 1)
		Return SetError(2, 0, 0)
	EndIf

	Return SetError(1, 0, 0)
EndFunc   ;==>_RegFileRestore

;===============================================================================
;
; Function Name:	_WriteToReg()
; Description:		Writes text to a specific line in a file
; Syntax:			_WriteLine(File, LineX or EOF, String)
;
;===============================================================================
Func _RegFileValueName($name)
	; A named REG_SZ entry requires the value name to be quoted.
	; Escape characters that are significant inside a .reg quoted name.
	$name = StringReplace($name, '\', '\\')
	$name = StringReplace($name, '"', '\"')
	Return '"' & $name & '"'
EndFunc   ;==>_RegFileValueName

Func _RegFileStringValue($value)
	; Preserve the existing _FullPathPlus quote option. If it already supplied
	; the outer quotes, do not add another pair.
	If StringLen($value) >= 2 Then
		If StringLeft($value, 1) = '"' And StringRight($value, 1) = '"' Then Return $value
	EndIf

	; Embedded quotes must be escaped inside REG_SZ string data.
	$value = StringReplace($value, '"', '\"')
	Return '"' & $value & '"'
EndFunc   ;==>_RegFileStringValue

Func _WriteToReg($file, $mainkey, $subkey, $name, $value)
	Local $write, $key, $iChanged = 0
	AutoItSetOption('ExpandEnvStrings', 0)
	AutoItSetOption('ExpandVarStrings', 0)
	Local $sRegVersion = ''
	If FileExists($file) And _RegKeyGet($file) = $mainkey Then $sRegVersion = FileReadLine($file, 1)
	Switch $sRegVersion
		Case 'REGEDIT4'
		Case 'Windows Registry Editor Version 5.00'
		Case Else
			$write = FileOpen($file, 10)
			If $write = -1 Then
				AutoItSetOption('ExpandEnvStrings', 1)
				AutoItSetOption('ExpandVarStrings', 1)
				Return SetError(1, 0, 0)
			EndIf
			Local $bHeaderOK = False
			If FileWriteLine($write, 'REGEDIT4') <> 0 Then $bHeaderOK = True
			If FileWriteLine($write, '[' & $mainkey & ']') = 0 Then $bHeaderOK = False
			FileClose($write)
			If Not $bHeaderOK Then
				AutoItSetOption('ExpandEnvStrings', 1)
				AutoItSetOption('ExpandVarStrings', 1)
				Return SetError(2, 0, 0)
			EndIf
			$iChanged = 1
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

			; IniWrite is retained only for its existing section/update behaviour.
			; The key and data are now explicitly formatted as valid .reg REG_SZ
			; syntax instead of being written as ordinary INI data.
			If IniWrite($file, $key, _RegFileValueName($name), _RegFileStringValue($value)) = 0 Then
				AutoItSetOption('ExpandEnvStrings', 1)
				AutoItSetOption('ExpandVarStrings', 1)
				Return SetError(3, 0, 0)
			EndIf
			$iChanged = 1
	EndSelect
	AutoItSetOption('ExpandEnvStrings', 1)
	AutoItSetOption('ExpandVarStrings', 1)
	Return SetError(0, 0, $iChanged)
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

			If $sOperation = 'EXPORT' Then
				$sCommand = _RegExePath(True)
			Else
				$sCommand = _RegExePath()
			EndIf

			Local $bExternalRegManager = False
			Local $sRegManager = _RegManager()

			If Not @error And $sRegManager <> '' Then
				; A custom registry manager has no defined RegView contract.
				If $RegView <> 'Native' Then
					_DebugWrite(">>>>>> Registry " & $sOperation & " failed - external registry manager cannot guarantee RegView=" & $RegView)
					Return SetError(3, 0, 0)
				EndIf

				$sCommand = $sRegManager
				$sPostOpt = ''
				$bExternalRegManager = True
			EndIf

			Switch $sOperation
				Case "IMPORT"
					$sCommand &= ' IMPORT "' & $sFile & '"'
					If Not $bExternalRegManager Then $sCommand &= _RegViewOption()

				Case "EXPORT"
					FileDelete($sFile)
					$sCommand &= ' EXPORT "' & $sKey & '" "' & $sFile & '"' & $sPostOpt
			EndSwitch
	EndSwitch

	Local $sRegTest = RunWait($sCommand, $sExePath, @SW_HIDE)
	Local $iRunError = @error

	If $iRunError Then
		_DebugWrite(">>>>>> Registry " & $sOperation & " failed - launch error=" & $iRunError & " Command: " & $sCommand)
		Return SetError(2, $iRunError, 0)
	EndIf

	If $sRegTest <> 0 Then
		_DebugWrite(">>>>>> Registry " & $sOperation & " failed - exit code=" & $sRegTest & " Command: " & $sCommand)
		Return SetError(2, $sRegTest, 0)
	EndIf

	Return SetError(0, 0, 1)
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
