# Gameplay and map plan — discovery draft

Superseded after the user's detailed answers by [Defend the Walls — gameplay design and delivery plan](defend-the-walls-gameplay-design.md). Use that document for confirmed decisions, priorities, delivery milestones and unresolved questions. The inventory below is historical discovery context, not a fresh questionnaire.

Date: 2026-10-19. Status: proposed, awaiting design answers. This is a planning document, not authorization to implement every proposed feature.

## Purpose

Make the existing magic system part of a satisfying game: clear goals, interesting spaces, readable threats, meaningful decisions, consequences, and a reason to return. New spell forms/functions are already in progress; this workstream should give those tools useful situations without depending on their completion.

Confirmed direction: castle defense remains the first mode and drives playable milestones. PvP arena remains a major product focus. The existing map layout and gameplay structure may be replaced while retaining Defend the Walls. Do not reopen the choice of primary mode.

Recommendation: validate one repeatable, staged city-defense mission on one deliberately designed map before expanding map count or long-term progression. Preserve shared combat foundations for PvP; tune PvE health, damage and encounters independently of PvP balance.

## Confirmed feedback and revised first milestones

User feedback, 2026-10-19:

- Spell damage feels much too low relative to monster health. Investigate actual damage delivery as well as tuning/scaling before changing numbers.
- Enemy AI is weak and enemies get stuck on raised ground. Traversal reliability is a first-milestone requirement, not later polish.
- Enemies have no visible animations in the user's play experience. Treat animation as missing/broken in practice until verified live; pose hooks in source do not establish working presentation.
- The map's three generic end lanes lack identity and purpose.
- The desired mission begins by defending outer-city residents. Failure leads to a fallback to the first wall. A courtyard behind that wall could require keeping clear; a third wall line could provide sewer access with a distinct objective. Courtyard/sewer mechanics and exact wall numbering are proposals awaiting clarification.

Revised order supersedes the original generic milestone sequence below:

1. **P0 — Diagnose and repair the existing fight.** Establish expected hits/time/mana to defeat representative enemies using starter and advanced loadouts; trace validated damage, mitigation, health and party scaling. Build a traversal test space with shallow rises, curbs, stairs, slopes, rubble, gates and crowding; verify actual hull/agent dimensions, grounding, jump execution, path updates and recovery. Add/repair visible idle, locomotion, attack wind-up/impact/recovery, stagger and death animation, synchronized to server combat timing. Gate: enemies traverse supported terrain and their intent is readable; ordinary enemies do not feel like damage sponges at the agreed power level. Do not assume enabling jump is sufficient: path waypoint jump handling already exists in source.
2. **P0 — Prototype the outer-city defense.** Make residents the stakes. Select one rescue/protection rule, one clear threat and one fallback route. Test civilian target selection/evacuation and capture the outcome in mission state. Gate: players understand whom they are defending, can affect civilian survival, and can complete or lose the stage without softlocking.
3. **P0 — Connect one fallback to a distinct courtyard encounter.** Define breach/retreat triggers, civilian/guard movement, objective transfer, player respawn and straggler handling. Prototype the courtyard's occupancy, access or defense rule once chosen. Gate: retreat is readable and reliable; success in the outer city creates a tangible benefit; failure has consequences without silently resetting everything.
4. **P1 — Extend to the remaining wall lines and sewer objective.** First agree on geography and objective count. Prototype one bounded sewer task and the cost of diverting defenders. Gate: the sewer changes team decisions while remaining feasible for solo play; mission victory and defeat remain unambiguous.
5. **P1 — Complete rewards, pacing, repeatability and presentation.** Credit residents saved, objectives, support and combat; explain consequences in results; tune party scaling and stage lengths; test full replay and reconnect/persistence behavior. Add final art only after the connected blockout works.
6. **PvP validation alongside the shared combat work.** Check targeting, movement, animation readability and damage policy with player opponents. Keep PvE tuning separate from PvP profiles. The arena's playable milestone and scope are still to be scheduled; its priority should not be silently reduced to a distant expansion.

