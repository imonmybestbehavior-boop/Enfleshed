# Development Magic Lab and normalized runtime

> **Update 2026-10-14:** the discovery system, its DataStore, Locus resource persistence and Locus practice progression have been removed (Phase 0.3 in [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)). Statements below about discovery milestones, saved Discovery records or Focus profiles are historical.

## Active test configuration

The active fighter sandbox enables spell discovery milestones. Successful casts
advance principle, form, and expression counters used to unlock editor options
and Focus profiles. Mana, Strain, complexity, server validation, and resource
limits remain part of the mechanics under test. The K panel selects a Focus
profile, while P opens the Grimoire to edit, save, and equip spells. Per-spell
power upgrades are not implemented yet.

The Grimoire and magic runtime are part of the active castle fighter sandbox. Open
`Enfleshed-Combat-Sandbox.rbxlx` and press Play to generate the test arena.

## Files

Created:
- `src/shared/Configuration/MagicLab.luau`: development gate and all Lab safety caps.
- `src/shared/Configuration/MagicSchema.luau`: shared editor and validation metadata for Forms, targeting, timing, payload categories, fields, and compatibility.
- `src/shared/Modules/SpellSpec.luau`: immutable legacy normalization, strict data validation, capability lists and estimates.
- `src/shared/Modules/MagicLibraryProfile.luau`: versioned nine-slot profile codec that refuses unsafe profile rewrites.
- `src/shared/Modules/MagicLocusProfile.luau`: versioned codec for persisted Mana, Strain, and configured special-resource pools, rejecting invalid or future profile data.
- `src/shared/Modules/MagicAreaSpec.luau`: pure shared validation for Field/Aura geometry dimensions and shape-specific fields.
- `src/shared/Modules/MagicAreaGrowth.luau`: shared interpolation and shape scaling for optional Field/Aura expansion.
- `src/shared/Modules/MagicConstructGrowthSpec.luau`: pure validation for bounded Construct growth settings and maximum expanded dimensions.
- `src/shared/Modules/MagicTargetConsentSpec.luau`: server-consent attribute and player-versus-NPC eligibility check.
- `src/shared/Modules/MagicAerialMovementSpec.luau`: finite speed and normalized 3D input bounds for the reusable aerial movement payload.
- `src/server/Services/MagicTriggerExecutors.luau`: uniform event-step dispatch to payloads or behaviors.
- `src/server/Services/MagicConditions.luau`: cast and target conditions, LOS and target caps.
- `src/server/Services/MagicPresentation.luau`: replicated temporary geometry, separate from mechanics.
- `src/server/Services/MagicLabService.luau`: development transport, per-player applied specification and server validation.
- `src/client/Controllers/MagicLabController.luau`: contextual editor, local estimates, optional preview.
- `tests/test_magic_lab.lua`: pure-data normalization, caps, unsupported combinations, malformed input, estimates and multi-payload regression tests.
- `tests/test_magic_trigger_spec.lua`: stock-Lua executable checks for trigger alias normalization, deterministic merge order, and legacy flat payload conversion.
- `tests/test_magic_library_profile.lua`: stable slot serialization, hydration and malformed/future-profile protection.
- `tests/test_magic_locus_profile.lua`: current-resource round trip, bounds and unsafe-profile protection.
- `tests/test_magic_area_spec.lua`: each Field/Aura shape, Ring bounds and invalid dimension/field rejection.
- `tests/test_magic_area_growth.lua`: static compatibility, bounded interpolation, scaled dimensions and definition immutability.
- `tests/test_magic_construct_growth_spec.lua`: static compatibility, complete growth settings, and maximum scaled dimensions/volume.
- `tests/test_magic_target_consent.lua`: default behavior, self opt-in, and NPC compatibility for consent-gated targets.
- `tests/test_magic_aerial_movement_spec.lua`: aerial speed caps and malformed/out-of-range 3D input rejection.
- `tests/test_magic_no_spell_identity_branches.py`: guards the generic executor architecture against spell-ID mechanic branches.
- This report.

Modified for this pass:
- `MagicService.luau`: normalize registered data, generic event dispatch, server cast timers, projectile radius/gravity/acceleration/distance, beam width, bounded active effects and cleanup.
- `MagicFormExecutors.luau`: route Projectile and Wave through the existing Form registry as well.
- `MagicPayloadExecutors.luau`: reusable Force impulse direction fallback; no stun.
- `MagicTypes.luau`: normalized specification/trigger/payload types.
- `ActionRouter.luau`: initialize Lab transport with existing authoritative character state.
- `MagicController.luau`: start Lab alongside existing controls.
- `InputController.luau`, `CameraController.luau`: release mouse and suppress gameplay actions while editing.
- The former city prototype place mappings are archived in `Shelved Project`.
- Rebuilt `Enfleshed-Combat-Sandbox.rbxlx`.

Existing uncommitted world/gameplay work was preserved. Registered `Spells.luau` was not edited.

## Normalized SpellSpec

Existing definitions are copied into Version 3 on entry. Their original source schema remains compatible. The normalized structure is:

```lua
{
    SpellId = "Example", Name = "Example", Version = 3, Tags = {},
    Source = { Principle = "Energy", Expression = "Fire" },
    Form = "Projectile", Targeting = "AimDirection",
    Geometry = "Sphere", Motion = "Linear",
    TargetRules = { Range = 90, MaxTargets = 16, RequiresLineOfSight = true },
    Conditions = {},
    Casting = { Mode = "Instant", Cooldown = 0.6, CastTime = 0, RecoveryTime = 0 },
    Lifetime = { Mode = "FixedDuration", Duration = 2.2 },
    Projectile = { Speed = 72, Radius = 1.1, MaxDistance = 158.4, Gravity = 0, Acceleration = 0 },
    Triggers = { OnImpact = {
        { Payloads = {{ Kind = "Damage", Amount = 10 }} },
        { Behavior = "Explode", Radius = 7, Payloads = {{ Kind = "Damage", Amount = 18 }} },
    } },
    Cost = { ManaDemand = 0, Strain = 0, Complexity = 0 }, -- Lab recomputes these
    Visual = { Color = Color3.fromRGB(255, 120, 50), ProjectileScale = 1 },
}
```

Form-specific mechanics live in Projectile/Beam/Field/Wave/Material data. Damage never lives in Projectile. All triggers contain steps with Payloads; behaviors own their payload execution. Legacy OnInterval becomes OnTick, and Wave.Payloads becomes an OnCast step. New conventional spells can reuse these components without another service.

## Grimoire creation flow

Creation starts with an **intent** such as healing, control, summoning, or area effects. Intent is a UI guide, not a saved spell type or a runtime rule. It puts recommended Forms first—for example, Aura and Field for healing—but keeps other Forms selectable when they can start with a compatible effect. The player explicitly chooses the Form, then a supported effect, Principle, and event. The full editor remains available for adding other compatible effects. Changing Form later uses the existing compatibility and confirmation rules; the Grimoire never silently changes the Form or substitutes an effect.

## Supported components

| Component | Implemented | Explicitly unsupported |
|---|---|---|
| Principles | Matter/Earth/Water; Energy/Fire/Lightning/Force; Body/BodyEnhancement; Soul/Spirit; Space/SpatialFold; Time/TemporalShift runtime paths | Broader expression-specific spell content and final RPG balance; use-based rank growth is disabled in the testbed |
| Forms | Projectile, instantaneous or held Channeled Beam, instant Beam Cascade, Wave, Field, Aura, Construct, SelfEnhancement, discrete Manipulation; Field/Aura areas support Sphere, Cylinder, Box, directional Cone, annular Ring, vertical Capsule, and thin vertical Plane/Wall hit volumes | Additional Form geometries and motion profiles beyond this bounded set; arbitrary imported geometry |
| Payloads | Damage (Elemental, Physical, or Soul channel), Force, Heal, periodic Restoration, Shield, Slow, Bind, owner-only Reveal, DamageOverTime, maintained Control, bounded MagicArmor modifier, temporary Transformation, Enhancement, sustained Aerial Movement, Space Displacement, TimeDilation, Manipulation Raise/Lower and Summon | Additional principle-specific payload behaviors |
| Behaviors | Explode on projectile impact; projectile Proximity, Absorb, Reflect, traveling Pulse, Homing, Pierce, Chain, Bounce, Split, Spread and post-impact Linger | Other behaviors |
| Conditions | Bounded ALL/ANY/NOT rules over exposed Caster, Target, Relationship, SpellState, Resource, Environment, Material, Status, DistancePosition, and Time properties; Environment includes exact zone tags, while Status exposes shield, slow, bind, reveal, and MagicArmor state | Arbitrary property access, a full faction framework, and unexposed predicates |

