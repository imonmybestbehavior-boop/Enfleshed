# Enfleshed — Game Status Audit

Audit date: 2026-10-14. Scope: `src/` (synced by `default.project.json`), `tests/`, `scripts/`, `docs/`, config. `Shelved Project/` (the old city build) was excluded. I read the code; I did not play it in Studio. Line numbers refer to the files as they were on the audit date.

Status labels: **IMPLEMENTED** (code path complete and wired), **PARTIAL** (wired, but missing pieces), **STUB** (placeholder), **MISSING** (no code), **BROKEN** (code exists and is wrong).

---

## 1. Executive summary

**Overall completion toward a shippable live game: about 25–30%.** The engineering foundation is strong and unusually disciplined: a server-authoritative combat router, a deep, validated, data-driven spell system (~52k lines of Luau, 141/194 files `--!strict`, ~100 test files), idempotent mission rewards, and enemy AI with telegraphs. But the *game* around it is a single 10-minute gate-defense mode on one procedurally built map, with 4 enemy types, no boss, no audio/music, no menus or settings, no tutorial, no monetization, no analytics, and a progression track that runs out after about 4 unlocks. Treat it as a **strong tech prototype / pre-vertical-slice**, not an alpha.

**Top 5 risks**
1. **Friendly fire/griefing in co-op:** melee hit detection has no target filter, so players can damage each other in the hub and during missions (`CombatService.luau:117-121`, `DamageService.luau:19-26`).
2. **Inventory duplication/rollback:** `SetAsync` with no session lock (`InventoryService.luau:105`) allows a server-hop race that duplicates dropped items.
3. **Spell Lab is enabled live while the config says it is opted out** (`Configuration/MagicLab.luau:2-5`: comment "Live servers are opted OUT", but `StudioOnly=false, AllowLive=true`), and the most complex system in the game is exposed with no live tuning, kill switch, or telemetry.
4. **Content cliff:** progression is 4 unlocks + 3 ranks + 2 slot milestones; levels run to 100 with no rewards attached. There is no reason to play past roughly 3–5 hours of XP play.
5. **No first-time-user flow:** no main menu, tutorial, settings, audio, or gamepad support. First-session retention will fail regardless of how good the spell system is.

**Single most important next step:** lock a **vertical slice**: fix friendly fire and the inventory session lock, then build the first 10 minutes (spawn → guided first spell → first mission → reward → first unlock) with audio and a settings menu, and instrument it with AnalyticsService funnel events.

---

## 2. Architecture map

```
Toolchain: Rokit (rojo 7.7.0, StyLua 2.5.2, luau 0.742) — rokit.toml
           No Wally packages, no frameworks (no Knit/Fusion/React/ProfileService). Hand-rolled modules.
           No git in this environment (repo has .git but no CLI); no Selene, no CI config found.

ReplicatedStorage.Shared  (src/shared)
  Configuration/   balance & schemas (MagicSchema 2102 lines, Sandbox, DefendTheWalls, SpellProgression, Items, Loot…)
  Modules/         ~70 pure spec/validator modules (SpellSpec, SpellDefinitionValidator, GrimoireLibrary, InventoryModel…)
  SpellVFXSystem/  cosmetic VFX composer/signature renderer (client-side)
  Networking/Protocol.luau   action names; SandboxRemotes folder (12 RemoteEvents, 0 RemoteFunctions)

ServerScriptService.Server (src/server)
  init.server.luau → creates remotes, then starts: EnemyRuntime → ActionRouter → DefendTheWallsService → CombatSandboxService
  Networking/ActionRouter      single entry for combat/magic/equipment input; token-bucket rate limit + sequence check
     ├─ MovementService (speed/teleport validation)   ├─ CombatService + HitDetectionService (server hitboxes)
     ├─ MagicService (5220 lines: casting, mana, strain, payloads)   ├─ SummonService, MagicStatusEffectService
     ├─ EquipmentService, InventoryService (DataStore)   ├─ MagicLabService (spell library DataStore, equip)
     └─ TrainingDummyService, MagicPresentation, SpellVFXRelay, MagicDiscoveryService
  DefendTheWallsService + MissionProgression (XP/Marks DataStore, UpdateAsync + receipts)
  EnemyRuntime/EnemyService (pathfinding, telegraph state machine), MapGenerator (seeded castle)

StarterPlayerScripts.Client (src/client)
  init.client.luau → controllers: Camera, HUD, Mission, Debug, Movement, Combat, Magic, Inventory, Equipment, SummonCommand…
  UI/  GuidedSpellForge (2747), GrimoireLibraryView, SpellHub, InventoryView — built imperatively with Instance.new
  MagicLabController (5476 lines) — the Grimoire

Client → Server: ActionRequest {Action, Sequence, Character, …}; MagicLabRequest(action,data,slot); InventoryRemote {Op};
                 MissionRemote(action string); AerialControl(character, dir); TrainingDummyRequest
Server → Client: ActionFeedback, MagicLabResponse, GrimoireResponse, MissionRemote snapshots, SpellVFX, MagicPresentation
Persistence: 6 separate DataStores per player (see §5)
```

