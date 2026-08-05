; ------------------------------------------------------------------------------
;
;					X-install
;
; ------------------------------------------------------------------------------
;
;===============================================================================
;
; Function Name:	_DefaultInstal()
; Description:		Install base default files
; Syntax:			_DefaultInstal(Tempdir, lang)
;
;===============================================================================
Func _DefaultInstall($Temp, $Lang="it")
	
	;  Install x-defaults
	FileInstall('files\x-default', $Temp & '\x-default')
	
	#cs
	; Install locale files
	FileInstall('files\x-default_it', $Temp & '\x-default_it')
	FileInstall('files\x-default_en', $Temp & '\x-default_en')
	
	; Install OpenOffice files
	FileInstall('files\x-default_views', $Temp & '\x-default_views')
	FileInstall('files\x-default_paths', $Temp & '\x-default_paths')
	FileInstall('files\x-default_common', $Temp & '\x-default_common')
	FileInstall('files\x-default_lang', $Temp & '\x-default_lang')

	; Install Dia - Scribus files
	FileInstall('files\x-default_options', $Temp & '\x-default_options')

	; Install KompoZer files
	FileInstall('files\x-default_comp', $Temp & '\x-default_comp')
	FileInstall('files\x-default_def', $Temp & '\x-default_def')
	#ce

EndFunc   ;==>_DefaultInstal
