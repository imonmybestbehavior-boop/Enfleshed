# Phase 11a — Interception (OnBeforeDamageTaken)

Status: done (uncommitted, awaiting review; approved 2026-10-28, point 3 changed: an undeliverable Owner share returns to the holder)
Request: Phase 11a of the spell-creator plan: a new event `OnBeforeDamageTaken` ("Before I take damage") on spells the hit character holds, fired inside `DamageService.apply` before mitigation, whose steps can Negate, Reduce or Redirect the incoming hit; charges, a 0.25 s interval, one interceptor per hit, no recursion; PvP caps; registration, Forge/Lab, parity, emergent audit.
Scope: branch `phase11a/interception` (worktree `C:/Users/bello/Documents/Projects/Enfleshed-phase11a`, moved out of the temp folder; from `phase10/constructs-traps`). `DamageService` (a hook, no new dependency on MagicService), a new server `MagicInterception` module, `MagicService` (holder discovery + wiring), `MagicPayloadExecutors` (DoT ticks marked periodic), schema/SpellSpec/condition spec/cost, `SpellStatCaps`, Forge/Lab, tests. · Out of scope: Studio, the main checkout, CURRENT_STATE.md, VFX, existing balance numbers, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- `DamageService.apply(attacker, target, amount, eventContext, melee)`: guards → outgoing strength → region multiplier → mitigation (`applyChannel` / `applyDamageTaken`) → melee defense → armor → PvP `Caps.damage` → per-hit cap → shields → `TakeDamage` → `Applied`. Callers: spell Damage executor and DoT ticks (`MagicPayloadExecutors`), `CombatService.applyMelee`, `EnemyService` (Enfleshed/monsters, `applyMelee`), `SummonService`, `DefendTheWallsGuards`.
- DamageService cannot require MagicService (MagicService requires it), so interception is a hook set at start.
- Held spells today (MagicService `Damage.Applied` listener ≈ 1269): active records with `spell.Caster == targetModel` (Auras etc.) and `enhancements[player][id]` with `effect.State.Character == targetModel` (Enchantments, including ones on allies). Attached Constructs: `record.AttachedHumanoid`.
- OnDamageTaken already supports `TargetFrom = "Attacker"` (Phase 3) and `Schema.TargetFromByEvent`.