---

## 3. Feature inventory

| Area | Feature | Status | Evidence | Notes |
|---|---|---|---|---|
| Combat | Light/heavy melee, combo, recovery | IMPLEMENTED | `server/Services/CombatService.luau:18-47` | Server-side timing; client only requests |
| Combat | Server hitboxes + LOS | IMPLEMENTED | `HitDetectionService.luau:15-72` | `GetPartBoundsInBox` + facing dot + raycast LOS |
| Combat | Block / parry | IMPLEMENTED | `CombatService.luau:49-96`, `MeleeDefenseService.luau` | |
| Combat | Dash / sprint, movement validation | IMPLEMENTED | `ActionRouter.luau:300-313`, `MovementService.luau` | Server owns dash cooldown, corrects positions |
| Combat | Damage numbers | IMPLEMENTED | `ActionRouter.luau:47-57` | Broadcast to all clients on every hit |
| Combat | Hitstop / screen shake | PARTIAL | `SpellVFXSystem/Effects/CameraShake.luau` | Spell VFX only; no melee hitstop found |
| Combat | Friendly-fire policy | BROKEN | `CombatService.luau:117-121` (no `CanTarget`) | Players can hit players |
| Waves | Timed 5-phase defense | IMPLEMENTED | `Configuration/DefendTheWalls.luau`, `DefendTheWallsService.luau:372-451` | 600s, budgeted spawns, party-scaled caps |
| Waves | Enemy composition | PARTIAL | `DefendTheWallsService.luau:438-446` | 4 kinds (Basic/Swift/Brute/Elite), one Elite per run |
| Waves | Boss wave | MISSING | — | |
| Waves | Endless / difficulty tiers | MISSING | — | Single difficulty |
| Waves | Win/lose/replay | IMPLEMENTED | `DefendTheWallsService.luau:268-332, 511-545` | Gate destroyed = lose, timer = win |
| Waves | Stuck-enemy cleanup | IMPLEMENTED | `DefendTheWallsService.luau:409-420` | 32s timeout |
| Enemies | AI state machine w/ telegraphs | IMPLEMENTED | `EnemyService.luau:32, 598-605, 776-805` | Idle/Chase/Telegraph/Attack/Recover/Vulnerable/Flinch |
| Enemies | Pathfinding w/ budget | IMPLEMENTED | `EnemyRuntime.luau:28-57` | Round-robin, max paths in flight |
| Enemies | Models | PARTIAL | `assets/enemies/{Basic,Brute,Elite,Swift}` | Need Studio check for final vs. placeholder art |
| Enemies | Loot drops | IMPLEMENTED | `InventoryService.luau:351-366`, `Configuration/Loot.luau` | Owner-protected pickup window |
| Co-op | Party up to 4, late join | IMPLEMENTED | `DefendTheWallsService.luau:202-219` | Participation-scaled rewards |
| Co-op | Revive / downed state | MISSING | — | Death = respawn via LoadCharacter |
| Co-op | Party/invite UI | MISSING | — | Same-server only |
| Spells | Spell data model (8 forms, 6 principles, 8 elements, triggers, conditions) | IMPLEMENTED | `Configuration/MagicSchema.luau:194`, `MagicPrincipleSpec.luau:37`, `MagicDamageRules.luau:5` | Very deep |
| Spells | Server validation of client spells | IMPLEMENTED | `SpellSpec.luau:215-230, 455+` | Key allowlist, tree size ≤700 nodes, depth ≤18 |
| Spells | Server cost/power budget | IMPLEMENTED | `SpellProgressionRules.luau:64-101` | Rank-gated mana/strain/complexity, repriced server-side |
| Spells | Spell builder UI (Spell Forge) | IMPLEMENTED | `client/UI/GuidedSpellForge.luau` (2747 lines) | |
| Spells | Library save/load (200 spells) | IMPLEMENTED | `GrimoireLibrary.luau:3`, `MagicLabService.luau:238-270` | UpdateAsync, refuses to overwrite invalid data |
| Spells | Spell name length/filter | MISSING | `SpellSpec.luau:494` checks type only | No TextService anywhere |
| Spells | 65 showcase + 3 starter spells | IMPLEMENTED | `GrimoireStarters.luau`, README | |
| Spells | Discovery/unlock of components | STUB | `Configuration/MagicLab.luau:7` `ProgressionEnabled=false` | Code exists, switched off |
| Progression | XP / level curve | PARTIAL | `MissionProgression.luau:89-97` | Levels to 100, but nothing is gated on level |
| Progression | Marks currency + unlocks | IMPLEMENTED | `MissionProgression.luau:180-246`, `SpellProgression.luau` | 4 unlocks, 3 spell ranks |
| Progression | Loadout slot growth 4→6→9 | IMPLEMENTED | `SpellProgression.luau:4-5`, `SpellProgressionRules.luau:6-14` | |
| Progression | Achievements / dailies / quests / prestige | MISSING | — | |
| Progression | Respec | N/A | — | Unlocks are permanent and non-exclusive, so none is needed |
| Items | Weapons/armor/consumables | PARTIAL | `Configuration/Items.luau` (12 items) | |
| UI | HUD (health, mana, actions) | IMPLEMENTED | `HUDController.luau` | |
| UI | Mission HUD + results | IMPLEMENTED | `MissionController.luau:110-215` | |
| UI | Inventory | IMPLEMENTED | `client/UI/InventoryView.luau` | Has UIScale |
| UI | Main menu / loading / settings / pause | MISSING | — | |
| UI | Tutorial | MISSING | — | `MagicAuthoringGuide` is help text only |
| UI | Leaderboard / shop | MISSING | — | No leaderstats, no shop |
| Input | Keyboard/mouse | IMPLEMENTED | `InputController.luau` (ContextActionService) | |
| Input | Touch | PARTIAL | `SummonCommandController.luau`, `MagicAerialController.luau` | Ad hoc |
| Input | Gamepad | MISSING | 2 gamepad references in all of `client/` | |
| Audio | Music / ambience / UI / hit SFX | MISSING | Only user-authored spell sound IDs (`MagicPresentation.luau:158`) | |
| Live ops | Monetization | MISSING | No MarketplaceService | |
| Live ops | Analytics | STUB | `DefendTheWallsService.luau:40-44` | Counters as Folder attributes; no AnalyticsService |
| Live ops | Remote config / kill switch | MISSING | — | |
| Live ops | Shutdown handling | PARTIAL | `BindToClose` in Inventory/MagicLab/Discovery/MagicService | Mission state is lost; rewards not granted |
| QA | Tests | PARTIAL | `tests/` ~100 files | Magic suites pass; 2 Python suites red (below) |

