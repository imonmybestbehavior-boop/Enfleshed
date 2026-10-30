# Phase 11e — Blood magic (health as a spell cost)

Status: done (2026-10-29), uncommitted
Request: Phase 11e of the spell-creator plan: a health cost (`Cost.Health` Flat / PercentMax), health paying for up to 100% of a spell's mana at 1 HP = 0.5 mana, `Cost.HealthPerSecond` for channels and toggles, a 10% health floor (blood magic never kills), paying health is not damage, a `HealthPaid` scale-by source, a "caster health below" condition, players only; PvP caps, Forge/Lab/HUD, parity, emergent audit.
Scope: branch `phase11e/blood-magic` (worktree `C:/Users/bello/Documents/Projects/Enfleshed-phase11e`, from `phase11d/spell-vs-spell`). SpellSpec (cost validation, estimate), a pure `MagicBloodCostSpec`, a Roblox-free `MagicBloodMagic` server module, MagicService (cast payment, upkeep loops, ScaleRead), `MagicScaleSpec` (new source), `MagicLabCost` / `SpellProgressionRules` (keep the health keys on reprice), `MagicCompanionSpellPolicy`, `SpellStatCaps`, Forge/Lab/HUD, tests. · Out of scope: Studio, the main checkout, CURRENT_STATE.md, VFX, existing balance numbers, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- Cost keys today: `ManaDemand`, `Strain`, `Complexity`, `SpecialResources` (validated at SpellSpec ~1325). Stored `Cost` is rebuilt from `Spec.estimate` on save (`MagicLabCost.refresh` in Studio, `SpellProgressionRules.reprice` live). Both rebuild the table, so new keys must be carried over explicitly.
- Cast payment: `costs()` → `LocusModel.cost(Cost, charge, ChargeCostScale, stats)` (mana × (1 + charge × scale) / Efficiency). The pre-check is `LocusModel.evaluate` in the cast check (~774), and the spend is `LocusModel.spend` after placement/special resources (~3227). Special resources show the "check, then pay, refund on later failure" pattern to copy.
- Recast (`recastActive`, OnRecast) never calls `costs()`, so recasts stay free with no change.
- Upkeep: `Casting.ManaUpkeepPerSecond` / `StrainPerSecond` paid per tick in two loops (active records ~5278, enhancements ~6109), ending the spell with an EXPIRED feedback reason.
- ScaleBy is additive: `Amount + min(PerUnit × units, Max)`, sources in `MagicScaleSpec.Sources`, read in MagicService `ctx.ScaleRead`. The estimate prices ScaleBy at its full `Max`.
- A caster-health condition already exists: `Caster.HealthPercent` (0..1, numeric operators). No new condition is needed (see Design).
- Server damage hooks (OnDamageTaken, OnBeforeDamageTaken/Interception, soul links, Shields, DamageTaken stat, Stealth/Polymorph breaks) all run inside the damage pipeline. No server code listens to a player's `Humanoid.HealthChanged`.

## Design (proposed)
- **Cost data** (all optional; absent means no blood magic):
  - `Cost.Health = { Mode = "Flat" | "PercentMax", Amount }`: a sacrifice on top of the mana cost. Flat is 1–100 HP; PercentMax is 1–40 (% of max health at cast).
  - `Cost.HealthForMana = 0–100`: the percentage of the spell's mana paid in health instead, at 2 HP per mana replaced.
  - `Cost.HealthPerSecond = 0.5–10`: only for Channeled / held / toggled (UntilToggledOff) spells.
  - Saved Cost keeps these keys through both reprice paths.
- **Estimate.**
  - `Spec.estimate` keeps `ManaValue` (the full mana price, unchanged).
  - `ManaDemand` becomes `ceil(ManaValue × (1 − share))`, and the new field `HealthFromMana = 2 × (ManaValue − ManaDemand)`.
  - The sacrifice is reported as `HealthCost = { Mode, Amount }`; PercentMax can only be shown as "%".
  - Strain and Complexity still come from the full value.
  - Rank limits (`SpellProgressionRules.canUse`) and the locus safety thresholds read `ManaValue`, so blood magic cannot slip past rank mana limits.
- **Payment (pure `MagicBloodCostSpec`).**
  - `amount(cost, estimate, maxHealth, chargeMultiplier, pvpCap)`: (sacrifice + replacement) × the same charge multiplier as mana. Efficiency does not apply. The PvP percent cap clamps the PercentMax sacrifice.
  - `canPay(health, maxHealth, amount, floor=0.1)` refuses if `health − amount < 10% of max`.
  - `tickEnds(health, maxHealth, perSecond, dt)` says when the next upkeep tick would cross the floor.
