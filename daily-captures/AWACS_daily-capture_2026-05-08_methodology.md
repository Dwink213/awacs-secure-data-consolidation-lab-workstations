# Methodology Capture: Split-Brain Trust and Layered Diagnosis
**Date:** 2026-05-08
**Session source:** AWACS Secure Lab Backup — authentication failure triage
**Book chapter affinity:** Chapter 2 (Ground Truth) + Chapter 6 (The Human Layer)

---

## Session Arc

The session opened with a vague symptom: "the system is failing to authenticate." Memory immediately surfaced that the system had been DEGRADED for 6 days due to an expired SAS token — so the initial hypothesis was correct. But that hypothesis was wrong. The SSL failure blocking Azure CLI wasn't the SAS token at all — it was Norton Antivirus intercepting TLS. The session then became a layered diagnostic: identify the interceptor, understand why one tool saw it and another didn't, progressively unblock each Azure domain family, and finally rotate the SAS once the path was clear. The ending state: both the SSL interception and the expired SAS were resolved, and the system returned to LIVE.

---

## Decision Sequences

### Starting with memory, then verifying — not assuming
**Starting assumption:** Memory said SAS token expired 2026-05-01. The authentication failure was probably that.
**What happened:** Azure CLI could authenticate (`az account show` returned data), but any live API call to Key Vault or Storage failed with SSL errors — not auth errors. The symptom pattern didn't match a SAS expiry.
**Pivot point:** The error was `CERTIFICATE_VERIFY_FAILED`, not `AuthorizationFailure`. Certificate errors precede authentication. The diagnosis shifted from "credentials" to "transport."
**Final decision:** Investigate the TLS layer before touching credentials.
**Transferable principle:** Match the symptom to the layer. Auth errors are application-layer. Certificate errors are transport-layer. They look similar ("can't connect to Azure") but have completely different root causes and diagnostic paths.

### Two tools, one host, different results — the split-brain indicator
**Starting assumption:** If PowerShell can reach `login.microsoftonline.com`, the network is fine and the problem is in Azure CLI config.
**What happened:** PowerShell succeeded. Azure CLI's Python failed. Same host, same port, same network. The divergence pointed to the trust store — not the network, not the credentials, not the CLI version.
**Pivot point:** Inspecting the cert issuer via .NET (`HttpWebRequest`) vs. Python (`ssl.wrap_socket`) showed different issuers for the same host. That's the diagnostic signature of TLS interception.
**Final decision:** Norton is re-signing the certs. The fix is exclusion, not cert patching.
**Transferable principle:** When two tools disagree about the same endpoint, the disagreement IS the data. Don't fix the "broken" tool — figure out why the two tools see different things.

### Progressive domain exclusion — one family at a time
**Starting assumption:** Excluding `login.microsoftonline.com` from Norton SSL scanning would fix all Azure CLI operations.
**What happened:** Login started working. Key Vault still failed (`*.vault.azure.net`). Vault exclusion added. Storage still failed (`*.blob.core.windows.net`). User disabled Norton entirely.
**Pivot point:** Each exclusion exposed the next blocked domain. Norton's SSL scanning was applied per-domain, not per-application — no single exclusion covered all Azure CLI traffic.
**Final decision:** User chose to disable Norton SSL scanning entirely rather than enumerate all Azure domains.
**Transferable principle:** When fixing TLS interception by exclusion, map the full set of domains a tool needs before starting — don't discover them one error at a time. For Azure CLI: `login.microsoftonline.com`, `management.azure.com`, `*.vault.azure.net`, `*.blob.core.windows.net`, `*.core.windows.net` at minimum.

---

## Human Judgment Moments

- **Moment:** Memory said "SAS token expired — rotate immediately." User asked to check Azure instead of immediately rotating.
  **The judgment call:** Verify current state before executing the remembered fix.
  **Why process alone wouldn't have gotten here:** The memory was 6 days old. If we'd rotated immediately without checking, we'd have generated a new SAS token that also couldn't be written to Key Vault (due to the SSL failure). The rotation would have appeared to succeed but silently failed.
  **Outcome:** Correct call. The SSL issue had to be cleared first. Memory was right about the SAS but wrong to assume it was the only problem.

- **Moment:** After three rounds of Norton domain exclusion, user disabled Norton entirely instead of continuing to enumerate domains.
  **The judgment call:** Stop the protocol and take the blunt instrument.
  **Why process alone wouldn't have gotten here:** The "correct" process was to identify all Azure domains and add them systematically. That could have taken several more iterations. The user recognized diminishing returns and switched strategies.
  **Outcome:** System unblocked immediately. Trade-off accepted: Norton SSL scanning disabled (reduced security posture) in exchange for unblocking the session. Decision is time-bounded — user can re-enable Norton with proper exclusions later.

---

## Discipline Practices Applied

- [x] **Institutional memory capture** — memory file consulted at session open; correctly surfaced DEGRADED state and SAS expiry
- [x] **Ground truth before live calls** — verified cert chain issuer before attempting fixes; compared .NET vs. Python trust explicitly
- [x] **Session-end capture** — this document
- [ ] Pattern → ADR in same session — the "two trust stores" pattern wasn't formalized as an ADR this session
- [ ] Compounding knowledge capture — Norton exclusion domains not yet added to `workstation/troubleshooting.md`

