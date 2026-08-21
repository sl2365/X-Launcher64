AutoItSetOption('ExpandEnvStrings', 1)
AutoItSetOption('ExpandVarStrings', 1)

Global $Root = @ScriptDir & '\Test_Suite\Working\Test48B\Root'
Global $ScriptIni = @ScriptDir & '\Test_Suite\Working\Test48B\Trace.ini'
Global $ScriptName = 'PortabilityFixture'
Global $AppName = 'Portability Fixture'
Global $AppVer = '1.0'
Global $RegView = 'Native'
Global $TraceProcMonCapturePartial = False
Global $TraceProcMonDetailAvailable = True
Global $Temp = $Root & '\Temp', $Cache = $Root & '\Cache'
Global $Home = $Root & '\Home', $Bin = $Root & '\Bin', $Lib = $Root & '\Lib'
Global $Doc = $Root & '\Documents', $Backup = $Root & '\Backup'
Global $Download = $Root & '\Download', $UserProfile = $Root & '\Profile'

#include 'x-udf.au3'
#include 'x-registry.au3'

Local $sWork = @ScriptDir & '\Test_Suite\Working\Test48B'
Local $sExternal = $sWork & '\External'
Local $sCSV = $sWork & '\Application_Trace.csv'
Local $sXML = $sWork & '\Application_Trace.xml'
Local $sConvertedCSV = $sWork & '\Application_Trace_Converted.csv'
Local $sPMC = $sWork & '\Application_Trace_Filter.pmc'
Local $sReport = $sWork & '\Application_Portability_Report.log'
Local $sLog = $sWork & '\Helper.log'
Local $sManagedFile = $sExternal & '\Managed, Settings.ini'
Local $sUnmanagedFile = $sExternal & '\Unmanaged.txt'
Local $sIgnoredFile = $sExternal & '\UnrelatedProcess.txt'
Local $sContainedFile = $Root & '\Data\Contained.txt'
Local $sChildFile = $Root & '\Data\Child.txt'
Local $sLauncherFile = $Root & '\LauncherAction.txt'
Local $sRegFile = $Root & '\Portable.reg'

DirCreate($Root & '\Data')
DirCreate($sExternal)
FileWrite($sContainedFile, 'contained')
FileWrite($sChildFile, 'child')
FileWrite($sManagedFile, 'managed')
FileWrite($sLauncherFile, 'launcher')

Local $hReg = FileOpen($sRegFile, 2 + 128)
If $hReg <> -1 Then
	FileWrite($hReg, 'Windows Registry Editor Version 5.00' & @CRLF & @CRLF & _
			'[HKEY_CURRENT_USER\Software\XLauncherStage8\Managed]' & @CRLF & _
			'"Portable"="1"' & @CRLF)
	FileClose($hReg)
EndIf

; Keep the generated fixture INI free of a UTF-8 BOM so its first section is
; visible to AutoIt's standard INI functions.
Local $hIni = FileOpen($ScriptIni, 2)
If $hIni <> -1 Then
	FileWrite($hIni, '[RunBefore]' & @CRLF & _
			'Regedit=.\Portable.reg' & @CRLF & @CRLF & _
			'[RunAfter]' & @CRLF & _
			'FileMove=' & $sManagedFile & '|.\Captured\Managed.ini|o' & @CRLF & @CRLF & _
			'[WriteToFile=.\Data\Contained.txt]' & @CRLF & _
			'Line1=fixture' & @CRLF)
	FileClose($hIni)
EndIf