- **Runtime (Roblox-free `MagicBloodMagic` + MagicService).**
  - The cast check refuses with "Not enough health · blood magic stops at 10%" and pays nothing.
  - The health is paid right after mana and special resources, before any effect runs, by setting `Humanoid.Health` directly. It never calls DamageService or `ctx.Damage`, so none of the damage hooks run. Mitigation does not apply, and it is not counted as healing or lifesteal.
  - The amount paid is stored on the cast's definition copy (`_HealthPaid`, like `_ChargeFraction`), so every event it causes can scale with it.
  - Upkeep: both loops also pay `HealthPerSecond × step` and end the spell *before* a tick that would cross the floor ("Blood upkeep ended · health floor").
- **Scaling.**
  - A new `MagicScaleSpec` source `HealthPaid` ("Health paid (HP)"), with units = HP paid at cast and `ctx.ScaleRead` returning `_HealthPaid`.
  - Because ScaleBy is additive, "× (1 + HP/100)" is authored as `PerUnit = Amount / 100`. Example: Damage 50, PerUnit 0.5, Max 50 → paying 40 HP gives 70 = ×1.4. A Forge preset fills that in.
  - In the existing order the bonus is clamped by `MaxScaleBonus`, and against players additionally to 50% (open) / 35% (ranked) of the authored amount (`SpellStatCaps`).
- **Condition.** Reuse `Caster.HealthPercent < x` and add a Forge/Lab preset labelled "Caster health below (%)". No new condition family.
- **Players only.**
  - `MagicCompanionSpellPolicy` rejects definitions with any health cost, so companions cannot be given them.
  - The cast path refuses a health cost when the caster is not a player (NPC/command casts).
- **PvP caps (provisional, `SpellStatCaps`):** `MaxHealthCostPercent` 40 open / 30 ranked (clamps the PercentMax sacrifice against players), `MaxHealthPaidBonus` 0.5 / 0.35 (bonus fraction of the authored amount).
- **MagicLab (provisional):** `BloodHealthFloor = 0.1`, `HealthPerMana = 2`, `MaxFlatHealthCost = 100`, `MaxPercentHealthCost = 40`, `MinHealthPerSecond = 0.5`, `MaxHealthPerSecond = 10`.
- **Editors / HUD.**
  - Forge: a "Pay with health" control in the cost panel (sacrifice mode + amount, the "health for mana" %, HP/s for held spells). The cost line shows both, e.g. "20 mana + 30 HP" (PercentMax as "+ 15% HP"). HealthPaid appears in the scale-by source list.
  - Lab: the same fields in its cost section.
  - HUD spell slot: shows the HP cost beside mana, and the refusal reason appears through the existing IMPOSSIBLE feedback.

## Milestones
- [x] M1 Rules (pure)
  - Accept: `MagicBloodCostSpec` (amount with charge, PercentMax, PvP percent cap; floor check; upkeep floor; mana replacement split with the 2:1 rate); `HealthPaid` scale source; unit tests (fully blood-powered = 0 mana and 2× HP; floor refusal; charge scaling).
  - Verify: `run_luau_unit_tests.py $LUAU blood scale`
  - Result: blood 1/1, scale_spec 1/1, StyLua clean. `MagicBloodCostSpec` (`uses`, `split` with mana rounded up, `sacrifice` with PvP percent cap, `amount` x charge, `canPay` floor inclusive, `tick`, `capPaidBonus`, `validate`); `HealthPaid` scale source (units = HP paid); MagicLab blood constants (provisional).
- [x] M2 Schema, validation, estimate, reprice
  - Accept: Cost keys validated (ranges; HealthPerSecond only on held/toggled spells); estimate fields `ManaValue` / `HealthFromMana` / `HealthCost`; both reprice paths keep the keys; rank limits and locus safety use `ManaValue`; companion policy rejects health costs; lab tests.
  - Verify: magic suite; progression/lab-cost unit tests; parity
  - Result: magic suite exit 0 (incl. `--forge-only`), companion policy 1/1, parity 58/58, audit unchanged 250/0, StyLua clean. Change from the plan: stored `Cost.ManaDemand` stays the *full* price and the estimate adds `ManaPaid` / `HealthFromMana` / `HealthCost` / `HealthPerSecond`, so rank limits, Locus safety and library sorting need no change; the runtime pays `ManaPaid`. Held spells still need positive mana upkeep; `HealthPerSecond` is extra. Both reprice paths carry Health/HealthForMana/HealthPerSecond.