**New practice observed this session:**
**Split-brain trust diagnosis** — when a symptom manifests in one tool but not another for the same endpoint, use each tool's trust model as the diagnostic lens. Compare cert chain issuers across runtimes (OS, Python, Java, etc.) to locate where interception is happening. This is a distinct diagnostic technique from standard SSL debugging and should be a named step in any "az CLI cert verification failure" runbook.

---

## Compounding Effects

**What this session left behind that makes the next session better:**

| Artifact | What it does for future sessions |
|----------|----------------------------------|
| `STATUS.md` updated to LIVE with new SAS expiry | Session opener immediately knows system state and next rotation deadline |
| Memory file updated with Norton SSL context | Next session won't re-diagnose the same issue if Norton is re-enabled |
| `~/.azure-ca/cacert.pem` with Norton root appended | If Norton is re-enabled, the patched bundle is ready to use with `az config set core.cafile` |
| Rotation commands confirmed canonical in STATUS.md | Next rotation is a copy-paste, not a recall exercise |

**Knowledge base delta:** Memory file updated with Norton SSL issue, new SAS expiry, and V2 priority elevation for rotation automation.
**Tooling delta:** `~/.azure-ca/cacert.pem` created (Norton-aware certifi bundle). `az config set core.cafile` config written and then cleared.
**Rule delta:** None encoded in CLAUDE.md this session — the Norton SSL fix is environment-specific, not a universal rule.

---

## Anti-Patterns & Time Sinks

- **Time sink:** Three rounds of Norton domain exclusion, discovering one blocked domain per round.
  **Root cause:** Started fixing before mapping the full attack surface. Applied the fix to the first failing domain instead of enumerating all domains Azure CLI touches first.
  **Prevention for next time:** When diagnosing TLS interception for a CLI tool, list all endpoints the tool uses before starting exclusion. For Azure CLI, that list is documented in `workstation/troubleshooting.md` (or will be after today's next action items are complete).

- **Time sink:** Attempted `az config set core.cafile` and environment variable approaches that didn't propagate to the az subprocess.
  **Root cause:** Assumed the fix (patching the CA bundle) would work the same way as documented, without verifying whether the env var was actually reaching the child process.
  **Prevention for next time:** Test env var propagation explicitly before assuming it works. In PowerShell, child processes launched via `.cmd` wrappers don't always inherit session env vars set mid-session.

---

## The Compounding Story

This session is a case study in why memory and ground-truth verification can't be separated. The memory was correct — the SAS token had expired. But acting on memory alone, without verifying current system state first, would have produced a failed rotation that looked like a success. The SSL failure would have silently swallowed the Key Vault write. The discipline of checking actual state before executing remembered procedures is what separated "system fixed" from "system still broken but now we don't know why."

The split-brain trust diagnosis — comparing what different runtimes see from the same endpoint — is a technique that most engineers know abstractly but rarely apply explicitly. The signature is: same host, same port, different result in two tools. When that pattern appears, the divergence is the diagnosis. The fix is in the trust model difference, not in either tool individually. This session made that pattern explicit and repeatable.

The progressive Norton domain discovery is an anti-pattern worth naming: "enumerate before you exclude." When unblocking a tool from TLS interception, the right move is to list all domains the tool uses, then add them to the exclusion list in one operation. Discovering domains one failed call at a time is slower, more frustrating, and creates the illusion of progress (each exclusion works!) while the underlying problem persists.

---

## Book Chapter Affinity

**Primary chapter:** Chapter 2 (Ground Truth) — the session turned on verifying actual state before acting on memory
**Secondary chapters:** Chapter 6 (The Human Layer) — two human judgment calls shaped the session outcome; Chapter 8 (Anti-Patterns) — progressive domain exclusion as a named anti-pattern
**Key quote or insight for the book:** "Memory told us what was wrong. Ground truth told us what was actually wrong. They weren't the same thing — and only one of them could fix the system."

---

## Book Flavor Tags

- [x] **Confession moment** — "the system is failing to authenticate" turned out to be Norton, not the system; the memory-based hypothesis was wrong
- [x] **Villain-vindication arc** — Norton cast as the villain (legitimately); exclusion list as the engineered fix; user ultimately chose the blunt instrument (disable) over the precise fix
- [x] **Memeable phrase** — "Windows trusted it. Python did not." — clean, quotable, captures the entire technical story in five words
- [ ] Caught-the-AI-lying moment
- [x] **Human-override moment** — user chose to disable Norton rather than continue domain-by-domain exclusion; judgment call that the book should examine
- [ ] Performative-vs-real contrast

**Narrative weight:** Medium
**Why it matters for the book:** The memory-vs-ground-truth tension is Chapter 2's core argument in action. The human override moment (disable Norton vs. enumerate domains) is a clean example of "good enough vs. correct" trade-off reasoning that Chapter 6 needs.

---

## Cross-References

- **Related methodology captures:** `docs/captures/s3-sp-cert-near-miss.md` (another auth-layer diagnosis session), `docs/captures/s4-sas-expiry-silent-failure.md` (the silent failure pattern that this session resolved)
- **Related topic captures from this session:** `AWACS_daily-capture_2026-05-08_norton-tls-interception.md`, `AWACS_daily-capture_2026-05-08_sas-rotation.md`
- **Builds on:** s4 methodology — identified silent failure as the root problem; this session closed the loop
- **Feeds into:** Chapter 2 (Ground Truth), Chapter 6 (The Human Layer), `workstation/troubleshooting.md` Norton gotcha section
