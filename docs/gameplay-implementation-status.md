# Gameplay implementation status — step 00 readiness audit

**Current status: step 02 procedural enemy animation implemented and tested through client state/joint observations; visible-viewport acceptance is pending because captures are blank.** Step 01 remains validated. See section 12 and [the enemy animation asset/coverage manifest](enemy-animation-assets.md). Historical sections retain earlier evidence and are superseded by later step records. Step 03 has not started.

Audit date: 2026-10-19 (America/Los_Angeles). Repository: `C:\Users\bello\Documents\Projects\Enfleshed`. HEAD: `f298859`, branch `baseline/since-oct-11`.

**Historical step 00 checkpoint: source/readiness audit and engine-independent baseline complete; step 01 had not started at that checkpoint.** At that time only this status document was added. No gameplay source, existing balance, magic, tests, assets or checked-in place files were edited. Temporary build/test outputs were isolated outside the project and cleaned up after the successful run.

Read `gameplay-implementation-guide.md` and `defend-the-walls-gameplay-design.md`. The implementation guide and latest user instructions take precedence over historical proposals in the design document: no magic changes, no existing balance changes, deferred editing/unlock changes, interim safe room with combat/spells/timer continuing, required downed/revive feature, and stop after step 08 for user playtesting. No applicable AGENTS.md was found in the workspace/ancestor directories checked or in the non-archived repository, including hidden paths.

## 1. Evidence and environment

Labels used below:

- **SOURCE:** directly established from current source or saved-place contents.
- **CHECK:** an engine-independent check actually executed in this audit.
- **REPORTED:** prior user play feedback; not reproduced live in this audit.
- **HYPOTHESIS:** a plausible mechanism requiring controlled runtime reproduction.
- **PENDING:** no current execution evidence.

### Studio access and saved place

- No callable Roblox/Studio tool was exposed in this session's tool inventory. A process query returned no `RobloxStudioBeta` process, and the pipeline's expected `%LOCALAPPDATA%/Roblox/mcp.bat` launcher was not found. These checks do not establish what may be running outside the accessible environment.
- `.mcp.json` names a Studio stdio command at `/home/deck/.local/bin/roblox-studio-mcp`; that is not a callable Windows Studio connection here. The existing `tools/vfx_pipeline/studio_mcp.py` bridge itself has unrelated local modifications and was read, not run or edited.
- **No live Studio observations were made.** No mission was started, no NPC was spawned, no character was killed, no saved rewards were tested online, and no multiplayer session was run.
- The existing `Enfleshed-Defend-The-Walls.rbxlx` is 32,419,312 bytes and has a `.lock` file. Neither was modified. A lock file alone does not establish an active Studio session.
- Read-only XML inspection found saved-place source equal to current source (normalizing line endings) for these seven modules: EnemyService, ModeRunner, DamageService, DefendTheWallsService, Sandbox configuration, DefendTheWalls configuration, and UIController. This is a limited comparison, not proof that the entire place or any running experience matches source.
- The saved place contained no hierarchy node named `EnfleshedModels`. `EnemyService.importedParts` expects `ServerStorage/EnfleshedModels/<Kind>`; absence leads to generated placeholder visuals in this saved artifact. This does not prove templates are absent in some other Studio/published place. `assets/enemies/README.md` describes the manual import; raw GLBs are not automatically loaded by Rojo.

### Tools and checks

Available: Rojo 7.7.0, StyLua 2.5.2, Luau binary under `.rokit` tool-storage 0.742.0, Python 3.12.10 and Git. Bash/python3 were not resolved by Get-Command, and the checked standard Git Bash locations were absent. The entire `scripts/check.sh` gate was therefore not executed as a Bash command.

Initial baseline invocation encountered inaccessible sandbox temp output and Windows cp1252 decoding errors. These were environment failures, not evidence of gameplay defects. The successful rerun used:

- `python -X utf8 -B ...` (and `-I` for standalone Python test scripts);
- an isolated `TemporaryDirectory` under the writable visualization root;
- `TEMP`/`TMP` pointing there for child harnesses;
- `ENFLESHED_PLACE_FILE` pointing to a newly built temporary `audit.rbxlx`;
- no overwriting of the repository place, no formatting writes and no test-source changes.

The successful rerun completed **19 checks: 18 passed; formatting failed**.

| Check | Actual result | What it proves / does not prove |
|---|---|---|
| Rojo build to isolated temporary output | PASS | Current source can be packaged; does not execute game physics/scripts |
| StyLua `--check src tests` | FAIL | Existing formatting differences in 14 VFX-related files; no files formatted |
| `test_defend_the_walls_map.py` | PASS, 8 tests | Map packaging/current structural wiring, not actual AI traversal |
| `test_mode_framework.py` | PASS, 4 tests | Current lifecycle/message/source contracts, not live round behavior |
| `test_combat_battle_map.py` | PASS, 2 tests | Practice-map structural checks |
| `test_place_references.py` | PASS, 5 tests | References in the fresh temporary build |
| `test_shutdown_rewards_wiring.py` | PASS, 3 tests | Shutdown reward wiring, not online durability |
| `test_telemetry_wiring.py` | PASS, 3 tests | Analytics wiring/guard contracts |
| `test_ui_kit.py` | PASS, 4 tests | Current UI/input wiring contracts |
| `test_module_boundaries.py` | PASS, 2 tests | Existing extraction boundaries |
| `test_stat_caps_wiring.py` | PASS, 3 tests | Existing cap wiring; caps unchanged |
| `defend_the_walls_layout_spec.luau` | PASS | Current seeded layout invariants |
| `combat_policy_spec.luau` | PASS | Co-op consent/open-zone/mutual-duel and hostile-payload policy |
| `profile_session_spec.luau` | PASS | Profile lock/create/takeover/release/corrupt cases |
| `telemetry_spec.luau` | PASS | Pure telemetry aggregation/contracts |
| `feature_flag_spec.luau` | PASS | Flag/window/kill-switch rules |
| `run_luau_unit_tests.py` | PASS, 69/69 | Standalone snapshot-based unit tests, including existing tuning/Nascent contracts |
| `run_luau_inventory_tests.py` | PASS | Inventory model suite |
| `run_luau_ui_tests.py` | PASS | Library-layout UI suite |

The nine Python scripts above contain 34 passing tests in total. Suite/check counts are distinct from individual assertion counts. The full Python/VFX/magic suite matrix in `scripts/check.sh` was not run; this is a relevant baseline, not a claim that the entire repository gate is green. Some VFX tests invoke asset-pipeline generation, which is outside this read-only audit.

Formatting failures: `src/client/Controllers/SpellVFXController.luau`; `src/shared/SpellVFXSystem/Assets/{StyledVFXManifest,ConnectedFirePoses}.luau`; `src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau`; `src/shared/SpellVFXSystem/Signature/{ArcBeam,ConnectedFire,DirectionalSprite,PathGlyphs,FieldDynamics,SignaturePlanner,SignatureKits,StreamBeam,SignatureRenderer}.luau`; `tests/spell_vfx_signature_spec.luau`. These are baseline findings, not work for gameplay step 01.

## 2. Working-tree ownership and protected scope

Before adding this file there were **18 tracked modified files and 513 untracked files** (`git status --porcelain=v1 -uall`). Most untracked content is VFX studies/assets/scripts/tools; the three planning documents are also untracked. Do not infer that an untracked file is disposable.

Tracked modifications observed and preserved:

