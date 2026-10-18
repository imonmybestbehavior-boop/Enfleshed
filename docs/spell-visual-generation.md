# Stat-driven spell appearance

Spell appearance is generated from a validated `SpellSpec`. Two mechanically different spells usually look different without anyone editing their visuals. The system is cosmetic only. It reads gameplay data and never writes it, and it has no effect on damage, targeting, collision, timing, status effects or hit geometry.

## Audit summary (what existed)

- `SpellVFXAnalyzer.resolve` mapped Element → motif/volume, Form → layout, and payload or behavior *names* → a comma-joined accent string. No numbers were read: a 3-damage DoT and a 25-damage DoT rendered identically.
- `SpellVFXComposer.attach` hard-coded node counts (10/18/24), emitter rate 5, trail lifetime 0.65, Fire size and pulse amplitude.
- `stamp` replicated the plan as instance attributes, so everything sent to the client must be scalar.
- Manual `Visual` fields (`CoreShape`, `ParticleStyle`, `TrailStyle`, `Opacity`, `Emission`, `ProjectileScale`, `VFXDefinition`) overrode inference. `VFXDefinition` could even change the rendered element.

## Pipeline

```
validated SpellSpec
 → SpellVisualFeatureExtractor.extract   (pure: normalized feature vector + bounded counts)
 → SpellVisualFingerprint.seed            (pure: stable 32-bit seed from canonical features)
 → SpellVFXAnalyzer.resolve / stamp      (server: base plan + one encoded `VFXFeatures` attribute + `VFXSeed`)
 → SpellVFXController → SpellVFXComposer.attach
 → SpellVisualPlanBuilder.build           (pure: features × SpellVisualAssetLibrary → bounded render plan)
 → Composer instantiates layers by priority and tiers them by distance
```

Modules live in `src/shared/SpellVFXSystem/Visual/`. Only the composer touches Roblox instances. The extractor, fingerprint, curves, library and plan builder are pure tables and functions, and they run under the plain Luau CLI in tests.

## Feature vector

All features are in `[0, 1]` unless noted, quantized to 1/1000 so the result is deterministic and the encoding is compact. Events are visited in sorted order. Totals across trigger steps are weighted: primary delivery events (`OnCast`, `OnImpact`, `OnEnter`, `OnSpawn`, `OnTick`, `OnProximity`) count 1, and secondary events (`OnExpire`, `OnExit`, `OnDamageDealt`, …) count 0.5.

| Feature | Source fields | Curve (reference) |
|---|---|---|
| `Direct` | `Damage.Amount` (+ `Explode` radius as a weak contribution) | log (120) |
| `DotTick` | strongest `DamageOverTime.Amount` per tick | log (25) |
| `DotRate` | `1 / DamageOverTime.Interval` of the strongest DoT | log (10/s, `MinInterval` = 0.1) |
| `DotDuration` | longest `DamageOverTime.Duration` | sqrt (15 = `MaxDuration`) |
| `DotTotal` | Σ Amount × ⌊Duration / Interval⌋ | log (250) |
| `Heal` | `Heal.Amount` + `Restoration` total | log (150) |
| `Shield` | `Shield.Amount` + positive `ModifyAttribute` MagicArmor | log (150 = `MaxShieldPerTarget`) |
| `Duration` | longest status duration (Slow, Bind, Shield, Reveal, TimeDilation, Control, Restoration, Enhancement) | sqrt (15) |
| `Slow` | 1 − `Slow.Multiplier` | smoothstep over 0..0.75 (`MinSlowMultiplier` = 0.25) |
| `Bind` | `Bind.Duration` | sqrt (4 = `MaxBindDuration`) |
| `Force` | max of `Force.Magnitude`, `Control.Acceleration`, `Control.MaxSpeed`/2, `Displacement.Distance`×4 | log (100 = `MaxForce`) |
| `Speed` | `Projectile.Speed` or `AerialMovement.Speed` | log (200 = `MaxSpeed`) |
| `Size` | `Projectile.Radius` (hit radius, **not** `ProjectileScale`) | sqrt (4) |
| `Range` | `Projectile.MaxDistance`, `Beam.Range`, `Wave.Range` | log (200 = `MaxRange`) |
| `Radius` | Field/Aura radius, outer radius or half width | sqrt (20 = `MaxRadius`) |
| `Width` | `Beam.Width` | sqrt (10) |
| `Homing` | `Homing.TurnRate` | sqrt (540) |
| `Linger` | `Linger.Duration` | sqrt (15) |
| `Construct` | ∛(Width × Height × Depth) | sqrt (20) |
| `Growth` | `GrowthDuration` (Wave, Field, Aura, Construct) | sqrt (15) |
| `Cast` | `CastTime` + `MaximumCharge` | sqrt (5) |
| `Lifetime` | `Lifetime.Duration` | sqrt (30) |
| `Payloads` | weighted payload count | saturation (8) |
| `Mark` | `ElementalMark.Stacks` | linear (5) |
| `TimeDilation` | abs(1 − `TimeDilation.Rate`) | linear (1) |
| `Reveal`, `Summon`, `Aerial` | duration, count, speed | sqrt / linear |
| `Repeat` | form pulse rate (`Interval`, `ChannelInterval`, Cascade `StrikeInterval`) when the spell repeats | log (10/s) |
| `Pierces`, `Bounces`, `Splits`, `Chains` | integer counts (`MaxPierces`, `MaxBounces`, `ChildCount`+2×`SidePairs`, `MaxJumps`/`StrikeCount`/`Propagate.MaxTargets`) | integers clamped to 0..8 |