## Design (proposed)
- **Authoring.**
  - Event `OnBeforeDamageTaken` on Aura, SelfEnhancement (Enchantment) and Construct. A Construct only intercepts while attached to a character.
  - Steps may carry `Intercept = { Action = "Negate" | "Reduce" | "Redirect", Percent, To }`:
    - Reduce: `Percent` 1–90.
    - Redirect: `Percent` 10–100, `To` = `Owner` (the spell's caster) or `Attacker`.
    - Normal Payloads/Behavior work alongside, with `TargetFrom` Holder / Attacker / Caster.
  - Spell field `Interception = { Charges = 1–5, EndWhenSpent = false }`, required when the spell has OnBeforeDamageTaken steps.
  - New step-condition family **Hit**, only on OnBeforeDamageTaken: `Damage` (incoming, before mitigation), `Element`, `AttackerIsPlayer`, `IsMelee`.
- **Runtime.**
  - `DamageService` gains `Damage.setInterceptor(fn)`. `apply` calls it after outgoing strength and before region/mitigation, unless the hit is a DoT tick (`eventContext.Periodic`, set in the DoT executor) or redirected (`eventContext.Redirected`). The interceptor returns the amount that still lands on the target.
  - New `MagicInterception` (server, loadable in the audit harness with doubles) gets the candidate records from MagicService.
  - **Who intercepts:** candidates are sorted oldest-applied first. The first one with charges left, ≥ 0.25 s since its last interception, and at least one step whose conditions pass is the single interceptor for that hit. It runs its passing steps (normal steps fire like OnDamageTaken), applies the first passing Intercept action, and uses one charge. At 0 charges with `EndWhenSpent` the spell ends; otherwise it stays but no longer intercepts.
  - **Redirect:** the redirected share is dealt via `Damage.apply` to the Owner or Attacker with `{ Redirected = true, Depth = hit depth + 1, OperationBudget = shared }`. It goes through the recipient's own mitigation and caps, is never intercepted, and keeps the cascade depth so reactions on it (thorns) stop at `MaxMagicEventDepth`.
- **PvP caps (provisional, `SpellStatCaps`, chosen by the attacker↔holder profile):** `MaxInterceptReducePercent` 50 open / 35 ranked; `MaxInterceptNegateChargesVsPlayer` 1 / 1 (per spell, counting negates of player hits); `MaxInterceptRedirectToAttackerPercent` 50 / 30.
- **Cost:** in the estimate, Negate costs most per charge, then Redirect, then Reduce (scaled by Percent), times Charges.
- **Limits (MagicLab, provisional):** `MaxInterceptionCharges = 5`, `MinInterceptionInterval = 0.25`.

## Milestones
- [x] M1 Interception rules (pure)
  - Accept: `MagicInterceptionSpec` — eligibility (not Periodic, not Redirected), candidate ordering (oldest first), charge/interval gate, apply action with PvP caps (Negate / Reduce % / Redirect share and recipient), negate-vs-player charge cap, charge use + spent; unit test.
  - Verify: `run_luau_unit_tests.py $LUAU interception`
  - Result: interception 1/1, StyLua clean. `MagicInterceptionSpec`: `eligible` (not Periodic/Redirected), `order` (oldest `AppliedAt`, stable), `newState`/`ready`/`use` (charges, interval, player-negate count), `resolve` (Negate/Reduce/Redirect with the three PvP caps; a capped-out Negate reports `Applied = false`; no action = hit unchanged), `costWeight` (Negate 6 > Redirect 1–4 > Reduce 0–3.6 per charge).
- [x] M2 Schema, validation, conditions, cost
  - Accept: event (label, help, order, Forms, payload/behavior timings), `Intercept` step field, `Interception` spell field, Hit condition family limited to the event, `TargetFromByEvent.OnBeforeDamageTaken`, estimate pricing; lab validation tests.
  - Verify: magic suite; parity
  - Result: magic suite exit 0, parity 54/54, audit unchanged. Event on Aura/SelfEnhancement/Construct (`Schema.InterceptionForms`), in reactive payload timings and Explode/SpawnEffect; `TargetFromByEvent.OnBeforeDamageTaken` = Holder/Attacker/Caster; `Intercept` validated per action (Negate has no Percent/To; Reduce 1–90; Redirect 10–100 to Owner/Attacker) and lets a step omit payloads; `Interception` required with the event (Charges 1–5 integer, optional EndWhenSpent) and rejected without it; Hit family (Damage, Element, AttackerIsPlayer, IsMelee) only via `ConditionSpec.validateStep(conditions, allowHit)`. Cost: `costWeight` × Charges added to controlWeight (weights scaled up so Negate > Redirect > Reduce survives rounding). SpellSpec now requires MagicInterceptionSpec; the shared lab preamble maps it. The lab test block sits in `do … end` (the enclosing function hit Luau's 200-local limit).
- [x] M3 Runtime and audit
  - Accept: `Damage.setInterceptor` hook before mitigation; DoT ticks marked `Periodic`; `MagicInterception.resolve` (candidates from MagicService: Auras on the holder, Enchantments on the holder, attached Constructs) runs passing steps, applies the action, redirects with `Redirected` + depth; spell end on spent charges; audit scenarios Parry, Absorb (50% × 3 charges), Guardian (Enchantment on ally → 50% to caster), and two guardians redirecting to each other (no loop).
  - Verify: emergent audit; parity (wiring); magic suite
  - Result: audit 212/0 failed (10 INTERCEPT checks: parry negate + counter-mark + end-when-spent, next hit lands; absorb 50% × 3 with one hit inside 0.25 s passing; DoT untouched; guardian 50% to the caster; Hit.Damage condition; two guardians do not loop; oldest wins), parity 55/55 (`test_interception_runs_before_mitigation_without_recursion`), magic suite exit 0, rojo build ok, modules compile. `DamageService.setInterceptor` (hook after outgoing strength, before region/mitigation/defense; returns 0 → no hit). New `MagicInterception.resolve` (Roblox-free, driven by the audit with doubles); MagicService supplies candidates (Auras following the holder, attached Constructs, Enchantments on the holder; `StartedAt` = applied time), redirects via `Damage.apply` with `Redirected`, depth + 1 and the shared budget; candidate lookup stops at `MaxMagicEventDepth`. Dispatch reports matches/first Intercept through `context.InterceptHooks`; Hit conditions read `context.IncomingHit`. A PvP-capped Negate uses no charge and leaves the hit unchanged. SpellSpec: an Intercept action counts as the spell's effect for the "1–8 payloads" rule (an Absorb has no payloads).
- [x] M4 Registration, editors, PvP caps
  - Accept: Forge ("Before I take damage", intercept action/percent/target, charges, end-when-spent), Lab (same), PvP caps in both profiles applied in M1 rules + stat caps test, parity consumers.
  - Verify: parity; magic suite incl. `--forge-only`; stat caps test
  - Result: parity 55/55, magic suite + `--forge-only` exit 0, stat_caps 1/1, StyLua clean, editors compile. PvP caps in both profiles (Reduce 50/35, Negate vs players 1/1 per spell, Redirect to attacker 50/30), applied through `Spec.resolve` with the attacker↔holder profile. Forge: "Before I take damage" phrase; the trigger inspector gains THE HIT (action chips, percent, send-to, charges, ends-when-spent) and `pruneStep` keeps Intercept-only steps; removing the trigger clears charges. Lab: Interception select, percent, send-to, charges, toggle. `Spec.normalize` adds `{ Charges = 1 }` when the event has steps and drops charges without it. Schema exposes `MaxInterceptionCharges` for the Forge.
- [x] M5 Integration and handoff
  - Accept: full gate pass; this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh` in the worktree; Studio items listed as pending.
  - Result: `bash scripts/check.sh` 40/40 PASS (81/81 unit tests). After the gate only `tests/test_magic_lab.lua` gained the normalization asserts; the magic suite and StyLua were rerun on it. Not committed or pushed. Pending Studio Play (source checks only): parry/absorb/guardian against real spell, melee and Enfleshed/monster hits; the guardian redirect landing on the caster in multiplayer; PvP caps in open and ranked zones; Forge/Lab controls for the new event.

## Open questions / blockers
- Hook position: after the attacker's strength bonus, before hit-region multiplier and every mitigation (plan). OK?
- Normal-only steps: a spell whose OnBeforeDamageTaken steps have no Intercept action still counts as the interceptor and uses a charge when a step passes (plan), so "one interceptor per hit" holds.
- Redirect to Owner when that attacker cannot damage the owner: the share goes back to the holder (decided 2026-10-28).
- Attached Construct: the attached character is the holder (plan).
- Negate cap vs players counts per spell lifetime (plan), not per minute.