- `.gitignore`;
- `assets/vfx/studies/3d_fire_v4/{README.md,STUDIO_IMPORT.md,manifest.json,published_assets.json}`;
- `docs/{spell-vfx-assets.md,stylized-3d-fire-prototype-plan.md}`;
- `scripts/{studio_connected_fire_all_cleanup.luau,studio_connected_fire_world_check.luau}`;
- `src/client/Controllers/SpellVFXController.luau`;
- `src/shared/SpellVFXSystem/Assets/VFXAssets.luau`;
- `src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau`;
- `src/shared/SpellVFXSystem/Signature/{SignatureKits,SignaturePlanner,SignatureRenderer}.luau`;
- `tests/{spell_vfx_signature_spec.luau,test_spell_vfx_signatures.py}`;
- `tools/vfx_pipeline/studio_mcp.py`.

Representative diffs were read: renderer/controller work changes connected fire, beams, field presentation, texture/style selection and effect lifecycle; the Studio bridge adds connection-wait handling. None is part of this audit or permission for gameplay edits.

### Protected files and behavior

Read-only throughout this gameplay workstream unless scope changes explicitly:

- `src/server/Services/Magic*.luau`, `SummonService.luau` and magic-specific runtime helpers;
- spell authoring, Grimoire, MagicController/MagicLabController, generated spells, aerial magic and spell VFX client code;
- `src/shared/SpellVFXSystem/**`, `src/shared/Configuration/{Magic*,Spells,SpellProgression,SpellStatCaps,GeneratedSpellStress}.luau`, and magic/spell/grimoire modules/types;
- magic action names, protocol behavior, definitions, starters, unlock/rank/cost/budget rules, mana/strain, caps and existing saved libraries;
- related VFX assets, pipeline tools, tests and ongoing working changes.

Do not "fix" these to make the gameplay baseline pass. Running unchanged regression checks is allowed; changing expectations or generated assets is not.

### Mixed-responsibility interfaces

| Interface | Gameplay use / exact boundary |
|---|---|
| `Configuration/Sandbox.luau` | Enemy navigation/hull settings are candidate step-01 surfaces; enemy stats, scheduler limits and player/magic/resource/camera/combat values remain frozen. Review exact changed keys, not just the filename. |
| `DamageService.luau` | Central melee/spell/summon damage, shield absorption, caps and mission-gateway rules. Existing apply APIs may be consumed; any new pre-lethal seam needs deliberate shared-contract review. Do not change amounts, caps or magic execution. |
| `Networking/ActionRouter.luau` | Character readiness, spawn routing and movement anchors coexist with casting, equipment and resource reset. Limit future edits to explicit gameplay spawn/incapacitation seams; avoid resetting/changing magic. |
| `MissionProgression.luau` | Existing commit/cache/load APIs support rewards; clean/purchase logic also owns magic Unlocks/SpellRanks. Do not alter schema cleaning, purchases or grants casually. |
| `PlayerProfileService.luau` | Shared inventory/progress session store, lock/save/shutdown ownership. Reuse; do not fork persistence or erase existing fields. |
| `UIController.luau` / HUD | Mission/lobby/result panels coexist with spell bar and unlock display. Update mission components only when their step is authorized. |
| `CombatPolicy`, stat caps, target tags | Shared targeting/consent used by spells and melee. Consume existing policy; do not globally enable PvP or modify magic targeting to fit objectives. |
| `init.server.luau`, `init.client.luau`, `default.project.json` | Shared bootstrap/remotes and place structure. Gameplay registration can eventually be narrow; do not change protected remote semantics or unrelated services. |

## 3. Current service and UI map

| Area | Current files and source behavior |
|---|---|
| Bootstrap | Server init creates remotes first, then starts flags, telemetry, profiles, EnemyRuntime, ActionRouter, DefendTheWallsService and CombatSandboxService with guarded startup. Client init starts launcher/camera/UIController and combat/magic/inventory controllers. |
| Round lifecycle | `Services/ModeRunner.luau`: participants/max size/late join, state messages, finish, reward commits, results delay, replay queue, abandonment and shutdown participation rewards. No public objective transition, downed or reinforcement controller. |
| Defense mission | `DefendTheWallsService.luau`: three lane choices, timed phases/budgets, active wall integrity, breach/retarget/fallback, repairs, guards, final-door defeat and timer victory. |
| Mission map | `Modules/DefendTheWallsLayout.luau`, `Services/DefendTheWallsMap/{init,Kit,Village,Corridors,Walls,Baileys,Gate,Lighting,Props}.luau`. Seeded data separated from world construction. |
| Practice map | `CombatSandboxService.luau`, `MapGenerator.luau`, `Configuration/CombatBattleMap.luau`. Separate from mission map; practice access prompt lives in defense staging. |
| Enemies | `EnemyRuntime.luau` schedules Heartbeat updates and bounded path jobs. `EnemyService.luau` creates rigs/hulls, selects attacks/targets, navigates and writes poses. `NascentAttackSelector.luau` selects current attacks. |
| Guards | `DefendTheWallsGuards.luau`: spearmen/crossbowmen, fixed posts, MoveTo chase/retreat, fallback teleport after arrival/timeout, no revive/search-rescue behavior. |
| Damage | `DamageService.luau`: `apply`, `applyMelee`, post-damage `Applied`. Shared status/defense/cap calculations; no cancellable/pre-lethal public hook. |
| Character spawn | `ActionRouter.characterAdded` uses MissionDefender and Workspace.DefendTheWalls.DefenderSpawn; otherwise practice/hub. Initializes existing health/speed and magic attributes. |
| Rewards/profiles | `MissionProgression.luau`, `PlayerProfileService.luau`, `Modules/ProfileSession.luau`: session-owned progress, receipts, retry/rollback, shutdown flush. |
| Mission client | `Controllers/UIController.luau:47` listens to MissionRemote; MissionResult at 108 and MissionState at 110. `UI/HUD/{Lobby,MissionTracker,WorldUI}` provide current lobby/results/objective warnings. M/D-pad up toggles lobby. Old MissionController/HUDController paths are not current entry points. |
| Existing editing access | `GrimoireLauncher.start()` returns Open/Bind; HUD uses the launcher's Open method. Reuse through the existing client wiring later. No safe-room service, gameplay editing entitlement or full-pause API exists. |

## 4. Frozen balance/configuration snapshot

These are source values, not measured live outputs. Mission enemy values override generic Enemy settings after construction. Do not mistake `Sandbox.Enemy.Health = 180` for mission Basic HP.

### Defense and waves

| Setting | Current value |
|---|---|
| Preparation / active / results | 20 / 600 / 12 seconds |
| Maximum participants | 4 |
| Wall pools / final doors | 650, 800, 950 / 1000 HP |
| Repairs | 2 shared charges, 180 restoration, configured range 12; server allows range +2 |
| Stuck removal | 32 seconds without >5 studs position change, if >13 studs from current objective |
| Seed / branch chance | 1693 / 0.3 |
| Gateway role damage scales | Basic .25; Swift .2; Brute .65; Elite 1.1 |
| Studio acceleration | false; accelerated duration 120; MockProgression true only applies when acceleration is active |

| Phase time | Interval | Target alive | Base cap | Spawn budget | Open lanes |
|---|---|---|---|---|---|
| 0 | 7 | 3 | 9 | 65 | 1 |
| 120 | 6 | 5 | 10 | 65 | 1,2 |
| 240 | 5.5 | 6 | 10 | 65 | 1,2,3 |
| 360 | 5 | 7 | 10 | 80 | 1,2,3 |
| 510 | 4.5 | 8 | 11 | 55 | 1,2,3 |

