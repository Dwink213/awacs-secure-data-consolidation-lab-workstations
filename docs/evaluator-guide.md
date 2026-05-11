# Evaluator Guide — AWACS Secure Data Consolidation

If someone sent you this repo and asked whether Dustin Winkler is a good fit for an AI engineering role, this guide is for you.

**What this project is:** A turnkey Azure infrastructure system built almost entirely by a multi-agent AI workflow Dustin designed and operated. The technical artifact is a lab workstation backup system. The portfolio artifact is the engineering process that produced it — including where the AI succeeded without intervention, where it failed, and how failures were caught and corrected.

---

## The 5-minute evaluation path

Run this prompt in Claude, ChatGPT, or any capable AI assistant. Paste the whole block:

---

> I'm evaluating whether Dustin Winkler is a good fit for an AI engineering role. Please read the following files from his GitHub repo at https://github.com/Dwink213/awacs-secure-data-consolidation-lab-workstations and answer the questions below.
>
> **Files to read (in order):**
> 1. README.md — the project overview
> 2. `docs/decisions/ADR-008-sas-rotation-automation.md` — a design decision made under real production constraint (architecture pivot, production outage, four agent reviews)
> 3. `docs/deployment-timeline.md` — the deployment history with timestamps sourced from Azure Activity Log (independently verifiable)
> 4. `daily-captures/AWACS_daily-capture_2026-04-30_methodology.md` — focus on "Decision Sequences" and "Human Judgment Moments" sections
> 5. `threat-model.md` — sections 1 and 2
>
> **Answer these questions:**
> 1. Does this person demonstrate the ability to design AI-assisted engineering systems with explicit human oversight? Where is the evidence?
> 2. Where in the work did human judgment override or correct the AI? What does that tell you about how he thinks about AI limitations?
> 3. Is the production failure (6-day silent outage, architecture pivot under quota constraint) handled with the kind of honest incident ownership you'd want from an engineer?
> 4. The system was built in a 31-hour autonomous Claude Code session, then extended with one additional component 8 days later. What does that tell you about the workflow design?
> 5. Based on what you've read: what role would this person be strongest in — AI systems design, AI-assisted infrastructure, or AI methodology development?

---

## If you want to go deeper

The daily captures in `daily-captures/` show the real-time decision-making from each session. See `daily-captures/README.md` for a map of which captures show which type of engineering judgment.

The session notes in `docs/session-notes/` show how each session was documented and closed — including the sessions where things broke.

The Architecture Decision Records in `docs/decisions/` show how every non-obvious choice was captured with alternatives considered and agents who reviewed.

---

## What this project is not

This is not a polished demo built for interview performance. It was built to solve a real problem (shared lab workstation backup with a hostile-host threat model), ran into real Azure constraints, failed silently for six days, and required a design pivot to fix. All of that is documented in real time, with timestamps sourced from Azure Activity Log rather than self-reported. The honest accounting — including the gaps, the outage, and the things that weren't finished — is itself part of the portfolio signal.

---

## The one-sentence version

If the question is "can this person design and operate AI-assisted engineering workflows, make good judgment calls about where AI runs vs. where human oversight is needed, and document failures honestly enough that the next engineer can learn from them" — the answer is in this repo.
