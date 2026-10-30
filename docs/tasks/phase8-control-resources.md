# Phase 8 — Control and resources

Status: done (uncommitted, awaiting review)
Request: Phase 8 of the spell-creator plan: Taunt/Fear (NPC-only), Stealth (monsters only, player path behind a flag), DrainResource/RestoreResource, ratio heals with overflow, full registration.
Scope: branch `phase8/control-resources` (temp worktree, from `phase7/reactions`). Magic schema/spec/executors/status service, `EnemyService` target selection, `MagicService` context hooks, `SpellStatCaps`, a new client controller for the stealth render path, magic tests. · Out of scope: Studio, the main checkout, gameplay-loop files, VFX restyle, existing balance numbers, `NascentAttackSelector`, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- Anchors on this branch (older than main): `EnemyService` disengage path and player scan ≈ lines 962–990 (`target = nil … setState("Idle")`, then the `Players`/`CityHuman` candidate loop); `targetRoot(subject)` ≈ 473. `MagicRevealSpec.attributeNames(userId)`. `MagicSpecialResourceSpec.spend/advance`. OnDamageDealt is emitted in MagicService's `Damage.Applied` listener (`damageContext.EmitEvent("OnDamageDealt", target)`).
- Pattern: each payload gets a timed status or executor, a pure rule module with a Luau unit test, schema entry with Polarity, parity-consumer entries, Forge icon/verb, Lab category.
- Decisions (proposed, see Open questions): Taunt/Fear are timed statuses whose attributes the server writes on the NPC model (`MagicForcedTarget` ObjectValue, `MagicFearSource` Vector3 + expiry); executors skip player targets. Fear = disengage (drop target, idle), no fleeing. Stealth = timed status → `MagicStealthed`; cleared by the holder dealing damage and by any Reveal on them. Drain moves the resource target → caster; Restore adds to the target. Ratio modes treat `Amount` as a percent (0–100).

## Milestones

- [x] M1 Taunt and Fear (NPC-only)
  - Accept: pure `MagicControlStateSpec` (active forced target / fear source with expiry); `Taunt`/`Fear` payloads (Polarity Bane) in schema, executors (players skipped), status service writing/clearing the attributes; `EnemyService` checks forced target and fear before the player scan, Fear reuses the disengage path; registered in every parity consumer; Forge/Lab entries.
  - Verify: `python -X utf8 scripts/run_luau_unit_tests.py $LUAU control_state`; `python -X utf8 -I tests/test_magic_registry_parity.py`; `python -X utf8 scripts/run_luau_magic_tests.py $LUAU`
  - Result: control_state 1/1, parity 49/49, magic suite exit 0, StyLua clean on touched files. New `MagicControlStateSpec` (Fear > valid Taunt > scan; longest effect wins); `Status.taunt/fear` (players skipped) write `MagicForcedTarget`/`…Until`/`MagicFearSource`/`MagicFearUntil` on the NPC model; EnemyService decides before the scan, Fear skips scan + objective. Limits `MaxTauntDuration = 6`, `MaxFearDuration = 4` (provisional).
- [x] M2 Stealth (monsters only, player path behind a flag)
  - Accept: `Stealth` payload (Boon) → `MagicStealthed`; EnemyService scan skips stealthed candidates; cleared when the holder deals damage and by Reveal on them; PvP profiles get `StealthHidesFromPlayers = false`; pure `MagicStealthSpec.hiddenFrom(...)` decides player-side hiding using `MagicRevealSpec` attributes; a client controller applies it only when the flag is true (no new code needed to turn it on); registered + editors.
  - Verify: `run_luau_unit_tests.py $LUAU stealth`; parity test; magic suite
  - Result: stealth 1/1, parity 50/50, magic suite exit 0, StyLua clean. `MagicStealthSpec` (monsters skip; player hiding needs the setting + can-fight + not revealed by that viewer via `MagicRevealSpec`); `Status.stealth`/`breakStealth` (DamageService on dealt damage, `Status.reveal`); EnemyService skips stealthed candidates and drops a target that stealths; `StealthHidesFromPlayers = false` in both PvP profiles; `MagicStealthController` returns immediately while off. Stealth added to CombatPolicy's known-gap list (supportive kinds are not listed there, like Heal).
