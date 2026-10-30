# Defend the Walls — gameplay design and delivery plan

Execution authority: [Gameplay implementation guide and copyable prompts](gameplay-implementation-guide.md). Latest user constraints override earlier delivery proposals here: **no magic-system changes, no existing balance changes (including enemy HP/scaling), defer magic editing/unlock enforcement changes, and use an interim safe room without freezing active spells.** The 2–3-hit target and full world pause remain design goals for later work, not requirements to alter protected systems now. Follow the guide for step order, scope boundaries, prompts and acceptance checks.

Follow-up decisions: outside combat and the mission timer continue during interim safe-room editing. Implementation stops after guide step 08 for the user's playtest before city expansion. **Downed state, teammate revives and solo guard rescue are required in that first loop.** Audit compatibility with the no-magic-changes boundary; report a concrete scope conflict if found rather than replacing the feature with immediate death/reinforcements.

Updated: 2026-10-19. Planning only; no gameplay implementation changes. This document supersedes the generic discovery questions and proposed sequencing in `gameplay-and-map-plan.md`. Confirmed decisions come from the user's answers; recommendations and open decisions are labeled separately.

## Player promise

“That spell was cool. I made it. I did not know these spells could work together to do that.”

Players discover powerful, emergent spell combinations that overcome combat and environmental obstacles they could not overcome before. Mastery, experimentation and unlocks are the primary reasons to return. Aim precision matters less than positioning, timing, spell design, combinations and teamwork.

Castle defense and arena PvP are co-primary experiences that feed into each other. Castle defense drives the next playable milestones. Do not reframe PvP as an incidental future mode. Preserve shared combat and player identity while defining mode-specific power rules.

## Confirmed decisions

### Structure and map

- Defend the Walls is the main current mission mode; more modes later. Substantially rebuild its layout.
- A mission hub contains the arena and areas for upgrades, inventory/crafting and similar services. These destinations do not imply every service must be implemented in the first milestone.
- Retain the ruined-castle, nighttime-siege atmosphere.
- Use authored, learnable structure with variable portions and encounters. Sewer sections can retain recognizable rooms while their arrangement changes.
- Village/crossroads have activities. Different approaches should differ through objectives and enemy composition.
- The opening uses rampart combat on this map. Broader rooftop/multilevel traversal remains a future-map emphasis; do not remove the rampart fantasy on that basis.
- Some cover/buildings can be destroyed or manipulated.
- Flight and teleportation may bypass normal routes; mana and strain constrain powerful movement. Do not add blanket route restrictions merely to preserve a preferred solution.
- Optional exploration and secrets offer a real choice between safer completion and greater payout.
- Confirmed order from enemy approach toward the final defense: **first wall → outer district → second wall → second district → third wall → courtyard → last wall**. This is four wall lines. Players start defending the first wall from its ramparts, casting down into swarms and using siege tools such as hot oil and trebuchets.
- Siege tools are fixed emplacements, consume shared supplies and can be destroyed by enemies. Separate tool health, operation state and shared supply accounting; exact costs and any cooldowns are playtest tuning.
- Returning to abandoned districts may offer secrets or other optional activities. This is a tentative exploration direction, not confirmation that failed resident objectives reset or that shelters/citizens can be restored.

### Mission flow