Party formulas: cap adds `4*(party-1)`, target adds `3*(party-1)`; spawn interval is 2 seconds below target, otherwise phase interval divided by `1 + .2*(party-1)`. One Elite is admitted from phase 4 when capacity/budget permit. No boss.

### Enemy and traversal

| Mission kind | HP | Walk speed | Model scale |
|---|---|---|---|
| Basic | 160 | 18 | 1 |
| Swift | 115 | 22 | 1 |
| Brute | 260 | 13 | 1.25 |
| Elite | 440 | 13 | 1.5 |

Generic Enemy defaults: 180 HP, speed 18, detection 36, disengage 64, think interval .1, desperate fraction .35. Current attack damage/timing:

| Attack | Damage | Telegraph / active / recovery |
|---|---|---|
| RushingStrike | 18 | .28 / .16 / .30 |
| FrenziedChain | 10 per hit, 4 hits | .18 / .13 / .85; .10 step gap |
| PredatoryLunge | 30 | .65 / .24 / .40; miss recovery 1.15 |
| MaulingCombination | 12,12,24 | .13 / .12 / .62; .12 step gap |
| ReversalSwipe | 15 | .16 / .12 / .40 |

Desperate recovery multiplier .72; flinch minor 0, significant .18, major .52. All attack range/travel/turning/hitbox values in Sandbox remain frozen as well.

Hull height 9, diameter 2.8, center offset Y 1.5, friction 0; R6 Humanoid HipHeight 0. Agent radius 2, height 9, can jump true, waypoint spacing 3; repath .75 seconds, target move threshold 5, waypoint tolerance 2, stuck time 1.25, progress distance .75. Direct sweep size `(2.8,8.5,2.8)`.

Shared scheduler values come from StressTest even when the stress harness is disabled: enemy collisions true; hit query 30 Hz; path starts 4/second; at most 2 paths in flight; corpse lifetime 2. Do not change budgets to conceal navigation failure.

### Guards, player, resources and progression

- Guards per wall: 4/2, 3/3, 2/4 spearmen/crossbowmen; maximum 18; think .3 seconds, retreat timeout 14. Spearman: HP 240, damage 16, range 7, cooldown 1.3, leash 24, speed 15. Crossbowman: HP 150, damage 20, range 85, cooldown 2.4, speed 14.
- Player health 400 (explicitly temporary stress-test tuning), walk 16, sprint 28, dash 14 studs/.18 seconds/.8 cooldown; block movement multiplier .5. No mission downed-life configuration exists yet. Actual automatic health regeneration/engine respawn settings were not measured; do not infer them from the desired slow-regeneration design.
- Protected resource config: starting mana 300; combat regen 10 mana/second, strain recovery 4/second, safe demand 45, safe strain 18; practice regen 30, strain recovery 8, safe demand 35, safe strain 18. MagicLocus Combat capacity 300, efficiency/potency 1, tolerance 100, complexity capacity 26. These are read-only profile/config values, not measured per-cast costs.
- Existing recruit sword light damage 24/26/30, heavy 52; item health consumable Heal 35, UseCooldown 1.5. Preserve all other melee/item/loot balance in their source configs; do not retune this workstream.
- Base reward values: victory 120 XP/50 Marks, defeat 30 XP/10 Marks; configured BonusXP 20/BonusMarks 10. Actual formula in DefendTheWallsService: `bonus=clamp(floor(Damage/500)+3*Repairs+Kills,0,10)`; `participation=clamp(timeJoined/(Duration*.5),0,1)`; XP `floor((baseXP+2*bonus)*participation)`, Marks `floor((baseMarks+bonus)*participation)`; score `floor(Damage+25*Kills+100*Repairs)`. Config bonus fields are not read by this formula. No economy changes authorized.
- Existing slots: 4 initially, 6 at 500 XP, 9 at 1800 XP. Existing unlock offers AdvancedForms 250 XP/80 Marks; AdvancedBehaviors 600/140; AdvancedEffects 1000/200; VisualCraft 350/60. Rank prices 100/200/350; rank XP 0/450/1200; mana limits 45/70/105/160, strain limits 25/40/65/100, complexity 8/12/17/26. Preserve these, not new form/element grants.
- Current PvE cap profile is empty/identity; PvPOpen damage multiplier .6/max hit 35; PvPRanked .5/max hit 30. All other existing cap limits stay unchanged. For eventual 1v1, mutual DuelOpponentUserId is an existing opponent-specific seam; a shared PvPZone string alone also enables damage between unrelated players in the same zone category.
- DevelopmentSandbox.Enabled true; generated spell stress enabled for development sandbox, seed 12345/count 10; population stress harness false. Do not toggle development flags during this audit to claim live progression validation.

The 2–3-hit starter-spell target is REPORTED desired future tuning, not a checked measurement. No cast sequence or damage output was observed here, and no balance was changed.

## 5. Problems and reproduction record

No issue below is labeled live-reproduced in this audit. For normal baseline play, prepare for 20 seconds and up to 600 active seconds. Current debugFinish/debugDamage/debugBreach require Studio + accelerated mock mode, which is presently off; do not quietly edit config to use them. `debugWave` is Studio-only but mutates the simulation and was not invoked. `scripts/studio_dtw_perf.luau` spawns a wave, so it is not a read-only inspection script.

### N01 — Raised-ground navigation failure

**REPORTED:** enemies get stuck on raised terrain. **SOURCE:** EnemyService:636–750 already computes paths, reacts to blocked paths and performs waypoint jumps. Step 01 must reproduce the precise obstacle/body combination before choosing a fix.

Reproduction plan: start a source-synced test place; lure each mission kind across shallow raised edges, stairs, ramps, corners and doorways; repeat with a same-height target, a target on elevation and multiple enemies. Record model scale, hull transform, agent/sweep dimensions, Humanoid state/grounding, waypoint action/index, direct/path branch, queue delay and stuck counters. A fixture/instrumentation belongs to step 01, not this audit.

Concrete source candidates:

1. **Vertical waypoint completion:** EnemyService:734–746 advances waypoints using only XZ distance before checking Jump action. A static control-flow trace with horizontal distance 0, vertical difference 4 and tolerance 2 satisfies the reached predicate and advances the waypoint. This is a deterministic source-path observation, not a physical reproduction. Test whether elevated/jump waypoints are skipped on the failing route.
2. **Scaled hull versus unscaled agent/sweep:** model scale is applied after Enemy.create in DefendTheWallsService:229; nav/sweep remain shared config. Expected scaled hull heights are 11.25 (Brute) and 13.5 (Elite), versus configured agent height 9; Elite hull diameter 4.2 versus agent diameter 4. Live measurements must confirm effective scaling/clearance. This mismatch is a hypothesis for larger-body failures, not proof for Basic failures.
3. **Direct chase decision:** EnemyService:712 onward blockcasts a configured sweep then chooses direct MoveTo; test shallow rises and whether direct mode repeatedly suppresses the necessary path/jump. Do not assume the sweep proves floor continuity.
4. **Grounding:** a tall cylinder is the colliding hull while visual limbs do not collide; HipHeight is 0. Inspect actual ground contact/root height rather than increasing speed or jumping globally.
5. **Failure masking:** mission code destroys immobile, distant enemies after 32 seconds and increments StuckRemoved (DefendTheWallsService:285). A later empty lane is not proof that enemies successfully navigated it.

### A01 — No visible enemy animation

**REPORTED:** enemies appear unanimated. **SOURCE:** Motor6D joints and procedural Transform assignments exist at EnemyService:243–318 and are updated at 768/829. No authored Animator/Animation track playback or client enemy-pose controller was found in inspected current runtime. Thus “no animation code exists” is incorrect; visible execution/replication remains unverified.

