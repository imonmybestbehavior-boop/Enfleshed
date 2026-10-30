# Defend the Walls

The default Rojo place now starts players in a small safe staging area. **BEGIN MISSION** starts a server-local defense with up to four defenders. Other players can join during preparation or combat if a slot is free. The **Practice gate** prompt in the staging area opens the original combat sandbox. The Grimoire and existing movement, melee, dash, and magic controls remain available.

## Loop

- 20-second preparation, 600-second defense, then results and cleanup.
- Three lanes open across five phases. The same `EnemyRuntime` scheduler and `EnemyService` AI run all mission enemies. Active caps and per-phase spawn budgets are in `src/shared/Configuration/DefendTheWalls.luau`.
- Enemy attacks damage a server-owned Humanoid gateway. The nearby ProximityPrompt console has two shared repair charges.
- Results grant XP, Mission Marks, and bounded contribution bonuses. The `EnfleshedMissionProgress_v1` DataStore holds versioned records and recent mission receipts for atomic duplicate prevention. Save failures are shown in the result UI.
- The same progression record owns spellcraft unlocks and per-library-spell ranks. The server checks purchases, active slot count, unlocked features, and calculated spell cost when equipping and casting. Four combat slots are available initially, six at 500 XP, and nine at 1,800 XP. Upgrades spend Marks after XP requirements are met.
- **PLAY AGAIN** readies a defender for the next run; **RETURN TO HUB** keeps them in staging. The next mission uses a fresh ID and removes mission enemies.

## Siege map (blockout stage)

The map is generated from a seed (`Config.Map.Seed`). `src/shared/Modules/DefendTheWallsLayout.luau` is pure data (spawns, lanes, crossroads, walls, doors). `src/server/Services/DefendTheWallsMap/` turns that data into the world through these modules: `Village`, `Corridors`, `Walls`, `Gate`, `Lighting`, `Props` and `Kit`. Here is the plan from the enemy side to the city: three spawns, a ruined village, then three walled corridors. The left and right corridors cross the centre one at a shared crossroads. The crossroads is a walled ruin: a solid shrine in the middle splits the flow, the ring wall opens only where a road passes, and low cover walls fill the gaps between roads. After that come wall 1 (palisade), wall 2 (curtain wall with towers) and wall 3 (bastion). The walls stand 100 studs apart. Each gap between walls (a bailey) holds staggered barricades in every lane, a ruined building between each pair of lanes, raised firing terraces on both sides and burning wagons (`DefendTheWallsMap/Baileys.luau`). The final doors stand in the gatehouse, with the staging courtyard in front of them. See `docs/defend-the-walls-blockout.svg`.

- Each wall has one integrity pool (`Config.Walls.Integrity`), shared by its three lane gates. A gate's Humanoid only stands in for that pool. The active wall's gates are tagged `CityHuman`, so enemy attacks land on them. Closed gates block everyone. Players reach the front by climbing the walkway ramps and dropping over, and come back with the **Climb back over** prompt on each wall's face. When a wall falls, its gates open, enemies retarget the next wall, the defender respawn (`Workspace.DefendTheWalls.DefenderSpawn`) moves back, and surviving guards regroup in front of the next wall. **Only the final doors lose the mission.** Their HP is still reported as `Gateway`.
- `MissionState` adds `WallLevel` (4 = only the doors remain), `WallCount`, `WallHP`, `WallMax`, `GuardsAlive` and `GuardsTotal`.
- The repair consoles work only on the active wall or the doors.
- Guards (`DefendTheWallsGuards.luau`, tuned in `Config.Guards`) spawn during preparation and never respawn. They use the ally tags and attributes, damage enemies through `DamageService`, and use `MoveTo` instead of pathfinding.
- Studio helper: `require(game.ServerScriptService.Server.Services.DefendTheWallsService).debugBreach()` breaks the active wall. It needs accelerated mock mode.
- Reviewing in Studio: run `rojo serve`, press Play, then **BEGIN MISSION**.
  - For screenshots, paste `scripts/studio_dtw_views.luau` into the **client** Command Bar. It shows each view for six seconds: the village, the crossing, each wall, the doors and an overview.
  - For performance, paste `scripts/studio_dtw_perf.luau` into the **server** Command Bar. It prints map part and light counts, spawns a 30-enemy three-lane wave with `debugWave` (Studio only), and reports server Heartbeat timings for 60 seconds.
- Mesh kit: `src/shared/Configuration/DefendTheWallsAssets.luau` lists the pieces. Until mesh IDs are filled in, everything is built from Parts.

## Build and test

```bash
rojo build default.project.json -o Enfleshed-Defend-The-Walls.rbxlx
ENFLESHED_PLACE_FILE=Enfleshed-Defend-The-Walls.rbxlx python3 tests/test_place_references.py
```

Open that place in Roblox Studio and press **Play**. For cooperative testing use Studio's **Test > Start** with 2–4 players. Confirm the shared timer and integrity, distinct rewards, death and respawn, replay, and that a second run has no old enemies. Test failure by leaving attackers at the gateway or use the Studio helpers below.

On gamepad, use **R2** for primary attack, **L2** for area action, **B** to dash, **Y** to switch equipment, and **L3** to sprint. Touch devices receive matching action buttons. Mission start, replay, hub return, and repair use GUI buttons or Roblox ProximityPrompts.

To test real persistence, publish a private test experience, enable **Game Settings > Security > Enable Studio Access to API Services**, keep `Studio.Accelerated = false`, and leave and rejoin after a completed mission. DataStore reads and writes cannot be verified by a Rojo build alone.

For fast lifecycle tests, set `Studio.Accelerated = true` in the mission configuration and rebuild. This uses a 120-second defense and **mock progression only** by default. In Studio's **server** Command Bar during an active run, use:

```lua
require(game.ServerScriptService.Server.Services.DefendTheWallsService).debugFinish(true)
require(game.ServerScriptService.Server.Services.DefendTheWallsService).debugFinish(false)
require(game.ServerScriptService.Server.Services.DefendTheWallsService).debugDamage(1000)
```

The helpers are restricted to Studio with accelerated mock progression. Repeat three runs in one server and inspect `Workspace.DefendTheWalls.MissionEnemies` and the `Workspace.DefendTheWalls` counters. Normal duration, phase times, enemy caps, gateway damage, repair charges, and rewards are centralized in the mission configuration.

The mission uses a separate compact arena outside the generated battlefield. The original sandbox remains reachable through the staging prompt. No checked-in place file is automatically synchronized with source edits; rebuild or use `rojo serve default.project.json` before Studio tests.

## Spell progression verification

Use a private Studio test with `DevelopmentSandbox.Enabled = false` to exercise live rules. New profiles should receive Ember Dart, Frost Needle, and Arc Lance; slots 5–9 should show as locked. Complete missions, buy a spellcraft unlock and a spell rank in Grimoire > Library > Upgrades, and verify Marks persist after rejoining. Try equipping a locked showcase spell, a high-cost spell without its rank, and a saved spell in a locked slot; all three should fail without deleting the saved spell or its assignment. The Studio development sandbox remains unrestricted when `DevelopmentSandbox.Enabled = true`.
