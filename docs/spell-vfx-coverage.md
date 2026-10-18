# Curated VFX coverage and audit

All **65 curated recipes now pass the production gameplay validator**, including server cost refresh, and resolve a cosmetic composition. The 13 earlier recipe/schema mismatches were repaired without relaxing validator rules.

The seven one-shot waves retain Instant/Charged casting, use caster-origin `Self` targeting, and resolve at their authored range; their expansion remains cosmetic. The three spherical fields retain their radii and omit unsupported `Height`. The three movement enhancements retain their bonuses and spell lifetimes and omit redundant payload `Duration`. Damage amounts, cooldowns, and the validator are unchanged.

**Visual sign-off is pending.** No Studio connector or running Studio process was available in this session. These are code coverage results, not claims that every spell is visually finished at gameplay distance.

## Before the pass

All 65 recipes selected one of six generic optional presets. Those presets referenced absent named mesh/particle templates and fell back to primitive geometry. Runtime presentation was separate from the spell-book drawing. Non-fire fields reduced to very transparent volumes, thin rims and small sparse wisps; wave pulses were debug spheres/discs. Fire cylinders (especially Bell of Cinders) had a separate substantial flame implementation. Beam core/halo, projectile shards and construct highlights existed but did not compose consistently with behavior or preview.

## Coverage

