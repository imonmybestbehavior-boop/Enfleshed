# Phase 11d — Spell vs Spell (Dispel, Force on spells, Field lenses)

Status: done (2026-10-28), uncommitted
Request: Phase 11d of the spell-creator plan: steps that target spells (`TargetKind = "Spell"`, Hostile/Allied/Any) — a Dispel payload (Shorten / End with a complexity rule; persistent constructs owner-only; Tether dispel = snap), Force moving Field/Aura centres and unattached Constructs (wall-checked), an `OnDispelled` event, Field lenses (`AffectsSpells`: AddMark / ScalePotency / Slow on projectiles crossing the Field, once per projectile per field); limits, PvP caps, registration, Forge/Lab, parity, emergent audit.
Scope: branch `phase11d/spell-vs-spell` (worktree `C:/Users/bello/Documents/Projects/Enfleshed-phase11d`, from `phase11c/transformations`). Schema/SpellSpec, `MagicTriggerDispatch` (spell targets), a new Roblox-free `MagicSpellTargets` server module, `MagicService` (record lookup, dispel/force effects, `OnDispelled`, lens scan in the Field update, lens marks on projectile impact), `MagicProjectileBehaviorExecutors` (Absorb scan reused), `SpellStatCaps`, Forge/Lab, tests. · Out of scope: Studio, the main checkout, CURRENT_STATE.md, VFX art, existing balance numbers, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- Active records live in MagicService `active` (`Kind` Field / Aura / Construct / Tether, `Position`, `Definition`, `Caster`, `Player`, `RemainingLifetime`, `Visual`); Fields/Auras use `AreaGrowth`/`Geometry` sizes; Constructs keep a `Visual` model of `ConstructPartNN`; Tethers have `AnchorA`/`AnchorB` and a snap path (`tetherDeps.Finish(..., "Snap")` after OnBreak).
- Persistent Constructs have no active record: a model with `MagicPersistentConstruct*` attributes, removed from the store when destroyed (`watchPersistentConstruct`).
- The Absorb/Reflect scan is `FindIncomingProjectile` in MagicService's projectile behavior context (hostile, closest, contact range).
- `Spec.estimate(d).Complexity` is the spell's complexity; cascades are bounded by the operation budget and `MaxMagicEventDepth`.

