# Enemy animation coverage and asset manifest

Step 02, 2026-10-19. This is an enemy-only **procedural prototype**, not final authored animation art. No external animation was purchased, downloaded, uploaded or assigned an invented ID.

## Current source and rig compatibility

- `src/shared/Modules/EnemyAnimation.luau`: existing repository Nascent attack silhouettes moved from server-only Motor6D writes into a client sampler; new locomotion/air/landing/recovery/death coverage authored as code in step 02. No AnimationTrack IDs are used.
- `src/client/Controllers/EnemyAnimationController.luau`: applies enemy transforms after Animator evaluation on PreSimulation. It is independently bootstrapped by `src/client/EnemyAnimation.client.luau`, without editing the player/magic bootstrap.
- `src/server/Services/EnemyService.luau`: existing combat phases publish one EnemyPose snapshot on changes. Existing attack schedule, steps and hit queries remain authoritative. Network delivery adds presentation latency; this is not a promise of zero-latency client/server frame alignment.
- `src/server/Services/EnemyAnimationCorpse.luau`: at most 24 cosmetic copies, 1.1-second lifetime, no Humanoid, collision hull, combat tags or query/touch/collision participation. These preserve immediate gameplay actor cleanup. Administrative deletion of a living actor does not create a corpse.
- Current fallback R6 rigs: six named visible parts, RootJoint, Neck, shoulders and hips. Neutral limb placement is preserved while fallback joints gain anatomical pivots. Translation offsets follow Model scale; angles do not scale.
- Existing GLBs/manifests: `assets/enemies/{Basic,Swift,Brute,Elite}`. The existing README documents six MeshPart imports under ServerStorage/EnfleshedModels. Those meshes contain body geometry, not reusable runtime animation tracks; imported templates are absent in the connected test place. Preserve existing imported pivots. Final imported-mesh fitting remains unverified. No new license or provenance claim is made for existing project meshes.

## Coverage and remaining art

| State | Procedural delivery | Final asset dependency |
|---|---|---|
| Idle | Breathing and asymmetrical ready posture | Author per-kind idle loops |
| Locomotion | Actual horizontal velocity drives gait phase; stopped chase settles | Author walk/run loops and root-speed matching for all four kinds |
| Jump/fall | Tucked rising legs, spread arms, falling posture | Author takeoff/air/landing clips for each silhouette |
| Landing | Brief visual compression, no root movement | Author weight-specific landings |
| Telegraph | Existing attack-specific windups | Author anticipation for RushingStrike, PredatoryLunge, FrenziedChain, MaulingCombination, ReversalSwipe |
| Strike | Existing attack/step-specific poses, immediate on received Attack phase | Author strikes/combos fitted to current active windows and hitboxes |
| Recover | Timed return toward ready posture | Author follow-through using existing recovery durations |
| Flinch | Distinct major/minor poses for existing accepted reactions | Author directional minor/significant/major hit reactions |
| Vulnerable | Existing collapsed/exposed posture | Author exhausted/missed-lunge openings |
| Death | Short visual collapse on a separate untargetable copy | Author per-kind deaths; no physical ragdoll introduced |

Any future acquired clips need a recorded creator/source, reuse rights, owning Roblox group/account, real uploaded IDs, and confirmation of six-part R6 joint mapping, proportions, scale and existing damage-window alignment. Player melee/magic clips are not presumed reusable. Acquisition/upload remains a separate dependency; this step does not claim final animation assets are delivered.

## Reproduction

Use a deliberately source-synced Studio Play session. Do not overwrite a saved place or sync unrelated in-progress VFX. Execute `scripts/studio_enemy_animation_review.luau` in the **server** context, then `scripts/studio_enemy_animation_observe.luau` in the **client** context. The server fixture checks Studio/server; the observer checks Studio/client. It temporarily changes only the test camera/UI, restores them after 44 seconds, and exposes bounded JSON in workspace.EnemyAnimationClientReport. The server report is workspace.EnemyAnimationReview.Result. Read both before destroying the fixture folder. Test-only citizen HP and enemy damage probes are not production tuning.

The fixture starts four current kinds, observes idle, explicitly requests a normal jump, starts travel across a four-stud rise, allows existing attacks, probes missed lunges with a moving test target, invokes existing reaction APIs, probes the existing low-health presentation and kills/removes actors. Death visual copies expire separately. Use the existing traversal fixture to repeat raised-edge, stairs, blocker and moving-target crowd tests.

Actual client joint/state evidence and a visible viewport review are separate acceptance checks. Blank or UI-covered capture files are failed visual evidence, regardless of passing state metrics. Final results/limitations are recorded in docs/gameplay-implementation-status.md.

## Engine references

- [Motor6D.Transform](https://create.roblox.com/docs/reference/engine/classes/Motor6D#Transform): not replicated; apply custom transforms on the client after Animator evaluation, before simulation.
- [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService): frame phases used by the client renderer. No global physics or clock changes are made.
