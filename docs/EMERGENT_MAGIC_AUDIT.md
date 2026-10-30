# Enfleshed — Emergent Magic Audit

Date: 2026-10-14 · Scope: `src/shared` + `src/server` magic runtime, Magic Lab editor, validation.

**Evidence types used in this report**

| Tag | Meaning |
|---|---|
| **[SRC]** | Source inspection only |
| **[LOCAL]** | Executed locally in `tests/emergent_magic_audit_spec.luau` (Luau 0.742 CLI) against real production modules |
| **[DOUBLE]** | Executed locally, but routed through a test double of `MagicService.emit/context` (the production function needs Roblox) |
| **[STUDIO]** | Not executed; needs Roblox Studio |

No Roblox Studio run was performed. Nothing in this report claims a Studio test passed.

Run the suite:

```
python3 scripts/run_emergent_magic_audit.py ~/.rokit/bin/luau
```

Result: **101 checks, 0 failed** (96 capability checks, 5 limitation checks). The original audit run had 49 checks; the later fixes listed in the Update block below added checks and turned several limitations into capabilities. The limitation checks assert *current* behaviour, so they act as a regression baseline: when the engine gains one of these capabilities, its check will fail and must be updated.

What the harness loads unchanged: `SpellSpec`, `MagicSchema`, `MagicLab` limits, `ProjectileBehaviorSpec`, `MagicTriggerDispatch`, `MagicBehaviorExecutors`, `MagicPayloadExecutors`, `MagicProjectileBehaviorExecutors`, `MagicTargetDeathSpec`, `MagicAreaMembership`.

What it mocks: `DamageService` (applies health loss and mirrors the `Damage.Applied` listener at `MagicService.luau:1084-1106`), physics ownership, movement, status and control services, `workspace`, `Vector3` and `CFrame`.

No production gameplay code was modified during the audit itself.

