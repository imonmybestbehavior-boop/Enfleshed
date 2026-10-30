# Phase 7 — Elemental reactions

Status: done
Request: finish Phase 7 of the spell-creator plan (elemental reactions) from the WIP commit `5ba6e88`.
Scope: branch `phase7/reactions` (temp worktree). Magic modules, executors, status service, conditions, magic tests, `docs/PVP_STAT_CAPS.md`. · Out of scope: Studio, gameplay-loop files, VFX restyle, existing balance numbers, the main checkout's uncommitted work.

## Context (only what a resumed session needs)
- Already done in `5ba6e88`: `MagicLab.ElementalInteractions` is one list (starters `{ Incoming, Effects }` + six reactions `{ Name, Existing, Incoming, ConsumeStacks, Effects }`, `ReactionMemory = 5`); `MagicElementalInteractionSpec` (`effectsFor`, `findReaction`, `reactionEffects`, `spellId`); `Status.checkReaction`, reaction check inside `Status.elementalMark` (before stacking), Frozen = Stun with SpellId `Reaction:Freeze`, concealment zones that block Reveal, `MagicLastReaction`/`MagicLastReactionAt` attributes; executors route starter and reaction effects through `Payloads.execute` (PvP caps) and spend the cascade budget; Force hits can Shatter; MagicService `ctx.FindHumanoidsNear`, `ctx.SpawnReactionField`; SpawnEffect `Element` override.
- Relevant files: `src/shared/Configuration/MagicLab.luau` (ElementalInteractions), `src/shared/Modules/MagicElementalInteractionSpec.luau`, `src/server/Services/MagicStatusEffectService.luau` (`checkReaction`, `elementalMark`), `src/server/Services/MagicPayloadExecutors.luau` (`applySecondary`, `applyReaction`, `ElementalMark`, `Force`), `tests/emergent_magic_audit_spec.luau`, `tests/test_magic_registry_parity.py`.
- Decisions: reactions never trigger reactions (`FromMark`/`FromReaction`); one reaction per landing (first match in list order); incoming mark still stacks after a reaction.

## Milestones

- [x] M1 Fix the 2 failing checks
  - Accept: audit harness maps `MagicOperationBudget`; parity test checks the new list-shaped config (each element still has a starter entry) and the new executor path; both pass.
  - Verify: `python -X utf8 -I tests/test_magic_registry_parity.py`; `python -X utf8 scripts/run_emergent_magic_audit.py $LUAU`
  - Result: parity OK; audit 154/154. Changed `tests/test_magic_registry_parity.py` (list-shaped config regex + `applySecondary` routes through `Payloads.execute`) and `tests/emergent_magic_audit_spec.luau` (maps `MagicOperationBudget`). Surprise: the harness's generic `StatusDouble` returned `1, true`, which the new code read as a reaction; added explicit `elementalMark`/`checkReaction` doubles matching the real signatures.
- [x] M2 `Status.Reaction` condition property
  - Accept: `MagicConditionSpec.Properties.Status.Reaction` (String, `=`/`~=` style operators) exists; `MagicConditions` resolves it from `MagicLastReaction` only within `ReactionMemory` seconds, else `""`; a step condition "Reaction = Freeze" validates.
  - Verify: `python -X utf8 scripts/run_luau_unit_tests.py $LUAU condition`; `python -X utf8 scripts/run_luau_magic_tests.py $LUAU`
  - Result: condition unit tests 4/4, magic suite exit 0. The window rule lives in the pure `MagicElementalInteractionSpec.recentReaction` (unit-tested in M3); `MagicConditions` only reads the two attributes. Uses the existing string operators (`==`, `!=`, `Is`, `IsNot`, ...).
- [x] M3 Reaction tests
  - Accept: unit test for `MagicElementalInteractionSpec` (starters equal the pre-Phase-7 values, `findReaction` order/matching, Force incoming); audit scenarios for all six reactions, "no reaction chains", and a static/parity check that reaction effects go through `Payloads.execute` (PvP caps).
  - Verify: `python -X utf8 scripts/run_luau_unit_tests.py $LUAU elemental`; `python -X utf8 scripts/run_emergent_magic_audit.py $LUAU`; parity test
  - Result: new `tests/test_magic_elemental_interaction_spec.lua` (2/2 elemental unit tests); audit 176/176 (22 new REACT checks: each reaction, one per landing, starters unchanged, no chains incl. a mark's own Force not shattering); parity 48/48 with budget/cap/order checks. PvP caps are covered statically (reaction effects → `applySecondary` → `Payloads.execute`); the audit world has no player owners, so caps aren't exercised there.
- [x] M4 Docs
  - Accept: `docs/PVP_STAT_CAPS.md` no longer lists the mark-secondary gap; it states that starter and reaction effects go through SpellStatCaps.
  - Verify: read the section
  - Result: "Known gap" paragraph replaced by a "Mark-triggered effects" bullet under "Where caps are applied" (starters + all six reactions via `applySecondary` → `Payloads.execute`; Freeze gets Stun DR and the 0.5 s cap; reaction Fields capped as spawned effects).
- [x] M5 Integration and handoff
  - Accept: full gate 40/40 (or only known-baseline failures); this file marked done; commit + push on `phase7/reactions` (per the Phase 7 brief).
  - Verify: `bash scripts/check.sh` in the worktree; Studio items listed as pending (reactions in live combat, Firestorm/smoke Fields, Reveal blocked in smoke).
  - Result: `bash scripts/check.sh` 40/40 (StyLua, rojo build, all python tests, magic/inventory/ui suites, emergent audit 176/176, unit tests). Studio-only, still pending: reactions in live combat, Firestorm/Toxic-smoke Field visuals and ticks, Reveal refused inside smoke, Freeze DR against players.

## Open questions / blockers
- The worktree branch predates the `CURRENT_STATE.md`/`AGENTS.md` docs (they live on `baseline/since-oct-11`), so I update `CURRENT_STATE.md` there only if you ask.
