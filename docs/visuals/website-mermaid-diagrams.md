# Website Mermaid Diagrams

Drop any of these into a Mermaid-enabled site (GitHub Pages, Docusaurus, Obsidian, Notion, etc.) and they render with the custom dark theme below.

Each `%%{init}%%` block applies the AWACS dark palette. Copy the whole code block including that line.

---

## Diagram 1 — System Architecture (Full)

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"background": "#040c1a", "primaryColor": "#0a1e38", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#1e3a5f", "lineColor": "#334155", "secondaryColor": "#071425", "tertiaryColor": "#0d2040", "clusterBkg": "#071425", "clusterBorder": "#1e3a5f", "titleColor": "#f1f5f9", "edgeLabelBackground": "#040c1a", "nodeTextColor": "#e2e8f0"}}}%%
flowchart LR
  subgraph Z1["Z1 · LAB WORKSTATION  (LOW TRUST)"]
    A[📁 Lab Data Files]
    B[⏰ Task Scheduler\nevery 30 min]
    C[push-files.ps1]
    D[🔐 SP Cert\nCurrentUser store]
    E[📋 Local Log\nC:/ProgramData/AwacsBackup]
    B --> C
    C --> D
    C --> E
    A --> C
  end

  subgraph Z34["ENTRA ID + KEY VAULT  (HIGH TRUST)"]
    AAD[Entra ID\nTenant + SP App Reg]
    KV[Key Vault\nawdust-kv-xxxx]
    SAS[Secret: current-write-sas\nrotated daily · 24h · write-only]
  end

  subgraph Z7["Z7 · STORAGE ACCOUNT  (HIGH TRUST)"]
    SA[awdustsaxxxx]
    CT[Container: lab-files]
    IMM[🔒 WORM · 90-day lock]
    VER[Versioning + Soft Delete]
    SA --> CT --> IMM
    CT --> VER
  end

  subgraph LOG["AUDIT ZONE — Log Analytics"]
    LA[awdust-la-xxxx\nWorkstation has NO write role here]
  end

  subgraph Z8["Z8 · CONSUMER DESKS  (MEDIUM TRUST)"]
    USER[Analyst Desktop\nMFA · Read-only RBAC]
  end

  C -- "1 cert assertion\n(private key never leaves)" --> AAD
  AAD -- "2 access token 1h" --> C
  C -- "3 Get Secret\n(single name only)" --> KV
  KV --> SAS
  SAS -- "4 today's SAS" --> C
  C -- "5 PUT blob via SAS\nwrite-only · sp=acw" --> SA
  SA -. "diag stream" .-> LA
  KV -. "audit stream" .-> LA
  AAD -. "sign-in logs" .-> LA
  USER -- "6 Read RBAC · MFA\nindividual identity" --> SA
```

---

## Diagram 2 — Trust Boundaries

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"background": "#040c1a", "primaryColor": "#0a1e38", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#1e3a5f", "lineColor": "#334155", "secondaryColor": "#071425", "tertiaryColor": "#0d2040", "clusterBkg": "#071425", "clusterBorder": "#1e3a5f", "titleColor": "#f1f5f9"}}}%%
flowchart LR
  subgraph LOW["LOW TRUST — Z1/Z2"]
    Z1["Z1: Lab Workstation\nshared login · on-prem"]
    Z2["Z2: Lab Egress Network"]
  end

  subgraph UNT["UNTRUSTED — Z3"]
    Z3["Z3: Public Internet\nTLS 1.2+ only"]
  end

  subgraph HIGH["HIGH TRUST — Z4/Z5/Z6/Z7"]
    Z4["Z4: Entra ID\ntoken issuer"]
    Z5["Z5: Azure Resource Manager\ncontrol plane"]
    Z6["Z6: Key Vault\nSAS secret store"]
    Z7["Z7: Storage Account\nwrite side"]
  end

  subgraph MED["MEDIUM TRUST — Z8"]
    Z8["Z8: Consumer Desks\ndomain-joined · MFA"]
  end

  Z1 -- "cert assertion only\nprivate key never leaves" --> Z4
  Z4 -- "access token 1h\nscoped to SP" --> Z1
  Z1 -- "Get Secret\nsingle name only" --> Z6
  Z6 -- "daily SAS\nsp=acw · 24h · 1 container" --> Z1
  Z1 -- "PUT blob via SAS\nwrite-only" --> Z7
  Z8 -- "user token · MFA\nRead-only RBAC" --> Z7
  Z7 -. "diagnostic stream\nno inbound from Z1" .-> Z4

  Z1 -. "BLOCKED\nno ARM role" .-> Z5
```

