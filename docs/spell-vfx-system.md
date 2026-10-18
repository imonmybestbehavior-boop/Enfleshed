# Spell VFX Analyzer and Composer

The cosmetic package lives at `ReplicatedStorage.Shared.SpellVFXSystem`. It does not resolve targets, apply damage, change spell state, or participate in hit detection.

## Data flow and precedence

`GrimoireStarters` → validated `SpellSpec` → server `MagicPresentation` anchors → `SpellVFXAnalyzer.stamp` attributes and `ComposedSpellVFX` tag → client `SpellVFXController` → `SpellVFXComposer.attach`.

The editor's **PLAY PREVIEW** uses `SpellVFXAnalyzer.resolve` and `SpellVFXComposer.preview`, which calls that same `attach` renderer. Preview creates only local non-colliding objects; it never casts the spell. Projectile previews travel, beam previews show a bounded path, and area previews take their dimensions from `MagicGeometry.areaSize`. Static icons use the resolved element with the existing geometry/palette drawings.

Since the stat-driven pass, appearance is **generated from gameplay numbers** as well as names: see [stat-driven spell appearance](spell-visual-generation.md). `SpellVFXAnalyzer.resolve` adds a normalized feature vector (`FeatureVector`, one replicated string attribute) and a deterministic `Seed`; the composer turns them into a bounded render plan through `SpellVisualPlanBuilder` and `SpellVisualAssetLibrary`.

Precedence:

1. Gameplay Form and Geometry: authoritative boundaries and silhouettes.
2. Element: motif, volume and palette. A spell's own Element always wins.
3. Mechanic accents ranked by magnitude (max four), then detail particles.
4. Player `Palette`/colors tint the layers. Untouched Origin colors defer to elemental colors.

**Legacy compatibility:** saved `CoreShape`, `ParticleStyle`, `TrailStyle`, `MaterialAppearance`, `Opacity`, `Emission`, `ProjectileScale`, `ImpactStyle`, `CastingStyle`, `SurfaceBehavior`, `EnvironmentalVisual` and `VFXDefinition` remain valid and load unchanged, but are no longer applied to composition (they are listed in `plan.Legacy`). A saved `VFXDefinition` no longer replaces the spell's element; the allowlisted `SpellVFX` remote presets, which carry no spell element, still supply theirs. Incomplete data uses Neutral + Projectile; unknown element names use Neutral.

`resolve` is pure and does not cache by spell ID: every edit or creation is analyzed from current data. No renderer branches on a spell's name. Resolved settings are visible in the visual editor's preview title and hint.

## Grammar

| Form | Composition | Origin / lifecycle |
|---|---|---|
| Projectile | Elemental heart, orbiting shell, two broad persistent trails | Follows the authoritative projectile; no locally predicted hits |
| Beam | Bright axial core, broad aura, full-length elemental helix | Server-supplied start and endpoint |
| Wave | Expanding crest and ground boundary | Server wave frame and current radius, including repeated channel pulses |
| Field | Boundary plus multi-height elemental volume | Placed/followed gameplay area; updates as its dimensions change |
| Aura | Orbiting volume and boundary | Authoritative aura anchor |
| Construct | Elemental lattice around each built component | Actual component transforms and sizes, including growth |
| SelfEnhancement | Mantle and payload accents | Welded cosmetic anchor on character, removed at effect expiry |
| Manipulation | Stone/element lattice | Cosmetic anchor on manipulated object for the operation cue |

| Element | Silhouette / volume / movement |
|---|---|
| Fire | Hot wedges and core, native Fire shells/pillars, fire particles, broad trails |
| Ice | Large rotating crystalline wedges, frost mist, fracture accents |
| Lightning | Thin fork fragments, rapidly changing arc connections, charged motes |
| Water | Rounded droplets, curved flowing links, spray |
| Wind | Long thin fragments, broad curved ribbons, turbulent mist |
| Earth | Slate chunks, slowly rotating heavy debris, descending dust |
| Poison | Bubble forms, colored vapor, slow pulsing movement |
| Neutral | Palette-driven rune lattice, orbiting glyph fragments and arcane motes |