Candidate geography, not a final stage count: outer residential district → first wall/fallback → courtyard → intervening defense line(s) → third wall/sewer access → final objective. The relationship between wall breaches, access and mission progression is undecided. Do not force walls to fall merely to expose all content; decide how strong defense can still reach victory and whether optional areas can unlock without a breach.

Design proposal: earlier outcomes persist as understandable advantages or losses, such as residents saved, guards available, supplies retained or time bought. Select a small number after clarification; do not implement all of these by default.

## Current source baseline

Reviewed source and documentation, not a live Studio play session. Existing code demonstrates systems, not play quality, current place synchronization, or verified performance.

- `src/shared/Configuration/DefendTheWalls.luau`: 20-second preparation, 600-second defense, five timed phases, up to four participants, three lanes, three wall integrity pools, final gateway, two shared repair charges, guards, XP and Marks.
- `src/shared/Modules/DefendTheWallsLayout.luau` and `src/server/Services/DefendTheWallsMap/`: seeded siege blockout with village, crossing routes, three defense lines, baileys, elevations and staging. This is distinct from the practice battlefield built by `MapGenerator`.
- `src/server/Services/DefendTheWallsService.luau`: wall breaches, fallback spawns, guard retreats, four enemy labels (Basic/Swift/Brute/Elite), time-driven spawning, one Elite after phase four begins, and victory when the timer expires while the final doors survive. Enemy labels and stat changes do not by themselves establish four distinct tactical roles.
- `src/server/Services/ModeRunner.luau`: reusable round lifecycle, participation, rewards, replay and telemetry hooks. Reuse this foundation where the chosen design fits it.
- `src/shared/Configuration/Sandbox.luau`: movement/camera configuration, melee support and separate practice/combat resource tuning. Player health is explicitly marked temporary stress-test tuning; this must be considered before judging difficulty.
- `docs/DEVELOPMENT_PLAN.md` records earlier foundation work. The older `GAME_STATUS_AUDIT.md` predates several changes; its missing/broken labels should not be copied into a new backlog without checking current source.

Prior documented decisions to preserve unless revised: safe co-op/hub; separate PvP arena (major focus, milestone timing to confirm); custom player spells; progressive spell-authoring unlocks; PC and console required, mobile desired; broader modes later; XP/Marks economy still provisional.

## Candidate loop

Prepare a loadout → read the next threat → choose a position or objective → fight using terrain and spell combinations → respond to an escalation or setback → recover and make a small decision → complete or fail the mission → understand the result, earn a useful reward, adjust the loadout → replay.

At the action scale, the loop is read threat → commit → see response → counter/reposition → exploit an opening. At the encounter scale it is identify priority → choose route/target → spend resources → resolve consequence. Both need to work before retention systems can help.

For a defense prototype, a candidate encounter is a telegraphed attack on two approaches, a durable enemy pushing the objective, an interruptible ranged threat, and an optional opportunity to protect a guard or recover supplies. Holding a choke, flanking the ranged threat, and intercepting the durable enemy should each offer a credible choice. These are proposals, not selected requirements.

## Priorities

P0 = needed to establish the playable foundation. P1 = needed for a compelling complete slice. P2 = expansion after the slice works. Difficulty/effort is relative, not a calendar estimate.

