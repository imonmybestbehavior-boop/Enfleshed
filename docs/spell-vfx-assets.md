# Spell VFX asset library and signature layers

Original, generated VFX assets (textures, flipbooks, meshes) and a modular signature system that plays them on top of the existing [spell VFX composer](spell-vfx-system.md). Cosmetic only. It never changes damage, hitboxes, timing or network authority.

**Current status (2026-10-17):** See the [overhaul audit and Milestone 1](spell-vfx-overhaul-milestone-1.md) for current inventory, artwork, checks and Studio evidence. The library contains 71 textures and 60 meshes with recorded IDs. A connected Studio preflight found failures for all seven sampled Fire texture IDs and successful creation of three sampled meshes. Finished-effect visual review is pending. The older inventory tables below describe an earlier subset and should not be read as current coverage or publication evidence.

## What exists

```
tools/vfx_pipeline/            generators (run headless in Blender 5.2; numpy from Blender's Python)
  build_all.sh                 regenerate everything (+ --lookdev for Cycles stills)
  gen_textures.py              19 grayscale+alpha PNGs incl. 5 flipbook atlases
  gen_meshes.py                14 meshes -> FBX + GLB, source .blend, preview render
  preview_textures.py          tinted contact sheet + flipbook strips on a dark backdrop
  lookdev.py                   Fireball / Body Burst composition stills (Blender, not Roblox)
  build_manifest.py            validates every file, writes the Luau manifest
assets/vfx/textures/           *.png + textures.json
assets/vfx/meshes/             *.fbx, *.glb + meshes.json
assets/vfx/source/             vfx_meshes.blend
assets/vfx/previews/           textures_sheet, flipbook_*, meshes_sheet, lookdev_* PNGs
assets/vfx/asset_ids.json      YOU fill this after uploading (never invented)
src/shared/SpellVFXSystem/
  Assets/VFXAssetManifest.luau GENERATED: name -> Id (nil until uploaded), fallback, flipbook, size
  Assets/VFXAssets.luau        resolver: custom asset or fallback, mesh templates, pooling
  Signature/SignatureLibrary   data: components, slots, quality, budgets, Fire + Body signatures
  Signature/SignaturePlanner   pure: spell features -> resolved layers
  Signature/SignatureRenderer  client: instantiates layers on server-stamped anchors
src/client/Controllers/SpellVFXShowcase.luau   Studio-only test arena (F8)
scripts/studio_vfx_asset_check.luau            Command Bar check of uploaded/imported assets
tests/test_spell_vfx_signatures.py             planner spec + client compile + manifest validation
```

All textures are **grayscale luminance + alpha**. Roblox multiplies particle, trail and beam textures by their `Color`, so one texture serves every palette and player tint. Flipbooks are square 1024 px atlases in row-major `Grid4x4`/`Grid8x8` order, which matches `ParticleEmitter.FlipbookLayout`. Noise is periodic, so looping flipbooks loop seamlessly and the strip textures tile along U.

### Textures