Normalization is bounded and nonlinear: `log1p(x)/log1p(ref)`, `sqrt(x/ref)`, `smoothstep` and `1 − e^(−x/k)`, all clamped. A value 10× the reference saturates at 1. It cannot produce a 10× object or 10× particles.

## Asset grammar

`SpellVisualAssetLibrary` holds data only. Each **layer** declares `Kind` (Nodes, Emitter, Trail, Fire, Light), `Arrangement` (Core, Comet, Helix, Boundary, Volume, Orbit, Crest, Lattice, Mantle, Shell, Branches, Satellites, Ascent, Bands, Wings, Echo, Lance, Runes, Crown), `Priority`, `Params` defaults, `Limits`, and **drivers** `{ Param, Feature, Weight, Curve? }`. The builder evaluates `value = default + Σ weight × curve(feature)`, then clamps it to the layer limits.

- **Grounded fields:** field element bodies use the `Ground` arrangement. They are spread evenly across the authoritative footprint (golden-angle spiral for round areas, R2 grid for boxes, area-uniform for cones, between radii for rings), stand upright on the **visible ground**, sway instead of tumbling, and never rise above the top of the field. Gameplay areas are centered on the cast point, so half the hit volume is usually underground. The composer raycasts down from the anchor (excluding characters and its own layers, rechecking every 0.5 s for followed fields) to find the visible floor. Body count, native Fire and particle rates scale with area radius, and body height scales with the footprint, varied per node by the seed. Flames and bubbles surge in height with the DoT pulse. `Field.Volume` is a low translucent `Carpet` on the floor. Bubbles and ripples resurface at a scattered spot each cycle (two low-discrepancy unit values, not the ordered spiral, so they never drift outward). Tick, DoT and growth pulses add no objects on fields. They make the field itself throb: the outline line widens and brightens and the floor surface flashes faintly, at the pulse frequency with strength from the pulse amplitude. Boundary corner nodes are hidden on fields, so the outline line alone carries the boundary. Scattered ground bodies get no connecting beams; only the boundary ring and lightning arcs are linked. Field particles emit upward from a floor-sized Disc/Box emitter, and floating accents (fracture spikes, wings, seekers) become radial ground streaks.
- **Form layers** (silhouette and authoritative boundary): Projectile core and shell and trail, Beam core and helix, Wave front, Field boundary and volume, Aura boundary and orbit, Construct lattice, SelfEnhancement mantle, Manipulation lattice.
- **Element layers** (elemental language): Fire flame tongues, hot core, embers, smoke, native Fire. Ice crystals and frost mist. Lightning forks and charge motes. Water droplets and spray. Wind ribbons and wisps. Earth stones and dust. Poison bubbles and vapor. Neutral runes and arcane motes.
- **Mechanic layers** (accents): Impact (direct damage), Smolder (DoT), Ascent (heal), Ward (shield), Drag (slow), Shackle (bind), Wings (force/displacement/aerial), Seeker (homing/reveal), Lance (pierce), Forks (chain/cascade), Satellites (split/spread), Echo (bounce/return), Afterglow (linger), Runes (marks), Crown (summon/enhancement), Clock (time dilation), Growth (area growth), Channel (repeated/channeled).

There are no assets named after spells. A spell's look is the composition of its form layers, its element layers, and up to four mechanic layers ranked by feature magnitude.

### Fire / DoT channels (independent and capped)

| Feature | Fire layer channel |
|---|---|
| `DotTotal` | flame body scale, flame count, native Fire size (fuller flames) |
| `DotTick` | flame surge pulse amplitude (stronger individual surges) |
| `DotRate` | flicker / pulse frequency, spark rate |
| `DotDuration` | ember lifetime and rate, smoke layer, trail persistence |
| `Direct` | hot-core brightness and size, impact burst, light |

## Composition precedence

1. **Gameplay form and geometry** are always authoritative: the boundary and silhouette layers (priority 1).
2. **Element** supplies motif, volume and palette (priority 2).
3. **Mechanic accents**, ranked by magnitude, at most four (priority 3).
4. **Detail particles** (priority 4).
5. **Player palette** (non-Origin `Palette` or custom colors) tints the layers. It never adds or removes layers.