---

## Diagram 3 — Data Flow (Sequence)

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"background": "#040c1a", "primaryColor": "#0a1e38", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#1e3a5f", "lineColor": "#334155", "secondaryColor": "#071425", "tertiaryColor": "#0d2040", "actorBkg": "#071425", "actorBorder": "#1e3a5f", "actorTextColor": "#e2e8f0", "activationBkgColor": "#0a1e38", "activationBorderColor": "#2563eb", "noteBkgColor": "#040c1a", "noteTextColor": "#64748b", "noteBorderColor": "#0e2040"}}}%%
sequenceDiagram
  autonumber
  participant WS as Lab PC
  participant Entra as Entra ID
  participant KV as Key Vault
  participant SA as Storage
  participant LA as Log Analytics

  WS->>Entra: cert assertion (JWT signed in-place)
  Entra-->>WS: access token (1h)
  Entra--)LA: sign-in event

  WS->>KV: Get Secret current-write-sas
  Note over WS,KV: token from step 2 authorizes this call
  KV-->>WS: today's SAS (24h · write-only)
  KV--)LA: KV audit event

  loop per new file
    WS->>SA: PUT blob via SAS (sp=acw)
    SA-->>WS: 201 Created
    SA--)LA: storage write log (caller IP · blob name)
  end

  WS->>WS: update local pushed ledger
  Note over SA: blob now under WORM · 90-day lock

  Note over LA: Workstation SP has NO write role on LA
  Note over LA: Audit trail is tamper-evident by design
```

---

## Diagram 4 — Deployment Flow

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"background": "#040c1a", "primaryColor": "#0a1e38", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#1e3a5f", "lineColor": "#334155", "secondaryColor": "#071425", "tertiaryColor": "#0d2040", "clusterBkg": "#071425", "clusterBorder": "#1e3a5f", "titleColor": "#f1f5f9"}}}%%
flowchart TD
  START([git clone + .\Deploy.ps1]) --> PF

  subgraph PREFLIGHT["Pre-flight Checks"]
    PF[Az CLI installed?\nLogged in?\nSubscription access?]
  end

  PF -- pass --> RG
  PF -- fail --> STOP([Preflight failed\nSee error output])

  subgraph DEPLOY["Azure Resource Creation"]
    RG[Create Resource Group\nawdust-rg]
    LA[Deploy Log Analytics\nawdust-la-xxxx]
    SA[Deploy Storage Account\nWORM · key auth disabled]
    KV[Deploy Key Vault\nRBAC mode]
    IMM[Apply Immutability Policy\n90-day lock]
    RBAC[Assign RBAC Roles\nSP: KV + SA write-only]
    SAS[Generate Initial SAS\nStore in Key Vault]
    RG --> LA --> SA --> KV --> IMM --> RBAC --> SAS
  end

  subgraph WORKSTATION["Workstation Bootstrap  (run once per PC)"]
    WS1[Install Az.Accounts module]
    WS2[Generate SP cert in CurrentUser store]
    WS3[Upload cert public key to SP in Entra]
    WS4[Write config.json with cert thumbprint]
    WS5[Register Scheduled Task every 30 min]
    WS1 --> WS2 --> WS3 --> WS4 --> WS5
  end

  SAS --> VERIFY
  WS5 --> VERIFY

  subgraph VERIFY["Post-deploy Verification"]
    V1[Run .\verify.ps1]
    V2{All tests green?}
    V1 --> V2
  end

  V2 -- yes --> DONE([System LIVE])
  V2 -- no --> DIAG([Check test output\nSee RUNBOOK.md])
```

---

## Usage

**GitHub / GitHub Pages:** Mermaid renders natively in `.md` files on GitHub. Paste any block above as-is.

**Docusaurus / VitePress:** Requires `@docusaurus/theme-mermaid` or equivalent plugin. The `%%{init}%%` theme overrides work as-is.

**Export to PNG:** Install `@mermaid-js/mermaid-cli` then:

```
npx mmdc -i website-mermaid-diagrams.md -o diagram.png --theme dark --backgroundColor "#040c1a"
```

To export all four diagrams individually, extract each code block to its own `.mmd` file and run the command per file.
