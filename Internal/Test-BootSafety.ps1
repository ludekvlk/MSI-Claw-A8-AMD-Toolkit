#requires -Version 5.1
# Read-only unit tests: all encryption queries are replaced with fixtures.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$script:VolumeQueryFails=$false
$script:Volumes=@([pscustomobject]@{DriveLetter=$env:SystemDrive})
$script:ProtectionResult=[pscustomobject]@{ReturnValue=0;ProtectionStatus=0}
function Get-CimInstance {
    [CmdletBinding()]param($Namespace,$ClassName,$Filter)
    if($script:VolumeQueryFails){throw 'Access denied fixture'}
    return $script:Volumes
}
function Invoke-CimMethod {
    [CmdletBinding()]param($InputObject,$MethodName)
    if($MethodName -cne 'GetProtectionStatus'){throw 'Unexpected method'}
    return $script:ProtectionResult
}
function Expect-Blocked([string]$Name) {
    $Blocked=$false
    try{Assert-BitLockerBootChangeReady}catch{$Blocked=$true}
    if(-not $Blocked){throw "Unsafe boot change allowed: $Name"}
}
Assert-BitLockerBootChangeReady
foreach($Status in @(1,2,-1)) {
    $script:ProtectionResult=[pscustomobject]@{ReturnValue=0;ProtectionStatus=$Status}
    Expect-Blocked "ProtectionStatus=$Status"
}
$script:ProtectionResult=[pscustomobject]@{ReturnValue=1;ProtectionStatus=0}
Expect-Blocked 'Failed method result'
$script:ProtectionResult=[pscustomobject]@{ReturnValue=0;ProtectionStatus=$null}
Expect-Blocked 'Missing protection status'
$script:ProtectionResult=[pscustomobject]@{ReturnValue=0;ProtectionStatus=0}
$script:Volumes=@()
Expect-Blocked 'Missing system volume'
$script:VolumeQueryFails=$true
Expect-Blocked 'Access denied'
$root=Split-Path -Parent $PSScriptRoot
$stage1=Get-Content (Join-Path $root '01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1') -Raw
$stage2=Get-Content (Join-Path $root '02-Install-Driver-And-Verify-Normal-Signing.ps1') -Raw
$launcher=Get-Content (Join-Path $root 'Install-LegionGo-AMD-26.10.1.ps1') -Raw
if($launcher -notmatch '(?s)if \(\$TestSigningBefore -or \$NoIntegrityBefore\) \{\s+Assert-BitLockerBootChangeReady'){throw 'Failure recovery bypasses boot safety check'}
if($stage1.IndexOf('Assert-BitLockerBootChangeReady') -gt $stage1.IndexOf('& bcdedit.exe /set testsigning on')){throw 'Stage 1 check too late'}
if($stage2 -notmatch '(?s)Assert-BitLockerBootChangeReady\s+Set-StateProperty \$State ''TransactionStatus'' ''DriverTransactionInProgress'''){throw 'Stage 2 missing pre-transaction check'}
if($stage2 -notmatch 'Assert-BitLockerBootChangeReady\s+& bcdedit.exe /set testsigning off'){throw 'Stage 2 missing pre-boot-change check'}
Write-Output '[PASS] Boot safety: protection-off accepted; active/unknown protection, query failures, and missing volume rejected; checks precede mutation.'