- Open intensely and put players into action with a few provided spells while teaching basics.
- Outer-district residents shelter in buildings with separate health pools. Players can lose some buildings before failing the stage, and can repair shelters as well as walls. Choose the exact loss threshold and repair tuning through prototypes.
- The second district has intermittent groups of citizens emerging and moving toward inner safe places; players protect them en route. Citizens follow preset routes, panic/run when threatened by enemies and take alternate routes when the main route is blocked. This is a distinct moving-protection objective, not a repeat of static shelter defense. Validate alternate-route availability and panic recovery instead of assuming every citizen can always improvise a safe path.
- Enemies can bypass the frontline and threaten inner walls while outer defenses still hold. Telegraphed bypass pressure and readable inner-defense status must make this a manageable threat rather than an invisible loss.
- Breached defenses or failed objectives trigger fallback. Retreat is a judgment about a failing position: dying while futilely defending it lets the Enfleshed gain ground. Do not invent automatic benefits for deliberately destroying defenses.
- Players can win while holding the outer district if citizens are protected and inner walls do not fall. The boss/end-assault location and trigger must support victory without forcing a breach.
- Courtyard control drains according to the Enfleshed occupying it; defenders' kills contest that drain. An empty control bar means the courtyard is lost and defenders fall back to the last wall. Do not substitute player presence alone for the confirmed kill-based counterpressure. Whether kills slow drain, restore control or both remains a tuning/design detail.
- The sewer is optional: closing/reducing approach paths both funnels remaining attackers and reduces overall pressure. Floodgates, collapses, barriers or combinations are acceptable mechanisms; select a concrete mechanism to suit the first prototype. It is not mandatory evacuation or a required underground phase. Exact access location and closure permanence remain open.
- Continuous pressure, with preparation options including scouting, defenses, guards and supplies.
- Secondary activities can include rescue, supplies, siege destruction, escorts and holding positions. They may split the party and introduce risk.
- Player choices indirectly influence subsequent challenges. The mission guides pacing without presenting a direct menu of next encounters.
- Default victory: survive assaults and defeat the final boss in a last stand. A discoverable alternate quick victory is desirable; its rule is undecided.
- The boss can attack any currently held position, including an intact first wall. It is more threatening deeper inside because defenders have less space and fewer supporting mechanics/tools. Build this difficulty through geometry and available support first; an automatic boss-stat increase was not requested. Later positions must remain winnable with readable counterplay.
- Initial pacing test: **5–10 minutes before the boss**, with elapsed assault time the tentative boss trigger. Boss combat adds to total run length. Longer per-phase pacing is a possible later test, not the initial target. Replay variation remains substantial.

### Combat and enemies

- Four-player co-op; solo must be challenging but feasible.
- Swarm combat while protecting positions or completing objectives. User references: Darktide, Vermintide and Space Marine 2. These are experiential references, not a requirement to reproduce their systems.
- Magic is central. Melee complements magic and is not intended to replace it; choosing no melee is valid.
- Include the intended enemy roles: ranged attacker, shield bearer, flanker, siege breaker, caster, healer, flyer and summoner. Stage their implementation; all remain in scope for the eventual roster.
- Roles differ in targeting and behavior. Dangerous attacks are punishing with clear warning.
- Resistances encourage spell combinations to overcome them.
- Enemies can counter constructs, fields, high ground and summons without systematically invalidating them.
- Discovered combinations may be very strong. Avoid immediately flattening every successful interaction into equal output.
- Some abilities use lock-on; others use free aim. Exact targeting rules remain open.
- Impact, animation, reactions, targeting, audio and combat information all need substantial work.
- An ordinary basic Enfleshed should die to **2–3 ordinary starter-spell hits** and feel easy to defeat with magic. Define representative direct-damage spells for this benchmark; do not force every damage-over-time tick or support spell to meet it.
- Existing assets cover magic and some melee animations. Plan to author or acquire the remaining animation/presentation assets after checking reuse and rig compatibility.

### Recovery and progression

