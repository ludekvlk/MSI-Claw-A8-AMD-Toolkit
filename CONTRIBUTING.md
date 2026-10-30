# Working on this source

Use Windows PowerShell 5.1 on Windows. Normal installation uses the MSI start shortcut; the commands below are for source validation only.

## Checks that do not install a driver

From the repository's root folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Preflight-AMD-26.10.1-Public-Beta-v5.0.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Internal\Test-MsiClawA8.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Internal\Test-BootSafety.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Internal\Test-RecoveryRearm.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Internal\Test-BcdBooleanOutput.ps1
```

Each command must succeed. The static preflight does not check live boot readiness or prove that the driver will load. Fixture tests replace selected system queries with sample data and must run in separate PowerShell processes, as above. The GitHub workflow runs this same group, without downloading or installing the AMD driver.

On a matching MSI device you can also run `Check-Compatibility.cmd`. The optional existing Driver Store regression script performs read-only live lookups and needs an AMD GPU; it is not suitable for the generic hosted CI runner:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Internal\Test-DriverStoreQueries.ps1
```

The `-LiveInventory` option also tests full inventory on the local machine and may require elevation. Neither path installs or removes a driver.

## Exact-source rebuild

If you already have the exact AMD source extracted, supply both paths. This creates temporary candidate INF/DAT files, verifies all four profiles and then removes those temporary outputs. It does not sign or install a driver. The example paths are the AMD extraction layout on the reviewed machine; adjust them to your own extraction:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Preflight-AMD-26.10.1-Public-Beta-v5.0.ps1 -OfficialInfPath 'C:\AMD\AMD-Software-Installer\Packages\Drivers\Display\WT6A_INF\u0205306.inf' -OfficialDatPath 'C:\AMD\AMD-Software-Installer\Packages\Drivers\Display\WT6A_INF\B026676\amdgcf.dat'
```

No AMD binaries should be committed. The source inputs must match:

| File | SHA-256 |
| --- | --- |
| Official `u0205306.inf` | `884C91EF4681D3E383B48DC760B4B2A95C95281E5796686A99A40B44FF65EE9D` |
| Official `amdgcf.dat` | `289B143A466FD08102BEB72210988BED37792E1762BB863F9B85916D8F7CE8D9` |
| Built MSI INF | `B279B6972A93D5ECA2D8D40F160F60D4B69206E3BC0DD1AC9A7BEB9CFA890C7E` |
| Built MSI DAT | `CDF57D74268F3CB763A996C16811CCB26F4055750743EEB68D03D8D686A2EC02` |

After intended runtime edits, run `tools\Update-PackageManifest.ps1`, then rerun the checks. Review why hashes changed before accepting them. Preserve exact bytes/encoding in frozen source data. Do not rename legacy schema identifiers independently of their readers.

## Adding support

Do not broaden the MSI profile to a device-ID-only match. A new subsystem or revision needs its own exact hardware evidence, reviewed OEM behavior, deterministic source outputs, rollback checks and physical post-reboot verification. Updating one JSON hardware ID is not sufficient: builders and preflight fixtures also freeze the allowed identities.

Record a physical test separately from a source test. Include Windows build/language, firmware, starting driver, Secure Boot, encryption protection, HVCI/code-integrity configuration, all reboot boundaries, final audit, and display/power behavior. Keep public test summaries free of personal paths and recovery information.
