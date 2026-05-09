# Component Map

How the eight Atomic Legos compose. Each box is one directory under `components/`. Each arrow is a *deployment-time output → input* dependency, except where labeled *runtime*.

```mermaid
flowchart TB
  subgraph DEPLOY["Deploy time (Bicep, in order)"]
    direction TB
    LA["05 Log Analytics\n(workspace + diag setting receiver)"]
    SA["01 Storage Account\n(account + container + diag → 05)"]
    IMM["04 Immutability Policy\n(applied to 01's container)"]
    KV["02 Key Vault\n(vault + diag → 05)"]
    SP["03 Service Principal\n(SP + cert + custom role)"]
    RBAC_W["RBAC: SP → write-only on 01's container"]
    RBAC_KV["RBAC: SP → Get Secret on 02"]
    RBAC_R["06 Consumer RBAC\n(read-only on 01's container)"]
    ROT["08 SAS Rotator\n(Automation Account + MSI)"]
    RBAC_ROT_KV["RBAC: MSI → KV Secrets Officer\n(scoped to current-write-sas resource ID)"]
    RBAC_ROT_SBD["RBAC: MSI → Storage Blob Delegator\n(SA level, to call GetUserDelegationKey)"]
    RBAC_ROT_W["RBAC: MSI → Storage Blob Data Contributor\n(container level, to generate acw SAS)"]

    LA --> SA
    LA --> KV
    SA --> IMM
    SP --> RBAC_W
    SA --> RBAC_W
    SP --> RBAC_KV
    KV --> RBAC_KV
    SA --> RBAC_R
    ROT --> RBAC_ROT_KV
    KV --> RBAC_ROT_KV
    ROT --> RBAC_ROT_SBD
    SA --> RBAC_ROT_SBD
    ROT --> RBAC_ROT_W
    SA --> RBAC_ROT_W
  end

  subgraph WORKSTATION["Workstation side (bootstrap)"]
    BOOT["bootstrap.ps1\ninstalls Az modules, imports cert, creates scheduled task"]
    PUSH["07 push-files.ps1\nthe runtime push"]
    BOOT --> PUSH
  end

  CERT["Cert (.pfx)\ngenerated at deploy time"]
  SP --> CERT
  CERT -.-> BOOT

  PUSH -. runtime .-> SP
  PUSH -. runtime .-> KV
  PUSH -. runtime .-> SA
```

## Deployment-time dependency order

The order matters. The deploy script enforces it:

1. **05 Log Analytics first.** Everything else points its diagnostic settings here. If LA is not up first, downstream diag settings 400-error.
2. **01 Storage Account.** Depends on LA for diag setting target.
3. **04 Immutability Policy.** Applied to the container *after* the container exists. Bicep handles this with `dependsOn`, but it's worth naming.
4. **02 Key Vault.** Depends on LA. Independent of Storage; could be deployed in parallel.
5. **03 Service Principal + Cert.** Independent of all of the above on the resource side, but its RBAC assignments depend on SA and KV existing.
6. **RBAC assignments.** SP → write-only on container, SP → Get Secret on KV.
7. **06 Consumer RBAC.** SA → read-only for the named consumer security group.
8. **08 SAS Rotator (Automation Account).** Bicep creates the Automation Account and RBAC assignments. `Deploy.ps1` then uploads the runbook content and links the 6-day schedule via REST API (two `az automation` CLI verbs don't exist; Bicep alone cannot upload runbook content).
9. **Initial SAS generation.** Deploy script writes the first SAS into the Key Vault secret slot so the system works on day one. Subsequent rotation is handled automatically by component 08 every 6 days.

## Runtime composition

Once deployed, the workstation push (component 07) at every scheduled run:

1. Authenticates as the SP using the local cert (→ Entra ID, component 03)
2. Calls Key Vault Get Secret (→ component 02)
3. Receives the day's SAS
4. Writes new files to the container using the SAS (→ component 01)
5. Logs to local file *and* writes a structured audit line that storage logging captures (→ component 05)

## What can be deployed independently for testing

- **05 (LA)** — yes, standalone
- **01 (SA)** — yes, with a placeholder LA workspace ID
- **04 (Immutability)** — needs 01 first
- **02 (KV)** — yes, standalone
- **03 (SP)** — yes, standalone (RBAC assignments are separate Bicep modules)
- **06 (Consumer RBAC)** — needs 01
- **07 (Workstation)** — needs 03's cert, 01's account name, 02's vault URL
- **08 (SAS Rotator)** — needs 01 (storage account name), 02 (KV name + secret resource ID), 05 (LA workspace ID)

The ability to deploy each in isolation is what makes Stage 4 implementation tractable and Stage 6 troubleshooting tractable.