| Texture | Size | Flipbook | Fallback | Use |
|---|---|---|---|---|
| `beam_energy` | 512×128 | — | Sparkle | U-tiling filament energy for Beams/Trails |
| `core_plasma` | 1024² | Grid4x4 loop | Sparkle | turbulent swirling energy core |
| `debris_chip` | 128² | — | Sparkle | angular fragment silhouette with hot rim |
| `dust_burst` | 512² | — | Smoke | heavy grit cloud (body impacts) |
| `ember_streak` | 128² | — | Sparkle | elongated spark, use `VelocityParallel` |
| `explosion_fire` | 1024² | Grid8x8 one-shot | Fire | 64 frames: flash → lobed billowing fireball → cooling soot → gone |
| `flame_tongue` | 1024² | Grid4x4 loop | Fire | teardrop flame whose licks tear off at the tip |
| `flame_wisp` | 512² | — | Fire | single leaning flame lick |
| `force_streak` | 512×128 | — | Sparkle | U-tiling speed lines |
| `glow_soft` | 256² | — | Sparkle | soft bloom |
| `heat_haze` | 256² | — | Smoke | low-contrast shimmer for faked distortion (not yet used) |
| `impact_star` | 512² | — | Sparkle | irregular radial flash |
| `pressure_wave` | 1024² | Grid4x4 one-shot | Sparkle | directional pressure crescent travelling "up" the frame |
| `rune_circle` | 1024² | — | Sparkle | industrial geared sigil with angular glyph band (not yet used) |
| `shockwave_ring` | 512² | — | Sparkle | thin ragged ring |
| `sinew_trail` | 512×128 | — | Sparkle | U-tiling fibrous strands (not yet used) |
| `slash_arc` | 512² | — | Sparkle | crescent slash (not yet used) |
| `smoke_billow` | 1024² | Grid4x4 one-shot | Smoke | Worley-billowed, self-shadowed puff that thins out |
| `trail_flame` | 512×128 | — | Fire | U-tiling ragged flame streak |

### Meshes

Authored in Roblox space: Y up, travel direction −Z, about 1 stud = 1 unit. Both FBX and GLB exports land in Roblox orientation, and every mesh is UV-mapped.

| Mesh | Tris | Fallback | Use |
|---|---|---|---|
| `fire_core` | 1472 | Ball | lobed turbulent core |
| `flame_shell` | 840 | Ball | 7 swept flame tongues around a hollow core |
| `flame_tongue` | 224 | Wedge | single curling flame blade (not yet used) |
| `comet_spike` | 912 | Ball | finned projectile silhouette (not yet used) |
| `shockwave_ring` | 512 | Cylinder | ragged band ring, XZ plane, radius 1 |
| `shockwave_dome` | 760 | Ball | open blast hemisphere (not yet used) |
| `sigil_ring` | 2188 | Cylinder | geared casting sigil |
| `energy_ribbon` | 128 | Block | helical ribbon (not yet used) |
| `debris_rock_a/b/c` | 24–28 | Block | faceted fractured chunks |
| `pressure_cone` | 800 | Wedge | force cone, opens along −Z, torn crescent rim |
| `flesh_shard` | 360 | Wedge | mutated organic spindle |
| `sinew_tendril` | 448 | Cylinder | curling organic tube (not yet used) |

## Architecture

```
server MagicPresentation  --stamp-->  anchor attributes (+ new: VFXPrinciple, VFXImpactRadius)
client SpellVFXController -> SpellVFXComposer.attach(anchor, plan)
                              ├─ Composer.Signatures.attach(...)   (injected by the controller)
                              │    SignaturePlanner.plan(plan, phase, quality) -> layers
                              │    SignatureRenderer builds layers from VFXAssets
                              └─ composer drops the procedural layers the signature `Replaces`
```

* **Components** (`SignatureLibrary.Components`): Projectile, Beam, Wave, Field, Aura, Construct, SelfEnhancement, Manipulation, plus **Cast** (the caster cue) and **Impact** (the per-hit anchor). Each maps an anchor phase (Gather/Release/Sustain/Impact/End) to the slots it plays.
* **Slots / effect layers:** Core, Shell, Secondary, Trail, Ambient, Cast, Charge, Impact, Dissipate.
* **Layer kinds** (generic, data-driven): Sprite (locked flipbook billboard), Emitter, Burst, Mesh, Debris (ballistic pooled meshes, no physics), Trail, Light.
* **Signatures** are data tables chosen by `Element` or `Source.Principle` and never by spell name or id. **Fire** and **Body** exist. A new identity is a new table: pick assets, palette tokens, params and drivers per slot. Optional `Forms`/`Roles` allowlists scope a layer.
* **Precedence:** a signature lists which composer priorities it replaces per role (Form = 1, Element = 2, Detail = 4). Mechanic accents (homing seekers, chain forks and so on, priority 3) always remain. Spells without a signature render exactly as before.

### Spell variables → visuals