---

## 4. Detailed findings by area

### A. Core gameplay loop

**Implemented**
- Server-authoritative melee: the client sends intent (`init.client.luau:16-41`). The server checks rate (`ActionRouter.luau:232-245`), sequence monotonicity (`:249-258`), action allowlist (`:260-275`), character identity and liveness (`:277-301`), then runs timing in `CombatService`. Hitboxes are resolved on Heartbeat on the server (`ActionRouter.luau:388-397`, `CombatService.luau:105-145`).
- The mission is a clean state machine: `IDLE → PREPARING → ACTIVE → REWARDS → CLEANUP → READY_FOR_REPLAY` (`DefendTheWallsService.luau:221-332`). Spawns are budgeted per phase and caps scale with party size (`:433-450`).
- Enemy AI has real telegraph/commit/vulnerable windows (`EnemyService.luau:32, 561, 776-805`), which gives good counterplay.

**Gaps**
- **One mode, one map, one difficulty.** There is no endless mode, no difficulty tiers, no modifiers, and no boss. A single Elite spawns at phase 4 or later (`:435-438`).
- The "wave system" is really a timed spawn director. There are no discrete waves, intermissions, or between-wave shopping or upgrade beat.
- No downed/revive state. Death mid-mission only increments `Deaths` (`:569-575`).
- The session loop exists but is thin: hub → mission → results → Grimoire Upgrades page → replay. The reward screen points players to "CHECK GRIMOIRE UPGRADES" (`MissionController.luau:146`) instead of offering an in-flow upgrade.
- No melee hitstop or hit-pause was found. Camera shake exists only in the spell VFX pipeline.

**Risks**
- Friendly fire (see §5 S1).
- If the last participant leaves, the run is silently abandoned (`DefendTheWallsService.luau:579-585`). That is acceptable, but nobody gets partial rewards.

