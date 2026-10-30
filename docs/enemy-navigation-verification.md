# Enemy navigation — step 01 verification

Status: **step 01 fixture validation passed in connected Studio** on 2026-10-19. Final run `96afed25-9c98-441c-a34f-8490e4a86adc`: 55/55 trials, 132/132 actors, zero path-compute failures, current fallback R6 rigs. Four fresh close-combat smoke tests also passed. See sections 10–11 of `gameplay-implementation-status.md` for reproduced failures, corrections, preserved evidence and precise limitations. The original absence of exposed Studio tools was an access issue, not a disconnected Studio.

## Scope and changes

- Existing combat HP/damage/speeds/timing, spawn behavior, model scales, magic systems, animation code and path/hit budgets are unchanged.
- The non-colliding HumanoidRootPart now uses the Default collision group instead of the visual-only group. In Studio, a test actor changed from Freefall/Air to Running/Concrete after this isolated change. Visual parts remain in their original group and the colliding hull is unchanged. This restores Humanoid ground queries without enabling root-part body collisions.
- `EnemyNavigation.luau` contains pure decisions for integer body-sized path clearance, floor-aware waypoint completion, jump-action consumption and direct-chase eligibility.
- `EnemyService.luau` uses actual collision-hull dimensions after mission scaling, scaled sweep size/center, R6 standing-floor reference for comparing floor waypoints, and one jump request when approaching each takeoff point. Issued takeoff points can be consumed while rising; their subsequent walk/landing points still check floor height.
- Grounded actors reconcile a nearby walk waypoint with the physical support surface only when its baked height disagrees. A ray starts above both heights so real upper floors retain the existing height requirement; jumps and airborne actors cannot use this fallback. This addresses the live ramp/landing mismatch without widening tolerances.
- A clear body sweep no longer overrides an elevated destination or an upcoming jump action. This preserves path/jump handling rather than treating line clearance as proof of a walkable rise.
- On-demand diagnostics expose path queue/compute timings, failures, blocked signals, waypoint/action, jump requests, hull/agent/sweep geometry, Humanoid state/FloorMaterial, and stuck recovery. No per-frame diagnostic remotes or extra path jobs were added.
- HipHeight, friction and general floor-continuity probing were **not** changed speculatively. The root collision-group correction follows a live isolated grounding experiment; any residual geometry failures still require samples.

Source evidence before the change: XZ-only waypoint advancement could consume an upper-floor point before processing its action; configured agent height stayed 9 after Brute/Elite bodies scaled to 11.25/13.5. Regressions exercise these decisions and the actual production chase closure with controlled vectors/sweep results. This is controller-level reproduction, not simulation of Roblox path generation or contact physics.

## Fixture setup

`src/server/Development/EnemyTraversalFixture.luau` is a dormant ModuleScript. It checks Studio + server before running and is never required by production bootstrap. It changes neither the mission map nor the normal configuration.

1. Use a separate source-synced Studio test session. Do not overwrite the repository's existing `.rbxlx` or lock file. Use Rojo serve into a deliberately selected test place or build a new, separate test output.
2. Press Play and use the **server** Command Bar. No mission/accelerated-mode toggle is needed. The fixture uses the real shared EnemyRuntime at the existing 4 path starts/second, 2 paths in flight and 30 Hz hit-query limits.
3. First run the focused subset:

```lua
local f = require(game.ServerScriptService.Server.Development.EnemyTraversalFixture)
print(f.run({
	Cases = { "Flat", "RaisedEdge", "Stairs", "LowClearance" },
	Kinds = { "Basic", "Swift", "Brute", "Elite" },
	Crowd = true,
	Seconds = 30,
}))
```

Each course runs each selected kind alone and then a crowd of two of each selected kind. Trials end on completion or timeout. Fixture version 2 additionally requires grounded contact to have been observed for each actor; sliding along on the hull while permanently reporting Air no longer counts as a clean pass. A timeout/death is recorded as failure before explicit trial teardown; no enemy is teleported or deleted as navigation recovery. Finished trial actors are destroyed solely to keep later trials from contaminating the shared path budget. Reports remain in server memory until clear.

4. To observe, use the Studio camera around `(2000,100,2000)` and subsequent lanes spaced 128 studs in Z. Keep player characters away from test actors: real target selection remains active and nearby players could distract them. Do not change targeting to force a pass. The standard floor extends from X=-10 to 170 relative to each lane; start is X≈0, finish X=120 and objective X=150.
5. Review the per-trial `[Traversal] ... PASS/FAIL` output. Completion checks crossing the finish region at its expected floor height, not enemy disappearance or mission stuck cleanup. `Fixture.summary()` reports totals. The fixture makes no claim about combat victory or performance targets.

## Full course matrix

Run after the focused subset, keeping the same file revision/configuration:

```lua
local f = require(game.ServerScriptService.Server.Development.EnemyTraversalFixture)
print(f.summary()) -- verify the preceding run has finished
f.clear() -- refuses while a run is active; capture needed report first
print(f.run({ Seconds = 30 }))
```

The default matrix is 11 courses × (4 solo kinds + one 8-enemy crowd) = 55 trials. Allow up to 30 seconds per trial; successful trials end early. Increase only the test timeout to 60 seconds if investigating queue saturation; do not raise the production scheduler budgets.