- Health and mana regenerate very slowly; items provide additional recovery.
- Change loadouts in a safehouse pause available **once per run**. One player may trigger a short mission pause without group agreement; unanimous agreement permits a longer window. Both have a fixed maximum timeout. Treat the pause as a shared mission resource, with one server-owned consumption record so different players/locations cannot activate extra pauses. Exact durations, readiness details and safehouse locations remain open.
- Downed players can be revived by teammates. Dead players return on wall fall or respawn-timer expiry, whichever occurs first, subject to the agreed life rules. Ensure simultaneous triggers cannot return/charge a player twice.
- Guards are valuable allies to protect and attempt to revive solo players during a rescue window. Failed rescue costs a life; exhausting lives loses the run. Starting life count and whether co-op lives are shared/individual are explicitly deferred to playtesting.
- Team roles emerge from custom spells, rather than assigned classes.
- Credit healing and effects contributing to enemy deaths, alongside other contributions. Exact attribution and abuse prevention need definition.
- Failure reduces current-run earnings while preserving previously banked progress.
- The first three successful runs should grant a couple of spells and basic editing access. Form and element editing are earned through early wins, not available before the first win. Exact grants and ordering remain open.
- Arena and defense share unlocks and currency. Arena wins also advance these early spell/editing unlocks. A 1v1 arena is sufficient for the first PvP milestone; power rules and reward rates remain open.
- The next meaningful milestone must demonstrate integrated systems, a complete loop, rewards and progress.

## Current problems to solve first

User-reported play problems: spells deal too little damage relative to enemy health; weak enemy AI becomes stuck on raised ground; enemies show no animations; repeated generic lanes weaken the map.

Source inspection confirms existing pathfinding and jump-waypoint handling, pose hooks, a round runner, fallbacks, guards and rewards. Their existence does not prove correct runtime behavior. Diagnose actual rigs, collision hulls, grounding, navigation and presentation rather than treating the solution as simply enabling jump or adding another state-machine layer. Existing documentation predates some foundation changes.

## Proposed loop

Hub/loadout → immediate first-wall rampart action with usable spells and siege tools → hold the line or fall back to shelter defense → protect intermittent moving citizens in district two if pushed inward → contest courtyard control through kills if pushed farther → defend the last wall if courtyard control is lost → defeat the timed final assault/boss at the surviving defense, or discover an alternate victory → receive full/reduced run earnings → unlock a spell/editing option → test the new combination in defense or arena.

Optional sewer actions, inner-wall incursions, revives and safehouse editing intersect this loop. The fallback sequence describes potential states; a team holding an earlier position is not required to visit every later state.

The first session teaches inside a bounded opening fight. Recommendation: do not require extended hub navigation or spell editing before the player experiences a successful cast. Give subsequent hub services clear purpose through the first result and unlock.

Every objective should support several spell approaches. Examples to prototype, not promises: control enemies away from shelters, protect an ally's revive, move through an obstacle using a costly movement spell, exploit terrain to group a swarm, or combine effects against a resistant threat. Record supported interactions and outcomes, rather than prescribing one named spell as the only key.

Emergence is a property of interacting rules, not a surprise the designer asks the user to specify. Provide consistent status, movement, collision, targeting and objective interactions; observe unprompted play; retain useful discoveries where they fit the intended constraints. A deliberately authored secret victory is a separate design feature. Do not promise any particular unexpected combination in advance.

## Prioritized work

