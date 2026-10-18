# Game Modes

Every round-based mode runs on `src/server/Services/ModeRunner.luau`. A mode file supplies only its content as a `ModeDefinition`; see `DefendTheWallsService.luau` for the reference implementation.

## What ModeRunner owns (do not re-implement in a mode)
- State machine: `IDLE → PREPARING → ACTIVE → VICTORY/DEFEAT → REWARDS → CLEANUP → READY_FOR_REPLAY`.
- Client requests on the mode's remote: `State`, `Start`, `Join`, `Replay`, `Hub` (0.3 s per-player throttle), feature-flag gate (`FeatureFlags.enabled(definition.Id)`).
- Participants: max size, late join, replay queue, leave/abandon, death and damage/kill attribution (any model whose `MissionId` attribute equals `runner.RoundId`).
- Rewards: `Progression.commit` keyed by round id (idempotent), result screen message, shutdown rewards (`Interrupted`), analytics (onboarding, progression start/end, economy).
- Snapshots: `MissionState` with `Mode`, `State`, `Id`, `Remaining`, `Duration`, `Participants`, `Joined`, `Profile`, `SaveAvailable` + the mode's own fields.

## What a mode supplies
| Hook | Purpose |
|---|---|
| `build(runner) -> Folder` | create the arena once; folder receives metric attributes |
| `duration(runner)` | ACTIVE length in seconds |
| `timeoutOutcome` | `true` = timer end is a victory (survival), `false` = defeat (race) |
| `prepare(runner)` | reset mode state for a new round (tag objectives with `runner.RoundId`) |
| `activate(runner)` *(opt)* | ACTIVE starts |
| `outcome(runner, now)` | checked first each second; return `true`/`false` to end the round |
| `tick(runner, now)` | each second while ACTIVE (spawns, phases) |
| `cleanup(runner)` | remove round content |
| `reward(runner, data, victory)` | XP/Marks formula |
| `newParticipant()` *(opt)* | extra per-player counters |
| `snapshot(runner, message)` | add mode fields to `MissionState` |
| `progressLabel(runner)` *(opt)* | number reported to analytics (e.g. phase) |

Also set `Id` (analytics path + feature flag name), `Remote`, `Preparation`, `Results`, `MaxParticipants`, `ParticipantAttribute` (spawn routing in `ActionRouter`).

## Adding mode #2
1. New `RemoteEvent` in `default.project.json` and `init.server.luau` (each mode has its own remote).
2. Add `<Id> = { Enabled = true }` to `Configuration/FeatureFlags.luau`.
3. Write `<Mode>Service.luau` with a definition; call `ModeRunner.new(def).start()` from its `start()`; add it to `init.server.luau`.
4. Route its `ParticipantAttribute` to a spawn point in `ActionRouter.characterAdded`.
5. Client: a controller for its HUD (reuse `MissionController` patterns; messages carry `Mode`).

Not yet generic: the hub/sandbox prompt and spawn routing live in Defend the Walls / ActionRouter; a mode-select hub arrives with mode #2.
