# Phase 11f — Environment reactions (Wet conducts Lightning, Fire burns Flammable parts, Ice freezes water)

Status: done (2026-10-30), uncommitted
Request: Phase 11f of the spell-creator plan:
- Lightning damage on a Wet character chains to other Wet characters (8 studs, 50% of the hit, up to 3 jumps).
- Fire on a `Flammable`-tagged part spawns a small burning Field.
- Ice on water (a `Water`-tagged part or Terrain water) spawns a breakable ice platform Construct.
- Per-caster limits, the cascade budget and depth, a spell-level `IgnoreEnvironment` off switch.
- PvP caps, Forge/Lab/preview, parity, emergent audit.

Scope: branch `phase11f/environment` (worktree `C:/Users/bello/Documents/Projects/Enfleshed-phase11f`, from `phase11e/blood-magic`).
- In scope: a pure `MagicEnvironmentSpec`; a Roblox-free `MagicEnvironmentReactions` server module; MagicService (the `Damage.Applied` listener for the chain, the `emit` OnImpact hook for fire and ice, Wet/water/flammable reads, spawning through the existing SpawnEffect path, per-caster limits); SpellSpec (`IgnoreEnvironment`); MagicLab config; `SpellStatCaps`; Forge/Lab/preview; tests.
- Out of scope: Studio and map tagging, the main checkout, CURRENT_STATE.md, VFX, existing balance numbers, fire spreading, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- Phase 7 already has a **Conduct** reaction (`MagicLab.ElementalInteractions`): when a Lightning *mark* lands on a Water-marked target, it deals a flat 8 damage once to every Water-marked target within 10 studs (`Chain` effect in `MagicPayloadExecutors.applyReaction`). It is mark-driven and single-hop; the new chain is damage-driven and multi-hop (see open question 1).
- `MagicEnvironmentZoneSpec` only encodes and matches zone tags; `MagicMaterialSpec` is about Matter material sources. Neither knows water or flammability, so this phase reads CollectionService tags plus Terrain material directly (through deps).
- Spell hits reach `Damage.Applied` (MagicService ~1593) with the damage context: `Depth`, `OperationBudget`, `Element`, `Redirected`.
  - Redirected/shared damage (`Redirected = true`, `Depth + 1`, same budget) already skips interception and soul links. Chained hits reuse that marking.
- Every impact goes through `emit(definition, "OnImpact", …, eventState)`, with `eventState.HitPart` set by the projectile, beam and wave sweeps (about 8 call sites, one choke point).
- `MagicWorldQuery.sweep` does not ignore water, so Terrain water is hit as `Terrain`; the material is read with a short ray at the hit point.
- `ctx.SpawnReactionField` (Firestorm / Toxic smoke) already spawns a Field through `spawnEffect`. Constructs are a SpawnEffect form, and Construct health is Phase 10 (`Construct.Health`).
- `Status.hasElementalMark(humanoid, "Water")` is the Wet mark.

## Design (proposed)
- **Pure rules (`MagicEnvironmentSpec`).**
  - `isWet{ Marked, Swimming, InWater }`.
  - `chain(origin, candidates, opts)`: picks hops greedily. Each hop goes to the nearest Wet, allowed, not-yet-hit character within 8 studs of the *last* struck character, up to 3 hops, each for 50% of the original hit (not compounding). PvP caps limit how many hops may land on players and the fraction they take.
  - `igniteAllowed(lastAt, now, cooldown)` gives a 3 s per-part cooldown.
  - `admit(list, record, cap)` is a per-caster FIFO: it returns the oldest record to remove when a 7th fire or 5th platform starts.
  - `reactionFor(element, surface)`: Fire + Flammable gives "Burn"; Ice + Water gives "Freeze"; anything else nothing.