**Recommendations**
- Add `CanTarget` to the melee rules that excludes other players unless PvP is enabled for the zone.
- Add 3 difficulty tiers plus an endless variant using the existing phase table. Add one boss archetype on top of the Elite logic.
- Add a downed state with a 10s revive using a ProximityPrompt, which already exists for repairs.

### B. Spell creation and magic system

**Implemented**
- Data model: 8 Forms (Projectile, Beam, Wave, Field, Aura, SelfEnhancement, Construct, Manipulation; `MagicSchema.luau:194+`) × 6 Principles × 8 Elements, with trigger events, conditions, payloads, behaviors, summons, constructs, and status effects.
- Validation is strong: `Spec.validate` starts with `safeTree` (≤700 nodes, depth ≤18; `SpellSpec.luau:215-230`), then applies a strict key allowlist (`:458-491`). Construct volume is capped (`:855`). Per-payload caps live in `Configuration/MagicLab.luau` (MaxDamage 100, MaxEffectTargets 256…).
- Cost is never trusted from the client. `reprice` recomputes cost and cooldown from `Spec.estimate` (`SpellProgressionRules.luau:84-101`), and `canUse` enforces rank limits (`:64-82`).
- Live casting uses only server-held equipped definitions: `EquipmentUse → Equipment.magicCast` (`ActionRouter.luau:351-363`). Raw `MagicStart` with a client definition is Studio-only (`:332-339`).
- Persistence: UpdateAsync that refuses to overwrite data it can't decode (`MagicLabService.luau:249-267`). There is versioning (`Spec` Version 3, `Library.Version 2`) and a `dehydrate/decode` path.

**Gaps**
- `Name` has no length limit or character filter (`SpellSpec.luau:494`). Names are currently sent only to the owner (`MagicService.luau:146`), so filtering is not yet a compliance blocker. It becomes one the moment names appear to others (sharing, killfeed, summon labels). A long name also inflates DataStore records (200 spells × arbitrary strings, against the 4 MB key limit).
- Discovery-based unlock pacing exists but is switched off (`MagicLab.luau:7`). The shipped progression gates only 4 coarse buckets (`SpellProgressionRules.luau:21-61`).
- No spell sharing or recipe codex for other players; there is no social layer for the strongest feature.
- No balance telemetry, so degenerate combinations can't be found from live data.
- `MaxEffectTargets = 256` and summons/constructs are capped per spell, but I found no global per-server budget for concurrent constructs, summons, or projectiles across 4 players.

**Risks**
- Balance surface is enormous. The emergent-magic audit (`tests/emergent_magic_audit_spec.luau`, `docs/EMERGENT_MAGIC_AUDIT.md`) is a good start, but it needs a stress spell per form running under 4 players + max enemies in Studio.

**Recommendations**
- Cap `Name` to 32 chars and control-free. Run it through `TextService:FilterStringAsync` before any cross-player display.
- Add a per-server "magic budget" (active projectiles, summons, constructs, status effects) that rejects casts when saturated.
- Turn discovery on for live, or delete it. Shipped-but-disabled systems rot.

### C. Progression

**Implemented**: XP (never spent), Marks (spent), 4 unlocks, 3 spell ranks per spell record, and slot milestones at 500 and 1800 XP. Rewards are idempotent via mission-id receipts (`MissionProgression.luau:129-135`).

**Numbers** (from `DefendTheWalls.luau:34`, `SpellProgression.luau`):
- Victory = 120 XP / 50 Marks (+≤20 XP/+≤10 Marks bonus). A run is about 10.5 minutes including prep and results.
- 9 slots at 1800 XP ≈ 13–15 wins ≈ **2.5 h**. All 4 unlocks need 1000 XP + 480 Marks ≈ **8–10 wins**.
- Rank 3 on one spell = 650 Marks ≈ 11 wins. Nine spells ≈ 5,850 Marks ≈ **100 wins ≈ 18 h**. That is the only long-tail sink, and it is a repetitive grind on a single map.
- Levels (`MissionProgression.luau:89-97`) are computed to 100 but gate nothing.

| Tier | Exists | Needed for 20–50 h |
|---|---|---|
| Account levels with rewards | 0 rewarding levels | 50+ with a reward every level |
| Unlock buckets | 4 | 20–30 granular (per form/behavior/effect), or discovery on |
| Spell ranks | 3 | 5 + cosmetic mastery |
| Missions/maps | 1/1 | 4–6 maps, 3 difficulties, endless |
| Enemies/bosses | 4/0 | 10–12 / 4–6 |
| Gear | 12 items | 40–60 with affix tiers (affix system exists in `Loot.luau`) |
| Achievements/dailies | 0 | 40 achievements, 3 dailies + 1 weekly |

