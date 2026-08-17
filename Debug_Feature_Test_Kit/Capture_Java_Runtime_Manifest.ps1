param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$rootItem = Get-Item -LiteralPath $Root -Force
if (-not $rootItem.PSIsContainer) {
    throw "Java runtime root is not a directory: $Root"
}

$rootPath = $rootItem.FullName.TrimEnd('\')
$prefix = $rootPath + '\'
$records = New-Object System.Collections.Generic.List[string]
[void]$records.Add(('R|{0}' -f $rootItem.LastWriteTimeUtc.Ticks))

Get-ChildItem -LiteralPath $rootPath -Force -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($prefix.Length)
        if ($_.PSIsContainer) {
            [void]$records.Add(('D|{0}|{1}' -f $relativePath, $_.LastWriteTimeUtc.Ticks))
        }
        else {
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            [void]$records.Add(('F|{0}|{1}|{2}|{3}' -f $relativePath, $_.Length,
                    $_.LastWriteTimeUtc.Ticks, $hash))
        }
    }

if ($records.Count -lt 3) {
    throw "Java runtime manifest is unexpectedly small: $Root"
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($Output, $records, $encoding)
