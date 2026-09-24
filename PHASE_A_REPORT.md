# Phase A implementation and Studio acceptance checklist

This implementation is ready for manual Studio acceptance testing. No Studio
physics, rendering, navmesh or live enemy chase has been run from this workspace.
Offline tests inspect the same geometry manifest that the runtime constructs;
they are not a substitute for normal gameplay. Phase B remains blocked.

## Resulting layout

| Requested measure | Implemented result |
| --- | --- |
| Footprint | Unchanged: X −700…700, Z 350…1750 (1,400 × 1,400 studs) |
| Authored route nodes | 42 |
| Explicit connections | 61 |
| Independent graph loops | 20 total: 14 above ground, 3 underground, 3 formed by the four surface/underground connections |
| Primary buildings | BarracksHallA, BarracksHallB, HousingThroughA, HousingThroughB, HousingThroughC, WorkshopMarketA, WorkshopMarketB, CommunalHall |
| Playable building floors | Eight ground floors plus eight upper floors at Y=36 |
| Roofs | Four accessible roofs at Y=72 |
| Rebuilt stair connections | 16: 8 ground-to-upper, 4 upper-to-roof, 4 underground entrances; 28 physical flights including returns |
| Door openings | 32, each 18 studs wide × 14 clear height |
| Upper network | Four explicit catwalk links plus two roof links; an extended Barracks/Housing chain and a separate Workshop/Communal Hall roof connection |
| Underground | 4 entrances, 7 junction/basement nodes, 9 underground connections, 3 independent loops at Y=−36 |
| Housing infill | 240 clipped lots, with 16-stud secondary lanes between the original lot rows/columns |
| Human visual height | 220–500 studs, above a 64-stud solid base |
| Ancient structure | Shaft walls 1,100 studs tall, overhead ribs at Y=600/690, suspended masses at Y=760, distant enclosure ceiling at Y=1,000 |
| Approximate generated Part count | 4,570 including hidden ground supports, enclosure, lamps, signs and markers; excludes characters, dummy, spell effects and existing baseplate |

Loop counts are graph cycle ranks (edges − nodes + connected components), not
every possible round trip. The 14 requested local loops are the aboveground
network; underground links add six independent cycles overall. Coincident route
intersections and secondary infill lanes can create further physical choices
that are not counted as new authored nodes.

The playable upper layer is Y=36/72, rather than extending to Y=140. It prioritizes
two properly connected levels and sustained roof routes over more disconnected
floors. Workshop West's upper room/balconies are a deliberate branch reached by
its stair; it is not part of the sustained roof network. Underground elevation
is deliberately one main level, reached through four real descending shafts;
there are no extra intermediate tunnel height changes in this pass.

## Construction and fixes

Routes are generated before buildings. Buildings have a central through hall,
side room partitions, front/rear openings, a separate stairwell, two broad stair
flights and a half landing. Upper floors contain actual stairwell cutouts and
usable landings. Every upper doorway has a balcony or connecting route outside.
Four buildings continue up a second stair pair to their roof. Ordinary ground
and upper routes reserve space before the housing lots are clipped.

Underground rooms and corridors form a floor union. Walls surround its perimeter
instead of blocking intersections. Two nodes sit beneath the workshops as
basement rooms. The four courtyard stairs connect to those passages through
bent maintenance links. Surface paving and the underground ceiling both contain
the stair shaft openings. The development catch surface remains at Y=−80.

Each infill lot uses one solid lower mass and four differently inset habitation
layers, with simple warm window bands and two grafted upper room additions that
project over the lanes above playable height. Six suspended upper streets/workshops
cross above the playable city. Background upper masses are non-collidable.
Ancient ribs, shaft walls and suspended masses provide multiple overhead layers;
the six-face persistent enclosure is a distant sky-occlusion backstop. Ordinary
building geometry still streams; the small shell remains loaded. Dark distance
fog blends the upper city into the megastructure.