For Cone Fields/Auras, **Reach** is measured forward from the area origin along local `-Z`, **Angle** is the full horizontal angle, **Height** is the vertical thickness, and **Yaw** rotates that direction around world vertical. The overlap query uses the cone's bounding box, then the server checks each Humanoid root against the exact authored cone before applying target rules and line of sight.

Ring Fields/Auras define an **Inner radius**, **Outer radius**, and **Height**. The server uses the outer radius for a bounded broad-phase overlap and accepts only roots between the two radii and within the vertical thickness. This leaves a safe center while allowing any already-supported payload and lifecycle event to affect targets in the annulus.

Fields remain stationary after casting by default. With an `EntityTarget` or `ObjectTarget`, **Follow selected target** attaches the area volume to the validated character or solid surface. If the attachment is removed, destroyed, or invalidated, the field ends through its ordinary `OnExpire` and area-exit cleanup. This can be combined with **Remain active until its target is lost**.

Environment condition zones are invisible server-resolved volumes: tag an oriented BasePart with `MagicEnvironmentZone`, set `MagicZoneId`, and optionally set `MagicZonePriority`. `MagicZoneTags` accepts up to eight comma- or semicolon-separated identifiers (letters, numbers, `_`, `-`, up to 24 characters each). `Environment.ZoneTags Has indoors` checks exact tag membership, not partial text; overlapping volumes use the same priority/zone-ID selection as `Environment.Zone`.

Plane Fields/Auras define **Width**, **Height**, **Thickness**, and **Yaw** for a thin vertical rectangular hit volume. This supports wall-like sheets and gates using the ordinary area payload and enter/exit lifecycle. The Plane is only a hit shape: it does not create collision geometry or block characters from walking through it.

Capsule Fields/Auras define **Radius** and total **Height**. The volume is vertically oriented with rounded ends; height must be at least twice the radius. The server queries a bounded box and then checks each target against the exact capsule, so healing, damage, and other existing area payloads can use the same enter/exit lifecycle. Growth scales both dimensions together and preserves the capsule proportions.

The **Detection** category currently contains **Reveal**. It marks eligible targets for the authored duration; the server replicates an owner-specific expiry, and only that caster's client draws the through-wall outline. Reveal does not add damage, acquire a lock, or ignore targeting/relationship rules. It is capped at 15 seconds and ends early if its caster or target leaves or dies.

Constructs and Self Enhancements may use `OnProximity` with Damage, DamageOverTime, Force, maintained Control, Slow, and Space Displacement payloads. The existing bounded active-proximity query samples nearby valid targets, then sends each effect through the same relationship/condition and server-authoritative executor paths as other Forms. It fires once per eligible target for that active effect, subject to the configured proximity target cap; placement or enhancement activation alone does not apply proximity effects.

Body SelfEnhancement targets self. Material Manipulation requires Matter, a server-tagged Earth-affinity material part, and `MagicRaise` authorization. Its discrete Raise and Lower operations can be used on a Manipulation cast or placed on Projectile impacts, Beam casts/ticks, and Wave casts/ticks when ObjectTarget is selected; the server checks the exact unobstructed part, matching `MagicMaterial`, and authorization before moving it vertically. Force and Physical control remain available on those Forms for explicitly tagged movable parts without a material attribute. Earth-affinity material casts can consume tagged Earth, Metal, or Wood sources; Water-affinity casts use tagged Water sources. Damage and Force can coexist on combat Forms; Enhancement remains restricted to its matching Form. Force adds velocity only: it does not create status or stun behavior. Bind is an explicit, separately selected control payload; it temporarily prevents walking, jumping, and dashing, then restores movement according to any remaining Slow or enhancement effects. Its duration is capped by the development configuration.

ObjectTarget eligibility for Projectile/Beam/Wave physics and authorized manipulation, Manipulation Form casts, and solid-surface attachment for Fields/Auras/Constructs uses a pure shared ruleset before the server performs the exact raycast/obstruction check. Physics requires a collidable, tagged, non-character, movable assembly with finite positive mass; authorized material manipulation also checks matching material and `MagicRaise`, and may use anchored tagged parts. The client selection remains an untrusted hint. Run `lua tests/test_magic_object_target_spec.lua` for the eligibility matrix; use Studio to validate live ray hits, walls, streaming, and assembly physics.

Events: Projectile exposes OnCast/OnSpawn/OnImpact/OnProximity/OnTick/OnExpire (OnProximity requires the Proximity behavior; OnTick runs while traveling with Pulse or after impact with Linger); Beam exposes OnCast and OnImpact at its server-raycast endpoint, plus OnTick for each channeled pulse; humanoid-targeting forms expose OnThreshold when their spell damage crosses its configured target-health percentage; instant Wave exposes OnCast; Field and Aura expose OnCast/OnSpawn/OnTick/OnExpire; SelfEnhancement and Manipulation expose OnCast. Beam OnImpact is available to its compatible payloads, so impact spells can compose without a Beam-specific payload executor.

Summon payloads default to **Caster** placement, which preserves the existing desired-count/refresh behavior. **Event** placement uses the server-resolved trigger position and adds the authored count each time that trigger fires, up to the existing server caps. The summon anchor is offset behind the incoming cast direction so a beam striking a floor does not place the anchor beneath its contact surface. A Channeled Beam can pulse while the player sweeps aim; an instant Beam can instead use **Cascade** to send a bounded sequence of vertical, obstruction-checked strikes around one aim point. Every strike emits its own Beam `OnImpact`, so Event-placed summons can appear at those actual contact points. Choose Hunter for local hostile acquisition, and select an equipped companion spell slot so each summon uses the ordinary server spell runtime. Summons retain source spell color and obey ordinary summon lifetime, commands, cooldown, line-of-sight, and companion-spell validation.

For an automatic cascade test, create an **Energy → Beam**, leave Cast style at **Instant**, and choose **Cascade** under **Beam pattern**. Set the strike count, spread radius, drop height, and interval, then add an `OnImpact` Summon payload with **Spawn at = Event**, **Hunter**, and an equipped hostile companion spell slot. Aim at a floor or other solid area within range. Each server sweep stops at the first physical obstruction; a ceiling can intercept a strike, and only actual contacts dispatch `OnImpact`. The sequence is bounded to eight strikes and consumes one active-effect slot while it runs. Use any Element color; the system does not require Fire or a special spell identity.

## Authority and validation

The client edits a copy, performs advisory validation and sends Apply. The server checks the full schema, types, finite values, bounded depth/size, compatibility and limits. It assigns one fixed temporary spell identity and recomputes cost estimates. Client-supplied development privileges are rejected. Cast sends only aim and world point; the server uses its own character, origin, definition, cooldown, material checks and hit detection.

The existing registered cast transport and DamageService remain authoritative. Normal registered spells retain mana/strain rules. Lab spells bypass ordinary resource consumption/capacity for experimentation; Channeled Beams are the exception and pay their authored startup cost and continuous mana upkeep so depletion can be tested. Estimates are not final balance. They still obey physical obstruction, valid targets, cooldowns and safety caps. Applying a different draft cannot reset its cooldown. Applying clears a temporary enhancement/pending cast; previously launched effects finish under their own bounded lifetime. Respawn/death clears active effects; leaving releases per-player state.

Summon payloads can opt into **Persist Until Dismissed** under Owner death behavior when their lifetime is **UntilCommanded**. That party waits up to 60 seconds for the owner to respawn, then rebinds and resumes its current order; disconnect always removes it. Fixed-duration summons and the default Dismiss on death policy keep the prior cleanup behavior.

Casting rules can require at least one free hand. The server checks the active equipped item's hand occupancy when a cast resolves and continues checking maintained channels; channels end if the item/rig state no longer leaves a hand free. Current recruit weapons occupy one hand, while future rig profiles may provide `MagicHandCount` and item definitions may declare `HandsOccupied`.

## Saved spell slots

The Studio Magic Lab now loads the player's nine fixed slots when the **P** menu opens and saves each applied slot to the versioned `EnfleshedMagicLabLibraryV1` DataStore. Saving is debounced and performed with `UpdateAsync`; slot definitions are revalidated on load and before write, computed costs are recalculated, and the Lab-only `Development` capability is never stored. Unknown profile versions, malformed slots, and invalid saved definitions are left untouched. If Studio API access or DataStore access is unavailable, the Lab reports that it is using a session library and still permits editing/testing without overwriting the saved profile.