- [x] M3 DrainResource / RestoreResource (players only)
  - Accept: `MagicSpecialResourceSpec.transfer` (Mana or a special resource, clamped to capacity/available); payloads (Drain Bane, Restore Boon) with `Resource` + `Amount`; MagicService context hook moves it between player pools (NPC targets ignored); PvP cap `MaxResourceDrainPerHit`; registered + editors.
  - Verify: `run_luau_unit_tests.py $LUAU special_resource`; parity test; magic suite; stat caps unit test
  - Result: special_resource 1/1, stat_caps 1/1, parity 50/50, magic suite exit 0, StyLua clean. Pure `Spec.drain`/`Spec.restore` in `MagicSpecialResourceSpec`; payloads with `Resource` (Mana + configured special resources, read from `MagicLocus` in the schema) and `Amount` (≤ `MaxResourceTransfer = 50`, provisional); `ctx.TransferResource` in MagicService (players only, self-drain ignored, HUD/special attributes synced); PvP `MaxResourceDrainPerHit` 15 open / 10 ranked (provisional). Test harness maps `MagicLocus` for the schema. RestoreResource joins CombatPolicy's known-gap list (supportive).
- [x] M4 Ratio heals and overflow
  - Accept: pure `MagicHealSpec` (`Flat | PercentMaxHealth | PercentDamageDealt`, overflow); `Mode` on Heal and Shield, `Overflow = "Shield"` on Heal; OnDamageDealt context carries the damage amount; `PercentDamageDealt` validates only on OnDamageDealt; clamp order from Phase 5 kept (amount → ScaleBy → mode → potency → … → caps).
  - Verify: `run_luau_unit_tests.py $LUAU heal`; magic suite; emergent audit (lifesteal scenario)
  - Result: heal 1/1, magic suite exit 0, emergent audit 182/0 failed (lifesteal, PercentDamageDealt/Caster validation, overflow shield), parity 50/50, StyLua clean. OnDamageDealt is emitted with `{ DamageDealt = amount }` → `context.DamageDealt`. Decision: OnDamageDealt targets the damaged creature, so lifesteal needed a new `TargetFrom = "Caster"` (OnDamageDealt only; `Schema.TargetFromByEvent`), shown as "Applies to" in Forge and Lab. Mode applies only to Heal/Shield (Force also has a `Mode` field). Overflow shield = the requested amount, after the per-hit heal cap, minus what was restored; capped by PvP `MaxShield`; lasts `HealOverflowShieldDuration = 5` (provisional).
- [x] M5 Integration and handoff
  - Accept: full gate 40/40 (or known-baseline failures only); this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh` in the worktree; Studio items listed as pending.
  - Result: `bash scripts/check.sh` 40/40 PASS (includes rojo build to a temp path and StyLua). Not committed or pushed. Pending Studio Play (source checks only so far): an NPC switching to a taunting caster and back when the taunt expires; a feared NPC disengaging and idling; monsters losing a stealthed player, and stealth breaking on damage or Reveal; the Mana/special-resource HUD after Drain/Restore; a lifesteal heal and overflow shield landing in a live fight; the Forge/Lab "Applies to" control for OnDamageDealt.

## Open questions / blockers
- Fear: plain disengage (drop target, stand idle) as the brief says, or also back away from the source? Plan: disengage only.
- Taunt/Fear PvP: NPC-only, so no PvP caps; they are listed in `SpellStatCaps.UncappedKinds` with that reason.
- RestoreResource source: plan adds to the target (paid by the spell's cost), not taken from the caster's pool.
- Heal overflow shield duration: plan uses a provisional `MagicLab.HealOverflowShieldDuration = 5`.
- Stealth on players: with the flag off, players still see stealthed players normally; only monsters lose them.
