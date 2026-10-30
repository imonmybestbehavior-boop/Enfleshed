# Phase 11c — Transformation modes (Polymorph and Shapeshift)

Status: done (uncommitted, awaiting review; approved 2026-10-28, point 1 changed: DefendTheWalls Elites also count as bosses)
Request: Phase 11c of the spell-creator plan: a Mode on the Transformation payload — Scale (unchanged) | Polymorph (others, harmless critter 1–8 s, can move at 70% but not melee/cast/specials, visual swap, BreakOnDamage, bosses immune, crowd control with Stun's diminishing returns, Cleanse removes it) | Shapeshift (self, 5–60 s, melee uses another MeleeProfiles profile, Recast ends it) — with one of each per character, Polymorph pausing Shapeshift, safe restore, an OnTransformEnd event, PvP caps, registration, Forge/Lab, parity, emergent audit.
Scope: branch `phase11c/transformations` (worktree `C:/Users/bello/Documents/Projects/Enfleshed-phase11c`, from `phase11b/tether`). `MagicTransformationSpec` (+ new pure state rules), `MagicStatusEffectService`, `MagicPayloadExecutors`, `MagicService` (Recast ends Shapeshift, OnTransformEnd), `DamageService` (break on damage), `ActionRouter` + `MagicCrowdControlSpec.blocks` (gating), `EnemyService` (polymorphed monsters do not attack), `ItemRules` (a loadout from a bare profile), `CombatPolicy`, `SpellStatCaps`, schema/SpellSpec, Forge/Lab, tests. · Out of scope: Studio, the main checkout, CURRENT_STATE.md, new art, existing balance numbers, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- Transformation today: payload `{ Mode = "Scale", Multiplier 0.7–1.35, Duration }`, Polarity Neutral; `Status.transform` stores the baseline scale on the target's status state (`captureTransformBaseline` / `restoreTransform`), effects aggregate in `refreshAttributes`.
- Crowd control: `MagicCrowdControlSpec` (Stun DR: 2nd stun in 8 s at 50%, 3rd immune; `blocks(category, stunned, silenced)`; Cleanse selects by Polarity). Gating: `ActionRouter` (player Attack/Move/Cast), `MagicService` casting checks, `EnemyService.stunned()` stops Nascent/Enfleshed attacks.
- Melee: `ItemRules.meleeLoadout(item)` builds a loadout from `MeleeProfiles.Profiles[archetype]` scaled by item stats; `ActionRouter` passes `Equipment.meleeLoadout(player)` to `CombatService`.
- No boss concept exists yet (DefendTheWalls roles are Basic/Swift/Brute/Elite). No critter model exists in `src`.

## Design (proposed)
- **Payload.**
  - `Transformation.Mode = "Scale" | "Polymorph" | "Shapeshift"` (Scale unchanged).
  - Polymorph: `Duration` 1–8, `BreakOnDamage = true`.
  - Shapeshift: `Duration` 5–60, `Profile` (one of `MeleeProfiles.Profiles`). It is valid only on self-targeted spells (an Enchantment on yourself), and may sit next to a Scale payload in the same spell.
  - Polarity by mode: Scale Neutral, Polymorph Bane (hostile in `CombatPolicy`), Shapeshift Boon (`Schema.TransformPolarity`). Cleanse uses the effect's polarity.
- **Pure rules (`MagicTransformationSpec` additions, unit-tested).** Per-character state `{ Polymorph?, Shapeshift? }`:
  - Replacing: a new effect of the same mode replaces the old.
  - Pause/resume: Polymorph pauses a running Shapeshift (its remaining time is frozen) and it resumes when the Polymorph ends.
  - Lifecycle: `tick` returns what ended; break on damage from anyone but the caster when BreakOnDamage.
  - Gating: `blocks(category)` (Attack and Cast blocked; movement allowed).
  - Melee: `meleeProfile`. Movement: the 0.7 speed factor.
  - Polymorph duration: Stun DR applied through the shared `stunHistory`, then the PvP cap.
  - Bosses: refused when the target model has the `MagicBoss` attribute (new; nothing sets it yet).
- **Runtime (`MagicStatusEffectService`).**
  - Polymorph and Shapeshift are status entries on the target's state.
  - Attributes: `MagicPolymorphed` (gates actions, adds 0.7 to the slow multiplier) and `MagicShapeshiftProfile`.
  - Visual swap: store each BasePart's/Decal's Transparency, set it to 1, and weld a part-built critter (body, head, ears; the spell's colour) to the root. Restore only if the same model still exists, so restore is safe after respawn or replacement. The Humanoid, hitbox, camera and network ownership are untouched.
  - Restore on expiry, break, Cleanse, death, respawn (CharacterRemoving / Died) and leaving.
  - `onEnd` callbacks fire `OnTransformEnd` on the spell on expiry, break, Cleanse and recast; not on death or leaving.
- **Gating.**
  - Players: `CrowdControl.blocks` gains `polymorphed`: Attack and Cast are blocked, Move/dash are allowed.
  - Monsters: `EnemyService` treats `MagicPolymorphed` like stunned for attacks only (they still walk).
  - Break on damage: `DamageService` calls `Status.breakPolymorph(target, attacker)` after damage lands (beside `breakStealth`).
- **Shapeshift melee.**
  - `ItemRules.profileLoadout(name)` builds an unscaled loadout from a profile.
  - `ActionRouter` uses it instead of the equipped weapon while `MagicShapeshiftProfile` is set (so a Magic Focus user gets claws too).
  - Recast: pressing the slot of the spell that shapeshifted you ends it (Magic.start, before cooldown; free), firing `OnTransformEnd`.
- **Event.** `OnTransformEnd` ("When the transformation ends") on Forms that can carry Transformation; its targets are the transformed character.
- **PvP caps (provisional):** `MaxPolymorphDurationVsPlayer` 1.5 open / 1.0 ranked, and BreakOnDamage is always forced on against players. Shapeshift has no cap.
- **MagicLab (provisional):** `MinPolymorphDuration = 1`, `MaxPolymorphDuration = 8`, `PolymorphSpeedMultiplier = 0.7`, `MinShapeshiftDuration = 5`, `MaxShapeshiftDuration = 60`.

## Milestones
- [x] M1 Transformation rules (pure)
  - Accept: spec state functions above + DR/PvP duration + boss refusal; unit tests (replace, pause/resume, break on damage except caster, gating, profile, Cleanse removal, DR shortening).
  - Verify: `run_luau_unit_tests.py $LUAU transform`
  - Result: transform_state 1/1, StyLua clean. New dependency-free `MagicTransformStateSpec` (kept apart from `MagicTransformationSpec`, which loads MagicLab): `isBoss` (MagicBoss or Elite), `polymorph`/`shapeshift` (replace, pause), `endPolymorph` (resume), `endShapeshift`, `tick`, `breaksOnDamage` (not by the caster), `blocks` (Attack/Cast), `meleeProfile`, `speedMultiplier`, `polymorphDuration` (range + PvP cap). The test also checks Stun then Polymorph through `MagicCrowdControlSpec.applyStun` (halved).
- [x] M2 Schema, validation, editors' data
  - Accept: Mode options + mode-specific fields (ShowWhen), ranges, Profile options from MeleeProfiles, Shapeshift self-only, polarity by mode in schema/CombatPolicy, `OnTransformEnd` event (label/help/order/timings), lab tests.
  - Verify: magic suite; parity
  - Result: magic suite exit 0 (transformation block in its own function scope: the lab test's main function sits at Luau's 200-register limit), parity 56/56, audit unchanged. Transformation Mode options + `BreakOnDamage` (new `Boolean` payload-field support in SpellSpec) + `Profile` (`Schema.ShapeshiftProfiles` from MeleeProfiles; the lab preamble loads it lazily); per-mode limits in SpellSpec (Scale ≤ MaxDuration with a multiplier; Polymorph 1–8 s; Shapeshift 5–60 s with a profile, SelfEnhancement + Self only); one Transformation per mode per spell; `Schema.TransformPolarity`; `CombatPolicy.isHostilePayload` treats Polymorph as hostile; `normalizePayload` keeps only the chosen mode's settings. `OnTransformEnd` on every Humanoid-target Form, reactive payload timings and Explode/SpawnEffect; it needs a Polymorph or Shapeshift on another trigger.
- [x] M3 Runtime, gating, audit
  - Accept: status-service Polymorph/Shapeshift with visual swap + safe restore + attributes; executor branch; break on damage; player/monster gating; shapeshift loadout; Recast ends Shapeshift; OnTransformEnd; audit scenarios (polymorph NPC: no attack, breaks on another's damage, restored; boss refused; shapeshift profile change and restore on expiry/death; polymorph pauses then resumes shapeshift; Stun then Polymorph gives a shortened polymorph).
  - Verify: emergent audit; parity (wiring); magic suite; unit tests
  - Result: audit 238/0 failed (15 TRANSFORM checks run the real `MagicTransformService` with recorded visuals: polymorphed NPC can move but not attack/cast, critter + 70% walk, caster's damage does not break it, another's does and it is restored, OnTransformEnd once; Elite refused; shapeshift profile on, off on expiry and on death; polymorph pauses then resumes a shapeshift with its 6 s; Stun then Polymorph halves it), parity 57/57 (`test_transformation_modes_gate_restore_and_share_crowd_control`; the Stun/Silence interrupt assertion updated for the Polymorphed reason), magic suite exit 0, unit tests 83/83, rojo build ok, modules compile. New `MagicTransformService` (state per Humanoid on the pure spec, overridable clock, `step`) + `MagicTransformVisual` (hide parts / weld a part-built critter / restore only the same model); Status gains `diminish` (shared stunHistory) and `setSpeedFactor` (folded into the slow multiplier, kept when the status state is removed). Gating: CrowdControl `blocks(..., polymorphed)`, ActionRouter, cast interrupts, EnemyService attacks. Melee: `ItemRules.profileLoadout` + `ActionRouter.meleeLoadoutFor`. Cleanse merges `Transform.cleanseCandidates`. Recast of the shapeshifting spell ends it before the cooldown gate. PvP caps live in SpellStatCaps (read by the executor).
- [x] M4 Registration, editors, PvP caps
  - Accept: Forge/Lab controls (mode, profile picker, break on damage, "When the transformation ends"), PvP caps in both profiles + stat-cap tests, parity consumers.
  - Verify: parity; magic suite incl. `--forge-only`; stat caps test
  - Result: parity 57/57, `--forge-only` exit 0, stat_caps 1/1, StyLua clean. The Forge and Lab render Transformation through their generic payload editors: Mode chips/select (both call `Schema.normalizePayload`, which resets the fields for the new mode), ShowWhen hides Multiplier / BreakOnDamage / melee style by mode, and the melee style lists `Schema.ShapeshiftProfiles`. Forge phrase "When the transformation ends". PvP `MaxPolymorphDurationVsPlayer` 1.5 / 1.0 tested. Companions still never cast Transformation (unchanged).
- [x] M5 Integration and handoff
  - Accept: full gate pass; this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh`; Studio items listed as pending.
  - Result: `bash scripts/check.sh` 40/40 PASS (83/83 unit tests). Not committed or pushed. Pending Studio Play (source checks only): the critter look and that hidden parts come back (accessories, faces); a polymorphed player's controls (walk at 70%, no melee/cast, dash allowed) and camera; polymorphed Nascent/Enfleshed not attacking; shapeshift melee feel with each profile, including from a Magic Focus; recast ending a shapeshift; Cleanse removing both; restore after death and respawn; PvP polymorph caps in open/ranked zones.

## Open questions / blockers
- Bosses: a `MagicBoss` model attribute or a DefendTheWalls `MissionRole = "Elite"` makes a character immune (decided 2026-10-28).
- Critter: no critter model exists in the code, so a small part-built placeholder (in the spell's colour) is welded on. OK?
- Dash while polymorphed: allowed (it is movement) — or blocked like other abilities?
- OnTransformEnd fires on expiry, break on damage, Cleanse and recast, not on death or leaving (plan).
- Shapeshift is self-only through an Enchantment on yourself (SelfEnhancement with Self targeting) (plan).
