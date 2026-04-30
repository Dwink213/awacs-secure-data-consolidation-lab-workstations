# Threat Model

**Status:** Stage 1 artifact. All four agents have signed at the bottom.
**Owner agent:** 🛡️ Security Engineer
**Date:** 2026-04-30
**Compliance regime:** CIS Azure Foundations Benchmark v5.0, GxP-ready (see `docs/decisions/ADR-000-compliance-regime.md`)

This document is load-bearing. Every later stage cites it. If a defense in this repo is not traceable back to an attacker, asset, or trust boundary in this document, it is over-engineered. If an attacker in this document is not defended against by some named control, the design has a gap.

---

## 1. What we are defending

| ID | Asset | Why it matters | Sensitivity |
|----|-------|----------------|-------------|
| A1 | Lab-generated data files on the workstation | Source-of-truth scientific output; loss means re-running experiments | High (integrity), Medium (confidentiality) |
| A2 | Backed-up data files in Azure Blob | The durable copy. Once landed, must outlive any compromise of the workstation. | High (integrity, availability), Medium (confidentiality) |
| A3 | Audit log of who/what/when wrote and read | Evidence for incident response and compliance review | High (integrity, tamper-evidence) |
| A4 | The auth credentials themselves (SP cert, SAS) | Their compromise is the gateway to A2 | High (confidentiality, scope-limitation) |

**Out of scope as assets:**
- Workstation OS integrity itself (different problem; assumed already compromised — see T3)
- Consumer-side analyst desktop (different trust zone, addressed separately by enterprise endpoint controls)

---

## 2. Trust boundaries

We name eight trust zones. The system's job is to ensure that crossings between them are *narrow, named, and auditable*.

| Zone | Trust Level | Why |
|------|------------|-----|
| Z1 — Shared Lab Workstation | **LOW** | Generic logins, multi-user, not domain joined, no central credential store, anything on disk lifted-able |
| Z2 — Lab Egress Network | **LOW** | Shared network; assume on-path observers |
| Z3 — Public Internet | **UNTRUSTED** | TLS only |
| Z4 — Entra ID (Azure AD) | **HIGH** | Microsoft-managed identity provider |
| Z5 — Azure Resource Manager (ARM) | **HIGH** | Control plane |
| Z6 — Key Vault | **HIGH** | Holds the rotated SAS |
| Z7 — Storage Account (write side) | **HIGH** | Where files land. Immutability enforced. |
| Z8 — Consumer Desks (analyst workstations, separate) | **MEDIUM** | Domain-joined, individual user identity, MFA |

The crossings worth naming:

- **Z1 → Z3:** TLS 1.2+ outbound from the lab PC, certificate pinning to `*.microsoftonline.com` and `*.blob.core.windows.net` (validated by OS trust store).
- **Z1 → Z4:** Cert-based SP authn. Workstation proves it has the private key (it never leaves the cert store).
- **Z4 → Z6:** SP token grants `Get Secret` on a single secret name (the rotated SAS).
- **Z6 → Z7:** SAS grants write-only on a single container.
- **Z8 → Z7:** Consumer RBAC grants read on the container, no write, no delete.

Anything trying to traverse a trust boundary outside these named crossings is a red flag.

---

## 3. Threat actors

We model six. Each is named, each gets a defense, each gets a test.

### T1 — Insider Analyst (low-skill, legitimate lab access)

**Capability:** Knows the shared workstation login. Can log in, copy any file off the box, see anything on disk.
**Goal:** Either curiosity, exfil, or accidental damage.
**Defenses:**
- Cert is in `Cert:\CurrentUser\My` of a *service account* used only by the scheduled task — analyst's interactive login does not have access.
- Even if analyst extracts the cert (admin elevation), it's write-only on a single container. Cannot read or delete anything.
- Cert lifetime ≤ 90 days; rotation procedure documented.
**Tests:** `tests/01-threat-model-defense.md` T1.1, T1.2.

### T2 — Lifted-Credential Adversary (cert or SAS exfiltrated)

**Capability:** Has the SP cert, OR has a current SAS token, but not lab-PC physical access. Tries to use them remotely.
**Goal:** Read or delete prior backups.
**Defenses:**
- SP RBAC role: `Storage Blob Data Contributor` *scoped to one container only*, with explicit deny on read for production data via separate role design — actually we use **a custom role `lab-pc-writer` with only `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write` and `…/add/action`** (no read, no delete).
- SAS: explicit `sp=racw` minus `r` and `d` and `l` — i.e., `sp=acw` — write/add/create only, single container, ≤24h lifetime.
- Immutable blob policy with time-based retention prevents delete *even with the right credential*.
- Diagnostic Settings log every auth event with source IP. Anomalous source IP triggers alert.
**Tests:** `tests/01-threat-model-defense.md` T2.1, T2.2, T2.3.

### T3 — Compromised Lab Workstation (malware / ransomware in residence)

**Capability:** Full local control of the workstation. Can read disk, intercept process memory, install a keylogger.
**Goal:** Encrypt or exfiltrate the durable copy.
**Defenses:**
- The push script writes; it does not read prior backups. Even with full local control, the attacker cannot use the script's credential to delete or read.
- Immutable retention prevents the durable copy from being encrypted.
- Audit trail exists in a separate trust zone (Z7 → Log Analytics in a different RG, possibly a different subscription) — the malware on Z1 cannot tamper with Z7's logs.
**Tests:** `tests/04-failure-modes.md` F3.1.

### T4 — Rogue Local Admin (legitimate IT or contractor with admin on lab PC)

