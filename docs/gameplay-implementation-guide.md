# Gameplay implementation guide and copyable prompts

Updated 2026-10-19. This is the execution plan for the design in `defend-the-walls-gameplay-design.md`. The latest scope instructions below override earlier suggestions to change damage, unlock enforcement or freeze the magic runtime. No implementation is performed by writing this guide.

## Scope: enforce this throughout

Confirmed latest instructions:

1. Work on the gameplay loop, map and mode infrastructure. **Do not modify the magic systems.**
2. **Leave all existing balance unchanged**, including enemy health/scaling. Measure the 2–3-hit starter-spell target, but do not tune toward it in this workstream.
3. Defer magic editing/unlock changes. Award XP, currency and wins through existing progression APIs; do not change form/element availability, saved spells, starter spells, slot growth, ranks or costs.
4. Build an **interim safe room without freezing active spells**. Do not claim this provides the originally requested world pause. Full pause remains deferred until it can be delivered within an explicitly authorized scope.
5. Confirmed follow-up: **outside combat and the mission timer continue during interim safe-room editing**. Stop after step 08 for the user's playtest before expanding the remaining city.
6. Confirmed follow-up: **downed state, teammate revives and solo guard rescue are required features of the first integrated loop**. Audit existing interfaces and implement them within the no-magic-changes boundary. If that boundary prevents consistent behavior, document the concrete dependency and request a scope decision; immediate death/reinforcement is not an approved substitute and step 07 remains incomplete.

Do not edit spell runtime, validators/schemas, authoring/Grimoire UI, spell definitions/library, effects/payload execution, magic targeting, mana/strain, spell VFX, magic progression rules, stat caps or magic network protocols. Read these as necessary to understand interfaces. Do not change magic indirectly through a shared config, feature flag, character attribute, global physics/time change or damage multiplier.

Existing enemy HP/damage/speed, player combat stats, resource rates, rewards/costs, spell values and existing caps remain unchanged. A new gameplay mechanic will need provisional parameters (for example a shelter count or rescue-window length); keep these isolated, labeled and configurable, not presented as approved balance or an opportunity to retune existing numbers. Reuse existing caps/budgets where possible. Record future balancing needs separately.

Permitted work includes enemy navigation/animation, map geometry, objective state, gameplay-only mission timing and mode lifecycle, siege-tool mechanics, NPC rescue/escort, existing reward wiring, mission UI, hub/arena access and testing. Shared infrastructure edits must be narrow, preserve existing consumers and avoid magic semantics. If a requested mechanic requires a forbidden change, report the dependency and continue independent authorized work; do not quietly implement a partial imitation and call it complete.

## Why this order

The current source already has a map generator, Defend the Walls builder, enemy scheduler, enemy attack state machine, guards, mode lifecycle, profiles, rewards and UI. Extend the existing foundations rather than building replacements by default.

Important source facts to recheck at the start of implementation:

- `src/server/Services/EnemyService.luau` already handles path requests, blocked paths, direct movement, waypoint jumps and procedural poses. Raised-ground failure requires diagnosis; enabling jump alone is not a plan.
- `src/server/Services/DefendTheWallsGuards.luau` uses simple MoveTo behavior. Rescue/retreat reliability cannot assume enemy pathfinding is automatically shared.
- `src/server/Services/ModeRunner.luau` currently finishes a round at EndAt using timeoutOutcome. Boss arrival must become separate from round completion; changing Duration alone will not deliver the desired loop.
- `src/server/Services/DefendTheWallsService.luau` currently uses three shared wall pools and separate final doors. The intended geometry has four wall lines with distinct intervening districts. Separate physical wall identity from active gameplay objective.
- `src/server/Networking/ActionRouter.luau` routes mission spawn using MissionDefender and DefenderSpawn, and sets player health. Change only gameplay spawn integration if needed; leave health and casting/action paths alone.
- `src/client/Controllers/UIController.luau` and `src/client/UI/HUD/` are current mission/lobby HUD entry points. Do not assume old documentation's MissionController/HUDController filenames still exist.
- `src/server/Services/MissionProgression.luau` owns XP/Marks and idempotent result handling; it also imports magic progression configuration. Reward integration must preserve magic-owned fields and behavior.
- Existing tests include `tests/defend_the_walls_layout_spec.luau`, `tests/test_defend_the_walls_map.py`, `tests/test_mode_framework.py`, `tests/profile_session_spec.luau` and `tests/combat_policy_spec.luau`.