Local $hCSV = FileOpen($sCSV, 2 + 128)
If $hCSV <> -1 Then
	FileWriteLine($hCSV, '"Time of Day","Process Name","PID","Operation","Path","Result","Detail"')
	_T48BCSV($hCSV, '10:00:00.000', 'Payload.exe', 1000, 'Process Start', _
			$Root & '\Payload.exe', 'SUCCESS', 'Parent PID: 900, Command line: Payload.exe')
	_T48BCSV($hCSV, '10:00:00.010', 'Child.exe', 1001, 'Process Start', _
			$Root & '\Child.exe', 'SUCCESS', 'Parent PID: 1000, Command line: Child.exe')
	_T48BCSV($hCSV, '10:00:00.020', 'Payload.exe', 1000, 'CreateFile', _
			$sContainedFile, 'SUCCESS', _
			'Desired Access: Generic Write, Disposition: OpenIf, Options: Non-Directory File')
	_T48BCSV($hCSV, '10:00:00.030', 'Payload.exe', 1000, 'WriteFile', _
			$sContainedFile, 'SUCCESS', 'Offset: 0, Length: 9')
	_T48BCSV($hCSV, '10:00:00.040', 'Child.exe', 1001, 'WriteFile', _
			$sChildFile, 'SUCCESS', 'Offset: 0, Length: 5')
	_T48BCSV($hCSV, '10:00:00.050', 'Payload.exe', 1000, 'WriteFile', _
			$sManagedFile, 'SUCCESS', 'Offset: 0, Length: 7')
	_T48BCSV($hCSV, '10:00:00.060', 'Payload.exe', 1000, 'WriteFile', _
			$sUnmanagedFile, 'SUCCESS', 'Offset: 0, Length: 9')
	_T48BCSV($hCSV, '10:00:00.070', 'Payload.exe', 1000, 'RegSetValue', _
			'HKCU\Software\XLauncherStage8\Managed\Portable', 'SUCCESS', 'Type: REG_SZ')
	_T48BCSV($hCSV, '10:00:00.080', 'Payload.exe', 1000, 'RegSetValue', _
			'HKCU\Software\XLauncherStage8\Unmanaged\Setting', 'SUCCESS', 'Type: REG_SZ')
	_T48BCSV($hCSV, '10:00:00.090', 'X-Launcher_x64.exe', 2000, 'WriteFile', _
			$sLauncherFile, 'SUCCESS', 'Offset: 0, Length: 8')
	_T48BCSV($hCSV, '10:00:00.100', 'Payload.exe', 1000, 'CreateFile', _
			$sExternal & '\Denied.txt', 'ACCESS DENIED', _
			'Desired Access: Generic Write, Disposition: OpenIf')
	_T48BCSV($hCSV, '10:00:00.110', 'Unrelated.exe', 3000, 'WriteFile', _
			$sIgnoredFile, 'SUCCESS', 'Offset: 0, Length: 4')
	FileClose($hCSV)
EndIf

Local $hXML = FileOpen($sXML, 2 + 128)
If $hXML <> -1 Then
	FileWrite($hXML, '<?xml version="1.0" encoding="UTF-8"?>' & @CRLF & _
			'<procmon><processlist><process>' & @CRLF & _
			'<ProcessIndex>1</ProcessIndex>' & @CRLF & _
			'<ProcessId>1000</ProcessId>' & @CRLF & _
			'<ParentProcessId>900</ParentProcessId>' & @CRLF & _
			'<ProcessName>Payload.exe</ProcessName>' & @CRLF & _
			'<CommandLine>Payload.exe --fixture</CommandLine>' & @CRLF & _
			'</process>' & @CRLF & '</processlist><eventlist>' & @CRLF & _
			'<event>' & @CRLF & '<ProcessIndex>1</ProcessIndex>' & @CRLF & _
			'<Process_Name>Payload.exe</Process_Name>' & @CRLF & _
			'<Operation>RegSetInfoKey</Operation>' & @CRLF & _
			'<Path>HKCU\Software\Noise</Path>' & @CRLF & _
			'<Result>SUCCESS</Result>' & @CRLF & _
			'<Detail>Last Write Time: fixture</Detail>' & @CRLF & _
			'</event>' & @CRLF & _
			'<event>' & @CRLF & '<ProcessIndex>1</ProcessIndex>' & @CRLF & _
			'<Process_Name>Payload.exe</Process_Name>' & @CRLF & _
			'<Operation>WriteFile</Operation>' & @CRLF & _
			'<Path>C:\Fixture\A&amp;B.txt</Path>' & @CRLF & _
			'<Result>SUCCESS</Result>' & @CRLF & _
			'</event>' & @CRLF & '</eventlist>' & @CRLF & '</procmon>' & @CRLF)
	FileClose($hXML)
