# PvP Stat Caps

Rules: `src/shared/Modules/SpellStatCaps.luau` · profiles: `src/shared/Configuration/SpellStatCaps.luau` · who may fight: `src/shared/Modules/CombatPolicy.luau`.

## Which profile applies
Decided per hit, per target:
| Situation | Profile |
|---|---|
| Target is an NPC, enemy, dummy or object | `PvE` (no caps) |
| Target is a teammate the caster cannot fight (normal co-op) | `PvE` (heals/shields uncapped) |
| Both players in an `Open` PvP zone, or in a mutual duel | `PvPOpen` |
| Both players in a `Ranked` zone | `PvPRanked` |

Zones are the server-owned Player attribute `PvPZone` (`"Open"` / `"Ranked"`); players in different zone kinds cannot hurt each other.

## Where caps are applied
- **Every damage hit** (spells, DoT ticks, melee, summons) in `DamageService.apply`, after armor/block and before shields: `× DamageMultiplier`, then `≤ MaxDamagePerHit`.
- **Every spell payload** in `MagicPayloadExecutors.execute`: targets are grouped by profile and each group gets a capped copy of the payload (durations, slow strength, bind, control, displacement, force, time dilation, size, stat changes, heal, shield, DoT). Caps are on the *final* value after potency, so potency boosts (absorb, ranks) cannot exceed them. Saved spells are never modified.

- **Mark-triggered effects**: an elemental mark's starter effects (for example Burning's DoT and Slow) and every elemental reaction effect (Conduct, Firestorm, Freeze, Shatter, Toxic smoke, Mire) go through the same `Payloads.execute` path (`applySecondary` in `MagicPayloadExecutors`). They get the hostility filter and the target's profile caps like any authored payload, and are credited to the caster of the incoming mark. Freeze's Stun also gets Stun's diminishing returns and the 0.5 s PvP cap. Reaction Fields (Firestorm, Toxic smoke) are ordinary spawned effects, so their ticks are capped the same way.

## Tuning
Values in `Configuration/SpellStatCaps.luau` are starting points. Tune from PvP playtests and the `SpellUsage` analytics event ([ANALYTICS.md](ANALYTICS.md)); disable a broken part entirely with the kill switches in [FEATURE_FLAGS.md](FEATURE_FLAGS.md).