## How to execute the prompts

Use the steps in order. Paste the execution contract below and one numbered prompt at a time into the implementation chat. Later prompts depend on the reviewed output of earlier steps; do not dispatch the entire list blindly. No new chat, subagent, branch, commit, PR, publication or deployment is requested by this guide.

Every implementation step should end with: files changed; behavior delivered; checks actually run; Studio observations versus assumptions; pending asset/dependency issues; and the exact next step. Update `docs/gameplay-implementation-status.md` as the implementation record, creating it in step 00. Keep the design document as the source for intent and this guide as the scope/sequence authority.

### Execution contract — paste before a step prompt

```text
Work in C:\Users\bello\Documents\Projects\Enfleshed. Read applicable AGENTS.md instructions and docs/gameplay-implementation-guide.md, docs/defend-the-walls-gameplay-design.md, and the current implementation-status file if present. Implement only the numbered step I supply. Preserve unrelated and in-progress user changes; inspect git status and relevant diffs first. Do not revert, format or regenerate unrelated files or a place file locked/open in Studio.

This is gameplay-only work. Do not change any magic runtime, spell definition, validator/schema, authoring/Grimoire UI, spell progression/unlock enforcement, mana/strain, magic targeting, VFX, stat-cap, or magic protocol code or behavior. Leave all existing balance unchanged, including mission enemy health/scaling and current reward values. Existing progression APIs may record XP/currency/wins without changing magic unlock behavior. Full world pause is deferred; the interim safe room must not freeze active spells or claim to pause them.

Read the actual code before editing. Reuse current services and public APIs. Keep new gameplay parameters isolated and explicitly provisional. Where a mechanic cannot be implemented inside this boundary, document its precise dependency, complete independent work and mark the mechanic deferred rather than bypassing the restriction. Use server authority for objectives, supplies, outcomes and rewards, with bounded/validated gameplay requests. Add meaningful tests for state transitions, navigation math, rewards and concurrency; verify actual movement/animation/gameplay in Studio when available. Never report a source/build check as a successful live playtest. Run relevant checks for the change and update docs/gameplay-implementation-status.md with evidence and unresolved items.
```

## Ordered steps

### 00 — Capture the starting point and ownership boundary

**Purpose:** know what is broken, what is already working and which changes belong to active magic work. No fixes yet.

**Implementation:** inspect source, current dirty files, tool availability and test commands. Record actual solo/co-op behavior where Studio access exists: initial spawn, attack delivery, raised-ground failures, visible animation, death return, wall breach, victory/defeat, rewards and replay. Mark unavailable observations honestly. List protected files and mixed-responsibility files. Record existing balance values without changing them. Identify existing public seams for lethal-damage interception, safe-room editing access and contribution attribution; do not invent APIs.

**Done when:** the status file contains a source map, reproducible failures, baseline checks and a protected-scope list. An unknown live behavior is clearly unknown.

```text
Step 00: Perform a read-only implementation readiness audit for the gameplay plan. Create docs/gameplay-implementation-status.md with current services/UI/tests, protected magic work, existing balance snapshot, reproducible issues and Studio access limitations. Inspect current enemy traversal and pose handling, ModeRunner timeout/death/respawn behavior, spawn routing, damage policy, guards, rewards and existing safe editing access. Identify whether downed-state interception and full mission pause can work without magic changes. Do not change gameplay source, balance, spell files or place files. End with an evidence-based next task for step 01.
```

### 01 — Fix enemy navigation before building more terrain

**Depends on:** 00.

**Implementation:** build a development-only traversal fixture: flat ground, shallow raised edges, stairs, ramps, slopes, corners, doorways and crowds. Match actual collision bodies to agents. Trace direct chase versus path following, grounding, jumps, blocked paths, repathing and recovery. Fix reproduced causes without changing existing movement-speed or attack balance. Keep scheduler budgets. Do not hide failures by deleting/teleporting all stuck enemies.

**Done when:** all supported obstacle types work repeatedly on actual enemy sizes, with multiple enemies and target changes; unsupported terrain is documented. Pure navigation helpers have focused tests where useful.