For cross-session Studio testing, publish the place to a private test experience and enable **Game Settings → Security → Enable Studio Access to API Services** for that test experience. Do not use production player profiles for development spell data. The spell-library data store is separate from the registered live spell registry. Locus Mana and Strain use a separate profile store and persist across respawn. The five canonical metrics stay at the values in `MagicLocus.luau`: the successful-cast practice curve is retained for future balance work but disabled in this unrestricted testbed. If DataStore access is unavailable, casting falls back to session resources after the load attempt and the saved profile is not overwritten. The pure codecs are covered by `tests/test_magic_library_profile.lua`, `tests/test_magic_locus_profile.lua`, and `tests/test_magic_locus_progression.lua`; actual persistence still needs a two-session Studio test with API access enabled.

`MagicLocus.SpecialResources` defines named resource pools separately from Mana and Strain. The development registry currently includes Focus, which begins at 100, recovers at 4 per second, and is exposed as server-set `MagicFocus` and `MagicFocusCapacity` player attributes. In the Setup page, set **Focus cost** above zero to require that pool; the server checks and spends it for player and companion casts. Conditions can also compare `Resource.Focus` or `Resource.FocusPercent`, including as an active spell's keep-alive rule. Special costs are visible in the estimate, capped by `MagicLab.MaxSpecialResourceCost`, and persist in the version-2 Locus profile. Version-1 profiles migrate safely by receiving configured starting values for each new pool. This is a generic registry extension point; adding a pool is configuration work and does not alter cast validation or spend dispatch.

Projectile collision uses sphere sweeps, including an initial part-overlap check. Beam uses a ray at width zero and a sphere sweep for nonzero width, stopping at world obstruction. AoE respects LOS by default. Target cap applies to each payload step/query; it is not a shared cross-event hit budget. A target may receive both direct and explosion damage intentionally.

An old impact path applied explosion payloads directly and again via Explode. The normalized dispatcher removes that duplicate application. Fireball now applies its configured direct 10 plus explosion 18 once each before player potency, rather than accidentally applying explosion damage twice.

## UI and exposed values

**P** opens/closes the Lab. It opens to a nine-slot menu: select an occupied slot to edit that spell, or an empty slot to create a new one. The selected slot stays visible in the editor header. Use Setup, Targeting, Effects, Presentation and Test to edit/test that slot; **SAVE SLOT** applies the edited spell back to it, while **BACK TO SLOTS** returns without discarding unsaved edits. The cursor is free in the panel and normal controls resume when closed.

Common: Principle, Form, targeting mode/range, max targets, LOS, cooldown, cast time, recovery, casting mode, charge times or channel mana upkeep, conditions and applicable event/payload controls. Geometry/Motion are constrained by Form, not arbitrary incompatible editable strings.

| Form | Contextual values |
|---|---|
| Projectile | Speed, radius, maximum distance, gravity, acceleration, duration, impact/proximity/tick Damage/Force, Explode, Proximity, Absorb, Reflect, traveling Pulse, Homing, Pierce, Chain, Bounce, Split, Spread, and Linger |
| Beam | Length/range, width, optional Channeled range/width growth, server pulse interval, Damage/Force; instant or held Channeled mode |
| Field | Radius, duration, tick interval in seconds, per-event Damage/Force |
| Wave | Cone or Sphere shape, Range, cone facing dot (-1 radial), optional Channeled range growth, Damage/Force |
| SelfEnhancement | Movement multiplier, walk bonus, jump bonus, toggle or timed duration |
| Manipulation | Tagged material search radius, vertical movement operation and distance |

Fields and Auras can choose **Sphere**, **Cylinder**, or **Box** under Form Mechanics. Sphere uses Radius; Cylinder uses Radius and Height and is upright; Box uses Width, Height and Depth. Box volumes can rotate around world vertical using **Yaw (degrees)**, bounded from -180° to 180°. All retain the same pulse interval and target/LOS rules. Their local test preview depicts the selected server hit volume, and Field's marker height remains presentation-only.

Charged casts build while the equipped slot's number key is held, release on key-up, and automatically release at MaximumCharge. Channeled Beam begins on press, locks the initial aim direction, follows the server-known hand origin, pays its authored mana upkeep and pulses at the configured interval until key-up or a hard limit. Recovery is a reuse floor combined with cooldown, not a movement lock. Enhancement uses the existing MovementService integration, multiplying walking and sprinting without competing WalkSpeed writes. Repeating an applied toggle with 1 turns it off.

The Lab authors a blank SpellSpec draft; the registered spell library is not used as a source of templates and is not modified by Lab edits.

### Persistent Field and Aura toggles

Field and Aura drafts can use a toggle lifetime alongside their existing fixed duration. The first cast creates the normal server-owned area and interval pulses; casting the same spell again turns it off. Toggle-off emits `OnExpire`, closes sampled membership with `OnExit`, and removes the replicated marker. SelfEnhancements and Constructs also expose `OnExpire`: it runs on normal duration end, resource/condition termination, toggle-off, caster reset, or construct removal. Construct expiry payloads can affect its still-valid attached character; self-enhancement expiry payloads target the caster. Active-effect limits still apply, and respawn/disconnect cleanup remains authoritative; instantaneous Forms cannot be toggled.

Constructs may use **Remain active until the Construct is destroyed**. That removes the authored timer but retains server cleanup on model removal, caster cleanup, and any other active termination conditions. It does not add Construct health or player damage interaction; destruction currently comes from server systems removing the model.

Projectile flight, Fields, Auras, Self Enhancements, Constructs, and channeled Beams/Waves may use **Remain active while a condition stays true**. The selected `EndWhen` rule becomes a keep-alive predicate: it must evaluate true when cast or activation is rejected, and the effect expires through its Form's ordinary cleanup when the rule becomes false or unavailable. Condition-bound Projectiles and channels require a maximum duration. Other condition-bound effects may optionally add a maximum duration, so whichever happens first—the condition failing or the timer ending—expires the effect. The timer is bounded to 0.1–15 seconds and uses the same normal cleanup path. The starter rule is `Resource · Mana > 0`; it does not spend mana on its own. Add Mana upkeep if the spell should drain Locus while maintained.

## Summons: quick setup and behavior

Think of summoning as four separate decisions: **call the companion**, choose its **policy**, optionally assign one **companion spell**, then issue a temporary **order**. These are separate on purpose: the summon is a caster of an ordinary server-validated SpellSpec, not another kind of spell Form.

There are **two different spell slots** involved:

1. Equip the spell that contains the `Summon` effect in one of your spell slots.
2. In that effect, choose a different equipped slot under **Companion spell to cast** if you want the summon to use magic. New Summon effects default to **None** so they do not silently point at an empty or unrelated slot.

With **None**, Guardian and Hunter still work: they follow you and use their basic attack. Medic and Controller deliberately wait for a compatible spell. A companion spell must be equipped, use a supported target Form, and contain a supported combat or support effect. Attack spells need Any/Hostile targeting; healing and protection spells need Ally targeting. The editor shows the selected slot's spell name and compatibility. Companions use your normal server-side magic resource limits.

The chosen **trigger event** controls when the companion appears. For a first test, use a Form/event that supports `OnCast`: casting immediately calls the companion. Projectile and Beam `OnImpact` wait until they contact an entity or obstacle. With the default **Caster** spawn position, repeated events refresh the existing group; **Event** placement instead adds a bounded group member at each server-resolved trigger point. Count, lifetime, and archetype are set in the Summon effect.

The **role** is the summon’s allowed targeting policy; the **order** is its temporary current intent. Guardian is the default and protects you from visible hostiles within its guard radius. Hunter searches a wider local radius. Both can use their built-in attack or a compatible assigned offensive spell. Medic only uses an Ally healing/protection spell. Controller needs a hostile spell with a supported control effect. Orders are: `N` selects a summon; `Z` Follow suspends target search; `X` Protect resumes role-based behavior; `C` Attack directs it to the hostile under the crosshair; `G` Support searches for an ally who needs the assigned Ally spell; `B` Move; `J` sets a two-point patrol; `H` Hold; `V` dismisses all. With no selection, orders apply to the owner’s active groups; selecting with `N` limits the order to that summon.

One additional distinction affects companion spells: **CommandCast** deliberately waits for an Attack or Support order. Instant, Charged, and bounded Channeled spells can act when the role/order finds a compatible target. All companion casts still use the owner’s normal server-side resource limits and cooldown checks. Targeting requires valid relationship rules, range, and an unobstructed line of sight; summons do not cast through walls or acquire arbitrary untagged hostiles.

The two current archetypes also have separate bounded procedural silhouettes: the Wisp is a luminous orb with six orbiting lights, while the Ward Sentinel has a slate core surrounded by four metal guard plates. These are cosmetic; they do not add collision, targeting, or damage rules.

