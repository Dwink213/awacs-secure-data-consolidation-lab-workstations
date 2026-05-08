# Daily Capture: Norton TLS Interception — Azure CLI Blocked by AV SSL Scanning
**Date:** 2026-05-08
**Session source:** AWACS Secure Lab Backup — troubleshooting "system failing to authenticate"

---

## What Happened

Azure CLI was failing with `[SSL: CERTIFICATE_VERIFY_FAILED] unable to get local issuer certificate` on every call to Azure endpoints. The root cause was Norton Antivirus's "Web/Mail Shield" SSL scanning feature, which intercepts all HTTPS traffic and re-signs it with a self-generated root CA (`CN=Norton Web/Mail Shield Root`). Windows trusted this cert (Norton pushed it to the Windows Certificate Store via installation), but Azure CLI's bundled Python uses its own certifi CA bundle — which knows nothing about Norton. The fix required progressively adding Azure domains to Norton's exclusion list, one family at a time (`login.microsoftonline.com`, then `*.vault.azure.net`, then `*.blob.core.windows.net`). The user ultimately disabled Norton's SSL scanning entirely to unblock the session.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** "Norton Antivirus was man-in-the-middling every single Azure API call. Not a breach. Not malware. Just your AV doing its job — silently breaking everything."
**Target audience:** Azure engineers, cloud platform teams, IT security professionals
**Post type:** Story + Teaching
**Emotional driver:** Recognition ("I've seen this before and had no idea what it was")
**Priority:** High

**Draft hook options:**
1. "Azure CLI stopped working. No config changed. No credentials rotated. The culprit: my antivirus."
2. "Two tools. Same host. One succeeds. One fails. That's not a bug — it's a trust model mismatch."
3. "Norton was signing every Azure API call with its own certificate. Windows was fine with it. Python was not."

**Viral levers present:**
- [x] **Confession arc** — "the system is failing to authenticate" turned out to be the AV, not the code
- [ ] Villain-vindication — Norton IS the villain; user fixed it by disabling rather than engineering around (partial)
- [x] **Memeable phrase:** "Windows trusted it. Python did not." — clean contrast, quotable
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism** — certifi vs. Windows Certificate Store split-brain; two trust models, one host
- [ ] Self-incriminating AI quote
- [ ] Comment-bait question
- [x] **Universal unnamed pain** — "my tool works but a different tool to the same endpoint doesn't" is a widely felt, rarely explained experience

**Lever count:** 4 / 8
**Viral candidate?:** Likely above average (3-4)

**Notes:** Sanitize freely — no employer data. The "two trust stores" angle is the teachable moment that engineers will share internally. Consider pairing with a diagram showing certifi vs. Windows store.

---

## Training Material

**Training potential:** High
**Could become:** Case study + Live demo
**Which course it fits:** Course 1 (AI-Assisted Infrastructure) — troubleshooting environment trust issues
**Teaching point:** Certificate trust is not global. Each runtime (Windows, Python, Java, Node) maintains its own CA bundle. A cert that one tool trusts may be unknown to another tool on the same machine. Diagnosing "works in PowerShell, fails in az CLI" requires understanding which trust store each tool uses.
**Prerequisite knowledge:** Basic TLS/PKI (what a CA is, what certificate verification does), awareness that Python bundles certifi separately from the OS

**Notes:** The diagnostic sequence — check az account show (cached), compare .NET vs Python SSL connection, inspect cert chain issuer — is a repeatable playbook worth formalizing.

---

## Technical Reproduction

**Steps to recreate:**
1. Install Norton 360 or Norton Antivirus with "Web/Mail Shield" SSL scanning enabled (default)
2. Install Azure CLI (which bundles Python 3.13 with its own certifi bundle)
3. Run `az keyvault secret show` — observe SSL cert verification failure
4. Run `Invoke-WebRequest https://login.microsoftonline.com` in PowerShell — succeeds
5. Inspect issuer of cert presented to `login.microsoftonline.com` via .NET `HttpWebRequest` — shows "Norton Web/Mail Shield Root"
6. Inspect issuer via Azure CLI's Python `ssl.wrap_socket` — same host, same Norton cert, but Python's certifi doesn't trust it

**Dependencies:**
- Norton Antivirus with SSL scanning enabled
- Azure CLI 2.x (Python 3.13 bundled)
- Azure subscription with Key Vault, Storage Account

**Environment:**
- Windows 11 Home 10.0.26200
- Azure CLI: `C:\Program Files\Microsoft SDKs\Azure\CLI2` (Python 3.13)

