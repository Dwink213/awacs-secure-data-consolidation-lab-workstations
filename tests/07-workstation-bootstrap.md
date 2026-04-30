# Test File 07 — Workstation Bootstrap

Owner: 🔧 Operator. The bootstrap turns a clean Windows lab PC into a configured push source.

---

## Test: W7.1 — Bootstrap on clean Win10/Win11 produces ready state

**Component:** workstation/bootstrap.ps1
**Question:** Starting from a fresh Windows installation with no Az modules, no cert, no scheduled task — after bootstrap completes, is the system ready to push?
**Expected Answer:** Yes. (a) Az.Accounts and Az.Storage installed, (b) cert imported into the service-account `Cert:\CurrentUser\My`, (c) scheduled task `AwacsBackupPush` registered to run every 30 min, (d) C:\ProgramData\AwacsBackup\ created, (e) `push-files.ps1` deployed.
**Failure Diagnosis:** Each step in bootstrap emits a `[STEP] OK` or `[STEP] FAIL`. Identify the failed step and its log line.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/W7_1-bootstrap-clean.ps1` (run inside a VM snapshot or sandbox)

## Test: W7.2 — Bootstrap: Az modules pinned to documented versions

**Component:** workstation/bootstrap.ps1
**Question:** Are `Az.Accounts` and `Az.Storage` installed at the exact versions named in `workstation/requirements.md`?
**Expected Answer:** Yes. `Get-Module -ListAvailable -Name Az.Accounts` returns the pinned version.
**Failure Diagnosis:** `Install-Module` was called without `-RequiredVersion`. Update bootstrap.
**Owner Agent:** 🛡️ (pinning is a supply-chain defense)
**Executable:** `tests/scripts/W7_2-az-versions.ps1`

## Test: W7.3 — Bootstrap: cert imported with non-exportable flag

**Component:** workstation/bootstrap.ps1
**Question:** Is the imported cert flagged non-exportable?
**Expected Answer:** Yes. `(Get-Item Cert:\CurrentUser\My\<thumb>).PrivateKey.CspKeyContainerInfo.Exportable` returns false (or modern equivalent for CNG keys).
**Failure Diagnosis:** `Import-PfxCertificate` invoked with `-Exportable` or without `-KeyExportable:$false`. Fix.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/W7_3-cert-non-exportable.ps1`

## Test: W7.4 — Bootstrap: scheduled task runs as service account, not interactive

**Component:** workstation/bootstrap.ps1, workstation/scheduled-task.xml
**Question:** Is the scheduled task configured with `RunLevel: Highest` (to bypass UAC) but as a *service* account (not the interactive analyst)?
**Expected Answer:** Yes. `Principal\UserId` in the task XML is the service account SID, not "INTERACTIVE" or the analyst.
**Failure Diagnosis:** Inspect via `schtasks /query /tn AwacsBackupPush /xml` or Task Scheduler GUI.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/W7_4-task-principal.ps1`

## Test: W7.5 — Bootstrap: PowerShell execution policy compatible with signed scripts

**Component:** workstation/bootstrap.ps1
**Question:** After bootstrap, can the signed `push-files.ps1` run, while an unsigned modification of it would be refused?
**Expected Answer:** Yes. ExecutionPolicy at `AllSigned` or `RemoteSigned` for the LocalMachine scope.
**Failure Diagnosis:** Policy at `Bypass` or `Unrestricted`. Tighten.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/W7_5-execpolicy.ps1`

## Test: W7.6 — Bootstrap: idempotent (rerun is safe)

**Component:** workstation/bootstrap.ps1
**Question:** Running bootstrap twice in a row: does second run complete cleanly without duplicating modules, certs, or tasks?
**Expected Answer:** Yes. Bootstrap detects existing state and skips already-done steps with `[STEP] SKIP (already present)`.
**Failure Diagnosis:** Second run errors on `Register-ScheduledTask` (duplicate). Add existence checks.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/W7_6-idempotent.ps1`

## Test: W7.7 — Uninstall: clean removal

**Component:** workstation/uninstall.ps1
**Question:** Does uninstall remove the cert, scheduled task, log directory, and config without leaving artifacts?
**Expected Answer:** Yes, with the cert backed up to `C:\ProgramData\AwacsBackup\removed-certs\` (timestamped) before removal — for forensic continuity.
**Failure Diagnosis:** Inspect post-uninstall state.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/W7_7-uninstall.ps1`

---

**Total tests in this file:** 7.
