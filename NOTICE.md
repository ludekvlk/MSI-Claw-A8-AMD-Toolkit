# Credits and source lineage

This MSI Claw A8 adaptation is built on the work of:

- **DontDoMuch and the LeGo AMD Driver Toolkit contributors:** [original Legion Go toolkit](https://github.com/DontDoMuch/LeGo1-graphic-driver-toolkit). The shared transaction, local signing, rollback, exact hardware selection, catalog verification and restart/resume architecture originate in that toolkit.
- **ryanoceros94:** [LeGo2-Adrenalin26.10.1](https://github.com/ryanoceros94/LeGo2-Adrenalin26.10.1), the AMD 26.10.1 adaptation used as the downloaded starting package.
- **Local MSI adaptation contributors:** the exact MSI Claw A8 Z2 Extreme profile, MSI routing without Lenovo OEM overrides/cleanup, boot-safety and recovery hardening, and this source preparation.

The starting ZIP was `LegionGo-AMD-26.10.1-Public-Beta-v5.0.1.zip`, from [release public-beta-v5.0.1-26.10.1](https://github.com/ryanoceros94/LeGo2-Adrenalin26.10.1/releases/tag/public-beta-v5.0.1-26.10.1).

Its local SHA-256 matches the release asset digest:

```text
CEFF392FCC4290D0FDAF517C9304BD76F8773F228E603CA05C09088FACFC288F
```

This identifies the starting download. It is **not** the checksum of this modified MSI source package. The local working folder already contained MSI changes and later repair work; it is not represented as an unmodified upstream release. The original ZIP's Windows download metadata also identifies the release URL. Temporary signed download URLs and local personal paths are not included here.

The upstream repositories carry the same MIT notice: `Copyright (c) 2026 LeGo AMD Driver Toolkit contributors`. That license is reproduced in [LICENSE](LICENSE). The scripts and documentation in this source distribution are provided under those MIT terms. AMD driver binaries and Microsoft tools are separate third-party software under their own terms; this repository does not bundle or relicense them.

AMD, MSI, Lenovo, Legion Go and other product names identify their respective products. This community adaptation is not endorsed by those companies or claimed as an official release by either upstream author.