EndIf

Local $bBuilt = _TraceBuildPortabilityReportFromCSV($sCSV, $sReport, $ScriptIni, _
		1000, '|', 2000, $Root)
Local $iBuildError = @error
Local $sText = FileRead($sReport)
Local $bAllPass = True

Local $bXMLConverted = _TraceConvertProcMonXMLToCSV($sXML, $sConvertedCSV)
Local $iXMLProcess = -1, $iXMLPID = -1, $iXMLOperation = -1
Local $iXMLPath = -1, $iXMLResult = -1, $iXMLDetail = -1
Local $bXMLHeader = _TraceCSVReadHeader($sConvertedCSV, $iXMLProcess, $iXMLPID, _
		$iXMLOperation, $iXMLPath, $iXMLResult, $iXMLDetail)
Local $sConvertedText = FileRead($sConvertedCSV)
_T48BResult($sLog, 'ProcMon XML process index maps to PID and canonical parser input', _
		$bXMLConverted And $bXMLHeader And $iXMLPID >= 0 And $iXMLDetail >= 0 And _
		StringInStr($sConvertedText, 'C:\Fixture\A&B.txt', 1) > 0 And _
		StringInStr($sConvertedText, 'Parent PID: 900, Command line: Payload.exe --fixture', 1) > 0 And _
		StringInStr($sConvertedText, '"Payload.exe","1000","WriteFile"', 1) > 0 And _
		StringInStr($sConvertedText, 'RegSetInfoKey', 1) = 0 And _
		StringInStr($sConvertedText, 'HKCU\Software\Noise', 1) = 0 And _
		Not $TraceProcMonDetailAvailable, $bAllPass)

Local $bPMCWritten = _TraceWriteProcMonPortabilityConfig($sPMC, $Root)
Local $iPMCRules = @extended
Local $sPMCHex = ''
Local $hPMC = FileOpen($sPMC, 16)
If $hPMC <> -1 Then
	$sPMCHex = String(FileRead($hPMC))
	FileClose($hPMC)
EndIf
Local $sCategoryRulePrefix = _TracePMCHexInt32(40086) & _TracePMCHexInt32(0) & '01'
Local $sCategoryWrite = $sCategoryRulePrefix & _TracePMCHexInt32(12) & _
		_TracePMCHexUTF16('Write')
Local $sCategoryWriteMetadata = $sCategoryRulePrefix & _TracePMCHexInt32(30) & _
		_TracePMCHexUTF16('Write Metadata')
Local $sCategoryProcess = $sCategoryRulePrefix & _TracePMCHexInt32(16) & _
		_TracePMCHexUTF16('Process')
Local $sOperationExcludePrefix = _TracePMCHexInt32(40055) & _
		_TracePMCHexInt32(0) & '00'
Local $sRegMetadataExclude = $sOperationExcludePrefix & _TracePMCHexInt32(28) & _
		_TracePMCHexUTF16('RegSetInfoKey')
Local $sBAMPath = 'HKLM\System\CurrentControlSet\Services\bam\State\UserSettings'
Local $sBAMExclude = _TracePMCHexInt32(40071) & _TracePMCHexInt32(4) & '00' & _
		_TracePMCHexInt32((StringLen($sBAMPath) + 1) * 2) & _TracePMCHexUTF16($sBAMPath)
Local $sStartArguments = _TraceProcMonStartArguments( _
		'C:\Trace Folder\Application_Trace.pml', _
		'C:\Trace Folder\Application_Trace_Filter.pmc')
Local $sExportArguments = _TraceProcMonExportArguments( _
		'C:\Trace Folder\Application_Trace.pml', _
		'C:\Trace Folder\Application_Trace.xml', _
		'C:\Trace Folder\Application_Trace_Filter.pmc')