> **Update (2026-10-14): per-cast operation budget implemented.** See risk F and plan step 1.
> - New module `src/shared/Modules/MagicOperationBudget.luau`, and a new limit `MaxOperationsPerCascade = 256` in `MagicLab`.
> - Wired into `MagicService`: `spendOperations` is called in `emit` and in `ApplySpherePayloads`, and `DamageContext.EmitEvent` passes the budget on to the next reaction.
> - Every dispatched event or area query costs 1 plus its target count. A root event (depth 0) starts a fresh budget, and nested reactions share their parent's budget.
> - When the budget runs out, the rest of the chain stops and the caster gets one `IMPOSSIBLE` feedback message.
> - **Also (2026-10-14): Explode now carries non-damage payloads.** `MagicSchema` Explode `PayloadKinds` now lists all 16 per-target kinds, and `DefaultPayloadKinds = {Damage}`. The Lab editor shows an on/off toggle for each blast payload, limited by Form, Principle, `MaxPayloads` and a minimum of 1.
> - **Also (2026-10-14): per-step conditions.** Any trigger step, including Explode steps, can carry an optional `Condition`. It uses the same whitelisted ALL/ANY/NOT rule language as spell-level conditions.
>   - **Allowed families:** Caster, Target, Relationship, Status, Resource, SpellState and Time. Environment, Material and `Target.HasLineOfSight` are rejected (`MagicConditionSpec.validateStep`).
>   - **When the event has targets:** the step runs only for the targets that pass. If none pass, the step is skipped.
>   - **When the event has no targets:** the condition is checked once without a target.
>   - **Fails closed:** a missing value or a missing condition adapter means the step does not run.
>   - **Code:** the filter is the pure module `MagicStepCondition`; `MagicTriggerDispatch` applies it, using `MagicConditions.stepTargets` as the server resolver.
>   - **Editor:** in Configure Effects, each step on the selected event has a "Step condition" section that reuses the existing condition-tree editor, now factored into `renderConditionTree`.
>   - **Not changed yet:** the three hard-coded event filters (HealthPercent, Command, DeathMode) were not migrated to conditions, and the editor still cannot add more than one plain payload step per event.
> - **Also (2026-10-15): SpawnEffect.** A new trigger-step behaviour that starts a separate Projectile, Field or Wave at the event.
>   - **Format:** the step carries a compact `Effect = { Form, Geometry, <Form settings>, Lifetime, Triggers }`.
>   - **Expansion:** `SpellSpec.expandSpawnEffect` builds a full child definition from a fresh draft of that Form. The child inherits the parent's Principle, Element, visuals and target relationship, and is validated recursively.
>   - **Bounds:** nesting is capped at `MaxSpawnNesting` = 2. Children must have a fixed or instantaneous lifetime and cannot summon. Only Projectiles can spawn more than one (`MaxSpawnCount` = 3, fanned across `SpreadAngle`). The estimate adds the child's cost for each spawn.
>   - **Timings:** offered wherever Explode is, plus area entry, exit and pulse, and Projectile pulse.
>   - **Runtime:** `MagicService.spawnEffect` builds the same active records the cast path builds. It respects `MaxActivePerPlayer`/`MaxActiveGlobal` and spends from the cascade budget.
>   - **Editor:** the Configure Effects view for a SpawnEffect step has a Form picker, that Form's settings, a duration, and a timing selector with effect toggles for the spawned effect.
>   - `safeTree` limits were raised to 700 nodes and depth 18 to fit two nesting levels.
>   - **Extended the same day to Beam, Aura, Construct and SelfEnhancement:**
>     - A spawned Beam fires from the event point along the event direction. Single and Cascade patterns both work.
>     - A spawned Aura follows the event's first target, or the caster if there is none.
>     - A spawned Construct is built upright at the event point, facing along the event direction. It is temporary only.
>     - A spawned SelfEnhancement applies to the caster, using their latest cast's combat state.
>     - Construct model building and SelfEnhancement start-up are now shared with the cast path (`buildConstructModel`, `startSelfEnhancement`).
>   - **Not yet:** Studio verification. Manipulation is excluded by design.
> - **Also (2026-10-15): runtime counters.** Three new SpellState condition values, usable in step, cast and target conditions, and listed automatically by the editor:
>   - `TriggerCount`: how many times this event has fired on this effect, counting this one.
>   - `AreaOccupants`: targets currently inside a Field or Aura.
>   - `EventTargets`: targets this event resolved.
>   - **Cadence:** a new `MultipleOf` comparison on `TriggerCount` (value at least 1) runs a step on every Nth trigger.
>   - **Code:** counts live in the pure module `MagicRuntimeCounters`, recorded by `MagicService.emit` on the effect's persistent record.
>   - **Fixes that came with it:** area transitions now keep the Field or Aura record as `RuntimeOrigin`. Occupancy now updates before `OnEnter`/`OnExit` fire, so entry conditions see the new count. Beam and Propagate impacts now carry their effect's record.
> - Measured in the harness: the 3-target recursive spell dropped from 9,841 damage ops to 127. With 16 targets it ran 209.

---

## A. Overall verdict

**Updated 2026-10-15: Level 4 (branching and nested behaviours) is met in the harness, pending Studio verification. Level 5 is not met.**

With SpawnEffect, per-step conditions and non-damage Explode, Tests C, D and F now pass as originally specified. See the Update block and section D. The rest of this section is the original verdict.

**Original verdict: Level 3, conditional effect chains. Level 4 is partially met; Level 5 is not.**

