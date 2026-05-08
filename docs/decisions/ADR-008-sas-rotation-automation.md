# ADR-008: SAS Rotation Automation via Azure Function + MSI

**Date:** 2026-05-08
**Status:** Accepted
**Agents who reviewed:** 🏗️ Architect, 🛡️ Security Engineer, 🔧 Operator, 📚 Documentarian

---

## Context

User-delegation SAS tokens have a hard 7-day maximum lifetime enforced by Azure. The system initially used manual rotation per `RUNBOOK.md`. On 2026-05-01 the token expired unnoticed — workstation blob pushes failed silently with HTTP 403 for 6 days 18 hours before being caught manually. A second compounding issue (Norton SSL interception) blocked the rotation toolchain on 2026-05-08. Manual rotation is not sustainable.

---

## Decision

Add an Azure Function (component 08) with a system-assigned Managed Identity that rotates the `current-write-sas` Key Vault secret on a 6-day NCRONTAB schedule.

---

## Alternatives Considered

| Option | Why Rejected |
|---|---|
| **Workstation scheduled task** (e.g., rotate from DESKTOP-0DBOTVV) | Tied to a single machine being online and logged in. If the workstation is off, rotation fails. No MSI available on non-Azure compute. SP cert rotation would itself become a dependency. |
| **Account-key SAS instead of user-delegation SAS** | Removes the 7-day cap — longer token lifetime is possible. But requires the rotator to hold or fetch the storage account key, which widens the credential exposure surface. The current architecture explicitly disables shared key access (`allowSharedKeyAccess: false`). This would require re-enabling it. Rejected. |
| **Azure Automation runbook** | Viable but introduces a separate service with its own managed runtime, update cycle, and cost model. Functions runtime is already a common pattern; adds less cognitive overhead for this workload. |
| **Key Vault rotation policy + event-driven rotation** | KV has native rotation for managed keys and certificates, but not for arbitrary secrets like SAS tokens. Would require a custom event grid integration of equivalent complexity to this approach. |

---

## Trade-offs Accepted

**What we give up:**
- One additional Azure resource (Function App + plan + storage account) — cost ~$0/month at 1 invocation per 6 days
- One additional deployment surface to maintain (PowerShell runtime, module dependencies)

**What we gain:**
- Rotation happens automatically, invisibly, before expiry — no operator action required
- MSI means zero credentials to store, rotate, or leak
- Rotation invocation is logged to `awdust-la-ybmh` — failure is visible and auditable
- Function failure leaves the old (still-valid) token in place — no silent fail during the overlap window

---

## Security Notes (🛡️ Security Engineer)

The MSI is granted `Key Vault Secrets Officer` scoped to the specific secret resource ID — not to the vault. It cannot read other secrets, create new secrets, or modify vault configuration.

`Storage Blob Data Contributor` is required because user-delegation SAS tokens can only grant permissions the issuing identity holds. The alternative (granting only `Storage Blob Delegator` without a data-plane role) produces a SAS token that clients can't use for writes. This is the minimum permission set that produces a functional `acw` token.

The Function App storage account (runtime use only) uses an account key connection string. This is unavoidable — the Functions runtime requires it for trigger/state management. It does NOT affect the data storage account, which remains `allowSharedKeyAccess: false`.

---

## CRON Schedule Rationale

`0 0 12 */6 * *` — noon UTC every 6 days.

- Generates a token valid for 6d 23h (1 hour inside the 7-day cap)
- 23-hour overlap: even if a rotation fires late, the old token remains valid during the gap
- Noon UTC chosen to avoid midnight edge cases and time zone ambiguity in logs
- 6 days chosen (not 6.5) because NCRONTAB doesn't support fractional days; `*/6` is the nearest clean interval

---

## Agents' Positions

🏗️ **Architect:** Approved. Clean single-responsibility component. MSI is the correct identity model for Azure-hosted compute. The 6-day schedule with 23h overlap is robust against single-run failures.

🛡️ **Security Engineer:** Approved with note. The `Storage Blob Data Contributor` on the container is the minimum required for user-delegation SAS to embed write permissions. Confirm this role is container-scoped (not SA-scoped) — it is, per `main.bicep`. No objection to account-key connection string for the Function's own runtime storage (unavoidable).

🔧 **Operator:** Approved. Failure mode is safe — old token stays valid during overlap. `Write-Error` + `throw` in `run.ps1` marks the invocation Failed in the Functions runtime, which will surface in Log Analytics. Manual fallback in `RUNBOOK.md` is preserved.

📚 **Documentarian:** Approved. Component README documents contract, failure mode, RBAC table, and verify commands. ADR captures the full decision trail including the incident that motivated this work.
