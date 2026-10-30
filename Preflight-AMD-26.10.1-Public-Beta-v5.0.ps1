#requires -Version 5.1
<#
READ-ONLY public package preflight for AMD 26.9.2 Public Beta v5.0.
Validates package integrity, PowerShell parsing, the release contract, all four
exact-HWID profiles, OEM directive parsing, Stage 1/2/4 safety ordering, and
optionally deterministic INF/DAT rebuilds from exact official AMD source files.
It does not execute any numbered mutating stage.
#>
[CmdletBinding()]
param([string]$OfficialInfPath='',[string]$OfficialDatPath='',[string]$ResultPath='')

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$Checks=@()
$Schema='LegionGo-AMD-26.9.2-Public-Beta-v5.0-PreflightResult-v1'

function Check([string]$Name,[bool]$Pass,[string]$Detail){
    $script:Checks += [pscustomobject]@{Name=$Name;Pass=$Pass;Detail=$Detail}
    if($Pass){Write-Host ("[PASS] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Green}
    else{Write-Host ("[FAIL] {0} :: {1}" -f $Name,$Detail) -ForegroundColor Red}
}
function Hash([string]$Path){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Required file is missing: $Path"}
    $Stream=$null;$Sha=$null
    try{
        $Stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        $Sha=[Security.Cryptography.SHA256]::Create()
        $Bytes=$Sha.ComputeHash($Stream)
        return ([BitConverter]::ToString($Bytes)).Replace('-','').ToUpperInvariant()
    }
    finally{
        if($null-ne$Stream){$Stream.Dispose()}
        if($null-ne$Sha){$Sha.Dispose()}
    }
}

Write-Host '========================================================================'
Write-Host ' LEGION GO AMD 26.10.1 PUBLIC BETA v5.0 - READ-ONLY PACKAGE PREFLIGHT'
Write-Host '========================================================================'

$ManifestPath=Join-Path $Root 'PACKAGE-MANIFEST.json'
$ManifestPass=$true;$ManifestDetail=''
try{
    if(-not(Test-Path -LiteralPath $ManifestPath -PathType Leaf)){throw 'PACKAGE-MANIFEST.json missing.'}
    $Manifest=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    $Count=0
    foreach($Row in $Manifest){
        $Path=Join-Path $Root ([string]$Row.Path)
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Manifest file missing: $($Row.Path)"}
        if((Get-Item -LiteralPath $Path).Length -ne [int64]$Row.Length){throw "Manifest length mismatch: $($Row.Path)"}
        if((Hash $Path) -cne [string]$Row.SHA256){throw "Manifest SHA256 mismatch: $($Row.Path)"}
        $Count++
    }
    $ManifestDetail=("{0}/{0}" -f $Count)
}catch{$ManifestPass=$false;$ManifestDetail=$_.Exception.Message}
Check 'PACKAGE_MANIFEST' $ManifestPass $ManifestDetail

$ScopePath=Join-Path $Root 'PUBLIC-RELEASE-SCOPE.json'
$ScopePass=$true;$ScopeDetail=''
try{
    if(-not(Test-Path -LiteralPath $ScopePath -PathType Leaf)){throw 'PUBLIC-RELEASE-SCOPE.json missing.'}
    $PublicScope=Get-Content -LiteralPath $ScopePath -Raw -Encoding UTF8|ConvertFrom-Json
    if([string]$PublicScope.Schema -cne 'LegionGo-AMD-26.9.2-Public-Beta-v5.0-Scope-v1'){throw "Unexpected scope schema: $($PublicScope.Schema)"}
    if([bool]$PublicScope.ManualProfileOverride){throw 'Manual profile override is not permitted.'}
    if(@($PublicScope.Profiles).Count -ne 4){throw "Expected exactly four public profiles; got $(@($PublicScope.Profiles).Count)."}
    $ScopeDetail='exact-HWID public scope; four profiles; no manual override'
}catch{$ScopePass=$false;$ScopeDetail=$_.Exception.Message}
Check 'PUBLIC_RELEASE_SCOPE' $ScopePass $ScopeDetail

$ParserErrors=0;$PsCount=0
foreach($File in @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse)){
    $Tokens=$null;$Errors=$null
    [Management.Automation.Language.Parser]::ParseFile($File.FullName,[ref]$Tokens,[ref]$Errors)|Out-Null
    $ParserErrors += [int]$Errors.Count
    $PsCount++
}
Check 'POWERSHELL_5_1_PARSER' ($ParserErrors -eq 0) ("Files=$PsCount; Errors=$ParserErrors")

. (Join-Path $Root 'Internal\Common.ps1')
$ReleaseContract=Get-LegionGoReleaseContract
$Profiles=@(Get-LegionGoProfiles -ProfileRoot (Join-Path $Root 'Internal\Profiles'))
Check 'RELEASE_CONTRACT' ([string]$ReleaseContract.ReleaseId -eq 'AMD-26.10.1' -and [string]$ReleaseContract.DriverVersion -eq '32.0.32015.7029') ("Release={0}; Driver={1}; Fingerprint={2}" -f $ReleaseContract.ReleaseId,$ReleaseContract.DriverVersion,$ReleaseContract.Fingerprint)
Check 'PROFILE_COUNT' ($Profiles.Count -eq 4) ("Count=$($Profiles.Count)")

$ExpectedProfileIds=@('LegionGo1','LegionGoS-Z1Extreme','LegionGo2-Z2Extreme','MsiClawA8-Z2Extreme')
$ProfileIds=@($Profiles|ForEach-Object{[string]$_.Id})
$IdPass=(@($ExpectedProfileIds|Where-Object{$_ -notin $ProfileIds}).Count -eq 0 -and @($ProfileIds|Where-Object{$_ -notin $ExpectedProfileIds}).Count -eq 0)
Check 'PROFILE_IDS_EXACT' $IdPass ($ProfileIds -join ',')
$Go1=$Profiles|Where-Object{[string]$_.Id -eq 'LegionGo1'}|Select-Object -First 1
$GoS=$Profiles|Where-Object{[string]$_.Id -eq 'LegionGoS-Z1Extreme'}|Select-Object -First 1
$Go2=$Profiles|Where-Object{[string]$_.Id -eq 'LegionGo2-Z2Extreme'}|Select-Object -First 1
Check 'ALL_PROFILES_INSTALL_CAPABLE' (@($Profiles | Where-Object { -not [bool]$_.InstallCapable }).Count -eq 0) ("Go1={0}; GoS={1}; Go2={2}" -f $Go1.InstallCapable,$GoS.InstallCapable,$Go2.InstallCapable)

$ScopeFixtures=[ordered]@{
    'MsiClawA8-Z2Extreme'='PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C5'
    LegionGo1='PCI\VEN_1002&DEV_15BF&SUBSYS_381217AA&REV_04'
    'LegionGoS-Z1Extreme'='PCI\VEN_1002&DEV_15BF&SUBSYS_380C17AA&REV_04'
    'LegionGo2-Z2Extreme'='PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C5'
}
foreach($FixtureId in $ScopeFixtures.Keys){
    $ResolvedFixture=Resolve-LegionGoProfile -Profiles $Profiles -InstanceIds @([string]$ScopeFixtures[$FixtureId])
    Check ('EXACT_HWID_SCOPE_'+[string]$FixtureId) ([string]$ResolvedFixture.Id -ceq [string]$FixtureId) ([string]$ScopeFixtures[$FixtureId])
}
$WrongFixtureRejected=$false
try{[void](Resolve-LegionGoProfile -Profiles $Profiles -InstanceIds @('PCI\VEN_1002&DEV_150E&SUBSYS_381C17AA&REV_C4'))}catch{$WrongFixtureRejected=$true}
Check 'UNVALIDATED_HWID_REJECTED' $WrongFixtureRejected 'Go 2 REV_C4 fixture rejected'

$FrozenExpected=[ordered]@{
    'MsiClawA8-Z2Extreme'=@('B279B6972A93D5ECA2D8D40F160F60D4B69206E3BC0DD1AC9A7BEB9CFA890C7E','CDF57D74268F3CB763A996C16811CCB26F4055750743EEB68D03D8D686A2EC02')
    LegionGo1=@('AE9D42FEA2FCBD6739CF1E4F540EA4A7F21EF5DA099C66F603130843462E747D','B928E5C32E85895A1C8EF20FBC90D3348C593AF88A1C6BF94E9A6B6E4A650E32')
    'LegionGoS-Z1Extreme'=@('6108B18E339E221506CB153B2F77B9521D1C7DF9B23429BA61381979A5BFE42E','B928E5C32E85895A1C8EF20FBC90D3348C593AF88A1C6BF94E9A6B6E4A650E32')
    'LegionGo2-Z2Extreme'=@('7201A6EC902929B2292BA4AA014645CA98A0B7B65777F15EA77D0BAB8D1B8DDB','CDF57D74268F3CB763A996C16811CCB26F4055750743EEB68D03D8D686A2EC02')
}
foreach($Profile in $Profiles){
    $Expected=$FrozenExpected[[string]$Profile.Id]
    $Pass=($null -ne $Expected -and [string]$Profile.Final.ExpectedInfSHA256 -ceq [string]$Expected[0] -and [string]$Profile.Final.ExpectedDatSHA256 -ceq [string]$Expected[1])
    Check ('PROFILE_FROZEN_IDENTITIES_'+[string]$Profile.Id) $Pass ("INF={0}; DAT={1}" -f $Profile.Final.ExpectedInfSHA256,$Profile.Final.ExpectedDatSHA256)
    $ReadyPass=$false;$ReadyDetail=''
    try{[void](Assert-SelectedProfileInstallReadiness -Profile $Profile);$ReadyPass=$true;$ReadyDetail='exact frozen public identity accepted'}catch{$ReadyDetail=$_.Exception.Message}
    Check ('INSTALL_READINESS_'+[string]$Profile.Id) $ReadyPass $ReadyDetail
}

$UnchangedManifest=Join-Path $Root 'Internal\V4-Unchanged-190.json'
$OfficialTargets=Join-Path $Root 'Internal\Official-Catalog-Targets-14.json'
$UnchangedRows=Get-Content -LiteralPath $UnchangedManifest -Raw -Encoding UTF8|ConvertFrom-Json
$OfficialRows=Get-Content -LiteralPath $OfficialTargets -Raw -Encoding UTF8|ConvertFrom-Json
$UnchangedCount=if($UnchangedRows -is [System.Array]){$UnchangedRows.Length}else{@($UnchangedRows).Count}
$OfficialCount=if($OfficialRows -is [System.Array]){$OfficialRows.Length}else{@($OfficialRows).Count}
Check 'UNCHANGED_MANIFEST_COUNT' ($UnchangedCount -eq 191) ("Count=$UnchangedCount")
Check 'UNCHANGED_MANIFEST_SHA256' ((Hash $UnchangedManifest) -eq '1E657A79BA64C86461664751021F87E5D7E29A216CE2422BBA93B9F24F5C6174') (Hash $UnchangedManifest)
Check 'OFFICIAL_TARGET_MANIFEST_COUNT' ($OfficialCount -eq 14) ("Count=$OfficialCount")
Check 'OFFICIAL_TARGET_MANIFEST_SHA256' ((Hash $OfficialTargets) -eq '25BAA48F8B69FCE85565ADC236B3941E1B442C935BB94C0351DEE559892D9CED') (Hash $OfficialTargets)

$ParsedDirectiveCount=0;$DirectiveParseError=''
try{
    foreach($Profile in @($GoS,$Go2)){
        foreach($SectionName in $Profile.Lenovo.OemSectionOrder){
            foreach($Directive in @($Profile.Lenovo.OemSections.$SectionName)){
                [void](Parse-LegionGoProfileRegistryDirective -Directive ([string]$Directive))
                $ParsedDirectiveCount++
            }
        }
    }
}catch{$DirectiveParseError=$_.Exception.Message}
Check 'PROFILE_OEM_DIRECTIVE_COUNT' ([string]::IsNullOrWhiteSpace($DirectiveParseError) -and $ParsedDirectiveCount -eq 58) ("Parsed=$ParsedDirectiveCount; Error=$DirectiveParseError")

$Stage1=Get-Content -LiteralPath (Join-Path $Root '01-Prepare-Build-Sign-And-Enter-Test-Signing.ps1') -Raw
$Stage2=Get-Content -LiteralPath (Join-Path $Root '02-Install-Driver-And-Verify-Normal-Signing.ps1') -Raw
$Stage3=Get-Content -LiteralPath (Join-Path $Root '03-Install-AMD-Software-And-Reboot.ps1') -Raw
$Stage4=Get-Content -LiteralPath (Join-Path $Root '04-Final-Persistence-Audit.ps1') -Raw
$StageContractTokens=@('Assert-SelectedProfileInstallReadiness','Assert-CandidateInfSelectedProfileBinding','Assert-WorkflowProfileIdentity','$BaseAuditCheckCount=45','$LegacyGo1RegistryCheckCount=27','$ExpectedAuditCheckCount=$BaseAuditCheckCount+6+$ProfileRegistryCheckCount',"'PROFILE_ACTIVE_DDINSTALL'")
foreach($Token in $StageContractTokens){
    $Present=($Stage1.Contains($Token) -or $Stage2.Contains($Token) -or $Stage3.Contains($Token) -or $Stage4.Contains($Token))
    Check ('STAGE_CONTRACT_'+($Token -replace '[^A-Za-z0-9]','_')) $Present $Token
}
Check 'STAGE1_READINESS_BEFORE_SOURCE_WORK' ($Stage1.IndexOf('Assert-SelectedProfileInstallReadiness') -ge 0 -and $Stage1.IndexOf('Assert-SelectedProfileInstallReadiness') -lt $Stage1.IndexOf('$ResolvedInstaller=Resolve-AdjacentAmdInstaller')) 'readiness gate precedes AMD source extraction'
$Stage2Marker="Set-StateProperty `$State 'TransactionStatus' 'DriverTransactionInProgress'"
Check 'STAGE2_BINDING_BEFORE_TRANSACTION' ($Stage2.IndexOf('Assert-CandidateInfSelectedProfileBinding') -ge 0 -and $Stage2.IndexOf('Assert-CandidateInfSelectedProfileBinding') -lt $Stage2.IndexOf($Stage2Marker)) 'exact HWID->DDInstall binding is proven before destructive transaction state'

$InfBuilderText=Get-Content -LiteralPath (Join-Path $Root 'Internal\Build-V4-Inf.ps1') -Raw
$DatBuilderText=Get-Content -LiteralPath (Join-Path $Root 'Internal\Build-V4-AmdGcfDat.ps1') -Raw
$AllProfileIds=@('LegionGo1','LegionGoS-Z1Extreme','LegionGo2-Z2Extreme','MsiClawA8-Z2Extreme')
$InfProfileCoverage=$true;$DatProfileCoverage=$true
foreach($ProfileId in $AllProfileIds){
    if(-not $InfBuilderText.Contains("'"+$ProfileId+"'")){$InfProfileCoverage=$false}
    if(-not $DatBuilderText.Contains("'"+$ProfileId+"'")){$DatProfileCoverage=$false}
}
$Go1ValidationGuard='Validation v1a enables only LegionGo1'
Check 'MULTIPROFILE_INF_BUILDER_STATIC' ($InfProfileCoverage -and -not $InfBuilderText.Contains($Go1ValidationGuard)) 'all four exact profile IDs routed; no Go1-only validation guard'
Check 'MULTIPROFILE_DAT_BUILDER_STATIC' ($DatProfileCoverage -and -not $DatBuilderText.Contains($Go1ValidationGuard)) 'all four exact profile IDs routed; Phoenix/Strix DAT selection is profile-driven'

$SourceArgumentsProvided=(-not [string]::IsNullOrWhiteSpace($OfficialInfPath) -or -not [string]::IsNullOrWhiteSpace($OfficialDatPath))
if($SourceArgumentsProvided){
    $BothSources=(-not [string]::IsNullOrWhiteSpace($OfficialInfPath) -and -not [string]::IsNullOrWhiteSpace($OfficialDatPath) -and (Test-Path -LiteralPath $OfficialInfPath -PathType Leaf) -and (Test-Path -LiteralPath $OfficialDatPath -PathType Leaf))
    Check 'SOURCE_INPUTS_PRESENT' $BothSources ("INF=$OfficialInfPath; DAT=$OfficialDatPath")
    if($BothSources){
        $InfSourceHash=Hash $OfficialInfPath;$DatSourceHash=Hash $OfficialDatPath
        Check 'OFFICIAL_INF_SOURCE_SHA256' ($InfSourceHash -eq '884C91EF4681D3E383B48DC760B4B2A95C95281E5796686A99A40B44FF65EE9D') $InfSourceHash
        Check 'OFFICIAL_DAT_SOURCE_SHA256' ($DatSourceHash -eq '289B143A466FD08102BEB72210988BED37792E1762BB863F9B85916D8F7CE8D9') $DatSourceHash
        $TempRoot=Join-Path ([IO.Path]::GetTempPath()) ('LegionGo-v5.0-Preflight-'+[guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $TempRoot -Force|Out-Null
        try{
            $InfBuilder=Join-Path $Root 'Internal\Build-V4-Inf.ps1'
            $DatBuilder=Join-Path $Root 'Internal\Build-V4-AmdGcfDat.ps1'
            foreach($Profile in $Profiles){
                $ProfileOut=Join-Path $TempRoot ([string]$Profile.Id);New-Item -ItemType Directory -Path $ProfileOut -Force|Out-Null
                $BuiltInf=Join-Path $ProfileOut 'u0205306.inf';$BuiltDat=Join-Path $ProfileOut 'amdgcf.dat'
                & $InfBuilder -OfficialInfPath $OfficialInfPath -OutputPath $BuiltInf -SelectedProfilePath ([string]$Profile.SourcePath)
                & $DatBuilder -OfficialDatPath $OfficialDatPath -OutputPath $BuiltDat -SelectedProfilePath ([string]$Profile.SourcePath)
                $InfHash=Hash $BuiltInf;$DatHash=Hash $BuiltDat
                Check ('DETERMINISTIC_INF_'+[string]$Profile.Id) ($InfHash -ceq [string]$Profile.Final.ExpectedInfSHA256) $InfHash
                Check ('DETERMINISTIC_DAT_'+[string]$Profile.Id) ($DatHash -ceq [string]$Profile.Final.ExpectedDatSHA256) $DatHash
                $BindingPass=$false;$BindingDetail=''
                try{$Binding=Assert-CandidateInfSelectedProfileBinding -InfPath $BuiltInf -Profile $Profile;$BindingPass=$true;$BindingDetail=[string]$Binding.ModelLine}catch{$BindingDetail=$_.Exception.Message}
                Check ('CANDIDATE_BINDING_'+[string]$Profile.Id) $BindingPass $BindingDetail
            }
        }finally{if(Test-Path -LiteralPath $TempRoot){Remove-Item -LiteralPath $TempRoot -Recurse -Force}}
    }
}else{
    Check 'SOURCE_REBUILD_SKIPPED' $true 'No source paths supplied; static package preflight only.'
}

$Failed=@($Checks|Where-Object{-not [bool]$_.Pass})
$Result=[ordered]@{
    Schema=$Schema
    GeneratedAt=(Get-Date).ToString('o')
    ReadOnly=$true
    Passed=($Failed.Count -eq 0)
    CheckCount=@($Checks).Count
    FailedChecks=$Failed.Count
    Profiles=@($Profiles|ForEach-Object{[ordered]@{Id=[string]$_.Id;InstallCapable=[bool]$_.InstallCapable;Fingerprint=[string]$_.Fingerprint;ExpectedInfSHA256=[string]$_.Final.ExpectedInfSHA256;ExpectedDatSHA256=[string]$_.Final.ExpectedDatSHA256}})
    Checks=$Checks
}
if(-not[string]::IsNullOrWhiteSpace($ResultPath)){
    $Parent=Split-Path -Parent $ResultPath
    if(-not[string]::IsNullOrWhiteSpace($Parent)){New-Item -ItemType Directory -Path $Parent -Force|Out-Null}
    $Result|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $ResultPath -Encoding UTF8
}
Write-Host '========================================================================'
Write-Host ("PUBLIC BETA v5.0 PREFLIGHT PASS: {0}" -f $Result.Passed)
Write-Host ("Checks: {0}; Failed: {1}" -f $Result.CheckCount,$Result.FailedChecks)
if(-not[string]::IsNullOrWhiteSpace($ResultPath)){Write-Host "Result: $ResultPath"}
if(-not $Result.Passed){exit 1}
exit 0
