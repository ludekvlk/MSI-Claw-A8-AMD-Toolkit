#requires -Version 5.1
# Read-only fixtures. Does not call bcdedit or change boot settings.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$Count = 0
foreach ($Name in @('testsigning','nointegritychecks')) {
    foreach ($Value in @('Yes','ON','true','1','No','OFF','false','0')) {
        $Expected = $Value -match '^(?i:yes|on|true|1)$'
        $Actual = ConvertFrom-BcdBooleanOutput -Output ("Windows Boot Loader`r`n$Name    $Value`r`n") -Name $Name
        if ($Actual -ne $Expected) { throw "Incorrect BCD boolean: $Name=$Value" }
        $Count++
    }
    if (ConvertFrom-BcdBooleanOutput -Output "Windows Boot Loader`r`n" -Name $Name) { throw 'Absent option must be off.' }
    $Count++
    foreach ($Output in @("$Name    Ano", "$Name    Oui", "$Name    unexpected", "$Name    Yes`r`n$Name    No", "$Name    ", $Name)) {
        $Blocked = $false
        try { [void](ConvertFrom-BcdBooleanOutput -Output $Output -Name $Name) } catch { $Blocked = $true }
        if (-not $Blocked) { throw "Unsafe BCD output accepted: $Output" }
        $Count++
    }
}
Write-Output "[PASS] BCD boolean parsing: $Count fixtures; unknown/localized values and duplicate rows fail closed."