### D. UI/UX

Exists: HUD (`HUDController.luau`), Mission HUD and results (`MissionController.luau`), Grimoire/Spell Forge/Library (`MagicLabController.luau`, `GuidedSpellForge.luau`, `GrimoireLibraryView.luau`, `SpellHub.luau`), Inventory (`InventoryView.luau`), summon command panel, Grimoire launcher button, Studio debug overlay (gated to Studio + StressTest, `DebugController.luau:14`).

Missing: main menu, loading screen, settings (audio, graphics, keybinds, camera, reduced motion), pause, tutorial, shop, leaderboard, party/invite, achievements, notification/toast system (beyond ad hoc labels), confirmation dialogs.

- **Scaling:** `InventoryView` uses `UIScale`. `MagicLabController` uses `ScreenInsets.CoreUISafeInsets` (good). Other screens use fixed offsets (`DebugController.luau:16`, `SummonCommandController.luau` branches on `TouchEnabled`). No shared responsive layout.
- **Gamepad:** effectively none. There is no `SelectionImageObject` or `GuiService.SelectedObject` handling, which blocks console.
- **Localization:** all strings are hardcoded English (for example `MissionController.luau:146, 212`). There is no LocalizationTable.
- **Theming:** two theme modules (`GrimoireTheme.luau`, `SpellForgeTheme.luau`) and `SpellForgeComponents.luau`. That is the start of a component library, but HUD and Mission UI don't use it.
- **Accessibility:** no colorblind mode, text size, remapping, or reduced shake.
- **Performance:** 6 `RenderStepped`/`BindToRenderStep` users (Camera, Combat, HUD, MagicLab×2, InventoryView). MagicLab and InventoryView should only bind while open. Verify that in the profiler.

### E. Onboarding and flow

- Players spawn in the hub (`ActionRouter.luau:113-117`). The only guidance is mission prompts and the README controls. There is **no tutorial**, and the first spell is equipped automatically from the Combat Starters.
- Dead ends: players who die mid-mission respawn at the Defender point (fine). Rejoining after a disconnect loses mission participation; the run continues without them.
- No teleports or reserved servers: one place, one server type.
- Settings: none, so nothing to persist.

### F. Security — see §5.

### G. Performance — see §6.

### H. Code quality

- `--!strict` on 141/194 Luau files. The non-strict ones should be listed and converted, or have their exclusion justified.
- **God files:** `MagicService.luau` (5220 lines), `MagicLabController.luau` (5476), `GuidedSpellForge.luau` (2747). These are the main maintainability risk.
- Errors: services start inside `pcall` (`server/init.server.luau:38-43`, `client/init.client.luau:43-55`), so one failure doesn't stop the others.
- Balance data is mostly config-driven. Exceptions: enemy HP and speed are hardcoded in `DefendTheWallsService.luau:347-349`, and spawn lane positions at `:333`.
- **TODO/FIXME/HACK: zero** in `src/`. Notes live in `docs/` instead.
- Tests (audit run): all `scripts/run_luau_magic_tests.py` suites pass. **Red:** `tests/test_grimoire_workflow_wiring.py` (3 known stale cases) and `tests/test_place_references.py`.
- Tooling: StyLua is configured (`.stylua.toml`). There is no Selene and no CI. The repo holds **13 `.rbxlx` place files** at the root, including 7 backups; move them out of source control.
- Dual mission metric systems (Folder attributes) are not observable in production.

### I. Content and polish

- Map: one seeded castle battlefield (`MapGenerator.luau`, `CombatBattleMap.luau`). The gate-defense arena geometry is built in code from Slate parts (`DefendTheWallsService.luau:46-133`), which reads as graybox.
- Audio: **none** outside user-authored spell sounds.
- VFX: an extensive composer and signature system (`SpellVFXSystem/`), and README states "live Studio art review is still pending".
- Animations: needs Studio verification; no `AnimationId` assets were checked here.

### J. Live-service readiness

All missing: MarketplaceService/ProcessReceipt, GamePasses, AnalyticsService funnels, remote config (Configuration objects or MemoryStore/DataStore-backed flags), private server handling, leaderboards, update pipeline (staging place, versioning). The only "telemetry" is attribute counters on the mission folder (`DefendTheWallsService.luau:40-44`).

Fair monetization for co-op PvE should be cosmetic: spell VFX palettes (VisualCraft is already a gate), Grimoire covers, weapon skins, extra library slots, and private servers. Do not sell rank or Marks boosts that affect party power.

