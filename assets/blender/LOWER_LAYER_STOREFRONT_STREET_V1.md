# Enfleshed — Lower Layer Storefront Street V1

This scene places the approved Storefront Kit V2 inside a compact Lower Layer street. It is an art and navigation review scene, not a Roblox-ready export.

## Open it

1. Open Blender 5.2.
2. Choose **File → Open**.
3. Open `assets/blender/generated/lower_layer_storefront_street_v1/lower_layer_storefront_street_v1.blend` inside `/home/deck/Projects/Enfleshed`.
4. Press **Numpad 0** to use the saved street-arrival camera. Without a numpad, use **View → Cameras → Active Camera**.
5. In the Outliner, select any camera named `CAM 01` through `CAM 07`. Use **View → Cameras → Set Active Object as Camera** to switch views.
6. Use the supplied PNG images for quick review. No rendering is required.

## What to review

- **CAM 01 — Street Arrival:** overall density, sightline and overhead construction.
- **CAM 02 — Shops Player Height:** whether the storefronts still read clearly when embedded in the city.
- **CAM 03 — Checkpoint:** the exposed obstruction on the obvious street route.
- **CAM 04 — Passage Entry:** whether Court 17 is noticeable without looking like a game-only secret door.
- **CAM 05 — Secret Courtyard:** the courtyard stair and first change in elevation.
- **CAM 06 — Catwalk Route:** the elevated connection toward the exit alley.
- **CAM 07 — Overhead Layout:** the relationship between the street, passage, courtyard and alley.
- **08 Route Diagram:** red marks the obvious street route; green marks the discovered route.

The intended discovered route is:

`street → Court 17 passage → rear courtyard → stair → catwalk → narrow alley stair → street beyond the checkpoint`

The direct street route remains open, but the inspection barrier slows and exposes the player. This establishes a gameplay reason to learn the passage route.

## Scene organization

- The six numbered collections are the preserved Storefront Kit V2 assets.
- `STREET ENVIRONMENT` contains the street, upper buildings, opposite wall, checkpoint, courtyard, stairs, catwalk, alley, cameras and lights.
- `REVIEW ROUTE OVERLAYS - hide for beauty` contains red and green route markers. It is hidden from normal renders. Enable it to inspect the route inside Blender.

## Regenerate it

The generator must be run against the Storefront V2 blend because it reuses those approved collections:

```bash
flatpak run org.blender.Blender --background \
  /home/deck/Projects/Enfleshed/assets/blender/generated/storefront_v2/storefront_kit_v2.blend \
  --python /home/deck/Projects/Enfleshed/assets/blender/scripts/lower_layer_storefront_street_v1.py \
  -- --render
```

Use `--output-dir /absolute/path` after `--` to save elsewhere. The generator reads Storefront V2 and writes a separate scene. It does not overwrite Storefront V1, Storefront V2, the Roblox place or any game scripts.

## Limits before Roblox

This scene uses separate editable pieces and procedural Blender materials. It has not been optimized, UV-baked, exported, given Roblox collision meshes or tested with the actual player controller. The stair dimensions, awning clearance, shop thresholds and narrow alley must be tested in Studio after an export copy is prepared. Route value must also be tested with guards, danger and traversal time; geometry alone cannot prove that the shortcut is worth learning.

`verification.json` records the saved-file structural checks. It confirms the route components exist and the blend reopens, not that a Roblox character can traverse them.