_T48BResult($sLog, 'Automatic ProcMon write filter is generated loaded and applied without INI changes', _
		$bPMCWritten And $iPMCRules = 20 And FileGetSize($sPMC) >= 1024 And _
		StringInStr($sPMCHex, _TracePMCHexUTF16('DestructiveFilter'), 1) > 0 And _
		StringInStr($sPMCHex, $sCategoryWrite, 1) > 0 And _
		StringInStr($sPMCHex, $sCategoryWriteMetadata, 1) > 0 And _
		StringInStr($sPMCHex, $sCategoryProcess, 1) > 0 And _
		StringInStr($sPMCHex, $sRegMetadataExclude, 1) > 0 And _
		StringInStr($sPMCHex, $sBAMExclude, 1) > 0 And _
		StringInStr($sPMCHex, _TracePMCHexUTF16($Root), 1) = 0 And _
		$sStartArguments == '/Quiet /Minimized /LoadConfig "C:\Trace Folder\Application_Trace_Filter.pmc" /BackingFile "C:\Trace Folder\Application_Trace.pml"' And _
		$sExportArguments == '/NoConnect /Quiet /OpenLog "C:\Trace Folder\Application_Trace.pml" /LoadConfig "C:\Trace Folder\Application_Trace_Filter.pmc" /SaveApplyFilter /SaveAs "C:\Trace Folder\Application_Trace.xml"', _
		$bAllPass)

Local $aFastFields[1]
Local $bFastCSV = _TraceCSVParseLine( _
		'"Payload.exe","1000","WriteFile","C:\Fixture\A,B\say ""Hello"".txt","SUCCESS","Offset: 0, Length: 5"', _
		$aFastFields)
_T48BResult($sLog, 'Fast canonical CSV parser retains commas and escaped quotes', _
		$bFastCSV And UBound($aFastFields) = 6 And _
		$aFastFields[3] = 'C:\Fixture\A,B\say "Hello".txt' And _
		$aFastFields[5] = 'Offset: 0, Length: 5', $bAllPass)

Local $aIndexedRecords[128][10], $iIndexedCount = 0
Local $oIndexedRecords = ObjCreate('Scripting.Dictionary')
Local $hIndexedTimer = TimerInit(), $j
For $j = 0 To 4999
	_TraceRecordAddIndexed($aIndexedRecords, $iIndexedCount, $oIndexedRecords, _
			'APPLICATION', 'FILE', $sExternal & '\Indexed_' & Mod($j, 200) & '.tmp', _
			'UNMANAGED', 'WriteFile', 'Payload.exe', 'performance fixture')
Next
Local $nIndexedMilliseconds = TimerDiff($hIndexedTimer)
Local $iIndexedEvents = 0
For $j = 0 To $iIndexedCount - 1
	$iIndexedEvents += Number($aIndexedRecords[$j][6])
Next
_T48BResult($sLog, 'Indexed repeated-target collapse avoids linear report growth', _
		IsObj($oIndexedRecords) And $iIndexedCount = 200 And _
		$iIndexedEvents = 5000 And $nIndexedMilliseconds < 10000, $bAllPass)

Local $aDirectRoots = _TraceRegFileGetRoots($sRegFile)
_T48BResult($sLog, 'Direct REG parser extracts the portable top-level registry root', _
		$aDirectRoots[0] = 1 And _
		StringUpper($aDirectRoots[1]) = _
		'HKEY_CURRENT_USER\SOFTWARE\XLAUNCHERSTAGE8\MANAGED', $bAllPass)
_T48BResult($sLog, 'Readable portability report is created from exported Process Monitor CSV', _
		$bBuilt And $iBuildError = 0 And FileExists($sReport), $bAllPass)
