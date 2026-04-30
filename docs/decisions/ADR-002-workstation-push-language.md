# ADR-002: Workstation Push Language — PowerShell with Az Modules

**Status:** Accepted
**Date:** 2026-04-30
**Agents who reviewed:** 🏗️ 🛡️ 🔧 📚

## Decision

**PowerShell 5.1+** (built into Windows since Windows 7, present on every supported lab workstation OS) using the `Az.Accounts` and `Az.Storage` modules. The push script is `workstation/push-files.ps1`. The bootstrap script (`workstation/bootstrap.ps1`) installs prerequisites idempotently.

## Alternatives considered

1. **Python (per the captured 2026-04-28 design)** — works, but requires a Python install + `azure-identity` + `azure-storage-blob` packages. That's an extra installer, an extra version to manage, and an extra attack surface (PyPI typosquats).
2. **Azure CLI (`az`) in a batch file** — works, single-binary install, but error handling and structured logging are weak. Hard to produce the verbose log lines Operator agent demands per Rule 8.
3. **AzCopy** — fast for bulk transfer, but it's a separate binary to bootstrap, and shaping a write-only auth model around it is harder than around the SDK.
4. **C# / dotnet console app** — over-engineered for the use case. Builds a binary that has to be signed and re-released on every change.

## Trade-off

We give up:
- Cross-OS portability (Linux lab workstations would need pwsh-core, not a hard sell but real friction)
- The richer Python ecosystem of file-handling and retry libraries
- AzCopy's transfer performance

We get:
- **Zero new runtime to install.** PowerShell 5.1 ships with Windows. Modules install via `Install-Module` from PSGallery, not from PyPI.
- **Native Task Scheduler integration.** Scheduled tasks can invoke `powershell.exe` directly, no wrapper batch needed.
- **Verbose logging out of the box** (`Start-Transcript`, structured `Write-Verbose`/`Write-Information`).
- **Code signing path** — PowerShell scripts can be Authenticode-signed and Group Policy can require signed scripts, defense-in-depth on the lab PC.
- **Cert handling is first-class.** The `Get-PfxCertificate` and `Cert:\CurrentUser\My` PSDrive are native PowerShell idioms.

## Rationale

The captured design assumed Python because Python is what the original author reached for. PowerShell collapses three problems into one (runtime, scheduler integration, logging). For a Windows-workstation-only target — which is what shared lab PCs realistically are — PowerShell is the smaller-footprint, less-clever-solution that meets every requirement.

If a future deployer needs Linux lab workstations, this ADR can be revisited and a parallel `push-files.py` added without changing the cloud side.

## Cross-Agent Review

- 🏗️ **Architect:** Accepts. The push contract is defined in the component README; the language behind it is swappable.
- 🛡️ **Security Engineer:** Accepts. Code-signing path is a meaningful gain. Native cert store integration is exactly what the layered auth model needs.
- 🔧 **Operator:** Strongly prefers. `Start-Transcript` plus rotated logs is what I need at 3 AM.
- 📚 **Documentarian:** Accepts. PowerShell reads more clearly to a Windows-centric audience than Python does.
