# Enfleshed

A deliberately small Roblox multiplayer movement/melee sandbox. Implemented:
sprinting, a predicted directional dash, a three-hit light combo, server-owned
hit detection/damage, one resetting target dummy, temporary waves of Stage 1 Enfleshed test enemies,
minimal debug feedback, and a server-authoritative Magic Runtime V1.
No external runtime dependencies or frameworks are used.

## Build and tools

`rokit.toml` pins Rojo **7.7.0** and StyLua **2.5.2**. With Rokit installed,
run `rokit install` to install those tools.

```bash
stylua --verify src tests/test_sandbox_tuning.lua
stylua --check src tests/test_sandbox_tuning.lua
lua tests/test_sandbox_tuning.lua
lua tests/test_spell_definitions.lua
rojo build default.project.json -o Enfleshed.rbxlx
python3 tests/test_place_references.py
git diff --check
```

Open `Enfleshed.rbxlx` in Studio. For subsequent source changes, run
`rojo serve default.project.json` and connect the matching Rojo Studio plugin
to localhost port 34872. Alternatively, rebuild and reopen the place.
Stop playtesting before syncing changes and restart the session afterward;
required modules and runtime state do not hot-reload automatically.

Rojo validates serialization and mappings, and StyLua parses/formats Luau.
`tests/test_place_references.py` checks literal Shared module lookups against the
built instance tree, validates direct script-relative module references, and
verifies that the build contains current source. This
regression check catches misspelled folder names that would otherwise wait forever.
`tests/test_sandbox_tuning.lua` uses system Lua to check the actual configuration
for combo lethality, timing, forgiving health, and hull/navigation dimensions;
it substitutes only Vector3 data and adds no game dependency.
Neither these checks nor the build runs Roblox physics or type-checks the scripts. Check Script Analysis
and server/client Output in Studio in addition to the playtests below.

## Controls and initial tuning

| Input | Action |
| --- | --- |
| WASD | Standard Roblox movement |
| Space | Standard Roblox jump |
| Hold left Shift | Sprint; release to walk |
| Q | Dash in movement direction, or character-facing direction when stationary |
| Left mouse click | Light attack; click again near recovery to chain |
| 1 | Cast Fireball toward camera aim |
| 2 | Cast Body Burst in facing direction |
| Hold/release 3 | Charge/release Stone Shot; aim at the Earth source |

Keyboard/mouse only in this sandbox. Sprint clears when the window loses focus,
a text box is focused, or the character dies/respawns. Attacks never change
WalkSpeed or movement momentum. Dash and attack execution cannot overlap.
There are no invulnerability frames, stamina, block, heavy attacks, knockback,
or generalized stun/status systems. Successful light hits briefly flinch this basic enemy only. The spawn has no temporary ForceField protection.

Edit **`src/shared/Configuration/Sandbox.luau`** for all gameplay tuning:

- Player max health: 400, restored on each spawn (temporary stress-test balance).
- Walk/sprint: 16 / 28 studs per second.
- Dash: 14 studs over 0.18 seconds, 0.8-second cooldown measured from acceptance.
- Combo damage: 24, 26, 30; each attack has startup, active, recovery, hitbox size,
  forward offset, and reach settings. One target takes damage once per swing.
- Combo resets 0.85 seconds after recovery ends. The last 0.18 seconds before
  the next attack can start accept a buffered click. Holding click does not repeat.
- Dummy: 100 HP, at `(0, 3, -18)`, replaced two seconds after defeat.
- Networking limits, movement-validation tolerances, and feedback duration also
  live in this configuration. Visual layout and dummy geometry are local placeholders.
- `Magic` holds temporary player mana/Locus metrics and aim limits. Registered
  spell data lives in `shared/Configuration/Spells.luau`.

## Magic Runtime V1

Magic is registered structured data interpreted by `MagicService`; spell names
do not select spell-specific server systems. Fireball, Body Burst, and Stone Shot
each declare their source, form, targeting, geometry, motion, casting, lifetime,
cost, payloads, and triggers. A further simple projectile should only need a new
definition using these existing component values.