```text
Step 01: Diagnose and repair the reproduced enemy raised-ground/navigation failures. Start with EnemyService, EnemyRuntime and the Enemy keys of Sandbox configuration; treat the rest of that shared config as protected. Create a development-only traversal fixture and diagnostics, reproduce the failure, then make the smallest navigation/collision correction. Preserve existing HP, damage, speeds, combat timing and path budgets. Test each enemy size, target changes, blocked routes and crowds. Include repeatable Studio instructions/results and keep stuck cleanup from concealing unresolved failures.
```

### 02 — Make enemy intent visible through animation

**Depends on:** 00–01.

**Implementation:** inspect existing mesh rigs/joints and procedural pose output. Fix broken presentation; implement readable locomotion, anticipation, impact/recovery, reactions and death without changing server attack timing. Produce an asset manifest for missing animations, reuse rights/source and rig compatibility. Asset acquisition/upload is a separate dependency, not a reason to invent IDs. A functioning temporary procedural pass may support prototyping but is not final authored art.

**Done when:** actual enemies visibly move and communicate attacks in Studio; damage stays aligned with existing timing, and interruption/death clean up presentation.

```text
Step 02: Audit the current enemy rigs and procedural poses, then deliver visible enemy-only animation for idle/movement, existing attack wind-up/impact/recovery, reactions and death. Reuse working rig/pose systems where possible and synchronize to existing server combat timing without rebalance. Do not touch player magic/melee animations or spell presentation. Record missing authored/acquired assets and provenance in a manifest; never fabricate uploaded asset IDs. Clearly distinguish prototype animation from final animation and validate on each current enemy rig.
```

### 03 — Separate mission lifecycle, defense position and boss timing

**Depends on:** 00; can be designed while 01–02 are being reviewed.

**Implementation:** model physical walls, region objectives and assault progression separately. Introduce the minimum mode hooks/state required for breach/objective failure, reinforcements, boss arrival, loss and result. Maintain old mode behavior by default. Boss arrival after 5–10 active minutes must not automatically grant victory. Design gameplay time abstraction without touching magic clocks or promising a full pause.

**Done when:** state tests cover repeated/simultaneous events, earlier-position success, final-defense loss, boss trigger versus victory, abandonment, disconnect and clean replay.

```text
Step 03: Extend the current ModeRunner and DefendTheWallsService seams minimally to separate round lifecycle, physical defense identity, region objectives, reinforcement events and boss arrival. Keep existing behavior as the default for unaffected modes. Add focused state logic/tests for breach and failed-objective progression, one-time transition processing, elapsed assault-time boss trigger distinct from timer victory, final loss, abandonment and replay reset. Provide gameplay timing/state seams for later safe-room work, but do not pause or alter magic clocks, player resources or active spells. Document every shared API change.
```

### 04 — Build the full route as a simple graybox

**Depends on:** 01, 03.

**Implementation:** author first wall → outer district → second wall → second district → third wall → courtyard → last wall. Mark rampart start, shelter plots, citizen paths/alternatives, fallback spawns, bypass routes, sewer connectors, safe room and boss footprints. Keep surfaces navigation-safe. Do not detail every district or add random module generation yet. Integrate with existing spell target/collision interfaces without changing them.

**Done when:** the route is walkable, enemy-navigable and clearly ordered; spawns/fallbacks are correct; boss-sized navigation envelopes are reserved at every held position.

```text
Step 04: Substantially rebuild the DefendTheWalls layout and modular map builders as a plain graybox following the exact four-wall order in the design. Start players on first-wall ramparts using existing gameplay spawn routing. Reserve distinct districts, repairable shelter plots, preset/alternate citizen routes, bypass approaches, optional sewer connections, safe room and boss fighting spaces. Preserve the nighttime identity with simple readable lighting. Test navigation and existing spell collision/targetability as consumers; do not alter magic to fit geometry. Extend layout/map tests for order, reachability and spawn locations.
```

### 05 — Implement first-wall siege gameplay

**Depends on:** 02–04.

**Implementation:** fixed, destructible oil and trebuchet emplacements, shared mission supplies, server-owned use/health, readable prompts/feedback. Create gameplay-specific damage through existing damage authority; do not reimplement spell effects or modify spell assets. Use isolated provisional siege parameters. Handle simultaneous users, destroyed tools, cancelled operations and round cleanup.

**Done when:** players start casting from ramparts and can operate siege tools; concurrent requests cannot duplicate shots or resource use; tool destruction disables use.