For a Beam composition test, equip a Channeled Beam in slot 1 with an `OnImpact` Summon payload set to **Event**, **Hunter**, and companion slot 2. Equip a compatible hostile spell in slot 2, aim at solid surfaces around a tagged hostile area, then hold and sweep the Beam; each actual ray hit should add one companion at that endpoint until the existing cap is reached. Use an Ember palette/color to make the summoned units inherit a fiery placeholder appearance. Then open the **Summons** HUD and check each unit’s assigned-spell status. Summon lifecycle and companion casting remain server-authoritative in `SummonService` and `MagicService`.

For a basic summon test, equip a simple OnCast Summon in slot 1 and leave its companion spell as None. Cast it and use Protect near a living Enfleshed or a training model tagged `MagicHostileTarget`, with a clear line of sight. A Guardian will only attack if the hostile is close enough to you; use Hunter to test the summon’s wider search. It should use its basic attack. To test support, assign an Ally Heal or Shield spell and use Support near an injured ally training dummy. If it does not act, the HUD’s reason distinguishes missing hostile registration, no living target, Guardian protection radius, scan range, blocked view, invalid spell, cooldown, and resource/casting limits.

## Estimates, visuals, safety and performance

The deterministic estimate responds to range, radius, speed, duration/tick count, damage, force, multiplier, target count, payload count and behavior count. It provides mana demand, strain and complexity, recomputed on the server. It is a development heuristic, not a player stat system.

Replicated projectile/beam/field/wave/explosion markers show actual casts. An optional local geometry preview lasts 1.5 seconds and clears before another preview. It does not cause hits. No final VFX system or assets were added.

Server particle presentation is bounded independently from gameplay geometry: concurrent emitter count, aggregate continuous particle rate, and burst particles per second have centralized limits in `MagicPresentation.luau` configuration. When pressure reaches a limit, cosmetic particles are reduced or omitted; projectile collision, damage, and core marker/beam geometry still run normally. `lua tests/test_magic_presentation_budget.lua` exercises the refill and concurrency limits. Studio playtesting should still observe dense multi-client casting to tune these defaults against Roblox's actual rendering and network cost.

Defaults: damage 100 per payload; Force 100 plus upward 30; radius 20; range 200; duration 15s; speed 200; acceleration magnitude 100; gravity 100; cooldown at least .15s; tick interval at least .1s; 16 targets; movement multiplier up to 4; jump bonus 30; eight payloads total, four per step, four steps per event; eight active effects/player and 64 globally. Requests are limited to one per .1s. Source spell validation remains compatible; client edits obey the stricter Lab limits.

One shared Heartbeat advances bounded projectile/field state. Field queries run at their configured interval without a lag-induced catch-up burst. No per-projectile Heartbeat connections or per-frame editor rebuilds. Initial overlap occurs once per projectile. Temporary markers use Debris; death/respawn/disconnect removes active objects. Large AoE and many simultaneous fields still need real multiplayer performance testing.

The default gate is Enabled=true, StudioOnly=true, AllowLive=false. A live development deployment requires explicitly changing both StudioOnly and AllowLive; there is no player-facing unlock.

### Projectile appearance scale

The Presentation page exposes a 1×–4× projectile appearance slider. It scales the visible core, particles, and trail while the configured Projectile Radius continues to control server hit detection and collision. Appearance scale is validated as visual-only and does not change estimated mana demand, strain, or complexity. Non-projectile Forms keep the control visible but disabled.

Material appearance may be set explicitly or left on Auto. Auto selects a restrained Roblox material from the spell's Principle/Expression; Constructs retain their established Slate default. The same shared mapping drives the server-rendered effect and local preview.

Studio check: compare the same projectile at 1× and 3× against a row of dummies and a wall. Its visible body should grow while impact reach and damage remain governed by the unchanged Radius and payload settings.

## Studio playtest

Projectile drafts can add up to the configured motion-phase limit and choose **Bezier** for a bounded cubic curve. Set **Side curve** and/or **Vertical curve** to shape the path; each is clamped by server validation. Bezier ignores gravity and acceleration by design, but still uses the authored phase duration and speed multiplier. Collision sweeps each actual curve segment, while the projectile's visible scale remains independent of hit radius. For a quick check, add a 1-second Bezier phase with Side curve 10 and Vertical curve 4, then fire past a row of dummies; the shot should visibly arc sideways/upward and still collide with anything intersecting its path.

### Casting movement rules

The Setup page allows spells to keep movement enabled with a bounded speed penalty, prevent movement, or prevent mouse-look rotation during charge, server-timed gather, and held channels. These rules are server-validated; a movement penalty composes with sprint, Body Enhancement, and Slow, while a full movement lock also blocks jump and dash. Rotation lock freezes client mouse-look, retains the server-validated initial aim through charge/gather, and rejects channeled aim updates. Movement and camera control return on cast completion, interruption, release, death, or respawn. Studio check: test a 50% penalty while sprinting and while Body Reinforcement is active, then disable movement and rotation during a charged cast and channel; cancel each and confirm the prior speed, aim control, and dash access return.

1. Stop any current session. Open **Enfleshed-Combat-Sandbox.rbxlx** with Studio's File → Open from File and press Play. The server generates the castle arena and spawns the player directly into combat.
2. Press P. Select Fireball. Set radius 1, speed 100, direct damage 10. Apply, close, aim at an existing target, then 1. The existing combat hit feedback should report damage.
3. Reopen P: radius 8, speed 35, direct damage 50, Explode enabled, explosion radius 12. Cast Test. Expect a slower, much wider projectile. Stand away from nearby walls/floor when comparing travel: an eight-stud radius can correctly collide immediately with close geometry. Do not interpret an immediate overlap hit as a failed cast.
4. Select BodyReinforcement, multiplier 3. Apply and 1. Compare walking and Shift sprint; Q dash and normal controls should remain available. 1 again disables the toggle. Test a timed duration too.
5. Select BurningGround; change radius, duration, tick interval and damage. Aim at visible ground within targeting range. 1. Check repeat damage only while targets occupy the field and cessation after expiry. Walls should block LOS damage by default.
6. Select LightningLance. Test zero and nonzero width against a target, then put solid geometry between caster and target. The wall must stop the beam.
7. Add Force alongside Damage on a draft. Confirm displacement without a new stun/control-lock. Material-target spells show a source-material picker; aim at its matching tagged Earth, Metal, Wood, or Water source. For Manipulation, choose Raise or Lower and test on a tagged part with `MagicRaise=true`; it should move by the authored distance in the selected vertical direction. Ordinary walls are not valid material targets.
8. Change Forms after adding effects. Keep effects that remain compatible and omit only those that the new Form cannot execute. Try unsupported Soul and out-of-range numeric values: Apply must reject with a reason.
9. Use Studio's Server & Clients test with two clients. Each client has independent Lab drafts/applied state; gameplay damage is server-owned. Check cooldown spam, death/respawn and disconnect during active fields/projectiles.
10. Close the Grimoire and retest equipment, sprint/dash, melee, and registered spell controls.

Aerial movement check: create a Self Enhancement with **Aerial movement** on **OnCast**, set speed to 32, apply, and cast it. WASD steers horizontally, Space rises, and Left Control descends; gamepad uses A/B, with Rise/Descend touch buttons. Release the controls to hover. Cast a separate speed Enhancement at the same time and confirm both effects coexist. Let the aerial spell expire (or cast its toggle again) and verify normal gravity and walking return. Try moving into a wall and confirm collision remains solid.

For Detection, create a Field or Aura with **Reveal** on **OnEnter**, choose an eligible hostile, and set duration to 8 seconds. Let the target enter, then have it move behind solid cover. The caster should still see its colored outline through the wall; a second client should not. Reapply Reveal before expiry to confirm the mark refreshes, then verify expiry and target/caster death remove the outline.

For Time, create a Time / TemporalShift Aura with **TimeDilation** on **OnTick**, rate 0.5, duration 5 seconds, and target a hostile. Confirm the target moves at half rate and any active Slow, Bind, Shield, or periodic DamageOverTime duration/ticks progress more slowly; the TimeDilation itself should expire after five world seconds. Repeat at rate 1.5 on an ally and confirm movement and periodic Restoration accelerate. An authored target condition on `Status.TimeRate` should distinguish the affected target from one at the default rate. Test with two clients to confirm the server remains authoritative.

Aerial Movement is a Self Enhancement payload. Its speed is bounded to 48 studs/second; the client sends only normalized movement intent at a throttled rate, and the server validates full 3D travel against the active limit. The spell's ordinary duration, toggle, and resource lifecycle controls cleanup. This is not target-applied flight or unrestricted teleportation.

For a target-bound effect, choose Aura or Construct and target a character or solid object; Fields need **Follow selected target**, and Projectiles need the `MaintainTarget` entity policy plus Homing. Enable **Remain active until its target is lost**, then remove or kill the target. Areas run expiry/exit cleanup, Constructs are destroyed, and maintained Projectiles run `OnExpire`. Free-standing or non-following effects reject this lifetime.

