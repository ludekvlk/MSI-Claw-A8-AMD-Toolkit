# Source review and compatibility assessment

Prepared **30 October 2026**. This report separates saved evidence from the working installation and read-only checks of the prepared source. No driver installation, certificate import, boot-setting change or restart was performed during this review.

## Conclusion

The source is suitable to share as a **community beta for the exact MSI Claw A8 Z2 Extreme hardware profile**, with the original MIT license and credits included. It is not evidence of support for every device sold as a Claw A8. The current MSI profile intentionally rejects different subsystem IDs and revisions. No broader hardware match should be added merely to advertise wider support.

For another device with the same complete graphics ID, the code does not depend on the original user's account name or graphics device instance suffix. It discovers the physical device and active driver at runtime. That makes another matching device a reasonable candidate, subject to the documented Windows, firmware, encryption, toolchain and signing requirements. It does not prove that a fresh installation or all OEM functions will succeed there.

## What was reviewed

- The public entry gate, main launcher and all four numbered stages.
- The shared profile resolver, release contract, source builders and frozen hashes.
- MSI routing through origin classification and the exclusions from Lenovo OEM settings/extension cleanup.
- Local certificate/catalog handling, temporary signing changes, rollback checkpoints, resume tasks, final audit, and dependency/installer discovery.
- Package manifests, existing reports and read-only regression scripts.
- Original download provenance, upstream repository/license, distribution contents and Git byte preservation.

This is a targeted source/distribution review and regression check, not an exhaustive security audit or a multi-device certification.

## Physical evidence already present

The working installation's saved final audit from **29 October 2026** identifies `MsiClawA8-Z2Extreme` and reports:

| Item | Saved result |
| --- | --- |
| Final checks | 51 passed |
| Failed checks / warnings | 0 / 0 |
| Display driver | 32.0.32015.7029 |
| Test Signing | OFF |
| nointegritychecks | OFF |
| Secure Boot | Disabled |

The stage 4 result records `Passed`, exit code 0. The audit was captured at the `SoftwareComplete` checkpoint, before the launcher would mark overall completion. It demonstrates the final audit's pass at that point; this report does not invent a later state transition or a new installation run. Personal evidence files are deliberately excluded from the published source.

The original MSI text README said physical installation had not been validated. That was stale relative to the later saved audit and has been replaced with the narrower, dated evidence above. Original Lenovo validation statements also mixed 26.9.2 lineage with 26.10.1 wording. This source does not claim physical 26.10.1 validation on those Lenovo models.

## Checks of the prepared source

Executed locally using Windows PowerShell 5.1 on 30 October 2026:

| Check | Result and scope |
| --- | --- |
| Full source preflight | 51 checks, zero failures; exact official INF/DAT inputs |
| All four deterministic builds | INF and DAT hashes match each profile's frozen expected outputs |
| All four model bindings | Complete expected HWID maps to the dedicated install section |
| MSI routing regression | Exact selection; wrong revision/subsystem, incomplete ID and ambiguity rejected; unhealthy GPU rejected; no Lenovo cleanup |
| Boot-safety fixtures | Protection-off accepted; active/unknown protection, missing volume and failed status queries blocked |
| Recovery re-arm fixtures | Requires proven rollback, a later boot and Test Signing before consuming recovery markers |
| BCD boolean fixtures | 30 cases; recognized true/false, absent options, localized/unknown values, empty values and duplicate rows |
| Driver Store regression | Bounded retries, no partial results, exact live INF/catalog lookup, invalid names rejected; default read-only mode |
| New compatibility helper | Found the exact MSI hardware ID on Windows 11 Home, build 26300 |
| Public entry gate, `-GateOnly` | Manifest 33/33, 20 PowerShell files parsed, static preflight 37/37; installation launcher not started |
| Git checkout round trip | All 45 source files retained byte-for-byte with `core.autocrlf=true`; dot files and maintainer tool included |
| Distribution inspection | Relative Markdown links resolve; no bundled binary/certificate payload or personal repair shortcut; no original user paths or temporary signed asset URLs found |

The static preflight without source inputs has 37 checks; it skips deterministic rebuilds and is what normal entry/CI checks use. The final installed-device audit also has 51 checks for MSI, but it is a different test from the 51-check source rebuild. These counts must not be confused.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for reproducible commands. This source preparation did not retest actual installation, driver binding, certificate creation, dependency downloads or post-reboot persistence. The GitHub workflow is supplied for future uploads; a hosted GitHub run is not claimed before publication.

## Changes made for sharing