```text
Step 05: Add fixed destructible hot-oil and trebuchet emplacements to the first-wall graybox. Implement mission-owned shared supplies and server-validated interaction/use state using existing damage authority. Keep siege mechanics independent of magic runtimes and existing spell assets. Add basic interaction feedback and provisional isolated siege settings. Test concurrent operation, supply exhaustion, destruction during operation, nonparticipant requests and replay cleanup. Preserve all existing combat and reward balance values.
```

### 06 — Implement repairable shelter defense

**Depends on:** 03–05.

**Implementation:** separate building health, repair interaction, resident status and tolerable shelter loss threshold; active objectives select failure/fallback. Keep existing walls' repair values intact; new shelter tuning is provisional. Enemies attack objectives by role using current interfaces. Show shelter/inner-wall threat status through gameplay HUD.

**Done when:** losing one building need not fail the stage; threshold failure occurs once; valid repairs cannot resurrect failed objectives accidentally; early held-position success is possible.

```text
Step 06: Implement outer-district inhabitants sheltering inside separate repairable buildings. Add server-owned shelter integrity/status, configurable provisional loss threshold and gameplay repair interactions using current service seams. Wire threshold failure to the step-03 transition model while preserving the possibility of winning with citizens protected and inner defenses intact. Add minimal mission HUD indicators and enemy objective-target wiring without changing spells or targeting rules. Test partial losses, simultaneous destruction/repair, invalid requests, fallback and replay reset.
```

### 07 — Deliver recovery, guards and reinforcement rules within the boundary

**Depends on:** 01, 03, 06.

**Implementation:** distinguish downed from dead and returned. Downed state, teammate revives and solo guard rescue are required. Audit all lethal paths and existing public interception interfaces first. If consistent interception requires protected magic changes, document the dependency and seek a specific scope decision; continue independent work but leave step 07 incomplete rather than silently dropping revives. Improve guards' movement for rescue/retreat. Return dead players on wall fall or timer expiry, whichever happens first, without double charge/respawn. Life counts/shared policy are explicitly configurable playtest variants. Preserve player health/resource tuning; isolate newly needed rescue settings as provisional gameplay configuration.

**Done when:** players enter a real downed state, teammates can revive them, solo guards can attempt rescue, failed rescue follows the agreed life/death rules, eligible dead players return once, and all-lives-exhausted produces one defeat. Test every applicable lethal damage path. A death/respawn-only implementation does not complete this step.

```text
Step 07: Implement the required downed state, teammate revives and solo guard rescue using audited existing gameplay interfaces. Preserve magic code/behavior and current health/resource balance. Audit all relevant lethal paths before choosing interception. Add mission-owned downed/dead/life/reinforcement state: wall fall or timer expiry returns eligible dead players once, with configurable test life policies and clean defeat at exhaustion. Improve guard retreat/rescue navigation. If protected magic changes are necessary, report the exact dependency for a scope decision and leave this step incomplete; do not replace the required revive feature with immediate death/respawn. Test damage-source coverage, revive interruption, simultaneous rescue/respawn triggers, leave/rejoin, all players incapacitated, blocked guard routes and replay.
```

### 08 — Close the first reward-and-replay loop

**Depends on:** 03, 05–07.

**Implementation:** existing XP/Marks/win receipt APIs, existing reward values/formulas, clear result UI and next action, clean replay. Keep banked progress. Preserve existing interruption behavior. Only credit events exposed accurately by existing interfaces; defer attribution needing new magic metadata. Do not add/edit magic grants or enforce form/element access. Describe future grants as future, not already unlocked.

**Done when:** first review build supports action → defend → success/failure → existing saved earnings → next action → replay. Duplicate completion cannot double-grant; private published reconnect verifies persistence.

```text
Step 08: Integrate the first complete rampart/shelter mission reward-and-replay loop through existing MissionProgression, PlayerProfileService and ModeRunner APIs. Preserve current XP/currency amounts/formulas, banked data, interruption handling and magic-owned progression fields. Show clear outcomes and the existing next-action/loadout access without editing Grimoire or unlocking new magic controls. Test duplicate finish, save failure, result/replay, disconnect and three consecutive runs. Record a published private persistence check if available; otherwise mark it pending. Defer unexposed magic support attribution rather than modifying payload metadata.
```

**Review checkpoint A — mandatory user playtest stop:** stop implementation after step 08 and provide the build/review instructions for the user's playtest before expanding content. Current weak damage remains known and unchanged. Judge navigation, readability, objective clarity, lifecycle and rewards independently of balance satisfaction. If revive support is blocked, disclose that clearly; a reduced recovery loop has not been accepted as a substitute.