The old paving, avenue, courtyard and building floors overlapped at the same
or nearly the same top Y; their competing visible planes explain the observed
flicker. The new builder subtracts already occupied rectangles on each floor
plane. All visible collision floors are disjoint at that plane. Hidden backup
supports are fully transparent, have their tops one stud below visible ground,
and overlap one another by 0.5 stud. Stair treads overlap horizontally but have
different top heights. This removes the identified coplanar source; motion in
Studio must still confirm the rendered result.

The local lantern is a warm PointLight on a root attachment (28-stud range,
brightness 2, shadows enabled), recreated on respawn and destroyed when the
character is removed. It lights only the local player's surroundings and adds
no new remotes or world-wide illumination.

Body Reinforcement has `Lifetime.Mode = UntilToggledOff` and an Enhancement
payload with `SpeedMultiplier = 3`. MagicService stores one effect per spell ID,
uses an infinite internal expiry, and removes it on the second activation.
Deactivation bypasses resource/activation-cooldown checks; activation retains
the existing mana cost and one-second cooldown. Death, removal and reset clear
the effect. The pre-existing jump bonus is retained while active.

The server MovementService and client sprint prediction use the same speed
calculation: `(walk or sprint speed + existing bonus) × multiplier`. Actual values
are 48 walking / 84 sprinting while active, and 16 / 28 after switching off.
Movement validation uses the enhanced ceiling and briefly retains the previous
ceiling when toggling off to account for motion already travelled. Dash remains
14 studs over 0.18 seconds, uses its existing cooldown/collision checks, and
returns to the correct current movement speed afterward. No leveling/stat system
was added. An existing `next()` lookup was also corrected to read the enhancement
record rather than its string key.

## Files introduced or repurposed

| File | Purpose |
| --- | --- |
| `src/shared/Configuration/PhaseATopology.luau` | Authored graph, primary building definitions and explicit route waypoints |
| `src/server/Development/LowerLayer/RouteGeometry.luau` | New Phase A geometry manifest: circulation, stairs, openings, floors and tunnel walls |
| `src/server/Development/LowerLayer/PhaseA.luau` | Renders the manifest, then housing, background layers, enclosure, lamps and landmark signs |
| `src/server/Development/LowerLayer/BuildContext.luau` | Retains runtime counts/persistent shell and configures interior distance fog |
| `src/shared/Configuration/LowerLayerGraybox.luau` | Updated avenue/enclosure dimensions; removed obsolete overlapping paving-row configuration |
| `src/server/Development/PhaseANavigationCheck.luau` | New opt-in, Studio-only engine navmesh check using the actual Stage 1 agent profile |
| `src/client/Controllers/LanternController.luau` | New local lantern with character lifecycle cleanup |
| `src/client/init.client.luau` | Starts the lantern |
| `src/shared/Modules/MovementSpeed.luau` | New small shared movement calculation used by authority and prediction |
| `MovementService`, `MovementController`, `ActionRouter`, `CombatTypes` | Compose/replicate/reset the multiplier and preserve movement validation |
| `MagicService`, `Spells`, `Sandbox`, `SpellDefinitionValidator` | Toggle lifetime, configured 3x multiplier, effect lifecycle and supported-definition validation |
| `tests/test_phase_a_geometry.lua` | New generated-floor overlap, stair landing, doorway, route support and agent clearance checks |
| `tests/test_phase_a_topology.lua` | Node/edge connectivity, building access and independent cycle-count checks |
| `tests/test_lower_layer_graybox.lua`, `tests/test_magic_v2.lua` | Updated scale/enclosure and reinforcement definition/speed regression checks |
| `README.md`, `PHASE_A_REPORT.md` | Current controls, implementation details and manual acceptance procedure |

## Exact Studio procedure

1. Stop the existing play session. Open the rebuilt `Enfleshed.rbxlx`, or sync
   the new sources through Rojo before starting a fresh session.
2. Start one server with two players from Studio's Test controls. Check server
   and client Output for errors. Verify each client has its own warm nearby light.
3. From RecruitSpawn, follow the main avenue, then take the west route into
   Barracks Hall A. Walk through to the opposite street; enter its stairwell,
   climb to Y=36, continue to Y=72, and cross toward Housing Through B. Verify
   both flights, landings, headroom, upper doors and both bridge ends.