| Area | Priority | Work and intended result | Dependency / relative effort |
|---|---|---|---|
| Stage win/fail rules | P0 | Castle defense is confirmed; define civilian stakes, fallback triggers, stage outcomes and overall victory | First; small discovery task |
| Damage delivery and PvE scaling | P0 | Diagnose low effective spell damage; agree on hits/time/mana per enemy role; separate PvE and PvP tuning | Before encounter tuning; medium |
| Enemy traversal | P0 | Resolve raised-ground failures with collision/agent/grounding/path/jump tests and reliable recovery | Before expanding the map; medium/large |
| Enemy animation | P0 | Working locomotion, readable attack timing, reactions and death on the actual rigs | Before judging combat feel; medium/large |
| Baseline live playtest | P0 | Walk the actual map and play solo/co-op; log travel, camera, threat, pacing and lifecycle problems | Access to synced Studio build; small |
| Movement, camera and aiming | P0 | Make moving, targeting, dashing and switching actions dependable in the intended spaces and on required inputs | Baseline; medium |
| Tactical map layout | P0 | One readable blockout with purposeful sightlines, routes, elevation, cover, retreat and objective access | Identity + movement envelope; large |
| Enemy roles and counterplay | P0 | A small set of behaviorally distinct threats with clear tells, commitments and responses | Combat baseline; large |
| Objective and encounter pacing | P0 | Pressure/recovery beats, clear threats and satisfying outcomes; prototype alternatives to timer-only survival if desired | Layout + enemy roles; large |
| Combat feedback and readability | P0/P1 | Early pass on hit/blocked/immune cues, telegraphs, audio, targeting and spell clutter; polish after layout stabilizes | Begins with combat baseline; medium |
| Resources, death and recovery | P1; decide at P0 | Define mana/health economy, attrition, respawn/revive and what failure costs | Identity + encounter prototype; medium |
| Spell–environment interaction | P1 | Useful niches for damage, control, defense, mobility and support; navigation-safe constructs and summons | Map + role prototype; medium/large |
| Co-op contribution and coordination | P1 | Solo scaling, shared objectives, pings, support credit, revive policy and anti-grief rules | Outcome/recovery rules; medium |
| Preparation, results and replay | P1 | Quick loadout preparation, understandable results, one useful next action, clean repeat runs | Existing ModeRunner; medium |
| Reward purpose and progression | P1 | Design one short earn/spend/feel-improvement loop using provisional costs | Core loop is enjoyable; medium |
| Onboarding and input/accessibility | P1; validate at P0 | Teach through play; show objective and input cues; verify PC/controller usability early | Baseline + chosen mechanics; medium |
| Visual identity, landmarks and soundscape | P1 | Distinguish routes and danger; create atmosphere while protecting combat readability | Blockout approved; medium/large |
| Performance and reliability | P0 throughout | Pathing, summons/constructs, crowded VFX, replication, respawns, joins and cleanup under load | Test every integrated milestone; ongoing |
| More maps, modes, bosses and long-term systems | P2 | Expand proven decisions and enemy combinations; add breadth after repeat play works | Successful slice; large |

## Implementation sequence and acceptance gates

### Milestone 0 — Agree on the game and observe the build

Deliver a one-page design brief for the confirmed city-defense mode: intended players, civilian protection, fallback loop, scope, success/failure, three design pillars and explicitly deferred features. Play the current synced source in Studio with ordinary combat rules as well as development settings. Record video/notes for solo and a small co-op group. Measure time to first meaningful action, travel time, idle time, death return time, wall transitions and why each run ended.

Gate: distinguish missing features, broken behavior and merely untested behavior; define the first civilian-defense encounter and the minimum rules needed to evaluate it. Primary activity is already decided.

### Milestone 1 — One space, one enjoyable fight

Build a small disposable graybox inside the chosen map approach. Establish walking/sprinting/dashing/aiming metrics. Include a main approach, an alternate route, a useful elevation, an objective and an escape. Mark intended sightlines, enemy access and player-only traversal explicitly. Prototype three tactical roles using current spells, such as a pursuer, an objective breaker and a ranged disruptor. Give each a readable tell, counter and recovery opening. Add enough hit/threat audio and visuals to evaluate the encounter.

Gate: representative starter loadouts can win through at least two approaches; players can explain enemy counters; the camera and navigation support the fight; a single firing perch or choke does not trivialize it. Test with controller input before fixing route dimensions.

### Milestone 2 — Build the map around decisions

Expand only the spaces needed for the mission. Give each region a distinct tactical purpose and recognizable landmark. Measure route timings and opportunities to rotate, intercept, retreat and recover. Test an intact wall, a breach, guard retreat and fallback at every defense line. Replace generic lane repetition with distinct residential, courtyard and inner-defense spaces. Test flying, teleportation, knockback, constructs and summons against boundaries and objective access.

Gate: players know where the current threat is and can reach it within the encounter's intended reaction window; every major route/elevation has a purpose; enemies can reach objectives throughout wall changes; no permanent blocker or inaccessible attacker can stall a run. Verify more than one seed if layout randomness remains enabled.

