#requires -Version 5.1
# Read-only checks. No numbered installer stage is executed.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$Profiles = @(Get-LegionGoProfiles -ProfileRoot (Join-Path $PSScriptRoot 'Profiles'))
$Exact = 'PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C5'
$Profile = Get-SelectedHardwareProfile -HardwareIds @($Exact)
if ($Profile.Id -cne 'MsiClawA8-Z2Extreme') { throw 'Wrong selected profile' }
[void](Set-LegionGoProfileRuntimeContext -Profile $Profile -ReleaseContract (Get-LegionGoReleaseContract))
foreach ($Ids in @(
    @('PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C4'),
    @('PCI\VEN_1002&DEV_150E&SUBSYS_00001462&REV_C5'),
    @('PCI\VEN_1002&DEV_150E'),
    @($Exact,'PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5')
)) {
    $Rejected=$false
    try { [void](Resolve-LegionGoProfile -Profiles $Profiles -InstanceIds $Ids) } catch { $Rejected=$true }
    if (-not $Rejected) { throw "Non-exact or ambiguous hardware accepted: $Ids" }
}
if (@($Profile.Lenovo.OemSectionOrder).Count -ne 0 -or @($Profile.Lenovo.RequiredSemanticMarkers).Count -ne 0) { throw 'MSI inherited Lenovo overrides' }
# These stubs ensure the MSI branch cannot query or remove Lenovo extensions.
function Get-Amduw23eDrivers { throw 'MSI must not enter Lenovo extension cleanup' }
function Get-AmdCnMetadataSafe { throw 'MSI must not require Lenovo provenance' }
if (@(Get-LenovoExtensionDrivers).Count -ne 0) { throw 'MSI extension cleanup must be empty' }
if (@(Get-Amduw23ePhysicalRepositoryInventory -RepositoryRoot 'Z:\nonexistent-test-path').Count -ne 0) { throw 'Lenovo repository audit must not apply to MSI' }
$Gpu=[pscustomobject]@{Status='OK';ProblemCode=0;HasProblem=$false;DriverProvider='Advanced Micro Devices, Inc.';Service='amduw23g';ActiveINF='oem1.inf';DriverVersion='32.0.23033.5002'}
if (-not (Get-TargetOriginClassification -Gpu $Gpu).OriginAcceptable) { throw 'Healthy MSI AMD origin rejected' }
$Gpu.ProblemCode=43;$Gpu.HasProblem=$true
if ((Get-TargetOriginClassification -Gpu $Gpu).OriginAcceptable) { throw 'Unhealthy GPU accepted' }
$Gpu.ProblemCode=0;$Gpu.HasProblem=$false;$Gpu.DriverProvider='Microsoft';$Gpu.Service='BasicDisplay';$Gpu.ActiveINF='display.inf'
if (-not (Get-TargetOriginClassification -Gpu $Gpu).OriginAcceptable) { throw 'Basic Display recovery origin rejected' }
Write-Output '[PASS] MSI exact selection, wrong revision/subsystem rejection, ambiguity rejection, AMD/Basic Display origins, Code 43 rejection, and no Lenovo cleanup.'
