#requires -Version 5.1
# Read-only regression tests; no driver binding or boot changes.
[CmdletBinding()]
param([switch]$LiveInventory)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

$RealQuery = ${function:Invoke-DriverInventoryQuery}
$script:QueryCalls = 0
$script:Mode = 'Recover'
function Invoke-DriverInventoryQuery {
    param([switch]$IncludeInbox)
    $script:QueryCalls++
    if ($script:Mode -eq 'Recover' -and $script:QueryCalls -eq 2) {
        return [pscustomobject]@{Success=$true;Rows=@([pscustomobject]@{Driver='oem1.inf'});Retryable=$false;Detail=''}
    }
    return [pscustomobject]@{Success=$false;Rows=@([pscustomobject]@{Driver='partial.inf'});Retryable=($script:Mode -ne 'AccessDenied');Detail='fixture failure'}
}
function Start-Sleep { param($Seconds) }
$Rows = @(Get-DriverStoreInventory)
if ($script:QueryCalls -ne 2 -or $Rows.Count -ne 1 -or $Rows[0].Driver -ne 'oem1.inf') { throw 'Transient failure recovery leaked partial results or failed to retry.' }
$script:Mode='Persistent'; $script:QueryCalls=0; $Blocked=$false
try { $null=Get-DriverStoreInventory } catch { $Blocked=$true }
if (-not $Blocked -or $script:QueryCalls -ne 3) { throw 'Persistent inventory failure did not stop after three attempts.' }
$script:Mode='AccessDenied'; $script:QueryCalls=0; $Blocked=$false
try { $null=Get-DriverStoreInventory } catch { $Blocked=$true }
if (-not $Blocked -or $script:QueryCalls -ne 1) { throw 'Nontransient inventory failure was retried or ignored.' }
Set-Item Function:\Invoke-DriverInventoryQuery -Value $RealQuery
Remove-Item Function:\Start-Sleep
Write-Output '[PASS] Inventory retries are bounded; partial results are discarded; access errors stop immediately.'

# This lookup must never enumerate unrelated packages.
function Get-WindowsDriver { throw 'Exact lookup must not call DISM enumeration.' }
$Gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -like 'PCI\VEN_1002*' } | Select-Object -First 1
if ($null -eq $Gpu) { throw 'No AMD GPU available for read-only lookup validation.' }
$Published = [string](Get-PnpDeviceProperty -InstanceId $Gpu.PNPDeviceID -KeyName DEVPKEY_Device_DriverInfPath).Data
$Catalog = Resolve-DriverStoreCatalogForPublishedInf -PublishedInf $Published
if (-not (Test-Path -LiteralPath $Catalog.CatalogPath)) { throw 'Active catalog lookup failed.' }
foreach ($Invalid in @('..\oem1.inf','C:\Windows\INF\oem1.inf','missing-driver-query-fixture.inf')) {
    $Blocked=$false
    try { $null=Resolve-DriverStoreInfForPublishedInf -PublishedInf $Invalid } catch { $Blocked=$true }
    if (-not $Blocked) { throw "Invalid or missing published INF accepted: $Invalid" }
}
Write-Output "[PASS] Live exact INF/catalog lookup and hash identity: $Published; invalid and missing names rejected."
Remove-Item Function:\Get-WindowsDriver

if ($LiveInventory) {
    $Rows = @(Get-DriverStoreInventory)
    if (@($Rows | Where-Object { $_.Driver -ieq $Published }).Count -ne 1) { throw 'Live inventory is missing the current GPU package.' }
    $Amd = @(Get-AmdDisplayDrivers)
    if ($Amd.Count -lt 1) { throw 'Live AMD display inventory is empty.' }
    Write-Output "[PASS] Fresh-process DISM inventory: $($Rows.Count) third-party packages; $($Amd.Count) AMD display packages."
}
