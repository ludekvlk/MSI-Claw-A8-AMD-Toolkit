#requires -Version 5.1
[CmdletBinding()]
param([switch]$GateOnly,[string]$OfficialInfPath='',[string]$OfficialDatPath='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$ManifestPath=Join-Path $Root 'PACKAGE-MANIFEST.json'
$Preflight=Join-Path $Root 'Preflight-AMD-26.10.1-Public-Beta-v5.0.ps1'
$Launcher=Join-Path $Root 'Install-LegionGo-AMD-26.10.1.ps1'
$Schema='LegionGo-AMD-26.9.2-Public-Beta-v5.0-PreflightResult-v1'
$Downloads=Join-Path $env:USERPROFILE 'Downloads'
$Evidence=Join-Path $Downloads ('LegionGo-AMD-26.9.2-Public-Beta-v5.0-EntryGate-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt')
$TranscriptStarted=$false
try{Start-Transcript -LiteralPath $Evidence -Force|Out-Null;$TranscriptStarted=$true}catch{}

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
function Stop-EntryTranscript{if($script:TranscriptStarted){try{Stop-Transcript|Out-Null}catch{};$script:TranscriptStarted=$false}}

try{
    Write-Host '========================================================================'
    Write-Host ' LEGION GO AMD 26.10.1 - Public Beta v5.0'
    Write-Host ' INDEPENDENT PACKAGE + PARSER + PREFLIGHT GATE'
    Write-Host '========================================================================'
    if(-not(Test-Path -LiteralPath $ManifestPath -PathType Leaf)){throw 'PACKAGE-MANIFEST.json is missing.'}
    $Manifest=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    $Count=0
    foreach($Row in $Manifest){
        $Path=Join-Path $Root ([string]$Row.Path)
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Manifest file missing: $($Row.Path)"}
        if((Get-Item -LiteralPath $Path).Length -ne [int64]$Row.Length){throw "Manifest length mismatch: $($Row.Path)"}
        if((Hash $Path) -cne [string]$Row.SHA256){throw "Manifest SHA256 mismatch: $($Row.Path)"}
        $Count++
    }
    Write-Host ("[PASS] PACKAGE_MANIFEST :: {0}/{0}" -f $Count) -ForegroundColor Green

    $ParserFailures=0;$ParserCount=0
    foreach($File in @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File -Recurse)){
        $Tokens=$null;$Errors=$null
        [Management.Automation.Language.Parser]::ParseFile($File.FullName,[ref]$Tokens,[ref]$Errors)|Out-Null
        $ParserFailures += [int]$Errors.Count;$ParserCount++
    }
    if($ParserFailures -ne 0){throw "PowerShell parser gate failed. Files=$ParserCount Errors=$ParserFailures"}
    Write-Host ("[PASS] POWERSHELL_5_1_PARSER :: Files={0}; Errors=0" -f $ParserCount) -ForegroundColor Green

    $ResultPath=Join-Path $Downloads ('LegionGo-AMD-26.9.2-Public-Beta-v5.0-Preflight-'+[Guid]::NewGuid().ToString('N')+'.json')

    $PreflightArgs=@(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-File',$Preflight
    )
    if(-not [string]::IsNullOrWhiteSpace($OfficialInfPath)){
        $PreflightArgs += @('-OfficialInfPath',$OfficialInfPath)
    }
    if(-not [string]::IsNullOrWhiteSpace($OfficialDatPath)){
        $PreflightArgs += @('-OfficialDatPath',$OfficialDatPath)
    }
    $PreflightArgs += @('-ResultPath',$ResultPath)

    $SourceMode=if(
        [string]::IsNullOrWhiteSpace($OfficialInfPath) -and
        [string]::IsNullOrWhiteSpace($OfficialDatPath)
    ){'STATIC_PACKAGE_PREFLIGHT'}else{'EXACT_SOURCE_REBUILD_PREFLIGHT'}
    Write-Host ("[INFO] PREFLIGHT_SOURCE_MODE :: {0}" -f $SourceMode)

    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @PreflightArgs
    if($LASTEXITCODE -ne 0){throw "Public Beta v5.0 preflight failed with exit code $LASTEXITCODE. Result=$ResultPath"}
    if(-not(Test-Path -LiteralPath $ResultPath -PathType Leaf)){throw 'Public Beta v5.0 preflight result is missing.'}
    $Contract=Get-Content -LiteralPath $ResultPath -Raw|ConvertFrom-Json
    if([string]$Contract.Schema -cne $Schema -or -not[bool]$Contract.Passed -or [int]$Contract.FailedChecks -ne 0){throw 'Public Beta v5.0 preflight result contract failed.'}
    Remove-Item -LiteralPath $ResultPath -Force -ErrorAction SilentlyContinue
    Write-Host '[PASS] PUBLIC_V5_0_PREFLIGHT :: package is exact and the four exact supported profiles are mutation-enabled.' -ForegroundColor Green
    if($GateOnly){
        Write-Host '[PASS] ENTRY_GATE_ONLY_COMPLETE :: launcher was not started.' -ForegroundColor Green
        Write-Host ("[EVIDENCE] {0}" -f $Evidence) -ForegroundColor Yellow
        Stop-EntryTranscript
        exit 0
    }
    Stop-EntryTranscript
    Remove-Item -LiteralPath $Evidence -Force -ErrorAction SilentlyContinue
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Launcher
    exit $LASTEXITCODE
}
catch{
    Stop-EntryTranscript
    Write-Host ("[BLOCKED] {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ("[EVIDENCE] {0}" -f $Evidence) -ForegroundColor Yellow
    Write-Host '[BLOCKED] Launcher was not started by this entry gate.' -ForegroundColor Red
    exit 1
}
