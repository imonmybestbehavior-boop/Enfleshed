# Enfleshed

A deliberately small Roblox multiplayer movement/melee sandbox. Implemented:
sprinting, a predicted directional dash, a three-hit light combo, server-owned
hit detection/damage, one resetting target dummy, one combat-capable Stage 1 Enfleshed test enemy,
and minimal debug feedback.
No external runtime dependencies or frameworks are used.

## Build and tools

`rokit.toml` pins Rojo **7.7.0** and StyLua **2.5.2**. With Rokit installed,
run `rokit install` to install those tools.

```bash
stylua --verify src
stylua --check src
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

Keyboard/mouse only in this sandbox. Sprint clears when the window loses focus,
a text box is focused, or the character dies/respawns. Attacks never change
WalkSpeed or movement momentum. Dash and attack execution cannot overlap.
There are no invulnerability frames, stamina, block, heavy attacks, knockback,
or stun mechanics. The spawn has no temporary ForceField protection.

Edit **`src/shared/Configuration/Sandbox.luau`** for all gameplay tuning:

- Walk/sprint: 16 / 25 studs per second.
- Dash: 14 studs over 0.18 seconds, 1.1-second cooldown measured from acceptance.
- Combo damage: 10, 12, 18; each attack has startup, active, recovery, hitbox size,
  forward offset, and reach settings. One target takes damage once per swing.
- Combo resets 0.85 seconds after recovery ends. The last 0.18 seconds before
  the next attack can start accept a buffered click. Holding click does not repeat.
- Dummy: 100 HP, at `(0, 3, -18)`, replaced two seconds after defeat.
- Networking limits, movement-validation tolerances, and feedback duration also
  live in this configuration. Visual layout and dummy geometry are local placeholders.

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
| `client/Controllers/DebugController.luau` | One small display for combo step, dash cooldown, and confirmed hit damage. |
| `server/init.server.luau` | Explicitly starts the sandbox, action router, and single test enemy. |
| `server/Networking/ActionRouter.luau` | Creates remotes, validates/rate-limits requests, owns per-player state/lifecycle, and runs one server update loop. |
| `server/Services/MovementService.luau` | Authorizes sprint/dash, tracks cooldown/distance budgets, checks dash obstacles, and corrects obvious movement violations. |
| `server/Services/CombatService.luau` | Owns combo progression/timing, samples active swings, and deduplicates targets across each swing. |
| `server/Services/HitDetectionService.luau` | Neutral model/origin/box query with caller-supplied target policy, optional reach/facing limits, and solid-obstacle raycasts; returns living Humanoids. |
| `server/Services/EnemyService.luau` | Creates one connected placeholder rig; owns idle/chase/telegraph/attack/recovery/death, simple navigation, temporary debug telegraphs, and health display. |
| `server/Services/DamageService.luau` | Applies server-only Humanoid damage and returns actual health removed. |
| `server/Services/SandboxService.luau` | Creates a spawn and one anchored dummy with health text and a delayed replacement on death. No NPC framework. |
| `shared/Configuration/Sandbox.luau` | Central movement, attack, dummy, networking, and debug tuning. |
| `shared/Types/CombatTypes.luau` | Shared Luau attack/request/result/state types. State type declarations expose no runtime player data. |
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
   dummy health must go 100 → 90 → 78 → 60 with hit feedback of 10, 12, and 18.
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


## Stage 1 Enfleshed enemy

One `Stage1Enfleshed` is created per play session at **(35, 3, -35)**, to the
right and forward of the spawn pad. It has 80 HP and moves at 12 studs/second.
The existing dummy remains. The enemy stays dead when defeated; restart Play
for another fight. There is no NPC spawning manager or reward system.

`Enemy` in `src/shared/Configuration/Sandbox.luau` holds every enemy gameplay
setting, including position, health, detection/disengagement distances, speed,
attack geometry/timing/damage, and navigation thresholds. The initial values are
28 studs for detection, 45 for disengagement, 4.5 for attack initiation, a
0.7-second windup, a 0.12-second hit window, a 0.8-second recovery, and 12 damage.

The server selects the nearest visible living player when idle, retains that
target during pursuit, and disengages if they die, leave, or exceed disengagement
range. Direct pursuit uses a body-width collision sweep; only blocked or stalled
pursuit requests a rate-limited path. Blocked paths and sufficiently moved goals
are recomputed. Failed routes stop safely and retry. Asynchronous results are
invalidated when the target/state changes or the enemy dies. Navigation is aimed
at this flat sandbox, not general open-world terrain traversal.

The states are Idle → Chase → Telegraph → Attack → Recover. When telegraphing,
the enemy stops, faces its target once, and commits the attack's world transform.
Its root is anchored through recovery to prevent contact physics moving the
strike. Neither the enemy nor its box follows a dodging player. After recovery,
server-owned movement resumes. An attack may hit multiple players in its fixed
box, but each at most once. A dead or disconnected original target never causes
the attack to redirect to someone else.

The orange box/highlight, red active box, and state label are **temporary debug
feedback only**. `Enemy.DebugTelegraph` disables the box/highlight without changing
combat; leave it enabled while testing dodge timing. These are ordinary replicated
instances with no collision/query participation, not a VFX framework or damage
source. The displayed box is the actual query volume. Contact with body parts in
the box can count, so move fully outside it when testing a dodge.

Both player and enemy combat call the same neutral `HitDetectionService.find`:
`find(attackerModel, originCFrame, boxCFrame, size, rules)`. Rules specify optional
maximum distance, minimum facing dot, line-of-sight enforcement, and a target
predicate. No player/enemy identity logic lives inside this query. EnemyService
supplies a predicate restricting victims to current player characters. Damage
always goes through the existing `DamageService.apply`. Player attacks continue
to hit the dummy, enemy, or other living characters through the original rules.

Player health uses the normal Roblox health bar and Humanoid death/respawn.
Enemy death cancels attacks, clears debug parts, invalidates outstanding paths,
disconnects its update/listeners, and leaves an inert corpse with a Dead label.
No loot, XP, progression, evolution, factions, patrols, or status effects exist.

### Exact enemy Studio tests

1. Run the build/check commands above. Stop the old Studio session and reopen
   the rebuilt `Enfleshed.rbxlx` from disk (do not overwrite it by saving the old
   open copy). Under Wine, paste this into Studio's Open File filename box:
   `Z:\home\deck\Projects\Enfleshed\Enfleshed.rbxlx`.
2. Press **F5 / Test**. Confirm the dummy still appears. Find the enemy to the
   right and ahead at `(35, 3, -35)`. Its label should say **Idle** at the spawn;
   approach within 28 studs with an unobstructed view to see **Chase**.
3. Let it approach. It should stop within about 4.5 studs, show an orange box
   and **Telegraph**, briefly turn red for **Attack**, then show **Recover**.
   Remain inside for one strike: your health should drop from 100 to 88, once.
4. On the next orange telegraph, hold **A or D and press Q** to dash sideways
   fully outside the box. Its orientation/location must remain fixed, and the
   missed attack must not reduce health. Repeat by dashing backward and circling
   behind it. Q has no invulnerability; remaining inside the box can still hurt.
5. Sprint and use left-click combos against it. Movement should remain mobile.
   One full 10/12/18 combo reduces enemy health **80 → 70 → 58 → 40**. Kill it,
   including during a windup: the box must disappear, no later strike may land,
   and it must stay dead. The dummy should still work independently.
6. Restart Play. Stand still and allow nine successful 12-damage strikes to
   verify normal player death and respawn. The enemy should stop attacking the
   dead character, and your new character's movement/combo/dash state should work.
   It may reacquire your new character if you respawn within detection range.
7. For navigation, stop Play and insert an anchored, collidable Part with Size
   `(16, 10, 2)` and Position `(35, 5, -22)`. Start Play, approach around the wall's
   right end near `(46, 3, -27)` until detected, then retreat behind the wall near
   `(35, 3, -10)`. The enemy should route around the wall rather than walk through
   it. While following a path, block that route with another collidable Part in
   the server view: it should replan or stop/retry safely. Remove the test walls
   after stopping. Attacks should never damage through a solid wall.
8. Choose **Server & Clients**, set **2 clients**, and press **F7**. Have one
   player approach first, then bring the second closer: the enemy should retain
   its living, in-range original target. Both clients must see the same enemy
   health/state/telegraph. Let the first player die, disconnect, or move beyond
   45 studs: the enemy should idle or acquire the other visible nearby player.
   Both players can damage it; it must not damage the target dummy.
9. Repeat sideways dodges using Network Simulator with roughly 100 ms latency
   in each direction. There is no lag compensation; very late dodges can reach
   the server after a hit, but the box must never follow the player. Compare this
   separately from baseline responsiveness and tune windup time if necessary.
10. Inspect client/server Output and Script Analysis. Confirm no missing-instance
    waits, path errors, or lingering enemy behavior after death. Source/build
    checks do not substitute for these engine playtests.
