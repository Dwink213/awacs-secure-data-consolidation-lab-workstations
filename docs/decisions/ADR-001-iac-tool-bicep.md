# ADR-001: IaC Tool — Bicep over Terraform

**Status:** Accepted
**Date:** 2026-04-30
**Agents who reviewed:** 🏗️ 🛡️ 🔧 📚

## Decision

**Bicep.** All Azure resources in this repo are authored in Bicep, deployed via `az deployment group create` (or `az deployment sub create` for the resource group itself).

## Alternatives considered

1. **Terraform** — works, broadly skilled labor pool, multi-cloud portable.
2. **ARM JSON** — rejected outright. The Documentarian agent will not let an ARM template into a "self-explaining" repo.
3. **Pulumi** — rejected, niche in the Azure single-cloud audience this repo targets.

## Trade-off

We give up:
- Multi-cloud portability (this design will never run on AWS/GCP)
- Terraform's mature `import` workflow for adopting existing resources
- Some Terraform-only modules in the registry

We get:
- Native Microsoft tooling, no third-party state file to secure
- No remote state backend to provision and lock (Terraform's chicken-and-egg)
- Built-in `az` CLI integration, simpler preflight
- Cleaner diff against ARM (Bicep transpiles to ARM, so what-if shows the actual ARM diff)
- Microsoft AVM (Azure Verified Modules) ecosystem if we want to reach for it later

## Rationale

The system is Azure-only by design (cert-based SP authenticating to Entra ID, Azure Storage, Azure Key Vault, Log Analytics). There is no realistic future in which we run this on another cloud. The portability "win" of Terraform is hypothetical here.

The bigger driver is operator simplicity: a buyer cloning this repo and running `./deploy.sh` should not have to provision a Terraform state backend and explain to their security team why a state file holds secrets.

## Cross-Agent Review

- 🏗️ **Architect:** Accepts. Bicep modules compose cleanly.
- 🛡️ **Security Engineer:** Accepts. No state file = one fewer secret-bearing artifact to protect.
- 🔧 **Operator:** Accepts. `az deployment what-if` is the operator-friendly preview I want.
- 📚 **Documentarian:** Accepts. Bicep reads almost like a typed config file; ARM JSON would have been a documentation hostile.