The client sends a registered spell ID plus bounded aim data. It never sends
damage, costs, targets, hit results, charge duration, or spell definitions. The
server measures charge time, retrieves and validates data, calculates costs,
consumes material, moves logical projectiles with swept raycasts, queries targets,
and applies damage through `DamageService`.

Temporary magic stats start at 120 mana on each spawn. Mana demand, Locus strain,
and complexity remain separate. `VALID` executes normally. `UNSAFE` executes
with a debug warning; a nearly full charged Stone Shot reaches the default safe
strain threshold. `IMPOSSIBLE` executes nothing, including for invalid spell/aim,
insufficient mana, early charge release, or absent Earth material.

The brown block at `(-9, 1.5, -12)` has the `MagicMaterialSource` tag plus
`MagicMaterial = "Earth"` and `AvailableAmount = 50`. Aim at it, hold **3** for
at least 0.15 seconds, then release to consume one amount and launch Stone Shot.
It resets when Studio Play restarts. This is a small environmental interface, not
terrain manipulation or a material framework.

Fireball proves Projectile + OnImpact + Explode. Body Burst proves a cone query
with Damage and Force payloads; Force changes velocity only. Stone Shot uses the
same generic projectile executor as Fireball but adds charged casting and a
material requirement. Visuals are temporary debug primitives separate from hit
geometry.

V1 intentionally excludes awakening, spell editing, persistence, progression,
unlocks, further principles/expressions, beams/fields/auras/constructs, complex
conditions, sustained commands, status effects, terrain destruction, and polished
visuals/audio/animations.

## Focused combat tuning pass

These are temporary stress-test values, not progression or final balance.
All durations below are seconds; each phase column is startup / active / recovery.

| Attack | Previous phases (total) | Current phases (total) | Damage before → after |
| --- | --- | --- | --- |
| Light 1 | 0.08 / 0.12 / 0.18 (0.38) | 0.05 / 0.08 / 0.12 (0.25) | 10 → 24 |
| Light 2 | 0.09 / 0.12 / 0.18 (0.39) | 0.06 / 0.08 / 0.12 (0.26) | 12 → 26 |
| Light 3 | 0.12 / 0.14 / 0.28 (0.54) | 0.09 / 0.10 / 0.19 (0.38) | 18 → 30 |

Total including final recovery: **1.31 → 0.89 seconds**. These are ideal chained
server timings, excluding input/network delay. Third-hit onset is 0.89 → 0.60
seconds. The third hit remains more committal; Q is usable once its recovery ends.
Player movement speed is never reduced by attacking. Other changes: max health
100 → 400, sprint 25 → 28 studs/second, dash cooldown 1.1 → 0.8 seconds.

Basic-enemy light-hit flinch is **0 → 0.16 seconds**. Only successful server
light damage triggers it. A hit during orange windup cancels that attack and its
box immediately; the enemy pauses, then must start a fresh windup. An already
active strike finishes before flinching. Existing recovery is not shortened;
repeated hits refresh the short pause rather than adding durations. Death removes
the reaction callback. There is no generalized status framework or player flinch.

Visible enemy parts are non-colliding. One invisible, root-welded upright cylinder
provides body-blocking: diameter 2.8 studs, height 9, center 1.5 above the root,
with friction 0. Its straight sides remove limb ledges and its tall cap discourages
normal jump/step climbing. Navigation clearance matches the hull. Both player/enemy
and enemy/enemy collisions remain enabled. Combat overlap queries include the
visible rig and exclude the enlarged hull, so its height does not enlarge the
damage target. Solid-obstacle checks remain enabled. This temporary tall shape
needs Studio physics testing, especially near elevated surfaces and low ceilings.

### Focused Studio checks

1. Stop Play and reopen the rebuilt `Z:\home\deck\Projects\Enfleshed\Enfleshed.rbxlx`.
   Press F5. Verify 400 player HP and no errors in Output.
2. Engage the wave-1 enemy and chain three left clicks. Expect enemy health
   **80 → 56 → 30 → 0**. Try Shift movement throughout, then Q after final recovery.
