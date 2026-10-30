# Upload this source to GitHub

This folder is a prepared source tree. It has not been pushed to GitHub and does not contain a Git repository or a remote connection. You can choose the repository name and account when you upload it.

## Simple upload using your browser

1. Sign into GitHub and create a new repository. A suitable name is `MSI-Claw-A8-AMD-Toolkit`.
2. A suitable description is: `Community AMD 26.10.1 driver toolkit for the exact MSI Claw A8 Z2 Extreme profile, derived from the Legion Go toolkit.`
3. Leave the automatic README, license and `.gitignore` options unticked: those files are already supplied here.
4. Select the option to upload existing files.
5. Open this prepared source folder on your computer. Upload its **contents**, so `README.md`, `Internal`, `LICENSE` and the start shortcuts are at the repository's top level. Do not upload an outer `GitHub-Source` folder as an extra nesting level.
6. Include the dot files and `.github` folder. Enable **View → Show → Hidden items** in File Explorer if needed. Check that `.gitignore`, `.gitattributes` and `.github/workflows/validate.yml` appear in the upload.
7. Check the uploaded file list before committing it. There should be no AMD installer, personal repair shortcut, diagnostic JSON, generated driver payload or certificate file.
8. Commit the upload with a message such as `Prepare MSI Claw A8 community source`.
9. Open the rendered README and the **Actions** tab. The supplied workflow runs read-only source checks on Windows; it does not install drivers or prove physical-device compatibility.
10. Download the repository using **Code → Download ZIP**, extract it into a fresh folder, and run the read-only commands in [CONTRIBUTING.md](CONTRIBUTING.md). This checks the bytes users actually receive.

Upload files individually/as folders after extracting the prepared ZIP. Uploading the source ZIP as a single repository file does not make GitHub show the project as a normal source repository.

## What is intentionally excluded

- The approximately 1.78 GB AMD installer. It is a separate official AMD download. [GitHub blocks ordinary repository files larger than 100 MiB](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github).
- The machine-specific `Apply-Installer-Fix.cmd`, which referenced a personal Downloads path and an external repair script.
- The local `MSI-*-Preflight-Result.json` reports and other personal run evidence.
- Installed/extracted AMD files, generated INF/DAT/catalog payloads, certificates, private keys, workflow state and rollback data.
- The original downloaded Lenovo ZIP. Its source URL and checksum are documented in [NOTICE.md](NOTICE.md).

The `.gitignore` is a convenience for Git. A browser upload can still upload ignored files if you select them. Use this clean prepared folder, not the original working folder containing the AMD `.exe`.

## If you publish a downloadable release

Use a distinct MSI community beta name so people do not confuse it with either upstream release. Mark the release as a pre-release. Include the supported full hardware ID and the security requirements from the README. Do not label it "all Claw A8 devices supported" or "official AMD/MSI driver".

You can attach the prepared source ZIP as a release asset. It contains source and instructions, not the AMD driver download. If you change any files, make a new ZIP and checksum instead of reusing an old checksum. The adjacent `.sha256` file supplied during preparation is for the specific ZIP created then.

Retain [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). The checked upstream license allows modification and distribution under its stated MIT terms; AMD and Microsoft downloads keep their own terms.

## Changing files later

Runtime files have byte-exact entries in `PACKAGE-MANIFEST.json`. The supplied `.gitattributes` prevents Git from changing their line endings automatically. Save intended edits, review the changes, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Update-PackageManifest.ps1
```

Run all checks in [CONTRIBUTING.md](CONTRIBUTING.md) afterward. Never refresh a manifest merely to hide unexplained corruption. The manifest detects accidental changes; because it ships beside the scripts, it is not a publisher signature or independent proof that a download is trustworthy.

Keep the build profiles, final INF/DAT hashes, release contract, workflow identity and recovery format stable unless you deliberately create and validate a new release. Existing installations use a persistent toolkit copy in ProgramData. Uploading or extracting new source does not update that copy. Do not replace its files during an unfinished installation.