### 09 — Add role-driven pressure and inner-wall bypasses

**Depends on:** 03–08.

**Implementation:** use existing enemy stats, attacks and budgets. Make target priority/composition respond to defense state and player objective choices. Add bounded, telegraphed bypass routes; prevent invisible automatic inner-wall losses. Begin with roles supportable by current behavior; roster expansion may add enemy-specific mechanics later without modifying spells. All requested roles stay on the roadmap.

**Done when:** choices influence pressure; bypasses are legible and reachable; solo play is not required to cover impossible simultaneous tasks. No spell counter-system or stat rebalance is smuggled in.

```text
Step 09: Add mission-specific role/target selection and a bounded pressure director using existing enemy stats, attacks and spawn budgets. Let objective/defense state and completed activities affect approaches without directly presenting a next-wave menu. Add telegraphed frontline bypass threats to inner defenses and gameplay HUD warnings. Keep enemy navigation scheduler limits and existing numbers unchanged; new role settings must be isolated provisional gameplay data. Do not add magic resistance/interaction changes. Validate solo versus four-player reachability and document remaining enemy-role implementation work.
```

### 10 — Implement moving citizens in district two

**Depends on:** 01, 03, 04, 09.

**Implementation:** intermittent groups, preset primary/alternate routes, panic from enemies, return toward safety, objective credit/loss. Support temporary blockage without infinite panic, silent rescue credit, or teleport-as-normal-navigation. Use gameplay damage/target interfaces compatible with unchanged spells. Keep route selection bounded under crowds.

**Done when:** citizens reroute and reach safety, losses affect objectives once, panic transitions are readable, and constructs/gates/crowds cannot permanently stall the run.

```text
Step 10: Implement intermittent second-district citizen groups with preset routes to inner safe places, enemy-triggered panic/running, and alternate-route selection when the primary route is blocked. Reuse audited navigation helpers where appropriate without coupling citizens to enemy combat AI. Add server-owned rescued/lost/active counters and provisional loss/cadence settings. Test crowds, breached gates, existing player constructs, multiple blocked routes, repeated panic, stage fallback and cleanup. Do not modify magic targeting/effects or count stranded citizens as rescued.
```

### 11 — Implement courtyard control and final fallback

**Depends on:** 03, 09–10.

**Implementation:** server-owned courtyard bounds/control, enemy occupation drain, defender kills counter drain, zero-control fallback. Isolate provisional rate/kill-credit formula; measure before selecting final balance. Presence alone does not replace kills. Prevent dead/removed enemies and duplicate death events from affecting control twice.

**Done when:** HUD explains drain/counterpressure; a zero crossing triggers one fallback; defeat and boss-state precedence are deterministic.

```text
Step 11: Implement courtyard control as gameplay objective state. Enfleshed occupation drains control; legitimate defender kills provide counterpressure; control reaching zero triggers fallback to the last wall exactly once. Use isolated provisional formula settings, accurate live occupant counts and existing damage/death events. Add clear HUD feedback without changing magic feedback code. Test boundary crossing, dead/removed occupants, simultaneous kills, duplicate events, stage changes, final-wall failure and clean reset.
```

### 12 — Add optional sewer intervention and bounded map variation

**Depends on:** 04, 09–11.

**Implementation:** one concrete gate/collapse/barrier mechanism first; optional access; reduce pressure and redirect survivors, leaving viable approaches. Respect existing enemies when routes close. Then add a small set of validated authored-room arrangements. Returning for secrets is optional and tentative; do not resurrect failed objectives or duplicate rewards. Do not add a new magic manipulation API for sewer devices.

**Done when:** intervention changes routing/pressure observably, no arrangement blocks required objectives, and bypass opportunities remain intentional.

```text
Step 12: Build an optional sewer branch with one gameplay-operated floodgate/collapse/barrier mechanism. It must reduce enemy approaches and total pressure while rerouting remaining attackers through viable paths. Keep existing balance configuration intact; express new intervention behavior in isolated provisional mission rules. Handle existing enemies losing a route and validate every permitted room arrangement before enabling seeded variation. Add return-area secrets only as optional activity hooks; do not reset failed objectives. Use existing spell/environment behavior unchanged.
```

### 13 — Deliver the boss and full defense outcome

