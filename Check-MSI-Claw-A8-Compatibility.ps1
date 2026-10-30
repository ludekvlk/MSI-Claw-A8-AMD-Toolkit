#requires -Version 5.1
# Hardware/OS check only. Does not install, elevate, change settings or reboot.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'Internal\Profile-Resolver.ps1')
    $Profiles = @(Get-LegionGoProfiles -ProfileRoot (Join-Path $PSScriptRoot 'Internal\Profiles'))
    $Devices = @(Get-CimInstance -ClassName Win32_PnPEntity -Filter "PNPClass='Display'" -ErrorAction Stop |
        Where-Object { $_.Present -eq $true -and [string]$_.PNPDeviceID -like 'PCI\*' })
    $Ids = @($Devices | ForEach-Object { $_.HardwareID } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $Profile = Resolve-LegionGoProfile -Profiles $Profiles -InstanceIds $Ids
    if ($Profile.Id -cne 'MsiClawA8-Z2Extreme') {
        throw 'This check is for MSI Claw A8 Z2 Extreme. A different profile was detected.'
    }
    $Os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    if (-not [Environment]::Is64BitOperatingSystem -or [int]$Os.BuildNumber -lt 22000 -or [int]$Os.ProductType -ne 1) {
        throw 'Use Windows 11 x64. Other Windows versions are outside this MSI release scope.'
    }
    Write-Host '[PASS] Exact MSI Claw A8 Z2 Extreme hardware ID found.' -ForegroundColor Green
    Write-Host $Profile.Hardware.ExactHardwareId
    Write-Host ("Windows: {0}, build {1}" -f $Os.Caption,$Os.BuildNumber)
    Write-Host ''
    Write-Host 'This confirms the hardware/OS match only. It does not prove installation readiness.'
    Write-Host 'Read README.md for Secure Boot, encryption, AMD download and reboot requirements.'
    Write-Host 'The installer performs additional checks. No driver or setting was changed.'
    exit 0
} catch {
    Write-Host ('[STOP] ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check the graphics hardware ID in Device Manager as described in README.md.'
    Write-Host 'Do not edit the hardware profile to force a match. No driver or setting was changed.'
    exit 1
}