3. Strike during the orange windup: the box should disappear, `SandboxState`
   briefly reads `Flinch`, and that canceled attack must cause no damage. Let a
   red active strike begin before hitting: it may still damage you.
4. Walk, sprint, jump, and dash into enemies from several directions. Their bodies
   should block you without limbs becoming stairs. Check wave 20 for stacking,
   unwanted lifting, or new bottlenecks. No crowd steering was added.
5. Reset three times, including immediately after dashing. Verify 400 HP, correct
   spawn placement above the floor, working controls, and unchanged wave progress.
   Repeat with two clients; damage and enemy deaths must agree on both clients.

## Architecture and files

The existing `default.project.json` mappings are unchanged:

| Source | Roblox location |
| --- | --- |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) |
| `src/server` | `ServerScriptService.Server` (Script) |
| `src/shared` | `ReplicatedStorage.Shared` (Folder) |

Rojo maps each `init.*.luau` directory to its entry script; Controllers and Services
are Folder children of those scripts. The client script runs from PlayerScripts.
Server modules and state never replicate. Shared configuration/types are public.
The baseplate, lighting, sound settings, formatter configuration, and tool pins
are preserved. Empty future-use folders remain available without dummy modules.

Every sandbox module is listed below; paths are relative to `src/`.

| File | Responsibility |
| --- | --- |
| `client/init.client.luau` | Wires controllers, sends sequenced action requests, dispatches feedback, and resets on character lifecycle changes. |
| `client/Controllers/InputController.luau` | ContextActionService bindings and sprint release on focus changes. |
| `client/Controllers/MovementController.luau` | Immediate local sprint/dash prediction, dash collision sweeps, cleanup, cooldown feedback, and rejected-prediction cancellation. |
| `client/Controllers/CombatController.luau` | Predicted swing boxes, one buffered click, combo reconciliation, and other players' approved swing effects. |
| `client/Controllers/MagicController.luau` | Collects camera aim for temporary spell shortcuts and sends only cast intent. |
| `client/Controllers/DebugController.luau` | Minimal HUD plus server-confirmed per-target outline/damage numbers, combo/dash feedback, and shared wave/living count. |
| `server/init.server.luau` | Explicitly starts the sandbox, action router, and temporary wave stress test. |
| `server/Networking/ActionRouter.luau` | Creates remotes, validates/rate-limits requests, owns per-player state/lifecycle, and runs one server update loop. |
| `server/Services/MovementService.luau` | Authorizes sprint/dash, tracks cooldown/distance budgets, checks dash obstacles, and corrects obvious movement violations. |
| `server/Services/CombatService.luau` | Owns combo progression/timing, samples active swings, and deduplicates targets across each swing. |
| `server/Services/MagicService.luau` | Interprets registered V1 spell data: validation, charge timing, cost/material handling, logical projectiles, geometry queries, and payload execution. |
| `server/Services/HitDetectionService.luau` | Neutral model/origin/box query with caller-supplied target policy, optional reach/facing limits, and solid-obstacle raycasts; returns living Humanoids. |
| `server/Services/EnemyService.luau` | Creates independent enemy handles with update/cleanup/path-job functions; preserves combat states, fixed telegraphs, and damage. |
| `server/Services/SandboxStressService.luau` | Temporary wave creation/cleanup, spaced spawn layouts, one shared enemy update connection, and round-robin path admission. |
| `server/Services/DamageService.luau` | Applies server-only Humanoid damage and returns actual health removed. |
| `server/Services/SandboxService.luau` | Creates a spawn and one anchored dummy with health text and a delayed replacement on death. No NPC framework. |
| `shared/Configuration/Sandbox.luau` | Central movement, attack, dummy, networking, and debug tuning. |
| `shared/Configuration/Spells.luau` | Registered data definitions for Fireball, Body Burst, and Stone Shot. |
| `shared/Types/CombatTypes.luau` | Shared Luau attack/request/result/state types. State type declarations expose no runtime player data. |
| `shared/Types/MagicTypes.luau` | V1 cast-intent, validation-result, and active-spell type contracts. |
| `shared/Types/init.meta.json` | Explicitly maps the new Types directory to a Folder. |
| `shared/Networking/Protocol.luau` | Remote names and the three supported action identifiers. |

