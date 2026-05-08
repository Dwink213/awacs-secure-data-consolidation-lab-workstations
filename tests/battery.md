# Test Battery — Full Catalog

This is the index. Every test in the system is listed here with its ID, owner agent, and what it covers.

## Coverage matrix

Each row = one tested concern. Each cell = the test ID(s) that cover it.

| Concern | Threat Model (01) | Contracts (02) | Integration (03) | Failure (04) | Compliance (05) | Deploy (06) | Workstation (07) |
|---------|------|------|------|------|------|------|------|
| T1 Insider Analyst | T1.1, T1.2 | | | | | | |
| T2 Lifted Credential | T2.1, T2.2, T2.3 | | | | | | |
| T3 Compromised Workstation | | | | F3.1 | | | |
| T4 Rogue Local Admin | | | | F4.1, F4.2 | | | W7.5 |
| T5 Network MITM | T5.1 | C1.4 | | | CIS-3.1 | | |
| T6 Curious Consumer | T6.1 | C6.1 | | | | | |
| Storage account hardening | | C1.1, C1.2, C1.3, C1.4, C1.5 | | | CIS-3.7, CIS-3.13, CIS-3.14 | | |
| Key Vault hardening | | C2.1, C2.2, C2.3 | | | CIS-7.1 | | |
| SP narrow scope | T2.3 | C3.1, C3.2 | | | | | |
| Immutability | T1.1, T2.2 | C4.1, C4.2 | I3.2 | | | D6.5 | |
| Audit trail | | C5.1 | I3.3 | | | | |
| Consumer RBAC | T6.1 | C6.1 | | | | | |
| Workstation push contract | | C7.1, C7.2 | I3.1 | F4.3 | | | W7.1, W7.2, W7.3, W7.4, W7.5, W7.6 |
| SAS rotation automation | | C8.1, C8.2, C8.3, C8.4, C8.5, C8.6 | | | | | |
| Idempotency | | | | | | D6.2, D6.3 | W7.6 |
| Teardown safety | | | | | | D6.4, D6.5 | |
| Preflight gating | | | | | | D6.1 | |

## Counts

- 🛡️ Security Engineer owns: 18 tests
- 🏗️ Architect owns: 12 tests
- 🔧 Operator owns: 19 tests
- 📚 Documentarian owns: 3 tests (review-of-docs gating)

## What "complete" means for the battery

The battery is complete when:

- Every threat actor (T1–T6) has at least one defense test
- Every Atomic Lego (01–08) has at least one contract test
- Every CIS control named in `threat-model.md` §5 has a compliance test
- Every named failure mode has a test
- Every script in `deploy/` has a test that exercises it end-to-end

This is currently the case (see per-file totals at the bottom of each test file).

## What the battery does NOT cover

- Performance and scale (push throughput, large-file behavior > 1 GB) — out of scope for the V1 design
- Multi-region failover — out of scope; design is single-region per ADR
- Cross-tenant scenarios — out of scope; design is single-tenant