The planner reads only the analyzer's normalized features. Visual scale never feeds hit size.

| Scalar | Source | Fireball | Body Burst |
|---|---|---|---|
| Size | projectile hit radius / area radius | body scale = hit diameter / 2.2, tongue rate | — |
| Potency | direct damage, DoT total | core framerate + spin, core/shell wobble, ember rate, impact fireball count, impact embers | — |
| Speed | projectile speed | shell stretch, tongue speed | — |
| Charge | CastTime + MaximumCharge | converge rate, charge point growth, sigil spin; ramps over the real charge time | inward draw rate, pulse growth |
| Range | max distance / beam / wave range | trail lifetime | cone length, front speed = range / lifetime |
| Homing | turn rate | longer trails so curves read; host faces actual motion | — |
| Force | Force/Control/Displacement payloads | — | front size/count, streak count/speed, fragment count/speed, cone overshoot |
| Lifetime | Lifetime/Linger | smoke wake, wisps | — |
| Area | real Explode radius | flash, fireball, shockwave and ground-ring size, ember speed | — |

To make this work, the shared feature extractor now also reads payloads declared on the form itself (`Wave.Payloads`, `Beam.Payloads`, …). Before, a wave's Force and Damage never reached any visual. All existing visual-plan, composer, VFX-coverage and identity tests still pass.

### Fireball

* **Charge:** converging sparks feed a growing plasma ignition point at the hand while a geared sigil turns under the caster. It all scales with the real charge time.
* **Release:** a white-hot flash, a forward lick of flame and sparks.
* **Flight:** a swirling flipbook heart and a twisting Neon core body inside a swept flame shell. Flame tongues stream backward. A ragged flame trail plus a hot inner trail, shed embers, a thin smoke wake and a moving light. The host turns to face actual motion, so homing curves show in the trails and stretched shell.
* **Impact:** a 0.12 s flash and a radial star, a lobed 64-frame explosion, then a camera-facing shockwave ring separate from a ground ring mesh. Embers spray out and molten (CrackedLava) debris bounces off the floor. Rolling smoke and cinders give a clear end.

### Body Burst

* **Charge/Release:** grit drawn inward and a dull sinew pulse at the chest, then a recoil crescent and dust blown off the feet.
* **Wave:** a ForceField pressure cone stretched to the real wave range overshoots and settles. Three staggered pressure crescents (`VelocityPerpendicular`) race to the range edge. Speed lines and torn flesh/rock fragments with short streak trails fly in the push direction. A ring at the leading edge faces the push, and grit drags along the floor.
* Palette is bone, sinew, bruise and grit with low light emission, so it reads as physical rather than glowing. It shares no layers with Fire.

## Quality and performance

| Preset | Kept layers | Rate × | Count × | Lights | Decorative meshes |
|---|---|---|---|---|---|
| High | priority ≤ 3 | 1 | 1 | yes | yes |
| Medium | ≤ 2 | 0.65 | 0.7 | yes | yes |
| Low | 1 only | 0.4 | 0.45 | no | no (priority-1 meshes kept) |

Priority-1 layers (Fire core heart, flame tongues, wake trail, impact flash/fireball/shockwave, Body cone and fronts) survive every preset and distance tier up to 120 studs. Beyond 180 studs nothing is drawn. The preset comes from the `SpellVFXQuality` player attribute. Otherwise it is auto-picked: graphics level ≤ 3 → Low, ≤ 6 or touch device → Medium, else High. It applies to both the composer and the signatures.

Global caps (`SignatureLibrary.Budget`): 24 sessions, 72 emitters, 420 continuous particles/s, 60/s per emitter, 900 burst particles/s, 48 per burst, 72 meshes, 10 lights, 24 trails. Under pressure, non-critical layers are skipped. One Heartbeat connection drives all sessions. Meshes are pooled per asset (24 each). Debris is scripted (anchored, no collisions or physics) and stops on a single floor raycast. Every session has a bounded end: one-shots stop after their layers, sustained sessions dissipate for at most 3 s after the anchor ends or disappears. These are configured limits; no frame-time profiling has been done.

