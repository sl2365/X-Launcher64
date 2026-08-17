Global $Root = @ScriptDir
Global $tempdir = @ScriptDir & '\Test_Suite\Working\Test50\Temp'

#include 'x-udf.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test50'
Local $sLog = $sWork & '\Probe.log'
Local $sCorrectedFalse = $sWork & '\CorrectedFalse.ini'
Local $sCorrectedTrue = $sWork & '\CorrectedTrue.ini'
Local $sFormerOnly = $sWork & '\FormerOnly.ini'
Local $sInvalidCorrected = $sWork & '\InvalidCorrected.ini'
Local $sFormerKey = 'Multiple' & 'Istances'
Local $bAllPass = True

DirRemove($sWork, 1)
DirCreate($tempdir)

Local $bFixtures = _WriteFixture($sCorrectedFalse, _
		'[Options]' & @CRLF & 'MultipleInstances=false' & @CRLF) And _
		_WriteFixture($sCorrectedTrue, _
		'[Options]' & @CRLF & 'MultipleInstances=true' & @CRLF) And _
		_WriteFixture($sFormerOnly, _
		'[Options]' & @CRLF & $sFormerKey & '=false' & @CRLF) And _
		_WriteFixture($sInvalidCorrected, _
		'[Options]' & @CRLF & 'MultipleInstances=maybe' & @CRLF)

Local $sCorrectedFalseResult = _ResolveMultipleInstancesOption($sCorrectedFalse, 'true')
Local $sCorrectedTrueResult = _ResolveMultipleInstancesOption($sCorrectedTrue, 'true')
Local $sFormerOnlyResult = _ResolveMultipleInstancesOption($sFormerOnly, 'true')
Local $sInvalidResult = _ResolveMultipleInstancesOption($sInvalidCorrected, 'true')
Local $bCorrectedFalse = ($bFixtures And ($sCorrectedFalseResult == 'false'))
Local $bCorrectedTrue = ($bFixtures And ($sCorrectedTrueResult == 'true'))
Local $bFormerIgnored = ($bFixtures And ($sFormerOnlyResult == 'true'))
Local $bInvalidDefault = ($bFixtures And ($sInvalidResult == 'true'))

_WriteProbeValue($sLog, 'Corrected-false resolved value', $sCorrectedFalseResult)
_WriteProbeValue($sLog, 'Corrected-true resolved value', $sCorrectedTrueResult)
_WriteProbeValue($sLog, 'Former-only resolved value', $sFormerOnlyResult)
_WriteProbeValue($sLog, 'Invalid-corrected resolved value', $sInvalidResult)

_WriteProbeResult($sLog, 'Corrected false value is accepted', $bCorrectedFalse)
_WriteProbeResult($sLog, 'Corrected true value is accepted', $bCorrectedTrue)
_WriteProbeResult($sLog, 'Former misspelling is not accepted', $bFormerIgnored)
_WriteProbeResult($sLog, 'Invalid corrected value uses the default', $bInvalidDefault)

If Not $bFixtures Or Not $bCorrectedFalse Or Not $bCorrectedTrue Or _
		Not $bFormerIgnored Or Not $bInvalidDefault Then $bAllPass = False

If $bAllPass Then Exit 0
Exit 1

Func _WriteFixture($sPath, $sContent)
	Local $hFile = FileOpen($sPath, 2 + 8)
	If $hFile = -1 Then Return False
	Local $iWritten = FileWrite($hFile, $sContent)
	Local $iWriteError = @error
	FileClose($hFile)
	Return $iWritten = 1 And $iWriteError = 0
EndFunc

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

Func _WriteProbeValue($sFile, $sName, $sValue)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile = -1 Then Return
	FileWriteLine($hFile, $sName & ': ' & $sValue)
	FileClose($hFile)
EndFunc