- **Level 2 is earned.** One spell runs several independent payload operations, plus a generic area behaviour, from one event. Removing one operation leaves the others unchanged (Test A, [LOCAL]/[DOUBLE]).
- **Level 3 is earned.** Effects talk to each other through generic events. For example, `OnImpact` runs Explode, the Explode damage emits `OnDamageDealt`, and that event runs a further payload. Other chains go through `OnThreshold` and `OnTargetDeath`. No spell-specific handler is involved (Tests B, E, G).
- **Level 4 is partial.**
  - Supported: one event can run several steps in parallel (up to 4). Persistent hazards (Field, Linger, Pulse) fire their own events. Split children are independent runtime entities with their own targeting, motion and collision.
  - Missing:
    - Secondary entities cannot have their own definition. Children, linger hazards and explosions all reuse the parent's single `Triggers` table.
    - Nesting is not possible: a child cannot split, and a trigger step cannot spawn a different Form.
    - Trigger steps have no per-step conditions.
    - The only area behaviour is an instant Damage-only sphere.
- **Level 5 is not earned.** A spell is exactly **one Form**, plus a flat `event → steps` map, plus a fixed list of projectile modifiers. You cannot write "projectile → field → wave" as configuration.

## B. Architecture map

```
MagicLabController (client editor, 5.7k lines)
  └─ MagicLabRequest remote ──► MagicLabService (save / apply / cast)
        └─ SpellSpec.normalize → SpellSpec.validate (MagicSchema + MagicLab limits) → SpellSpec.estimate (cost)
MagicController (cast input) ──► ActionRequest ──► MagicService (4.9k lines; one cast path per Form)
  ├─ Form runtimes: Projectile / Beam / Wave / Field / Aura / Construct / SelfEnhancement / Manipulation
  │    projectile tick → MagicProjectileBehaviorExecutors.spawn/update/impact
  │      (Homing, Pierce, Chain, Propagate, Bounce, Split, Spread, Linger, Pulse, Proximity, Absorb, Reflect, Return)
  ├─ emit(definition, event, …)  MagicService.luau:972
  │    └─ context(...)  :757  (targets via MagicConditions, DamageContext.EmitEvent with depth cap, ApplySpherePayloads)
  │         └─ MagicTriggerExecutors → MagicTriggerDispatch.execute  (event filter → Behavior | Payloads)
  │              ├─ MagicBehaviorExecutors   (Explode only)
  │              └─ MagicPayloadExecutors    (20 payload kinds → DamageService, StatusEffect, Control, Summon…)
  ├─ Damage.Applied listener :1084 → re-emits OnDamageDealt / OnThreshold / OnTargetDeath (depth+1)
  ├─ Area membership → OnEnter / OnExit (:1338), proximity → OnProximity, timers → OnTick / OnExpire
  └─ MagicPresentation / SpellVFX remote (VFX decoupled from payloads)
```

**Where it is extensible:**
- Payload kinds (`Schema.Payloads` plus an executor table).
- Projectile behaviours (`ProjectileBehaviorSpec` plus an executor table).
- Trigger behaviours (`Schema.Behaviors` plus `MagicBehaviorExecutors`).
- Events (`Schema.Forms[*].Events`).

**Where it is hard-coded:**
- `MagicService` has one bespoke runtime per Form.
- `MagicTriggerDispatch.lua:9-15` has per-event matching for `OnThreshold`, `OnCommand` and `OnTargetDeath`.
- Allowed event sets are listed per Form and per behaviour.
- `Explode.PayloadKinds = {"Damage"}` (`MagicSchema.luau:1832`).
- `Split` forbids depth above 0 (`MagicProjectileBehaviorExecutors.luau:234`).

**Hidden per-spell hardcoding: none found** [SRC].
- `SpellId ==` comparisons exist only for stacking and ownership bookkeeping, for example `MagicPayloadExecutors.luau:303`, `MagicService.luau:1433`, `:2911`.
- There are no preset-name branches. The existing guard `tests/test_magic_no_spell_identity_branches.py` passes.
- VFX goes through `MagicPresentation`, separate from damage.

## C. Capability matrix

