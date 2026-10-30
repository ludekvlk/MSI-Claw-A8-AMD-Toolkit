#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CanonicalNode {
    [CmdletBinding()]
    param([Parameter(Mandatory=$false)]$InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [string] -or $InputObject -is [char] -or $InputObject -is [bool] -or $InputObject -is [ValueType]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $Result = [ordered]@{}
        foreach ($Key in @($InputObject.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
            $Result[$Key] = ConvertTo-CanonicalNode -InputObject $InputObject[$Key]
        }
        return $Result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $Items = @()
        foreach ($Item in $InputObject) {
            $Items += ,(ConvertTo-CanonicalNode -InputObject $Item)
        }
        return $Items
    }

    $ObjectResult = [ordered]@{}
    foreach ($Property in @($InputObject.PSObject.Properties | Sort-Object Name -CaseSensitive)) {
        if ($Property.MemberType -in @('NoteProperty','Property','AliasProperty','ScriptProperty')) {
            $ObjectResult[$Property.Name] = ConvertTo-CanonicalNode -InputObject $Property.Value
        }
    }
    return $ObjectResult
}

function Get-CanonicalObjectJson {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$InputObject)

    $Canonical = ConvertTo-CanonicalNode -InputObject $InputObject
    return ($Canonical | ConvertTo-Json -Depth 100 -Compress)
}

function Get-ObjectFingerprint {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$InputObject)

    $Json = Get-CanonicalObjectJson -InputObject $InputObject
    $Utf8 = New-Object Text.UTF8Encoding($false)
    [byte[]]$Bytes = $Utf8.GetBytes($Json)
    $Sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace('-','')
    }
    finally {
        $Sha.Dispose()
    }
}

function Assert-LegionGoProfileSchema {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Profile)

    if ([int]$Profile.SchemaVersion -ne 1) { throw "Unsupported profile SchemaVersion: $($Profile.SchemaVersion)" }
    if ([string]::IsNullOrWhiteSpace([string]$Profile.Id)) { throw 'Profile Id is required.' }
    if ([string]::IsNullOrWhiteSpace([string]$Profile.DisplayName)) { throw "Profile $($Profile.Id) DisplayName is required." }

    $Exact = [string]$Profile.Hardware.ExactHardwareId
    $Prefix = [string]$Profile.Hardware.HardwarePrefix
    $ExactPattern = '^PCI\\VEN_[0-9A-F]{4}&DEV_[0-9A-F]{4}&SUBSYS_[0-9A-F]{8}&REV_[0-9A-F]{2}$'
    if ($Exact -cnotmatch $ExactPattern) {
        throw "Profile $($Profile.Id) exact HWID is invalid or not uppercase-normalized: $Exact"
    }
    if ($Prefix -cne ($Exact -replace '&REV_[0-9A-F]{2}$','')) {
        throw "Profile $($Profile.Id) HardwarePrefix does not match ExactHardwareId."
    }
    if ($Exact -notmatch '&SUBSYS_[0-9A-F]{8}&REV_[0-9A-F]{2}$') {
        throw "Profile $($Profile.Id) DEV-only targeting is forbidden."
    }

    $Family = [string]$Profile.Amd.Family
    if ($Family -notin @('Phoenix','Strix')) {
        throw "Profile $($Profile.Id) AMD family is not allowlisted: $Family"
    }
    if ([string]::IsNullOrWhiteSpace([string]$Profile.Amd.BaseInstallSection)) {
        throw "Profile $($Profile.Id) BaseInstallSection is required."
    }
    if ([string]::IsNullOrWhiteSpace([string]$Profile.Amd.DedicatedInstallSection)) {
        throw "Profile $($Profile.Id) DedicatedInstallSection is required."
    }
    if ([string]$Profile.Lenovo.ExtensionId -cne '{07A2A561-D001-4503-B239-EF2FE0379EFB}') {
        throw "Profile $($Profile.Id) Lenovo ExtensionId is unexpected."
    }

    if ([bool]$Profile.InstallCapable) {
        if ($null -eq $Profile.Final) {
            throw "InstallCapable profile requires exact final INF/DAT SHA256 values: $($Profile.Id)"
        }
        foreach ($Name in @('ExpectedInfSHA256','ExpectedDatSHA256')) {
            $Hash = [string]$Profile.Final.$Name
            if ($Hash -cnotmatch '^[0-9A-F]{64}$') {
                throw "InstallCapable profile requires exact final INF/DAT SHA256 values: $($Profile.Id) $Name"
            }
        }
    }
}

function Get-LegionGoProfiles {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ProfileRoot)

    if (-not (Test-Path -LiteralPath $ProfileRoot -PathType Container)) {
        throw "Profile root not found: $ProfileRoot"
    }

    $Profiles = @()
    foreach ($File in @(Get-ChildItem -LiteralPath $ProfileRoot -Filter '*.json' -File | Sort-Object Name)) {
        $Profile = Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json
        Assert-LegionGoProfileSchema -Profile $Profile
        $Fingerprint = Get-ObjectFingerprint -InputObject $Profile
        $Profile | Add-Member -NotePropertyName Fingerprint -NotePropertyValue $Fingerprint -Force
        $Profile | Add-Member -NotePropertyName SourcePath -NotePropertyValue $File.FullName -Force
        $Profiles += ,$Profile
    }

    if ($Profiles.Count -eq 0) { throw "No profiles found under: $ProfileRoot" }

    $DuplicateIds = @($Profiles | Group-Object Id | Where-Object Count -gt 1)
    if ($DuplicateIds.Count -gt 0) { throw "Duplicate profile Id(s): $($DuplicateIds.Name -join ', ')" }

    $DuplicateHwids = @($Profiles | Group-Object { $_.Hardware.ExactHardwareId } | Where-Object Count -gt 1)
    if ($DuplicateHwids.Count -gt 0) { throw "Duplicate exact profile HWID(s): $($DuplicateHwids.Name -join ', ')" }

    $DuplicateSections = @($Profiles | Group-Object { $_.Amd.DedicatedInstallSection } | Where-Object Count -gt 1)
    if ($DuplicateSections.Count -gt 0) { throw "Duplicate dedicated DDInstall section(s): $($DuplicateSections.Name -join ', ')" }

    return $Profiles
}

function Resolve-LegionGoProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object[]]$Profiles,
        [Parameter(Mandatory=$true)][string[]]$InstanceIds
    )

    $NormalizedInstanceIds = @(
        $InstanceIds |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { ([string]$_).Trim().ToUpperInvariant() }
    )

    $Matches = New-Object 'System.Collections.Generic.List[object]'
    foreach ($Profile in $Profiles) {
        foreach ($InstanceId in $NormalizedInstanceIds) {
            if ($InstanceId -ceq $Profile.Hardware.ExactHardwareId) {
                $Matches.Add($Profile) | Out-Null
                break
            }
        }
    }

    if ($Matches.Count -ne 1) {
        $Ids = @($Matches | ForEach-Object { $_.Id })
        throw "Expected exactly one supported target. MatchCount=$($Matches.Count) Matches=$($Ids -join ',')"
    }

    return $Matches[0]
}
