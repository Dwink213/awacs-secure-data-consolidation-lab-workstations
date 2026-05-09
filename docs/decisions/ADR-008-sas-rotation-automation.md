# ADR-008: SAS Rotation Automation via Azure Automation Account + MSI

**Date:** 2026-05-08
**Status:** Accepted
**Agents who reviewed:** 🏗️ Architect, 🛡️ Security Engineer, 🔧 Operator, 📚 Documentarian

---

## Context

User-delegation SAS tokens have a hard 7-day maximum lifetime enforced by Azure. The system initially used manual rotation per `RUNBOOK.md`. On 2026-05-01 the token expired unnoticed — workstation blob pushes failed silently with HTTP 403 for 6 days 18 hours before being caught manually. A second compounding issue (Norton SSL interception) blocked the rotation toolchain on 2026-05-08. Manual rotation is not sustainable.

---

## Decision

Add an Azure Automation Account (component 08) with a system-assigned Managed Identity that rotates the `current-write-sas` Key Vault secret on a 6-day schedule.

---

## Alternatives Considered

| Option | Why Rejected |
|---|---|
| **Azure Function (Consumption plan)** | Deployment failed in production: Consumption plan ("Dynamic") requires a VM quota allocation that personal/MSDN Azure subscriptions return as 0. The Function App provisioned but the runtime container could not start. Zero tolerance for "works on Enterprise subscriptions, fails on personal" in a public repo targeting lab environments. |
| **Workstation scheduled task** | Tied to a single machine being online and logged in. If the workstation is off, rotation fails. No MSI available on non-Azure compute. SP cert rotation would itself become a dependency. |
| **Account-key SAS instead of user-delegation SAS** | Removes the 7-day cap but requires the rotator to hold or fetch the storage account key, which widens the credential exposure surface. The current architecture explicitly disables shared key access (`allowSharedKeyAccess: false`). Rejected. |
| **Key Vault rotation policy + event-driven rotation** | KV has native rotation for managed keys and certificates, but not for arbitrary secrets like SAS tokens. Would require a custom Event Grid integration of equivalent complexity. |

---

## Trade-offs Accepted

**What we give up:**
- One additional Azure resource (Automation Account, Free SKU) — cost $0/month at 1 invocation per 6 days
- Runbook content must be uploaded via REST API after Bicep deploy. Two `az automation` CLI verbs (`runbook replace-content` and `jobSchedules create`) do not exist in the current CLI; `Deploy.ps1` handles this via `Invoke-RestMethod` with a Bearer token

**What we gain:**
- Rotation happens automatically, invisibly, before expiry — no operator action required
- MSI means zero credentials to store, rotate, or leak
- Automation Account Free SKU supports PowerShell runbooks with no billing beyond the 500 free min/month (rotation uses < 1 min/run × 60 runs/year)
- Rotation invocation is logged to the Log Analytics workspace — failure is visible and auditable
- Runbook failure leaves the old (still-valid) token in place — no silent fail during the 23-hour overlap window

---

## Security Notes (🛡️ Security Engineer)

The Automation Account's MSI is granted `Key Vault Secrets Officer` scoped to the specific secret resource ID — not to the vault. It cannot read other secrets, create new secrets, or modify vault configuration.

`Storage Blob Data Contributor` scoped to the `lab-files` container is required because user-delegation SAS tokens can only grant permissions the issuing identity holds. The alternative (granting only `Storage Blob Delegator` without a data-plane role) produces a SAS token that clients cannot use for writes. This is the minimum permission set that produces a functional `acw` token.

**Important: the Automation MSI is the widest credential in the system.** It can write directly to the `lab-files` container without a SAS intermediary. Mitigating controls: (1) MSI token is ephemeral — it cannot be exported from the Automation runtime; (2) immutability policy prevents delete even with direct write access; (3) every job invocation is logged to Log Analytics with timestamp and outcome. This credential exposure is named as trust zone Z9 in `threat-model.md` §2.

Automation Account configuration values are stored as Automation Variables (not environment variables). String variables are JSON-encoded by Bicep (`'"${value}"'` produces `"value"` in the variable store); `Get-AutomationVariable` decodes them at runtime.

---

## Schedule Rationale

Azure Automation Day-frequency schedule, interval = 6, start-time noon UTC.

- Generates a token valid for 6d 23h (1 hour inside the 7-day cap)
- 23-hour overlap: even if a rotation fires late, the old token remains valid during the gap
- Noon UTC chosen to avoid midnight edge cases and time zone ambiguity in logs
- The schedule-to-runbook link is a `jobSchedule` REST resource (PUT), since `az automation jobSchedules create` does not exist in the current CLI

---

## Agents' Positions

🏗️ **Architect:** Approved. Clean single-responsibility component. MSI is the correct identity model for Azure-hosted compute. The 6-day schedule with 23h overlap is robust against single-run failures. The imperative runbook upload via REST API is inelegant but honest — better to document it than to pretend Bicep alone handles it.

🛡️ **Security Engineer:** Approved with note. `Storage Blob Data Contributor` on the container is the minimum required for user-delegation SAS to embed write permissions. Confirmed container-scoped (not SA-scoped) per `main.bicep`. The ephemeral MSI token and immutability policy together adequately mitigate the Z9 widened credential. Z9 is now named in `threat-model.md` §2 with its mitigating controls documented.

🔧 **Operator:** Approved. Failure mode is safe — old token stays valid during the overlap window. `Write-Error` + `throw` in the runbook marks the invocation Failed in Automation job history, which surfaces in Log Analytics. Monthly health check (`C8_5-last-rotation-ok.ps1`, `C8_6-sas-expiry-valid.ps1`) documented in `RUNBOOK.md`. Manual fallback preserved.

📚 **Documentarian:** Approved. Component README documents contract, failure mode, RBAC table, and verify commands. This ADR captures the full decision trail including the production outage that motivated the work and the Azure Functions quota failure that drove the pivot to Automation Account.