| Capability | Status | Evidence |
|---|---|---|
| Multiple payloads per event | Implemented & tested | A [LOCAL/DOUBLE] |
| Multiple steps per event (≤ `MaxSteps`=4) | Implemented & tested | C [DOUBLE]; cap test |
| Independent configuration per payload | Implemented & tested | A |
| Events emitted by effects (OnDamageDealt/OnThreshold/OnTargetDeath re-emission) | Implemented & tested | B, F, G1 [DOUBLE]; production path [SRC] `MagicService.luau:1084` |
| OnEnter / OnExit (Field, Aura) | Implemented, runtime untested here | E dispatch [DOUBLE]; membership [SRC] `:1338` → [STUDIO] |
| OnTick / OnInterval / OnExpire / OnSpawn / OnCast / OnProximity / OnCasterDeath / OnDamageTaken / OnBreak / OnCommand | Implemented, untested end-to-end | [SRC]; schema event lists printed by suite |
| OnThreshold | Partial: per-target **health %** only | F |
| Runtime counters: `SpellState.TriggerCount` (with `MultipleOf` cadence), `AreaOccupants`, `EventTargets` | Implemented & tested | COUNTERS [DOUBLE using real `MagicRuntimeCounters`, evaluator, validator] |
| OnChargeComplete, OnTargetAcquired, OnEffectCreated/Destroyed | Unsupported | [SRC] absent from schema; F check |
| Per-step conditions | Implemented & tested (`step.Condition`, per-target filter, fail-closed) | STEPS checks [DOUBLE with real `MagicStepCondition`, dispatch, validator]; server resolver [SRC] → [STUDIO] |
| Secondary area effect | Implemented & tested: `Explode` = instant sphere carrying any per-target payload (Summon, Enhancement, AerialMovement, Manipulation excluded) | A, B |
| Effects that spawn a different effect (Form) | Implemented & tested (`SpawnEffect`: every Form except Manipulation) | C, F [DOUBLE using real `SpellSpec.expandSpawnEffect`]; runtime [SRC] `MagicService.spawnEffect` → [STUDIO] |
| Secondary projectiles (Split/Spread) | Implemented & tested | C, D [LOCAL] |
| Secondary entities with independent state/targeting/motion/collision/lifetime | Implemented (runtime records per child) | D [LOCAL] targeting; rest [SRC] `MagicService.luau:1920-1980` |
| Secondary entities with independent **effects/definition** | Implemented & tested (spawned effects carry their own definition) | D [DOUBLE] |
| Nested secondaries (child splits, explosion spawns projectile) | Partial: spawned effects nest up to `MaxSpawnNesting` = 2; Split children still cannot split | F, SAFETY |
| Persistent effects with own lifetime (Field, Aura, Construct, Linger) | Implemented; Linger tested | F [LOCAL] |
| Reusable effect definitions across spells | Unsupported (no references / sub-spell library) | [SRC] |
| Same payload across Forms | Implemented & tested (Damage valid on 7 Forms) | probe + A/E/G |
| Safe serialization | Implemented | strict `keys()` whitelist in `SpellSpec.validate`; unknown field test |
| Recursion bound | Implemented: `MaxMagicEventDepth`=8 | SAFETY |
| Fan-out / per-cast work budget | Implemented & tested (`MaxOperationsPerCascade`) | SAFETY: 3 targets went from 9,841 to 127 damage ops [DOUBLE using the real budget module]; Studio verification pending |

## D. Experimental spell results

All configurations are in `tests/emergent_magic_audit_spec.luau`. No new spell-specific code was written for any test.

