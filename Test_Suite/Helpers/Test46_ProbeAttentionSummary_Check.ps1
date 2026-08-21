param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath
)

$lines = @(Get-Content -LiteralPath $ReportPath)
$heading = 'FINDINGS REQUIRING ATTENTION'
$headingIndex = -1

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -ceq $heading) {
        $headingIndex = $index
    }
}

if ($headingIndex -lt 0) {
    exit 1
}

if (($headingIndex + 1) -ge $lines.Count -or
        $lines[$headingIndex + 1] -cne '------------------------------') {
    exit 1
}

$orderedDetails = @()
for ($index = 0; $index -lt $headingIndex; $index++) {
    if ($lines[$index] -match '^\[(FAIL|WARN)\] ') {
        $orderedDetails += $lines[$index]
    }
}

$summaryDetails = @()
for ($index = $headingIndex + 2; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -eq '') {
        continue
    }
    if ($lines[$index] -notmatch '^\[(FAIL|WARN)\] ') {
        exit 1
    }
    $summaryDetails += $lines[$index]
}

if ($orderedDetails.Count -eq 0 -or
        $orderedDetails.Count -ne $summaryDetails.Count) {
    exit 1
}

for ($index = 0; $index -lt $orderedDetails.Count; $index++) {
    if ($orderedDetails[$index] -cne $summaryDetails[$index]) {
        exit 1
    }
}

exit 0