| Workstream | Importance | First deliverable | Evidence of completion |
|---|---|---|---|
| Effective damage and scaling | P0 | Damage/health/resource baseline for representative loadouts and enemy roles | Basic Enfleshed dies in 2–3 representative starter hits; verify mana/time cost and stronger loadouts |
| Traversal and crowd navigation | P0 | Reliable traversal on curbs, stairs, slopes, rubble, gates and crowds | Repeated supported-terrain runs without reproducible blocking; recovery handles temporary obstacles |
| Enemy animation and attack readability | P0 | Working locomotion, wind-up, impact/recovery, reaction and death | Visible on actual enemy rigs; presentation matches server damage timing |
| Rampart opening and siege tools | P0 | First-wall swarm encounter, fixed hot-oil and trebuchet prototypes with health and shared supplies | Useful against swarms, supplies consumed once per operation, destruction disables tools; players experience magic immediately |
| Outer-city encounter and shelter objective | P0 | One small district with shelter buildings, two approaches and one optional activity | Multiple useful spell tactics; shelter failure and held-position victory both work |
| Connected fallbacks and courtyard | P0 progression foundation, P1 full map | Breach/objective transitions through the agreed geography; occupancy-driven courtyard control | Strong defense can win early; courtyard loss moves defense to last wall; solo can recover |
| Second-district citizen protection | P1 | Intermittent moving groups, preset/alternate routes, panic behavior and inner safe destinations | Citizens reroute around supported blockages; panic does not permanently strand groups; viable solo and under bypass threats |
| Safehouse mission pause | P0 state/timer foundation, P1 full UX | Once-per-run short unilateral pause, bounded extended unanimous pause | All mission clocks/entities resume consistently; concurrent requests consume only one use; no repeated-trigger stall |
| Enemy tactical roles and pressure direction | P0 foundation, P1 roster expansion | A few contrasting roles first; role-based target selection and pressure | Players must change priorities; subsequent challenges react to state without hard-countering every loadout |
| Resources, downed state and guards | P0 integrated slice | Slow regeneration, items, revive/death/return rules and guard rescue | A death is a setback without routinely causing an unavoidable loss |
| Rewards and first unlocks | P0 integrated slice | Persisted partial/full rewards, first spell grants and basic editing | One result leads to a meaningful improvement, survives rejoin and cannot double-grant |
| Arena and shared combat validation | Co-primary product | 1v1 duel test with shared unlocks/currency and separately defined power rules | PvE changes do not silently alter intended PvP power; rewards cannot bypass intended progression accidentally |
| Sewer, secrets and authored variation | P1 | Optional route-closure/funneling mechanism and a few valid module arrangements | Paths reduce/reroute without trapping the mission; all arrangements completable |
| Hub flow and loadout station | P1; minimal access in slice | Quick mission/arena entry and a useful unlock/loadout destination | Players can understand and repeat the loop without developer directions |
| Destruction, art and audio | P0 readability, P1 expansion/polish | Minimal readable fight feedback early; selected interactive props and final kit later | Gameplay collisions/objective access remain valid after destruction and art replacement |
| Additional modes, extensive crafting and content breadth | Later | Expand the proven foundation | Does not delay the first integrated defense-and-progression loop |

P0 means required for the next integrated slice; not that every row must be finished before any playable test. Use incremental builds and integrate early.

## Delivery milestones

### A. Repair and measure the fight

- Establish intended starter and representative advanced loadouts. Measure actual validated damage, hit delivery, resistance/mitigation, enemy health, party scaling, kill time, casts and mana spent.
- Tune basic enemies to 2–3 representative starter-spell hits; define separate heavy-enemy durability. Keep crowd enemies and special threats distinct; avoid scaling difficulty only through health.
- Build a small traversal harness with raised ground, stairs, slopes, corners, doors, destructible obstacles and crowding. Check agent settings against actual body size, grounded state, waypoint jumps, repathing and recovery.
- Make animation visible and aligned with combat authority. Audit existing magic/melee assets and rig compatibility, repair reusable presentation and budget authoring/acquisition for the rest.
- Test representative combinations and ensure fixes preserve intended strong interactions.

Exit: the existing fight is readable, enemies reliably move on supported terrain, and damage feels appropriate against agreed benchmarks. Source tests plus Studio checks are necessary; no specific root cause is claimed in advance.

### B. First integrated rampart and outer-city loop

- Graybox first-wall ramparts and the adjacent outer district, with meaningful approaches, independently repairable shelter buildings and one optional activity. A standalone test slice need not build the entire city first.
- Open in action on the ramparts with starter spells and short contextual cues. Prototype fixed, destructible hot-oil and trebuchet emplacements drawing from shared supplies. Tune supply costs, operation time, area effects and any cooldowns after interaction tests. Show tool health and remaining supplies; resolve concurrent use and destruction during operation without duplicate effects or supply spending.
- Support first-wall holding, breach into the outer district, some shelter losses without immediate failure, and a configurable shelter-failure threshold. Test repair while under pressure.
- Introduce a small contrasting enemy set. Recommendation for first implementation: swarm pursuer, siege/objective breaker and one disruptor; select the disruptor role after the objective rules are set. Other requested roles remain on the roster roadmap.
- Integrate downed state, solo guard rescue window, life loss, reinforcement return, item recovery and solo/co-op scaling. Choose configurable initial life/timer values after the open rules are answered.
- End this early prototype with explicit success/failure, persisted run rewards, a spell/basic-editing unlock and immediate replay. It is an integration build, not the final mission structure.

