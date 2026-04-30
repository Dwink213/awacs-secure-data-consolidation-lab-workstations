# Workstation Requirements

Per CLAUDE.md Rule 10, every workstation requirement is captured. The bootstrap script installs everything below — the operator runs the bootstrap, not these steps individually.

## OS

- Windows 10 22H2 or Windows 11 22H2 (or later)
- Workstation OS, not Server

## PowerShell

- PowerShell 5.1 (built into Windows since Windows 10)
- PowerShell 7+ optional, not required

## .NET

- .NET Framework 4.7.2+ (default on supported Windows versions)

## Modules (installed by bootstrap)

Pinned versions — supply-chain hardening per ADR-002 and threat-model T6 (supply chain).

| Module | Pinned Version | Source |
|--------|----------------|--------|
| Az.Accounts | 2.13.2 | PSGallery |
| Az.Storage | 6.1.1 | PSGallery |
| Az.KeyVault | 5.0.1 | PSGallery |

Future hardening: mirror these to a private NuGet/PSGallery feed and update `bootstrap.ps1` to use `-Repository <private>`.

## Network access required

- Outbound HTTPS (443) to:
  - `login.microsoftonline.com` (Entra ID token)
  - `*.vault.azure.net` (Key Vault data plane)
  - `*.blob.core.windows.net` (Storage data plane)
- TLS 1.2+ enabled in OS network stack (default on supported Windows versions)

## Local storage

- ≥500 MB free in `C:\ProgramData\AwacsBackup\` for logs and ledger

## User accounts

A dedicated **service account** is required:

- Local user, not domain account (to fit the "no domain join" model)
- Member of `Users` only (no admin rights)
- Password set; password expiration disabled
- "Log on as a batch job" right granted (for scheduled task)

The cert is imported into THIS user's `Cert:\CurrentUser\My` store. Interactive analysts using the lab PC do NOT have access to this account by default.

## Certificate

- Provided by the deployer as a `.pfx` (or `.pem`)
- Thumbprint captured at install time and written to `config.json`
- Imported with `-KeyExportable:$false` (non-exportable)

## Group Policy (recommended for production)

- `Set-ExecutionPolicy AllSigned` for `LocalMachine` scope
- Code-signing CA in `Trusted Publishers`
- Restricted PowerShell logging enabled (script block + module logging)

## Bootstrap is idempotent

Re-running `bootstrap.ps1` on an already-configured workstation will:

- Detect installed modules → skip
- Detect existing cert → skip (does not re-import)
- Detect existing scheduled task → skip
- Detect existing config → ask before overwriting

## Uninstall

`workstation/uninstall.ps1` reverses everything cleanly. Removed cert is backed up to `C:\ProgramData\AwacsBackup\removed-certs\<timestamp>\` for forensic continuity.