Reproduction plan: observe the same enemy from server and client views during chase, anticipation, strike, recovery, flinch and death; check actual joint output on placeholder and imported rigs. Confirm template availability before attributing appearance to assets. Do not change attack timings or magic/player animations. Step 02 addresses this after traversal.

### O01 — Existing mission does not implement the new objectives

**SOURCE:** current layout is spawn village/crossroads/three lanes → three walls → final doors, not the designed interleaved four-wall city. There are no separate shelter objective pools, moving citizens/panic routes, courtyard occupancy bar, controllable sewer routing, player siege emplacements or safe-room service. Static village houses are not protected-resident objectives.

Reproduction plan: inspect a normal defense's objective HUD/targets and the world hierarchy; damage active gates and observe wall progression. Only final doors lose the current mission. Compare against the desired district sequence. These are feature gaps, not a claim of broken existing wall code.

### O02 — Timer wins rather than introducing a boss

**SOURCE:** ModeRunner:315 calls finish(timeoutOutcome) at EndAt; defense sets timeoutOutcome true at DefendTheWallsService:352. An Elite is a scaled existing enemy, not a boss phase. Boss arrival needs a separate event/state before implementing its content.

Reproduction plan: let a normal run reach its end with final doors surviving; expect existing timer victory, not a boss. Source-determined expectation; not executed in this audit. Outcome is checked before timeout, so a detected final-door failure wins that ordering.

### D01 — No downed, life or reinforcement rules

**SOURCE:** ModeRunner:322 only observes Humanoid.Died and increments Deaths. No downed state, revive prompt/handler, life accounting, rescue timer or wall-fall/timer reinforcement policy exists. Guards expose spawn/retreat/clear/alive/total, not rescue. Their MoveTo retreat can PivotTo the post after arrival/timeout (Guards:194), so an apparently successful retreat is not proof of successful path traversal.

Reproduction plan: receive lethal damage during a mission and inspect death count/character lifecycle; then breach a wall. There is no source path authorizing revive or wall-triggered reinforcement. No CharacterAutoLoads/RespawnTime override was found, so actual engine/place automatic respawn behavior must be measured, not described as the requested timer policy.

### R01 — Rewards and replay need verification, not replacement by assumption

**SOURCE/CHECK:** existing commit receipts, retries/rollback, profile locks, saved-result flag, shutdown participation reward and replay queue are wired and relevant structural tests pass. No confirmed runtime duplication/data-loss bug was reproduced. No complete healing/CC/defense contribution stream was found in the inspected reward interface; current counters are Damage/Kills/Repairs/Deaths.

Reproduction plan for a private published test: win, record result/XP/Marks/receipt, rejoin and compare; repeat defeat with banked progress; queue Replay during rewards; select Hub; repeat three rounds and check old enemies/guards/prompts and mission IDs. Test save failure and duplicate finish with a controlled test harness. All remain PENDING; mock/local tests do not prove DataStore durability.

Replay source at ModeRunner:247 cleans mode content, reloads participants, clears the table, enters READY_FOR_REPLAY and starts the next run for queued players. It is not an absent system. New objectives will need explicit reset coverage.

## 6. Can existing public interfaces support downed interception?

**Answer: no existing pre-lethal public interface was found. This does not yet prove that magic implementation files must change.**

Evidence:

1. DamageService exports only apply, applyMelee and Applied. It calls Humanoid:TakeDamage at line 68, computes killed, then emits Applied at line 73. Applied is a notification after damage, not a cancellation/interception contract. It cannot reliably preserve a living downed character before lethal damage.
2. Enemy claws (EnemyService:895), player melee (CombatService:174), direct payload damage (MagicPayloadExecutors:403), periodic spell damage (same file:87) and summon attacks (SummonService:774) use that shared damage service. The repository search found no second direct TakeDamage call in server source. Actual engine/environment death and out-of-world cases still require separate policy.
3. Magic/status/summon code has Died/death callbacks and Health<=0 checks. Trying to turn a post-Died character back into an ordinary live one would have already triggered cleanup/target-death effects; do not use post-hit healing or a shield/ForceField trick as downed interception.
4. Keeping a Humanoid alive while downed also requires a gameplay incapacitation policy for movement, melee, interactions and casting. ActionRouter currently rejects dead characters, not a mission-owned downed state. Existing spell lifecycle behavior while downed must be reviewed without editing magic just to hide inconsistencies.

Candidate for later step-07 design: a mission-scoped, default-no-op pre-lethal decision seam in the **shared DamageService**, preserving existing damage/defense/shield/cap calculation and all non-mission behavior, with mission-owned downed/dead/revive state. This would be a new interface, not use of an already available API. It could avoid edits to individual spell implementations, but it changes shared lethal-hit behavior deliberately and needs source-path and mode-isolation tests. No such hook was added here, and compatibility with the strict no-magic-behavior-change boundary is not established merely by proposing it.

Step 07 must bring a concrete design/evidence if that shared boundary cannot remain in scope. Required downed, teammate revive and solo guard rescue are not optional; immediate death/reinforcement is not an approved replacement. This dependency does not block step-01 navigation work.

### Other audited seams

- **Safe room:** existing launcher can open the existing editor. No full pause API; active spells, mission clock and combat must keep running in the authorized interim design. Do not modify magic clocks or unlocks.
- **Rewards:** reuse Progression.commit and existing profile service; preserve Unlocks/SpellRanks and existing formulas. Additional form/element grants are deferred. Existing XP-driven slot behavior continues unchanged.
- **Support credit:** Damage.Applied carries damage/killed/context, not a universal effective-heal/CC/protection assist feed. Do not fabricate accurate attribution or modify magic payload metadata in this workstream.
- **Arena:** mutual duel attributes already provide opponent-specific consent; retain existing caps. Implement match ownership/cleanup later rather than editing magic targeting or making all players in a generic Open zone mutually attackable.

## 7. Preservation verification

SHA-256 aggregation was captured before creating this document, sorting Git-listed tracked and nonignored untracked file paths, then hashing each path plus its content digest. The same groups were checked after the audit. Counts exclude ignored files; this is preservation evidence for the current source/assets, not a Git cleanliness claim.

| Group | Files at baseline | Baseline SHA-256 |
|---|---|---|
| src | 262 | `260b97fab86e395c7402129f8b0955ed5c74b44e5bbc6934758ee250b0fb3688` |
| tests | 114 | `3490d3989c18a197d0532e681472ec15a4797c596fbeb0986d2c04821c379571` |
| scripts | 79 | `091fa2acb16025d3c577906e53bf17329604a101016793f1d14e7afcaca50278` |
| tools | 96 | `a859ef62e26a54cb52fb852ea28191ad59d81935343538e06922fc1d34101f31` |
| assets | 2107 | `473c67cc5f137263a3e1d31b802881f324e9b0194727d0557dc67720e6b461f8` |
| Prior docs, excluding this new status file | 33 | `5c2310f937757529fea450f413bd98c8d9d46549a3ed986990f20a6a7858e16b` |

Existing place SHA-256: `c89a0406bb062389527f1c683bd6c6dfbf397668fdf239d7ca455e7561c29beb`. Existing project configuration SHA-256: `9c0c84a6c4b58f44c8de7ddb6ea7af62552cdc517e11420b707056ed8792b9ed`. No stage/commit/reset/cleanup of user work was performed.

## 8. Evidence-based step-01 task list

