# Daily Capture: End-to-End Push Verified — 78/78 Files in Immutable Storage
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — full system verification on DESKTOP-0DBOTVV

---

## What Happened

After resolving a four-layer error chain (SAS truncation → BOM corruption → RBAC permission gap → propagation delay), the complete cert-to-blob pipeline was verified end-to-end at 03:01:16. The push script authenticated via certificate, fetched the SAS from Key Vault, identified 78 files in `C:\Users\Dustin\Downloads\`, uploaded all 78 to `awdustsaybmh/lab-files` under WORM immutability policy, updated the local ledger, and exited clean. 79 blobs confirmed in the container (78 workstation files + 1 RBAC test blob). The `AwacsBackupPush` scheduled task runs every 30 minutes automatically going forward.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** I deployed a zero-trust secure backup system from scratch overnight. Here's what the first real push looked like — and the four errors that almost stopped it.
**Target audience:** Azure engineers, IT security, DevOps, cloud architects
**Post type:** Proof + Story
**Emotional driver:** Satisfaction after struggle — the system works
**Priority:** High

**Draft hook options:**
1. "78 files. 4 errors fixed. 1 working backup pipeline. Here's the full chain from cert auth to immutable blob — built overnight, verified this morning."
2. "The push script hit 4 different errors. Each one looked different. They all had the same root cause. Here's what finally made it work."
3. "I built a zero-trust file backup system for lab workstations. No managed identity. No public access. No account keys. Just a cert, a Key Vault, and a write-only SAS. It works."

**Viral levers present:**
- [x] Confession arc — 4 errors before success; each one documented honestly
- [x] Villain-vindication — SAS token storage was the villain; BOM-free WriteAllText was the fix
- [x] Memeable phrase: "The cert authenticated. The SAS fetched. The blobs landed. Four errors to get here."
- [ ] All-caps emotional pivot
- [x] Specific technical mechanism: cert → SP auth → KV SAS fetch → container PUT with user-delegation SAS → WORM blob written
- [ ] Self-incriminating AI quote
- [x] Comment-bait question with stored answers: "What's your most ridiculous Azure auth debugging chain?" — every Azure engineer has one
- [x] Universal unnamed pain: The working system that looks identical to the broken system right up until it isn't

**Lever count:** 5 / 8
**Viral candidate?:** Yes (5+)

**Notes:** This post pairs with the SAS cascade post. Consider writing them as a two-part series: "Part 1: The four errors" → "Part 2: The system that finally worked." The proof element (actual blob names, real timestamps, real file names like `TurboTaxReturn.tax2024`) makes it credible. Sanitize file names for public posts.

---

## Training Material

**Training potential:** High
**Could become:** Case study / Live demo
**Which course it fits:** Course 1 (AI-Assisted Infrastructure)
**Teaching point:** This is the complete architecture in motion: service principal cert auth, Key Vault secret retrieval, SAS-based blob write, WORM immutability, local ledger for dedup. Students can see every layer working together in a single run.
**Prerequisite knowledge:** Azure Storage, Key Vault, service principals, PowerShell Az module

**Notes:** The full push log is the teaching artifact — every step logged with timestamps, cert expiry check, SAS length/prefix validation, per-file sha256, ledger update. This is what production-quality diagnostic logging looks like.

---

## Technical Reproduction

**Steps to recreate:**
1. Deploy IaC: `./deploy/Deploy.ps1 -Prefix <p> -SubscriptionId <sub> -Region eastus2`
2. Bootstrap workstation: `./workstation/bootstrap.ps1 -ConfigPath ./out/<p>-workstation-config.json -CertPath ./out/<p>-sp-cert.pfx -CertPassword <pw>`
3. Generate SAS: `az storage container generate-sas --name lab-files --account-name <sa> --auth-mode login --as-user --permissions acw --expiry <24h>` — store via `--file` with `UTF8Encoding($false)`
4. Run push: `powershell.exe -File C:\ProgramData\AwacsBackup\push-files.ps1`
5. Verify: `az storage blob list --account-name <sa> --container-name lab-files --auth-mode login --output table`

**Dependencies:**
- Azure subscription with Owner access
- Windows 11 workstation
- Az modules 2.13.2 / 6.1.1 / 5.0.1
- Git OpenSSL for PEM→PFX conversion

**Environment:**
- DESKTOP-0DBOTVV, Windows 11, PS 5.1
- Azure subscription 49521d08-4a34-4355-a069-919af69ad956
- RG: awdust-rg, eastus2

**Gotchas (full list from this session):**
- `Install-Module` hangs non-interactively without NuGet provider pre-install
- `TimeSpan.MaxValue` as RepetitionDuration overflows Task Scheduler XML
- `LogonType S4U` requires admin; use `Interactive` for interactive workstations
- SAS tokens contain `&` — use `--file` not `--value` with `az keyvault secret set`
- PowerShell 5.1 `Out-File -Encoding utf8` adds 3-byte BOM — use `System.Text.UTF8Encoding($false)`
- `Storage Blob Delegator` alone is not enough for user-delegation SAS — also need `Storage Blob Data Contributor`
- RBAC propagation: 2–5 minutes; regenerate SAS AFTER propagation
- Background push tasks for large files (100MB+) need timeout > 5 minutes

**Code/commands to preserve:**
```
Push log summary:
[02:52:54] [INFO] Push starting on DESKTOP-0DBOTVV
[02:52:57] [INFO] AAD auth OK
[02:53:02] [INFO] SAS fetched (length: 270, starts: se=20)
[02:53:03] [INFO] Files to push: 78 of 78 total
[02:53:08–03:01:15] [INFO] PUT OK: [78 files, 6.5MB to 352MB]
[03:01:16] [INFO] Ledger updated with 78 new entries
[03:01:16] [INFO] Push complete: 78 files pushed.
```

**Related files:** `workstation/push-files.ps1`, `C:\ProgramData\AwacsBackup\pushed.json`, `docs/session-notes/SESSION_2026-04-30.md`

---

## Product Extraction

**Standalone potential:** Yes
**What it is:** A complete turnkey zero-trust workstation backup system for Azure — deploy, bootstrap, push, verify, teardown in one repo
**Who would use it:** IT operations teams, research labs, regulated environments (GxP-adjacent, FedRAMP-interested), any organization with shared workstations and data residency requirements
**What it needs for GitHub:**
- [x] All IaC, scripts, bootstrap, tests already in repo
- [ ] SAS rotation automation (currently manual)
- [ ] Multi-workstation documentation (one workstation tested; the system scales by design)
- [ ] Cost estimation in README
- [ ] `git clone` + one-command deploy demonstration (video or GIF)

**MVP scope:** What's already in the repo. The system is deployable today.
**Monetization angle:** Open source credibility → AWACS training + managed deployment service
**Competitors/alternatives:** Azure Backup (overkill, expensive, not workstation-focused), robocopy + SFTP (no immutability, no audit trail), OneDrive (not air-gapped, not WORM)
**Verdict:** Build it — it's already built. Next: GitHub publish + README polish + SAS rotator

---

## Content War Chest Category

- [x] **Proof content** — Working system, verified, with logs
- [x] **Teaching content** — Complete implementation reference
- [x] **Product content** — Actual deployable thing

**Primary category:** Proof content

---

## Raw Material

Final push log (abbreviated):
```
[02:52:54] Push starting on DESKTOP-0DBOTVV
[02:52:57] AAD auth OK
[02:53:02] SAS fetched (length: 270, starts: se=20)
[02:53:03] Files to push: 78 of 78 total
[02:53:08] PUT OK: (System By Scars) - Agent Roll Call Remix.mp3 (6.5MB)
[02:54:49] PUT OK: Git-2.53.0.2-64-bit.exe (64MB)
[02:56:05] PUT OK: VSCodeUserSetup-x64-1.112.0.exe (131MB)
[02:58:59] PUT OK: VSProjects.zip (352MB)
[03:01:15] PUT OK: KGD-Ebook1_Claude-Code-Managing-Azure-Local.pdf
[03:01:16] Ledger updated with 78 new entries
[03:01:16] Push complete: 78 files pushed.
```

Blob count verification:
```
az storage blob list → 79 blobs total
DESKTOP-0DBOTVV/2026-04-30/[78 workstation files]
test/awacs-rbac-check.txt [RBAC verification blob]
```

---

## Next Actions

- [ ] Publish repo to GitHub (Dustin to confirm scope of public disclosure)
- [ ] Add SAS rotation automation to Deploy.ps1 (currently seeds 24h SAS; needs scheduled rotation)
- [ ] Update Deploy.ps1 to auto-assign `Storage Blob Data Contributor` at deploy time
- [ ] Polish README with `git clone` + deploy GIF / screenshot
- [ ] Test a second workstation bootstrap to verify multi-workstation isolation

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md`, `AWACS_daily-capture_2026-04-30_azure-rbac-delegator-vs-contributor.md`, `AWACS_daily-capture_2026-04-30_bootstrap-completion-fix.md`
- **Related project files:** `workstation/push-files.ps1`, `deploy/Deploy.ps1`, `docs/session-notes/SESSION_2026-04-30.md`
- **Builds on:** All prior session work — IaC, test battery, architecture
- **Feeds into:** GitHub publish, AWACS training Course 1, SAS rotation product component
