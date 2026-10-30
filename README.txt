MSI Claw A8 Z2 Extreme - AMD 26.10.1 community toolkit

Read README.md for the complete beginner guide, source credits and limitations.
Start with Check-Compatibility.cmd for a read-only hardware/OS check.
Install using Start-MSI-Claw-A8-AMD-26.10.1.cmd after following the preparation steps.

Download AMD's full 26.10.1 installer separately from AMD. Keep the original
whql-amd-software-adrenalin-edition-26.10.1-win11-c.exe under your Downloads folder.
Keep the project's supplied files and Internal folder together.

Exact MSI target: PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C5
Windows 11 x64; administrator rights; AC power; Secure Boot disabled.
Preserve your encryption recovery key and suspend BitLocker protection before
firmware/boot changes. The toolkit does not suspend protection automatically.
Sign in to the same Windows account after each required reboot.

Secure Boot must remain disabled for this local signer. Test Signing is temporary
and must finish OFF; nointegritychecks must finish OFF. Resume BitLocker protection
after the complete workflow succeeds. Do not delete rollback/state during a failure.

Community beta: one MSI device has a saved successful 51/51 final audit dated
2026-10-29. Other hardware revisions and Windows/security configurations are not
universally validated. The source preparation itself has not been reinstalled.
See docs/REVIEW.md and NOTICE.md. Original MIT license is in LICENSE.