---

## 5. Security findings

| # | Sev | Finding | Exploit scenario | Location | Fix |
|---|---|---|---|---|---|
| S1 | **High** | Melee can damage other players everywhere | Griefer kills teammates during a mission or in the hub. Teammates lose time and the gate falls | `CombatService.luau:117-121` (no `CanTarget`); `DamageService.luau:19-26` only blocks same summon owner | Pass `CanTarget = function(m) return Players:GetPlayerFromCharacter(m) == nil end` (or a zone PvP flag); add the same check centrally in `Damage.apply` |
| S2 | **High** | Inventory save uses blind `SetAsync` without a session lock | Player A drops a rare item for B, then immediately joins another server. The new server's `GetAsync` (`:130`) can run before the old server's `save` (`:105`) finishes, so A loads the copy with the item → duplication | `InventoryService.luau:98-112, 115-143` | UpdateAsync with a session lock (`LockedBy = JobId, LockedAt`) and a reject/wait on a foreign lock, or ProfileStore. Persist a version number and refuse older writes |
| S3 | Medium | Six independent per-player DataStores with no cross-store atomicity | Unlock spent in MissionProgress while the Library write fails → inconsistent but not exploitable today. Bigger cost: request budget at scale | `MissionProgression.luau:11`, `InventoryService.luau:23`, `MagicLab.luau:9-13`, `MagicLocus` | Consolidate into one profile document per player (keep the Library separate if it is large) |
| S4 | Medium | Spell `Name`/collection text has no length cap and no TextService filtering | Today: DataStore bloat (approaching 4 MB) → save failures. Future: unfiltered UGC shown to others is a ToS violation | `SpellSpec.luau:494`; repo-wide grep finds no `TextService` | 32-char cap now; filter before any cross-player display |
| S5 | Medium | Spell Lab enabled for live despite the "opted OUT" comment | Every live player can author arbitrary spells within rank budgets. Intended? With no kill switch, a found degenerate spell can't be hotfixed without a publish | `Configuration/MagicLab.luau:2-5` | Decide intent. Add a server flag readable at runtime (DataStore or MemoryStore) that disables specific forms/payloads |
| S6 | Low | Damage numbers and snapshots broadcast widely | Not an exploit; bandwidth only (see P2) | `ActionRouter.luau:47-57` | — |
| S7 | Low | `MissionRemote` accepts `Join` mid-run, after which `LoadCharacter` teleports to the defender point | A player can reset position or heal by Hub→Join? `Hub` is blocked while ACTIVE (`:537`), so only first entry respawns. Low | `DefendTheWallsService.luau:202-219, 523-526` | Fine as is; consider no full heal on join |
| S8 | Info | `RunService:IsStudio()` gates on all debug paths | Verified: `MagicStart/Release/AimUpdate` (`ActionRouter.luau:332-339`), `debugFinish/debugDamage` (`DefendTheWallsService.luau:625-644`), Studio starter items (`InventoryService.luau:82`). No `loadstring`, no hardcoded admin UserIds, no HttpService beyond `GenerateGUID` | — | Keep it that way |

Positive controls verified: token-bucket rate limits (`ActionRouter.luau:236-245`, `InventoryService.luau:325-332`, MagicLab 0.1s throttle `MagicLabService.luau:585-590`, Mission 0.3s `:515-519`); NaN/range checks on vectors (`MagicService.luau:164-172`, `ActionRouter.luau:303-311`); payload tree budgets (`SpellSpec.luau:215`, `SpellVFXRelay.luau:8-37`); server-side network ownership of enemies (`EnemyService.luau:241`); idempotent reward commit (`MissionProgression.luau:129-135`); validated UpdateAsync purchases with an expected-rank guard (`:210-215`).

Not present, so not reviewable: ProcessReceipt and GamePass checks (no monetization).

---

## 6. Performance findings (ranked by expected impact)

