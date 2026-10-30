# Architecture — Enfleshed

Module boundaries and dependencies for orientation. Read only the section you need. File paths are under `src/`. For live status see `CURRENT_STATE.md`; for a detailed service/UI map of the Defend the Walls gameplay area see `docs/gameplay-implementation-status.md` §2–3.

## Build and place mapping (`default.project.json`)

| Source | Studio location |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (+ `SandboxRemotes` RemoteEvents) |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

Rojo builds `Enfleshed-Defend-The-Walls.rbxlx` (gitignored). Folders with `init.meta.json` are plain folders, not scripts.

## Bootstrap

- `server/init.server.luau` creates every remote first (names in `shared/Networking/Protocol.luau` plus a few literal names), then starts services inside a guarded `startService` (pcall, warn on failure): FeatureFlagService, TelemetryService, PlayerProfileService, EnemyRuntime, ActionRouter, DefendTheWallsService, CombatSandboxService. Other services are started lazily by whoever requires them.
- `client/init.client.luau` starts GrimoireLauncher and CameraController first, then requires the remaining controllers by name; input is disabled if a required combat/magic controller fails. `client/EnemyAnimation.client.luau` is a separate bootstrap for enemy animation.

## Request flow

Client controller → `RemoteEvent` in `SandboxRemotes` → `server/Networking/ActionRouter.luau` (validates and dispatches to services; also owns character spawn routing and per-character attribute setup) → service → feedback remote / replicated attributes → client controller/UI.

`ActionRouter` is the hub: it depends on Combat, Damage, Equipment, Inventory, MagicLab, Magic, MagicPresentation, Movement, SpellVFXRelay, Summon, Telemetry and TrainingDummy services. Edits there touch shared spawn/casting paths; keep them narrow.

## Systems

### Combat (melee, movement, damage)
- `CombatService` (melee actions) → `HitDetectionService`, `MeleeDefenseService` (block/parry), `MovementService` (sprint/dash), `EnemyService`; config `shared/Configuration/MeleeProfiles`, `Sandbox`.
- `DamageService` is the single damage entry point (`apply`, `applyMelee`, `Applied` signal). Used by Combat, Magic, Summon, Enemy, Guards, Mode, Inventory. Applies status effects (`MagicStatusEffectService`), defense and caps (`shared/Modules/CombatPolicy`, `shared/Configuration/SpellStatCaps`). Highest fan-in module: changes affect everything.
- `EquipmentService`, `InventoryService` (+ `shared/Modules/InventoryModel`, `ItemRules`, `Configuration/Items`, `Loot`). Client: `CombatController`, `InputController`, `MovementController`, `EquipmentController`, `InventoryController`, `UI/InventoryView`.

### Enemies
- `EnemyRuntime` (Heartbeat scheduler, bounded path jobs) → `EnemyService` (rigs, hulls, targeting, navigation, attacks, server pose state) → `NascentAttackSelector`, `EnemyAnimationCorpse`.
- Pure logic: `shared/Modules/EnemyNavigation`, `EnemyAnimation` (pose sampler). Client rendering: `client/Controllers/EnemyAnimationController`.
- Dev fixture: `server/Development/EnemyTraversalFixture` (not started by production bootstrap).

### Game modes and maps
- `ModeRunner` — generic round lifecycle: participants, state messages, finish, rewards commit, replay, shutdown.
- `DefendTheWallsService` (mission) → `ModeRunner`, `DefendTheWallsGuards`, `DefendTheWallsMap/*` (world construction), `shared/Modules/DefendTheWallsLayout` (seeded pure layout), config `Configuration/DefendTheWalls*`.
- `CombatSandboxService` (practice area) → `MapGenerator`, `Configuration/CombatBattleMap`, `EnemyService`. `TrainingDummyService` for targets.

### Progression and persistence
- `PlayerProfileService` (session-locked profile store; `shared/Modules/ProfileSession` is the pure lock/merge logic) ← `MissionProgression` (XP, Marks, unlocks, spell ranks; idempotent rewards), `InventoryService`, `ModeRunner`.
- `MissionProgression` is mixed ownership: mission rewards and magic unlock/rank rules (`Configuration/SpellProgression`, `Modules/SpellProgressionRules`).

