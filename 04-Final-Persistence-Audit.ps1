#requires -Version 5.1
#requires -RunAsAdministrator
<##
Read-only final persistence audit for AMD 26.9.2 Public Beta v5.0.
It does not install/remove drivers, change certificates, write registry values,
change BCD, install MSI/AppX packages, or alter workflow state. It writes
an evidence report under the current user's Downloads folder and an
invocation-specific pass/fail result contract under the workflow root.
##>
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Internal\Common.ps1')
$SelectedProfile = Initialize-LegionGoProfileContext
$Version = 'Public-Beta-v5.0'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$EvidenceRoot = Join-Path "$env:USERPROFILE\Downloads" ('LegionGo-AMD-26.9.2-Public-Beta-v5.0-Final-Audit-' + $Timestamp)
$StageResultPath = Join-Path $Script:WorkflowRoot 'stage4-result.json'
$InvocationId = [string]$env:LEGIONGO_STAGE_INVOCATION_ID
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$Checks = @()
$Warnings = @()
function Write-Stage4Result {
    param([Parameter(Mandatory=$true)][string]$Status,[Parameter(Mandatory=$true)][int]$ExitCode,[Parameter(Mandatory=$true)][int]$FailedChecks,[Parameter(Mandatory=$true)][string]$EvidencePath)
    $Result = [ordered]@{
        Schema = 'LegionGo-AMD-26.9.2-Public-Beta-v5.0-Stage4Result'
        Release = $Version
        InvocationId = $InvocationId
        Status = $Status
        ExitCode = $ExitCode
        FailedChecks = $FailedChecks
        EvidencePath = $EvidencePath
        GeneratedAt = (Get-Date).ToString('o')
    }
    Write-JsonAtomic -InputObject $Result -LiteralPath $StageResultPath -Depth 10
}
$BaseAuditCheckCount=45
$LegacyGo1RegistryCheckCount=27
$ProfileRegistryCheckCount=$LegacyGo1RegistryCheckCount
if([string]$SelectedProfile.Id -ne 'LegionGo1'){
    $ProfileRegistryCheckCount=0
    foreach($SourceSectionName in $SelectedProfile.Lenovo.OemSectionOrder){
        $ProfileRegistryCheckCount += @($SelectedProfile.Lenovo.OemSections.$SourceSectionName).Count
    }
}
$ExpectedAuditCheckCount=$BaseAuditCheckCount+6+$ProfileRegistryCheckCount
function Add-Check([string]$Name,[bool]$Pass,[string]$Detail) {
    $script:Checks += [pscustomobject]@{Name=$Name;Pass=$Pass;Detail=$Detail}
    $CheckIndex=@($script:Checks).Count
    $AuditPercent=[int][Math]::Min(100,[Math]::Floor(($CheckIndex*100.0)/$ExpectedAuditCheckCount))
    $AuditStatus=if($Pass){'PASS'}else{'FAIL'}
    Write-ActivityProgress -Activity 'Final persistence audit' -Percent $AuditPercent -Status $AuditStatus -Detail ("Check {0}/{1} :: {2}" -f $CheckIndex,$ExpectedAuditCheckCount,$Name)
    if ($Pass) { Write-Host ("[PASS] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Green }
    else { Write-Host ("[FAIL] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Red }
}
function Add-Warning([string]$Name,[string]$Detail) {
    $script:Warnings += [pscustomobject]@{Name=$Name;Detail=$Detail}
    Write-Host ("[WARN] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Yellow
}
function Hex([byte[]]$Bytes) { if ($null -eq $Bytes) { return '' }; return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join ',') }
function Read-RegValue([string]$Path,[string]$Name) {
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}
function Test-Reg([string]$Path,[string]$Name,$Expected,[string]$Kind,[string]$CheckName='') {
    $Actual = Read-RegValue $Path $Name
    $Pass = $false; $A=''
    if ($Kind -eq 'Binary') { $A=Hex ([byte[]]$Actual); $Pass=($A -eq [string]$Expected) }
    elseif ($Kind -eq 'Dword') { if ($null -ne $Actual) { $A=[string][uint32]$Actual; $Pass=([uint32]$Actual -eq [uint32]$Expected) } }
    else { $A=[string]$Actual; $Pass=($A -ceq [string]$Expected) }
    $ResolvedCheckName=if([string]::IsNullOrWhiteSpace($CheckName)){('REG_' + $Name)}else{$CheckName}
    Add-Check -Name $ResolvedCheckName -Pass $Pass -Detail ("Path={0}; Expected={1}; Actual={2}" -f $Path,$Expected,$A)
}
function Product-Installed([string]$Code) { try { return ((Get-MsiProductState -ProductCode $Code) -eq 5) } catch { return $false } }

Write-Section 'LEGION GO AMD 26.9.2 Public Beta v5.0 - FINAL READ-ONLY AUDIT'
$State = Read-WorkflowState
if ($null -ne $State) { [void](Assert-WorkflowProfileIdentity -State $State -Profile $SelectedProfile -ReleaseContract $Script:ReleaseContract) }
Add-Check 'WORKFLOW_STATE_PRESENT' ($null -ne $State) $(if($null-ne$State){[string]$State.Stage}else{'missing'})
if ($null -eq $State) { throw 'Workflow state is required to bind the per-machine signer identity.' }
Add-Check 'WORKFLOW_RELEASE' ([string]$State.Release -eq $Version) ([string]$State.Release)
Add-Check 'WORKFLOW_SOFTWARE_STAGE' ([string]$State.Stage -in @('SoftwareComplete','Complete')) ([string]$State.Stage)
Add-Check 'PROFILE_ID' ([string]$State.SelectedProfileId -eq [string]$SelectedProfile.Id) ([string]$State.SelectedProfileId)
Add-Check 'PROFILE_EXACT_HWID_STATE' ([string]$State.SelectedExactHardwareId -eq [string]$SelectedProfile.Hardware.ExactHardwareId) ([string]$State.SelectedExactHardwareId)
Add-Check 'PROFILE_AMD_FAMILY' ([string]$State.SelectedAmdFamily -eq [string]$SelectedProfile.Amd.Family) ([string]$State.SelectedAmdFamily)
Add-Check 'PROFILE_BASE_DDINSTALL' ([string]$State.SelectedBaseInstallSection -eq [string]$SelectedProfile.Amd.BaseInstallSection) ([string]$State.SelectedBaseInstallSection)

Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 4 -Status 'QUERYING' -Detail 'discover live GPU, active INF, driver properties, and kernel identity'
$Gpu = Get-LegionGoGpu
Add-Check 'GPU_STATUS' ($Gpu.Status -eq 'OK' -and $Gpu.ProblemCode -eq 0 -and -not [bool]$Gpu.HasProblem) ("Status=$($Gpu.Status); ProblemCode=$($Gpu.ProblemCode); HasProblem=$($Gpu.HasProblem)")
Add-Check 'PROFILE_LIVE_EXACT_HWID' ([string]$Gpu.DeviceID -like ([string]$SelectedProfile.Hardware.ExactHardwareId+'*')) ([string]$Gpu.DeviceID)
$ActiveDdInstallPass=$false;$ActiveDdInstallDetail=''
try{Assert-CandidateInfSelectedProfileBinding -InfPath $Gpu.InfPath -Profile $SelectedProfile;$ActiveDdInstallPass=$true;$ActiveDdInstallDetail=[string]$SelectedProfile.Amd.DedicatedInstallSection}catch{$ActiveDdInstallDetail=$_.Exception.Message}
Add-Check 'PROFILE_ACTIVE_DDINSTALL' $ActiveDdInstallPass $ActiveDdInstallDetail
Add-Check 'DRIVER_VERSION' ($Gpu.DriverVersion -eq $Script:ExpectedDriverVersion) $Gpu.DriverVersion
Add-Check 'ACTIVE_INF_SHA256' ($Gpu.InfSHA256 -eq $Script:ExpectedFinalInfSHA256) $Gpu.InfSHA256
Add-Check 'KERNEL_SHA256' ($Gpu.KernelSHA256 -eq $Script:ExpectedKernelSHA256) $Gpu.KernelSHA256
$DriverStoreRoot = $null
$CatalogDisposition = ''
$ExpectedCatalogHash = ''
$ExpectedCatalogSigner = ''
Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 10 -Status 'RESOLVING' -Detail 'locate active Driver Store repository'
try { $DriverStoreRoot = Resolve-DriverStoreRootForPublishedInf -PublishedInf $Gpu.ActiveINF } catch { Add-Check 'DRIVERSTORE_ROOT' $false $_.Exception.Message }
if ($null -ne $DriverStoreRoot) {
    $Dat = Join-Path $DriverStoreRoot 'B026676\amdgcf.dat'
    $ResolvedFinalCatalog = $null
    try { $ResolvedFinalCatalog = Resolve-DriverStoreCatalogForPublishedInf -PublishedInf $Gpu.ActiveINF } catch { Add-Check 'ACTIVE_CATALOG_RESOLVE' $false $_.Exception.Message }
    $Cat = if ($null -ne $ResolvedFinalCatalog) { [string]$ResolvedFinalCatalog.CatalogPath } else { '' }
    $CatName = if ($null -ne $ResolvedFinalCatalog) { [string]$ResolvedFinalCatalog.CatalogName } else { '' }
    Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 12 -Status 'HASHING' -Detail 'active amdgcf.dat'
    $DatHash = ''; try { $DatHash=Get-SHA256 $Dat } catch {}
    Add-Check 'ACTIVE_DAT_SHA256' ($DatHash -eq $Script:ExpectedFinalDatSHA256) $DatHash
    Add-Check 'ACTIVE_CATALOG_NAME' ($CatName -ieq 'u0205306.cat') $CatName
    Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 14 -Status 'HASHING' -Detail ("active catalog: {0}" -f $CatName)
    $CatHash=''; if (-not [string]::IsNullOrWhiteSpace($Cat)) { try{$CatHash=Get-SHA256 $Cat}catch{} }
    $CatalogDisposition = if ($null -ne $State.PSObject.Properties['ActiveCatalogDisposition']) { [string]$State.ActiveCatalogDisposition } else { '' }
    $ExpectedCatalogHash = if ($null -ne $State.PSObject.Properties['ExpectedActiveCatalogSHA256']) { [string]$State.ExpectedActiveCatalogSHA256 } else { '' }
    $ExpectedCatalogSigner = if ($null -ne $State.PSObject.Properties['ExpectedActiveCatalogSignerThumbprint']) { [string]$State.ExpectedActiveCatalogSignerThumbprint } else { '' }
    Add-Check 'ACTIVE_CATALOG_DISPOSITION' ($CatalogDisposition -in @('Stage1Candidate','RetainedPreexistingExactFinal')) $CatalogDisposition
    Add-Check 'ACTIVE_CATALOG_EXPECTED_HASH' (-not [string]::IsNullOrWhiteSpace($ExpectedCatalogHash) -and $CatHash -eq $ExpectedCatalogHash) ("Disposition=$CatalogDisposition; Expected=$ExpectedCatalogHash; Actual=$CatHash")
    try {
        Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 18 -Status 'SIGNATURE' -Detail 'Windows Authenticode validation for active display catalog'
        $Sig=Get-AuthenticodeSignature -LiteralPath $Cat
        $ActualSigner = if($null-ne$Sig.SignerCertificate){[string]$Sig.SignerCertificate.Thumbprint}else{''}
        Add-Check 'CATALOG_SIGNATURE' ($Sig.Status -eq 'Valid' -and -not [string]::IsNullOrWhiteSpace($ExpectedCatalogSigner) -and $ActualSigner -eq $ExpectedCatalogSigner) ("Status=$($Sig.Status); Disposition=$CatalogDisposition; ExpectedSigner=$ExpectedCatalogSigner; ActualSigner=$ActualSigner")
    } catch { Add-Check 'CATALOG_SIGNATURE' $false $_.Exception.Message }
    try { Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 18 -Status 'TRUST' -Detail 'validate active catalog signer trust and absence of private key'; Assert-PublicSignerTrust -Thumbprint $ExpectedCatalogSigner; Add-Check 'ACTIVE_CATALOG_SIGNER_TRUST_NO_PRIVATE_KEY' $true $ExpectedCatalogSigner } catch { Add-Check 'ACTIVE_CATALOG_SIGNER_TRUST_NO_PRIVATE_KEY' $false $_.Exception.Message }
    try {
        Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 20 -Status 'VERIFYING' -Detail 'resolve pinned SignTool and verify active INF catalog membership'
        $Tools = Resolve-PortableKitTools
        if ($null -eq $Tools) { throw 'Pinned portable SignTool is unavailable for active catalog membership verification.' }
        $ActiveInfInStore = Join-Path $DriverStoreRoot 'u0205306.inf'
        $MembershipOutput = & $Tools.SignTool verify /pa /v /c $Cat $ActiveInfInStore 2>&1
        $MembershipExit = $LASTEXITCODE
        $MembershipDetail = (@($MembershipOutput) -join ' ')
        if ($MembershipDetail.Length -gt 500) { $MembershipDetail = $MembershipDetail.Substring(0,500) }
        Add-Check 'ACTIVE_CATALOG_INF_MEMBERSHIP' ($MembershipExit -eq 0) ("Exit=$MembershipExit; $MembershipDetail")
    } catch { Add-Check 'ACTIVE_CATALOG_INF_MEMBERSHIP' $false $_.Exception.Message }
}

$OfficialTrustDisposition = if ($null -ne $State.PSObject.Properties['OfficialCatalogTrustDisposition']) { [string]$State.OfficialCatalogTrustDisposition } else { '' }
$OfficialRegisteredPath = if ($null -ne $State.PSObject.Properties['OfficialCatalogRegisteredPath']) { [string]$State.OfficialCatalogRegisteredPath } else { '' }
$OfficialRegisteredSHA256 = if ($null -ne $State.PSObject.Properties['OfficialCatalogRegisteredSHA256']) { [string]$State.OfficialCatalogRegisteredSHA256 } else { '' }
$OfficialRegisteredSignerSubject = if ($null -ne $State.PSObject.Properties['OfficialCatalogRegisteredSignerSubject']) { [string]$State.OfficialCatalogRegisteredSignerSubject } else { '' }
$OfficialSourceSHA256 = if ($null -ne $State.PSObject.Properties['OfficialCatalogSourceSHA256']) { [string]$State.OfficialCatalogSourceSHA256 } else { '' }
$OfficialManagedBaseName = if ($null -ne $State.PSObject.Properties['OfficialCatalogManagedBaseName']) { [string]$State.OfficialCatalogManagedBaseName } else { '' }
$OfficialStatePass = ($OfficialTrustDisposition -in @('Apply','Idempotent') -and $OfficialSourceSHA256 -eq $Script:ExpectedOfficialCatalogSHA256 -and $OfficialRegisteredSHA256 -eq $Script:ExpectedOfficialCatalogSHA256 -and $OfficialManagedBaseName -ieq $Script:OfficialCatalogManagedBaseName)
Add-Check 'OFFICIAL_CATALOG_STATE_CONTRACT' $OfficialStatePass ("Disposition=$OfficialTrustDisposition; SourceSHA=$OfficialSourceSHA256; RegisteredSHA=$OfficialRegisteredSHA256; ManagedName=$OfficialManagedBaseName")

$OfficialPathPass = $false
if (-not [string]::IsNullOrWhiteSpace($OfficialRegisteredPath)) {
    try { $OfficialPathPass = (Test-LegionGoManagedCatalogPath -CatalogPath $OfficialRegisteredPath) -and (Test-Path -LiteralPath $OfficialRegisteredPath -PathType Leaf) } catch { $OfficialPathPass = $false }
}
Add-Check 'OFFICIAL_CATALOG_REGISTERED_PATH' $OfficialPathPass $OfficialRegisteredPath

$OfficialActualHash = ''
if ($OfficialPathPass) { try { $OfficialActualHash = Get-SHA256 -LiteralPath $OfficialRegisteredPath } catch {} }
Add-Check 'OFFICIAL_CATALOG_SHA256' ($OfficialActualHash -eq $Script:ExpectedOfficialCatalogSHA256) ("Expected=$($Script:ExpectedOfficialCatalogSHA256); Actual=$OfficialActualHash")

$OfficialSigStatus='';$OfficialSigSubject=''
if ($OfficialPathPass) {
    try {
        $OfficialSig=Get-AuthenticodeSignature -LiteralPath $OfficialRegisteredPath
        $OfficialSigStatus=[string]$OfficialSig.Status
        if($null-ne$OfficialSig.SignerCertificate){$OfficialSigSubject=[string]$OfficialSig.SignerCertificate.Subject}
    } catch {}
}
Add-Check 'OFFICIAL_CATALOG_SIGNATURE' ($OfficialSigStatus -eq 'Valid' -and $OfficialSigSubject -match $Script:ExpectedOfficialCatalogSignerPattern -and $OfficialSigSubject -eq $OfficialRegisteredSignerSubject) ("Status=$OfficialSigStatus; StateSigner=$OfficialRegisteredSignerSubject; ActualSigner=$OfficialSigSubject")

$DualAudit=@();$DualAuditError=''
if ($null -ne $DriverStoreRoot -and -not [string]::IsNullOrWhiteSpace($ExpectedCatalogHash) -and -not [string]::IsNullOrWhiteSpace($ExpectedCatalogSigner)) {
    try { $DualAudit=@(Get-LegionGoDualCatalogAudit -DriverStoreRoot $DriverStoreRoot -ExpectedLocalCatalogSHA256 $ExpectedCatalogHash -ExpectedLocalSignerThumbprint $ExpectedCatalogSigner) } catch { $DualAuditError=$_.Exception.Message }
} else { $DualAuditError='Driver Store root or active local catalog identity is unavailable.' }
$DualAuditExact = ([string]::IsNullOrWhiteSpace($DualAuditError) -and $DualAudit.Count -eq 14)
Add-Check 'DUAL_CATALOG_TARGETS_EXACT' $DualAuditExact $(if($DualAuditExact){'14/14 frozen target lengths and SHA256 values exact'}else{$DualAuditError})
$DualLocalCount = @($DualAudit | Where-Object { $_.HasExpectedLocalCatalog }).Count
Add-Check 'DUAL_CATALOG_LOCAL_COVERAGE' ($DualAuditExact -and $DualLocalCount -eq 14) ("Covered=$DualLocalCount/14")
$DualOfficialCount = @($DualAudit | Where-Object { $_.HasExpectedOfficialCatalog }).Count
Add-Check 'DUAL_CATALOG_OFFICIAL_COVERAGE' ($DualAuditExact -and $DualOfficialCount -eq 14) ("Covered=$DualOfficialCount/14")
$DualOfficialPaths = @($DualAudit | ForEach-Object { $_.OfficialCatalogPaths } | Where-Object { $_ } | Sort-Object -Unique)
$DualUniqueOfficialPass = ($DualAuditExact -and $DualOfficialPaths.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($OfficialRegisteredPath) -and [string]$DualOfficialPaths[0] -ieq $OfficialRegisteredPath)
Add-Check 'DUAL_CATALOG_UNIQUE_OFFICIAL_PATH' $DualUniqueOfficialPass ("Count=$($DualOfficialPaths.Count); Enumerated=$($DualOfficialPaths -join ','); State=$OfficialRegisteredPath")
$DualEvidence=[ordered]@{Generated=(Get-Date).ToString('o');Error=$DualAuditError;ExpectedLocalCatalogSHA256=$ExpectedCatalogHash;ExpectedLocalSignerThumbprint=$ExpectedCatalogSigner;OfficialCatalogPath=$OfficialRegisteredPath;OfficialCatalogSHA256=$OfficialActualHash;OfficialCatalogSignerSubject=$OfficialSigSubject;Targets=@($DualAudit)}
Write-JsonAtomic -InputObject $DualEvidence -LiteralPath (Join-Path $EvidenceRoot 'Dual-Catalog-Target-Audit.json') -Depth 40

Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 21 -Status 'QUERYING' -Detail 'enumerate AMD Display packages with fresh Driver Store inventory'
$Display = @(Get-AmdDisplayDrivers)
$FinalRows=@();$OldRows=@()
foreach($D in $Display){try{$H=Get-SHA256 ([string]$D.OriginalFileName);if($H-eq$Script:ExpectedFinalInfSHA256){$FinalRows+=$D};if($H-eq'A5FA34998C1B181A682727EB10EE18531EB2B5873AD8B40F0D104C6738ED0E83'){$OldRows+=$D}}catch{}}
Add-Check 'FINAL_V5_DRIVERSTORE_ROW_PRESENT' ($FinalRows.Count -ge 1) ("ExactFinalRows=$($FinalRows.Count)")
Add-Check 'AMD_DISPLAY_PACKAGE_INVENTORY' $true ("TotalAmdDisplayRows=$($Display.Count); InactiveOrOtherRows=$([Math]::Max(0,$Display.Count-$FinalRows.Count)); LegacyA5faRows=$($OldRows.Count); inactive rows are retained by design")
Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 25 -Status 'QUERYING' -Detail 'build target-compatible Display Driver Store inventory'
$TargetInventory=@(Get-DisplayDriverInventory | Where-Object { $_.TargetsSelectedProfile })
Add-Check 'LEGION_GO_DISPLAY_PACKAGE_INVENTORY' $true ("TargetCompatibleRows=$($TargetInventory.Count); ActiveINF=$($Gpu.ActiveINF); active exact binding is authoritative")
$AllExt=@(Get-Amduw23eDrivers)
$Ext=@(Get-LenovoExtensionDrivers)
$ForeignStagedCount=[Math]::Max(0,$AllExt.Count-$Ext.Count)
Add-Check 'NO_STAGED_LEGION_GO_AMDUW23E' ($Ext.Count -eq 0) ("Go1Applicable=$($Ext.Count); ForeignNonApplicable=$ForeignStagedCount; TotalAmduw23e=$($AllExt.Count); foreign packages are preserved by design")
$PhysicalExtError=''
$PhysicalExt=@()
try { $PhysicalExt=@(Get-Amduw23ePhysicalRepositoryInventory) } catch { $PhysicalExtError=$_.Exception.Message }
$PhysicalGo1=@($PhysicalExt | Where-Object { [bool]$_.TargetsSelectedProfile })
$PhysicalForeign=@($PhysicalExt | Where-Object { -not [bool]$_.TargetsSelectedProfile })
$PhysicalPass=([string]::IsNullOrWhiteSpace($PhysicalExtError) -and $PhysicalGo1.Count -eq 0)
Add-Check 'NO_PHYSICAL_LEGION_GO_AMDUW23E_REPOSITORY' $PhysicalPass ("Go1Applicable=$($PhysicalGo1.Count); ForeignNonApplicable=$($PhysicalForeign.Count); Error=$PhysicalExtError; foreign repositories are preserved by design")
Add-Check 'TEST_SIGNING_OFF' (-not (Get-TestSigningConfigured)) ('Configured=' + (Get-TestSigningConfigured))
Add-Check 'NO_INTEGRITY_CHECKS_OFF' (-not (Get-NoIntegrityChecksConfigured)) ('Configured=' + (Get-NoIntegrityChecksConfigured))
$FinalSecureBoot=Get-SecureBootState
Add-Check 'SECURE_BOOT_DISABLED_FOR_LOCAL_SIGNER' ($FinalSecureBoot -eq $false) ('SecureBoot=' + [string]$FinalSecureBoot)
$Stage1Signer = [string]$State.SignerThumbprint
$SignerTrustDisposition = if ($null -ne $State.PSObject.Properties['SignerTrustDisposition']) { [string]$State.SignerTrustDisposition } else { '' }
$ExpectedSignerTrustDisposition = if ($CatalogDisposition -eq 'Stage1Candidate') { 'ActiveStage1SignerRetained' } elseif ($CatalogDisposition -eq 'RetainedPreexistingExactFinal') { 'UnusedStage1SignerRemoved' } else { '' }
Add-Check 'STAGE1_SIGNER_TRUST_DISPOSITION' (-not [string]::IsNullOrWhiteSpace($ExpectedSignerTrustDisposition) -and $SignerTrustDisposition -eq $ExpectedSignerTrustDisposition) ("CatalogDisposition=$CatalogDisposition; Expected=$ExpectedSignerTrustDisposition; Actual=$SignerTrustDisposition")
$SignerRelationPass = if ($CatalogDisposition -eq 'Stage1Candidate') { $Stage1Signer -eq $ExpectedCatalogSigner } elseif ($CatalogDisposition -eq 'RetainedPreexistingExactFinal') { -not [string]::IsNullOrWhiteSpace($Stage1Signer) -and $Stage1Signer -ne $ExpectedCatalogSigner } else { $false }
Add-Check 'STAGE1_ACTIVE_SIGNER_RELATION' $SignerRelationPass ("CatalogDisposition=$CatalogDisposition; Stage1Signer=$Stage1Signer; ActiveSigner=$ExpectedCatalogSigner")
if ($CatalogDisposition -eq 'RetainedPreexistingExactFinal') {
    try { Assert-SignerTrustAbsent -Thumbprint $Stage1Signer; Add-Check 'UNUSED_STAGE1_SIGNER_ABSENT' $true $Stage1Signer } catch { Add-Check 'UNUSED_STAGE1_SIGNER_ABSENT' $false $_.Exception.Message }
} else {
    Add-Check 'UNUSED_STAGE1_SIGNER_ABSENT' $true 'Not applicable: Stage1Candidate is the active catalog signer and its public trust must remain.'
}

$ClassPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\' + [string]$Gpu.DriverKey
if([string]$SelectedProfile.Id -eq 'LegionGo1'){
    $DxvaPath = Join-Path $ClassPath 'UMD\DXVA'
    Test-Reg $ClassPath 'DALNonStandardModesBCD5' '07,20,12,80,00,00,00,00,08,00,12,80,00,00,00,00,09,00,16,00,00,00,00,00,10,00,16,00,00,00,00,00,10,80,19,20,00,00,00,00,12,00,19,20,00,00,00,00,14,40,25,60,00,00,00,00' 'Binary'
    Test-Reg $ClassPath 'DALRestrictedModesBCD5' '16,00,12,00,00,00,00,00,12,80,10,24,00,00,00,00' 'Binary'
    foreach($Pair in @(
        @('HotkeysDisabled',1,'Dword'),@('dvr_ui_component_na','true','String'),@('DFPFreeSyncDefault',1,'Dword'),@('PP_WaitOnRegisterTimeout',10000,'Dword'),@('AllowWebContent','false','String'),@('LogoUrl','hide','String'),@('SystemTray','false','String'),@('DALRULE_ALLOWMONITORRANGELIMITMODESCRT',0,'Dword'),@('ToggleRsHotkey','none','String'),@('LCDFreeSyncDefault',7,'Dword'),@('PP_UserVariBrightLevel',2,'Dword'),@('Dal_UserVariBrightLevel',2,'Dword'),
        @('DalFeatureEnablePsrSU',0,'Dword'),@('DalDisableZ10',1,'Dword'),@('EnableswGCFakeCGCG',1,'Dword'),@('DalEmbeddedIntegerScalingSupport',1,'Dword'),@('DalPSRFeatureEnable',0,'Dword'),@('DalWirelessDisplaySupport',1,'Dword'),@('DalDetectRequireHpdHigh',0,'Dword'),@('DisableFBCSupport',1,'Dword'),@('SmartDCDefMode',0,'Dword')
    )) { Test-Reg $ClassPath ([string]$Pair[0]) $Pair[1] ([string]$Pair[2]) }
    Test-Reg $ClassPath 'BDC7EDEA37E855EFFD36' '59,79,07,9B' 'Binary'
    Test-Reg $ClassPath 'BDC7EDEA40E855EFFDFB' '59,79,07,9B' 'Binary'
    Test-Reg $ClassPath 'ShowRSOverlay' 'true' 'String'
    Test-Reg $DxvaPath 'ColorVibrance_ENABLE_DEF' '1' 'String'
}else{
    $ProfileRegIndex=0
    foreach($SourceSectionName in $SelectedProfile.Lenovo.OemSectionOrder){
        foreach($Directive in @($SelectedProfile.Lenovo.OemSections.$SourceSectionName)){
            $ProfileRegIndex++
            $Parsed=Parse-LegionGoProfileRegistryDirective -Directive ([string]$Directive)
            $RegistryPath=$ClassPath
            if(-not [string]::IsNullOrWhiteSpace([string]$Parsed.SubKey)){$RegistryPath=Join-Path $ClassPath ([string]$Parsed.SubKey)}
            $ProfileCheckName=('PROFILE_REG_{0:D2}_{1}' -f $ProfileRegIndex,[string]$Parsed.Name)
            Test-Reg -Path $RegistryPath -Name ([string]$Parsed.Name) -Expected $Parsed.Expected -Kind ([string]$Parsed.Kind) -CheckName $ProfileCheckName
        }
    }
}

$CNextCode = if ($null -ne $State.PSObject.Properties['ExpectedCNextProductCode'] -and -not [string]::IsNullOrWhiteSpace([string]$State.ExpectedCNextProductCode)) { [string]$State.ExpectedCNextProductCode } else { '{3E29E4A3-84A8-4FD0-BE51-9100C2F2C2AB}' }
$DvrCode = if ($null -ne $State.PSObject.Properties['ExpectedDvrProductCode'] -and -not [string]::IsNullOrWhiteSpace([string]$State.ExpectedDvrProductCode)) { [string]$State.ExpectedDvrProductCode } else { '{17D1889D-8542-4ECE-975A-5BC1845314BC}' }
Add-Check 'CNEXT_MSI_INSTALLED' (Product-Installed $CNextCode) $CNextCode
Add-Check 'DVR_MSI_INSTALLED' (Product-Installed $DvrCode) $DvrCode
$RuntimeNames=@('RadeonSoftware.exe','cncmd.exe','AMDRSServ.exe','AMDRSSrcExt.exe','amdow.exe','PresentMon-x64.exe','RSServCmd.exe')
foreach($RName in $RuntimeNames){
    $Path=Join-Path "$env:ProgramFiles\AMD\CNext\CNext" $RName;$H='';try{$H=Get-SHA256WithProgress -LiteralPath $Path -Activity ('Final audit runtime SHA-256: '+$RName)}catch{}
    $ExpectedRHash = ''
    if ($null -ne $State.PSObject.Properties['RuntimeHashes']) {
        $RProp = $State.RuntimeHashes.PSObject.Properties[$RName]
        if ($null -ne $RProp) { $ExpectedRHash = [string]$RProp.Value }
    }
    $RPass = if (-not [string]::IsNullOrWhiteSpace($ExpectedRHash)) { $H -eq $ExpectedRHash } else { -not [string]::IsNullOrWhiteSpace($H) }
    Add-Check ('RUNTIME_'+$RName) $RPass $H
}
Set-ActivityLivenessContext -Activity 'Final persistence audit' -Percent 89 -Status 'QUERYING' -Detail 'audit ancillary RSXCM AppX registration'
$RsxAll=@(Get-AppxPackage -AllUsers -Name 'AdvancedMicroDevicesInc-RSXCM' -ErrorAction SilentlyContinue)
$Rsx=@($RsxAll|Where-Object{[string]$_.Version-eq'22.10.0.0'})
if($Rsx.Count-ge1){$RsxcmAncillary=[pscustomobject]@{Name='AdvancedMicroDevicesInc-RSXCM';ExpectedVersion='22.10.0.0';Status='Expected';ExpectedCount=$Rsx.Count;TotalCount=$RsxAll.Count;Versions=@($RsxAll|ForEach-Object{[string]$_.Version}|Sort-Object -Unique)};Write-Host ("[PASS] RSXCM_ANCILLARY :: Expected 22.10.0.0 registration count=$($Rsx.Count)") -ForegroundColor Green}
elseif($RsxAll.Count-gt0){$RsxVersions=@($RsxAll|ForEach-Object{[string]$_.Version}|Sort-Object -Unique);$RsxcmAncillary=[pscustomobject]@{Name='AdvancedMicroDevicesInc-RSXCM';ExpectedVersion='22.10.0.0';Status='UnexpectedVersion';ExpectedCount=0;TotalCount=$RsxAll.Count;Versions=$RsxVersions};Add-Warning 'RSXCM_ANCILLARY_UNEXPECTED_VERSION' ("Expected=22.10.0.0; Versions=$($RsxVersions -join ','); non-blocking shell/context-menu integration warning")}
else{$RsxcmAncillary=[pscustomobject]@{Name='AdvancedMicroDevicesInc-RSXCM';ExpectedVersion='22.10.0.0';Status='NotRegistered';ExpectedCount=0;TotalCount=0;Versions=@()};Add-Warning 'RSXCM_ANCILLARY_NOT_REGISTERED' 'AdvancedMicroDevicesInc-RSXCM is not registered; non-blocking shell/context-menu integration warning'}
$Legacy=@(Get-AppxPackage -AllUsers -Name 'AdvancedMicroDevicesInc-2.AMDRadeonSoftware' -ErrorAction SilentlyContinue)
Add-Check 'NO_LEGACY_RADEON_STORE_APPX' ($Legacy.Count -eq 0) ("Count=$($Legacy.Count)")
foreach($Task in @('StartCN','StartDVR')){$T=Get-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue|Select-Object -First 1;Add-Check ('TASK_'+$Task) ($null-ne$T) $(if($null-ne$T){[string]$T.State}else{'missing'})}

$Failed=@($Checks|Where-Object{-not$_.Pass})
$Report=[ordered]@{Schema='LegionGo-AMD-26.9.2-Public-Beta-v5.0-Final-Audit';Generated=(Get-Date).ToString('o');ReadOnly=$true;Passed=($Failed.Count-eq0);FailedChecks=$Failed.Count;WarningCount=@($Warnings).Count;Warnings=$Warnings;RsxcmAncillary=$RsxcmAncillary;Checks=$Checks;Gpu=$Gpu;WorkflowStage=[string]$State.Stage;SignerThumbprint=[string]$State.SignerThumbprint;SignerTrustDisposition=$(if($null-ne$State.PSObject.Properties['SignerTrustDisposition']){[string]$State.SignerTrustDisposition}else{''});ActiveCatalogDisposition=$(if($null-ne$State.PSObject.Properties['ActiveCatalogDisposition']){[string]$State.ActiveCatalogDisposition}else{''});ExpectedActiveCatalogSHA256=$(if($null-ne$State.PSObject.Properties['ExpectedActiveCatalogSHA256']){[string]$State.ExpectedActiveCatalogSHA256}else{''});ExpectedActiveCatalogSignerThumbprint=$(if($null-ne$State.PSObject.Properties['ExpectedActiveCatalogSignerThumbprint']){[string]$State.ExpectedActiveCatalogSignerThumbprint}else{''});OfficialCatalogTrustDisposition=$OfficialTrustDisposition;OfficialCatalogRegisteredPath=$OfficialRegisteredPath;OfficialCatalogRegisteredSHA256=$OfficialRegisteredSHA256;OfficialCatalogRegisteredSignerSubject=$OfficialRegisteredSignerSubject}
Write-JsonAtomic -InputObject $Report -LiteralPath (Join-Path $EvidenceRoot 'Final-Audit.json') -Depth 30
$Checks|Format-Table -AutoSize|Out-String -Width 240|Set-Content -LiteralPath (Join-Path $EvidenceRoot 'Checks.txt') -Encoding UTF8
$Warnings|Format-Table -AutoSize|Out-String -Width 240|Set-Content -LiteralPath (Join-Path $EvidenceRoot 'Warnings.txt') -Encoding UTF8
$AuditPassed = ($Failed.Count -eq 0)
$AuditExitCode = if($AuditPassed){0}else{1}
$AuditStatus = if($AuditPassed){'Passed'}else{'Failed'}
Write-Stage4Result -Status $AuditStatus -ExitCode $AuditExitCode -FailedChecks $Failed.Count -EvidencePath $EvidenceRoot

Complete-ActivityProgress -Activity 'Final persistence audit' -Detail (("{0}/{1} checks executed" -f @($Checks).Count,$ExpectedAuditCheckCount))
Write-Section 'FINAL RESULT'
Write-Host ("SCRIPT 4 PASS: {0}" -f $AuditPassed)
Write-Host ("Failed checks: {0}" -f $Failed.Count)
Write-Host ("Warnings: {0}" -f @($Warnings).Count)
Write-Host ("PUBLIC BETA v5.0 COMPLETE: {0}" -f $AuditPassed)
Write-Host "Evidence: $EvidenceRoot"

exit $AuditExitCode