1. Recheck current working changes and this baseline. Leave protected magic/VFX, existing combat stats and scheduler caps untouched. Read any newly added repository instructions.
2. Establish a callable source-synced Studio session or document the runtime limitation. Preserve the existing place/lock; use an isolated test artifact or a deliberate serve workflow. No claim of a live fix without a live reproduction.
3. Add a development-only traversal fixture with flat ground, shallow rises/curbs, stairs, ramps, slopes, corners, doorways and temporary blockers. Keep obstacle dimensions/seed recorded; avoid production-map edits as a substitute for diagnosis.
4. Exercise Basic, Swift, Brute and Elite separately and in crowds. Use current speeds/health; record actual scaled hull bounds, root height, grounding, agent/sweep size and waypoint positions/actions. Keep target positions repeatable.
5. Instrument the branch between direct chase and path following, queue/computation delay, waypoint advancement, blocked signals and stuck recovery. Record StuckRemoved; disappearing enemies do not count as traversing successfully.
6. First investigate the **XZ-only reached predicate before Jump handling** using a target/waypoint at nearly the same XZ but different Y. Add a focused pure regression if a helper is extracted. Do not blindly replace all distance checks without understanding standoff behavior.
7. Investigate the **post-construction model scale versus fixed agent/sweep** using low-clearance and narrow passages. Decide a geometrically correct per-model navigation representation only after measuring actual hulls; do not resize health/speed or alter magic transformations to fit a path.
8. Check **direct-sweep floor continuity and hull grounding** on small rises. Isolate the root cause for Basic as well as larger enemies. Only then make the smallest navigation/collision correction.
9. Repeat target movement, blocked/unblocked routes, close melee standoff, crowding, new spawn and cleanup. Preserve 4 path starts/second, 2 in flight, current hit-query behavior and existing combat timings.
10. Run targeted tests plus the existing 69-unit baseline and relevant map tests using UTF-8/writable temp settings. Leave unrelated formatting failures recorded. Add actual Studio evidence and update this status file with the reproduced cause, exact fix, supported terrain and remaining failures.

Step 01 exit: repeatable runtime traversal succeeds on the supported fixture with all current mission sizes, without balance/magic changes, hidden deletion-as-success, or uncontrolled path-budget growth. Then proceed to step 02 animation visibility. Downed-state design remains tracked for step 07; user playtest remains mandatory after step 08.

## 9. Step 01 — navigation changes and verification

Historical source-only checkpoint, 2026-10-19. **Superseded by the live validation in sections 10–11.** At this earlier checkpoint the exposed inventory/process query did not reveal Studio, and the launcher was searched under redirected LOCALAPPDATA. That was an access-detection mistake: the native MCP bridge and connected Studio were recovered later. The pending-runtime statements, preliminary dimensions and next-action instructions below describe this historical checkpoint only.

### Files changed

| File | Work |
|---|---|
| `src/server/Services/EnemyService.luau` | Navigation integration, hull-based clearance/sweep, floor/jump advancement, conservative direct chasing, on-demand diagnostics |
| `src/shared/Modules/EnemyNavigation.luau` | New pure geometry/waypoint/direct-chase decisions |
| `src/server/Development/EnemyTraversalFixture.luau` | New Studio-server-only opt-in fixture; never imported by normal bootstrap |
| `tests/test_enemy_navigation.lua` | New pure and production-chase regression cases; service/fixture syntax compilation |
| `docs/enemy-navigation-verification.md` | Setup, matrix, diagnostics, limitations and actual runtime acceptance instructions |
| This status file | Step-01 record; original step-00 evidence retained |

### Reproduced logic and changes

1. **Elevated waypoint accepted on horizontal distance alone.** A waypoint four studs above the current floor at the same X/Z was eligible for advancement in the old predicate. The regression now retains that waypoint until the hull-bottom-derived floor position reaches the appropriate height within the existing tolerance. Actual production chase code is exercised with controlled vector/sweep dependencies; this is controller-level reproduction, not engine physics.
2. **Jump action could be skipped.** An unissued Jump waypoint at the current X/Z is retained until its action is issued. Issue once when near takeoff and grounded; do not mark an airborne attempt as issued. An issued takeoff can be consumed while rising so it does not strand the actor above its old floor. Landing/walk points still check height. Regression cases cover approach distance, single issuance, airborne retry and subsequent waypoint advancement.
3. **Body scaling versus navigation bounds.** Enemy navigation now reads the actual upright cylinder hull after mission ScaleTo. Preserve the configured clearance margin at that scale and round dimensions upward to CreatePath integer clearances. Expected current agent radius/height: Basic/Swift 2/9, Brute 3/12, Elite 3/14. Scaled sweep dimensions/center follow the body; hull changes invalidate old routes and stale compute results.
4. **Clear sweep bypassing elevated pathing.** Direct chasing remains available for clear, near-level targets, but no longer cancels a needed jump or treats a vertically displaced target as ordinary flat walking. Existing close melee standoff is retained. No speed/attack change or general floor-continuity probing was introduced.

Navigation diagnostics report actual hull/sweep/agent geometry, root/hull-bottom positions, FloorMaterial/Humanoid state, waypoint index/action/position, issued jump index/count, current direct/path/wait mode, queue age/wait, compute duration/status/failures, blocked paths and stuck recoveries. They are queried on demand; no debug remotes or extra per-frame replication.

### Fixture and runtime reproduction plan

The dormant module runs only when explicitly invoked from a Studio server. It creates isolated lanes around `(2000,100,2000)`, outside current gameplay areas, without modifying the mission map. Cases: Flat, Curb, RaisedEdge, Stairs, Ramp, Slope, Corner, Doorway, LowClearance, BlockedPath and MovingTarget. Each selected current enemy kind runs alone, then a crowd uses two of each selected kind. Default full matrix: 55 trials, up to 30 seconds each, early finish on actual region/floor-height completion.

It uses real EnemyRuntime and current mission HP/speed/model-scale values in test actors. Shared limits remain 4 path starts/second, 2 in flight and 30 Hz hit queries. Target movement and temporary blockers exercise path invalidation/recovery. Actors are not teleported. Timeouts/deaths are logged as failures before explicit trial teardown, and no mission StuckRemoved cleanup is used. Teardown keeps completed trials from occupying the shared budget and is not a recovery strategy.

The fixture has not been physically validated yet. Its compile success does not prove contact behavior, path baking, panic-free crowd behavior or that its scenarios are all traversable. Keep observing player characters outside test actors' detection range; existing target selection was deliberately left unchanged. Preserve failing samples and refine test geometry/controller behavior from actual evidence.

### Automated checks actually run

All 12 relevant checks passed after the initial implementation:

- Focused StyLua check on the four navigation code/test files.
- Fresh isolated Rojo build; repository place/lock not overwritten.
- **70/70 standalone Luau tests** (the prior 69 plus the new navigation suite).
- `test_defend_the_walls_map.py` (8), `test_mode_framework.py` (4), `test_place_references.py` (5), `test_module_boundaries.py` (2), `test_stat_caps_wiring.py` (3), `test_shutdown_rewards_wiring.py` (3).
- Layout, combat-policy and profile-session Luau specs.

Following the added airborne-jump regression, the focused navigation suite passed again, and final formatting, 70/70 standalone tests and a fresh temporary build all passed against the final source. These checks cover floor/jump logic, scaled integer clearances, actual production chase wiring, preserved flat direct movement/standoff, stuck-recovery request admission, and syntax of Roblox-facing code. They do not cover actual ComputeAsync/contact/animation replication.

The existing full-repository VFX formatting baseline remains outside this change. No tests/formatting expectations were changed to hide unrelated failures. The full magic/VFX suite matrix was not rerun; all protected files are preserved instead.