4. Test the upper chain from Barracks Hall B to Housing Through A/B and Housing
   Through C without returning to ground. Separately cross the Workshop Market A
   roof to Communal Hall. Walk the front and rear entrances of all eight buildings.
5. At the western/eastern courtyard nodes near (±520, 0, 1400) and
   (±520, 0, 600), descend the visible stair openings. Traverse the northern
   junctions, workshop basements and southern loop, then exit another shaft.
6. Sprint along road/interior intersections while moving the camera. Confirm no
   floor color flicker, invisible ordinary floor, blocked landing or sky leak.
7. Press **6** once. Verify Humanoid.WalkSpeed is **48**, or **84** while holding
   Shift. Wait at least 10 seconds. Dash with **Q**, then toggle **6** off while
   moving; speed must return to **16/28** without correction snapping. Repeat,
   then die/reset while active and verify the replacement character starts normal.
8. During the server play session, run this in the **server Command Bar**:

   ```lua
   require(game.ServerScriptService.Server.Development.PhaseANavigationCheck).run()
   ```

   Nine checks print PASS/FAIL for avenue, alley, courtyard, housing, stairs,
   workshop, market and underground paths. A successful navmesh result is not
   proof that the enemy controller follows it successfully.
9. Let the existing 1/5/10/20 waves pursue you through those same routes. Check
   doorframes, turns, both stair flights and tunnel junctions with several enemies.
   Player-only roof paths do not need to support normal enemy pursuit. Measure
   frame rate and navigation hesitation at 20 enemies.
10. In Explorer, select `Workspace.LowerLayerGraybox` and inspect `PartCount`,
    `RouteNodeCount`, `RouteConnectionCount`, `IndependentLoopCount`,
    `StairFlightCount`, `InfillHousingCount`, and `HumanVisualHeight`.

## Remaining acceptance work

Offline route support, floor partitioning and agent-envelope tests pass; actual
NPC movement, Roblox stair handling, camera comfort, streaming appearance,
lighting, rendered flicker and 20-enemy performance remain unverified. No live
enemy traversal tests have been performed here. The first Studio run may reveal
navmesh or controller issues that axis-aligned geometry checks cannot detect.
U7 is intentionally a balcony/upper-room branch; the underground stays on one
main level; no Phase B geometry or new encounters were added.

Stop after Phase A playtesting and collect screenshots before further work.

## Interior variation, lighting, and spawn coverage pass

The topology and footprint remain unchanged. The eight primary buildings now use
eight authored interior styles: Barracks Hall A has bunk bays and a guard post;
Barracks Hall B has a training hall and observation dais; Housing A has dense
cells; Housing B has a split living level; Housing C faces a courtyard through
alcoves; Workshop A uses an open work floor and loading platform; Workshop B is
a storage/service workshop; and Communal Hall has stalls and a gathering dais.
These elements are deliberately non-colliding graybox detail during this pass,
so they do not narrow the existing enemy-compatible circulation, stairs, doors,
or bridges. The distinct structure is visible without changing the approved
traversal contract.

Baseline lighting now follows actual routes: 92 street/alley fixtures, 48
interior/doorway fixtures, and 18 underground/stair fixtures, for **158**
environmental PointLights. They have shadows disabled for performance. This
replaces the previous 38-light baseline, a net increase of about 120 route
lights. Forty-eight neon upper-city window parts add distant inhabited scale
without extra dynamic lights. The lantern is now attached higher and forward,
with a 36-stud range and 3.25 brightness (previously 28 and 2), while retaining
its one shadow-casting light per local player.

The old stress spawner did not have authored city anchors. It tried a radial
layout around the old market center and then rejected all results with the
obsolete `abs(X/Z) < 250` baseplate check; Phase A begins at Z=350. Its tall
ground probe also hit a surface ceiling before it could see underground floors.
The new selection uses **99** authored candidates: **70 surface** candidates
across main/secondary streets and avenues, **8 interior** candidates, and **21
underground** candidates. It requires a valid nearby floor, a clear enemy hull,
minimum player distance, maximum local encounter distance, and normal candidate
spacing. It preserves the existing 1/5/10/20 active-wave limits and no spawn
director was added. Set `SpawnDebug = true` in `LowerLayerGraybox.luau` to
generate development-only candidate markers at the next fresh play session.