### Milestone 3 — Complete a short mission loop

Choose a mission duration appropriate to the connected defense stages; the earlier 6–10-minute suggestion is not a commitment. Arrange introduction → pressure → recovery/choice → complication → climax → result. Compare timed pressure with bounded waves within the defense mode. Add only one secondary objective and one escalation mechanic first. Implement the chosen death/recovery rules and solo/co-op scaling. Reuse the round lifecycle instead of duplicating it; extend its hooks only when the selected design needs them.

Gate: first-time players understand the goal; both a win and a loss are understandable; failure does not leave a dead round; late join, abandonment and replay behave intentionally. Complete three consecutive runs in the same server with clean resets.

### Milestone 4 — Make the outcome matter

Connect results to one meaningful reward or unlock and a quick loadout adjustment. Decide what persists and what resets. Credit support and objective work as well as damage. Add short contextual teaching, route/threat indicators, pings if needed, basic settings and accessibility controls. Integrate the spell workstream through a few representative loadouts rather than demanding a showcase for every form.

Gate: a new player can enter, prepare, fight, finish, understand rewards, adjust and replay without developer explanation. A failed mission can still teach something and provide the agreed partial progress. Check a published private test for persistence; source tests cannot prove saved rewards survive reconnects.

### Milestone 5 — Playtest, tune, then produce art

Run repeated solo and 2–4-player sessions, including unfamiliar testers. Compare deaths, objective damage, failed route changes, stuck enemies, spell usage, support contribution, idle time and replay decisions. Fix the largest sources of confusion or frustration first. Replace the approved graybox with final assets while preserving collision, navigation and combat visibility. Stress the intended party/enemy/spell combination and retest the target inputs.

Provisional gates, to confirm after baseline: 4/5 unfamiliar testers identify their first objective within 30 seconds; first meaningful action within 45 seconds; most combat time contains a clear actionable threat; testers can explain why a run ended; at least two tactics remain viable; no reproducible path blockage or round lifecycle failure. Use the existing performance budget as a starting point, then agree on device-specific frame targets and test scenes. These are targets, not current measurements or promises.

## Coordination and boundaries

- Treat spell authoring/forms/functions as an existing workstream. Gameplay planning should specify needed capabilities and representative loadouts; coordinate interfaces before touching shared magic code.
- Start with existing spell capabilities. Verify candidate new forms in the encounters when ready, without holding the entire map milestone for them.
- Reuse the map layout/builder separation, ModeRunner, enemy scheduler, combat policy, profiles and telemetry where they fit. Audit current behavior before scheduling replacements.
- Avoid creating a generic world framework, full economy, large enemy roster or more modes to compensate for an unproven first encounter.
- No calendar commitment until the game direction, map scope, art approach and playtest capacity are known. Re-estimate at each acceptance gate.
- This draft is additive. Existing VFX/form/function changes are outside its implementation scope.

## Clarifying questions

Answer in batches; short answers are sufficient. The original inventory below is retained for context. Questions 2–4 are answered: castle defense drives milestones, Defend the Walls remains mode one, and layout/structure can be replaced. Questions 5–6 are partially answered by the combat/traversal/animation feedback and staged-city concept. Use the focused follow-up questions below next; do not ask answered direction questions again.

### Direction and scope

1. What is the central fantasy: inventive mage, frontline battlemage, siege defender, explorer, or something else?
2. Is the main game castle defense, exploration/adventure, arena combat, or a hybrid? Which is primary?
3. Should Defend the Walls become the main mode, an introductory mode, or a disposable prototype?
4. Should we improve the existing layout, substantially rebuild it, or consider a new setting?
5. What are the three most frustrating things in the current playable build?
6. Describe your ideal five minutes of play, from entering the space to the payoff.
7. Which games are useful references, and which specific mechanics or feelings should we borrow from each?
8. Is solo play a complete intended experience, or mainly a fallback for a co-op game?
9. Does the current four-player party limit fit the intended experience?
10. How long should one mission and one typical play session last?
11. How demanding should combat be: relaxed power fantasy, tactical pressure, precise execution, or selectable difficulty?
12. What must the next playable milestone prove before you consider it a meaningful upgrade?