| Spell | Form | Element | Geometry | Element layers | Behavior accents | Status |
|---|---|---|---|---|---|---|
| Aegis Beacon | Construct | Neutral | Arch | Rune + Arcane | Ward | Validated; live QA pending |
| Ashen Crossfire | Projectile | Fire | Sphere | Flame + Fire | Fracture,Pulse,Satellites | Validated; live QA pending |
| Astral Lariat | Beam | Neutral | Line | Rune + Arcane | Bands | Validated; live QA pending |
| Bastion Sentinel | Projectile | Neutral | Sphere | Rune + Arcane | Crown | Validated; live QA pending |
| Bell of Cinders | Field | Fire | Cylinder | Flame + Fire | Fracture,Pulse | Validated; live QA pending |
| Blackglass Mirror | Field | Neutral | Plane | Rune + Arcane | Seeker | Validated; live QA pending |
| Blue Hour | Wave | Water | Sphere | Ripple + Spray | Bands,Seeker | Validated; live QA pending |
| Bramble Snare | Field | Poison | Ring | Bubble + Vapor | Bands,Pulse | Validated; live QA pending |
| Cairnkeeper | Construct | Earth | Pillar | Stone + Dust | Bands,Fracture | Validated; live QA pending |
| Celestial Pin | Beam | Neutral | Line | Rune + Arcane | Bands | Validated; live QA pending |
| Cinder Comet | Projectile | Fire | Sphere | Flame + Fire | Fracture,Pulse | Validated; live QA pending |
| Cinder Verdict | Projectile | Fire | Sphere | Flame + Fire | Fracture,Rune,Wings | Validated; live QA pending |
| Cometfall Array | Field | Fire | Cylinder | Flame + Fire | Fracture,Wings | Validated; live QA pending |
| Crosswind Lane | Wave | Wind | Cone | Ribbon + Mist | Bands,Wings | Validated; live QA pending |
| Dawnward | SelfEnhancement | Neutral | Self | Rune + Arcane | Ward | Validated; live QA pending |
| Drowned Crown | Projectile | Water | Sphere | Ripple + Spray | Fracture,Rune | Validated; live QA pending |
| Echoing Brand | Wave | Neutral | Sphere | Rune + Arcane | Fracture,Seeker | Validated; live QA pending |
| Faultline | Wave | Earth | Cone | Stone + Dust | Fracture,Wings | Validated; live QA pending |
| Foxfire Carousel | Projectile | Fire | Sphere | Flame + Fire | Echo,Forks,Fracture,Pulse | Validated; live QA pending |
| Frostline Tripwire | Field | Ice | Plane | Crystal + Mist | Bands | Validated; live QA pending |
| Gale Mantle | SelfEnhancement | Wind | Self | Ribbon + Mist | Crown,Wings | Validated; live QA pending |
| Gale Reversal | Wave | Wind | Sphere | Ribbon + Mist | Bands,Wings | Validated; live QA pending |
| Glass Labyrinth | Field | Ice | Box | Crystal + Mist | Bands | Validated; live QA pending |
| Glasswing Seeker | Projectile | Ice | Sphere | Crystal + Mist | Bands,Fracture,Lance,Seeker | Validated; live QA pending |
| Gravemire | Field | Poison | Box | Bubble + Vapor | Bands,Pulse | Validated; live QA pending |
| Graven Track | Field | Poison | Line | Bubble + Vapor | Bands,Pulse | Validated; live QA pending |
| Gravitas Well | Field | Neutral | Sphere | Rune + Arcane | Bands | Validated; live QA pending |
| Hearthline | Wave | Neutral | Cone | Rune + Arcane | Rise | Validated; live QA pending |
| Hollow Beacon | Construct | Neutral | Pillar | Rune + Arcane | Seeker | Validated; live QA pending |
| Lantern of Mercy | Construct | Neutral | Pillar | Rune + Arcane | Rise,Ward | Validated; live QA pending |
| Lifeline Thread | Beam | Neutral | Line | Rune + Arcane | Rise | Validated; live QA pending |
| Mirror Step | SelfEnhancement | Neutral | Self | Rune + Arcane | Crown,Ward | Validated; live QA pending |
| Mirror Ward | Projectile | Neutral | Sphere | Rune + Arcane | Ward | Validated; live QA pending |
| Mistral Screen | Field | Wind | Plane | Ribbon + Mist | Seeker,Wings | Validated; live QA pending |
| Mothlight Decoy | Projectile | Neutral | Sphere | Rune + Arcane | Pulse,Seeker | Validated; live QA pending |
| Peregrine Wisp | Projectile | Neutral | Sphere | Rune + Arcane | Crown | Validated; live QA pending |
| Pollen Veil | Field | Poison | Sphere | Bubble + Vapor | Bands,Pulse | Validated; live QA pending |
| Prism Splitter | Projectile | Lightning | Sphere | Fork + Charge | Fracture,Satellites | Validated; live QA pending |
| Prismatic Bulwark | Construct | Neutral | Arch | Rune + Arcane | Rise,Ward | Validated; live QA pending |
| Quarry Hands | Manipulation | Earth | Point | Stone + Dust | Lattice | Validated; live QA pending |
| Razor Current | Projectile | Water | Sphere | Ripple + Spray | Bands,Echo,Fracture | Validated; live QA pending |
| Redshift Lunge | SelfEnhancement | Fire | Self | Flame + Fire | Crown | Validated; live QA pending |
| Ricochet Hex | Projectile | Lightning | Sphere | Fork + Charge | Echo,Forks,Fracture,Rune | Validated; live QA pending |
| Rime Reservoir | Projectile | Ice | Sphere | Crystal + Mist | Bands,Fracture,Pulse | Validated; live QA pending |
| Runeglass Wall | Field | Ice | Plane | Crystal + Mist | Bands | Validated; live QA pending |
| Sanguine Orbit | Aura | Neutral | Ring | Rune + Arcane | Rise | Validated; live QA pending |
| Seismic Crown | Wave | Earth | Sphere | Stone + Dust | Fracture,Wings | Validated; live QA pending |
| Siphon Spindle | Beam | Neutral | Line | Rune + Arcane | Bands,Fracture | Validated; live QA pending |
| Sirocco Spiral | Aura | Wind | Ring | Ribbon + Mist | Bands,Wings | Validated; live QA pending |
| Static Orchard | Field | Lightning | Sphere | Fork + Charge | Bands,Fracture | Validated; live QA pending |
| Stone Bastion | Construct | Earth | Box | Stone + Dust | Ward | Validated; live QA pending |
| Stonewake | Manipulation | Earth | Point | Stone + Dust | Lattice | Validated; live QA pending |
| Sundering Pulse | Wave | Earth | Sphere | Stone + Dust | Wings | Validated; live QA pending |
| Sunspike | Beam | Fire | Line | Flame + Fire | Fracture,Pulse | Validated; live QA pending |
| Tempest Lattice | Beam | Lightning | Line | Fork + Charge | Fracture,Wings | Validated; live QA pending |
| Thunderhead | Beam | Lightning | Line | Fork + Charge | Bands,Forks,Fracture | Validated; live QA pending |
| Tideglass Mine | Construct | Water | Sphere | Ripple + Spray | Bands,Fracture | Validated; live QA pending |
| Umbral Exchange | Projectile | Neutral | Sphere | Rune + Arcane | Bands,Echo,Fracture | Validated; live QA pending |
| Undertow Ring | Field | Water | Ring | Ripple + Spray | Bands | Validated; live QA pending |
| Verdant Sanctuary | Aura | Neutral | Capsule | Rune + Arcane | Rise,Ward | Validated; live QA pending |
| Verdict Mark | Projectile | Lightning | Sphere | Fork + Charge | Forks,Fracture,Rune,Wings | Validated; live QA pending |
| Wellspring Knot | Field | Water | Cylinder | Ripple + Spray | Rise,Ward | Validated; live QA pending |
| Winter's Gate | Field | Ice | Cylinder | Crystal + Mist | Bands,Fracture | Validated; live QA pending |
| Witchfire Fan | Field | Fire | Cone | Flame + Fire | Fracture,Pulse | Validated; live QA pending |
| Witchlight Pursuit | Projectile | Neutral | Sphere | Rune + Arcane | Fracture,Seeker | Validated; live QA pending |

