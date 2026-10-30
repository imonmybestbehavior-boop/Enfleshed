# Current state — Enfleshed

Short, current facts only. Update this at the end of a task; put long evidence in the workstream's own doc. Last updated 2026-10-23 (main Studio navigation/animation sync; no repository gameplay source changes).

## Git snapshot

- Checked-out branch: `baseline/since-oct-11` at `f298859`. It carries a large **uncommitted** working tree (~20 modified tracked files, ~500 untracked: VFX work, enemy navigation/animation, new docs/scripts/tests) made with Codex. Treat all of it as the user's in-progress work: do not revert, reformat or commit it unless asked.
- Spell-creator expansion branches `phase0/test-harness` … `phase7/reactions` are stacked on an older base (each is 1 commit behind `baseline/since-oct-11`) and **not merged**. The plan for them lives outside the repo (project file `spell-creator/implementation-plan.md`).
- `phase7/reactions` (`5ba6e88`, "WIP: elemental reactions") is unfinished: 2 checks failing (38/40). It is checked out in a separate, prunable worktree under a temp folder. Do not touch it unless the task is Phase 7.

## Implemented (source exists and engine-independent checks pass)

- **Combat:** melee light/heavy/block/parry, sprint/dash, equipment switch (melee ↔ Magic Focus), inventory, loot, quick-slot consumables. See `docs/inventory-and-melee.md`, `docs/CONTROLS.md`.
- **Magic:** data-driven spell schema and validator, Grimoire authoring UI (library, editor, guided forge, preview, training), 65 showcase spells + 3 combat starters, slots 4 → 6 → 9 via mission XP, spell ranks, server-owned unlocks, summons, constructs, status effects, triggers/conditions, PvP stat caps.
- **Spell VFX:** composer + signature renderers; connected 3D fire projectile integrated into real casts (graphics/perf acceptance pending, see below).
- **Defend the Walls mission:** lanes, timed phases, wall integrity/breach/fallback, repairs, guards, final door, timer victory, persistent XP/Marks, replay. Practice sandbox via the staging "Practice gate".
- **Enemies:** 4 kinds (Basic, Swift, Brute, Elite) with telegraphed attacks; navigation fix (gameplay step 01, validated live 20/20 trials); procedural client-side enemy animation (step 02, implemented).
- **Platform:** session-locked profiles, idempotent rewards, feature flags/kill switches, telemetry.

## In progress / incomplete

| Workstream | State | Authority doc |
|---|---|---|
| Gameplay loop (Defend the Walls expansion, steps 00–17) | Step 02 implemented; **visual acceptance gate open** (Studio viewport captures came back blank). Step 03 not started. Stop after step 08 for user playtest. | Scope/sequence: `docs/gameplay-implementation-guide.md`. Evidence log: `docs/gameplay-implementation-status.md` (long; read the top status line and the newest section only). Design intent: `docs/defend-the-walls-gameplay-design.md`. |
| Spell VFX restyle (fire, beams, fields, Soul family) | Uncommitted Codex work in `SpellVFXSystem/*`, `SpellVFXController`, `tools/vfx_pipeline`, `assets/vfx/studies/*`. Graphics performance and batch-spawn hitches open. | `docs/spell-vfx-family-plan.md`, `docs/stylized-3d-fire-prototype-plan.md`, `assets/vfx/studies/3d_fire_v4/RUNTIME_INTEGRATION.md` |
| Spell-creator expansion (phases 0–11) | Phases 0–6 on unmerged branches; Phase 7 WIP (2 failing checks); 8–11 not started. | project file `spell-creator/implementation-plan.md` |

### Active scope rule (gameplay workstream)

While doing gameplay-loop steps: **do not modify magic systems, spell VFX, Grimoire, magic protocol or existing balance.** Full list and mixed-ownership files: `docs/gameplay-implementation-guide.md` "Scope" and `docs/gameplay-implementation-status.md` §2.

## Main Studio place

- On 2026-10-23, the existing main local place was backed up, selectively synced with the seven enemy navigation/animation/runtime-fixture scripts, and saved through Studio. Other 265 existing script containers were unchanged. Main place remains open in Edit; no cloud publish or new Play/visual acceptance was performed.
- Pre-sync backup: `place-backups/Enfleshed-before-gameplay-sync-20261023-170200.rbxlx`. Detailed receipts and file hashes: `docs/gameplay-implementation-status.md` §13. Use a fresh backup before future main-place syncs; do not rebuild over the main place with Rojo.

## Known issues and limits

- StyLua `--check src tests` fails on in-progress VFX files (baseline; not caused by other work).
- `scripts/check.sh` needs Bash; on the Windows machine run its component commands (see `AGENTS.md` → Testing).
- No working Studio viewport capture from agents so far; visual/feel checks need a human in Studio.
- Enemy imported meshes (`ServerStorage/EnfleshedModels`) are absent from the saved place, so placeholder enemy visuals render. See `assets/enemies/README.md`.
- Game-level gaps from the 2026-10-17 audit (no boss, audio, menus/settings, tutorial; short progression track): `docs/GAME_STATUS_AUDIT.md` §1, §7. Some of its findings may since be fixed; recheck before relying on one.

## Doc map (what is current vs historical)

- Current authorities: the docs in the table above, `README.md`, `docs/CONTROLS.md`, `docs/inventory-and-melee.md`, `docs/defend-the-walls.md`, `docs/FEATURE_FLAGS.md`, `docs/PVP_STAT_CAPS.md`, `docs/PERFORMANCE_BUDGET.md`.
- Reference/historical (read only when needed): `magic-lab.md` (82 KB), `magic-system-roadmap.md` (74 KB), `EMERGENT_MAGIC_AUDIT.md`, `GAME_STATUS_AUDIT.md`, `DEVELOPMENT_PLAN.md`, `spell-vfx-overhaul-milestone-1.md`, `gameplay-and-map-plan.md`, grimoire redesign docs.
