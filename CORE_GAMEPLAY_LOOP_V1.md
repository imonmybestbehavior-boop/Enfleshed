# Core Gameplay Loop V1 — session prototype

This pass changes onboarding and adds a modest living population and server-owned incidents. Phase A geometry, combat abilities, progression and Phase B are outside this pass. The earlier disabled stress waves and contextual Nascent health bars remain intact.

## Opening and equipment

The first character of a server session wakes in the B1 interior. The short opening establishes amnesia, ordinary human life, an ancient nonhuman structure, and the familiar Enfleshed threat. It offers three cloth/skin palettes and one choice: recruit melee weapon **or** recruit magic weapon. A player is held in place during the choice; the camera releases the cursor. The server validates the preset, weapon, character readiness and living Humanoid, and accepts one successful choice per session.

Appearance strips arbitrary accessories and clothing and applies primitive cloth coverings and restrained colors to the existing Roblox rig. This supports the standard R6/R15 part layout; it is not a final cosmetic system. No hair picker, asset downloads or persistence were added. Appearance is applied again after avatar appearance loading and on respawn.

EquipmentService owns the single granted item. The unchosen slot is empty, rather than a second free starting weapon. The equipment slots remain extensible and no class flag is introduced. Resetting the character preserves the choice and palette; starting a new server session presents the opening again.

The assignment HUD is hidden without an active assignment. The compass does not show the unused board as the default objective. The board and existing optional assignment service remain available. No replacement permanent quest marker was added.

## Living city

The default roster has nine human placeholders: two residents, two workers, a shopkeeper, two guards, a patrol and a traveling courier. Nodes are authored in `CityLife.luau`; the hard population cap is 18 including temporary event travelers. Residents/workers move locally, shopkeepers hold their location, guards hold posts, and patrol/courier routes connect existing nodes. Population retries after deaths are delayed 90 seconds. Failed ground checks defer creation rather than placing people in voids.

One 4 Hz update loop handles danger and movement. Civilians, residents, workers and shopkeepers retreat from visible nearby Enfleshed. Guards and patrols approach and use existing DamageService for short-range, cooldown-limited melee. The existing Nascent AI can acquire tagged living humans as well as players; its attack patterns and damage path remain the same. Event objective references let attackers approach their intended human target from farther away.

Names/roles appear through a line-of-sight, eight-stud interaction prompt. **K** gives a short local remark; there are no permanent giant labels or dialogue trees. The figures are primitive humanoids, not final character models or animated citizens.

Navigation uses direct movement when a broad sweep is clear. Blocked routes use the engine pathfinder, at most two human path starts per second, one computation in flight and a four-second per-human retry interval. Dead/removed NPCs invalidate path results. Paths and temporary actors are explicitly released.

## World events

`WorldEvents.luau` defines weights, location categories, counts, timings, rewards and anchors. The director uses unique IDs and the lifecycle Preparing → Active → Resolving → Completed/Failed → Cleanup → location cooldown. It reserves the configured enemy count during preparation, so simultaneous events cannot overbook the six-enemy cap. At most two events coexist. Ordinary random scheduling waits 90 seconds initially and at least 180 seconds between starts; locations then cool down for 480 seconds, or 1,200 for the prototype assault. Frequency is configurable. Counts are inclusive ranges, fixed at 1/1/2/3 by default.

Eligibility requires a living player who has finished the opening, 45–240 studs from the location, an available location and capacity, and valid grounded spawn candidates. Barracks, recruit spawn and the opening room are protected. Enemy hull clearance, player distance and separation are rechecked after preparation. Occluded emergence is preferred; a valid visible position outside the minimum distance is a fallback. If no safe position exists, the event is skipped or fails preparation; it never substitutes the catch floor.

- **LocalAttack:** one Nascent approaches a nearby human at housing, workshop or checkpoint. The protected human must survive and the owned enemy must die. Nearby civilians flee and guards react.
- **TravelIncident:** a supply carrier and guard travel S4 → S5 → S6 independently of player acceptance. One Nascent attacks. Completion requires the carrier to arrive alive and the event enemy to be defeated. Guard death alone does not fail the event.
- **Breach:** two Nascent occupy a qualifying workshop/underground location. Defeat those owned enemies to clear it. There is no successor wave.
- **RampartAssault:** a limited three-Nascent prototype using existing S7 as ArchApproach, S6 as RampartDefenseLine, S5 as MilitaryStaging and S4 as CivilianRetreatArea. These semantic positions are exposed under `Workspace.WorldEvents.Anchors`. During the 25-second warning, nearby guards move to the defense line and nearby civilians withdraw. Attackers approach a defense guard; the guard must survive. Cleanup releases mobilization orders so surviving people resume normal routines. No arch/rampart art was built.

Local attack, breach, travel and assault active timeouts are 180, 240, 240 and 300 seconds respectively. Failed events pay nothing; both outcomes clean up after eight seconds. Location cooldown timestamps are exposed as server-owned `Cooldown_<LocationId>` attributes.

