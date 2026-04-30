# Test File 03 — Integration

Owner: 🏗️ Architect + 🔧 Operator. The Atomic Legos compose into a working system.

---

## Test: I3.1 — End-to-end push from workstation produces blob and log

**Component:** system (07 + 03 + 02 + 01 + 05)
**Question:** When `push-files.ps1` runs on a configured workstation with a test file in the watched directory, does the file appear in the storage account container, and does an audit log entry appear in Log Analytics within 5 minutes?
**Expected Answer:** Both yes. Blob exists at expected path (`<hostname>/<YYYY-MM-DD>/<filename>`). LA query `StorageBlobLogs | where OperationName == "PutBlob"` returns the event with caller principal ID matching the SP.
**Failure Diagnosis:**
1. Blob missing → check local transcript log on the workstation. If push got an HTTP error, follow the error code.
2. Blob present, log missing → check diag setting linkage (`tests/scripts/C5_1`). LA ingestion delay can be up to 10 min for new workspaces.
**Owner Agent:** 🏗️
**Executable:** `tests/scripts/I3_1-end-to-end.ps1`

## Test: I3.2 — Blob lands and is immediately under immutability

**Component:** 01 + 04
**Question:** Within 60 seconds of write, can a delete attempt against the new blob be issued, and is it refused?
**Expected Answer:** Refused. 409 BlobImmutableDueToPolicy.
**Failure Diagnosis:** Immutability policy not in effect on this container. See C4.1.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/I3_2-immediate-immutability.ps1`

## Test: I3.3 — Audit chain: sign-in, KV read, storage write all present

**Component:** 05 + 03 + 02 + 01
**Question:** For one push, can we trace the full event chain in Log Analytics: Entra sign-in by SP → KV Get Secret by SP → Storage PutBlob by SP?
**Expected Answer:** All three events present, correlatable by SP object ID and time window (within 60s of each other).
**Failure Diagnosis:**
1. Sign-in missing → Entra ID diag setting not pointed at LA. Add it.
2. KV event missing → KV diag setting missing or AuditEvent category disabled.
3. Storage event missing → as I3.1.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/I3_3-audit-chain.ps1`

## Test: I3.4 — Multi-workstation: two pushes do not collide

**Component:** system
**Question:** When two workstations push files at the same time, do both succeed, with no overwrite or partial state?
**Expected Answer:** Both succeed; blob naming includes hostname so paths are disjoint by construction.
**Failure Diagnosis:** If a workstation overwrote another's file, blob naming convention is broken. Inspect push-files.ps1 path construction.
**Owner Agent:** 🏗️
**Executable:** `tests/scripts/I3_4-concurrent-push.ps1`

## Test: I3.5 — SAS rotation: new SAS valid, in-flight push tolerates rotation

**Component:** 02 + 07
**Question:** When the SAS rotates mid-day (forced manual rotation for the test), does the next push pull the new SAS without an extra reconfigure?
**Expected Answer:** Yes. Push always reads from KV per-run; it does not cache SAS across runs.
**Failure Diagnosis:** If push uses stale SAS: script is caching SAS to disk or memory across runs. Should not. Fix push-files.ps1.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/I3_5-sas-rotation.ps1`

---

**Total tests in this file:** 5.
