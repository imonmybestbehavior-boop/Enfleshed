# Enfleshed

A deliberately small Roblox multiplayer movement/melee sandbox. Implemented:
sprinting, a predicted directional dash, a three-hit light combo, server-owned
hit detection/damage, one resetting target dummy, and minimal debug feedback.
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
built instance tree and verifies that the build contains current source. This
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
| `server/init.server.luau` | Explicitly starts the sandbox and action router. |
| `server/Networking/ActionRouter.luau` | Creates remotes, validates/rate-limits requests, owns per-player state/lifecycle, and runs one server update loop. |
| `server/Services/MovementService.luau` | Authorizes sprint/dash, tracks cooldown/distance budgets, checks dash obstacles, and corrects obvious movement violations. |
| `server/Services/CombatService.luau` | Owns combo progression/timing, samples active swings, and deduplicates targets across each swing. |
| `server/Services/HitDetectionService.luau` | Server-oriented box queries, living-Humanoid resolution, reach/facing checks, and solid-obstacle raycasts. |
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
