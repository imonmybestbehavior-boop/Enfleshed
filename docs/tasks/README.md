# Task files (milestones for complex work)

Use a task file only for complex or multi-session work (see `AGENTS.md` → Workflow). One file per task: `docs/tasks/<short-slug>.md`. It is the resume point: a new session reads `CURRENT_STATE.md`, then this file, and continues at the first unchecked milestone without re-surveying the repo.

Workstreams that already have their own step plan and status log (for example the gameplay loop in `docs/gameplay-implementation-guide.md`) keep using those; the numbered steps are the milestones. Do not duplicate them here.

Rules:

- 2–6 milestones. Each one is a reviewable unit that leaves the build working.
- Acceptance criteria must be checkable (a test passes, a value appears, a file exists), not "works well".
- Verification names the exact command or Studio action. Prefer the focused check; the full gate runs once, in the last milestone.
- After finishing a milestone: tick it, fill in "Result" in 1–3 lines (files changed, checks run, anything surprising). Do not paste logs.
- When the task is done, move durable facts to `CURRENT_STATE.md` / `ARCHITECTURE.md` and mark the file `Status: done`. Keep it short or delete it once merged.

## Template

```markdown
# <Task title>

Status: planning | in progress | done
Request: <one line, what the user asked for>
Scope: <files/areas allowed> · Out of scope: <what must not change>

## Context (only what a resumed session needs)
- Relevant files: <paths + function names>
- Decisions: <choices made and why>

## Milestones

- [ ] M1 <deliverable>
  - Accept: <objective criteria>
  - Verify: <exact command or Studio steps>
  - Result:
- [ ] M2 <deliverable>
  - Accept:
  - Verify:
  - Result:
- [ ] M3 Integration and handoff
  - Accept: full gate passes or failures match the known baseline; CURRENT_STATE.md updated
  - Verify: `bash scripts/check.sh` (or its component commands on Windows); Studio items listed as pending if not observed
  - Result:

## Open questions / blockers
- 
```
