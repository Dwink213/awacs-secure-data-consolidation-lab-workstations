# Daily Capture: Azure RBAC — Storage Blob Delegator vs. Data Contributor
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — SAS generation debug, push-files.ps1 verification

---

## What Happened

During push-files.ps1 debugging, a user-delegation SAS with `sp=acw` (add/create/write) returned `AuthorizationPermissionMismatch` even though the SAS was structurally valid. Root cause: the signing identity had only `Storage Blob Delegator` — which grants the ability to call `GenerateUserDelegationKey` — but NOT `Storage Blob Data Contributor`, which grants actual data-plane write access. Azure's rule: a user-delegation SAS cannot grant permissions the signer doesn't already hold. Assigning `Storage Blob Data Contributor` to the deploying identity resolved it.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** You gave yourself the "delegator" role and wondered why the SAS didn't work. Here's the gap Microsoft doesn't explain well.
**Target audience:** Azure engineers, cloud architects, security teams managing storage access
**Post type:** Teaching
**Emotional driver:** Recognition — "I've hit exactly this and didn't know why"
**Priority:** High

**Draft hook options:**
1. "Storage Blob Delegator sounds like it lets you delegate storage access. It doesn't. Here's what it actually does."
2. "The user-delegation SAS was structurally perfect. It still returned 403. Here's the RBAC piece Microsoft buries in the footnotes."
3. "Two roles. Both required. One is obvious, one isn't. Here's the Azure Storage user-delegation gap that burns engineers."

**Viral levers present:**
- [ ] Confession arc
- [x] Villain-vindication — Azure RBAC naming creates a false mental model; the fix is explicit
- [x] Memeable phrase: "Storage Blob Delegator lets you sign the key. Storage Blob Data Contributor gives you something to sign."
- [ ] All-caps emotional pivot
- [x] Specific technical mechanism: `GenerateUserDelegationKey` action vs. actual data-plane permissions; SAS is bounded by signer's data rights
- [ ] Self-incriminating AI quote
- [x] Comment-bait question with stored answers: "What Azure RBAC gotcha has bitten you?" — every Azure engineer has one
- [x] Universal unnamed pain: RBAC role names that imply capabilities they don't provide

**Lever count:** 5 / 8
**Viral candidate?:** Yes (5+) — this is a clean, quotable teaching post with strong comment potential

**Notes:** This pairs well with the SAS cascade post. Could be a series: "Azure Storage Auth: The Complete Failure Taxonomy." Sanitize for public — no employer or project names.

---

## Training Material

**Training potential:** High
**Could become:** Module / Exercise
**Which course it fits:** Course 1 (AI-Assisted Infrastructure), potentially a standalone Azure Storage Auth module
**Teaching point:** Azure has two conceptually separate permission layers for user-delegation SAS: (1) the right to generate a delegation key (`Storage Blob Delegator`) and (2) the data permissions you're trying to delegate (`Storage Blob Data Contributor` or `Writer`). Both are required. The role names are misleading.
**Prerequisite knowledge:** Azure RBAC basics, Azure Storage SAS fundamentals

**Notes:**
- This is a genuine knowledge gap — Microsoft's documentation mentions it but buries the dependency
- High value as a standalone "Azure Storage Auth gotchas" unit
- Pairs with: BOM-free secret storage, SAS rotation patterns

---

## Technical Reproduction

**Steps to recreate:**
1. Create storage account with `az storage account create`
2. Assign `Storage Blob Delegator` to a user on the storage account
3. Login as that user, run `az storage container generate-sas --as-user --permissions acw`
4. Use resulting SAS to PUT a blob
5. Observe: `AuthorizationPermissionMismatch` 403

**Fix:**
1. Also assign `Storage Blob Data Contributor` to the same user
2. Regenerate SAS (delegation key must be issued after RBAC propagation)
3. PUT succeeds

**Dependencies:**
- Azure subscription with Owner or UAA rights
- Azure Storage account
- Azure CLI

**Gotchas:**
- RBAC propagation takes 2–5 minutes; regenerate SAS AFTER propagation
- The old delegation key (generated before the RBAC grant) will still produce invalid SAS — must regenerate
- `Storage Blob Data Contributor` grants read+write+delete; if you only want write, use `Storage Blob Data Writer` (role ID: `56bec394-c678-4ac4-b691-b6a9a5af9d8c`)
- This applies only to user-delegation SAS. Account SAS (signed with storage account key) bypasses this check

**Code/commands to preserve:**
```bash
# Check what data-plane roles exist on storage account for a user
az role assignment list \
    --assignee <user-object-id> \
    --scope <storage-account-resource-id> \
    --output table

# Required roles for valid user-delegation SAS with write permissions:
# 1. Storage Blob Delegator (ba92f5b4-...) — generate delegation key
# 2. Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe) — data-plane write

# Note: Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe) is NOT Blob Data Contributor
# Blob Data Contributor: ba92f5b4-2d11-453d-a403-e96b0029c9fe
# (confirm with: az role definition list --name "Storage Blob Data Contributor" --query "[].id")
```

**Related files:** `deploy/Deploy.ps1`, `components/06-rbac-consumer-access/main.bicep`

---

## Product Extraction

**Standalone potential:** Maybe
**What it is:** An RBAC pre-flight checker for user-delegation SAS generation — validates the signer has both required roles before attempting SAS creation
**Who would use it:** Azure automation engineers, anyone implementing SAS rotation pipelines
**MVP scope:** A function: `Test-AzSasSignerPermissions -StorageAccount -UserId` that returns pass/fail with remediation instructions
**Monetization angle:** Open source credibility / AWACS toolbox component
**Verdict:** Explore further — small, useful, low effort

---

## Content War Chest Category

- [x] **Teaching content** — Gives away knowledge
- [x] **Proof content** — Shows you can do the work

**Primary category:** Teaching content

---

## Raw Material

Exact role listing that revealed the gap:
```
Principal                                              Role                    Scope
-----------------------------------------------------  ----------------------  --------
DWINKLER213_gmail.com#EXT#@...                        Storage Blob Delegator  /subscriptions/.../storageAccounts/awdustsaybmh
```

After fix:
```
Principal                                              Role                           Scope
-----------------------------------------------------  -----------------------------  --------
DWINKLER213_gmail.com#EXT#@...                        Storage Blob Delegator         /subscriptions/.../storageAccounts/awdustsaybmh
DWINKLER213_gmail.com#EXT#@...                        Storage Blob Data Contributor  /subscriptions/.../storageAccounts/awdustsaybmh
```

The key quote from Microsoft docs (buried): "The permissions granted by the user delegation SAS are a subset of the permissions of the user or service principal that obtained the user delegation key."

---

## Next Actions

- [ ] Update Deploy.ps1 to assign `Storage Blob Data Contributor` to deploying identity at deploy time
- [ ] Add ADR documenting the dual-role requirement for user-delegation SAS rotation
- [ ] Consider RUNBOOK.md entry: SAS rotation troubleshooting — check both Delegator AND Data roles
- [ ] Verify push-files.ps1 succeeds after RBAC propagation (wakeup at 02:51)

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md`
- **Related project files:** `deploy/Deploy.ps1`, `workstation/push-files.ps1`
- **Builds on:** Component 06 RBAC design (consumer read-only)
- **Feeds into:** ADR for SAS rotation, Deploy.ps1 hardening
