# Executable Test Scripts

These are the runnable counterparts to the markdown specs in the parent `tests/` directory. They are invoked en masse by `deploy/verify.ps1`.

## What's in this directory

The first-pass executable subset (this commit):

| Script | Spec file | Concern |
|--------|-----------|---------|
| `C1_1-https-only.ps1` | `02-component-contracts.md` | Storage HTTPS-only |
| `C1_3-shared-key-disabled.ps1` | `02-component-contracts.md` | Shared-key auth off |
| `C1_4-tls-minimum.ps1` | `02-component-contracts.md` | TLS 1.2 floor |
| `C1_5-soft-delete-versioning.ps1` | `02-component-contracts.md` | Soft delete + versioning |
| `C2_1-kv-soft-delete-purge.ps1` | `02-component-contracts.md` | KV soft-delete + purge |
| `C2_2-kv-rbac-mode.ps1` | `02-component-contracts.md` | KV RBAC mode |
| `C3_1-sp-cert-only.ps1` | `02-component-contracts.md` | SP no client secret |
| `C4_1-immutability-applied.ps1` | `02-component-contracts.md` | Immutability policy live |
| `C5_1-diag-settings.ps1` | `02-component-contracts.md` | Diag settings present |
| `C6_1-consumer-rbac.ps1` | `02-component-contracts.md` | Consumer reader-only |
| `T2_2-immutability-blocks-delete.ps1` | `01-threat-model-defense.md` | T2.2 immutability blocks delete |
| `CIS-3_13-storage-logging.ps1` | `05-compliance.md` | CIS-3.13 (wrapper of C5.1) |
| `CIS-Custom-shared-key.ps1` | `05-compliance.md` | CIS-Custom (wrapper of C1.3) |
| `D6_3-idempotent.ps1` | `06-deployment.md` | Bicep redeploy is no-op |

## What's NOT yet implemented (honest gap)

The remaining tests (specs in parent `tests/*.md`) have markdown specs but no executable counterpart yet. Adding them is straightforward — each follows the same template (param `-ResourceGroup` + `-Prefix`, import `_helpers.psm1`, use `Test-Assert`). High-value next adds:

- `T1_1-sp-read-denied.ps1` — actively use the SP cert and verify GET fails (requires the cert in the test runner's environment, not just the deployed env)
- `I3_1-end-to-end.ps1` — drop a file in a watched dir on a test workstation, wait, verify blob + LA log
- `F4_1-staleness-alert.ps1` — confirm the Scheduled Query Rule resource exists and points at the action group
- `W7_*-bootstrap-tests.ps1` — these run on a candidate workstation, verifying cert in store, scheduled task registered, etc.

## Running tests individually

**Command:** `pwsh tests/scripts/C1_1-https-only.ps1 -ResourceGroup awacslab-rg -Prefix awacslab`
**What it does:** runs one test against a deployed environment.
**Expected output:** `[PASS]` line; exit code 0 on success, 1 on failure.

## Running the whole battery

**Command:** `pwsh deploy/verify.ps1 -ResourceGroup awacslab-rg -Prefix awacslab`
**What it does:** discovers every `*.ps1` in this directory, runs each, prints a structured table.
**Expected output:** "All N tests passed." on green, or a list of failures.
