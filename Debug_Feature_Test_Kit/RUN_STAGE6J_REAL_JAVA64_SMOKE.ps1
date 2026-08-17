Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ExpectedPassCount = 23
$JavaRoot = 'D:\SyMenu\ProgramFiles\PA.c\PortableApps\CommonFiles\Java64'
$JavaExe = Join-Path $JavaRoot 'bin\java.exe'
$JavawExe = Join-Path $JavaRoot 'bin\javaw.exe'
$KitRoot = $PSScriptRoot
$ProjectRoot = Split-Path -Parent $KitRoot
$SourceExe = Join-Path $ProjectRoot 'X-Launcher_x64.exe'
$TestRoot = Join-Path $KitRoot 'Stage6J_Real_Java64_Smoke'
$LauncherRoot = Join-Path $TestRoot 'Launcher'
$RuntimeRoot = Join-Path $LauncherRoot 'RuntimeRoot'
$TestExe = Join-Path $LauncherRoot 'X-Launcher_x64.exe'
$RootIni = Join-Path $TestRoot 'Stage6J_Java64_Root.ini'
$ExeIni = Join-Path $TestRoot 'Stage6J_Java64_Executable.ini'
$RootDebug = Join-Path $LauncherRoot 'Stage6J_Java64_Root.dbg'
$ExeDebug = Join-Path $LauncherRoot 'Stage6J_Java64_Executable.dbg'
$ManifestHelper = Join-Path $KitRoot 'Capture_Java_Runtime_Manifest.ps1'
$ManifestBefore = Join-Path $TestRoot 'Java64_Before.manifest'
$ManifestAfter = Join-Path $TestRoot 'Java64_After.manifest'
$RootIniBefore = Join-Path $TestRoot 'Stage6J_Java64_Root.before.ini'
$ExeIniBefore = Join-Path $TestRoot 'Stage6J_Java64_Executable.before.ini'
$ResultsPath = Join-Path $KitRoot 'Stage6J_Real_Java64_Smoke_Results.txt'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ResultLines = New-Object System.Collections.Generic.List[string]
$PassCount = 0
$FailCount = 0
$ExitCode = 1

function Add-Result {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Passed) {
        $script:PassCount++
        $line = '[PASS] ' + $Message
    }
    else {
        $script:FailCount++
        $line = '[FAIL] ' + $Message
    }

    [void]$script:ResultLines.Add($line)
    Write-Host $line
}

function Assert-Prerequisite {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Add-Result -Passed $Passed -Message $Message
    if (-not $Passed) {
        throw $Message
    }
}

function Write-SmokeIni {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ConfiguredJavaPath
    )

    $lines = [string[]]@(
        '[Setup]',
        'AppName=Stage6JRealJava64Smoke',
        'AppVer=ReadOnlyAcceptance',
        'Lang=en',
        '',
        '[FileSystem]',
        'Root=.\RuntimeRoot',
        'Temp=.\Temp',
        'Lib=.\Lib',
        'Download=.\Downloads',
        '',
        '[FileToRun]',
        'PathToExe=$Java$\bin\java.exe',
        'Parameters=-version',
        'WorkingDir=$Java$\bin',
        '',
        '[Options]',
        'DeleteTemp=true',
        'MultipleInstances=true',
        'FixAppData=false',
        'RunWait=true',
        'ShowSplash=false',
        'ShowTrayTip=false',
        'WriteLog=false',
        'HideShellWindow=true',
        'RegView=Native',
        'FirstRun=false',
        'Java=true',
        ('JavaPath=' + $ConfiguredJavaPath),
        'JavaURL=https://example.invalid/must-not-download.zip',
        'Debug=true',
        'TestRun=false'
    )

    [System.IO.File]::WriteAllLines($Path, $lines, $script:Utf8NoBom)
}

