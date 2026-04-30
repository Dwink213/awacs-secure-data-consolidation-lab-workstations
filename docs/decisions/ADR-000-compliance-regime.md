# ADR-000: Compliance Regime and Data Sensitivity

**Status:** Accepted (autonomous decision under user authorization)
**Date:** 2026-04-30
**Agents who reviewed:** 🏗️ 🛡️ 🔧 📚

## Context

CLAUDE.md Rule 3 says the threat model must be the first artifact. The threat model cannot be honest without naming the regulatory and data-sensitivity world the system lives in. The captured 2026-04-28 design did not specify a compliance regime.

The user authorized autonomous decisions. This ADR records the choice and the reasoning so any deviation later is a *documented* deviation, not a silent drift.

## Decision

**Generic enterprise / CIS-aligned, with GxP-ready hooks.**

The system is designed to:

1. Pass a generic SOC 2 / CIS Azure Foundations Benchmark v5.0 control review without exception
2. Be *upgradable* to GxP / 21 CFR Part 11 by tightening retention duration, enabling legal hold, and adding e-signature on the consumer-side access path — without re-architecting the data plane
3. **Not** assume HIPAA/PHI handling — files are presumed to be lab research data, not patient identifiers. If PHI ends up in scope, the design must add CMK encryption with customer-controlled keys and a BAA workstream.

## Alternatives considered

1. **Full GxP / 21 CFR Part 11 from day one** — rejected because it locks the design to longer retention windows and audit-trail formality the user did not request, increasing cost and friction.
2. **HIPAA-tier** — rejected because the captured design says "lab research data," not patient data. Adding HIPAA defensive controls speculatively would over-build.
3. **Trade-secret / proprietary research only** — rejected because it doesn't drive a stricter audit trail than CIS already does, and CIS is broader.

## Trade-off

We accept that if this design later needs to land in a regulated GxP environment, we will need to:
- Increase retention from the chosen default (90 days) to the regulated minimum (typically 7+ years for FDA records)
- Enable legal hold in addition to time-based retention
- Add a documented periodic audit-log review procedure
- Capture e-signature attestation on consumer-side data access if records are submitted to FDA

The architecture does not block any of these — they are configuration-level changes. ADR-000 names them so the upgrade path is explicit.

## Rationale

The lowest defensible bar (CIS) is also the bar that buys the most universal applicability. A buyer cloning this repo from GitHub does not necessarily live in a regulated industry; making the default GxP would alienate the broader audience. Making the default CIS with GxP hooks captured serves both.

## Cross-Agent Review

- 🏗️ **Architect:** Accepts. CIS gives concrete control names to map components against.
- 🛡️ **Security Engineer:** Accepts with reservation. If the actual deployer's data is in fact PHI or GxP records, this ADR must be re-opened and the threat model extended. Documented as a Stage-1 assumption.
- 🔧 **Operator:** Accepts. CIS gives me Diagnostic Settings, Activity Log, and Storage Logging as named controls to verify in tests.
- 📚 **Documentarian:** Accepts. The upgrade path is captured; future readers can find their way to GxP from here.