### Scope preservation and remaining limitations

- No magic, spell, VFX, animation, progression/unlock, damage, health, speed, attack-timing, resource, map, bootstrap or scheduler configuration was edited. EnemyRuntime and DefendTheWallsService remain unchanged. No existing place file was rebuilt or saved.
- Before edits, a sorted path/content hash was captured for **2,697 existing files outside the six intended navigation/doc paths**, including untracked user work. Baseline aggregate: `74d9c13acb517036805735b16e3aed0f15f47cb9d02af83a9a8a1d00aba21985`. The final count and digest matched exactly, verifying preservation of those existing files, including protected systems/configuration and the repository place.
- Grounding/HipHeight/friction are intentionally unchanged because no live root cause was reproduced. Scaled clearance is a source/geometry correction, not certification that larger agents traverse every existing map gap.
- No current course can yet be certified as physically supported; all live obstacle/crowd/moving-target tests remain pending.
- Existing enemy attack lunges and production stuck-enemy removal are unchanged. Fixture success does not measure combat balance or imply production stuck-removal is now unnecessary.

### Exact next action

Open a separate source-synced Studio session and run the focused fixture subset in `enemy-navigation-verification.md` with all four kinds. Inspect first/last/transition samples for any failures, then run the full 55-trial matrix. Record grounding, paths, queues, clearance and recovery before making further changes. Correct any reproduced residual failures inside step 01. **Do not proceed to step 02 animation work or rebuild the production map.**

## 10. Live Studio follow-up after connection correction

This section supersedes section 9's pending-Studio limitations and preliminary body dimensions. Section 9 records the earlier source-only stage; use the final live results below for current completion status.

Date: 2026-10-19. The user correctly reported Studio MCP connected. The exposed tool inventory had no Studio namespace, the sandbox hid the process, and LOCALAPPDATA pointed into a sandbox package. The actual launcher exists at `C:/Users/bello/AppData/Local/Roblox/mcp.bat`. The repository bridge initializes inside the sandbox but returns no tools; using the real launcher directory and approved execution outside the sandbox exposes 28 tools and the connected Studio `e14a69e7-cf61-43b3-b9f2-e1bcef8724f9`, `Enfleshed-Defend-The-Walls.rbxlx`. Allowing reconnection time is necessary for reliable calls.

### Session integrity

Initial Studio state was Edit. Read-only comparison established that the live EnemyService source matched the audited HEAD version, not the navigation fix, and that navigation helper/development fixture modules were absent. Only EnemyService, the new EnemyNavigation module and the new fixture were temporarily staged; no save or publish operation was invoked. Protected live magic/VFX content was not synchronized or overwritten. These temporary Edit changes must be restored at the end of verification, preserving unrelated place work.

### Actual grounding failure and controlled experiment

First live run `6e43f4c8-aa15-4d4a-b620-292731493d57` used the earlier navigation patch. Flat courses reached their finish but all sampled enemy kinds still reported Freefall/Air. Basic then timed out at the four-stud rise: root approximately `(2038.586,102.964,2122.855)`, computed jump waypoint `(2041,104,2122.5)`, zero jump requests, 10 path requests and 9 stuck recoveries after about 30 seconds. This was a real physics/controller failure, not a source-only hypothesis.

On the active Swift fixture actor, only the non-colliding root's collision group was changed from SandboxEnemyVisuals to Default. Before: FloorMaterial Air, state Freefall, root Y≈102.984 and hull bottom≈99.984 over a measured floor at Y=100. After .5 seconds: FloorMaterial Concrete, state Running, root Y≈104.000 and hull bottom≈101.000. Existing speed 22, JumpPower 50 and UseJumpPower true were unchanged. This isolates the root visual-group/world-ground-query mismatch.

Source correction: assign the already non-colliding root to Default while leaving visual parts, physical hull, HipHeight, friction, health, speed, attacks and budgets unchanged. Fixture version 2 requires each actor to have observed non-Air ground contact, preventing a flat hull-slide from hiding this failure. The diagnostic run was cancelled; subsequent clean verification uses new actors from the corrected source.

### Verification in progress

Clean full-matrix run: `68a5092a-b9bf-45a4-8966-16be87648878`; eleven courses, four solo kinds plus one mixed eight-enemy crowd per course, 30-second timeout, original shared path budgets. Detailed progress/evidence exports are under `C:/Users/bello/.codex/visualizations/2026/10/19/01a155dd-ba09-7002-a0df-aa0ec505db4b/navigation-live/`. An attempted full diagnostic-report export hit the MCP's text-size limit; its partial raw file is not a valid complete JSON report. Use bounded progress/final evidence exports instead.

After the grounding correction, focused formatting, 70/70 standalone tests and another isolated temporary Rojo build passed. Final live matrix results and Edit-source restoration are pending; do not yet certify all supported terrain.

### R6 floor reference and residual crowd failure

The root-group-only run completed Flat 5/5 and RaisedEdge 5/5, but Curb and Stairs each passed 4/5: their mixed crowds left two Elites stalled. The run was cancelled during Ramp; its partial final Ramp entry is cancellation, not an independent terrain failure. Valid bounded export: `navigation-live/root-fix-intermediate-summary.json`.

A grounded Elite on the curb stood with root Y≈107, hull bottom≈102.5 over floor Y=101. Treating the hull bottom as the waypoint floor exaggerated the height error by 1.5 studs and could prevent descending to lower walk waypoints within the existing 2-stud tolerance. The corrected reference follows the engine's R6 standing formula: leg height + root height / 2 + HipHeight below root. Agent height includes the hull top above that reference. Current fallback-body radius/height is Basic/Swift 2/10, Brute 3/13, Elite 3/15. HullBottom remains a separate diagnostic; HipHeight itself is unchanged.

Next diagnostic matrix run `487485e3-224a-4cf0-b5da-c90bb1374541` uses both live-derived corrections, all eleven courses, all four solo kinds and eight-enemy mixed crowds. The 70/70 standalone suite and focused formatting passed again against this source. It subsequently reproduced the slope failure below; do not count this cancelled run as final validation.

### Physical slope support versus baked waypoint height

Run `487485e3-224a-4cf0-b5da-c90bb1374541` passed all 25 trials through Ramp, then the Slope solos Basic/Swift passed while Brute/Elite and the mixed crowd failed. Brute was Running/Concrete at ground Y≈112, X≈2075.35, but waypoint 2 was Walk at Y≈108.566 at essentially the same X/Z; after 30 seconds it had 18 successful path requests and 17 stuck recoveries. Elite showed the same landing mismatch. A mixed-crowd sample on the ramp showed the reverse error: waypoint Y≈104.846 versus physical standing floor Y≈101.861. First/last diagnostics are preserved in `navigation-live/slope-before-support.json`. A later Corner trial was cancelled, not failed independently.

Correction: when a **walk** waypoint is already within the existing horizontal tolerance but fails height completion, a grounded actor can reconcile it against a physical support ray. The ray starts above both current floor and baked waypoint, and ends below current floor by the existing tolerance. Advance only if the observed surface is within that same height tolerance. This handles ramp/landing baking mismatch without enlarging tolerance or skipping a real upper floor. Jump actions and airborne actors cannot use this reconciliation. No global floor probe or additional path jobs are added; the conditional navigation ray is separate from unchanged hit-query budgets. Regression tests cover physical versus actual lower floors, actual upper floors, distant points, jumps and airborne actors, including the production chase closure.

## 11. Step 01 final live validation