## Participation, rewards and discovery

DamageService exposes actual dealt damage. The director credits only player attackers damaging a model both tagged with the matching EventId and present in that event's owned enemy roster. Five actual damage qualifies. Guard damage and ambient kills do not count.

Travel can also qualify a player through at least 20 seconds and 40 studs spent near the moving carrier. Stationary waiting, being remote from the group and large teleport-like position changes do not contribute. Qualifying players receive 20/25/30/45 Military Scrip for successful local/travel/breach/assault events, automatically once per event. No board return is required. Rewards use the existing session MilitaryScrip attribute; no datastore, XP or new economy is introduced. A disconnected player is not paid offline.

The HUD displays only the nearest event within its discovery radius (80–150 studs), plus brief reward/interaction notices. It adds no map dots and never reveals all active events. Preparation text, fleeing humans and guard/enemy movement are the prototype cues; no new sound/VFX assets were added. The map/compass is preserved. Legacy sandbox debug text and unrestricted development spell keys are hidden/disabled by default; both are available through explicit Studio configuration.

## Runtime ownership and performance

EnemyRuntime centralizes collision-group setup, shared enemy updates and the existing fair path budget independently of disabled stress waves. Ambient, optional assignment and world-event owners create handles there and own their cleanup. Stress-test mode retains its dedicated test coordinator. The configurable enemy path defaults remain four starts/second and two in flight. Hit queries remain limited to active attacks.

Ambient enemies remain a separate population (`Population="Ambient"`); event enemies use `Population="WorldEvent"` and their unique EventId. Ambient cleanup/spawn scans now run once per second instead of every frame, and spawn candidates receive ground and safe-zone checks. Calm defaults cap ambient enemies at six, spawn at most one every 15 seconds and reuse a candidate no sooner than 90 seconds. Ambient kills neither resolve incidents nor award event scrip. Optional assignments and explicitly enabled stress waves can add their own bounded enemies.

## Files created

| File | Purpose |
| --- | --- |
| `src/shared/Configuration/CityLife.luau` | Session opening, appearance palettes, modest human roster and navigation/development settings. |
| `src/shared/Configuration/WorldEvents.luau` | Four event definitions, semantic anchors, frequency, caps, rewards and Studio controls. |
| `src/server/Services/OpeningService.luau` | Validated session choice, spawn placement and appearance reapplication. |
| `src/client/Controllers/OpeningController.luau` | Short opening and preset/weapon selection UI. |
| `src/server/Services/LivingCityService.luau` | Human rigs, contextual interaction, local routines, danger reactions, bounded navigation and event travelers. |
| `src/server/Services/WorldEventService.luau` | Server event lifecycle, owned enemies, local discovery, contribution and automatic rewards. |
| `src/server/Services/WorldEventRules.luau` | Small deterministic cap, outcome and reward rules used by the director and tests. |
| `src/server/Services/WorldSpawnService.luau` | Ground/hull clearance, safe zones, player eligibility and preferred occluded spawn selection. |
| `src/server/Services/EnemyRuntime.luau` | Shared enemy collision initialization, AI updates and path scheduling independent of stress mode. |
| `src/client/Controllers/WorldEventController.luau` | Minimal nearby event and temporary notice HUD. |
| `tests/test_world_events.lua` | Semantic references, defaults, caps, cooldowns, contribution isolation, escort outcomes and exactly-once rewards. |
| `CORE_GAMEPLAY_LOOP_V1.md` | This implementation report and test procedure. |

## Files modified in this pass

- `EquipmentService`: grant one validated starter instead of both weapons.
- `ActionRouter`: opening lifecycle/readiness, requests gated until choice, development spells Studio opt-in.
- `DamageService`: actual damage notification for participation.
- `EnemyService`: tag existing Nascent; allow living human targets and event objective references, retaining the existing combat implementation and contextual health UI.
- `AmbientEnemyService`: shared runtime, safe grounded spawns, slower population scans.
- `AssignmentService`: shared runtime, dead-handle cleanup, preserve already-owned scrip.
- `EquipmentController`: synchronize equipped slot from replicated attributes across respawns and late startup.
- `CameraController`, `InputController`: release cursor and suppress combat input during the opening; gate development spell shortcuts.
- `AssignmentController`, `NavigationController`: optional assignment presentation only while assigned.
- `DebugController`: no normal stress-starting message or giant development HUD.
- Server/client entry points: start the new bounded services/controllers.
- `Navigation.luau`: calmer ambient defaults.
- `README.md`: current gameplay-loop entry point and validation command.
- `Enfleshed.rbxlx`: rebuilt output (ignored generated file).

Existing uncommitted geometry, material/Blender assets, Sandbox cleanup and topology changes were preserved; they are not claimed as new work in this pass.

## Studio test procedure