| Issue found | Prepared-source action |
| --- | --- |
| Personal repair shortcut referenced a missing external script in a user-specific folder | Excluded `Apply-Installer-Fix.cmd` from distribution and regenerated the manifest |
| Approximately 1.78 GB AMD installer in the working folder | Excluded it; documented a separate official AMD download |
| Personal preflight reports in the working folder | Excluded them; published this redacted summary instead |
| Missing license/credit in the extracted package | Verified both upstream MIT notices, included LICENSE and traced the exact starting asset in NOTICE.md |
| Old required-installer name and 26.9.2 checksum in public scope | Updated the public download name; aligned installer verification metadata to runtime `DYNAMIC` behavior |
| Stale/no-install MSI validation statement and contradictory Lenovo physical claims | Replaced the text guides and clarified dated MSI evidence and Lenovo source-only scope |
| Git may normalize line endings and break runtime SHA-256 checks | Added `.gitattributes` to preserve runtime bytes |
| English-only `Yes` detection treated all unrecognized values as false | Added explicit parsing: only recognized values are accepted; unfamiliar/localized, empty and duplicate values stop the workflow |
| New users had to open Device Manager or start installation to check targeting | Added a read-only compatibility shortcut and script |
| Future edits need consistent integrity metadata | Added a manifest-refresh tool, source-only CI and contribution instructions |

The original working scripts, installed driver, ProgramData workflow and source AMD installer were left intact. Changes exist in the separate prepared source tree. Frozen hardware profiles, source INF/DAT hashes, driver builders, driver target version and release-contract fingerprint were preserved.

## Compatibility boundaries and remaining work

1. **Hardware revisions:** only `PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C5` is the MSI target. Another subsystem or revision needs new evidence, builder/profile fixtures and physical testing. Memory or SSD size is not consulted by selection, but that does not establish that every regional SKU uses the same hardware ID.
2. **Windows security configurations:** Secure Boot must be disabled. BitLocker protection must be deliberately suspended before required firmware/boot changes, then resumed after success. HVCI/Memory Integrity, WDAC, enterprise policy and fresh Windows code-integrity states have not been comprehensively tested. Local catalog trust plus official AMD binary/catalog checks are not the same as Microsoft signing the modified MSI package.
3. **Languages:** BCD output parsing recognizes explicit English/boolean values. Unknown localized values now block. Other Windows languages are not claimed supported without live validation; localized Inf2Cat output is also unvalidated. A future language-independent BCD API implementation would need its own tests.
4. **Windows layout:** this workflow retains the existing `C:\ProgramData` state root and searches `$env:USERPROFILE\Downloads`. Nonstandard Windows drive layouts and redirected Downloads folders are unvalidated. Putting the AMD installer beside the extracted toolkit avoids relying on a redirected Downloads search. Changing the state root requires a deliberate migration plan.
5. **Initial driver state:** the MSI origin path accepts healthy AMD display origins and Microsoft Basic Display recovery origins. It rejects unhealthy/ambiguous states. Testing one successful local install does not prove every OEM-driver starting state or damaged system can recover.
6. **AMD source revisions:** installer discovery searches names containing `26.10.1`. The installer must be AMD Authenticode-valid; the extracted INF/DAT must match exact pinned hashes, and final output hashes must match. Whole-installer, kernel and some companion identities are captured dynamically during the trusted-source workflow, rather than being independently pinned as one release-wide executable checksum. Do not substitute another release or represent all these files as statically pinned.
7. **Dependencies:** exact Microsoft NuGet packages/tools are pinned, but this review did not exercise downloading them on a clean machine. The code allows one pinned Inf2Cat binary's `UnknownError` Authenticode status only with its hash, architecture and expected Microsoft signer/product identity; this existing exception was retained, not generalized.
8. **OEM behavior:** brightness, screen modes/VRR, sleep/wake, battery/power behavior, docking, external displays, video functions and games need testing on additional devices. MSI extensions being preserved does not prove every MSI feature works with this AMD build. FSR options or performance improvements are not guaranteed by successful installation.
9. **Updates and rollback:** no comprehensive uninstall/cleanup tool is included. Rollback attempts restore captured driver material, not every software/system change. Windows Update or a later AMD/OEM install can replace the driver; no permanent protection from that is promised.
10. **Existing workflows:** the legacy release/workflow/schema identifiers are intentionally retained so readers stay consistent. Existing installs use their persistent toolkit copy. Do not drop new scripts into an unfinished transaction; finish or recover it with its matching files. The persistent-copy routine copies the package directory, so run from a clean extracted source copy and keep large installers separately in Downloads, rather than running from a checkout containing `.git` and generated files.

The release contract's legacy `InstallerName` is informational; the actual discovery code searches `*26.10.1*.exe`. It was retained to avoid changing an established fingerprint solely for a file-name correction. The README and public scope give the current official download name. Similarly, old `26.9.2` schema/report strings were not globally renamed: doing so requires coordinated changes to every reader and any resume/recovery compatibility policy.

Recommended next validation is a clean installation of this exact prepared source on another matching MSI device, followed by every reboot boundary, final audit and real display/power checks. That is additional compatibility evidence, not a reason to bypass the existing exact-hardware checks.
