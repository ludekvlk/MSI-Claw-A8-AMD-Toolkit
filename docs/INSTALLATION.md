# MSI Claw A8 Z2 Extreme — AMD 26.10.1 community toolkit

Install AMD Software: Adrenalin Edition **26.10.1** on an MSI Claw A8 BZ2EM with a matching Ryzen Z2 Extreme graphics device.

**Current release: [Community Beta 1 — v1.0.0-beta.1](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/tag/v1.0.0-beta.1)** · [Download toolkit ZIP](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/download/v1.0.0-beta.1/MSI-Claw-A8-AMD-26.10.1-GitHub-Source.zip) · [Download checksum](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/download/v1.0.0-beta.1/MSI-Claw-A8-AMD-26.10.1-GitHub-Source.zip.sha256)

You need **two downloads**: this small toolkit ZIP and AMD's full 26.10.1 installer. The AMD driver download is separate; follow Step 2 below.

This is a community adaptation of the Legion Go driver toolkit. It takes the official AMD download, prepares a package for the exact MSI graphics device, signs that package locally, installs it, and checks the result after restarting Windows.

**Status: community beta.** One local MSI Claw A8 installation has a saved successful final audit from **29 October 2026: 51 checks passed, no failures or warnings**. This source preparation adds documentation, packaging and a boot-output safety fix; it has passed read-only checks but has not been installed again. Success on one device does not guarantee success on every Claw A8 or every Windows setup. See [the review and validation limits](REVIEW.md).