Exit: a player can fight → protect an objective → finish or fail → understand rewards → improve a loadout → replay. Saving and first unlocks must work here, rather than waiting for the full map to exist.

### C. Connected defense and strategic retreat

- Connect first wall → outer district → second wall → second district → third wall → courtyard → last wall incrementally. Preserve the order even while some spaces are simple grayboxes.
- Implement breached-defense/failed-objective triggers, warnings, guard retreat, respawn relocation, survivor handling and continued enemy advance while players are dead.
- Add intermittent second-district citizens traveling to inner safe places on preset routes; enemies trigger panic/running and blocked main routes trigger alternate routes. Define cadence, destinations and tolerable losses. Test panic transitions and recovery, crowds, breached gates, player constructs and cases where all alternatives are temporarily blocked. Do not solve blocked navigation by silently granting rescue credit.
- Implement courtyard control: server-owned occupancy, kill-based counterpressure, zero-control fallback and explicit HUD feedback. Tune the exact drain/kill/recovery formula rather than assuming occupation or kills alone always dominate.
- Add bypass threats to inner walls with warnings, readable status and solo-aware pressure. Connect shelter outcomes, protected moving citizens, surviving allies, siege equipment, resources and sewer changes to later pressure where appropriate. Shelter protection and moving citizens belong to different districts.
- Integrate once-per-run safehouse editing: short pause on one player's request, longer pause with everyone's agreement, hard timeout for both and coherent resumption of all mission state. Arena and hub activity continue. Show consumption and remaining time to the whole party; treat simultaneous activations as one pause, and do not reset the cap with repeated votes.
- Support victory from a held outer district with protected citizens and intact inner walls. Define boss spawn/reachability at the active defense rather than requiring the team to reach the last wall.

Exit: both holding and retreating are meaningful choices; retreat is costly but viable; neither approach stalls the run or silently resets consequences.

### D. Sewer, final assault and controlled variation

- Add one optional sewer mechanism that closes/reduces enemy approach paths, reduces total pressure and reroutes remaining attackers. Validate access, at least one viable enemy approach and varied sewer arrangements. Avoid silently deleting enemies that lose a route.
- Add the final assault and a boss that can reach/fight at any held defense, including the first wall. Preserve distinct counterplay while inner positions become harder through tighter space and fewer supporting mechanics. Verify boss navigation, ability footprints, telegraphs and viable escape/counter windows at every position; do not apply a blanket stat multiplier as a substitute for testing the spaces.
- Add bounded variations in encounters, activity placement and modular sections. Keep entry/exit connections, objective reachability and escape routes valid.
- Add an authored alternate victory only after its discovery, cost, rewards and replay impact are defined. Separately test emergent combinations through unprompted experimentation; do not prescribe the surprise.
- First test 5–10 minutes of active assault before boss arrival, tentatively driven by elapsed time; paused editing time should not accidentally advance the assault clock. Tune boss duration separately and revisit longer phase pacing only if playtesting supports it.

Exit: a complete defense run with optional risk, readable consequences, a climax, replay variation and a viable solo route. Decide whether successful optional activities extend run length or replace other beats.

### E. Arena, hub and repeat-play validation

Recommendation: create a minimal duel-test arena as soon as milestone A stabilizes shared combat, and validate it during B–D. Castle defense continues to drive the full-loop milestone. Arena polish, rewards and hub integration are separately scoped; co-primary status does not require simultaneous feature parity.