**Depends on:** 03, 08–12.

**Implementation:** elapsed active assault time triggers boss arrival after a configurable 5–10-minute test target; it does not win the round. Fight at any held defense, including first wall. Inner locations are harder because space/support is lost, not via changes to current stats or magic. New boss-specific stats/mechanics need isolated provisional config; do not rebalance existing actors. Test animation, navigation and telegraph footprint. Separate regular boss victory from deferred secret victory.

**Done when:** boss spawn is one-time; every valid held location supports counterplay; movement/fallback during boss fight does not stall; boss defeat/final-defense loss have explicit precedence.

```text
Step 13: Implement the timed final assault/boss using the step-03 lifecycle. Use 5–10 active minutes before boss arrival as the initial configurable test target, never automatic timer victory. The boss must reach and fight at any held position, including the first wall. Make later positions more threatening through reduced room and surviving siege support, preserving current balance/magic systems. Place any new boss mechanics/stats in isolated provisional configuration. Add enemy-only presentation and test first-wall hold, inner-position fight, breach during boss, simultaneous boss death/final loss and replay. Keep alternate secret victory explicitly deferred until its rule is selected.
```

### 14 — Add the interim safe room; do not implement world pause

**Depends on:** 03, 07–08; plan the clock implications in step 03.

**Implementation:** one shared use per run, short unilateral service window, capped longer unanimous extension and existing editing access. Confirmed: active spells, outside combat and the mission clock continue. No global time scale, anchoring/freeze workaround or stopped-mission-clock claim. Recommended physical arrangement: an isolated room using existing geometry/protection behavior, no newly added invulnerability, and existing editor access only. Exact location/protection details remain package-level design work.

**Done when:** the chosen interim rules are visible to players, one-use/timeout/readiness cannot be reset, and editing cannot stall others. State clearly that full pause remains deferred.

```text
Step 14: Implement only the clarified interim safe-room rules in this guide/status file. Do not freeze active spells, alter magic clocks, add invulnerability, anchor the world or advertise a full pause. Use one shared service use per run, a short one-player activation and capped longer unanimous window, with existing editing entry points only. Server-own consumption/timeout/votes; handle disconnects, downed players and concurrent requests. Preserve existing editing availability and unlock enforcement. If outside combat/mission-clock/protection rules remain unanswered, prepare the safe-room shell and request the specific missing choice before wiring its behavior; continue independent work.
```

### 15 — Connect the hub and a minimal 1v1 arena

**Depends on:** 03, 08; can start after checkpoint A while later defense content proceeds.

**Implementation:** simple hub destinations, clear defense/arena entry, duel participation/outcomes, leave/disconnect, replay and existing shared XP/currency/win accounting. Use existing combat consent and PvP cap profiles unchanged; scope mutual opponents so spectators/hub players cannot be attacked. Do not create a global PvP flag that allows unrelated duels to cross-damage. Audit whether a room-local match relationship can use the existing policy without magic changes; if not, defer that dependency. New PvP reward schedule requires a separate decision, not invention.

**Done when:** two players can enter a valid duel, play with unchanged custom spells/caps, finish/leave and return safely; defense does not corrupt duel state/rewards. No editing unlock grant changes.

```text
Step 15: Add minimal hub navigation and a 1v1 arena using existing combat consent, targeting policy, stat caps, mode lifecycle and shared progression APIs unchanged. Audit opponent isolation before enabling damage; prevent spectators, hub players and unrelated duel pairs from becoming targets. Implement server-owned enter/leave/start/end/replay and disconnect outcomes, with reward wiring only where an existing approved schedule applies. Do not change magic, PvP cap numbers, unlock rules or invent economy values. If policy isolation needs a protected change, report and defer that seam. Test alongside an active defense round and document integration limitations.
```

### 16 — Expand enemy behaviors, feedback and final art in batches

**Depends on:** checkpoint A; full polish after 10–13.

**Implementation:** fulfill intended roster through enemy-only behavior/content: ranged, shield, flanker, siege breaker, caster, healer, flyer, summoner. Enemy caster/summoner roles must not extend the player magic system; use independent NPC mechanics or defer required shared changes. Add mission/enemy/siege/UI sounds, telegraphs and reactions; leave spell VFX and player magic presentation untouched. Replace graybox with authored assets while preserving navigation and objectives. Record asset provenance and ownership/upload dependencies.

