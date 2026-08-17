Local $sLog = @ScriptDir & '\Arguments.log'

FileDelete($sLog)

Local $hLog = FileOpen($sLog, 2)
If $hLog = -1 Then Exit 2

FileWriteLine($hLog, 'ARG_COUNT=' & $CmdLine[0])
For $i = 1 To $CmdLine[0]
	FileWriteLine($hLog, 'ARG_' & $i & '=' & $CmdLine[$i])
Next

FileClose($hLog)
Exit 0