The existing `init.meta.json` files preserve the Controllers, Services,
Configuration, Networking, Modules, and Utilities folders as Rojo Folders.
`.stylua.toml` specifies Luau syntax, tabs, Unix line endings, and 120-column
wrapping. `README.md` documents each sandbox file and the test procedure.

Attack execution, target queries, and damage application have separate entry
points because this sandbox uses all three. There is no generic ability system,
service locator, automatic module loader, or speculative combat framework.

## Authority and networking

At startup the server publishes `ReplicatedStorage.Shared.SandboxRemotes` with
reliable `ActionRequest` and `ActionFeedback` RemoteEvents.

The client sends the action, increasing sequence, current character, and either
sprint intent or a finite normalized horizontal dash direction. It never sends
an authoritative target, combo step, hit position, or damage amount. Requests
are rate-limited before parsing, and character/state/cooldown checks run on the
server. State is discarded on death, removal, and respawn; feedback is scoped
to the character so old acknowledgements do not mutate a new character.

The server replies with acceptance, combo timing, dash cooldown, and sprint state.
Approved swings are broadcast for presentation; hit/damage feedback goes only
to the attacker. The dummy's server-owned health display replicates to everyone.
The debug combo is predicted initially and reconciled on acknowledgement.

During an attack's active window, the server queries a box positioned relative
to the server-observed root. It excludes the attacker, resolves living targets,
checks reach/facing, raycasts for solid obstacles, and tracks already-hit Humanoids.
Only then does DamageService call TakeDamage. The same path handles the dummy
and other players; each player has independent combo/cooldown/hit state.

A dash starts before sending the request. A temporary local LinearVelocity
constrains horizontal speed, preserving gravity; collision sweeps stop it near
walls. The server approves the cooldown/state, checks movement distance and
obstacle crossings, and temporarily takes network ownership to correct obvious
violations. Rejections/corrections remove local dash constraints. Attack movement
is untouched, including sprint speed.

This retains standard client-owned Roblox character physics. Distance tolerances
are intentionally forgiving of replication jitter; this is not a complete speed,
flight, or teleport anti-cheat. There is no historical hit rewind/lag compensation.
At high latency, a predicted swing can miss on the server. A server hitch that
skips an entire active window produces no hit. Studio latency testing is needed
before treating the initial tolerances as production-ready.

## Respawn movement initialization

The server waits for the new character root to enter Workspace before creating
movement state. For `Movement.SpawnValidationGrace` (one second by default), it
refreshes movement anchors from the live root while Roblox finishes spawn
placement. This only suspends movement corrections: it adds no invulnerability,
health changes, or cooldown reset beyond the existing respawn reset. Horizontal
distance corrections preserve the current root height instead of restoring an
old spawn/jump height. Old-character removal cannot clear a newer character's state.
Roblox documents that CharacterAdded fires before final spawn placement in its
[character loading order](https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacterAsync).

Respawn regression check: reset your character at least three times, including
immediately after dashing, then let enemies kill you and respawn naturally. Each
new avatar should land above the spawn pad, remain on the baseplate, and regain
normal walking/sprinting/dashing. Repeat with two Studio clients and simulated
latency. Wave progress must remain intact. These engine checks must be run in
Studio; build/reference checks alone do not reproduce character spawning.

## Exact Studio test procedure

1. Build using the command above, open `Enfleshed.rbxlx` in Studio, and open Output
   and Script Analysis. Resolve any runtime/type errors before judging feel.
2. Select **Test** and press **F5**. Use Test rather than Run so an avatar spawns.
   Confirm a small debug display, one target dummy, and a spawn pad appear.
3. Walk with WASD, then hold/release left Shift. Attack while sprinting:
   movement should remain at sprint speed. Release Shift while chat is focused
   or switch windows; returning must not leave sprint stuck on.
4. Press Q while moving forward, backward, and sideways, then while stationary.
   The dash must begin immediately and keep its initial direction. Repeated Q
   presses during cooldown must not extend/restart it. Jump and dash to verify
   gravity still acts. Q during attack recovery and attack during a dash must
   not start overlapping actions.
