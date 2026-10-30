# MSI Claw A8 — AMD 26.10.1

A community tool for installing **AMD Adrenalin 26.10.1** on the **MSI Claw A8 Z2 Extreme**. It prepares the driver, installs it and checks the result after restarting Windows.

**[Download the toolkit ZIP](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/download/v1.0.0-beta.1/MSI-Claw-A8-AMD-26.10.1-GitHub-Source.zip)** · [Release notes](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/tag/v1.0.0-beta.1) · [Detailed installation guide](docs/INSTALLATION.md)

This is a **community beta**, not an official MSI or AMD update. It worked on one tested Claw A8, but other devices and Windows setups may behave differently.

## Is it for my device?

Use this only with an **MSI Claw A8 BZ2EM with Ryzen Z2 Extreme and Windows 11**. It is not intended for Intel-based Claw models.

After extracting the download, double-click **`Check-Compatibility.cmd`**. This checks your device without changing anything. If it does not pass, stop — do not force the installation.

## 1. Download two things

- **[The toolkit ZIP](https://github.com/ludekvlk/MSI-Claw-A8-AMD-Toolkit/releases/download/v1.0.0-beta.1/MSI-Claw-A8-AMD-26.10.1-GitHub-Source.zip):** save it in Downloads, right-click it and choose **Extract All**. Keep all the extracted files together.
- **[AMD's full 26.10.1 driver installer](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-10-1.html):** download the RDNA package and leave it in Downloads. Its name should be `whql-amd-software-adrenalin-edition-26.10.1-win11-c.exe`.

You do not need to run the AMD installer yourself. The toolkit will use it.

## 2. Prepare your Claw

- Save your work, connect the charger and allow about **30–60 minutes**.
- If you use **BitLocker or Device Encryption**, keep your recovery key somewhere you can access from another device. **Suspend protection before changing boot settings**; resume it after installation succeeds. The toolkit does not do this for you.
- **Disable Secure Boot in your device's firmware settings. It must stay disabled while using this driver.** This may affect games that require Secure Boot.

The installer changes driver trust and boot settings. If these preparation steps are unfamiliar, follow the [detailed guide](docs/INSTALLATION.md#step-3--prepare-encryption-and-secure-boot) or get help before continuing.

## 3. Install

1. Open the extracted toolkit folder.
2. Double-click **`Start-MSI-Claw-A8-AMD-26.10.1.cmd`**.
3. Accept the Windows administrator prompt, read the instructions and confirm when ready.
4. Let it work. Windows will restart several times. **Sign into the same account after each restart.**
5. Wait for the final success message. Then resume encryption protection if you suspended it.

The screen may flicker during installation. Do not close the installer, turn off the device or run the numbered scripts separately. Required extra tools are downloaded automatically when needed.

A successful installation should finish with **51 checks passed**, driver **32.0.32015.7029**, and Windows **Test Signing OFF**. Secure Boot stays disabled.

## If something goes wrong

**Stop at the first error.** Keep the error message and the installation's log and recovery folders. Do not repeatedly retry or bypass checks.

If it does not continue after a restart, sign into the same account and open the MSI start shortcut once. For other problems, use the [troubleshooting and recovery guide](docs/INSTALLATION.md#common-problems). The [official MSI driver](https://www.msi.com/Handheld/Claw-A8-BZ2EMX/support) is the recovery option; automatic rollback is not guaranteed.

Never post your encryption recovery key or unreviewed personal logs on GitHub.

## Credits and more information

Adapted from [DontDoMuch's Legion Go toolkit](https://github.com/DontDoMuch/LeGo1-graphic-driver-toolkit) through [ryanoceros94's AMD 26.10.1 version](https://github.com/ryanoceros94/LeGo2-Adrenalin26.10.1). Some script names still say LegionGo because they share that original workflow.

[MIT license](LICENSE) · [Full credits](NOTICE.md) · [Testing and compatibility limits](docs/REVIEW.md) · [Contributor guide](CONTRIBUTING.md)
