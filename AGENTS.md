# AGENTS.md — Enfleshed

Instructions for coding agents (Claude Code reads this through `CLAUDE.md`; Codex reads it directly). Keep this file short; put detail in the linked docs.

Roblox (Luau) combat game built with Rojo: wave defense mission ("Defend the Walls") plus a combat sandbox with an open-ended spell-creation system (Grimoire).

## Start of every task (cheap orientation)

1. Read `CURRENT_STATE.md` (what works, what is open, active workstreams and their scope rules).
2. Read only the `ARCHITECTURE.md` section for the area you will touch. Do not re-survey the repository.
3. Run `git status --short -- src tests scripts docs` and look at diffs only for files you will touch. The working tree normally contains uncommitted user/Codex work; it is not yours to revert, format or "clean up".
4. If a task file exists in `docs/tasks/` for this work, resume from its first unchecked milestone.

## Where to look (and where not to)

- Search `src/` first, then `tests/`. Scope searches by path (`src/server/Services`, `src/shared/Modules`, ...) and glob (`*.luau`).
- Do not search or read: `assets/` (744 MB, generated VFX studies/previews), `Shelved Project/` (archived city project), `place-backups/`, `*.rbxlx` (32 MB place XML), `tools/.validation-tools/`, `tmp/`, `__pycache__/`. Only open `assets/` or `tools/vfx_pipeline/` when the task is VFX asset pipeline work.
- Very large files: `MagicLabController` (180 KB), `MagicService` (163 KB), `GuidedSpellForge` (80 KB), `MagicSchema` (65 KB), `SpellSpec` (57 KB), `GrimoireStarters` (54 KB), `SummonService` (50 KB), `SignatureRenderer` (48 KB), `EnemyService` (37 KB). Generated data: `SpellVFXSystem/Assets/ConnectedFirePoses.luau`, `*.rbxmx`. Grep for the function you need and read a line range; never read these whole.
- `docs/` holds ~35 design/audit docs, many long and partly historical. Read one only when `CURRENT_STATE.md` or `ARCHITECTURE.md` points to it for your task.

## Rules

- Change only what the task needs. No drive-by refactors, renames, reformatting or regenerated assets.
- Reuse existing services and APIs (see `ARCHITECTURE.md`). Server is authoritative; client requests go through `Shared/Networking/Protocol` and `ActionRouter`.
- Put new rules/math in a pure module under `src/shared/Modules/` with a Luau test, and keep Roblox-instance code thin. This is the existing pattern.
- Keep new tuning values in `src/shared/Configuration/`, labeled provisional. Do not change existing balance numbers unless the task asks.
- New server modules start with `--!strict`. Format with StyLua (`.stylua.toml`), on touched files only.
- Do not overwrite `Enfleshed-Defend-The-Walls.rbxlx` (it may be open/locked in Studio). Build to a temp path.
- Do not commit, push, switch branches or touch other branches/worktrees unless asked.
- Never report a source/build check as a live Studio playtest. Say which checks actually ran.
- Active workstream scope rules in `CURRENT_STATE.md` override general instructions here.

## Workflow

Simple task (one area, a few files): orient → read the relevant code → edit → focused test → finish.

Complex task (multiple systems, >~5 files, multi-session, or ambiguous design):

1. Plan first, separately from implementing. Write `docs/tasks/<slug>.md` from `docs/tasks/README.md`: milestones, each with deliverable, acceptance criteria and verification. Get the plan agreed if design choices are open.
2. Implement one milestone at a time. After each one passes, tick it and add 1–3 lines of findings to the task file. That file is the resume point; a resumed session reads it plus `CURRENT_STATE.md`, not the whole repo.
3. At the end: run the broader checks once, update `CURRENT_STATE.md` (short, current facts only), and move durable lessons into `ARCHITECTURE.md` or the relevant doc.

## Testing (focused first, broad once)

Tools come from Rokit (`rokit.toml`: rojo 7.7.0, StyLua 2.5.2, luau 0.742.0). On Windows there is usually no Bash, so `scripts/check.sh` will not run directly; run the component commands. Use `python -X utf8` on Windows to avoid cp1252 decode errors. `$LUAU` = path to the rokit `luau` binary.

| Changed area | Focused check |
|---|---|
| a pure module in `src/shared/Modules` with a `tests/test_<name>.lua` | `python scripts/run_luau_unit_tests.py $LUAU <name-filter>` |
| a module with a self-contained spec `tests/*_spec.luau` | `$LUAU tests/<name>_spec.luau` |
| magic / Grimoire / spell VFX | `python scripts/run_luau_magic_tests.py $LUAU [--library-only --workflow-only --starters-only --visual-plan-only --composer-only --vfx-only --forge-only --action-flow-only]` (pick the flag for the area) |
| inventory / UI layout | `scripts/run_luau_inventory_tests.py`, `scripts/run_luau_ui_tests.py` |
| wiring/source-contract tests | `python -I tests/test_<name>.py` (map and place-reference tests need `ENFLESHED_PLACE_FILE=<temp build>.rbxlx`) |
| any source change, before finishing | `rojo build default.project.json -o <temp>/check.rbxlx` and `stylua --check <touched files>` |

Run the full gate (`bash scripts/check.sh`, or every component above) once at the end of a complex task or at an integration checkpoint, not after every edit. Do not rerun a check that already passed unless the code it covers changed since. Known baseline failure: StyLua reports existing formatting differences in in-progress VFX files; do not fix those as part of unrelated work. Gameplay, animation, VFX look and multiplayer need Studio Play to verify; list them as pending if Studio is unavailable.

## Recording discoveries

- Short, current facts → `CURRENT_STATE.md`. Module boundaries/dependencies → `ARCHITECTURE.md`. Per-task progress → `docs/tasks/<slug>.md`. Long evidence logs stay in the workstream's own status doc.
- Edit existing docs in place; do not create a new doc when an existing one covers the topic. Delete nothing in `docs/` without reviewing it.