### World and map

13. Do players launch missions from a hub, roam a continuous world, or enter connected combat regions?
14. Should the layout be authored and learnable, randomized each run, or authored with variable encounters?
15. Should most play happen on the ground, on walls/rooftops, or across multiple vertical layers?
16. Is the ruined castle/night siege identity something to keep? What atmosphere should the map convey?
17. Should the village and crossroads offer objectives/exploration, or mainly guide enemies toward defenses?
18. What distinguishes each lane beyond position: enemies, terrain, hazards, rewards, or access routes?
19. How long should switching lanes or returning from a respawn take?
20. Should routes include shortcuts, unlockable gates or one-way drops, and who can use them?
21. How much cover should block attacks, and should players be able to destroy or move it?
22. What should prevent permanent safety on towers, rooftops or distant firing positions?
23. Should flying/teleportation bypass normal routes, and where are the intended boundaries?
24. How much exploration, secret finding and environmental storytelling belongs inside a timed mission?

### Objectives and pacing

25. Should victory mean surviving a timer, clearing waves, defeating a boss, completing objectives, or a combination?
26. Should losing walls be an avoidable failure state, expected progression, or a strategic sacrifice?
27. Would you prefer continuous pressure or discrete waves with recovery/preparation periods?
28. What can players do during preparation besides select spells: place defenses, deploy guards, scout, or spend supplies?
29. Should players choose the next challenge, lane or modifier, or should the mission direct them?
30. Which secondary objectives sound useful: rescue guards, recover supplies, destroy siege engines, escort allies, or hold locations?
31. Should secondary objectives split the party and create risk, or mostly reinforce the main objective?
32. How should a mission climax feel: last stand, named elite, boss, escape, or decisive final push?
33. How much should encounters vary between replays, and what should remain predictable enough to master?
34. Can a struggling team recover, or should mistakes steadily compound into a loss?
35. Should players be able to pause, abandon or restart a solo run without losing all progress?
36. What should happen when someone joins late, disconnects, or leaves with the party near defeat?

### Combat and enemies

37. Should melee be as important as magic, a mana-saving fallback, or optional?
38. Should success depend mostly on aiming, positioning, timing, loadout design, combinations, or teamwork?
39. Which enemy roles matter first: ranged attacker, shield bearer, flanker, siege breaker, caster, healer, flyer, or summoner?
40. Should ordinary enemies primarily pursue players, attack objectives, or switch behavior by role?
41. How punishing should enemy hits and crowd control be, and how much warning should dangerous attacks provide?
42. Should most attacks be dodgeable/blockable/parryable, or should some require distinct counters?
43. Should enemies have resistances or weaknesses, and how do we avoid invalidating a player's favorite spell theme?
44. Can enemies break constructs, evade persistent fields, contest high ground, or disrupt summons?
45. Should strong combinations reward experimentation even if they dominate a wave, or should encounters actively counter them?
46. Which feedback needs the most work: impact, animation, enemy reactions, targeting, damage/status information, or sound?
47. Do you want lock-on, free aiming, soft assistance, or different options by input device?
48. How visually crowded can combat get before spell spectacle harms readability?

### Resources, cooperation and failure

49. Should mana/health recover automatically, through drops, at safe points, or through support abilities?
50. Should loadouts be changeable anywhere, only in safe zones, or only between encounters?
51. Are consumables and gear central tactical choices, or supporting systems for now?
52. On death, should players respawn, wait for a wave, become downed and revivable, or spend shared lives?
53. Should solo players get a different recovery rule, a companion, or a differently composed encounter?
54. How much should allied guards matter: background atmosphere, useful defenders, or units players command and protect?
55. Should players share repair charges/supplies, have individual resources, or vote on major expenditures?
56. Do we want team roles to emerge naturally from custom spells, or explicitly assign roles?
57. Which coordination tools are needed first: danger pings, objective pings, ally status, role indicators, or quick commands?
58. How should healing, control, defense, reviving and objective work receive credit alongside damage and kills?
59. What should failure cost: time only, reduced rewards, consumables, temporary run upgrades, or persistent losses?
60. Should solo and co-op reward rates be comparable, or is one intended to progress faster?