## Automated checks

- Production resolver tests: all 65 recipes accepted after server cost refresh, regression assertions for the 13 repaired recipes, all 64 Element × Form combinations, additive behaviors, preset precedence, override removal, and data-only creation passed.
- Official Luau compiler: all 164 source scripts compile.
- Rojo build: `Enfleshed-Combat-Sandbox-VFX.rbxlx` built successfully.
- Built-place references and exact source serialization: 5 checks passed.
- Spell-identity architecture check and particle-budget test passed.
- The broader Magic Lab suite fails at its existing “Channeled Beams should support expiry triggers” payload assertion. The old starters-only suite calls the removed `Starters.build` API. These are not passing checks.
- Repository-wide StyLua check reports existing formatting differences outside this pass (including CombatController and the HUD section of MagicService). New VFX modules and edited UI/presentation modules pass targeted formatting; changed files pass whitespace checks.

Studio execution, Output inspection, frame-time profiling, and visual comparison remain **not performed**. Use the review sequence and actual casts before artistic acceptance.

## Stat-driven example plans

Produced by `tests/spell_visual_plan_spec.luau` from real curated SpellSpecs with only their payload or behavior numbers changed. Each passes the real validator. These are generated render plans (layer parameters), **not** reviewed Studio visuals.

| Example | Seed | Time scale | Budget used | Key layers |
|---|---|---|---|---|
| Weak fast-ticking fire DoT projectile | 3998778741 | 1.00 | parts=20 links=6 emitters=3 rate=24.9 fire=5 | `Projectile.Core(Count=1 Scale=0.39 PulseAmplitude=0.05 Brightness=0.6)`<br>`Fire.Flames(Count=6 Scale=1.11 PulseAmplitude=0.19 PulseFrequency=8.42)`<br>`Fire.HotCore(Count=1 Scale=0.18 Brightness=0.7)`<br>`Fire.Native(Count=5 Size=9.34)`<br>`Mechanic.Smolder(Count=6 Scale=0.35 PulseAmplitude=0.21 PulseFrequency=6.74 Opacity=0.62)`<br>`Fire.Embers(Rate=10.8 Lifetime=1.08 Size=1.04)`<br>`Fire.Smoke(Rate=3.6 Lifetime=1.73 Size=1.4 Opacity=0.55)` |
| Strong slow-ticking fire DoT projectile | 2714611962 | 1.00 | parts=22 links=6 emitters=3 rate=23.7 fire=6 | `Projectile.Core(Count=1 Scale=0.39 PulseAmplitude=0.05 Brightness=0.6)`<br>`Fire.Flames(Count=8 Scale=1.43 PulseAmplitude=0.45 PulseFrequency=3.01)`<br>`Fire.HotCore(Count=1 Scale=0.18 Brightness=0.7)`<br>`Fire.Native(Count=6 Size=11.58)`<br>`Mechanic.Smolder(Count=6 Scale=0.35 PulseAmplitude=0.45 PulseFrequency=2.29 Opacity=0.73)`<br>`Fire.Embers(Rate=13.2 Lifetime=1.74 Size=1.26)`<br>`Fire.Smoke(Rate=6.4 Lifetime=2.55 Size=1.4 Opacity=0.55)` |
| High direct-damage fire projectile | 1897936021 | 1.00 | parts=27 links=7 emitters=2 rate=17.9 fire=2 | `Projectile.Core(Count=1 Scale=0.57 PulseAmplitude=0.05 Brightness=0.98)`<br>`Fire.Flames(Count=4 Scale=0.61 PulseAmplitude=0.12 PulseFrequency=3.66)`<br>`Fire.HotCore(Count=1 Scale=0.39 Brightness=0.99)`<br>`Fire.Native(Count=2 Size=5.35)`<br>`Mechanic.Impact(Count=8 Scale=0.97 Length=0.74)`<br>`Mechanic.Smolder(Count=6 Scale=0.35 PulseAmplitude=0.15 PulseFrequency=2.82 Opacity=0.43)`<br>`Fire.Embers(Rate=7.3 Lifetime=0.91 Size=0.66)` |
| Low-damage long-duration poison field | 447469041 | 1.00 | parts=33 links=8 emitters=1 rate=11.2 fire=0 | `Field.Volume(Count=9 Scale=0.6)`<br>`Poison.Bubbles(Count=10 Scale=1.02 PulseAmplitude=0.19 PulseFrequency=2.16)`<br>`Mechanic.Smolder(Count=6 Scale=0.35 PulseAmplitude=0.19 PulseFrequency=2.82 Opacity=0.6)`<br>`Poison.Vapor(Rate=11.2 Lifetime=2.73 Size=1.6 Opacity=0.5)` |
| High-value shield aura | 1132499298 | 1.00 | parts=35 links=13 emitters=1 rate=5.5 fire=0 | `Aura.Orbit(Count=12 Scale=0.55)`<br>`Mechanic.Ward(Count=4 Thickness=0.15 Opacity=0.66)`<br>`Mechanic.Channel(Count=6 Scale=0.3 PulseAmplitude=0.25 PulseFrequency=1.4 Opacity=0.45)` |
| Fast chaining lightning beam | 1429938326 | 0.94 | parts=40 links=28 emitters=1 rate=15.5 fire=0 | `Beam.Core(Count=1 Scale=0.44 PulseAmplitude=0.05 Brightness=0.87)`<br>`Lightning.Forks(Count=8 Scale=0.5 PulseFrequency=16)`<br>`Mechanic.Channel(Count=6 Scale=0.3 PulseAmplitude=0.25 PulseFrequency=6.5 Opacity=0.45)`<br>`Mechanic.Forks(Count=6 Scale=0.3 Length=0.85)` |

Readings:

- **Weak fast-ticking vs strong slow-ticking fire DoT:** the strong DoT has larger, fuller flames (`Scale`, `Count`, native Fire `Size`) and stronger surges (`PulseAmplitude`). The weak one flickers faster (`PulseFrequency` 8.4 vs 3.0) because its interval is shorter. The longer burn gives longer-lived embers and smoke.
- **High direct-damage fire projectile:** the core and hot core are larger and brighter, and the impact accent has a bigger burst, while sustained flame volume stays small.
- **Low-damage long-duration poison field:** modest bubble volume, but long vapor lifetime and persistent density.
- **High-value shield aura:** four ward shells with maximum thickness and opacity.
- **Fast chaining lightning beam:** six fork accents (one per cascade strike) and high flicker frequency. The time scale is below 1 because the spell also slows.