Final source run: `96afed25-9c98-441c-a34f-8490e4a86adc`, FixtureVersion 2, Studio **server** execution. **55/55 trials passed, 132/132 actors reached**, all with observed grounding and none dead. Each of eleven courses ran Basic, Swift, Brute and Elite individually, then two of each in one mixed crowd. Courses: flat, .5/1-stud curbs, four-stud raised edge, six one-stud stairs, 6/40 ramp, 12/40 slope, corner barriers, 12-wide/18-high doorway, 9.5-high lintel with side detours, timed temporary blocker, and moving target. Every raised-edge trial issued a jump. The low lintel is below all current standing-agent clearances; success means navigating its available side route, not fitting through it.

Every trial finished within 10.55 seconds of its 30-second timeout. There were zero path-computation failures. Maximum observed queue wait was 1.823 seconds, maximum compute duration .121 seconds. Several mixed crowds had one startup stuck-recovery request while sharing the original budget; they recovered and completed. This is not a general performance benchmark. BlockedPath Brute, Elite and mixed trials received a blocked-path signal and subsequently completed. Original limits: 4 path starts/second, 2 in flight, 30 Hz hit queries. No teleportation or production stuck-removal was used to pass a trial.

Actual cylinder hull height/diameter: Basic/Swift 9/2.8, Brute 11.25/3.5, Elite 13.5/4.2. Actual sweep X/Y/Z: Basic/Swift 2.8/8.5/2.8, Brute 3.5/10.625/3.5, Elite 4.2/12.75/4.2. Integer agent radius/height: 2/10, 3/13, 3/15 respectively. Separate Ground/HullBottom samples capture R6 standing reference versus physical hull position; first spawn samples can precede settled standing height.

Evidence directory: `C:/Users/bello/.codex/visualizations/2026/10/19/01a155dd-ba09-7002-a0df-aa0ec505db4b/navigation-live/`.

- `final-matrix.json`: complete, valid bounded JSON containing every trial, actor outcome, body measurements, mode coverage and queue/compute/recovery maxima.
- `final-samples.json`: complete, valid representative samples for slopes, stairs, low clearance, blockers and moving targets, including waypoint positions/actions and direct/path states.
- `slope-before-support.json`, `root-fix-intermediate-summary.json`: failed/cancelled diagnostic runs, not final passing evidence.
- `focused-before-grounding-mcp.json`: truncated early export; explicitly not valid complete report evidence.

Final source checks: focused StyLua, 70/70 standalone Luau tests, and fresh temporary Rojo build passed. Earlier relevant map/mode/reference/boundary/stat-cap/reward checks remain as recorded in section 9. No magic/VFX files or their test expectations changed.

The final preservation hash matched **all 2,697** original files outside the six intended paths: `74d9c13acb517036805735b16e3aed0f15f47cb9d02af83a9a8a1d00aba21985`. Method: sort Git-listed tracked + nonignored untracked paths; feed each UTF-8 path followed by its binary SHA-256 file digest into an aggregate SHA-256. Final per-file manifest is `navigation-live/protected-files-final.json`. Saved place SHA-256 remains `c89a0406bb062389527f1c683bd6c6dfbf397668fdf239d7ca455e7561c29beb`.

Supported terrain is bounded by these explicit fixture geometries and current fallback R6 rigs. This does not certify arbitrary production gaps, taller steps, steeper slopes, imported replacement meshes, guard navigation, client-visible animation quality, or a complete mission playthrough. No imported EnfleshedModels were present in this session. Those are separate checks, not hidden failures in this matrix. Step 02 animation and production map reconstruction were not started.

### Close combat and session teardown

After exporting traversal evidence, the fixture was cleared and fresh actors were spawned sequentially for a 12-second close-range NPC combat smoke test per kind. Basic, Swift, Brute and Elite all grounded, entered Chase/Telegraph/Attack/Recover, delivered positive damage to an isolated tagged test citizen, and remained alive. Existing attack/lunge behavior and timing were exercised, not modified. Test dummy health 1000 is an isolated observation aid, not a production balance change. `navigation-live/combat-result.json` is valid bounded evidence for states, distances and target health; its raw Vector3 Root fields serialize to null, so use `final-samples.json` for position evidence. This is a server smoke test, not a client animation or PvP test.

`navigation-live/final-console.json` also records unavailable unpublished-place DataStore/profile persistence, Roblox UI FoundationProvider warnings and an asset type mismatch for 203785492. These were outside the navigation test scope; no persistence or asset fix is claimed, and no navigation script exception was reported in that captured output.

Cleanup receipt `navigation-live/cleanup.json`: traversal and combat folders absent, zero test enemy models remaining. The original live Edit EnemyService was restored with an exact-current-source guard (`edit-enemy-restoration.json` returned true); temporary helper/fixture removal is separately guarded. Initial combined restoration requests failed before applying. The fixture source guard contained a JSON Unicode escape that is invalid in a Luau string; preserve Unicode characters directly when quoting that source. Split guarded requests restore the modules after fixing that quoting issue. No save or publish call was made. Repository fixes remain ready for normal source sync.

Final Edit cleanup receipt `navigation-live/edit-fixture-restoration.json`: helper absent, development fixture/folder absent. Studio is stopped in Edit with its original EnemyService restored. **Step 01 complete for the supported fixture; stop here.** Step 02 and production-map rebuilding remain unstarted.

## 12. Step 02 — enemy animation implementation and evidence

Date: 2026-10-19. **Procedural presentation implemented; final visible-viewport acceptance remains pending.** No step 03 work started. The connected Studio MCP was used for server/client runtime observations. All new animation code is enemy-only; player magic/melee presentation and existing VFX were preserved.

### Reproduced cause and rig audit

Baseline source already wrote six R6 joint poses on the server every update but had no enemy client animation controller or Animator. Baseline server report recorded a nonidentity RootJoint Transform during Chase; the client reported identity during Telegraph on the same actor. This matches the documented non-replicated Motor6D.Transform behavior. Reports: `animation-live/baseline-server.json`, `baseline-client.json`. The first screenshot was UI-covered, so it is not visible-animation evidence.

Fallback joints had C0 at the limb center and C1 identity. Anatomical shoulder/hip/neck pivots now retain the same neutral part placement through matching C0/C1. Imported mesh pivots are preserved. No imported EnfleshedModels were present in this Studio session, so imported mesh fitting is not certified. Existing GLBs/manifests and the available player/melee animation code were inspected; no enemy AnimationTrack assets were found or invented.

### Implementation and ownership

- EnemyAnimation shared sampler reuses existing attack silhouettes and adds stopped/moving gait distinction, rising/falling/landing, recovery and progressive death poses. Actual velocity drives gait phase; translation offsets scale with the Model.
- EnemyAnimationController applies transforms on the client in PreSimulation. Independent LocalScript bootstrap avoids editing the player/magic initialization path. Existing server phases, step and presentation flags replicate in one EnemyPose attribute snapshot on changes, rather than per-frame transforms. Phase finish times come from existing combat timers; active strikes are applied immediately on receipt. Network presentation latency remains possible.
- EnemyAnimationCorpse retains at most 24 cosmetic copies for 1.1 seconds after actual death; originals still clean up immediately. Copies remove Humanoids, hulls and combat tags and disable collisions, queries and touches. They do not register with EnemyRuntime. Living administrative removals do not spawn death copies.
- Manual Studio server/client review scripts exercise existing combat APIs and restore temporary camera/UI settings. No production bootstrap invokes the test fixture.
- Coverage, rig compatibility, asset provenance and remaining authoring/acquisition needs are listed in `docs/enemy-animation-assets.md`. This is prototype procedural art, not delivery of final authored clips.

### Runtime checks versus visible review