### Progression, presentation and delivery

61. What should make someone want another run: mastering combat, trying spells, discovering the map, unlocking tools, loot, or a continuing story?
62. Which rewards should the first three successful runs give, and what player decision should each unlock?
63. Should progression mostly expand options or significantly increase raw power?
64. Do you want temporary upgrades within a run, persistent upgrades between runs, or both?
65. Should spellcraft lessons happen before combat, during short safe beats, or only when the player seeks them out?
66. What minimum instructions should appear before the first fight, and what should players discover themselves?
67. Are PC and console still required for the first slice, with mobile a later goal?
68. Which accessibility/settings controls are essential early: remapping, aim assistance, reduced shake/flashes, text size, color-independent cues, or audio controls?
69. What art approach is feasible: authored meshes, a modular kit, procedural Parts, or a mix? Are there assets/budget constraints?
70. How often can you playtest, and can we recruit unfamiliar solo and co-op testers?
71. Which files or systems are actively owned by the spell work so gameplay work can coordinate changes safely?
72. What should we explicitly exclude from this milestone, and is there a target date or effort budget that should constrain it?

## Focused follow-up questions after the confirmed direction

### Residents and the first fallback

- Are residents active NPCs to escort/evacuate, people sheltering in buildings, or an abstract population count?
- Is the outer district's goal to save everyone, a required minimum, or as many as possible before retreat?
- Do enemies deliberately hunt civilians, attack shelters, pursue defenders, or split into different roles?
- Does evacuation happen automatically over time, or require players to open routes, guide groups or activate transport?
- What triggers fallback: a gate breach, civilian losses, enemy occupation, a timer, or a player decision?
- Can players win from a strong outer-city defense, or must the mission advance inward regardless?
- What survives a fallback: residents, guards, supplies, injuries, enemy survivors, or a chosen subset?
- Can players return to abandoned districts, and what prevents or discourages staying behind indefinitely?

### Geography, courtyard and sewer

- Is the outer district outside wall one, with the courtyard between walls one and two and sewer access at wall three?
- Should all three wall lines have playable objectives, or should some mainly provide transitions?
- What does keeping the courtyard clear mean: no enemies for a duration, limited occupancy, protecting a route, or preventing capture?
- What happens when the courtyard is overrun: civilian losses, blocked retreat, loss of supplies, or another fallback?
- Should sewer access be available before the third wall is breached, or unlock through stage progression?
- Is the sewer task evacuation, closing an infiltration route, activating a mechanism, recovering supplies, or something else?
- Is the sewer mandatory for victory or an optional source of advantage?
- Should defenders split between the wall and sewer, or move there as a team?
- How should a solo player complete the sewer task without losing an unattended defense?
- What finally wins the mission: evacuation completed, reinforcements arrived, a final assault defeated, or another condition?

### Immediate combat work and PvP

- At baseline power, how many ordinary spell hits should kill a basic Enfleshed? What about a heavy enemy?
- Should difficulty increase mainly through enemy numbers/coordination, tougher health pools, or both?
- Should ordinary enemies die quickly enough to support crowd-clearing, with durable enemies reserved for explicit threats?
- Should Enfleshed climb/jump ordinary obstacles, use designated ramps, or gain special traversal by archetype?
- What movement/attack personality should animations convey: frantic, shambling, predatory, heavy, or mixed by type?
- Are there usable animation assets already, or should the plan include creating/acquiring them?
- Should the first PvP milestone be a small playable duel arena alongside defense development, or follow the first connected defense slice?
- Should PvP normalize player progression, use existing stat caps, or offer separate rulesets?

## Next decision

Clarify resident behavior, fallback triggers, courtyard rules, sewer purpose and mission victory. Turn the revised first two milestones into concrete tasks and checks. First implementation should address traversal, effective damage and animation, then prove resident defense in a small outer-city blockout before constructing the full city.