**Capability:** Admin on the lab PC. Can install software, read any cert store, modify scheduled tasks.
**Goal:** Disable backup silently, or extract credentials for later use.
**Defenses:**
- Scheduled task health is monitored via the *Azure side* — the storage account's "last write timestamp" per workstation is alerted on. If a workstation stops pushing for 25 hours, an alert fires. The rogue admin cannot disable that detection from the lab PC.
- Cert is non-exportable at install time (`-KeyExportable:$false` in `Import-PfxCertificate`). A motivated admin can still lift it via tooling, but they trip the audit trail when they use it.
- Code-signing requirement on the script (defense-in-depth; replacing the script silently fails Group Policy).
**Tests:** `tests/04-failure-modes.md` F4.1, F4.2.

### T5 — Network On-Path Observer (lab egress MITM)

**Capability:** Passive sniffing or active MITM on the lab egress network.
**Goal:** Intercept files in transit, or capture credentials.
**Defenses:**
- TLS 1.2+ enforced at the storage account (`minimumTlsVersion: TLS1_2`) and Key Vault.
- Cert-based SP authn never sends the private key over the wire (signed assertion only).
- SAS in transit is bearer-grade but short-lived (≤24h) and write-only.
**Tests:** `tests/01-threat-model-defense.md` T5.1.

### T6 — Curious Consumer (legitimate RBAC reader on consumer side)

**Capability:** Has read on the container from their own desktop. Tries to delete or tamper with files.
**Goal:** Cover up a mistake, or pivot to write access.
**Defenses:**
- Consumer RBAC role: `Storage Blob Data Reader` only. No write, no delete.
- Immutability prevents delete even if RBAC misconfigured.
- All read events logged with caller identity and source IP.
**Tests:** `tests/01-threat-model-defense.md` T6.1.

---

## 4. Out-of-scope threats (explicitly accepted)

Naming these so future readers know we *thought about them and chose not to defend against them*.

| ID | Threat | Why out of scope |
|----|--------|------------------|
| OOS-1 | Microsoft / Azure platform compromise | We trust the cloud provider. If Microsoft is breached, the design is moot. |
| OOS-2 | Quantum-break of TLS or Entra | Not a current-decade threat; defense would be replacing protocols, not architecture. |
| OOS-3 | Physical destruction of lab PC before next push window | The system is a *push-on-schedule* backup, not a real-time mirror. Files created and destroyed within one push interval are lost. **Mitigated by:** documented push frequency in component README; deployer sets to match their tolerance for loss. |
| OOS-4 | Subscription Owner-level rogue | A Subscription Owner can delete the resource group regardless of design. **Partial mitigation:** subscription-level Resource Lock recommended in RUNBOOK; storage account-level CanNotDelete lock applied by deploy script. |
| OOS-5 | Supply-chain attack on PowerShell / Az modules / PSGallery | **Partial mitigation:** bootstrap pins module versions; future improvement is to mirror modules to a private gallery. |
| OOS-6 | Lab data confidentiality at rest on the lab PC itself | The workstation is hostile territory; if confidentiality of raw files on disk matters, that's a different project (BitLocker, drive encryption, DLP). |

---

## 5. Compliance assumptions and hooks

Per ADR-000, we are CIS-aligned with GxP-ready hooks. The relevant CIS Azure Foundations Benchmark v5.0 controls this design satisfies (or is structured to satisfy):

| CIS Control | How we satisfy it |
|-------------|-------------------|
| 3.1 Ensure that 'Secure transfer required' is set to 'Enabled' | `supportsHttpsTrafficOnly: true` on the Storage Account |
| 3.7 Ensure that 'Public access level' is set to Private | `allowBlobPublicAccess: false` |
| 3.8 Ensure 'Default Network Access Rule' is set to Deny | (optional flag in deploy; default off for first-time deployers, recommended on in RUNBOOK) |
| 3.13 Ensure Storage logging is enabled for the Blob service for read/write/delete | Diagnostic Setting on the blob service |
| 3.14 Ensure Soft Delete is enabled for blob | `deleteRetentionPolicy.enabled: true`, 14 days |
| 5.1.x Activity Log to Log Analytics workspace | Subscription-level diagnostic setting in deploy |
| 7.1 Ensure Key Vault is recoverable | `enableSoftDelete: true`, `enablePurgeProtection: true` |
| 8.5 Ensure that no custom subscription owner roles are created | We do not create any |

GxP upgrade hooks:
- Retention default 90 days → can be extended to 7 years via parameter
- Time-based retention → legal hold can be added without redeploy
- Audit log retention default 90 days → extendable to 365+ via Log Analytics retention

---

## 6. Cross-Agent Review

### 🏗️ Architect
Signed. The crossings (§2) are the input to the component decomposition. Each crossing becomes the contract of one Atomic Lego.

### 🛡️ Security Engineer
Signed, with two flags carried forward:
1. T4 (Rogue Local Admin) defense relies on detection rather than prevention. If the deployer's environment cannot tolerate the alert latency, this needs hardening (e.g., per-workstation cert with online revocation list).
2. The "explicit deny on read" semantics in T2 require careful RBAC role construction. The component README for `03-service-principal-auth` must enumerate the exact role JSON.

### 🔧 Operator
Signed. T4 alert ("workstation stopped pushing for 25h") is an operator-owned control and must appear in `tests/04-failure-modes.md` and `RUNBOOK.md`.

### 📚 Documentarian
Signed. This document is the canonical reference for §2 trust zones (Z1–Z8) and §3 actor IDs (T1–T6). Other documents must cite by ID, not redefine.