Evidence directory: `C:/Users/bello/.codex/visualizations/2026/10/19/01a155dd-ba09-7002-a0df-aa0ec505db4b/animation-live/`.

First four-kind run: all kinds showed changed joints/legs, idle/chase/telegraph/attack/recovery/flinch and low-health presentation in the client DataModel. All four cosmetic deaths were observed moving and noncolliding/nonqueryable/nontouchable, then expired. All 151 recorded damage events were inside authoritative Attack phase windows (`review-server-result.json`, `review-client-result.json`).

Repeat coverage run: explicit ordinary jump requests covered airborne motion for all four kinds; Swift's moving-target missed-lunge probe reached Vulnerable on server and client. All kinds again covered common states and safe moving cosmetic deaths; zero corpses remained afterward. All 146 recorded hits were within active phase windows (`coverage-server-result.json`, `coverage-client-result.json`). Vulnerability is an existing common rendering branch; only Swift entered it naturally in this run. A client observer requiring the controller in the MCP execution context returned an unstarted diagnostic instance despite observed live joint motion; that counter was excluded from the repeat acceptance data. The repeat observer reads actual replicated Instances and poses.

**Visual acceptance limitation:** repeated native screen_capture calls returned white 3D viewports (UI could render), including explicit camera coordinates. These files are failed capture evidence, not proof of readability. Attempting client Set3dRenderingEnabled was denied by RobloxScript capability. The computer-use skill was read and attempted as a fallback, but node_repl initialization failed with “failed to write kernel assets … path specified … os error 3.” No desktop automation occurred. Thus no claim is made that an actual visible client viewport or final imported-mesh animation quality was visually reviewed. A human or working viewport capture must still assess silhouettes, foot sliding, telegraph readability, contact alignment and transitions before closing step 02's visual gate.

### Scope and automated checks

At the start, SHA-256 was recorded for 2,703 existing Git-listed files. All 2,701 existing files outside EnemyService and this status document matched afterward, including prior step 01 helpers/fixture/tests, balance/configuration, existing magic/VFX work and saved place. Existing EnemyService chase, requestPath, beginAttack and update function bodies are byte-for-byte unchanged from the step 01 baseline; recorded in `animation-live/scope-check.json`. Only rig/presentation publication and cosmetic death integration were changed in that mixed-responsibility service.

71/71 standalone Luau tests passed, including the new pose coverage/scaling suite and existing navigation regression. Focused formatting and a fresh isolated Rojo build passed. Map (8), mode (4), module-boundary (2), stat-cap wiring (3), and shutdown reward wiring (3) checks passed. Full magic/VFX suites were not rerun; their sources/tests were preserved. Live navigation regression and final Studio staging restoration are recorded below when complete.

### Navigation, crowds and bounded death cleanup

Final navigation run `8592b1e9-6c9b-44b6-87db-f5fb95da7e2f`: **20/20 trials passed, 48 actors**, all current kinds solo and in mixed crowds across RaisedEdge, Stairs, BlockedPath and MovingTarget. No path-computation failures; longest trial 11.232 seconds, maximum queue wait 1.268 seconds, unchanged 4-start/second and 2-in-flight limits. Complete bounded report: `animation-live/navigation-final.json`. The client crowd probe (`crowd-client.json`) sampled 294 times, observed eight simultaneous enemies, and recorded nonidentity joint motion for Basic, Swift, Brute and Elite. This is actual client DataModel evidence; it is not a substitute for the failed visible-viewport captures.

The 32-death burst probe (`death-cap-result.json`) produced exactly 24 retained cosmetic copies, all without Humanoids/combat tags and all collision/query/touch-disabled. After 1.5 seconds none remained. Final console capture contained no EnemyAnimation errors. Existing initialization warnings outside this workstream were left unchanged.

Final source formatting, 71/71 standalone tests and isolated build passed. The live controller and final formatted source differ only by extracting the identical motion table into a local variable to avoid StyLua's layout oscillation; no pose logic or values changed. Existing source preservation was rechecked: 2,701/2,701 out-of-scope files unchanged, including saved place SHA-256 `c89a0406bb062389527f1c683bd6c6dfbf397668fdf239d7ca455e7561c29beb`.

### Step 02 acceptance and remaining action

The implementation and available engine/client-state regressions pass. **Step 02's visual acceptance gate remains open** because no usable visible 3D capture was obtained. Final animation assets are also still a documented art dependency, not silently substituted with invented IDs. Do not start step 03 on the assumption that these visuals have been approved.

Next action: use a working visible, source-synced Studio client and the two manual review scripts to inspect all four silhouettes, real motion, short telegraphs, active strike contact, reactions, vulnerability, jump/landing transitions and death copies. Confirm imported MeshPart rigs separately after the existing documented import process if those assets are to ship. Keep current attack timing/hitboxes and navigation unchanged while fixing any observed presentation issue. No production map rebuild or objective implementation was begun.

Studio teardown verified: `original-enemy-restored.json` returned true, `temporary-modules-removed.json` confirmed all six temporary modules removed, and `final-studio-state.json` reported Edit. Restoration used exact staged-source guards and preserved unrelated live content. No save/publish was invoked. The repository retains the implementation for deliberate normal source sync. Stop here at step 02 with the visual gate explicitly pending.

## 13. Main Studio sync requested 2026-10-23

User requested backing up the current Studio place and syncing navigation/animation into the main place. Studio MCP listed zero instances and desktop inventory showed Studio closed, so the backup is of the latest saved main place, not an unsaved session.

- [x] Back up the saved main place before any edits. File: `place-backups/Enfleshed-before-gameplay-sync-20261023-170200.rbxlx`. Original and backup SHA-256 match: `888a2f42bcbe8fc3bdf8d6fdd07a550a57b22ac703c6732dc73fab5793e51746`.
- [x] Open the main place and sync only enemy navigation/animation runtime modules plus the dormant traversal fixture; preserve other live scripts/assets.
- [x] Verify exact source matches and save the main local place through Studio. No gameplay/magic source edits, full-place Rojo rebuild, cloud publish or progression changes were made.

Result: main Studio instance `476f858d-ba97-4eab-91fe-f449c5ad3cca` opened the existing local `Enfleshed-Defend-The-Walls.rbxlx` (PlaceId 0). The old live EnemyService matched Git HEAD; all six added modules were absent. Synced EnemyService, EnemyAnimationCorpse, EnemyNavigation, EnemyAnimation, EnemyAnimationController, the EnemyAnimation LocalScript, and dormant EnemyTraversalFixture. All seven class/source comparisons matched repository files after sync. Checksums/length/class for all 266 original script containers were compared: only the intended EnemyService changed, and the other 265 were unchanged. Six new scripts and the development folder were added; unrelated VFX/magic sources/assets were not synchronized.

Saved the updated main place through Studio's local Save command after the verified backup. The earlier general no-overwrite/build restriction was honored by not regenerating the place with Rojo; the user's explicit main-place sync request authorized saving these selected edits in Studio. Updated main file: 32,454,301 bytes; SHA-256 `14950665c916752beebb15e7ad4661ba58357ca0335b8c8951a31f8a98c9edc6`. Backup remains 32,419,311 bytes and retains the verified pre-sync hash. The place stays open in Edit for the user. No Play test or new visual acceptance was performed in this sync task; step 02's visual review remains pending.

Sync receipts and per-script checks: `C:/Users/bello/.codex/visualizations/2026/10/19/01a155dd-ba09-7002-a0df-aa0ec505db4b/studio-main-sync/`. No repository gameplay source was edited in this task. No cloud publish occurred.