| Case | Geometry / behavior | What to inspect |
|---|---|---|
| Flat | 180×80 floor, no obstacle | Flat direct chase/standoff remains available; no needless path jobs |
| Curb | .5- and 1-stud raised slabs | Contact, grounding and direct/path decisions |
| RaisedEdge | 4-stud rise onto upper platform | Jump actions, floor-aware progress, landing |
| Stairs | Six 1-stud steps, 8-stud treads, upper landing | Waypoint advancement and each scaled body |
| Ramp | Rise 6 over run 40 | Ground contact and route continuity |
| Slope | Rise 12 over run 40 | Same checks on a steeper, still bounded slope |
| Corner | Connected perpendicular barriers | Repath/turning and clearance around edges |
| Doorway | 12-wide, 18-high opening | Scaled agent fits an actually adequate opening |
| LowClearance | Central lintel bottom at 9.5; open side alternatives | All current standing agents must route around the central lintel; they must not plan a body-impossible central route |
| BlockedPath | Blocker collides from elapsed 1–6 seconds; side alternatives | Forward-blocked handling, queue delay and recovery after opening |
| MovingTarget | Goal root shifts ±12 in Z every 4 seconds | Target movement, stale-route rejection and close approach |

These are **test geometries**, not a certified supported-terrain specification. Contact/voxel behavior and actual paths require Studio observation. Corner/low-clearance courses permit valid detours; taking a detour is not failure. Keep all trials on the same build for comparisons.

## Reading diagnostics and cancellation

```lua
local f = require(game.ServerScriptService.Server.Development.EnemyTraversalFixture)
print(f.summary())
local report = f.report()
if report then
	for i, trial in report.Trials do
		print(i, trial.Case, trial.Passed, trial.Elapsed)
		for actorIndex, actor in trial.Actors do
			print(actorIndex, actor.Kind, actor.Reached, actor.Died, actor.ReachedAt)
		end
	end
end
```

Each trial's `Samples` has .25-second records with actor index and navigation diagnostics. Vectors are serialized as `{X,Y,Z}` for inspection/JSON export through existing Studio facilities. Preserve at least the failing actor's first, last and transition samples, not only the final count. Distinguish the R6 standing-floor reference `Ground` from the separately reported `HullBottom` and actual Humanoid `FloorMaterial`/state. `Ground` uses leg height + half root height + HipHeight below the root; hull contact alone is not proof of Humanoid grounding. Version 2 requires observed non-Air contact for every actor.

To stop, call `require(...EnemyTraversalFixture).cancel()`; wait until summary reports Cancelled/Finished/Error, then clear explicitly. Never call clear on an active run. Every new run requires clear first so reports are not silently overwritten. The fixture is isolated from mission-owned StuckRemoved cleanup; a missing or dead actor is not a successful traversal.

## Automated verification

Run with the actual installed Luau executable and Python UTF-8 mode. On this Windows environment, use a writable temporary directory for child test harnesses (`TEMP`/`TMP`); the default sandbox temp directory failed permissions during step 00.

```text
python -X utf8 -B scripts/run_luau_unit_tests.py C:/Users/bello/.rokit/bin/luau.exe enemy_navigation
python -X utf8 -B scripts/run_luau_unit_tests.py C:/Users/bello/.rokit/bin/luau.exe
stylua --check src/server/Services/EnemyService.luau src/shared/Modules/EnemyNavigation.luau src/server/Development/EnemyTraversalFixture.luau tests/test_enemy_navigation.lua
```

The navigation test compiles the Roblox-facing service/fixture but does not execute their engine APIs. It extracts and runs the actual chase closure with controlled dependencies to test upper floors, jump issuance/advancement, approaching takeoff, flat direct chase, melee standoff and budgeted stuck recovery. The pure tests cover measured body-sized integer clearances for all four kinds and floor/jump decisions. Map packaging tests and a fresh temporary Rojo build provide additional integration checks; neither proves live motion.

## Required evidence before declaring step 01 complete

- Source/build identity and configuration used; actual Studio server/client observations.
- Each current mission kind, solo and in crowds, on each supported obstacle; moving targets and temporary blockers included.
- Actual measured HullSize/SweepSize/AgentRadius/AgentHeight, root and hull-bottom heights, FloorMaterial/state, queue/compute times, waypoint/action/index, jump requests and stuck recoveries.
- No test relies on production StuckRemoved deletion, teleportation or increased budgets for success.
- No changes to existing balance, magic, attack/animation behavior or production-map geometry.
- Residual failures explicitly recorded with samples. Without this evidence, step 01 remains implemented but awaiting runtime validation; do not move to step 02 or claim all terrain works.

## API references consulted

- [Roblox pathfinding guide](https://create.roblox.com/docs/characters/pathfinding): path actions, blocked paths and engine movement/grounding guidance. Existing MoveTo architecture was preserved rather than replaced wholesale.
- [PathfindingService.CreatePath](https://create.roblox.com/docs/reference/engine/classes/PathfindingService#CreatePath): agent height/radius are integer clearances. Bounds are rounded upward so they do not understate measured hull size.

- [Humanoid.HipHeight](https://create.roblox.com/docs/reference/engine/classes/Humanoid#HipHeight): the R6 standing-height formula used by the waypoint floor reference. Agent height also includes the physical hull top above this standing floor.

## Verified terrain and remaining boundaries

All eleven courses above passed with four solo kinds and an eight-enemy mixed crowd on the same final source. This certifies these bounded fixture cases, including side detours where appropriate; it does not certify arbitrary production map geometry, imported replacement rigs, guard routes or client animation quality. No production map or saved place was changed. Maximum observed queue wait 1.823 seconds, compute .121 seconds, trial 10.55 seconds; original global budgets were preserved. Occasional single crowd startup recoveries completed through the existing scheduler.

Evidence: `C:/Users/bello/.codex/visualizations/2026/10/19/01a155dd-ba09-7002-a0df-aa0ec505db4b/navigation-live/final-matrix.json` and `final-samples.json`. Source checks passed: 70/70 standalone Luau tests, focused formatting and fresh temporary Rojo build. Temporary Studio Edit staging is restored after verification without saving/publishing; the repository source retains the fix for normal source sync. Stop after step 01.