## Design (proposed)
- **Spell targets.** A step field `TargetKind = "Character" | "Spell"` and `SpellRelationship = "Hostile" | "Allied" | "Any"` (default Hostile, by the target spell owner's relationship to the caster).
  - A Spell step resolves the live Fields, Auras, Constructs and Tethers it touches: the impact point or `HitPart` for OnImpact; the Explode radius for Explode steps; the event's area for Wave/Field/Aura events.
  - The hit test (pure `MagicSpellTargetSpec`) uses a circle of the area's outer radius for Fields/Auras, the model's bounds (or its hit part) for Constructs, and a 2-stud-wide line for Tethers.
  - Only Dispel and Force (plus visuals) may sit in a Spell step; validation refuses other payloads, and refuses Dispel in Character steps.
  - Dispatch hands the resolved records to the payload as `context.SpellTargets`.
  - Persistent Construct models are found by hit part or bounds as well.
- **Dispel payload.** `Mode = "Shorten" (Seconds 1–30) | "End"`.
  - End removes the spell only when the target's estimated complexity is at most the dispel spell's own; otherwise it shortens the target by half its remaining time.
  - Untimed spells (UntilToggledOff, Persistent) can only be Ended, never shortened.
  - Persistent Constructs: only their owner may End them; others get nothing.
  - Constructs or Auras attached to a character can be dispelled; Enchantments cannot (Cleanse).
  - A dispelled Tether snaps (OnBreak, no OnExpire).
  - An End fires `OnDispelled` once, before cleanup, and the spell then ends without OnExpire.
  - Polarity: Bane when the step targets Hostile spells, otherwise Neutral (`Schema.DispelPolarity`). The parity known-gap lists are updated.
- **Force on spells.**
  - Movable: unattached Field and Aura centres (record `Position` + marker), and non-persistent, unattached Constructs (PivotTo).
  - Distance: up to 10 studs along the step's direction.
  - Walls: wall ray, ground and clearance checks reused from Displacement (`displaceTarget`'s rules, factored into a shared helper). Blocked moves stop short at the wall (padding), and a move under 0.5 stud does nothing.
- **Limits.** Each spell target takes at most one Dispel or Force per root cast: a set kept on the cascade's operation budget. Everything spends the operation budget and stays under `MaxMagicEventDepth` (OnDispelled emits at depth + 1).
- **Field lenses.** `Field.AffectsSpells = { Who = Hostile | Allied | Any, AddMark = Element?, ScalePotency = 0.5–1.5?, Slow = 0.3–1.0? }` (at least one modifier).
  - The Absorb scan is generalised into `FindProjectilesIn(area, who, owner)`, which Absorb/Reflect and the Field update both use.
  - Each Field records `LensedProjectiles[projectile]`, so a projectile is changed at most once per field: `PotencyMultiplier *= ScalePotency`, `Velocity *= Slow`, and `LensMarks += Element`.
  - On impact, MagicService applies `Status.elementalMark(element, 1 stack)` to the humanoid hit for each lens mark.
  - PvP floors apply when the projectile belongs to a hostile player.
- **PvP caps (provisional):** `MinLensPotencyVsPlayers` 0.7 / 0.8, `MinLensSlowVsPlayers` 0.6 / 0.7, `MaxSpellForceDistance` 10 / 6.
- **MagicLab (provisional):** `MaxDispelSeconds = 30`, `MaxSpellForceDistance = 10`, `TetherDispelWidth = 2`.

## Milestones
- [x] M1 Rules (pure)
  - Accept: `MagicSpellTargetSpec` (hit tests per kind, relationship filter), `MagicDispelSpec` (End/Shorten with the complexity rule and halving fallback, untimed spells, persistent owner rule, once-per-cast), lens modifiers with once-per-field and PvP floors, spell-force distance with the PvP cap; unit tests.
  - Verify: `run_luau_unit_tests.py $LUAU spell_target dispel lens`
  - Result: spell_target 1/1 (one test file covers all three modules), StyLua clean. `MagicSpellTargetSpec` (relationship filter, area/bounds/tether hit tests on X/Y/Z, force distance with PvP cap, once-per-cast `claim`), `MagicDispelSpec` (End/Shorten with complexity rule and halving fallback, untimed only End, persistent owner rule, polarity by relationship), `MagicSpellLensSpec` (once per field, PvP floors, `hasModifier`).
- [x] M2 Schema, validation, event
  - Accept: `TargetKind`/`SpellRelationship` step fields; Dispel payload (fields, polarity, parity consumers); Force allowed in Spell steps; validation (only Dispel/Force in Spell steps, Dispel only there); `OnDispelled` on Field/Aura/Construct/Tether; `Field.AffectsSpells`; lab tests.
  - Verify: magic suite; parity
  - Result: magic suite exit 0 (spell-vs-spell block in its own function scope), parity 57/57 (Dispel in the BANE set; registered in all 11 consumers, no known gap), audit unchanged. Step fields `TargetKind` / `SpellRelationship`; Spell steps take only Dispel/Force (Dispel only there) and no Conditions (they check characters); Dispel payload (`Mode` Shorten/End, `Seconds` 1–30 for Shorten), allowed in Explode; `Schema.DispelPolarity`; `OnDispelled` on Field/Aura/Construct/Tether (+ reactive payload timings, Explode/SpawnEffect); `Field.AffectsSpells` (Who + at least one of AddMark / ScalePotency 0.5–1.5 / Slow 0.3–1). Dispatch: a Spell step gets `SpellTargets` from `context.ResolveSpellTargets` and an empty character list; the Dispel executor and a Force branch call `context.DispelSpells` / `context.ForceSpells` (wired in M3).
- [x] M3 Runtime and audit
  - Accept: `MagicSpellTargets` (resolve, dispel, force; Roblox-free with deps) wired into MagicService and Dispatch; OnDispelled and Tether snap; persistent owner rule; Force with wall stop; lens scan + impact marks; audit scenarios (cheap Field ended / expensive halved; persistent construct vs non-owner; Tether dispel → OnBreak; Construct OnDispelled once; Force stops at a wall; fire lens marks an allied projectile's target; slow lens slows a hostile projectile once; two Fields dispelling each other on OnDispelled do not loop).
  - Verify: emergent audit; parity (wiring); magic suite
  - Result: audit 250/0 (12 SPELLS checks), parity 58/58 (new spell-vs-spell wiring test), magic suite exit 0, rojo build ok. Finding: Explode builds its own context and dropped `SpellTargets`, so Dispatch now runs a Spell step's payloads directly and validation allows only Explode (its radius is the reach) or no behavior. `projectilesNear` is shared by FindIncomingProjectile and the lens scan.
- [x] M4 Registration, editors, PvP caps
  - Accept: Forge ("Target spells" toggle with relationship, Dispel, "When it's dispelled", LENS section in the Field editor) and Lab equivalents; PvP caps in both profiles + stat-cap tests; parity consumers (Dispel registered everywhere, no known gap).
  - Verify: parity; magic suite incl. `--forge-only`; stat caps test
  - Result: magic suite exit 0, parity 58/58 (editor wiring asserted), stat caps 1/1 (lens floors and spell Force cap in both PvP profiles, none in PvE), spell_target 1/1, compile check ok (Forge, Lab). Pure `stepMode`/`syncStep` decide whether a step can target spells (Dispel requires it, Force only offers it) and keep `TargetKind` consistent after picker/toggle/remove edits in both editors. Forge: "Target spells" + "Which spells" in the Payload and Explode inspectors, LENS section in the Field editor. Lab: same controls on the primary step and the Explode blast, LENS after TRAP (kept on geometry change).
- [x] M5 Integration and handoff
  - Accept: full gate pass; this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh`; Studio items listed as pending.
  - Result: full gate 40/40 (first run failed `--forge-only`: the Forge harness module map lacked `MagicSpellTargetSpec`; added). Not committed. Studio pending: dispel on live Fields/Auras/Constructs/Tethers (hit areas, OnDispelled, Tether snap), Force moving a Field centre / Construct against real walls, lens marks/slow/potency on real projectiles, saved-construct owner rule, PvP caps with two players, Forge/Lab layout of the new controls.

## Open questions / blockers
- Hit test approximations: Fields/Auras as a circle of their outer radius, Tethers as a 2-stud line, Constructs by bounds or hit part (plan). Exact per-shape tests (cones, rings) are not planned.
- Lens "Who" is the projectile owner's relationship to the Field's owner (plan).
- Dispel on untimed spells (UntilToggledOff, Persistent): only End applies; Shorten does nothing (plan).
- Complexity compares each spell's estimated complexity as authored (`Spec.estimate`), not its current state (plan).
- "Once per spell target per cast" is per root cast, so a cascade of the same cast cannot dispel or push the same spell twice (plan).