**Done when:** each added role has readable counterplay, valid navigation/objective interactions, performance checks and no magic dependency hidden inside it. Test batches before adding the next.

```text
Step 16: Expand the remaining requested enemy roster in small reviewed batches using NPC-only mechanics, unchanged existing balance and isolated provisional new-enemy settings. Add enemy/mission/siege/UI audio and visual readability, then replace approved graybox areas with final assets while preserving collision and route metrics. Do not reuse a role request as permission to extend player magic runtimes, summons, payloads, spell VFX or resistance rules. Record unavailable assets and protected dependencies honestly. Validate each role's target priorities, tells, counterplay, objective effects, crowd navigation and performance before the next batch.
```

### 17 — Verify the complete loop and produce the tuning handoff

**Depends on:** completed supported steps; list deferred work explicitly.

**Implementation:** solo, two-player and four-player sessions; first-wall hold and forced retreat; shelter losses; panic/alternate routes; courtyard fall; sewer intervention; boss at all positions; deaths/lives; safe-room limits; duel/defense coexistence; rewards/save failure/rejoin; three consecutive rounds; representative existing spells including mobility/constructs/summons. Use existing telemetry hooks for measurable gameplay facts. Classify defects, balance issues and protected magic dependencies separately.

**Done when:** supported scope passes checks, unresolved items are visible, and future balance/magic work has an evidence-based handoff. Do not declare final design complete while full pause/editing grants/downed dependencies remain deferred.

```text
Step 17: Perform the end-to-end gameplay verification matrix from this guide. Run relevant existing suites and the full repository gate where available; use actual Studio solo/two/four-player tests for behavior and a private published experience for persistence. Verify first-wall hold, each fallback/objective, citizens, sewer, boss, recovery, interim safe room, replay and arena coexistence using unchanged existing spells. Report exact evidence and unavailable checks. Produce docs/gameplay-playtest-report.md with defects, observations, performance, protected dependencies and a separate future balance backlog. Do not fix reported damage/scaling weakness by changing any current balance or magic values.
```

## Checks and implementation workflow

1. Before each step, inspect current files/instructions, the status record and relevant diffs. Do not assume concurrent magic work has stopped.
2. Choose the smallest reviewed task, implement it, run focused checks and inspect the diff for forbidden edits. Mixed-responsibility files require reviewing exact changed sections, not just filenames.
3. Use engine-independent tests for objective math, transitions, race conditions, supply accounting and rewards. Use Studio for actual navigation, animation, spell/objective interaction and multiplayer behavior.
4. Build a distinct test output with `rojo build default.project.json -o <new-test-output>.rbxlx`, or use `rojo serve default.project.json`. Do not overwrite the open/locked place. Check tool availability rather than assuming PowerShell supports Bash scripts directly.
5. The current comprehensive gate is `bash scripts/check.sh` in a Bash-capable environment with the repo's tools. Read the script first; if Bash/tools are unavailable, run relevant documented component commands and list what could not run. Existing magic tests may run as regression checks without editing their source/expectations to accommodate gameplay changes.
6. Run the full gate at integrated checkpoints and before final handoff. Compare failures with the step-00 baseline; do not repair unrelated active magic work to make this branch appear green.
7. Stop expansion at review checkpoints to play the build. Calendar estimates follow actual navigation/asset findings; no unsupported week-by-week promise is made here.

## Clarifications still needed

Only the first safe-room choice affects a near-term implementation boundary; other questions can be answered before their package begins.

1. Settled: mission timer and outside combat continue during interim safe-room editing. Active spells are not frozen.
2. Settled: downed state, teammate revives and solo guard rescue are required. An audit must establish how to implement them without magic changes. If a genuine conflict is found, explain the precise protected dependency and request a scope decision; do not substitute immediate death/reinforcement automatically.
3. While form/element unlock changes are deferred, should results simply show existing XP/Marks/wins, with planned editing grants documented outside the live UI? Recommendation: yes, to avoid promising grants the build cannot deliver.
4. Settled: stop after step 08's rampart/shelter/reward loop for the user's playtest before moving to the remaining city.

Life counts, shelter thresholds, citizen counts, control rates, new siege costs, failure reward tuning, safe-room windows, boss test parameters and arena reward rates belong in explicit playtest/configuration decisions. Existing numerical balance stays unchanged throughout this workstream. The original 2–3-hit target remains a future tuning objective, not an acceptance condition for current code changes.