5. Approach the dummy within roughly four studs and face it. Click once, then
   click near each swing's recovery to chain 1 → 2 → 3. On a stationary full combo,
   dummy health must go 100 → 76 → 50 → 20 with hit feedback of 24, 26, and 30.
   Moving out of range should miss. Waiting more than 0.85 seconds after recovery
   resets the next attack to step 1. Very early repeated clicks do not skip steps.
6. Kill the dummy. Exactly one replacement with 100 HP should appear two seconds
   later. An attack must not damage yourself, a dead dummy, or the same Humanoid
   more than once per swing even when several body parts overlap the box.
7. Stop the session. In edit mode add an anchored, collidable Part with Size
   `(12, 12, 1)` and Position `(0, 6, -15.5)`. Start Test again: from the spawn side,
   attacks must not damage the dummy through this wall, and dashes must not pass
   through it. Stop and delete this temporary test wall afterward.
8. Select **Server & Clients**, set **2** clients, and press **F7** (or Play).
   In each client, approach the dummy. Both must see identical health changes;
   only the attacker sees their hit marker/damage. Each sees the other's swings.
   Stand the players near each other and attack: the victim's health must change
   on the server, with independent combos and dash cooldowns for each player.
9. Reset a character during/after a swing and dash. Respawn at normal walk speed
   with fresh combo/cooldown state, no leftover dash constraint, and working input.
   Disconnect one client; the other must continue functioning without Output errors.
10. Repeat movement, combos, and wall checks with Network Simulator latency enabled
    (start with approximately 100 ms in each direction, then add modest jitter).
    Dash onset must remain immediate. Check for false corrections during valid
    straight dashes, cooldown reconciliation, and server-confirmed damage only.
    Extreme delay may need different movement tolerances; report it separately
    from baseline responsiveness.
11. In the client Command Bar of a fresh playtest, send a malformed request:
    `game.ReplicatedStorage.Shared.SandboxRemotes.ActionRequest:FireServer("invalid")`.
    It should cause no error or damage, and normal controls should still work.
    Also inspect the server view: no client-provided target/damage is used, and
    replicated visual SwingPreview parts cannot cause damage.
12. End the session and inspect both server and client Output. Record movement
    feel and desired tuning changes in Sandbox.luau; stop/restart after edits.

