# Test File 04 — Failure Modes

Owner: 🔧 Operator. The system must fail safely and observably.

---

## Test: F3.1 — Network outage during push: no data loss

**Component:** 07-workstation-push-script
**Question:** If network drops mid-push, does the script:
  (a) abort cleanly without corrupting the local "pushed" ledger?
  (b) on next scheduled run, retry the unpushed files?
**Expected Answer:** Both yes. Ledger only updated *after* successful 201 from storage.
**Failure Diagnosis:** If files are skipped on retry: ledger update happens before write completes. Reorder.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/F3_1-network-drop.ps1` (uses local network blocker)

## Test: F4.1 — Workstation silent failure: alert fires after 25h

**Component:** 05-log-analytics + alert rule
**Question:** If a workstation stops pushing (any reason), does an alert fire when no `PutBlob` event is observed for that workstation's hostname for >25 hours?
**Expected Answer:** Yes. Alert via Action Group to a configured email/webhook.
**Failure Diagnosis:** If alert does not fire: check the saved KQL in the alert rule. Should be:
```kql
StorageBlobLogs
| where OperationName == "PutBlob"
| summarize lastSeen=max(TimeGenerated) by tostring(parse_json(Properties).ObjectKey)
| where lastSeen < ago(25h)
```
**Owner Agent:** 🔧
**Executable:** `tests/scripts/F4_1-staleness-alert.ps1` (verifies alert rule exists; does not wait 25h)

## Test: F4.2 — Cert expiring soon: alert fires at 14d

**Component:** workstation/scheduled task + script self-check
**Question:** Does the push script log a CRITICAL event when the SP cert is within 14 days of expiry?
**Expected Answer:** Yes. Logs to local transcript AND emits a synthetic blob `_health/<hostname>-cert-expiring.json` so the cloud side picks it up.
**Failure Diagnosis:** Self-check missing. Add `Get-Item Cert:\CurrentUser\My\<thumbprint>` and check `NotAfter` in the script.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/F4_2-cert-expiry-warn.ps1`

## Test: F4.3 — Bad SAS: graceful failure, no crash, retry next run

**Component:** 07
**Question:** If the SAS in KV is invalid (manually corrupted for the test), does the push script log ERROR, exit non-zero, leave files unpushed for next attempt, and *not* leak the bad SAS to logs?
**Expected Answer:** All four yes. The SAS string never appears in any log line (redacted to `[REDACTED-SAS]`).
**Failure Diagnosis:** SAS in logs: tighten redaction. Crash: handle 403 cleanly.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/F4_3-bad-sas.ps1`

## Test: F4.4 — KV unreachable: degraded mode

**Component:** 07
**Question:** If KV is unreachable (DNS or firewall block), does push script abort cleanly, log ERROR, and not push files?
**Expected Answer:** Yes. Files remain on disk for next run. No partial state.
**Failure Diagnosis:** As F4.3.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/F4_4-kv-unreachable.ps1`

## Test: F4.5 — Storage account unreachable: degraded mode

**Component:** 07
**Question:** If storage account is unreachable, similar behavior?
**Expected Answer:** Yes. Same as F4.4.
**Failure Diagnosis:** As F4.3.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/F4_5-sa-unreachable.ps1`

---

**Total tests in this file:** 6.