- Use shared unlocks and currency across defense and the first 1v1 arena. Wins in either mode advance early editing grants; ensure cross-mode claims cannot duplicate grants. Define normalized/capped PvP power and mode reward rates separately.
- Reuse shared spell definitions, movement, targeting and readable combat presentation; keep PvE encounter/health tuning separate.
- Provide clear hub access to defense, arena and unlocked editing/upgrades; only build inventory/crafting services needed by the chosen loop.
- Test PC/controller input, four-player swarms, boss/construct/summon combinations, death/revive, disconnects, rewards and repeated rounds.
- Expand the enemy roster in behaviorally tested batches. Add authored art/audio without changing established collision and route metrics accidentally.

Exit: repeated defense runs and arena matches support the intended custom-spell fantasy, with reliable rewards, understandable contribution, acceptable performance and no reproducible round or navigation failures.

## Design tensions to resolve explicitly

1. **Continuous pressure, respawn and editing pause.** First wall-fall/timer event returns dead players; define life accounting and preserve revive as a downed-state action. Safehouse allows one pause per run, short unilateral or longer unanimous, both capped. Freeze mission simulation/timers consistently, including attacks, projectiles, status effects, spawn schedules, escort movement and control drain; keep arena and unrelated hub players running. Validate this behavior for existing spell runtimes before implementing a superficial AI-only freeze.
2. **Timing and many spaces.** Initial test is 5–10 minutes before the boss. Do not assume every run must visit every district or courtyard: early held-position victory is intended. Optional sewers change pressure routing rather than adding a mandatory phase.
3. **Strategic retreat.** Leaving a doomed defense preserves lives and the ability to contest the next position. Delaying until death gives enemies a lead. Preserve this tradeoff without bonuses for intentionally throwing. Decide the boss/end trigger for teams holding the outer district.
4. **Powerful combinations and PvP.** Preserve interactions where possible, but define PvP counterplay and power constraints explicitly. An interaction may clear a PvE swarm without being allowed to create an unavoidable player kill.
5. **Free traversal and objective validity.** Resource costs constrain movement. Objective state still needs to survive shortcutting: discovery, interaction, rescue credit, boss activation and alternate victory must be intentional. Check that teleports do not strand NPCs or break progression; do not prescribe arbitrary walls as the default fix.
6. **Failure rewards.** Confirmed: reduce run earnings and preserve banked progress. Define the reduction formula and treatment of optional objectives/collected rewards; repeated rescue/respawn must not duplicate grants.
7. **Support credit.** Healing and active-effect assists need bounded, attributable events. Track effective healing, meaningful effect contribution, protection/rescue/objective actions and shared credit. Avoid rewards for overheal, repeatedly tagging harmless targets, self-created damage or duplicate application spam.
8. **Variation and mastery.** Keep landmarks and objective rules learnable while varying connections/encounters within tested constraints. Randomness should create decisions rather than unreachable tasks or unwinnable enemy combinations.

## Buildable work packages

| ID | Priority | Package | Depends on | Reviewable result / acceptance |
|---|---|---|---|---|
| G01 | P0 | Combat baseline and traversal diagnosis | Existing source | Recorded starter damage/kill benchmarks and traversal failures; fix/verify 2–3-hit basic enemies and supported terrain |
| G02 | P0 | Rig/animation audit and first enemy set | G01 metrics; can audit alongside it | Asset reuse/acquisition list plus visible locomotion/attack/reaction/death aligned with damage |
| G03 | P0 | Objective and mission-time foundation | Confirmed rules | Server-owned shelter, breach, life/respawn and pause-aware timing contracts; simultaneous events transition once |
| G04 | P0 | First-wall rampart graybox and siege tools | G01; G02 for fight review | Starter magic, oil and trebuchet usable against swarms; reliable attack routes and breach into district |
| G05 | P0 | Outer-district shelter encounter | G03, G04 | Separate shelter health/repair, partial tolerable losses, fallback rule and viable held-position outcome |
| G06 | P0 | Rewards, early editing and replay | G03, G05 | Win/loss → persisted earnings → earned form/element grants → loadout improvement → clean replay; banked progress preserved |
| G07 | P1 | Full four-wall graybox and moving citizens | G03, G05 | Ordered map, intermittent escorted citizens, fallback spawns, bypass threats and readable inner-wall status |
| G08 | P1 | Courtyard control | G03, G07 | Occupancy drains, defender kills counter it, zero triggers last-wall fallback; HUD explains change |
| G09 | P1 | Sewer routing and variation | G07 navigation topology | Optional intervention reduces pressure and funnels remaining attackers; closures never softlock a run |
| G10 | P0 foundation / P1 full UX | Bounded safehouse editing | G03; audit existing runtime clocks | Short one-player pause, longer unanimous window, hard timeout and complete mission resume |
| G11 | P1 | Timed boss and complete defense run | G06–G10 | Boss after 5–10 active minutes, valid at held defenses; full solo/co-op outcomes and three clean replays |
| G12 | Co-primary | First 1v1 arena and hub links | G01, G03, G06; develop alongside G07–G11 | Shared grants/currency, defined PvP caps, isolated mission pause and usable defense/arena entry |

