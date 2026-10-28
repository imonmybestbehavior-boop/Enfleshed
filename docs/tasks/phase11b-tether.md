# Phase 11b — Tether Form

Status: done (uncommitted, awaiting review; approved 2026-10-28 with all defaults)
Request: Phase 11b of the spell-creator plan: a Tether Form linking two characters (Caster↔Target or Target↔Target) with MaxLength, line-of-sight break (0.5 s grace), Duration, Interval/OnTick per end, optional Pull, OnBreak on a snap, ShareDamage (soul link, no loops), per-caster/per-character limits, PvP caps, a Beam visual; registration, Forge/Lab, parity, emergent audit.
Scope: branch `phase11b/tether` (worktree `C:/Users/bello/Documents/Projects/Enfleshed-phase11b`, from `phase11a/interception`). Schema/SpellSpec/LifetimeSpec/PrincipleSpec, `MagicFormExecutors`, `MagicService` (create/step/end, damage hook), `DamageService` (hook also sees DoT ticks for sharing), `MagicTriggerDispatch` (per-end step targets), `MagicPresentation` (Beam + snap), `SpellStatCaps`, Forge/Lab, tests. · Out of scope: Studio, the main checkout, CURRENT_STATE.md, new art, existing balance numbers, commits/pushes (only if asked).

## Context (only what a resumed session needs)
- 11a added `Damage.setInterceptor` (called only for interception-eligible hits) and `Redirected` damage that is never intercepted and continues the cascade depth. Tether sharing reuses that marking.
- Line of sight: `MagicWorldQuery.sweep(start, delta, caster, visual, radius, ignored)` (raycast); Field sampling: `NextInterval` per record in the Heartbeat.
- `OnBreak` today means "a shield from this spell broke" (Shield executor → `DamageContext.EmitEvent("OnBreak")`), added to every Humanoid-target Form.

## Design (proposed)
- **Authoring.** `Tether = { Anchors = "CasterToTarget" | "TargetToTarget", MaxLength 10–60, BreakOnLineOfSight = true, Interval 0.1–10, Pull = false, ShareDamage = nil | 10–90 }`.
  - Targeting is EntityTarget (aim / lock-on, like Enchantments on others). CasterToTarget: A = caster, B = the picked target. TargetToTarget: A = the picked target, B = the nearest other eligible character to A within MaxLength.
  - Lifetime: FixedDuration (plus the usual end conditions). Instant cast.
  - Events: OnCast, OnTick (every Interval), OnBreak ("When it snaps"), OnExpire (also OnDamageDealt/OnTargetDeath/OnRecast as reactive events). Step field `Anchor = "A" | "B" | "Both"` (default Both) chooses which end a step acts on, so one step drains B and another heals A.
- **Runtime.** A `Kind = "Tether"` active record, stepped in the Heartbeat.
  - **Ending:** either anchor dead or gone → ends (OnExpire). Beyond MaxLength, or line of sight blocked for more than 0.5 s → snaps (OnBreak, no OnExpire). Duration over → OnExpire.
  - **Pull** (optional): past 80% of MaxLength the server nudges both anchors together (bounded impulse through `Movement.allowMagicImpulse`); it still snaps beyond MaxLength.
  - **Rules:** pure `MagicTetherSpec` owns the decisions (stretch state, LoS grace timer, pull force, picking the oldest tether to end, anchor counts, share split) and has unit tests.