**Gotchas:**
- `az account show` may succeed from cached credentials even when SSL is broken — a false green
- `az config set core.cafile=<path>` exists but requires the az subprocess to pick it up; env vars (`REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`) did not propagate reliably to the az.cmd child process in this session
- Norton exclusions apply per-domain, not per-application — must be added for each Azure domain family separately
- User-delegation SAS generation hits `blob.core.windows.net` (storage endpoint), not just `management.azure.com` — all families need exclusion

**Diagnostic commands:**
```powershell
# Check what cert is being presented to a host via .NET (Windows store)
$req = [System.Net.HttpWebRequest]::Create("https://login.microsoftonline.com")
$req.Timeout = 10000; $req.AllowAutoRedirect = $false
try { $req.GetResponse().Close() } catch {}
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$req.ServicePoint.Certificate
Write-Host "Issuer: $($cert.Issuer)"

# Check the same host via Azure CLI's Python
& "C:\Program Files\Microsoft SDKs\Azure\CLI2\python.exe" -c @"
import ssl, socket
ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
conn = ctx.wrap_socket(socket.socket(), server_hostname='login.microsoftonline.com')
conn.connect(('login.microsoftonline.com', 443))
cert = conn.getpeercert()
issuer = {k:v for t in cert.get('issuer',[]) for k,v in [t[0]]}
print('Issuer org:', issuer.get('organizationName','?'))
conn.close()
"@
```

**Domains to exclude from Norton SSL scanning for Azure CLI:**
- `login.microsoftonline.com`
- `*.vault.azure.net`
- `*.blob.core.windows.net`
- `management.azure.com`
- `*.core.windows.net` (covers all storage endpoints)

**Related files:**
- `C:\Users\Dustin\.azure-ca\cacert.pem` — patched certifi bundle with Norton root appended (created this session, not committed)
- `STATUS.md` — updated to LIVE after resolution

---

## Product Extraction

**Standalone potential:** Maybe
**What it is:** A diagnostic script that detects TLS interception by comparing Windows store vs. Python certifi trust for a given host, and generates the correct `cacert.pem` patch automatically
**Who would use it:** Enterprise Azure CLI users behind corporate SSL inspection (Zscaler, Netskope, Norton, Symantec Blue Coat)
**What it needs for GitHub:**
- [ ] Generalize to any intercepting CA (not Norton-specific)
- [ ] Auto-detect which Azure domains need exclusion
- [ ] Output: either patched bundle OR Norton exclusion list

**MVP scope:** A 50-line PowerShell script: detect interception, identify the intercepting root, patch `~/.azure-ca/cacert.pem`, set `REQUESTS_CA_BUNDLE` permanently
**Monetization angle:** Open source credibility / lead magnet — surfaces in Azure CLI troubleshooting searches
**Competitors/alternatives:** None found — this is underdocumented

**Verdict:** Explore further — small effort, high discoverability value

---

## Content War Chest Category

- [x] **Proof content** — Shows deep Azure + Python SSL debugging capability
- [x] **Teaching content** — The two-trust-store mental model is genuinely useful
- [ ] Methodology content
- [ ] Product content

**Primary category:** Teaching content

---

## Raw Material

```
Cert chain on login.microsoftonline.com BEFORE Norton exclusion:
Subject: CN=stamp2.login.microsoftonline.com, O=Microsoft Corporation
Issuer:  CN=Norton Web/Mail Shield Root, O=Norton Web/Mail Shield, OU=generated by Norton Antivirus for SSL/TLS scanning
Thumbprint: 2C20E56C4F4CF9BAD2D9617CC660FE53481D42F2

Norton root:
Subject: CN=Norton Web/Mail Shield Root
Thumbprint: BD2217FCEC2414CC1677CDE73889AFCFC656A038
Valid until: 01/01/2040

Cert chain AFTER login.microsoftonline.com exclusion (real chain restored):
Subject: CN=stamp2.login.microsoftonline.com, O=Microsoft Corporation
Issuer:  CN=DigiCert Global G2 TLS RSA SHA256 2020 CA1

vault.azure.net still intercepted after login exclusion:
Issuer: CN=Norton Web/Mail Shield Root (confirmed)

blob.core.windows.net still intercepted after vault exclusion:
Issuer: CN=Norton Web/Mail Shield Root (confirmed)
```

---

## Next Actions

- [ ] Build the diagnostic/patch script as a small GitHub gist or repo
- [ ] Write LinkedIn post using "Windows trusted it. Python did not." as the hook
- [ ] Add Norton exclusion domains to `workstation/troubleshooting.md` as a known gotcha
- [ ] Consider adding a preflight check to `deploy/preflight.ps1` that detects TLS interception

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-05-08_sas-rotation.md`
- **Related project files:** `workstation/troubleshooting.md`, `STATUS.md`
- **Builds on:** The SP cert near-miss session (s3) — another case of auth-layer diagnosis
- **Feeds into:** Deploy preflight script; `workstation/troubleshooting.md`