These are implementation packages, not separate new chats or authorization to start coding. No calendar estimates until runtime/animation audits establish scope. G01–G06 form the first integrated review build; G07–G11 complete the larger defense structure. G10 pause-aware timing must be designed in G03 even if its full UI ships later.

### Required scenarios for package review

- G04: two players operate siege tools against one shared supply pool; an emplacement is destroyed mid-operation; neither case duplicates attacks or spending.
- G07: citizen group encounters enemies, panics, finds its main route blocked and uses an alternate; temporary blockage of all routes cannot permanently freeze mission state.
- G10: one player triggers the short pause, the group extends by agreement within the allowed cap, timeout resumes play, and any second trigger in that run is refused. Rejoin/disconnect cannot reset consumption.
- G11: boss arrives while first wall holds and can be defeated there; separately test boss at inner defenses with reduced space/support. Courtyard loss and a wall breach during the boss fight resolve cleanly.
- Optional return visits: secrets can provide a reason to revisit abandoned areas, but returning must not silently rewind objective failures or duplicate completion rewards.

## Remaining decisions and playtest variables

Do not ask answered questions again. Life counts and individual/shared co-op lives are explicitly playtest variables. Keep shelter count/loss threshold, repair amount/cost, citizen cadence/loss threshold, respawn timer, control drain/kill credit, siege supplies/cooldowns and reward multipliers configurable. Suggested values must be labeled test tuning rather than confirmed design.

The remaining structural questions can be answered during package design:

1. How do failed district objectives affect shelters/citizens left behind? Return secrets are tentative; failed-objective permanence remains unspecified.
2. Where is safehouse access? Downed players, disconnects, resource regeneration and cooldown progress during pause need explicit rules. Exact short/extended caps are playtest tuning.
3. What occurs if an inner wall falls during the boss fight? Boss relocation/targeting and overall defeat precedence need a consistent rule.
4. Where is optional sewer access, and are closures permanent for the run? Prototype mechanism selection can use any approved variation.
5. In 1v1, should power use existing PvP stat caps or a different normalization rule? Earlier PvP decisions favor custom spells with caps; use that as the baseline rather than reopening it without a concrete issue. Reward rates for participation/wins need tuning.
6. Which forms/elements are the initial earned grants, and how are they distributed across the first three wins in either mode?

Broad discovery is sufficient to start package-level planning. These remaining details can be resolved in the relevant design/implementation package; do not keep cycling through answered questions or delay the combat/traversal baseline for unrelated map tuning.

## Verification and planning limits

This plan combines source review with user-reported play feedback; no new live gameplay validation was performed while writing it. Before implementation, review active spell work and coordinate shared-file ownership. Add meaningful regression checks for damage, objective transitions, attribution and rewards; use Studio for traversal, rigs/animation, gameplay feel and actual multiplayer. Verify persistence in a private published test. Dates/effort estimates follow confirmed objective rules, animation scope and playtest capacity; do not treat the milestone list as a calendar commitment.