Layers are built in priority order. When a budget is exhausted, later (lower-value) layers are dropped first.

## Legacy compatibility rule

`SpellSpec` stays at v3 and `MagicVisualSpec.validate` is unchanged. Every saved spell still loads, validates and round-trips byte-for-byte. Generation is the default for every spell:

- `Palette`, `Color`, `SecondaryColor` and `AccentColor` are kept as the player's high-level cosmetic choice. As before, untouched Origin defaults defer to elemental colors.
- `CoreShape`, `ParticleStyle`, `TrailStyle`, `MaterialAppearance`, `Opacity`, `Emission`, `ProjectileScale`, `ImpactStyle`, `CastingStyle`, `SurfaceBehavior`, `EnvironmentalVisual` and `VFXDefinition` are **retained but not applied** to composition. `VFXDefinition` no longer changes the rendered element. The analyzer reports retained legacy choices in `plan.Legacy` so the editor can show them.
- The six allowlisted `SpellVFX` remote presets (`FireBurst`, …) still play. They pass their own `Element` and `Form`.

## Deterministic variation

`SpellVisualFingerprint.seed` hashes `Element|Form|Geometry|<encoded features>` with a 31-multiplier polynomial and a bit32 avalanche. Spell names, `SpellId` and `math.random` are never read. `Fingerprint.unit(seed, salt)` gives stable per-purpose values for phase offsets, angular offsets, trail curvature, crystal tilt, rune layout and motif variant. Mechanically identical spells share a seed. Different spells usually do not.

## Budgets and quality tiers

| Scope | Cap |
|---|---|
| Active client sessions | 32 |
| Layers per spell | 12 (≤ 4 mechanic accents) |
| Parts per spell | 40 (12 reserved for mechanic accents) |
| Beams (links) per spell / Trails per spell | 28 / 3 |
| Emitters per spell / rate per emitter / per spell | 4 / 24 / 48 per second |
| Native Fire per spell / global | 8 / 96 |
| Lights per spell | 1 |
| Global emitters / continuous rate (client reserve) | 32 / 160 per second |

Quality presets (`High`, `Medium`, `Low`) scale counts and rates and lower the priority ceiling. At runtime, distance tiers apply: under 70 studs all priorities are shown, under 120 priority ≤ 3, under 180 priority ≤ 2 (silhouette and element only), and beyond that the effect is hidden. Under global pressure, emitters and Fire are skipped while node layers survive. Priority 1 layers are always kept, so boundaries stay readable.

## Truthfulness

- Boundary layers sit exactly on the authoritative footprint (±0.49 of `VFXSize`). Area volume layers are clamped inside it. Feature-driven height and density change *within* the footprint, never its extent.
- The projectile core is ≤ 0.6× the hit diameter, and shells and satellites are ≤ 0.75×. Only fading trails and particles extend beyond. `ProjectileScale` is ignored, because it could imply a larger hitbox.
- Beam cores never exceed the authoritative width.
- Every layer has a minimum opacity and size floor, so low-damage utility spells stay visible. Brightness and particle caps keep high-damage spells from flooding the screen.

## Statistic → visual parameter table

| Statistic | Visual parameters |
|---|---|
| Direct damage | core scale and brightness, impact burst size, fracture count, light brightness |
| DoT total | flame/vapor body scale and count, native Fire size, volume density |
| DoT per tick | pulse amplitude (surges) |
| DoT tick rate | pulse/flicker frequency, spark rate |
| DoT duration | ember/smoke lifetime and rate, trail lifetime, afterglow |
| Heal | ascent density, brightness, upward speed |
| Shield | ward layer count, thickness, opacity |
| Effect duration | mantle layers, persistence |
| Slow / time dilation | drag band count, global animation rate (down to 0.5×) |
| Bind | shackle band count and tightness |
| Force / displacement | wing/ribbon length and count, directional speed |
| Projectile speed | trail length, streamlining (core elongation), motion rate |
| Projectile radius | core and shell scale (bounded to the hit size) |
| Range | helix node count, trail length |
| Area radius / beam width | spatial footprint (authoritative); detail density |
| Homing | seeker count, forward lead |
| Pierce / Bounce / Split / Chain | lance length / echo count / satellites / fork branches (each ≤ 6) |
| Linger | afterglow lifetime |
| Construct size / growth | lattice node count / growth ring speed |
| Cast time / charge | gather intensity |
| Payload count | accent count |
| Marks | rune count |
| Repeat/channel rate | channel pulse frequency |

Example plans are produced by `tests/spell_visual_plan_spec.luau` and recorded in `docs/spell-vfx-coverage.md`.

## Verification boundary

Automated tests cover determinism, bounds, monotonicity, orthogonality, compatibility, purity and budget caps, all without rendering. The visual quality of these compositions has **not** been inspected in Roblox Studio in this session.