Geometry rules combine with these families: Cone samples widen along -Z; Box/Plane/Line use corners and faces; Ring samples both its inner and outer radii; round areas distribute layers in height and radius. Constructs attach per real component, preserving arch gaps. Behavior accents are additive and deduplicated: Split/Orbit → satellites; Chain/Cascade → forks; Bounce/Return → echoes; Pierce → lance; Homing/Reveal → seeker; Shield → ward; Heal/Restoration → ascent; Bind/Slow/Control/TimeDilation → bands; Summon/Enhancement → crown; Force/Displacement/AerialMovement → wings; damage → fracture; lingering/DoT → pulse; elemental marks → runes.

Gather contracts into a charging ring; release expands; sustain animates; impact expands into fragments; ending fades for 0.6 seconds. Cancellation destroys gather anchors. Session teardown disconnects heartbeat and destroys its owned folder. A removed anchor finishes at its last transform; it cannot leave an immortal emitter behind.

## Data-only example

```lua
local spell = {
    Form = "Beam", Element = "Ice", Geometry = "Line",
    Targeting = "AimDirection",
    Beam = { Width = 1.5, Range = 24 },
    Visual = { VFXDefinition = "None", CoreShape = "Crystal" },
}
local Shared = game:GetService("ReplicatedStorage").Shared
local Analyzer = require(Shared.SpellVFXSystem.Core.SpellVFXAnalyzer)
local Composer = require(Shared.SpellVFXSystem.Core.SpellVFXComposer)
print(Analyzer.resolve(spell).Label) -- Ice / Beam / Line · Crystal + Mist
Composer.preview(spell, CFrame.new(0, 8, 0))
```

This demonstrates cosmetic inference only. To cast a newly authored spell, create/validate a complete SpellSpec through the existing editor.

## Assets and budgets

The procedural composer itself uses only the built-in `fire_main.dds`, `smoke_main.dds` and `sparkles_main.dds` textures and procedural Parts/WedgeParts/Beams. Generated textures, flipbooks and meshes, plus the Fire and Body signature layers that use them, are documented in [spell VFX asset library](spell-vfx-assets.md). No asset IDs are invented; until assets are uploaded, those layers use built-in fallbacks.

Server particle budget reserves 32 emitters / 180 continuous particles per second; the client composer reserves 32 / 160, keeping the combined ceilings within the former 64 / 360. Burst budget is unchanged. The controller selects the nearest 28 runtime anchors every 0.25 seconds. Per-spell plans cap at 12 layers (4 accents), 40 parts (12 reserved for accents), 28 links, 3 trails, 4 emitters (24/s each, 48/s per spell), 8 native Fire and 1 light; globally 32 sessions, 96 Fire and 32 lights. Distance tiers: < 70 studs everything, < 120 no detail particles, < 180 silhouette + element only, beyond hidden. `Composer.Quality` (`High`/`Medium`/`Low`) scales counts and rates. Priority 1 boundary/silhouette layers are never dropped. These are configured limits, not a measured frame-time claim; live stress profiling is pending.

## Verification and limitations

See [all 65 recipes and repair notes](spell-vfx-coverage.md). All 65 now pass gameplay validation and server cost refresh. Regression tests enforce zero skipped recipes and preserve the repaired spells’ casting modes, reach, radii, movement bonuses, and lifetimes.

Run:

```bash
python3 scripts/run_luau_magic_tests.py /path/to/luau --vfx-only
python3 scripts/run_luau_magic_tests.py /path/to/luau --visual-plan-only
python3 scripts/run_luau_magic_tests.py /path/to/luau --composer-only
python3 -m unittest tests/test_spell_visual_no_identity_branches.py
rojo build default.project.json -o Enfleshed-Combat-Sandbox-VFX.rbxlx
ENFLESHED_PLACE_FILE=Enfleshed-Combat-Sandbox-VFX.rbxlx python3 tests/test_place_references.py
```

Open **Enfleshed-Combat-Sandbox-VFX.rbxlx**. In Studio Play, open the Grimoire with P, select a spell, then VISUALS → Automatic → PLAY PREVIEW. `scripts/studio_vfx_review.luau` is a client Command Bar review sequence for eight representative elements/forms at normal camera distance. Inspect actual casts too: projectile movement/impact, held beams, field boundaries, wave channels, construct growth, self-effect expiry, and cancellation. Watch Output for `[SpellVFX]` errors and verify cleanup after previews and respawn.

Live Studio visual review was unavailable in this session. No claim is made that all spells have passed the requested normal-distance artistic sign-off. The engine-independent tests and successful build cannot substitute for that review.