## Import into Roblox

Requires Studio (asset upload cannot be done from this environment).

1. **Textures.** Studio → *Asset Manager* → *Bulk Import*, select all `assets/vfx/textures/*.png`. Copy each image's asset id. Use the **Image** id, not a Decal id; if you get decals, insert one and read its `Texture` property for the image id.
2. **Meshes.** Pick either:
   * **(recommended)** *File → Import 3D* each `assets/vfx/meshes/*.fbx`. Name the resulting MeshPart exactly as the file (e.g. `fire_core`) and put it under `ReplicatedStorage › VFXAssets › Meshes` (create both Folders). Rojo leaves these Studio-only children alone. Save the place.
   * or upload the meshes and put their mesh ids into `asset_ids.json` as `"mesh:<name>": <id>` (plain names are image ids); the client then builds them with `AssetService:CreateMeshPartAsync`.
3. Fill `assets/vfx/asset_ids.json`, e.g. `{ "flame_tongue": 1234567890, "fire_core": 2345678901 }`, then run:
   ```bash
   python3 tools/vfx_pipeline/build_manifest.py
   ```
   Rojo sync picks up the regenerated `VFXAssetManifest.luau`. The script rejects unknown names and non-numeric ids.
4. In Play mode, paste `scripts/studio_vfx_asset_check.luau` into the Command Bar. It lists what is still on fallback and any asset that failed to load.

## Showcase / test arena (Studio)

Play the sandbox in Studio and press **F8**. The panel has these controls:
* **Spell:** Fireball or Body Burst.
* **Playback:** PLAY, or a single phase (Charge, Release, Impact); ×1/×5 simultaneous casts, Repeat, Slow-mo.
* **Look:** Dark room (enclosed backdrop with a fixed camera; toggle off to play in the real map in front of you), Assets (custom/fallback A/B), quality Low/Medium/High/Auto.
* **Variables:** radius, damage, speed, charge time, explode radius, homing turn rate, Body force and range. These change the spell fields, so the real analyzer re-derives features.

Live budget usage is shown in the panel. The showcase stamps local anchors exactly like `MagicPresentation`, so the real controller, composer and renderer draw them. Nothing reaches the server.

## Verification done here

* `python3 tests/test_spell_vfx_signatures.py`: signature selection by data, phase → component mapping, every variable → visual mapping above (and that size, potency and force stay independent), Low keeps all critical layers, every referenced asset and palette token exists, worst-case driven rates stay within caps, manifest validation, and Luau compilation of the client-only modules.
* Existing suites still green: the full magic suite and its `--vfx-only`, `--visual-plan-only`, `--composer-only`, `--starters-only`, `--library-only` and `--workflow-only` modes, the emergent-magic audit, `test_magic_registry_parity.py`, `test_spell_visual_no_identity_branches.py`, and `rojo build`.
* Asset files: PNG signature/size/RGBA/flipbook grid checks, FBX/GLB magic bytes, triangle limits. GLBs were re-imported into Blender for the lookdev renders.

## Not verified / needs a Studio pass

* No rendering in Roblox has been observed. Tuning (sizes, opacities, light emission, flipbook framerates) is from first principles and the Blender lookdev only.
* Behaviours to confirm visually:
  * the `Cylinder` emitter shape axis used for the "Flat" dust kick-up;
  * the in-plane rotation of `VelocityPerpendicular` pressure crescents;
  * ForceField material on the pressure cone and front ring without a TextureID;
  * fallback primitives, which are dimmed to 35 % because open shapes read as solid blobs (the sigil, fire core and flame-shell meshes are skipped entirely without the real mesh).
* Real Fireball impact anchors carry no direction, so impact embers burst radially and the ground ring needs a floor within 9 studs.
* Distortion is only approximated; Roblox has no refraction (`heat_haze` is provided but unused).
