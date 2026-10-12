# Enfleshed — Storefront Kit V2

## Open and review (no scripting needed)

1. Open Blender 5.2.
2. Choose **File → Open** and open `assets/blender/generated/storefront_v2/storefront_kit_v2.blend` inside `/home/deck/Projects/Enfleshed`.
3. Press **Numpad 0** to see the overview camera. Without a numpad, use **View → Cameras → Active Camera**.
4. Start with the supplied `storefront_v2_overview.png` and six numbered detail images. They are already rendered; you do not need to wait for Blender to render.
5. In the Outliner at the upper right, expand any numbered shop collection. Select its pieces and choose **View → Frame Selected** to inspect it. Middle mouse orbits; the wheel zooms. Use the on-screen navigation gizmo if your mouse has no middle button.
6. To render one shop yourself, select its CAMERA in the Outliner, use **View → Cameras → Set Active Object as Camera**, then **Render → Render Image**. The original saved camera is the overview.
7. Use **File → Save As** with a new filename for your own edits.

## What changed

Six genuinely different uses share a believable architectural scale: four-metre frontage, 3.4-metre shallow interior, approximately 2.2-metre door height. The street is toward negative Y, with the front at Y=0. Dimensions are review proportions in metres, not a commitment to Roblox studs.

- **Hearth food counter:** street serving bowls and menu, timber counter, open staff door, cookware, ingredient shelving, striped canopy.
- **Daily rations:** framed display with grain bins, security bars, folded shutters, side entry, weighing balance and stocked shelving.
- **Tool repair:** broad open working bay, folded timber shutters, workbench and vise, hanging hammers, repair chest and spare wheels.
- **Lower dispensary:** modest service emblem, medicine display, open entry, treatment cot and bottle shelving.
- **Cloth and mending:** fabric bolts in the window, hanging textiles, folded cloth and a worktable, canopy and side door.
- **Residential through passage:** mail cubbies, side stair, narrow hall and real rear doorway. Intended as a candidate connection to a courtyard, not a decorative dead end.

Old block piers and lintels carry later timber infill, utility drainpipes, lamps and small masonry repairs. Materials are restrained and procedural, so this file has no missing image dependencies. These remain stylized art-review assets; they are not a final sculpted or textured production set.

## Organization and reuse

Each numbered collection is a marked collection asset. `00 REVIEW ONLY` holds the review ground, drains, cameras and exterior lights. Each shop contains its own warm interior light. Exclude lighting, cameras and the review ground from game export.

Use **File → Append**, open this blend's **Collection** folder, and choose the shop collection to bring it into another Blender scene. The saved scene is a comparison lineup, not the final dense city map. Shops can be placed together along a narrow street; the passage can connect to a rear alley. A useful secret route still requires actual destination connections, blockers or danger in the game layout.

V1's script and blend are preserved. No Roblox scripts, place files, existing materials or prior Blender scenes are modified by this kit. V2 is not automatically installed into the running game.

## Regenerate (optional)

Save any open work first. The generator clears the currently open scene, so use a **new empty Blender file** if running it from Blender's Text Editor. Open `assets/blender/scripts/storefront_kit_v2.py` in the Text Editor and press **Run Script**. It saves to the V2 directory above. It does not open V1.

On this machine you can instead run in a terminal:

```bash
flatpak run org.blender.Blender --background --python /home/deck/Projects/Enfleshed/assets/blender/scripts/storefront_kit_v2.py -- --render
```

This rebuilds the V2 blend and seven preview images. `--output-dir /absolute/path` chooses a different destination. The script uses Blender 5.2 APIs and avoids the removed V1 Eevee sampling properties. The material `use_nodes` setting currently emits a Blender 6.0 deprecation notice but is supported in Blender 5.2.

## Before game import

Review the style first. Then make export copies, convert lettering if needed, apply/merge geometry selectively, establish UVs and texture baking, set Roblox scale and test collision in Studio. The kit intentionally retains separate named pieces for editing. It is not an optimized game mesh, and its procedural materials do not transfer directly to Roblox. Door clearances and the passage must be checked with the actual player controller. The side stair is a visual prototype and requires collision and headroom review in context.

## Validation performed

Generated and reopened with **Blender 5.2.0 LTS**. Checked six collection assets, seven cameras, 628 mesh objects with positive dimensions, collection origins and parent relationships, thresholds and door frames, the rear passage opening, and the saved overview camera. Rendered and visually reviewed the overview and all six detail views. See `generated/storefront_v2/validation.json` for the machine-readable scene checks and `manifest.json` for output fingerprints and preserved V1 fingerprints.