## Validation and remaining work

Offline checks cover data, formatting/parsing, project builds, references and geometry invariants; they do **not** execute Roblox physics, GUI input, replication or Humanoid movement. Studio testing above is still required. No standalone Luau typechecker is installed in this workspace.

Before player-facing magic: design permissions/progression separately, establish balance/resource economics, define faction rules, perform adversarial multiplayer/load testing, replace placeholder presentation, provide accessibility/gamepad/mobile editing alternatives if desired, and decide which currently unsupported components actually belong in scope. Do not expose this development transport as a player spell editor.

Recorded offline results (2026-09-28):
- Earlier validation covered the registered spell definitions and Magic Lab constraints; the current editor no longer offers preset selection.
- StyLua check passed for the touched runtime, controller, configuration, type and test files.
- Rojo 7.7.0 built both requested places successfully.
- Main-place reference/source checks: three tests passed.
- `git diff --check` passed.
- Studio execution and standalone Luau typechecking were not run; the latter tool is not installed.

## Expanding Fields and Auras (2026-10-08)

Fields and Auras can optionally declare `GrowthStartScale`, `GrowthEndScale`, and `GrowthDuration` alongside their ordinary shape dimensions. Configure all three, or leave them blank/zero for a static area. The server linearly interpolates the scale by active age, applies it to every dimension of the selected Sphere, Cylinder, Box, Cone, Ring, Capsule, Plane, or Line, and uses the same scaled dimensions for overlap queries and exact membership. The replicated area marker follows those dimensions. The expansion caps the largest resulting dimension at the normal configured area limit. Expansion may grow or contract and holds its final scale until the spell ends. Channeled Waves can use the same three bounded values to grow or contract their server cone reach over channel age; damage queries, object-target reach checks, debug telegraphs, and the local preview all use the corresponding authored or interpolated range. Channeled Beams can scale length and width together, keeping sweep radius, obstruction endpoint, and replicated beam width synchronized. Instant Beams and Waves reject growth because they have no active geometry lifetime. This does not add new active-effect lifetimes or client-authored hit geometry.

Constructs also accept those three growth values. The server scales the actual anchored model, so all authored collision pieces grow together; the visible preview begins at the configured start scale. On surface-attached shapes, the contact face remains flush as dimensions change. Every 0.1 seconds, the server checks the proposed expanded envelope against collidable world parts and Humanoids, plus six axial ray checks that also detect Terrain; if blocked, growth pauses at the last clear size and tries again. Each maximum dimension remains at or below 20 studs and maximum volume at or below 2,000 cubic studs. Growth can expand or contract, holds its final scale, and does not change the normal Construct lifetime or damage behavior.

Studio test: in the P editor, make a Field or Aura and give it an ally-targeted Heal/Restoration payload. Set start scale to `0.25`, end scale to `1.5`, and duration to `3`. Cast beside an injured ally just outside the initial boundary; the marker and healing reach should expand together. Repeat with a Ring and a Cone, verify the inner hole and direction remain correct, then remove one growth value and confirm server validation rejects the incomplete configuration. Leave all three unset and confirm an existing spell remains static. For a Construct, use the same scales and duration with a small Bridge or Pillar, cast it against a wall, and confirm its contact face stays attached and its collision grows. Put another solid or character in the expansion path; growth should pause before overlapping it, then resume if the path clears. Check that an unobstructed Construct reaches the authored end size and still expires normally.

## Optional target consent (2026-10-08)

`TargetRules.RequiresConsent` defaults to false, preserving every existing definition. When true, the server requires player-character targets to have the server-owned `MagicAcceptsTargetedSpells` attribute set to true. Direct EntityTarget validation rejects a non-consenting player; the shared target filter excludes them from other Forms and summon-cast payloads. NPCs, Enfleshed, and training dummies are unaffected. The consent preference is session-scoped and defaults off. The Studio Magic Lab Test page has a self-only opt-in toggle, and Targeting exposes the per-spell requirement. A remote client can change only its own consent value, through the ordinary sequenced and rate-limited action route.

Studio test: use two clients. Keep client B opted out and cast a `RequiresConsent` projectile/Field/Aura at or around B; B should receive no payload effects. Opt B in on the Magic Lab Test page and repeat; B should now be eligible. Repeat against a training dummy while B is opted out to confirm NPCs remain eligible. Finally disable `RequiresConsent` and verify existing spell behavior remains unchanged. The consent control is currently a development test setting; a player-facing preferences screen and persistence remain future work.


## Aura and source-free Construct expansion (2026-09-29)

SpellSpec, MagicTypes, the Form registry, MagicService, Lab UI and data tests were extended. Registered Version 3 definitions can use the same validator; legacy registered definitions still normalize as before.

Aura uses `Aura = {Radius, Interval}`, Self targeting, Sphere geometry and FollowCaster motion. It follows the server character root, excludes the caster, respects LOS, applies configurable Damage/Force on ticks, and expires with its duration or caster death. Force is radial from the caster; no stun is added. Radius and tick interval use existing area limits. Estimates account for Aura tick frequency.

Construct uses `Construct = {Width, Height, Depth, Distance}`, AimDirection targeting by default, Box geometry, Stationary motion and a fixed duration. It has no material requirement. AimDirection creates the geometry in open air at the configured range; if the aim ray hits a wall, floor, or character, it snaps flush and attaches there. WorldPoint places at a chosen point within the configured range. ObjectTarget and EntityTarget remain optional exact-attachment modes. Pitch determines elevation and yaw determines facing. Width/height/depth each allow 0.5–20 studs, volume is capped at 2,000 cubic studs, and placement distance at 4–40 studs. Placement does not require surrounding free volume, so a Construct may overlap existing geometry. Dimensions and distance are editable; there is no free rotation gizmo. Existing active-effect counts and lifetime limits apply. Platforms disappear on expiry/death/disconnect unless the static-Construct Persistent lifetime is selected.

Construct supports the built-in Box, Sphere, Cylinder, Wedge, Arch, Pillar, Stairs, and Bridge shapes, plus **Custom** compositions of up to five Box, Sphere, Cylinder, or Wedge primitives. Each custom part has normalized size, offset, and rotation fields; validation checks rotated bounds against the overall Construct envelope. A custom part may also opt into an independent 0.1–15 second expiry; parts without one inherit the Construct's normal lifetime. When the last part expires, the whole Construct uses its ordinary `OnExpire` and cleanup path. The same registry drives the editor preview, complexity estimate, and server-created collision parts, so the preview cannot author geometry the server does not validate. Ordinary Constructs create temporary collision geometry and do not add health, damage, or resource-object behavior. The opt-in Persistent lifetime is limited to static, trigger-free Constructs; bounded records are saved per place, restored when a server starts, and removed from storage when the server destroys/removes their model. It requires Studio API Services access and is not a live-game authoring path. Aura supports the Field event set. Stone Shot and Stone Raise retain their existing tagged-source rules.

Studio checks:
1. P → choose **Aura** → Effects → add Damage → Test → equip → close → cast from the selected number slot. Walk near an existing enemy: the ring follows you, Damage repeats at the chosen interval, and stops after the duration. Add Force to test outward displacement. A wall must block effects with LOS enabled.
2. P → choose **Construct** → Effects-independent Test → equip and cast, aiming into clear air. It must work without any material source or selected object. Test open-air placement, WorldPoint placement, automatic wall/floor/character attachment, collision, expiry, and placement that intersects nearby geometry.
3. In the same blank Construct draft, adjust Distance/Height/Width/Depth, aim slightly downward into clear space, then cast both in open space and where the resulting shape overlaps a nearby wall or floor. Both placements should succeed; confirm the geometry can visually or physically overlap the environment.
4. Use two clients to check shared collision, independent casts and death/disconnect cleanup. Recheck normal magic and movement.
5. For Persistent, publish a private test place, enable **Game Settings → Security → Enable Studio Access to API Services**, select **Persist in this place between servers**, cast a Construct on static geometry or in open air, stop Play, and start a fresh server. Confirm it restores. Destroy the server-side model in Workspace, restart again, and confirm the record stays removed. With API Services disabled or DataStore unavailable, the cast must fail with feedback and create no model.

Automated expansion checks covered multi-payload Aura, unsafe interval/dimension/distance rejection, no material dependency and no Construct damage triggers. Engine placement, movement and multiplayer behavior still require Studio verification.


### Construct attachment update

A server ray now attaches a construct flush to the first wall, floor or character within its configured Distance. The box remains upright and its dimensions determine the offset from the surface. A camera aim point is used only after directional validation; server raycasts decide the actual target. With no hit, it still forms in open air. Other occupied geometry can still reject placement.