- **Runtime (Roblox-free `MagicEnvironmentReactions`, driven by deps from MagicService).**
  - `onDamage(hit, deps)`:
    - Applies only when the hit came from a spell (Depth set), its Element is Lightning, it is not Redirected/Chained, the spell does not ignore the environment, and the target is Wet.
    - Resolves candidates with `FindHumanoidsNear` + `CombatPolicy.canDamage` (allies and players outside PvP excluded).
    - Deals each hop as `Damage.apply(caster, other, amount, { Redirected = true, Chained = true, Depth = depth + 1, OperationBudget, Element = "Lightning" })`.
    - Spends 1 + hops from the cascade budget and skips at `MaxMagicEventDepth`.
  - `onImpact(impact, deps)`, on `emit` OnImpact with a HitPart, when the spell's Element is Fire or Ice and it does not ignore the environment:
    - **Fire on a `Flammable` part** (or a material in the empty `FlammableMaterials` list), at most once per part every 3 s: spawns a Field at the hit point with radius 4, 5 s, Fire element and `IgnoreEnvironment`. Each tick applies a Fire ElementalMark (1 stack) and a light burn (DamageOverTime 2/s for 2 s). Existing DoT PvP caps apply. It is owned by the caster, with the spell's relationship rules.
    - **Ice on water** (a `Water`-tagged part, or Terrain whose material at the hit is Water): spawns a Construct box 6 × 1 × 6 studs on the surface, lasting 8 s, with `Construct.Health = 50`, so it is walkable and breakable.
    - Limits: 6 fires and 4 platforms per caster. Starting one more ends the oldest (RemainingLifetime = 0).
    - Each reaction spends from the cascade budget and spawns at depth + 1, skipped at the max depth.
  - Wet in MagicService:
    - the Water mark;
    - `Humanoid:GetState() == Swimming`;
    - `FloorMaterial == Water`;
    - a short downward ray from the root hitting a `Water`-tagged part or Terrain water.
- **Turning it off.** A spell-level `IgnoreEnvironment = true` (optional boolean) turns off all three for that spell: its hits never chain, and its impacts never ignite or freeze. It is carried on the damage context so a chain checks the *attacking* spell. Spawned fires and platforms set it on themselves.
- **No loops.**
  - Chained hits are Redirected/Chained, so they never chain again.
  - Chained hits land on characters, not parts, so they cannot ignite.
  - Spawned Fields and Constructs ignore the environment.
  - Everything spends the root cast's budget.
- **Tags to place in Studio (for you):**
  - `Flammable` (CollectionService) on any BasePart that should catch fire.
  - `Water` on BaseParts that act as water. Terrain water needs no tag.
- **Config (MagicLab, provisional):** `WetChainRadius = 8`, `WetChainFraction = 0.5`, `WetChainJumps = 3`, `EnvironmentFireRadius = 4`, `EnvironmentFireDuration = 5`, `IgniteCooldown = 3`, `MaxEnvironmentFires = 6`, `IcePlatformSize = 6`, `IcePlatformDuration = 8`, `IcePlatformHealth = 50`, `MaxIcePlatforms = 4`, `FlammableMaterials = {}`.
- **PvP caps (provisional, SpellStatCaps):** `MaxWetChainPlayerJumps` 2 / 1, `MaxWetChainFraction` 0.4 / 0.3. Environment fire burns use the existing DoT caps.
- **Editors.**
  - Forge: an "Ignore the world" toggle (spell-wide, root Form panel) and preview lines, e.g. "Chains through wet targets" (Lightning), "Sets Flammable things alight" (Fire), "Freezes water into platforms" (Ice). When the toggle is on, the line reads "Ignores the world".
  - Lab: the same toggle in Casting.

## Milestones
- [x] M1 Rules (pure)
  - Accept: `MagicEnvironmentSpec` (isWet, chain with hop rules and PvP caps, ignite cooldown, FIFO admit, reactionFor); unit tests.
  - Verify: `run_luau_unit_tests.py $LUAU environment`
  - Result: environment_spec 1/1, StyLua clean. `MagicEnvironmentSpec`: `isWet`, `chain` (greedy nearest hop from the last struck, Fraction of the original hit, per-candidate PvP MaxJumps/MaxFraction), `reactionFor`, `igniteAllowed`, `admit`/`forget` FIFO limits.
- [x] M2 Schema, config, validation
  - Accept: `IgnoreEnvironment` validated (boolean) and kept; MagicLab config; SpellStatCaps entries; the Conduct change (open question 1); lab tests; parity unchanged.
  - Verify: magic suite; parity
  - Result: magic suite exit 0, parity 60/60, audit 256/0, elemental interaction tests 2/2, StyLua clean. `IgnoreEnvironment` (boolean) on spells and spawn effects; spawned children inherit it. MagicLab environment config (provisional, `FlammableMaterials = {}`), SpellStatCaps `MaxWetChainPlayerJumps` 2/1 and `MaxWetChainFraction` 0.4/0.3. Conduct keeps its name and 1-stack consume with no effects; the audit's old Conduct damage checks now assert a Lightning mark alone deals no chain damage.
