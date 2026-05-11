# Daily Captures — What These Are

Each file in this directory is a session capture written during or immediately after a working session on this project. They follow the AWACS capture methodology: each session's key events are documented across multiple lenses before the context is closed.

---

## How to read a capture

Each capture has several sections. If you're evaluating this project as a portfolio piece, the sections that show engineering process are:

**"What Happened"** — the factual session arc. What was the starting state, what broke, what was diagnosed, what was the outcome. The raw story.

**"Decision Sequences"** (in methodology captures) — structured records of each decision made during the session: the starting assumption, what violated it, the pivot, the final decision, and the transferable principle extracted. These are the judgment calls made in real time, not retrospective polish.

**"Human Judgment Moments"** (in methodology captures) — explicit documentation of where human judgment was required to override or redirect the AI. These capture the moments where autonomous AI execution hit a wall and human reasoning resolved it. For evaluating AI collaboration discipline, these are the most direct signal.

**"Technical Reproduction"** — step-by-step recreation of the incident or build, including gotchas and environment specifics.

---

## The other sections

Each capture also contains a **Social Potential**, **Training Material**, and **Product Extraction** section. These are AWACS content pipeline fields — they feed a book, a course, and a LinkedIn content queue that runs in parallel with the technical work. They are not portfolio noise; they reflect how value is extracted from each session beyond the code. But if you're evaluating technical and AI engineering fit specifically, you can skip them.

---

## Captures by signal type

| File | Best section | What it shows |
|------|-------------|---------------|
| `AWACS_daily-capture_2026-04-30_methodology.md` | Decision Sequences + Human Judgment Moments | 31-hour autonomous build: where AI ran, where human judgment intervened |
| `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md` | What Happened + Technical Reproduction | Cascade debugging: SAS token truncation at `&`, BOM corruption, RBAC gap |
| `AWACS_daily-capture_2026-05-01_sas-expiry-silent-failure.md` | What Happened | Silent 403 failure mode: scheduled task exits 0 even when all writes fail |
| `AWACS_daily-capture_2026-05-08_norton-tls-interception.md` | What Happened + Technical Reproduction | Two-trust-store split: Windows cert store vs. Python certifi; diagnosed live |
| `AWACS_daily-capture_2026-05-08_sas-rotator-build.md` | What Happened + Technical Reproduction | Architecture pivot under constraint: Azure Functions quota → Automation Account MSI |
| `AWACS_daily-capture_2026-05-09_iac-reality-inversion-pattern.md` | What Happened | Named anti-pattern: AI documents the planned design, not the shipped design |
| `AWACS_daily-capture_2026-04-30_memory-system-first-use.md` | What Happened | Memory system across context compaction: AI warns of upcoming expiry, warning proves correct |

---

## The pattern across all captures

Every session produced a failure, a diagnosis, and a documented resolution. No session was declared complete without verifying the actual system state against the claimed state. The discipline: every error was fixed at the layer where it existed, not papered over at the layer where it was visible.

That discipline — ground truth before completion claims, transferable principles extracted from every failure — is the methodology this project was built to demonstrate.
