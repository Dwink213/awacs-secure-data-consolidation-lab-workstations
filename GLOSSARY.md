# Glossary

Project-specific terms used in this repo.

| Term | Meaning |
|------|---------|
| **Atomic Lego** | A single-responsibility, independently testable, single-directory component. Per CLAUDE.md Rule 2. |
| **AWACS** | The methodology this project uses: Architect / Security Engineer / Operator / Documentarian — four named agents who review every significant decision. |
| **Cert-based SP** | Service Principal authenticated by certificate, not by client secret. The on-prem analogue of Managed Identity. |
| **Consumer / Consumer Desk** | The analyst at their own workstation reading backups. Distinct trust zone (Z8) from the lab PC (Z1). |
| **Cross-Agent Review** | A block in a markdown file capturing all four agents' positions on a decision, including disagreements. Not flattened. |
| **GxP-ready** | Designed so that a future deploy in a regulated (GxP / 21 CFR Part 11) environment can be made compliant by configuration changes only, not redesign. |
| **Hostile host** | Threat-model term: a machine assumed to be compromisable. The lab PC is a hostile host. |
| **Lab PC / Lab workstation** | A shared workstation with generic logins, not domain joined, where lab data is generated. Trust zone Z1. |
| **Layered auth** | The cert + rotated-SAS combination. Cert gets you in the door, SAS does the actual write. Two layers, two rotations. |
| **Lego boundary** | The interface contract a component publishes in its README. Crossing it without an explicit dependency is a violation. |
| **Push-on-schedule backup** | The model: lab PC initiates writes on a schedule, never pulls. No inbound from cloud → lab PC. |
| **Automation Account** | Azure service that runs PowerShell runbooks on a schedule. Used by component 08 (SAS Rotator) with a system-assigned MSI. Free SKU supports 500 min/month of runbook execution. |
| **MSI (Managed Identity)** | Azure-assigned identity for Azure-hosted compute. Token is ephemeral and non-exportable from the runtime. The Automation Account's MSI is the widest credential in this system (see Z9 in `threat-model.md`). |
| **SAS** | Shared Access Signature, an Azure Storage credential. Here always write-only, container-scoped, 6d 23h (rotated automatically every 6 days by component 08). |
| **User-delegation SAS** | A SAS signed by a user (or MSI) identity's delegation key rather than the storage account key. Requires the signing identity to hold the permissions the SAS grants. 7-day Azure-enforced lifetime maximum. |
| **Service Account (lab PC)** | The dedicated local user the scheduled task runs as. Distinct from interactive analyst logins. |
| **Stage Gate** | A user-confirmation checkpoint between AWACS methodology stages. Skipped explicitly in the autonomous overnight run that produced this v1. |
| **Trust Zone (Z1–Z9)** | One of the nine named zones from `threat-model.md` §2. Crossings are credentials; everything is auditable. Z9 (Automation Account) was added 2026-05-08 — see ADR-008. |
| **Turnkey** | Per CLAUDE.md Rule 9: pull-down-deployable in one command. The deliverable bar for this repo. |
| **Unique4** | The 4-character deterministic hash suffix used in resource names to satisfy Azure's globally-unique-name rules without operator input. |
| **Workstation Bootstrap** | The one-shot installer (`workstation/bootstrap.ps1`) that brings a clean lab PC to ready state. |
| **Write-only RBAC** | A custom role granting `…/blobs/write` and `…/add/action` and nothing else. The defense underpinning the entire lab-side trust model. |