- [x] M3 Runtime and audit
  - Accept: `MagicEnvironmentReactions` wired (Applied chain, emit OnImpact fire/ice, Wet/water/flammable reads, spawns, per-caster limits, budget/depth). Audit scenarios:
    - the chain hits 2 Wet targets at 50%, skips a dry one, and hits nobody twice;
    - no hop onto an ally or onto a player outside PvP;
    - one fire per part within 3 s;
    - the 7th fire ends the oldest;
    - the ice platform breaks at 0 health and melts after 8 s;
    - IgnoreEnvironment turns all three off;
    - chained lightning on a Flammable part spawns nothing (bounded).
  - Verify: emergent audit; parity (wiring); magic suite
  - Result: audit 271/0 (15 ENVIRON checks via the real executors + `MagicEnvironmentReactions`), parity 61/61 (environment wiring test), magic suite exit 0, rojo build ok, StyLua clean. MagicService was at the 200-local limit, so the world helpers live in one `World` table. `spawnEffect` now returns the Field/Construct record (used for the per-caster limits); spawned platforms register Construct health. Hops reuse `InterceptionSpec.eligible` (no chains from DoT ticks or redirected hits). The audit harness mirrors MagicService: a Damage.Applied chain hook and `ctx.IsWet`, both off outside the ENVIRON block so older totals are unchanged.
- [x] M4 Registration, editors, PvP caps
  - Accept: Forge toggle + preview lines; Lab toggle; stat-cap tests for the chain caps; parity editor wiring.
  - Verify: parity; magic suite incl. `--forge-only`; stat caps test
  - Result: parity 61/61 (editor/preview wiring), magic suite + `--forge-only` exit 0, stat caps 1/1 (chain hops/share in both PvP profiles, none in PvE), environment_spec 1/1, compile ok, StyLua clean. Forge: "THE WORLD" section with "Ignore the world" on the spell; preview line "WORLD · Chains through wet targets" / "Sets Flammable things alight" / "Freezes water into platforms" / "Ignores the world" (pure `EnvironmentSpec.previewLine`). Lab: the toggle in Cost (also hosted by the Forge's Advanced view).
- [x] M5 Integration and handoff
  - Accept: full gate pass; this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh`; Studio items listed as pending.
  - Result: full gate 40/40 on the first run. Not committed. Studio pending: the chain on real characters (standing in Terrain water / on Water-tagged parts, swimming, Water mark), fires on Flammable parts (look, ignite cooldown, oldest out at 7), ice platforms on Terrain water and Water parts (walkable, breakable, melt, oldest out at 5), PvP chain caps with two players, Forge/Lab layout of the new controls.

## Open questions / blockers
1. **Conduct overlap.** A Lightning hit with a Lightning mark on a Water-marked target would run both the old Conduct (flat 8 to all Water-marked within 10) and the new chain. Plan: the new chain replaces Conduct's `Chain` effect. The Conduct reaction stays, with its name (for the "last reaction" condition) and its 1-stack consume, but loses the flat damage. So there is one chain rule, now also triggered by standing in water.
2. **Decided:** Wet is checked *before* the hit's reactions run: the payload group snapshots which of its targets are Wet before any payload or reaction in it resolves, so a Water mark used up by the same hit (Conduct) still counts.
3. Chain hops start from the last struck character, each for 50% of the original hit after mitigation (not 50% of 50%) (plan).
4. "Fire / Ice impact" means an impact of a spell whose Element is Fire / Ice (projectile, beam, wave hit parts). Fields and Auras do not ignite parts (plan).
5. The ice platform appears at the water surface hit point, ignoring the caster's Construct placement rules, and counts toward Construct limits like other spawned Constructs (plan).

## Tags to place in Studio (Daniel)
- `Flammable` (CollectionService tag) on every BasePart that should catch fire, e.g. crates, hay, wooden barricades. Untagged parts never burn (`MagicLab.FlammableMaterials` is empty).
- `Water` (CollectionService tag) on every BasePart that acts as water, e.g. a pond or trough surface, or a water volume a character can stand in. Terrain water needs no tag.
