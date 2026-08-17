Global $Root = @ScriptDir
Global $tempdir = @ScriptDir & '\Test_Suite\Working\Test24\WrongTemp'

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test24'
Local $sTemp = $sWork & '\Temp'
Local $sLog = $sWork & '\Probe.log'
Local $sTitle = 'X-Launcher Issue 14 Splash Test'
Local $sImage = @ScriptDir & '\graphics\x-splash.jpg'
Local $iExpectedWidth = 421
Local $iExpectedHeight = 257
Local $sNaturalTitle = 'X-Launcher Natural Splash Test'
Local $sWidthOnlyTitle = 'X-Launcher Width Only Splash Test'
Local $sHeightOnlyTitle = 'X-Launcher Height Only Splash Test'
Local $sNaturalImage = $sWork & '\NaturalSize.bmp'
Local $iNaturalWidth = 181
Local $iNaturalHeight = 117
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($sTemp)
DirCreate($tempdir)

_SplashScreen($sTitle, $sImage, 5000, $sTemp, $Root, $iExpectedWidth, $iExpectedHeight)

Local $hSplash = WinGetHandle($sTitle)
Local $bTitleUsed = ($hSplash <> 0)
Local $bWidthUsed = False
Local $bHeightUsed = False

If $bTitleUsed Then
	Local $aClientSize = WinGetClientSize($hSplash)
	If IsArray($aClientSize) Then
		$bWidthUsed = ($aClientSize[0] = $iExpectedWidth)
		$bHeightUsed = ($aClientSize[1] = $iExpectedHeight)
	EndIf
EndIf

_WriteProbeResult($sLog, 'Configured splash title used', $bTitleUsed)
_WriteProbeResult($sLog, 'Configured splash width used', $bWidthUsed)
_WriteProbeResult($sLog, 'Configured splash height used', $bHeightUsed)

_SplashScreenOff()

If Not $bTitleUsed Or Not $bWidthUsed Or Not $bHeightUsed Then $bAllPass = False

Local $sPowerShellPath = StringReplace($sNaturalImage, "'", "''")
Local $sPowerShell = 'powershell.exe -NoProfile -NonInteractive -Command "' & _
		'Add-Type -AssemblyName System.Drawing; ' & _
		'$bmp = New-Object System.Drawing.Bitmap -ArgumentList ' & $iNaturalWidth & ',' & $iNaturalHeight & '; ' & _
		'$bmp.Save(''' & $sPowerShellPath & ''',[System.Drawing.Imaging.ImageFormat]::Bmp); ' & _
		'$bmp.Dispose()"'
Local $iPowerShellExit = RunWait($sPowerShell, '', @SW_HIDE)
Local $bNaturalImageCreated = ($iPowerShellExit = 0 And FileExists($sNaturalImage))
Local $bImageDimensionsDetected = False

If $bNaturalImageCreated Then
	Local $aDetectedSize = _ImageGetSize($sNaturalImage)
	If IsArray($aDetectedSize) Then
		$bImageDimensionsDetected = ($aDetectedSize[0] = $iNaturalWidth And _
				$aDetectedSize[1] = $iNaturalHeight)
	EndIf
EndIf

_WriteProbeResult($sLog, 'Natural-size splash fixture created', $bNaturalImageCreated)
_WriteProbeResult($sLog, 'Image dimensions detected', $bImageDimensionsDetected)

Local $bNaturalWidthUsed = False
Local $bNaturalHeightUsed = False
If $bNaturalImageCreated Then
	_SplashScreen($sNaturalTitle, $sNaturalImage, 5000, $sTemp, $Root, '', '')
	Local $hNaturalSplash = WinGetHandle($sNaturalTitle)
	If $hNaturalSplash <> 0 Then
		Local $aNaturalClientSize = WinGetClientSize($hNaturalSplash)
		If IsArray($aNaturalClientSize) Then
			$bNaturalWidthUsed = ($aNaturalClientSize[0] = $iNaturalWidth)
			$bNaturalHeightUsed = ($aNaturalClientSize[1] = $iNaturalHeight)
		EndIf
	EndIf
	_SplashScreenOff()
EndIf

_WriteProbeResult($sLog, 'Blank width used natural image width', $bNaturalWidthUsed)
_WriteProbeResult($sLog, 'Blank height used natural image height', $bNaturalHeightUsed)

Local $bWidthOnlyAspect = False
If $bNaturalImageCreated Then
	_SplashScreen($sWidthOnlyTitle, $sNaturalImage, 5000, $sTemp, $Root, 362, '')
	Local $hWidthOnlySplash = WinGetHandle($sWidthOnlyTitle)
	If $hWidthOnlySplash <> 0 Then
		Local $aWidthOnlySize = WinGetClientSize($hWidthOnlySplash)
		If IsArray($aWidthOnlySize) Then
			$bWidthOnlyAspect = ($aWidthOnlySize[0] = 362 And $aWidthOnlySize[1] = 234)
		EndIf
	EndIf
	_SplashScreenOff()
EndIf

Local $bHeightOnlyAspect = False
If $bNaturalImageCreated Then
	_SplashScreen($sHeightOnlyTitle, $sNaturalImage, 5000, $sTemp, $Root, '', 234)
	Local $hHeightOnlySplash = WinGetHandle($sHeightOnlyTitle)
	If $hHeightOnlySplash <> 0 Then
		Local $aHeightOnlySize = WinGetClientSize($hHeightOnlySplash)
		If IsArray($aHeightOnlySize) Then
			$bHeightOnlyAspect = ($aHeightOnlySize[0] = 362 And $aHeightOnlySize[1] = 234)
		EndIf
	EndIf
	_SplashScreenOff()
EndIf

_WriteProbeResult($sLog, 'Blank height preserved image aspect ratio', $bWidthOnlyAspect)
_WriteProbeResult($sLog, 'Blank width preserved image aspect ratio', $bHeightOnlyAspect)

If Not $bNaturalImageCreated Or Not $bImageDimensionsDetected Or _
		Not $bNaturalWidthUsed Or Not $bNaturalHeightUsed Or _
		Not $bWidthOnlyAspect Or Not $bHeightOnlyAspect Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _WriteProbeResult($sFile, $sName, $bPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return

	If $bPass Then
		FileWriteLine($hFile, $sName & ': PASS')
	Else
		FileWriteLine($hFile, $sName & ': FAIL')
	EndIf

	FileClose($hFile)
EndFunc