The generated geometry test now checks every candidate against a supported floor
and the Stage 1 envelope. Remaining Studio checks are live navmesh/chase results
through interior/underground candidates, visual light balance, and any dark
corners left between the intentionally lower-lit alleys. Phase B remains blocked.

## Stage 1 Nascent Enfleshed Combat V1

The existing Stage 1 rig, procedural Motor6D posing, direct pursuit/path queue,
shared round-robin path budget, `DamageService`, and neutral `HitDetectionService`
remain in use. `EnemyService` now owns state execution and target/navigation;
`NascentAttackSelector.luau` is a small pure state-based selector. Attack tuning
is centralized in `Sandbox.Enemy.Nascent`.

The Nascent states are Idle, Chase, Telegraph, Attack, Recover, Vulnerable,
Flinch, and Dead. It selects Mauling Combination while extremely close,
Predatory Lunge at 8–19 studs, Frenzied Chain in close pressure situations, and
Rushing Strike at ordinary melee distance. At 35% health it uses the same
telegraphs but shortens recovery to 72% and favors Frenzied Chain, rather than
receiving a damage or raw-speed increase.

Rushing Strike has a 0.28-second telegraph, travels 7 studs while striking,
deals 18 damage, and recovers in 0.30 seconds. A selected missed rush transitions
into a readable 0.16-second Reversal Swipe, which deals 15 damage and has no
extended punish. Frenzied Chain advances through four strikes (10 damage each),
then grants 0.85 seconds of vulnerability. Predatory Lunge has a 0.65-second
telegraph, travels 16 studs, deals 30 damage, and grants 1.15 seconds of
vulnerability on a miss. Mauling Combination is three advancing close strikes
for 12, 12, and 24 damage. Its hits do not lock a player into the rest of the
sequence. All travel is server-owned and collision-checked.

Nascent health is now 180. Minor hits apply damage without interruption.
Significant hits cause a 0.18-second flinch and can interrupt a telegraph.
Major hits cause a 0.52-second stagger. Any player hit during Vulnerable is
treated as major, making missed lunges and completed frenzies the intended
counterattack windows. Recruit melee strikes one and two are minor; the third
strike is significant. This removes the previous left-click flinch loop.

`DebugNascent` defaults to false. When enabled alongside the existing telegraph
debug setting, the model exposes state, current attack, vulnerability, and
desperation attributes, and shows temporary attack geometry.

Static configuration and geometry checks pass. No live Studio 1v1, two-Nascent,
or main-road/alley/interior/stair/market/underground chase test has been run from
this workspace. The largest remaining risk is feel and collision behavior during
the server-owned advancing attacks; custom animation assets will later be needed
to replace the procedural placeholder body poses.

## Stage 1 Nascent presentation, tracking, and recruit-bolt pass

Frenzied Chain now applies capped rotational tracking during both its windup and
active windows. The configurable cap is **420 degrees per second**. Its four
strikes scale that cap by **1.00, 0.78, 0.58, and 0.18**, respectively; it stops
retargeting once the player exceeds the configurable 10-stud escape range. This
changes facing only: the existing forward strike travel remains server-owned, so
it cannot slide sideways, teleport, or attach to the player.

The Stage 1 rig remains a small animatable R6/Motor6D foundation. Its prototype
body now uses a hunch-forward torso, offset head, oversized right striking arm,
larger left arm, and welded shoulder/rib/back/jaw growths. These growths are
non-colliding visual pieces; the existing invisible hull remains responsible for
physical body blocking. The result is a deliberately asymmetric, once-human
silhouette without introducing assets, a general NPC model framework, or a new
enemy type.