Attachments follow moving target Parts using a relative transform. Character attachments are non-colliding and do not weld/anchor or trap the target rig; world attachments remain solid. Target removal/death removes the attached construct, as do the existing caster cleanup and lifetime rules.

Test a blank **Construct** draft against a wall and a character, then aim another draft at the floor. Adjust Distance if the target is too far away. Move the target to verify following; kill/remove it to verify cleanup. Check tight corners with large dimensions: open-air placement must still succeed even when the shape intersects nearby geometry. Offline data/reference/build/format/whitespace checks pass; attachment physics and visual alignment require Studio playtesting.

### Focused verification and feedback pass

Offline findings addressed:
- Magic Lab status was hidden once the editor closed. A single reusable, three-second feedback label now displays cast success, rejection reasons and damage while playing. It uses one update connection; hits do not create new GUI objects or delayed cleanup tasks.
- Aura broad-phase bounds queries could include roots outside the stated radius. Aura now also requires root distance within that radius.
- Field/Aura could tick on their expiry frame. Scheduled tick payloads now stop at expiry; explicit OnExpire payloads still execute as authored.
- Construct box/plane offset calculation is isolated in `MagicGeometry.luau` and exercised by `tests/test_magic_geometry.lua`: floor, wall, ceiling and slopes; all eight corners must remain outside the contact plane, with the nearest touching it.

The existing server authority, character attachment following and death/leave cleanup paths were reviewed. This is not a live multiplayer verification. No Studio connector or installed Studio test runner was available in this session.

Focused manual acceptance test in the rebuilt combat sandbox:
1. P → choose Construct → Test → equip → close. Aim at a wall within Distance and press the selected slot key. Verify contact placement, visible cast feedback, and collision. Try a tight corner: if rejected, the on-screen reason should be readable. Repeat with a separate Construct draft on floor and a sloped surface.
2. In a two-client test, attach to the other character, then have them move and turn. Confirm following without pinning/flinging. Kill/reset the target; attachment must disappear. Repeat and reset the caster instead, then repeat and disconnect the caster. Neither client should retain an orphaned construct.
3. Aura draft: add Damage and test just inside/outside the configured root radius and behind a solid wall. Add Force and verify outward displacement without a stun. Verify no further periodic damage after duration ends.
4. Retest Fireball and LightningLance near/far targets with vertical aim, then while standing close to a wall. Confirm the crosshair and actual impact agree sufficiently for play; report any offset with the spell, distance and screenshot. Camera behavior was not changed by this pass.

Formatting, geometry/data tests, source/reference validation and both Rojo builds were run. Physics, GUI appearance, camera accuracy and two-client behavior remain pending manual Studio confirmation.


### Nine-slot loadout and multiplayer physics update

**P** opens/closes the editor and loads the saved library. Select a slot (1–9), choose/edit a spell, and press **SAVE SLOT**; **SAVE + CAST** applies it and then casts. Number keys **1–9** cast equipped snapshots; editing a draft does not disable other slots. The on-screen list shows all assignments. These development bindings take priority over the old numbered preset controls while the Lab is enabled. Each player has a separate nine-slot server loadout with debounced persistence and a session-only fallback. Replacing a slot preserves that slot's cooldown and removes only its enhancement/pending cast. Repeating a toggle uses that same slot. Current Locus Mana and Strain persist in a separate profile and are preserved through character respawn.

The slot menu loads the player's saved spell library when opened. Drafts remain local until the user applies a slot; applying updates the authoritative per-player slot and schedules the versioned profile save. If DataStore access fails, the same UI remains usable with session-only data.

`MagicSlots.luau` defines and validates the nine fixed identities; `test_magic_slots.lua` covers invalid indices and stable unique keys. Loadouts are bounded server-owned copies. Apply responses identify the action and slot so a rejected cast cannot accidentally acknowledge a pending equip. Casts include the current character and reject stale pre-respawn requests. Combined movement bonuses remain capped even with several equipped enhancements.

Force now uses a mass-scaled physics impulse. Anchored targets are skipped. Player-owned assemblies briefly transfer simulation to the server for .2 seconds; one shared cleanup loop restores their previous ownership mode. A one-second, server-only horizontal movement allowance (capped at 120 studs/s extra) prevents ordinary magic pushes from being mistaken for speed violations. Wall/dash safety remains active. This is bounded development physics handling, not a generalized status system or final anti-cheat.

Additional Studio test: equip Fireball in 1, Aura in 2, Barrier in 3, and Reinforcement in 4. Alternate all four; verify separate cooldowns and that editing/replacing slot 3 does not remove slot 4's enhancement. Use two clients with different loadouts. Test Aura Force against the other client, movement recovery without snapback, repeated pushes, wall contact, caster/target death, and disconnect during an impulse. Check Studio Output for errors. Live physics and multiplayer results remain unverified here because Studio is unavailable.

### Elements, damage over time and Beam readability

The Lab has an **Element** picker: Neutral, Fire, Ice, Lightning, Earth, Water, Wind, and Poison. It remains separate from the Principle, controls presentation color, and supplies the damage type for the spell's magic damage payloads. Water is also a Matter expression and source profile, but selecting Water as an Element does not add water-specific payload behavior or material physics. A target may define a server-owned numeric attribute such as `MagicResistanceWater` between 0 and 1; 0.25 reduces matching incoming magic damage by 25%, and 1 grants immunity to that type. `MagicArmor` is a flat reduction applied after resistance, capped at 100. Missing attributes mean no resistance or armor. Non-magic combat damage is unaffected. Element does not add burning, freezing, stun, or another status effect; those require explicit payloads.

Studio check: make a Matter spell, select the Water expression and Water Element, then cast it at a training dummy. Add `MagicResistanceWater = 0.5` to one dummy and leave another without that attribute; equal hits should deal half damage to the resistant dummy. Change only the Element to Neutral and confirm Water resistance no longer applies. Water source consumption is a separate Matter material requirement and is not implied by the Element selection.

Combat Forms can combine **DamageOverTime** with Damage and Force. Controls are **Damage per hit/tick**, **DoT duration**, and **DoT tick interval**. Damage goes through the existing server DamageService and feedback. The effect follows the victim after impact—even after leaving a field/aura. Reapplying from the same caster and equipped slot refreshes duration/strength, without stacking another copy or postponing its next tick. Different slots/casters can stack. Death/removal of either caster or victim clears effects. When the source authors `OnTargetDeath`, active periodic, timed status, and maintained Control effects keep that lifecycle event eligible after their projectile or area source ends; a death caused directly by that same spell remains classified once as `KilledByThisSpell`. Periodic-effect caps are centralized in `MagicLab.luau`. There is no stun.

**ModifyAttribute** currently supports only `MagicArmor`, through a server allowlist. Its additive value is bounded to ±100 and lasts for its authored duration. Positive armor reduces magic damage after resistance; negative armor lowers base armor but never makes final armor negative. Concurrent spell sources aggregate up to the global cap and do not overwrite the target's authored `MagicArmor`. Magic Lab shows this setting with other effect payloads, and successful changes appear as temporary `MagicArmor` feedback above the target. Wisp support spells can select allies who need a positive armor modifier; negative modifiers are treated as hostile effects.

Limits: 32 active DoTs/caster, 256 globally; interval .1–5 seconds, duration up to 15 seconds, per-tick damage up to 100 and authored total base damage up to 500/application. At capacity new effects are ignored while existing effects may refresh. Estimates account for authored tick count. `MagicTickClock.luau` retains schedule phase under normal frame jitter and skips missed ticks rather than producing catch-up bursts; a final delayed tick has at most one interval of grace. Tests cover timing, expiration, validation, costs and element choices.

Beam uses a camera-facing ribbon at least 1.4 studs visually wide, plus expanding/fading start and impact pulses. These are presentation-only, non-colliding and non-queryable. Instant Beam resolves once; Channeled Beam performs repeated server sweeps using Beam.Width, with physical obstruction checked independently on every pulse. Wider visuals do not damage extra targets or bypass walls.

For a channel test, choose Beam → Channeled, set a short duration and a visible Mana upkeep value, put Damage on **OnTick**, and equip it to slot 1. Hold **1** at a dummy to see repeated server damage; release to stop immediately. Hold it at a wall with a dummy behind the wall to confirm the beam terminates at the obstruction. Hold until mana is depleted, then hold for the configured duration, and verify each automatically ends. Repeat with a second client observing the beam and damage numbers. Direction locks at cast start in this first version.

