# Air-Gapped Lab Workstation Backup → Immutable Azure Blob

**Captured:** 2026-04-28
**Outcome:** This design shipped. The full IaC, test battery, and workstation bootstrap were built autonomously over a 31-hour Claude Code session starting 2026-04-30, with one additional component (automated SAS rotation) added 2026-05-08. The system has been in production since 2026-04-30 with 97+ blobs verified.

This document is the inception artifact — the design thinking captured before the build. It shows the problem framing, the auth options considered and rejected, and the reasoning that drove the layered credential architecture. The `Interview-frame version` section at the bottom is how this design was being articulated at the time; the full build is the proof it held up.

---

## The Problem

Shared lab workstations. Workstation OS, not server. Generic logins (multiple analysts use the same physical PC, same credentials). Not domain-joined. No central credential authority.

Files on these machines feed downstream analysis. If a machine crashes mid-day, the work is gone.

Traditional backup doesn't fit:

- Workstation OS, most enterprise backup products are licensed and built for servers
- No domain join, no central credential store
- Generic shared logins mean any credential left on disk is portable to anyone with access
- Analysts shouldn't have to physically walk to each machine to retrieve their files
- The lab machine has to be assumed hostile, anything on disk can be lifted

---

## Requirements

1. Files leave the machine on a schedule, no human action required
2. Files land where the lab group can access them from their own desks
3. Once landed, files cannot be deleted (immutability + retention)
4. Nothing on the lab PC can be used to:
   - Steal data
   - Delete the backup
   - Pivot into the storage account
5. Cost stays inside the lab group's subscription (their data, their bill)
6. Runs without humans touching it

---

## The Design

A scheduled task on the lab machine pushes files to an Azure Storage account. The task can be as simple as a batch file or PowerShell script invoked by Task Scheduler. No agent, no license, no backup product.

### The auth problem

The lab machine is hostile territory. Whatever auth method is used has to be:

- Write-only (push files, can't read or delete what's already there)
- Scoped to one container (no pivot to other storage)
- Either short-lived or worthless if extracted

### The chicken-and-egg

If the script pulls credentials from Key Vault at runtime, what authenticates the script to Key Vault? The credential problem moves one layer back. There has to be *something* on the lab machine that proves it's allowed to call Key Vault. That something becomes the new theft target.

So the question is: what's the smallest, least-stealable, most-rotatable thing that can sit on a lab PC?

### Auth options considered

**Option A — Certificate-based Service Principal**

Lab machine holds a `.pfx` with a private key. Python script uses cert to authenticate to Azure AD, gets a token, writes directly to storage *or* pulls a SAS from Key Vault.

- Cert is bound to the machine
- Cert can be rotated on a schedule (30/60/90 day cycle)
- No human-readable secret on disk
- SP scoped write-only on a single container
- Risk: someone with admin on the lab PC can copy the cert; mitigated by short lifetime

**Option B — SAS token rotated daily, fetched from Key Vault**

External process (Function, Logic App, GitHub Action) generates a fresh write-only SAS token daily, writes it to Key Vault. Lab machine pulls it.

- Cleanest credential rotation
- Still requires Key Vault auth from the lab machine, loops back to Option A's problem

**Option C — Layered (recommended landing point)**

Cert-auth Service Principal → Key Vault → daily-rotated SAS token → write to immutable blob.

- Two layers of separation
- Cert gets you in the door
- SAS does the actual write
- SAS rotates daily, cert rotates quarterly
- If either is stolen: blast radius is small, time-bounded, write-only, destination is immutable

### Why Managed Identity isn't the answer

Managed Identity is Azure's preferred pattern for this kind of thing. But MI only works on Azure-hosted compute (VMs, Functions, App Service). Lab boxes are on-prem workstations, not Azure resources. So MI is off the table unless you Arc-enable the lab machines, which is a much bigger commitment (Arc agent, ongoing management, possibly licensing) and almost certainly overkill.

Certificate-based SP is the on-prem analogue of MI. Right answer for hostile-host, non-Azure compute.

---

## Storage-side controls

The destination does the heavy lifting once the file lands:

- **Immutable blob storage** with legal hold or time-based retention policy
- **Versioning** as a second layer of protection
- **Retention lock** so the backup outlives the credential

Even if a credential gets lifted and someone tries to delete, they can't.

---

## Access pattern for consumers

Lab group accesses their data from their own desks via their own RBAC, completely separate from the lab-machine identity. They never touch the lab PC to recover files.

This is the self-service piece. The analysts can pull their own files on their own time, no walkup, no ticket, no IT involvement after deploy.

---

## Why this design holds up

This isn't a backup-product story. It's a threat-model story.

- **Engineering judgment first.** The standard answer (deploy a backup product) doesn't work here. Reading the constraints (workstation OS, generic login, no domain, hostile-host model) drives the design, not the toolkit.
- **Threat modeling.** Assume the lab machine will be compromised. Design for that, not against it. Write-only credential, immutable destination, retention lock.
- **Cost discipline.** Files land in the lab group's subscription. The right team pays for their own storage.
- **Minimum viable execution.** Batch file on a scheduled task. No new product, no new license, no new agent. The least clever solution that meets every requirement.
- **Self-service for the consumers.** Analysts go to their desks and get their files.

---

## Interview-frame version (for LightEdge and similar conversations)

> "We had shared lab workstations with generic logins. Anything on disk had to be assumed compromised. So I designed a write-only push to an immutable blob target, with the credential rotated daily out-of-band. The auth model traded off between certificate-based service principal and SAS rotation, and I landed on a layered approach because no single credential on a hostile host can be both convenient and secure."

That's a 30-second answer that demonstrates threat-modeling, Azure fluency, and the discipline to not over-engineer.

---

## LinkedIn-post raw material

Hooks worth pulling out of this design later:

- "How do you back up a workstation that has a generic login and lives on the wrong side of the trust boundary? You don't, you push from it instead."
- "The cleverest part of this design is that it doesn't use a backup product at all."
- "If your auth model assumes the host is honest, your auth model is wrong."
- "Managed Identity is the right answer, until your compute isn't in Azure. Then it's certificate-based SP."

---

## Open items

- Confirm whether this shipped to production or stayed at design phase. Both have value, just different stories.
- If it shipped: capture which auth model actually deployed, capture the file count / volume / retention period if known.
- If design-only: note what blocked it from shipping (budget, priority, scope decision), that's also a useful interview answer.
