# Architecture

**Stage 2 artifact.** All four agents signed at the bottom. This document and its sibling diagram files are the canonical map of the system.

## Reading order

1. `system-diagram.md` — what the system looks like at the component level
2. `component-map.md` — how the Atomic Legos compose
3. `trust-boundaries.md` — which crossings carry which credentials (cite to threat-model.md §2)
4. `data-flow.md` — what happens to a single file from creation to consumer access
5. `deployment-flow.md` — what `./deploy.sh` does, in order

## The Atomic Legos

Per CLAUDE.md Rule 2, every component is a single-responsibility independently testable unit. We have **eight**.

| # | Component | Single Responsibility | Trust zone(s) it lives in | Owner agent |
|---|-----------|----------------------|---------------------------|-------------|
| 01 | Storage Account | Durable, immutable, write-only-from-lab destination | Z7 | 🛡️ |
| 02 | Key Vault | Holds the rotated SAS; gates access by SP identity | Z6 | 🛡️ |
| 03 | Service Principal + Custom Role | Lab-PC's narrowly-scoped Entra identity | Z4 ↔ Z5 ↔ Z6/Z7 | 🛡️ |
| 04 | Immutability Policy | Time-based retention on the container; the "you cannot delete" guarantee | Z7 | 🛡️ |
| 05 | Log Analytics + Diagnostic Settings | The audit trail. Tamper-evident, separate trust zone. | Outside Z7 | 🔧 |
| 06 | RBAC for Consumers | Read-only access to the container from analyst desks | Z8 → Z7 | 🏗️ |
| 07 | Workstation Push Script | The thing on the lab PC. Cert auth, fetch SAS, push files, log. | Z1 | 🔧 |
| 08 | SAS Rotator | Azure Automation Account + MSI that rotates `current-write-sas` every 6 days | Z9 | 🔧 |

The cloud-side seven (01–06, 08) are deployed by `deploy/Deploy.ps1` (Bicep + post-deploy REST API steps). The workstation-side one (07) is deployed by running `workstation/bootstrap.ps1` on each lab PC.

## Naming standard

Per AWACS prior work and CLAUDE.md Rule 5, region name does NOT appear in resource names where the resource type is multi-region-eligible. Resources are named:

```
<prefix>-<short-component>-<unique4>
```

- `prefix` is user-supplied, lowercase, ≤8 chars (e.g., `awacslab`)
- `short-component`: `sa` (storage), `kv` (key vault), `la` (log analytics), `id` (managed identity / SP), `rg` (resource group)
- `unique4`: 4 deterministic chars derived from the resource group name + subscription ID, to satisfy global-uniqueness rules without requiring user input

Storage Account names are the strictest: 3–24 chars, lowercase alphanumeric only. We collapse hyphens for the SA name, e.g., `awacslabsa1234`.

Resource Group: `<prefix>-rg`. The deploy creates this — user does not pre-create.

## IaC structure

Each component directory contains a self-contained `main.bicep` plus an `parameters.example.json`. The top-level `deploy/main.bicep` (created in Stage 5) is a thin orchestrator that includes each component module, passes through user inputs, and wires outputs to inputs.

This makes each component independently deployable for testing — the Operator agent's requirement.

## Cross-Agent Review

- 🏗️ **Architect:** Signed. Decomposition is clean; each Lego maps to exactly one CLAUDE.md repository directory.
- 🛡️ **Security Engineer:** Signed. Trust crossings line up with the Lego boundaries; nothing crosses without a named credential.
- 🔧 **Operator:** Signed. Each Lego deployable in isolation = each Lego diagnosable in isolation.
- 📚 **Documentarian:** Signed. The reading order serves a 6-month-later engineer.