- **ShareDamage.** Applied after Interception for the same hit. The holder's share (ShareDamage %) goes to the other anchor as `Redirected` + `Shared` damage via `Damage.apply`: never shared back, never intercepted, and the cascade depth continues. DoT ticks are shared, so DamageService calls the hook for every hit that is not Redirected, and Interception keeps skipping Periodic hits itself. If the attacker may not damage the other anchor, the share stays on the target.
- **Limits.** At most 2 live Tethers per caster (a new one ends the oldest, OnExpire), and at most 3 tethers per character as an anchor (a cast that would exceed it is refused before cost).
- **Visual.** A server `Beam` between two attachments on the anchors' roots, in the spell's element colour, removed on end; on a snap a short `Presentation.impact` at the midpoint. No new assets.
- **PvP caps (provisional):** `MaxTetherLength` 40 open / 30 ranked (by the caster's zone, like Rush). `MaxTetherShareDamagePercent` 50 / 35 when the receiving anchor is a player. `TetherPullOnPlayers` true open / false ranked.
- **MagicLab (provisional):** `MaxTetherLength = 60`, `MaxTetherInterval = 10`, `TetherLineOfSightGrace = 0.5`, `TetherPullStart = 0.8`, `TetherPullSpeed = 12`, `MaxTethersPerCaster = 2`, `MaxTethersPerCharacter = 3`.

## Milestones
- [x] M1 Tether rules (pure)
  - Accept: `MagicTetherSpec` — length (cap), `step(state, distance, hasLineOfSight, dt, settings)` → "Hold" | "Pull" | "Snap" with the 0.5 s LoS grace, pull velocity, `share(amount, percent, cap)`, `oldestToEnd(list, max)`, `anchorFull(count, max)`; unit test.
  - Verify: `run_luau_unit_tests.py $LUAU tether`
  - Result: tether 1/1, StyLua clean. `MagicTetherSpec`: `length`, `newState`/`step` (Snap on distance or LoS blocked > grace, the grace timer resets when seen again; Pull between PullStart and MaxLength), `pullSpeed` (0 → full speed across that band), `shareable` (not Redirected/Shared; Periodic allowed), `share` (≤ 90%, PvP cap), `toEnd` (oldest first), `anchorFull`.
- [x] M2 Schema, validation, dispatch
  - Accept: `Schema.Forms.Tether` (mechanics, events, FormOrder), Principles, LifetimeSpec, SpellSpec (fields, ranges, EntityTarget, Instant, FixedDuration), `Anchor` step field on Tether events, payload/behavior timings, `MagicFormExecutors.Tether`; Dispatch routes `Anchor` A/B/Both via `context.AnchorTargets`; shields from a Tether do not fire its OnBreak (OnBreak means the snap); lab validation tests.
  - Verify: magic suite; parity
  - Result: magic suite exit 0 (Tether validation block), parity 55/55, audit unchanged. `Schema.Forms.Tether` after Rush (EntityTarget, FixedDuration, Instant), payloads with per-form sets gain Tether like Rush; every Principle but Matter. `Anchor` step field only on Tether spells; Dispatch routes A/B through `context.AnchorTargets`. On a Tether, OnBreak is the snap: no Shield needed for it in SpellSpec, and its shields breaking never emit it (MagicService `EmitEvent`). `createDraft` now sets `TargetPolicy = "Aim"` for Forms that default to EntityTarget (only `normalize` did before).
- [x] M3 Runtime, sharing, visuals, audit
  - Accept: cast (anchor pick, limits, Beam), Heartbeat step (alive, distance, LoS grace, pull, OnTick per Interval, snap/expire), ShareDamage through the 11a hook, `Presentation.tether`/snap; audit scenarios: drain tether, two chained enemies snapping (OnBreak stuns both), soul link 50% on an ally + crossed soul links without a loop, LoS grace short vs long.
  - Verify: emergent audit; parity (wiring); magic suite
  - Result: audit 223/0 failed (11 TETHER checks: drain tether damages only B and heals only A, no pulse before the interval; chain holds then snaps with OnBreak stunning both and no OnExpire; LoS 0.3 s holds with the grace reset, 0.6 s snaps; 50% soul link to the caster; crossed links share once; DoT ticks shared), parity 56/56 (`test_tether_snaps_shares_and_never_loops`), magic suite exit 0, rojo build ok, modules compile. New Roblox-free `MagicTether` (`settings`, `update`, `share`) driven by MagicService deps (alive, distance, LoS via `sweep`, emit with `AnchorTargets`, pull, finish). Anchors are picked and the 3-per-character limit checked in `validate` (before cost); `CreateTether` ends the caster's oldest beyond 2. `DamageService` now calls the hook for every non-Redirected hit; `MagicInterception` still skips Periodic itself (11a parity check updated to the new hook line), and `shareSoulLinks` runs after it with `Redirected + Shared` damage. Pull sets horizontal velocity on server-owned roots and is skipped for players where `TetherPullOnPlayers = false`; on client-owned player roots it may not take effect (Studio check). PvP config values landed here because the runtime reads them (M4 adds their tests).
- [x] M4 Registration, editors, PvP caps
  - Accept: Forge (Form card "Tether", anchors, length, LoS, interval, pull, share; "When it snaps"; per-step end chooser) and Lab equivalents; PvP caps in both profiles; stat-cap tests; parity consumers.
  - Verify: parity; magic suite incl. `--forge-only`; stat caps test
  - Result: parity 56/56, magic suite + `--forge-only` exit 0, stat_caps 1/1, editors compile, StyLua clean. Forge: Tether icon/verb ("Link two characters"), OnBreak reads "When it snaps" on a Tether (`phraseFor`, three call sites), per-step "Acts on" chooser (you / the target, or first / second target). Lab: Tether mechanics through the generic loop (its Interval was hidden outside Channeled/Field/Aura; Tether added), per-step "Acts on" select. Grimoire glyph; Control intent recommends Tether. PvP caps (`MaxTetherLength` 40/30, `MaxTetherShareDamagePercent` 50/35, `TetherPullOnPlayers` true/false) tested. Companions: Tether is outside the companion Form set, unchanged.
- [x] M5 Integration and handoff
  - Accept: full gate pass; this file marked done; no commit/push unless asked.
  - Verify: `bash scripts/check.sh`; Studio items listed as pending.
  - Result: `bash scripts/check.sh` 40/40 PASS (82/82 unit tests). Not committed or pushed. Pending Studio Play (source checks only): the Beam look and the snap flash; drain/heal pulses in a fight; Target-to-Target picking the nearest second enemy; distance and line-of-sight snaps around pillars (0.5 s grace); Pull on NPCs and on players (client-owned roots may ignore server velocity); soul-link sharing between players in PvP zones; the 2-per-caster and 3-per-character limits.

## Open questions / blockers
- TargetToTarget picks the second anchor as the nearest eligible character to the first within MaxLength (plan). "First two characters hit" would need a projectile-style sweep; not planned.
- Pull still snaps beyond MaxLength (plan); it only acts between 80% and 100%.
- OnBreak on a Tether means only the snap: shield-break OnBreak from a Tether's own Shield payloads is not routed to it (plan).
- A cast that would give a character a 4th tether is refused before cost (plan), instead of ending one of theirs.
- ShareDamage runs after Interception on the same hit (plan): an interceptor on the target acts first, then the soul link splits what lands.