1. Stop Play and close the old place. Open the rebuilt **Enfleshed.rbxlx** from this repository, or sync current source with Rojo 7.7.0 while stopped. Start a fresh server session; runtime modules do not hot-reload.
2. Use **Test → Server & Clients**, two clients. Check server and client Output and Script Analysis. Each client should independently receive the short opening. Choose different appearances and opposite weapons. Confirm only the chosen slot has an item and normal play starts immediately.
3. Controls: **WASD**, **Space**, **Shift** sprint, **Q** dash, **left click** equipped primary attack, **right click** magic area action, **E** switches only to an owned slot (the other starter slot is empty), **M** map, **K** contextual human interaction. Existing mouse-look is restored after choosing.
4. Reset one character. The opening must not return, the palette and chosen item must remain, and the client must use the correct attack. Rejoining a fresh server should show the opening again. Confirm there is no mandatory assignment-board message or default objective marker. Optional board assignments should still work.
5. Visit B3/B4 housing, B6/B7 workshops and S4/S6 checkpoints. Inspect the `LivingCity` folder if a person is hard to find. Verify short routines, patrol/courier travel, contextual names, civilian retreat and guards engaging visible Nascent. Check doorways/stairs for stalls; engine navigation is not validated by an offline build.
6. For deterministic event tests, **before starting Play**, set `WorldEvents.Development.Enabled=true` and `RandomEnabled=false` in the source/config and sync/rebuild. In Studio's **server** Command Bar while playing, use one of:

   ```lua
   print(workspace.WorldEvents.Force:Invoke("LocalAttack"))
   print(workspace.WorldEvents.Force:Invoke("TravelIncident"))
   print(workspace.WorldEvents.Force:Invoke("Breach"))
   print(workspace.WorldEvents.Force:Invoke("RampartAssault"))
   ```

   These are server-only BindableFunction calls, not client remotes. They bypass random selection/wait, **not** safe zones, player-distance rules, location cooldowns, human availability or caps. A false return explains why no eligible location was found. Walk 60–120 studs from the intended location before forcing. Restart Play between tests if the location is cooling down.

7. For LocalAttack, stand near S4 or a housing/workshop anchor and intervene during the preparation/attack. One client deals at least five damage; the other remains uninvolved. Kill the owned Nascent while its protected human survives. Only the contributor should gain 20 scrip, once. Repeat with both clients contributing. Kill an ambient Nascent and confirm it does not advance the event or award this reward.
8. For TravelIncident, start near S4 (Market Checkpoint), then follow the supply carrier toward S5/S6. Test both damage contribution and following for 20 seconds/40 studs. Waiting in place should not qualify. Arrival alone must not complete while the event enemy lives; carrier death or timeout should fail without payment.
9. For Breach, use the D5 Utility Junction vicinity. Clear the two owned enemies, confirm 30 scrip for contributors and no replacement wave. Test a timeout by ignoring an incident.
10. For RampartAssault, stand 60–120 studs from S6 toward S7. During preparation watch nearby guards/civilians mobilize. Confirm three Nascent emerge near S7 and approach the line. Defend the protected guard, clear the force and verify 45 scrip for contributors. Allow that guard to die in a separate session and verify failure. Survivors should resume ordinary routines after cleanup.
11. Inspect `Workspace.WorldEvents` for State, DefinitionId, LocationId, owned enemies and cooldown attributes. Walk away: event text should disappear, and undiscovered events should not populate the map. After success, watch scrip for another minute to catch duplicate rewards. Repeat several force/cleanup cycles and check that event folders, dead NPCs and enemy models do not accumulate.
12. Restore normal defaults: `Development.Enabled=false`, `RandomEnabled=true`, `FrequencyMultiplier=1`. Human toggles/scaling are in `CityLife.NPCs`; turning humans off intentionally prevents human-dependent events, while Breach can still run. `CityLife.DevelopmentSpells=true` restores Studio-only 1–7/F/R shortcuts and their HUD for sandbox testing. `Sandbox.StressTest.Enabled` remains false and `Sandbox.Enemy.DebugLabels` remains false normally.

## Validation and remaining limits

Rojo **7.7.0** builds the place. StyLua parses/formats the source; the existing Lua tests and new event rule tests pass. The Python built-place reference/source checks pass. `git diff --check` is clean.

These checks do **not** execute Roblox physics, networking, avatar loading or pathfinding, and do not substitute for Luau Script Analysis. Studio testing has not been performed here. Particular playtest risks are navigation through the dense geometry, guard/escort survivability, event availability when candidates are occupied, avatar package differences and the primitive human presentation. Paths can fail; actors retry at bounded rates and events time out rather than teleporting or inventing a route. Population scaling to its full cap may leave no slots for travel actors; the event then fails preparation safely. Appearance and scrip last only for the current server session. There is no progression, shop economy, final animation/VFX, persistence, final rampart geometry or Phase B work.
