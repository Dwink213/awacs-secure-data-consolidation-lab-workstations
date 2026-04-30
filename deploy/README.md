# Deploy

Turnkey deploy/verify/teardown for the cloud-side six components. The workstation-side seventh component is bootstrapped separately (`workstation/bootstrap.ps1`) on each lab PC.

## Prerequisites

- PowerShell 5.1 or later (PowerShell 7 also works)
- Azure CLI ≥2.50.0 with Bicep ≥0.20.0
- An Azure subscription, you logged in as Owner OR Contributor + User Access Administrator
- An Entra ID security group whose members will be allowed to read backups (capture its Object ID)

## One-command deploy

**Command:**
```
./deploy/Deploy.ps1 -SubscriptionId <sub> -Region eastus2 -Prefix awacslab -ConsumerGroupObjectId <group-oid> -AlertEmail ops@example.com
```

**What it does:** preflight → create RG → create SP+cert → deploy Bicep → generate initial SAS → emit workstation config and cert.

**Expected output:** "DEPLOY COMPLETE" banner with paths to `./out/<prefix>-sp-cert-*.pem` and `./out/<prefix>-workstation-config.json`.

## Verify

**Command:** `./deploy/verify.ps1 -ResourceGroup awacslab-rg -Prefix awacslab`
**What it does:** runs every `tests/scripts/*.ps1` against the live environment.
**Expected output:** table of test name → PASS/FAIL → duration; non-zero exit code if any failed.

## Teardown

**Command:** `./deploy/teardown.ps1 -SubscriptionId <sub> -Prefix awacslab`
**What it does:** removes RBAC, SP, locks, RG. Refuses if immutability is Locked.
**Expected output:** "Teardown complete" message.

To purge soft-deleted Key Vaults afterward, add `-PurgeSoftDeleted`.

## Files in this directory

| File | Purpose |
|------|---------|
| `main.bicep` | Top-level orchestrator; composes components 01–06 |
| `preflight.ps1` | Refuses if environment isn't ready |
| `Deploy.ps1` | The one-command deploy |
| `verify.ps1` | Runs the executable test battery |
| `teardown.ps1` | Removes everything safely |

## Limitations honestly named

- The deploy script uses `az ad sp create-for-rbac --create-cert`, which writes the cert PEM to the deploying user's `.azure` directory. Path discovery is best-effort across CLI versions; if it fails, the script falls back to scanning. If the fallback fails, the operator must locate the PEM manually (`Get-ChildItem $env:USERPROFILE/.azure -Recurse -Filter '*.pem'`).
- User-delegation SAS generation requires the deploying identity to have `Storage Blob Delegator` (or be Owner). The deploy warns if SAS generation fails and points to the manual fix.
- The teardown's immutability-state check is a guardrail, not an iron lock. Azure itself enforces Locked policies; teardown's check is a fast-fail before contacting Azure.
- There is currently no equivalent `.sh` script for non-Windows operators. PowerShell-only is honest given the workstation-side is Windows. A `.sh` deploy could be added later — the Bicep is platform-agnostic.