### Magic (spell creation and runtime)
Data model → authoring → runtime → presentation:
- **Schema/data:** `shared/Configuration/MagicSchema`, `Spells`, `MagicElements`, `MagicSummons`, `MagicLab`; `shared/Modules/SpellSpec` (spec model), `SpellDefinitionValidator`, ~60 pure `Magic*Spec` / `Magic*` rule modules (one per mechanic: targeting, triggers, conditions, lifetime, area, status, etc.), `Types/MagicTypes`.
- **Authoring (Grimoire):** server `MagicLabService` (save/library/slots/costs; uses `GrimoireLibrary`, `GrimoireStarters`, `MagicSlots`, `MagicLabCost`, `MissionProgression`). Client `GrimoireLauncher` → `MagicController` → `MagicLabController` (very large) → `UI/GuidedSpellForge`, `GrimoireLibraryView`, `SpellHub`, `GrimoireConditionTreeEditor`, `GrimoireGeometryPreview`.
- **Runtime:** `MagicService` (very large; cast pipeline, budgets, state) → executor modules `MagicFormExecutors`, `MagicBehaviorExecutors`, `MagicProjectileBehaviorExecutors`, `MagicPayloadExecutors`, `MagicManipulationExecutors`, `MagicTriggerExecutors`/`MagicTriggerDispatch`, `MagicConditions`, `MagicStatusEffectService`, `MagicControlService`, `MagicWorldQuery`, `MagicConstructBuilder`, `MagicPersistentConstructStore`, `SummonService`, `MagicSummonPlacement`, `MagicPhysicsOwnership`.
- **Presentation/VFX:** server `MagicPresentation` + `SpellVFXRelay` → remotes `MagicPresentation`, `SpellVFX` → client `MagicPresentationController`, `SpellVFXController`, `GeneratedSpellController`, `MagicRevealController`. `shared/SpellVFXSystem/` = `Core` (composer, registry, session), `Signature` (per-family renderers: fire, beams, glyphs, fields), `Effects` (primitive effect types), `Visual` (spell → visual plan), `Assets` (asset manifests; some generated). Asset pipeline: `tools/vfx_pipeline/`, Studio scripts `scripts/studio_*.luau`.

### Cross-cutting
`FeatureFlagService` (+ `Modules/FeatureFlagSpec`, `Configuration/FeatureFlags`), `TelemetryService`, `TextFilterService`, `client/UI/Kit` (UI primitives), `client/UI/HUD/*` (CombatHUD, SpellBar, Lobby, MissionTracker, WorldUI) driven by `UIController`.

## Remotes (`SandboxRemotes`)

ActionRequest / ActionFeedback (most gameplay), AerialControl, MagicLabRequest / MagicLabResponse / GrimoireResponse (Grimoire), TrainingDummyRequest / Response, MagicPresentation, SpellVFX, MissionRemote (mission state/results), InventoryRemote.

## Tests

- `tests/test_*.lua` — standalone Luau unit tests, run by `scripts/run_luau_unit_tests.py` against a source snapshot (`loadfile` shim). `test_magic_lab.lua` / `test_grimoire_library.lua` run via `scripts/run_luau_magic_tests.py` flags.
- `tests/*_spec.luau` — self-contained specs that `require("../src/...")`; run directly with `luau`.
- `tests/test_*.py` — source-contract/wiring tests (Python `unittest`). Some read a built place via `ENFLESHED_PLACE_FILE`; VFX ones may invoke `tools/vfx_pipeline`.
- `tests/test_module_boundaries.py` enforces that modules extracted from MagicService / MagicLabController / GuidedSpellForge stay stateless and do not require their owner.
- `scripts/check.sh` = full gate (Bash).

## Design decisions to reuse

- Pure logic in `shared/Modules` + Luau tests; Roblox-instance code thin.
- Server authority for damage, objectives, rewards, unlocks; clients send bounded requests.
- One damage pipeline (`DamageService`) and one targeting/consent policy (`CombatPolicy`); do not add parallel ones.
- Large files are split by extracting stateless helper modules required by their owner (see boundary test), not by rewriting.
