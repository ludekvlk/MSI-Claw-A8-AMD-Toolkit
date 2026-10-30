Read README.md for the full MSI Claw A8 beginner guide.

Installation: Start-MSI-Claw-A8-AMD-26.10.1.cmd
Read-only device check: Check-Compatibility.cmd
Exact MSI profile: PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C5

This MSI adaptation derives from DontDoMuch's Legion Go toolkit through
ryanoceros94's AMD 26.10.1 release. NOTICE.md records the exact source and credits.
It uses AMD Strix defaults without Lenovo OEM registry/display overrides or
Lenovo extension cleanup on the MSI profile.

Keep Internal and every supplied runtime file. Download AMD's full 26.10.1
installer separately; no driver binaries are bundled in this source tree.
Use only the main start shortcut after completing the security preparation.

One MSI device has a saved 51/51 successful audit from 2026-10-29. The prepared
source changes have read-only validation and have not been physically reinstalled.
Matching hardware does not guarantee all power/display/game behavior.

Secure Boot must stay disabled with the local signer. Preserve your encryption
recovery key, explicitly suspend protection before boot changes, and resume it
after success. Test Signing and nointegritychecks must finish OFF.
See README.md for complete steps, troubleshooting and recovery limitations.