[GitHub's read-only source validation passed](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/actions/runs/41096126927) for the released commit. This checks package integrity and safety fixtures; it does not install a driver on a physical Claw A8.

**Read the preparation steps before starting.** The toolkit changes the graphics driver, certificate trust and boot settings, and restarts Windows several times. Secure Boot must be disabled and remain disabled while using this locally signed configuration. Windows Test Signing is temporary and must finish OFF. Save your work and keep your encryption recovery key somewhere you can access without this device.

This is not an official MSI, AMD or Lenovo release. AMD's standard driver package does not officially support handheld gaming devices; MSI's own driver remains the supported recovery option. [AMD release notes](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-10-1.html), [MSI support](https://www.msi.com/Handheld/Claw-A8-BZ2EMX/support).

## Where this project comes from

The original work is [DontDoMuch/LeGo1-graphic-driver-toolkit](https://github.com/DontDoMuch/LeGo1-graphic-driver-toolkit). It provides the build, signing, installation, rollback and restart/resume workflow for specific Lenovo Legion Go devices.

The AMD 26.10.1 starting package came from [ryanoceros94/LeGo2-Adrenalin26.10.1, release public-beta-v5.0.1-26.10.1](https://github.com/ryanoceros94/LeGo2-Adrenalin26.10.1/releases/tag/public-beta-v5.0.1-26.10.1). The original downloaded ZIP's metadata and checksum identify that release. This adaptation adds an exact MSI Claw A8 profile and MSI routing to that shared workflow, together with local recovery and boot-safety fixes.

The MSI profile uses AMD's **Strix** driver settings. It does not add Lenovo brightness values, screen modes or Lenovo-specific registry settings. MSI's existing OEM extensions are excluded from the Lenovo extension cleanup path. The AMD INF file (the installation instructions) and `amdgcf.dat` (a driver data file) are adapted for this device; AMD's driver binaries are copied from the official download.

Many file names and progress messages still say `LegionGo`, `v5.0`, or even `26.9.2`. Those names come from the shared workflow and some internal report formats. They do not mean that a Lenovo driver profile is chosen on an MSI. Selection is automatic from the device's full hardware ID. The target display driver here is **32.0.32015.7029 / AMD 26.10.1**.

Both upstream projects use the MIT license. Their original copyright and license are preserved in [LICENSE](../LICENSE). See [credits and source details](../NOTICE.md).

## Will it work on my Claw A8?

The MSI profile accepts exactly this graphics hardware ID:

```text
PCI\VEN_1002&DEV_150E&SUBSYS_14AF1462&REV_C5
```

In simple terms, that is the device's full identification number. The model name or the words "Z2 Extreme" alone are not enough.

| Device or setup | Status |
| --- | --- |
| MSI Claw A8 BZ2EM, full ID shown above, Windows 11 x64 | Intended MSI target; one local successful audit |
| Another region, colour or storage size | May work if the full graphics ID matches; not separately verified |
| Different `SUBSYS` or `REV` value | Rejected; needs a separately reviewed profile |
| Intel-based MSI Claw, Claw 7 AI+, Claw 8 AI+ | Outside this MSI AMD profile |
| Another Z2 Extreme handheld | Not covered by the MSI profile |
| Windows 10, Linux or SteamOS | Outside this MSI release's validation scope |
| Secure Boot enabled | Installation blocked |
| Active BitLocker protection, or unreadable encryption status | Installation blocked before boot changes |

The original three Lenovo profiles are retained for compatibility with the inherited code. Their presence is not a claim that this MSI adaptation has physically tested those devices on 26.10.1.

### Check your device without installing anything

After downloading and extracting this project, double-click **`Check-Compatibility.cmd`**. It checks the MSI graphics ID and Windows version. It does not install anything or change settings. A pass means the hardware and OS match; the installer still has more checks to do.

You can also check manually:

1. Right-click the Windows Start button and select **Device Manager**.
2. Open **Display adapters**.
3. Double-click the built-in AMD graphics adapter, then open **Details**.
4. In **Property**, choose **Hardware Ids**.
5. Compare the complete line, including `SUBSYS_14AF1462` and `REV_C5`, with the line above.

If it differs, stop. Do not edit the profile or remove checks to force installation.

## What you need

- A matching MSI Claw A8 Z2 Extreme running Windows 11 x64.
- An administrator account and the device connected to its charger.
- A normal Windows layout with `C:\ProgramData`; nonstandard drive layouts are unvalidated. The automatic download search uses your user profile's `Downloads` path, so put the AMD installer beside the toolkit if Downloads has been redirected.
- Internet for dependency downloads, unless the exact required tools are already cached.
- The project folder and AMD's full **26.10.1** driver installer, downloaded separately.
- Enough free space on the Windows drive for the large AMD download, extraction, a working driver package and rollback copies. Allow several GB; there is no measured universal minimum.
- Your BitLocker or Device Encryption recovery key, if encryption is used.
- Time to leave the device alone through several restarts. Allow roughly 30–60 minutes; download speed and Windows setup affect the time.

Use the built-in **Windows PowerShell 5.1**. The `.cmd` shortcuts select it automatically. PowerShell 7 is not the intended launcher.

## Step 1 — Download this project and extract it

Open the [Community Beta 1 release page](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/tag/v1.0.0-beta.1). Under **Assets**, download **`MSI-Claw-A8-AMD-26.10.1-GitHub-Source.zip`**. You can also use the [direct toolkit ZIP download](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/download/v1.0.0-beta.1/MSI-Claw-A8-AMD-26.10.1-GitHub-Source.zip).

The attached toolkit ZIP is the packaged version checked for this release. GitHub also lists automatically generated **Source code** archives. Those contain the tagged repository snapshot; the named toolkit ZIP is the simplest download to follow with this guide. **Code → Download ZIP** on the repository page downloads the current branch, which may include later changes.

1. Save the ZIP in **Downloads**.
2. Right-click the ZIP and choose **Properties**. If Windows shows **Unblock**, tick it and select **Apply** after checking that you trust the download.
3. Right-click the ZIP and choose **Extract All**.
4. Open the extracted folder. You should see `Start-MSI-Claw-A8-AMD-26.10.1.cmd` and an `Internal` folder.

You may rename the outer folder to something simple, such as `MSI-Claw-A8-AMD-26.10.1`. Keep all files and the `Internal` folder together. Do not run from inside the ZIP or move individual scripts into another folder.

The release includes a `.sha256` file for checking the named toolkit ZIP. Its SHA-256 is:

```text
98A5DE0C41F018FC24EFCCCD45F0F6F61796000D2167123E8742E3EC0D4E9CCE
```

This checksum applies to the attached **Community Beta 1 toolkit ZIP**, not AMD's installer or GitHub's generated source archives.

## Step 2 — Download the official AMD 26.10.1 installer

Open [AMD's official 26.10.1 release page](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-10-1.html). Find the section with the driver download and choose the full package for RDNA graphics.

The download linked by AMD when this source was prepared is:

```text
whql-amd-software-adrenalin-edition-26.10.1-win11-c.exe
```

Keep the original file name. Put the file in your **Downloads** folder, beside the extracted project folder. The project also searches inside its own folder and recursively under your normal user Downloads folder.

```text
Downloads
├── whql-amd-software-adrenalin-edition-26.10.1-win11-c.exe
└── MSI-Claw-A8-AMD-26.10.1
    ├── Start-MSI-Claw-A8-AMD-26.10.1.cmd
    ├── Check-Compatibility.cmd
    ├── README.md
    └── Internal
        └── ...keep every supplied file here...
```

You do not need to run the AMD installer yourself or manually extract an AMD folder. The toolkit extracts it using 7-Zip. Do not substitute AMD Auto-Detect, a chipset installer, an OEM driver ZIP, or a newer Adrenalin version. A file with "26.10.1" in its name still has to pass the AMD signature and exact extracted-source checks. Renaming another download will not make it compatible.

The AMD installer is not part of this GitHub source. AMD may revise or replace downloads; if the exact source checks fail, stop and report the mismatch rather than bypassing them. If a direct download gives an AMD download error, use the download button on AMD's release page in your browser.

## Step 3 — Prepare encryption and Secure Boot

**Do this before starting installation or changing firmware settings.**

1. Save your files and close games and applications.
2. If BitLocker or Device Encryption is enabled, confirm that you can access the recovery key from another device or an offline copy. Do not post it on GitHub.
3. Deliberately suspend protection before changing Secure Boot or allowing the installation's boot changes. This means pausing protection, not decrypting the whole drive. Use Windows' BitLocker controls and Microsoft's guidance for your Windows edition. Automatic resumption can happen after a restart; protection must still be suspended at each required boot-change check. If your Windows edition does not provide a suitable control, stop and get help rather than bypassing the check. [Microsoft BitLocker guidance](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/operations-guide).
4. Disable **Secure Boot** in UEFI firmware. A usual route is **Settings → System → Recovery → Advanced startup → Restart now**, then **Troubleshoot → Advanced options → UEFI Firmware Settings**. Exact firmware menus vary; use MSI's instructions for your model.
5. Start Windows normally and keep the charger connected.

The toolkit does not retrieve recovery keys, suspend encryption or change firmware settings for you. It stops if encryption protection is active or its state cannot be determined.

**Secure Boot and Test Signing are different settings.** This workflow requires Secure Boot to stay disabled with its local signer. It turns Windows Test Signing on temporarily and then off again. Do not follow advice for a different fork that says to re-enable Secure Boot immediately afterward: this package's final audit specifically requires it disabled. Some games or security policies may require Secure Boot; this configuration may be unsuitable for those uses.

## Step 4 — Start the installer

1. Open the extracted project folder.
2. Double-click **`Start-MSI-Claw-A8-AMD-26.10.1.cmd`**.
3. Accept the Windows administrator prompt after checking that it is the script you intended to run. This source script is not publisher-signed; the AMD installer is checked separately.
4. Read the selected device and the messages on screen.
5. Answer the two initial installation/restart confirmations only when ready. They authorize the remaining installation stages and the required automatic restarts.

The toolkit checks its supplied files before starting the installation. It can install 7-Zip x64 through WinGet if needed. It also downloads exact Microsoft signing tools from NuGet. These downloads are checked against pinned hashes. A full Windows SDK/WDK installation is not normally needed. If WinGet is unavailable, install [7-Zip x64 from its official website](https://www.7-zip.org/download.html) first, then try again.

Do not run the numbered scripts yourself. The main launcher chooses the correct step and handles saved progress.

## Step 5 — Let it restart and continue

The workflow runs these steps:

1. **Build and sign:** extract the official AMD source and create the exact MSI package and a local signing certificate.
2. **Temporary Test Signing restart:** restart into the mode used to install the locally signed package.
3. **Install and verify:** save rollback material, bind the package to the matching device, and arrange the return to normal signing.
4. **Normal-signing restart:** check that the installed driver loads with Test Signing off.
5. **AMD Software and final checks:** install/repair matching AMD Software components if needed, restart if required, and run the final persistence audit.

The screen can flicker while the graphics driver changes. Downloading, hashing and building can take several minutes. Avoid shutting down, closing the installer window or starting a second copy during a transaction.

After each restart, sign back in with the **same Windows account**. A saved scheduled task resumes the workflow at the next sign-in. If it does not resume, open the same MSI start shortcut once and read its status. If it reports an error, stop and preserve the evidence; repeated forced retries are not a repair method.

## Step 6 — Check the result

Wait for the final success report. A working desktop alone does not mean every stage passed.

Expected results include:

- The MSI profile is selected and the GPU has no Device Manager error.
- The display driver version is **32.0.32015.7029**.
- Windows Test Signing is **OFF**.
- `nointegritychecks` is **OFF**.
- Secure Boot is still **disabled**, as required by this local-signing configuration.
- The final audit passes. The MSI profile normally has **51** checks.

For a manual version check, open **Device Manager → Display adapters → AMD graphics → Properties → Driver**. AMD Software should also open normally.

After the complete workflow succeeds, resume BitLocker protection if you suspended it and verify its status in Windows. It is not automatically resumed by the toolkit. Keep the recovery key available because a changed boot configuration can still require it.

Try your usual games, brightness adjustment, refresh-rate changes, VRR, sleep/wake, battery and AC use, and any external monitor or dock. Those functions need real use testing; the installation audit cannot prove every game or power/display feature works.

The workflow keeps state, logs, its persistent toolkit and rollback references under:

```text
C:\ProgramData\LegionGo-AMD-26.10.1-MultiDevice-v5.0\MsiClawA8-Z2Extreme
```

Build/source and rollback data also use the Windows drive's `AMD` folder. Final and failure evidence is written under Downloads. Some report names still contain `26.9.2` because the internal format is inherited. Do not delete these folders while installation is incomplete or a problem is being investigated.

## Common problems

| Message or symptom | What to do |
| --- | --- |
| Unsupported hardware or no exact match | Check the full hardware ID. Do not change the profile to force it. |
| AMD installer not found | Put the full original 26.10.1 `.exe` under your user Downloads folder. Enable File Explorer file-name extensions if needed. |
| AMD signature or source/hash mismatch | Stop. Check the AMD version and download source. A later AMD package revision may need a new reviewed release. |
| Package manifest mismatch | Extract a fresh copy. Editing runtime files or changing their line endings invalidates the checksum. |
| Secure Boot enabled or unknown | Follow the preparation steps. A static source preflight does not check firmware readiness. |
| BitLocker active or status unavailable | Confirm recovery-key access and resolve protection/status using Windows controls. Do not remove the safety check. |
| Unrecognized BCD value / Windows language | This source now stops on unfamiliar boot-setting output. Localized Windows output needs a reviewed implementation/test; it must not be guessed as OFF. |
| 7-Zip or signing-tool download fails | Check internet access. Install official 7-Zip if WinGet is missing. Preserve the error if a pinned Microsoft package is unavailable. |
| Another workflow or installer is active | Finish or deliberately recover that workflow first. Do not delete its state or task just to bypass the message. |
| Restart happened but nothing continues | Sign into the same account; open the MSI start shortcut once. Preserve any error. |
| Driver loads only with Test Signing on, Code 43, or final audit fails | Treat installation as failed. Keep recovery evidence and use the recovery guidance below. |

Managed Windows policies, Memory Integrity/HVCI and other code-integrity configurations can affect loading and trust. They have not all been validated. Do not disable additional security features just to force a pass.

## If you need to go back

The toolkit attempts rollback when a driver transaction fails, but rollback is best effort. There is no separate one-click uninstall script in this source.

If Windows is usable, preserve the failure report and rollback folders. Get the official graphics driver for your exact model from [MSI's Claw A8 support page](https://www.msi.com/Handheld/Claw-A8-BZ2EMX/support) and follow MSI's recovery/installation instructions. Device Manager's **Roll Back Driver** may be available, but is not guaranteed. Installing the OEM driver does not automatically undo every certificate, task or catalog change this toolkit made.

If Windows cannot start normally, use Windows Recovery/Startup Settings and MSI's recovery guidance, or get help from someone comfortable recovering a graphics driver. Have the encryption recovery key ready. Do not delete random Driver Store packages or certificates. Re-enabling Secure Boot with this locally signed driver still active is not a supported recovery procedure.

When reporting a problem, include your model, full graphics hardware ID, Windows version, driver version, the step that failed and the exact error. Review logs before sharing: they may contain your Windows username, paths, device instance identifiers and certificate details. Never share passwords, encryption recovery keys, private certificates or a complete unreviewed workflow folder.

## For people publishing or changing the source

See [PUBLISHING.md](../PUBLISHING.md) for simple GitHub upload instructions, [docs/REVIEW.md](REVIEW.md) for findings, and [CONTRIBUTING.md](../CONTRIBUTING.md) for validation commands.

Publish the source files and original MIT license together. Users download AMD's installer separately. Do not upload your AMD `.exe`, generated driver package, machine-specific certificates, recovery files or personal logs. The supplied `.gitignore` helps Git users; it cannot protect a manual drag-and-drop upload.