Test: P → LightningLance → choose Lightning → equip slot 1 → cast across the street and vertically. Verify the flash and impact are readable with the character on screen and that a wall stops damage. Equip Fireball with direct Damage plus DamageOverTime (5/tick, four seconds, one-second interval) in slot 2; hit once and watch later damage without recasting. Repeated hits should refresh, not multiply the same slot's effect. Reset either participant during the effect, and test with two clients. These live Studio checks remain pending; offline checks do not verify rendered visibility or replication.

### Reusable spell presentation kit

New files:
- `src/shared/Configuration/MagicPresentation.luau`: Form-to-pose defaults, pose duration/culling and bounded particle settings.
- `src/client/Controllers/MagicPresentationController.luau`: R6/R15 shoulder overlays for server-approved casts. PreAnimation removes the previous overlay; PreSimulation blends the current one over Animator output. No leg/root poses, movement locks, or uploaded animation assets.

Updated MagicPresentation provides hand gathering particles, projectile core/trail and impact particles, layered moving Beam ribbons plus core/endpoint flares, eight-node area boundary particles, and construct formation/dissolve. Built-in Roblox particle texture only; no external asset dependency. Existing server-generated Parts still define gameplay, with cosmetic emitters/attachments added separately. Construct collision disappears immediately on expiry; its dissolving copy is non-colliding/non-queryable. Other expired visuals stop emission and finish their particle/trail fade.

Server runtime emits presentation cues only on accepted execution or charge. ActionRouter publishes a server-to-client presentation remote; MagicController starts the observer controller. No client-to-server animation/VFX remote exists. One active pose per character, at most 32 observed casts and a 180-stud initial distance filter. Poses end on death/removal or their bounded timer; visual particles and transient models use Debris. Charged gestures are capped at three seconds; release overrides the gathering pose. Instant spells retain instantaneous mechanics and play a short release flourish rather than acquiring a new gameplay windup. Cancelling charge can leave a brief cosmetic pose until its timer ends.

Projectile and Beam casts use the server-known right hand when unobstructed and reasonably close to the root; a root-to-hand sweep prevents moving the origin through a wall. Equipment-provided origins stay intact. Aim convergence remains direction-validated. There is no damage prediction, wall bypass, or widened hitbox from the presentation effects. Cosmetic projectile bodies retain their full mechanical radius because the initial overlap test uses that radius.

P → **Casting presentation** allows Auto, ProjectileCast, BeamCast, GroundCast, SelfCast, OverheadCast, WardCast, and SweepCast. Auto follows the Form; each named profile provides a shared gather/release pose and server timing. Profile choice changes neither damage nor cost, and invalid profiles are rejected. Forms, payloads, equipment, slots and progression are otherwise unchanged.

Projectile Presentation also includes **Surface impact behavior**. `Pulse` briefly expands a flat cosmetic disc along a struck world surface; `None` disables it. Character hits do not leave a surface mark. The pulse is non-collidable, non-queryable, capped by the shared cosmetic burst budget, and never persists or changes damage, hit detection, or terrain.

Studio acceptance:
1. Equip Projectile, Beam, Field/Aura, Construct and SelfEnhancement across slots. Check their distinct arm gestures while stationary, sprinting and turning. Melee and dash should remain usable.
2. Check R6 and R15 avatars. Observe from the second client: both should show accepted casts; no shoulders should remain stuck after expiry, death or respawn.
3. Inspect hands at cast time, projectile trails/impacts, the Beam core/ribbon, moving Aura boundary and stationary Field. Verify constructs collide during formation, lose collision immediately at expiry, then visually dissolve.
4. Stand near a wall: moving a hand across it must not allow shots through it. Check raised/lowered aim and equipment casts.
5. Cast repeatedly with both clients, then stop. Check for lingering Parts, attachments, emitters, poses or Output errors. No live rendering/physics claims are made by offline checks.

Offline: presentation allowlist/cost-invariance, magic schema/timing, slots, geometry and V1/V2 spell checks passed; formatting, references, Rojo builds and whitespace checks run. Live Studio pose, rendering and multiplayer verification remain pending.

### Visible body-pose correction

The first casting overlay only affected shoulders. It is replaced by saved/restored Motor6D C0 offsets applied in parent-body axes, leaving Animator.Transform available for locomotion. R6 uses RootJoint for torso lean; R15 uses Waist plus elbows. Shoulder, torso and neck movement distinguish release, beam, ground and self casts. Release presentation lasts .65 seconds, with eased entry/return. Recasting restores the old baseline before applying another pose; death, removal and expiry restore all saved offsets. The HumanoidRootPart is never repositioned and no movement lock is added.

Verify a side view in Studio: projectile torso twist/right-arm release, two-arm Beam extension, ground-cast forward lean, and self-cast gathered arms. Test sprinting during casts, rapid recasting and death/respawn for stuck joints. This changes the rendering approach but remains unverified in live Studio here.

### Upgraded avatar joint compatibility fix

The previous Motor6D-only detection excluded modern R15 AnimationConstraints. `MagicRig.luau` now recognizes both classes and identifies body roles by connected body parts instead of joint names. It reads the joint reference frame without modifying rig attachments. The controller now applies Transform overlays during PreSimulation, after Animator evaluation, and removes its own previous overlay before the next animation evaluation. The prior C0/render-step approach has been removed.

Release gesture duration is now 1.1 seconds with a sustained central hold. `MagicPoseJointCount` and `MagicPoseProfile` are local character attributes for diagnostics; an unsupported rig produces one Output warning instead of silently doing nothing. Tests use mock legacy/upgraded joints, missing attachments, root exclusions and gesture timing. They do not execute the Roblox engine.

This follows Roblox's documented AnimationConstraint migration guidance:
https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint

Stop Play, reopen the freshly rebuilt place, and cast once without rapidly recasting. Look for a sustained arm extension/torso lean. If absent, inspect the character attributes from the client Explorer: zero joint count means recognition failed; a nonzero count means evaluation/rendering needs further investigation. Real Studio verification remains pending.

### Gesture and release synchronization pass

Configuration/MagicPresentation.luau now owns per-profile server timing (Gather → Release → Recovery). Defaults: Projectile .16/.12/.20s, Beam .28/.18/.24s, Ground .20/.12/.22s, Self .14/.10/.20s. Profiles map by Form, with Auto and profile override still available. These are tuning defaults; changing the table changes all spells assigned to that profile without touching spell data.

All instant casts first validate on the server, then reserve the caster's single pending-cast slot. The clients receive the gather cue; movement, sprint and dash remain active. At the server's ReleaseAt time, it sends the release pose/spark cue. The authoritative Form executor, damage, construct placement or enhancement activates after that profile's Release delay. Cooldown begins at activation. Death/respawn or replacing a pending Lab slot cancels and restores the cue. Unsupported/invalid casts never start a gesture. Existing held charge begins in a gathering pose; a valid release enters the same server-timed release sequence. Early release cancels the pose.

The client hand transform isn't authoritative on the server. For ordinary player Projectile/Beam casts the client sends its current raised-hand point; the server accepts it only within 3.5 studs of the root and after a root-to-hand obstruction ray. Invalid points use a server fallback. The subsequent projectile sweep/Beam ray remains server-authoritative and can still hit a wall immediately beyond the hand. Equipment muzzle origins continue to use the server's equipped weapon data.

Studio procedure: stop Play and open the rebuilt combat sandbox. Equip a projectile, Beam, Field, Construct and SelfEnhancement in slots. In a side view and then from a second client, press each slot once: see the gather, then observe spell/VFX release at the end of that gesture, followed by brief recovery. Check Beam begins at the raised hands, ground effects begin at the downward release, and self enhancement begins on its upward release. Move/sprint/dash while gathering; there should be no movement lock. Press another slot during gather and confirm it is rejected without starting another pose. Test respawn during gather and charged Stone Shot hold/release. Fire at a wall close to the hand: no projectile or damage may appear through it. Check Studio Output and per-character MagicPoseProfile attributes if cue appears but pose does not.

StyLua check, both Rojo builds and git diff --check passed. This environment did not run Studio or automated test suites for this pass, so animation-to-hit alignment, multiplayer cue ordering and wall clearance still need live verification.

### Composable projectile behavior pass

Projectile definitions can combine up to three element-agnostic behavior entries in `Projectile.Behaviors`. `ProjectileBehaviorSpec.luau` owns authoring defaults, field controls, bounds and validation metadata; `MagicProjectileBehaviorExecutors.luau` owns runtime dispatch. The registry implements Homing (`SearchRadius`, `TurnRate`), Pierce (`MaxPierces`, the number of additional humanoid targets), Chain (`Radius`, `MaxJumps`, `DamageFalloff`), Bounce (`MaxBounces`, `Restitution`), Split (`ChildCount`, `SpreadAngle`, `DamageFalloff`), and Spread (`SidePairs`, `SpreadAngle`, `DamageFalloff`). Existing OnImpact triggers and payloads still define what each direct, chained, split-child or spread projectile hit does; Explosion remains an impact trigger behavior. Chain, Split and Spread therefore work with any projectile element and payload combination instead of being dedicated Lightning mechanics. Homing queries only when acquiring/reacquiring a target, while collision, target selection, line of sight, bounce contacts and damage remain server-owned. Additional projectiles count against the ordinary active-effect limits; split children cannot recursively split.