| Test | Configuration (abridged) | Result | Notes |
|---|---|---|---|
| **A** Multiple effects | Projectile `OnImpact = [{Damage 10, Force 30}, {Behavior=Explode r6, [Damage 4]}]` | **Pass** | The hit target took 10+4 damage and 1 impulse. A bystander took 4 damage and no impulse. With Force removed, damage was the same and there was no impulse. Limit: Explode cannot carry Force. |
| **B** Conditional chain | `OnImpact = [{Explode r8 [Damage 7]}]`, `OnDamageDealt = [{Force}]` | **Pass** | Exactly one sphere ran. It damaged only enemies inside the radius. The explosion's damage re-emitted `OnDamageDealt` and applied Force. There is no Fireball-style handler. |
| **C** Parallel branches | Original: `Behaviors=[Split×3]`, `OnImpact=[{Explode}, {Slow}]`. **Now:** `OnImpact=[{SpawnEffect Wave}, {SpawnEffect Projectile ×3}]` | **Pass** (was Partial) | One impact starts a damaging spherical Wave (everyone in range hit, nobody outside) and three secondary Projectiles. Original result: | Both steps ran. The Split executor produced 3 children and ended the parent. Branch A was an instant sphere, not an *expanding wave*, because there is no way to spawn a Wave Form from a trigger. |
| **D** Independent secondaries | Original: `Behaviors=[Split×3, Homing]`. **Now:** `SpawnEffect` Projectile ×3 with its own `Homing` and `OnImpact=[Slow]` | **Pass** (was Partial) | The children carry their own definition: they home, and their impact slows rather than running the parent's Damage. Split itself still copies the parent. Original result: | Each child acquired a different homing target (Enemy1, Enemy2, Enemy3). Children are separate runtime records with their own position, velocity, TargetsHit and lifetime [SRC]. They share the parent's payloads and behaviours; they cannot split again or carry a distinct definition. |
| **E** Persistent conditional area | Field `FixedDuration 6`, `OnEnter=[Damage]`, `OnDamageDealt=[Explode]` | **Pass at dispatch level**; membership tracking is [STUDIO] | Entry dispatch applies damage, and the follow-up Explode validates. Explode is not allowed directly on Field `OnEnter`/`OnTick`. |
| **F** Multi-stage | Original: Projectile `Linger 4s r6`, `OnTick=[Damage]`, `OnThreshold 50%=[Force]`. **Now:** Projectile `OnImpact` → `SpawnEffect` Field (4 s) → Field `OnEnter` with `Condition` target health < 50% → `SpawnEffect` Wave `[Force]` | **Pass** (was Partial) | Impact starts a 4 s Field. A healthy enemy entering does nothing; a wounded one triggers a Wave that displaces everyone in range. The count-of-enemies version also passes: a Field `OnEnter` step with `AreaOccupants >= 3` spawns the Wave only when the third enemy enters (COUNTERS checks). Original result: | Linger turns the projectile into a bounded 4 s hazard. Health-threshold crossings trigger Force on each target. Missing: a *count-of-enemies* threshold, a separate field definition, a wave spawn, and distinct triggers per stage (Pulse and Linger ticks share one `OnTick`). |
| **G1** Leech Comet | Body: Homing+Pierce, `OnImpact Damage 60`, `OnTargetDeath Heal` | **Pass** | A kill emits `OnTargetDeath`, which runs Heal. |
| **G2** Grave Bloom | Soul Field: `OnTick Damage`, `OnTargetDeath Summon` | **Pass** | A kill inside the field triggers Summon. Actual NPC spawn is [STUDIO]. |
| **G3** Ricochet Pulse | Time: Bounce+Pulse, `OnTick Slow`, `OnExpire Explode Damage 9` | **Pass** | Bounce reflects velocity, and the expiry explosion deals damage. Pulse-to-OnTick timing in flight is [SRC]/[STUDIO]. |

## E. Architectural limitations (ranked)