| # | Finding | Location | Measure by |
|---|---|---|---|
| P1 | Unbounded custom-spell load: 4 players × 9 slots of constructs/summons/status ticks with no global budget | `MagicService.luau` (heartbeat loops ~4300-4500), `SummonService.luau`, `MagicStatusEffectService.luau` | Studio local server with 4 clients each spamming `GeneratedSpellStress` spells plus phase-5 mission; MicroProfiler server frame, Script Performance on MagicService |
| P2 | `snapshot(nil)` fires a full state + **full profile (incl. 40 receipt GUIDs)** to every player every second, and again on every gate hit | `DefendTheWallsService.luau:166-199, 465-467, 597-603` | Developer Console › Network › MissionRemote KB/s during a gate assault. Fix: send the profile only on change; use an UnreliableRemoteEvent for the timer tick |
| P3 | Every damage event → `FireAllClients` ImpactNumber | `ActionRouter.luau:47-57` | Network recv KB/s with AoE spells on 20 enemies. Fix: batch per Heartbeat, send only to nearby or involved players |
| P4 | Enemy update per Heartbeat for all handles plus pathfinding jobs | `EnemyRuntime.luau:27-57` | MicroProfiler at cap (11 + 12 for party of 4 = 23 enemies); budget < 3 ms |
| P5 | Client RenderStepped in 6 controllers; Grimoire (5.4k lines) may build large trees | `MagicLabController.luau`, `InventoryView.luau` | Client MicroProfiler with the Grimoire closed vs. open; confirm unbind on close |
| P6 | Workspace StreamingEnabled with a 6000×8000 baseplate and generated map | `default.project.json` | Mobile memory in Developer Console (target < 700 MB on low-end) |
| P7 | No pooling for enemies or loot parts; damage numbers are unverified | `InventoryService.luau:250-290` creates a part + prompt per drop | Instance count over a 30-minute session (Developer Console › Memory › Instances) |

Budget recommendation: server Heartbeat < 8 ms average at 4 players + 23 enemies + stress spells; client 60 FPS on mid PC and 30 FPS on low-end mobile; client memory < 700 MB on mobile.

Profiling plan: (1) idle hub, 4 players; (2) mission phase 5, 4 players, starters only; (3) same with each player running the heaviest `GeneratedSpellStress` spell; (4) 60-minute soak (3 consecutive missions + Grimoire use) watching server memory and instance count; (5) mobile device emulator with the Grimoire open.

---

## 7. Missing-for-ship checklist

**Blocker**
- Fix friendly fire (S1) — S
- Inventory session locking / ProfileStore migration (S2, S3) — M
- Decide and enforce live Spell Lab scope, plus a kill switch (S5) — M
- Tutorial / first-time flow — L
- Settings menu (audio, sensitivity, keybinds) with persistence — M
- Audio: music, ambience, hit/UI SFX — M (content)
- Shutdown handling: grant partial rewards in `BindToClose` for active missions — S
- Fix the red tests and add CI (rojo build + StyLua + Luau runners) — S
- Gamepad navigation for all screens (console is a launch platform); touch as a follow-up — L
- Progressive Forge-feature unlocks that double as the spell-creation tutorial — L

**Must-have**
- Boss + 6–8 more enemy archetypes — XL
- 2–3 more mission maps or variants and difficulty tiers — XL
- Spell name cap and filtering (S4), plus spell sharing with moderation — M
- Mode framework extracted from DefendTheWallsService (3–5 modes planned) — L
- PvP arena: zone PvP flag, duels with consent — L
- Remove the unused discovery/Locus systems — S
- AnalyticsService funnel + economy events — M
- Per-server magic budget (P1) — M
- Revive/downed state — M
- Results → upgrade in-flow; level rewards — M

**Should-have**
- Leaderboards (best score already persisted: `Best`), achievements, dailies — L
- Cosmetic monetization + ProcessReceipt — L
- Localization tables — M
- Split `MagicService` / `MagicLabController` — L

**Nice-to-have**
- Endless mode — M
- Accessibility (colorblind, reduced shake, text size) — M

---

## 8. Progression content gap

| Content | Exists | Target (20–50 h) |
|---|---|---|
| Spell forms / principles / elements | 8 / 6 / 8 | Sufficient |
| Curated spells | 65 showcase + 3 starter | Sufficient. Gate them as rewards |
| Unlock buckets | 4 | 20–30 |
| Spell ranks | 3 | 5 |
| Enemy archetypes | 4 | 10–12 |
| Bosses | 0 | 4–6 |
| Missions / arenas | 1 / 1 | 4–6 / 4–6 |
| Difficulty tiers | 1 | 3 + endless |
| Gear items | 12 | 40–60 |
| Achievements | 0 | 40+ |
| Daily/weekly goals | 0 | 3 + 1 rotating |
| Rewarding levels | 0 | 50+ |

---

## 9. Roadmap