- [x] M3 Runtime and audit
  - Accept: cast check + payment (after validation, before effects), refusal pays nothing, non-player casters refused, `_HealthPaid` + ScaleRead, upkeep in both loops ending at the floor; audit scenarios (flat 30 HP exact; floor refusal pays nothing; no soul link / Interception from paying; 40 HP → ×1.4 damage; HP/s channel ends at the floor; full blood = 0 mana, 2× HP).
  - Verify: emergent audit; parity (wiring); magic suite
  - Result: audit 257/0 (7 BLOOD checks), parity 59/59 (new blood wiring test), magic suite exit 0, rojo build ok, StyLua clean. `MagicBloodMagic` (quote/canPay/pay/upkeep, Roblox-free) wired into MagicService: `costs()` pays `ManaPaid`, the cast check and execute refuse at the floor before anything is paid, health is set directly after special resources and before effects, `_HealthPaid` on the cast copy feeds ScaleRead, upkeep in both loops. Companion/command casts (`castContext`) are refused. The Locus "unsafe" threshold sees the mana actually drawn (Strain still from the full price). PvP HealthPaid cap in `scaledAmount` via `context.CapProfile`.
- [x] M4 Registration, editors, HUD, PvP caps
  - Accept: Forge "Pay with health" + dual cost line + HealthPaid scale-by + "Caster health below" preset; Lab equivalents; HUD slot HP cost; PvP caps in both profiles + stat-cap tests; parity consumers.
  - Verify: parity; magic suite incl. `--forge-only`; ui suite; stat caps test
  - Result: parity 59/59 (editor/HUD wiring asserted), magic suite + `--forge-only` + `--action-flow-only` exit 0, ui suite pass, stat caps 1/1, blood 1/1, compile ok, StyLua clean. Shared `BloodCostSpec.costLabel` ("20 mana + 30 HP") and `paidScalePreset` (PerUnit = Amount/100); `ActionFlow.casterHealthBelow`. Forge: HEALTH header stat, Guided "PAY WITH HEALTH" on the spell, "Grows with health paid" on scalable effects of blood spells. Lab: PAY WITH HEALTH in Cost (also hosted by the Forge's Advanced view), HealthPaid preset in Scale by, "+ IF HURT" branch. HUD slot shows mana paid plus the HP part in red. The Forge harness now maps `Shared.Configuration.MagicLab`.
- [x] M5 Integration and handoff
  - Accept: full gate pass; this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh`; Studio items listed as pending.
  - Result: full gate 40/40. First run failed `test_vfx_asset_audit.py` only because this worktree's untouched `assets/` files had been normalised to LF (their recorded hashes are of CRLF checkouts); restoring the default checkout of `assets/` fixed it. Not committed. Studio pending: paying health on real casts (floor refusal message, charged costs, HP/s channels and toggles ending at the floor), no damage reactions from paying (parry, soul link, Stealth/Polymorph), HealthPaid scaling vs players, Forge/Lab/HUD layout of the new controls.

## Open questions / blockers
1. ScaleBy is additive in this codebase, so "× (1 + HP/100)" becomes a preset (`PerUnit = Amount/100`) rather than a new multiplicative mode (plan). The PvP cap is on the bonus as a fraction of the authored amount.
2. "CasterHealthBelow" already exists as `Caster.HealthPercent <`; I add a preset label instead of a duplicate condition (plan).
3. The health sacrifice and mana replacement both scale with charge; Locus Efficiency only reduces mana, not health (plan).
4. `HealthPaid` counts the health paid at cast (sacrifice + replacement), not upkeep (plan).
5. Rank limits use the full mana value, so replacing mana with health can't unlock a spell early (plan).

## Follow-up fix (requested 2026-10-29)
- `MagicService.execute` called `CompanionSpellPolicy.requiresCommandSlot(d)` with `d` undefined there (a nil global since the first upload), so a companion CommandCast would error. Now `requiresCommandSlot(definition)`; parity test `test_companion_command_cast_slot_uses_the_cast_definition` guards it. Parity 60/60, audit 257/0, magic suite, build and StyLua pass after the fix.