1. ~~**One spell = one Form + one flat trigger table.**~~ **Addressed 2026-10-15 by SpawnEffect** for every Form except Manipulation, which needs a selected object that an event point cannot supply. Original finding: No effect can own a definition. The result is that projectile → field → wave chains, children that behave differently from their parent, and explosions that spawn projectiles are impossible. *(Severity: critical; blocks Level 4 and 5.)*
2. **The only spawning trigger behaviour is `Explode`.** ~~Damage-only~~ **Fixed 2026-10-14:** it now carries any per-target payload. It is still an instant sphere: there is no lasting or expanding area. *(Medium.)*
3. ~~No per-step conditions.~~ **Fixed 2026-10-14** (see Update). Original finding: Steps accept only `Payloads` plus fixed event filters (`HealthPercent`, `Command`, `DeathMode`). Branching on a condition such as "if target burning", "if count ≥ 3" or "every 3rd tick" is impossible. *(High.)*
4. **Event filtering is hard-coded in `MagicTriggerDispatch.luau:9-15`**, with one `if` per event. Adding a filterable event needs dispatcher code. *(Medium.)*
5. **Projectile behaviours are fixed modifiers, not composable effects.** `Split` is limited to depth 0, `Linger` always ends travel, and `Pulse` and `Linger` both feed `OnTick`. *(Medium.)*
6. **No shared runtime state, counters or variables**, so player-defined thresholds have nothing to read. *(Medium.)*
7. ~~**The editor exposes only a subset.**~~ **Largely addressed 2026-10-15.** Codex added an action map plus selectable, reorderable and removable steps with "+ ADD ALSO". On top of that, "+ ADD IF" (a copy of the selected step with a starter condition) and "+ OTHERWISE" (a copy with the exact inverse condition, from `MagicActionFlow.otherwise`) now exist. The action map shows each branch's rule, and the step-condition panel follows the selected step. Original finding: Payload toggles go into one "primary" step per event, plus one toggle per behaviour (`MagicLabController.luau:1317-1450`, `4320-4345`). The schema allows 4 steps per event, but the UI cannot author several independent payload steps on one event. *(Medium.)*

## F. Security & performance risks

- **Exponential reaction fan-out [DOUBLE, high-confidence SRC].** `OnDamageDealt → Explode(Damage) → OnDamageDealt` passes validation. Every damaged target re-emits the event, and the depth cap of 8 limits depth but not breadth.
  - Measured in the harness: 1 target gives 9 damage ops, while 3 targets give **9,841 damage ops from a single cast**. The worst case at `MaxTargets`=16 is on the order of 16⁸.
  - `SpellSpec.estimate` only doubles Complexity (3 → 6) and does not model recursion.
  - The production `ApplySpherePayloads` (`MagicService.luau:948`) does not dedupe targets across nested events.
  - Not verified in Studio. It should be treated as a server-DoS vector until a per-cast budget exists.
- **Event depth is the only chain guard.** There is no per-cast operation budget, area-query budget or per-frame server budget. Active-entity caps exist: `MaxActivePerPlayer`=8, `MaxActiveGlobal`=64, summon caps, and `MaxSplitChildren`=5.
- **Client data.** Definitions are re-validated server-side with a strict key whitelist and numeric bounds (`SpellSpec.validate`). Unknown events, fields, payloads and out-of-range radii are rejected [LOCAL]. This is good.
- **Caster death and cleanup.** `OnCasterDeath` exists, periodic effects check `Caster:IsDescendantOf(workspace)` (`MagicPayloadExecutors.luau:35,62`), and `MagicCastInterruption` exists. Not exercised here [STUDIO].
- **Durations are bounded** (`MaxDuration`=15, `MinInterval`=0.1).

## G. Recommended architectural changes (smallest coherent set)

None of these needs a rewrite. The `emit → Dispatch → executors` seam is already the right extension point.

1. **Per-cast budget.** Put an `OperationBudget` on the runtime origin (`RuntimeOrigin`, already threaded through `eventState`). Decrement it in `emit` and in `ApplySpherePayloads`, and stop when it is exhausted. Also add a validator rule or estimate term for self-reactive events, such as an `OnDamageDealt` step that deals damage.
2. **Generalise trigger-step behaviours.**
   - Let `Explode` accept any payload kind that is valid on the host Form and event, instead of `{"Damage"}` only.
   - Add a `SpawnEffect` behaviour that instantiates an *embedded child definition* (any Form) at the event position and direction. The child gets its own `Triggers`, is validated recursively by `SpellSpec.validate`, and carries `depth+1` plus the parent's budget. This one change unlocks Tests C, D and F.