1. **Vertical slice (4–6 wks).** S1/S2/S5 fixed; tutorial; settings; audio pass; analytics funnel. *Exit:* a new player reaches the first unlock in under 30 min unaided in 5/5 playtests; 0 known exploits rated High; CI green.
2. **Alpha (8 wks).** Boss + 4 enemies, 2nd map, difficulty tiers, revive, gamepad. *Exit:* 4-player stress at < 8 ms server frame; D1 retention measured in a closed test.
3. **Beta (8 wks).** Progression expansion (levels, 20+ unlocks, achievements, dailies), leaderboards, localization scaffolding, magic budget. *Exit:* economy sim shows 20 h+ of goals; no data loss in a 1,000-session soak.
4. **Soft launch.** Cosmetic store + ProcessReceipt, remote config, staging place, rollback plan. *Exit:* D1 ≥ 25%, D7 ≥ 8%, crash/data-error rate < 0.1%.
5. **Launch.** Marketing assets, thumbnails, age questionnaire, live-ops calendar.

---

## 10. Needs manual verification in Studio

- Whether enemy meshes in `assets/enemies/*` and VFX are final or placeholder, and animation coverage (no `AnimationId` audit performed).
- That `Enfleshed-Defend-The-Walls.rbxlx` matches `src/` (the place does not auto-sync; see `README.md`).
- Place settings: API Services enabled (DataStores), Team Create, avatar type and scaling, max players per server, chat/voice settings, experience questionnaire.
- Whether spell AoE/summons damage other players (melee does per code; spell targeting is consent-gated per `MagicTargetConsentSpec.luau`, but area paths were not traced exhaustively).
- Real frame time and memory under the profiling scenarios in §6.
- Mobile and console readability of the Grimoire (5.4k-line UI built in code).
- Lighting/Atmosphere (`default.project.json` sets Voxel lighting, Ambient black).

## 11. Developer decisions (answered 2026-10-14)

| # | Question | Decision | Impact on this audit |
|---|---|---|---|
| 1 | PvP? | No PvP in co-op/hub. A separate PvP arena is planned, with open-PvP zones and duel zones; ranked PvP later | S1 stands: block player→player damage by default. Add a zone-based PvP flag in `Damage.apply`, plus duel consent (reuse `MagicTargetConsentSpec`). Ranked PvP will need spell-balance normalization and matchmaking (MemoryStore queues) |
| 2 | Live spell authoring | Unlock Forge features progressively, as a way to teach spell creation | S5: replace the 4 coarse buckets in `SpellProgressionRules.requirements` with fine-grained, tutorial-paced unlocks (per form/trigger/payload). That gating becomes the tutorial backbone (§E) |
| 3 | Mode count | Defend the Walls is the first of an assumed 3–5 modes | Generalize `DefendTheWallsService` into a mode framework (shared state machine, rewards, results UI) before building mode 2 |
| 4 | Marks grind | Placeholder; economy still to be designed | §C numbers are provisional. Build an economy model/spreadsheet before content expansion |
| 5 | Spell sharing/trading | Yes | Raises S4 to **High** once shipped: TextService filtering of names/tags, report/moderation path, sharing-specific DataStore with size caps. Shared spells must be re-validated and re-priced server-side for the receiver (already true for equip) |
| 6 | Platforms | Console and PC required; mobile desired | Gamepad navigation moves to **Blocker**. Grimoire/Forge need a controller-first navigation pass and a responsive layout system |
| 7 | Discovery/Locus/foci | Not used; progression design still TBD | Remove the disabled discovery path (`MagicDiscoveryService`, `MagicLab.ProgressionEnabled`, Locus DataStore) to shrink the surface and the per-player DataStore count (S3) |
| 8 | Monetization | Early access to features and other non-pay-to-win rewards | Early access must not grant power in ranked PvP: gate early-access features out of ranked queues, or limit them to cosmetic/QoL. ProcessReceipt with a receipt ledger is needed |

### Follow-up decisions
| Question | Decision | Impact |
|---|---|---|
| Early access meaning | Paying players test features before official release (temporary) | Needs per-feature flags with a release date (remote config), and an entitlement check via GamePass/ProcessReceipt. Early-access features stay out of ranked until released for everyone. Doubles as a live beta channel, so pair it with analytics and a feedback path |
| PvP spell power | Players use their own custom spells, with stats capped | Add a PvP stat-cap profile applied server-side at cast time: clamp damage, CC duration, summon/construct counts, and mana/complexity budget per ranked tier. `SpellProgressionRules.canUse` + `reprice` is the natural hook; the clamp must run in `MagicService` payload execution, not only at equip |
| PvP rewards | Titles and unique cosmetics only | PvP stays out of the power economy. Needs a title/cosmetic inventory (separate from gear), a display surface (nameplate/title UI with TextService-safe preset titles), and anti-farming for duels (no rewards from repeated duels against the same opponent; ranked only) |