The Studio-only P editor exposes toggles and bounded numeric controls for all six projectile behaviors. Behavior combinations are held in the current draft and validated again by the server. Spell estimates account for behavior complexity. These controls do not modify registered source definitions.

Playtest using P: toggle Proximity, Absorb, Reflect, Pulse, Homing, Pierce, Chain, Bounce, Split, Spread, or Linger on projectile drafts; give Proximity a payload on On target approaches, and Pulse/Linger a payload on On each pulse. Use dummies to verify proximity triggers once per target within its configured radius and target cap, traveling pulses sample around the moving projectile at their interval and radius, plus homing, piercing, chain jumps stopping at walls/range, split fans, symmetric spread, Bounce, and a stationary Linger hazard that expires on time. For interception, use two clients and mark the incoming caster hostile; verify Absorb consumes only the hostile projectile and raises damage within its configured cap, while Reflect redirects it toward its original caster and attributes resulting damage to the reflector. Verify reflection hop limits prevent ping-pong. Also add an OnThreshold damage trigger at 50%; its payload should run only on the hit that takes a target from over half health to half or lower, then test a hit that crosses multiple configured thresholds. Linger cannot be combined with Bounce, Pierce, or Split because those impact outcomes conflict. Repeat with different Elements. Runtime targeting, obstruction, replication, and performance need Studio verification.

### Contextual Magic Lab editor

The Lab is organized into Setup, Targeting, Effects, Presentation, and Test pages. Setup chooses the source/Form and casting details; Targeting shows only modes, mechanics, and rules supported by the selected Form; Effects groups only compatible payloads by purpose (including Healing and Shield where supported) and exposes the selected payload's own settings; Presentation is explicitly visual-only; Test equips the draft to one of the numbered slots. The Effects page disappears for Forms without target effects.

`MagicSchema.luau` is the shared source for these labels, descriptions, field bounds/defaults, compatibility, and visibility. The same definitions inform `SpellSpec` server validation, while authoritative behavior still comes from server executors. To add a future editor capability, define its authoring metadata and compatibility there, then implement and validate its server execution separately; the UI does not grant a gameplay effect by itself. Summon payloads are backed by the server-owned `SummonService` and bounded `MagicSummons` configuration.

Advanced cast conditions can now be edited as recursive `ALL`, `ANY`, and `NOT` trees rather than only as a flat rule list. Each group supports adding/removing safe property rules and nested groups; individual rules or groups can be inverted. The editor disables operations that would exceed the server's maximum depth, total node count, or child count. Existing simple checkbox rules remain available, and legacy or saved nested conditions remain editable. Run `lua tests/test_magic_condition_tree.lua` for the pure tree editing and limit checks; use Studio to inspect the recursive editor layout and verify saved nested rules still load and validate.

Healing and Shield are derived from Forms marked as humanoid-targeting, rather than being attached to Projectile. They are available on Projectile impact, Beam/Wave cast, Field/Aura cast/spawn/tick/expiry, Self Enhancement cast/proximity, and Construct proximity. A Construct can therefore be authored as an open-air healing patch or protective zone; it does not need a floor or other surface. Wave, Field, and Aura drafts can opt to include the caster; this is off by default because damaging/control payloads on the same area would affect the caster too. Material Manipulation remains object/material focused and does not expose humanoid payloads.

The Setup page also exposes optional minimum Locus Capacity, Efficiency, Potency, Strain tolerance, and Complexity capacity. Zero leaves a metric unrestricted. The server checks these owner metrics on every cast, including a companion spell cast on the owner's Locus.

Target conditions can filter against exact tags on server-authored models. Set the model's `MagicConditionTags` attribute to a comma-, semicolon-, or space-separated list (for example, `armored, cultist`), then use Target → Tags → Has/DoesNotHave in the generic condition editor. Tags are normalized and bounded; this does not query arbitrary model attributes.

When Material Appearance is **Auto**, the preview and server visual select a material from the spell's Principle and Expression. Choose a specific material to override that default. Construct Auto remains Slate for compatibility with the existing solid-geometry look.

Damage and Damage over time Effects expose optional per-region multipliers for head, torso, arms, legs, and other rig parts. Direct Projectile and Beam hits use the server-reported contact part. Wave, area, and other effects without a direct contact part use torso scaling. The defaults are 1x for every region, preserving existing spell behavior; values range from 0x to 4x. These values scale damage before existing armor/resistance and shield handling and do not disable or injure body parts.

Fields and Auras can add optional cosmetic **Environmental layer** (`Motes` or `GroundMist`) and **Camera distortion** (0–1). The particle layer attaches to the replicated area marker, uses the spell's secondary color and shared particle budget, and ends with the area. Distortion is computed locally from nearby server-tagged area markers and applies a subtle blur/color shift to only that client's camera; it fades over 24 studs outside the area. Both default off and do not alter hit geometry, damage, line of sight, or world materials. The current Roblox implementation is a bounded screen-space approximation, not a refraction shader. In Studio, compare both layers on a short-lived Field and moving Aura, then verify they clear when each effect expires or is toggled off; test two clients and confirm only the nearby client's camera changes.

Held casts now transition from their gather gesture into a sustained procedural pose for as long as the server owns the channel. Releasing, toggling off, interruption, death, or effect expiry sends a cleanup cue so the character returns to its normal animation. To check this, hold a Channeled or Sustained spell for longer than the 3.5-second gather-pose cap, then release it and verify the pose remains stable while active and restores immediately afterward. This uses the existing pose profiles and does not add spell-specific animation assets.

Construct `OnExpire` now also runs when the caster dies, resets, or leaves while an ordinary or sustained Construct is active. Any attached target is passed to that event only while it is still alive; cleanup dispatches before the visual model is removed. A Studio check should cover reset/death with an active Construct that has an `OnExpire` Heal or feedback payload.

## Destruction-bound area lifetimes (2026-10-08)

Field and Aura can use `UntilDestroyed`, matching the existing Construct lifetime. Destroying the server-owned visible marker terminates the effect through ordinary `OnExpire` and `OnExit` cleanup, including channel release and active membership removal. Use this when another server-authorized interaction can remove an area early. It does not make the marker client-authoritative.

### Expression availability in the testbed

Every registered Expression, including Water, Lightning, Force, and Unawakened, is available for new and existing test spells. Casts do not advance discovery counters. The server still validates that each Expression belongs to its selected Principle. Existing Discovery records remain readable so a selected Focus profile can persist; historical cast counts no longer unlock or restrict anything.

Studio check: open P on a fresh or returning test account and confirm all expressions can be selected immediately, saved, equipped, and cast when their ordinary authored requirements are met.

### Magic Focus profiles

The **K** panel selects a server-owned Magic Focus profile. Recruit, Fire, Earth, and Body Enhancement are all available immediately. Each selection maps Primary and Area actions onto existing registered spell definitions; the cast route still requires the owned Magic Focus to be active and the Magic Runtime performs ordinary cast validation. The selected profile is saved as a test preference. A profile chosen while Discovery is still loading is queued and applied when its saved data finishes loading.

Studio check: press K, select each profile immediately, equip the Magic Focus with E, and verify its left-click and right-click registered spells. Rejoin a published private test experience with Studio API access enabled to confirm the selected profile persists and can be switched again.

The bounded discovery and requirement evaluators remain available as dormant development tools, but the current configuration does not consult them to gate a test option.

Time Dilation lifecycle check: apply a TimeDilation payload from one client to a target, then reset or kill its caster before the authored duration ends. The target should immediately return to its ordinary movement/time rate, while unrelated effects from other casters remain active. Repeat with a viewer-scoped effect and disconnect the viewer; it should clean up through the same status expiry path.

Maintained Control also exposes `SpellState.ControlledMass`: the live total assembly mass currently controlled by this caster's spell. It can be tested in cast, target, and lifetime conditions using the ordinary numeric comparisons. It becomes zero after the spell has no controlled targets.

`SpellState.TargetsHit` counts valid Humanoid targets selected by payloads that declare `TracksHumanoidTargets` in the server executor metadata. This includes support, movement, displacement, and self-enhancement payloads; targeted world-object interactions do not count as Humanoid hits.