3. **Per-step `Condition` using the existing `MagicConditionTree` / `MagicConditionEvaluator`.** Evaluate it in `MagicTriggerDispatch` before running a step. Move the three hard-coded event filters into this one mechanism.
4. **Per-runtime counters.** Examples: `TriggerCount`, a targets-in-area count, and a step-level `Every N`. Expose them to conditions. This enables real thresholds and cadence branching.
5. **Editor:** a step list per event (add, remove, reorder steps; per-step condition; "spawn effect" opens a nested editor using the same Form chapters).

## H. Prioritised development plan

| # | Missing capability | Change | Modules | Acceptance criteria | Tests |
|---|---|---|---|---|---|
| 1 | Fan-out safety | Per-cast op/area-query budget on `RuntimeOrigin`; estimate penalty for self-reactive steps | `MagicService` (emit, context, ApplySpherePayloads), `SpellSpec.estimate`, `MagicLab` limits | 3-target recursive spell executes ≤ budget ops; feedback reports truncation | Flip the SAFETY fan-out check to assert `ops ≤ Limits.MaxOpsPerCast`; Studio stress with 10 dummies |
| 2 | Non-damage area secondaries | `Explode.PayloadKinds` = host-compatible kinds | `MagicSchema`, `MagicLabController` behaviour UI | Explode+Force/Slow validates and applies to sphere targets | Flip the "Explode cannot carry Force" check |
| 3 | Per-step conditions / branching | `Condition` step field evaluated in `MagicTriggerDispatch` via `MagicConditionEvaluator`; migrate HealthPercent/Command/DeathMode | `MagicTriggerDispatch`, `SpellSpec.validate`, `MagicConditionSpec` | Two steps on one event with mutually exclusive conditions; only the matching one runs | Flip "trigger steps cannot carry their own condition"; existing `test_magic_trigger_dispatch.lua` still passes |
| 4 | Effects that create effects (nested) | `SpawnEffect` behaviour carrying an embedded child definition; recursive validation with `MaxNestingDepth` and summed cost | `MagicSchema.Behaviors`, `MagicBehaviorExecutors`, `MagicService` (start a Form runtime from an event context instead of only from a player cast), `SpellSpec` | Test F as authored (projectile → field → wave) runs with no new spell code; children have distinct Triggers | New audit tests C-wave, D-distinct-children, F-full; Studio run |
| 5 | Counters / thresholds | Runtime counters exposed to conditions (`TriggerCount`, `AreaOccupants`) | `MagicService` runtime state, `MagicConditionEvaluator` | "When ≥3 enemies inside field, emit wave" works | Flip the "no area-occupancy threshold" check |
| 6 | Child-specific projectile behaviour | Split/Spread may reference a child definition (reuse #4) and permit bounded depth | `ProjectileBehaviorSpec`, `MagicProjectileBehaviorExecutors`, `MagicService.SpawnSplit` | Child can split once more under the budget; child payloads differ from the parent's | Flip both D limitation checks |
| 7 | Editor access | Step list, per-step condition picker, nested child editor, save/reopen round-trip | `MagicLabController`, `MagicLabService` codec | Every capability above authorable and survives save/reload | `grimoire_flow_spec` additions; Studio UI pass |
| 8 | Reusable definitions | Named sub-effects in the player library, referenced by id (resolved and re-validated server-side) | `GrimoireLibrary`, `MagicLabService`, `SpellSpec` | A sub-effect edited once updates all spells that reference it | Codec round-trip test |

## Notes

- `tests/test_magic_lab.lua` (via `scripts/run_luau_magic_tests.py`) was **already failing** before this audit, at line 325: "Channeled Beams should support expiry triggers". That failure is unrelated to this audit and was left alone.
- Files added: `tests/emergent_magic_audit_spec.luau`, `scripts/run_emergent_magic_audit.py`, and this report. No production files were changed.