Studio UI reference: [testing modes](https://create.roblox.com/docs/studio/testing-modes)
and [Network Simulator](https://create.roblox.com/docs/studio/network-simulator).


## Temporary enemy wave stress test

This is a disposable sandbox harness, not a production spawning system.
The waves are **1 → 5 → 10 → 20** identical Stage 1 enemies. When the last enemy
in a wave dies, the next wave starts after three seconds. After the last wave,
the HUD says **Stress test complete** and no more enemies spawn. Player death
and respawn do not restart the wave; restarting Studio Play starts again at wave 1.
There is no XP, loot, difficulty scaling, pooling, or crowd-steering system.

### Configuration and placement

`StressTest` in `src/shared/Configuration/Sandbox.luau` contains wave sizes,
inter-wave delay, corpse lifetime, arena center, ring radius/minimum spacing,
spawn clearance/attempts, hit sampling rate, and the shared path budget.
Enemy combat stats remain in `Enemy` and stay constant across waves.

Enemies spawn on a ring centered at **(35, 3, -35)**. The default first enemy is
at **(35, 3, -59)**. Walk right and forward from the player spawn toward the arena
center to engage the wave. Minimum spacing is eight studs; the radius expands
for larger counts. At the default center, all 20 ring positions are within the
28-stud detection range. Placement avoids the dummy, spawn pad, current player
positions, collidable obstacles, and the edge of this specific baseplate. If all
candidate layouts are occupied, the HUD reports a blocked spawn area and retries.
No partial wave is created. Players can move toward distant survivors to finish.

### Scaling controls and intentional tradeoffs

- One Heartbeat connection updates all enemy handles. Navigation/detection use
  the existing 0.1-second interval, with staggered initial offsets. Cheap state
  timing runs every frame. Player combat's existing loop is unchanged.
- Enemy hitbox queries occur only in the 0.12-second damaging window, capped at
  `HitQueryRate = 30` per second per attacking enemy. There are no catch-up query
  bursts after slow frames, and each victim still takes damage once per swing.
- Clear routes use direct pursuit. Blocked/stalled routes request pathfinding.
  Each enemy can have one pending/in-flight request, and its existing retry
  interval remains. Pending jobs receive round-robin admission across the wave.
  Valid old paths can still be followed while waiting for a replacement.
- **`PathStartsPerSecond = 4` and `MaxPathsInFlight = 2` are configurable test
  defaults, not architectural limits.** Starts are paced evenly, without bursts
  after frame stalls. If 20 enemies all need an initial path, admission alone
  can take roughly five seconds at this default, and slow computations can add
  delay. This hesitation is explicitly something to measure and compare.
- `StressTest.EnemyCollisions = true` enables enemy-to-enemy physical collision
  so rigs no longer deliberately pass through each other. Navigation sweeps still
  exclude the enemy folder to avoid treating every crowd member as a static wall.
  Crowds can now form bottlenecks or push each other; no crowd steering has been
  introduced. Set this flag false only for comparison with the old overlapping case.
- **Player/enemy physical collision remains enabled. Crowd body-blocking is
  deliberately under evaluation.** Do not interpret an inability to pass through
  enemy bodies as automatically a path-budget failure. Walls remain solid, and
  the existing attack obstruction checks remain in force.
- Death cancels debug effects, pending routes and connections once, and removes
  the handle from active updating on the next shared update. Corpses immediately
  become non-collidable/non-queryable and are removed after two seconds. Each
  wave clears remaining old handles. In-flight computations cannot be interrupted
  through ComputeAsync; their results are invalidated and destroyed when they
  return, and their slots are released even on errors. The update connection
  stops after final corpse cleanup. No state persists across Studio sessions.

Collision filtering follows Roblox's [collision group APIs](https://create.roblox.com/docs/reference/engine/classes/PhysicsService).
The remaining geometry, movement physics, and navmesh behavior need Studio testing.

### Debug inspection

The normal HUD adds wave/total, living enemies, an inter-wave countdown, or
completion. These come from server-owned attributes on `Workspace.SandboxStressTest`.
Late joiners see the same state. There are no new action remotes or per-enemy HUD
connections. `Workspace.SandboxStressTest.Enemies` contains the current rigs.

In the server Explorer, select `SandboxStressTest` and inspect Attributes:

| Attribute | Meaning |
| --- | --- |
| `Wave`, `TotalWaves`, `LivingEnemies`, `Status` | Shared wave state |
| `PendingPaths` | Live enemies waiting for a shared path slot |
| `PathsInFlight` | Computations currently running; may briefly lag between metric updates |
| `PathsStarted` | Total admitted path jobs since the test started |

An enemy's `PathQueued` and `SandboxState` attributes help distinguish a waiting
path job from Telegraph, Recover, or an idle enemy that has not detected a player.
Counters refresh at the think interval; they are diagnostic, not a full profiler.

### Enemy combat behavior

Enemies have 80 HP, deal 12 damage, and keep the existing idle → chase → telegraph
→ attack → recovery behavior. The 0.7-second orange windup and red hit box are
only temporary debug effects. Facing/location commit at the start of windup:
sideways/backward dashes out of the fixed box still dodge. The enemy is stationary
through recovery; attacks do not track players after commitment. Health and damage
remain server-owned through the existing neutral HitDetectionService and
DamageService. The target dummy, sprinting, player combos, and normal Roblox
player death/respawn remain available.

### Exact Studio stress-test procedure

1. Build using the commands at the top of this README. Stop and close the old
   place without overwriting the rebuilt file, then reopen:
   `Z:\home\deck\Projects\Enfleshed\Enfleshed.rbxlx`.
2. Press **F5 / Test**. Verify **Wave 1/4 | Living 1**. Walk toward the arena
   center `(35, 3, -35)`; the first enemy begins at `(35, 3, -59)`.
3. Check the original combat: orange telegraph, fixed red attack box, sideways
   **A/D + Q** dodge, left-click combo, and **Shift** sprint. One enemy strike
   should remove 12 HP; your full combo removes 80 HP, defeating an untouched 80-HP enemy.
   Player health starts at 400 on initial spawn and respawn.
4. Defeat every enemy in turn. Expect living counts **1, 5, 10, 20** at the start
   of their respective waves and a three-second countdown between waves. Old
   corpses should disappear in two seconds. After wave 4, verify completion,
   living 0, no remaining enemy rigs/debug boxes after cleanup, and no new wave
   even after waiting another ten seconds.
5. Reset your character during a wave. Verify normal respawn and controls, with
   unchanged wave progress. Stop/restart Play: wave and path counters must reset
   and there should be only one `SandboxStressTest` folder.
6. For a navigation-only comparison, temporarily set `WaveSizes = { 20 }` in
   Sandbox.luau, rebuild/reopen, and restore `{ 1, 5, 10, 20 }` afterward. No enemy
   stats need changing. Stand near the center to acquire all 20. On the empty
   baseplate, direct pursuit should dominate. Inspect path counters and Output.
7. While testing, switch to the **server** view and use its Command Bar to add
   an obstacle after the enemies have noticed you:
   ```lua
   local wall = Instance.new("Part")
   wall.Name = "StressTestWall"
   wall.Anchored = true
   wall.Size = Vector3.new(24, 10, 2)
   wall.Position = Vector3.new(35, 5, -28)
   wall.Parent = workspace
   ```
   Return to the client and lure enemies around this wall. Watch `PendingPaths`,
   `PathsInFlight`, and changes in `PathsStarted`. Note waiting time and whether
   a low admission budget stalls enemies without usable paths. The temporary
   wall disappears when Play stops; recreate the same obstacle for comparisons.
8. Repeat the same 20-enemy obstacle scenario with `PathStartsPerSecond = 12`
   and `MaxPathsInFlight = 4`, rebuilding/restarting after config changes. Compare
   hesitation, frame time, and path backlog against **4 / 2**. These are trial
   settings, not a recommended final budget. Restore defaults after comparing.
9. Deliberately move into a crowd and dash against enemy bodies. Player/enemy
   and enemy/enemy collision should remain solid. Rigs should not deliberately
   occupy the same space. Record crowd bottlenecks, pushing, or climbing separately
   from pathfinding delays; enabling collisions is not a crowd-steering solution. Check for attacks hitting through walls
   and false movement corrections while surrounded.
10. Select **Server & Clients → 2 clients → F7**. Both clients should show the
    same wave and living count. Kill enemies from both clients, reset/disconnect
    one client, and finish a wave: it must advance exactly once. Verify late
    joiners see current state and no duplicate rigs appear.
11. Inspect server and client Output, Script Analysis, and Studio performance
    tools. Compare the same scene at 1, 5, 10, and 20 enemies; watch server frame
    time, physics cost, path backlog, and instance/memory trends after each wave.
    Compare with `Enemy.DebugTelegraph = false` to separate temporary debug-effect
    rendering cost from AI cost. Restore it afterward for dodge testing.

Formatting, build and reference checks do not execute Roblox AI/physics and do
not establish a measured 20-enemy performance result. Run the Studio scenarios
above before drawing conclusions about budget size or combat feel.


### Target readability check

Each wave enemy now has a distinct overhead label (`Enfleshed 01`, etc.). A
server-confirmed player hit briefly outlines that specific target in white and
shows a damage number above its head. The attacker HUD also names the target.
Each target hit by a swing receives its own feedback; misses produce none.
The effects are local temporary debug feedback, automatically removed by Debris,
and replaced rather than piled up when the same target is hit again. They do
not change hit detection, damage, or the enemy's orange/red telegraph.

In wave 5 or 10, attack a front enemy while others stand nearby. Confirm the
numbered enemy losing health is the one that flashes and receives a number;
nearby unhit enemies should not flash. Test a miss and a swing reaching multiple
targets. In a two-client test, each client should see feedback only for their own
confirmed hits. Also check whether physical crowd bottlenecks need further work.