Procedural presentation now distinguishes idle breathing, reckless chase,
individual Frenzied strikes, Rushing Strike, lunge compression and launch,
Mauling steps, Reversal Swipe, minor flinch, major stagger, vulnerability, and
death. Active hit queries start only after the corresponding active strike pose
has been applied. Existing optional debug hitbox parts remain available through
`DebugTelegraph` plus `DebugNascent`; they are disabled in normal play because
`DebugNascent` defaults to false. These are still procedural poses rather than
authored animation assets. Blender-authored meshes and animation clips remain
the appropriate later upgrade for deformation, weight shifts, grounded foot
placement, and a production-quality death.

Recruit Magic Bolt now has a **0.60-second** primary-fire cooldown in its spell
definition. The existing per-player server `Ready` timestamp enforces it for
every cast request, including held input, so a rapid client cannot bypass it.

Projectile travel now uses a swept server ray each update. It ignores cosmetic
non-solid query pieces, but resolves the first enemy humanoid or collidable
world surface. A valid collision processes `OnImpact` once, destroys the visual,
and removes the active projectile. Lifetime expiry now only removes the bolt;
it no longer incorrectly behaves as an impact. Damage remains represented as
payload data and `Explode` still dispatches through the behavior registry. A
future registered Pierce or Bounce behavior can explicitly alter termination
without changing individual spell IDs; no empty future handlers were added in
this pass.

All repository static tests, StyLua, Rojo build, reference checks, and whitespace
checks pass. Studio runtime validation is still required for wall/floor/enemy
projectile impacts and Frenzied sidestep/dash behavior; neither can be executed
outside Studio here. No Stage 2 work, map changes, new Nascent attacks, or broad
combat rebalance was performed.

## Stage 1 Nascent close-range tracking pass

Circle-strafing was effective because ordinary pursuit depended on `MoveTo` and
attacks mostly selected their facing at state boundaries. A nearby player could
therefore orbit around a stale body direction while the Nascent repeatedly ran
past them. The Nascent now manually pivots its actual root/body direction during
Chase, with no separately-aimed hitbox. Its chase turn caps are 220 degrees per
second at long range, 380 at mid range, 620 inside 8 studs, and 820 inside 3.5
studs. A target more than 105 degrees off-angle can use the 980-degrees-per-
second short pivot cap. These are capped physical turns, not teleports or
sideways repositioning.

Direct nearby pursuit now moves toward a 2.35-stud standoff point and stops
there instead of repeatedly running through the target. This lets the body pivot
and transition into its existing close attacks. Pathing remains unchanged for
obstructed routes. True Vulnerable states do not use the new turning path, so a
missed lunge and Frenzied exhaustion remain punish windows.

Rushing Strike and Predatory Lunge use 680/640-degree telegraph turn caps,
then reduce to 110/65 during their committed active movement. Mauling tracks at
720 degrees per second across its strikes with multipliers 1.00, 0.82, and 0.20.
Reversal Swipe turns at 900 during windup and 260 during its short active arc.
Frenzied Chain retains its 420-degree cap and 1.00, 0.78, 0.58, 0.18 strike
scaling. All rotations update the same root CFrame used for attack travel and
hitboxes.

Static configuration, build, place-reference, and whitespace validation pass.
Circle-strafe, proper-dodge, and lunge/frenzy/maul feel tests require manual
Roblox Studio playtesting and have not been claimed as executed here. Fast root
pivots still use procedural animation, so an authored planted-foot turn is the
appropriate later presentation improvement if the body twist appears too abrupt.

## Close-range chase stall correction

The first close-range turning pass left manual root rotation active during every
chase distance. That could conflict with normal Humanoid locomotion while
following a distant target. Manual root turning now applies only inside the
8-stud close-combat range; ordinary pursuit restores standard Humanoid
autorotation and movement. A second issue classified the intentional 2.35-stud
melee standoff as a lack of navigation progress, causing the watchdog to clear
direct pursuit and request an unnecessary path. Holding that standoff now resets
the progress timer instead. The close pivot, attack tracking, vulnerability, and
pathing behavior otherwise remain unchanged.