function Test-ContainsText {
    param(
        [string]$Text,
        [string]$Expected
    )

    return $Text.IndexOf($Expected, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Test-OneJavaPathForm {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$IniPath,

        [Parameter(Mandatory = $true)]
        [string]$DebugPath
    )

    # X-Launcher is compiled as a Windows GUI-subsystem executable. Windows
    # PowerShell does not reliably populate $LASTEXITCODE for that executable
    # type, so wait on an explicit process object and read its ExitCode.
    $launcherArgument = '"--x-launcher-config={0}"' -f $IniPath.Replace('"', '\"')
    $launcherProcess = Start-Process -FilePath $script:TestExe `
        -ArgumentList $launcherArgument -Wait -PassThru
    $launcherExitCode = $launcherProcess.ExitCode
    Add-Result -Passed ($launcherExitCode -eq 0) -Message ($Label + ' JavaPath launcher exit code was 0')

    $debugExists = Test-Path -LiteralPath $DebugPath -PathType Leaf
    Add-Result -Passed $debugExists -Message ($Label + ' JavaPath debug log was created')

    $debugText = ''
    if ($debugExists) {
        $debugText = [System.IO.File]::ReadAllText($DebugPath)
    }

    Add-Result -Passed (Test-ContainsText $debugText 'source=configured; access=read-only') `
        -Message ($Label + ' JavaPath was normalized and accepted read-only')
    Add-Result -Passed (Test-ContainsText $debugText 'mode=true; source=configured') `
        -Message ($Label + ' Java selection reported configured priority')
    Add-Result -Passed (Test-ContainsText $debugText 'mode=RunWait; exitcode=0; error=0') `
        -Message ($Label + ' JavaPath launched java.exe successfully')
    Add-Result -Passed (-not (Test-ContainsText $debugText '[Java] JavaGet=')) `
        -Message ($Label + ' JavaPath bypassed JavaGet')
    Add-Result -Passed (Test-ContainsText $debugText '; fail=0; warn=0;') `
        -Message ($Label + ' debug session contained no failures or warnings')
}

Write-Host '============================================================'
Write-Host 'X-LAUNCHER STAGE 6J - REAL JAVA64 SMOKE TEST (CORRECTED)'
Write-Host '============================================================'
Write-Host ''
Write-Host 'Installed runtime under test:'
Write-Host $JavaRoot
Write-Host ''
Write-Host 'This test reads that runtime and launches java.exe -version twice.'
Write-Host 'It does not alter a real application INI and does not download Java.'
Write-Host 'Creating complete before and after manifests can take a little while.'
Write-Host ''

try {
    $resolvedKitRoot = [System.IO.Path]::GetFullPath($KitRoot).TrimEnd('\')
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($TestRoot)
    if (-not $resolvedTestRoot.StartsWith($resolvedKitRoot + '\',
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The isolated test-folder boundary check failed.'
    }

    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $LauncherRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null

    Assert-Prerequisite -Passed (Test-Path -LiteralPath $SourceExe -PathType Leaf) `
        -Message 'Built X-Launcher_x64.exe was found'
    Assert-Prerequisite -Passed (Test-Path -LiteralPath $JavaExe -PathType Leaf) `
        -Message 'Installed Java64 java.exe was found'
    Assert-Prerequisite -Passed (Test-Path -LiteralPath $JavawExe -PathType Leaf) `
        -Message 'Installed Java64 javaw.exe was found'
    if (-not (Test-Path -LiteralPath $ManifestHelper -PathType Leaf)) {
        throw 'Java runtime manifest helper was not found.'
    }

    Copy-Item -LiteralPath $SourceExe -Destination $TestExe -Force
    Assert-Prerequisite -Passed (Test-Path -LiteralPath $TestExe -PathType Leaf) `
        -Message 'Launcher was copied into the isolated smoke-test folder'

    Write-Host 'Capturing the complete Java64 before-manifest...'
    & $ManifestHelper -Root $JavaRoot -Output $ManifestBefore
    Assert-Prerequisite -Passed (Test-Path -LiteralPath $ManifestBefore -PathType Leaf) `
        -Message 'Complete Java64 before-manifest was created'

    Write-SmokeIni -Path $RootIni -ConfiguredJavaPath $JavaRoot
    Write-SmokeIni -Path $ExeIni -ConfiguredJavaPath $JavawExe
    Copy-Item -LiteralPath $RootIni -Destination $RootIniBefore -Force
    Copy-Item -LiteralPath $ExeIni -Destination $ExeIniBefore -Force

    Write-Host ''
    Write-Host 'Running JavaPath as the Java64 runtime root...'
    Test-OneJavaPathForm -Label 'Runtime-root' -IniPath $RootIni -DebugPath $RootDebug

    Write-Host 'Running JavaPath as the full javaw.exe path...'
    Test-OneJavaPathForm -Label 'Executable-form' -IniPath $ExeIni -DebugPath $ExeDebug

    $rootIniSame = (Get-FileHash -LiteralPath $RootIniBefore -Algorithm SHA256).Hash -eq `
        (Get-FileHash -LiteralPath $RootIni -Algorithm SHA256).Hash
    $exeIniSame = (Get-FileHash -LiteralPath $ExeIniBefore -Algorithm SHA256).Hash -eq `
        (Get-FileHash -LiteralPath $ExeIni -Algorithm SHA256).Hash
    Add-Result -Passed ($rootIniSame -and $exeIniSame) `
        -Message 'Both JavaPath configuration files remained byte-identical'

    $fallbackClean = -not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'Lib\Java')) -and `
        -not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'Downloads'))
    Add-Result -Passed $fallbackClean `
        -Message 'No bundled Java or JavaURL download fallback was created'

    Write-Host ''
    Write-Host 'Capturing the complete Java64 after-manifest...'
    & $ManifestHelper -Root $JavaRoot -Output $ManifestAfter
    Assert-Prerequisite -Passed (Test-Path -LiteralPath $ManifestAfter -PathType Leaf) `
        -Message 'Complete Java64 after-manifest was created'

    $runtimeUnchanged = (Get-FileHash -LiteralPath $ManifestBefore -Algorithm SHA256).Hash -eq `
        (Get-FileHash -LiteralPath $ManifestAfter -Algorithm SHA256).Hash
    Add-Result -Passed $runtimeUnchanged `
        -Message 'Installed Java64 tree remained byte-for-byte and metadata identical'
}
catch {
    Add-Result -Passed $false -Message ('Runner stopped: ' + $_.Exception.Message)
}
finally {
    $overallPass = $PassCount -eq $ExpectedPassCount -and $FailCount -eq 0
    if ($overallPass) {
        $overall = 'PASS'
        $ExitCode = 0
    }
    else {
        $overall = 'FAIL'
        $ExitCode = 1
    }

    $output = New-Object System.Collections.Generic.List[string]
    [void]$output.Add('X-LAUNCHER STAGE 6J REAL JAVA64 SMOKE RESULTS - CORRECTED')
    [void]$output.Add('=============================================================')
    [void]$output.Add('')
    [void]$output.Add('Java root: ' + $JavaRoot)
    [void]$output.Add('Required pass count: ' + $ExpectedPassCount)
    [void]$output.Add('')
    foreach ($line in $ResultLines) {
        [void]$output.Add($line)
    }
    [void]$output.Add('')
    [void]$output.Add('Passed: ' + $PassCount)
    [void]$output.Add('Failed: ' + $FailCount)
    [void]$output.Add('Overall: ' + $overall)
    [System.IO.File]::WriteAllLines($ResultsPath, $output, $Utf8NoBom)

    Write-Host ''
    Write-Host '------------------------------------------------------------'
    Write-Host ('Passed: ' + $PassCount)
    Write-Host ('Failed: ' + $FailCount)
    Write-Host ('Overall: ' + $overall)
    Write-Host '------------------------------------------------------------'
    Write-Host ''
    Write-Host 'Results were written to:'
    Write-Host $ResultsPath
}

exit $ExitCode
