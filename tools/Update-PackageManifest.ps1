#requires -Version 5.1
# Maintainer tool: refresh byte identities only after reviewing intended changes.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Files = @(
    Get-ChildItem -LiteralPath $Root -File | Where-Object {
        $_.Extension -in @('.ps1','.cmd','.txt') -or $_.Name -eq 'PUBLIC-RELEASE-SCOPE.json'
    }
    Get-ChildItem -LiteralPath (Join-Path $Root 'Internal') -File -Recurse
)
$Rows = @(foreach ($File in @($Files | Sort-Object FullName)) {
    [ordered]@{
        Path = $File.FullName.Substring($Root.Length + 1)
        Length = [int64]$File.Length
        SHA256 = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
    }
})
$Json = $Rows | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $Root 'PACKAGE-MANIFEST.json'), ($Json + "`r`n"), (New-Object Text.UTF8Encoding($false)))
Write-Output ("Updated PACKAGE-MANIFEST.json: {0} files. Run preflight before distributing." -f $Rows.Count)