_T48BResult($sLog, 'Repeated low-level file events collapse into unique target counts', _
		StringInStr($sText, 'UNMANAGED application write targets=2', 1) > 0 And _
		StringInStr($sText, 'MANAGED application write targets=2', 1) > 0 And _
		StringInStr($sText, 'CONTAINED application write targets=2', 1) > 0 And _
		StringInStr($sText, 'X-LAUNCHER action targets=1', 1) > 0, $bAllPass)
_T48BResult($sLog, 'Application child PID activity is attributed and unrelated PID activity is excluded', _
		StringInStr($sText, 'Child.exe', 1) > 0 And _
		StringInStr($sText, 'Command line= Child.exe', 1) > 0 And _
		StringInStr($sText, $sChildFile, 1) > 0 And _
		StringInStr($sText, $sIgnoredFile, 1) = 0, $bAllPass)
_T48BResult($sLog, 'Current INI file and registry rules classify external targets as managed', _
		StringInStr($sText, '[RunAfter] FileMove source', 1) > 0 And _
		StringInStr($sText, '[RunBefore] Regedit=', 1) > 0 And _
		StringInStr($sText, 'HKCU\SOFTWARE\XLAUNCHERSTAGE8\MANAGED', 1) > 0, $bAllPass)
_T48BResult($sLog, 'Unmanaged file and registry writes remain visible for user review', _
		StringInStr($sText, $sUnmanagedFile, 1) > 0 And _
		StringInStr($sText, 'HKCU\Software\XLauncherStage8\Unmanaged\Setting', 1) > 0 And _
		StringInStr($sText, 'add an appropriate INI rule', 1) > 0, $bAllPass)
_T48BResult($sLog, 'Portability report uses equals separators for readable key-value fields', _
		StringInStr($sText, 'Actor= APPLICATION', 1) > 0 And _
		StringInStr($sText, 'PID= 1001', 1) > 0 And _
		StringInStr($sText, 'Parent PID= 1000', 1) > 0 And _
		StringInStr($sText, 'Process= Child.exe', 1) > 0 And _
		StringInStr($sText, 'Command line= Child.exe', 1) > 0 And _
		StringInStr($sText, 'Path= ' & $sChildFile, 1) > 0 And _
		StringInStr($sText, 'INI coverage= Inside the configured Root', 1) > 0 And _
		StringInStr($sText, 'Actor: ', 1) = 0 And _
		StringInStr($sText, 'Command line: ', 1) = 0, $bAllPass)
_T48BResult($sLog, 'Relevant failures state limitations residue and privacy are explicit', _
		StringInStr($sText, 'Relevant failed operations=1', 1) > 0 And _
		StringInStr($sText, 'ACCESS DENIED', 1) > 0 And _
		StringInStr($sText, 'PRESENT AFTER EXIT', 1) > 0 And _
		StringInStr($sText, 'LIMITATIONS', 1) > 0 And _
		StringInStr($sText, 'Privacy=', 1) > 0, $bAllPass)

If $bAllPass Then Exit 0
Exit 1

Func _T48BCSV($hFile, $sTime, $sProcess, $iPID, $sOperation, $sPath, $sResult, $sDetail)
	FileWriteLine($hFile, _T48BQuote($sTime) & ',' & _T48BQuote($sProcess) & ',' & _
			_T48BQuote($iPID) & ',' & _T48BQuote($sOperation) & ',' & _
			_T48BQuote($sPath) & ',' & _T48BQuote($sResult) & ',' & _T48BQuote($sDetail))
EndFunc

Func _T48BQuote($sValue)
	Return '"' & StringReplace($sValue, '"', '""') & '"'
EndFunc

Func _T48BResult($sFile, $sName, $bPass, ByRef $bAllPass)
	Local $hFile = FileOpen($sFile, 1)
	If $hFile <> -1 Then
		If $bPass Then
			FileWriteLine($hFile, $sName & '=PASS')
		Else
			FileWriteLine($hFile, $sName & '=FAIL')
		EndIf
		FileClose($hFile)
	EndIf
	If Not $bPass Then $bAllPass = False
EndFunc
