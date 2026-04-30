# Tests

**Stage 3 artifact.** Per CLAUDE.md Rule 1 (Test-First Battery), every component has its tests defined here *before* its IaC or scripts are written. Tests in this directory are markdown specs. The corresponding executable scripts live in `tests/scripts/`.

## Structure

| File | Owner | What it asks |
|------|-------|--------------|
| `battery.md` | All four | The full catalog. Cross-references everything. |
| `01-threat-model-defense.md` | 🛡️ | "Did we actually defend against T1–T6 from `threat-model.md`?" |
| `02-component-contracts.md` | 🏗️ | "Does each Atomic Lego do what its README says it does?" |
| `03-integration.md` | 🏗️ + 🔧 | "Do the Legos compose into the system?" |
| `04-failure-modes.md` | 🔧 | "Does the system fail safely and observably?" |
| `05-compliance.md` | 🛡️ | "Does this satisfy the CIS controls named in the threat model?" |
| `06-deployment.md` | 🔧 | "Does `git clone` + one command produce a running system?" |
| `07-workstation-bootstrap.md` | 🔧 | "Does the bootstrap turn a clean Win10/11 into a ready lab PC?" |

## Test record format

Every test, in every file, follows this format:

```markdown
## Test: [ID — Short Name]
**Component:** [01-storage-account | 02-key-vault | ... | 07-workstation-push-script | system]
**Question:** [What this test asks of the system]
**Expected Answer:** [The specific outcome that proves it works]
**Failure Diagnosis:** [If the expected answer is not met, the procedure for determining why]
**Owner Agent:** [🏗️ | 🛡️ | 🔧 | 📚]
**Executable:** [tests/scripts/<filename> | n/a (design-time only)]
```

Tests labeled "design-time only" are satisfied by review of the artifacts (Bicep, scripts) — they do not require a deployed environment. Tests with an executable counterpart are satisfied by running the script against a deployed environment.

## How to run

After deploy completes, the verify script chains all executable tests:

**Command:** `pwsh ./deploy/verify.ps1 -ResourceGroup <prefix>-rg`
**What it does:** Runs every `tests/scripts/*.ps1` against the deployed environment, prints a structured pass/fail report.
**Expected output:** All tests green; non-zero exit code if any fail.

Individual test scripts can also be run by name for targeted re-validation.
