> Studio installation: the approved 91-image / 60-mesh library is now integrated. See [STUDIO_INTEGRATION.md](STUDIO_INTEGRATION.md) for upload receipts, runtime wiring, the connected-lightning correction, and verification. Earlier local-only status notes below describe the original bake stage.

# Existing asset restyle — Cel & Brush

**Bake update (2026-10-18):** the user approved this style pass and requested the bake. `baked/` now contains 91 unique identity-specific atlases from all 71 existing texture designs. The gallery reads those actual baked PNGs. `existing_asset_baked_pass.zip` packages them with the 60 mesh material variants, manifests, profile and import notes. Source alpha and original artwork are preserved; no uploads or production activation occurred. See [BAKED_IMPORT.md](BAKED_IMPORT.md).

This pass restyles the **current custom library**, rather than inventing more spell designs. It is a material/palette pass inspired by flat cel-shaded adventure art, with a restrained traditional-art influence through warm accents and colored ink. No new motifs, paper textures, geometric shapes or animation frames are added.

Open `http://127.0.0.1:8767/studies/style_unification_v1/index.html` while the local `assets/vfx` preview server is running.

## Delivered

- All **60 existing mesh GLBs** have local material-region variants in `meshes/`. Original positions, normals, UVs and every oriented triangle are retained. Only face material assignments and palette values change. The existing ink hulls use colored shadow ink, with no extra hull growth.
- All **71 existing textures** are baked into 91 unique identity-specific colored atlases, with original dimensions, alpha, atlas layout and frame order. Their source PNG files remain untouched. The revised gallery view loads the baked PNGs directly.
- The profile covers the **13 existing visual identities**. It does not create new gameplay principles or make unsupported Principle/Form pairs valid.
- `assets/vfx/styles/cel_traditional_v1.json` contains the palette and proposed runtime look controls. It is review data, not an active production override.

The comparison uses a neutral kit-tinted source view and a flat restyle view, sharing the frame and camera. It is not an exact before/after of a fully layered Studio spell. The actual game may add scene lighting, bloom and material effects that this gallery does not reproduce.

## Art decisions

Use broad body/light regions, hue-shifted shadows, small warm accents and colored contour ink. Existing glyph/sigil linework keeps its source shape. `glow_soft` and `heat_haze` retain continuous tone falloff. Texture alpha is copied verbatim, including smoke fades and original cutouts. No source noise is deleted, no contours are invented, and no atlas cell is moved.

Mesh color regions follow the existing face normals. Area-weighted thresholds keep one triangulation-heavy detail from dominating the palette. Cream accents are limited to small eligible regions; a broad tied top plane does not become a large white highlight. Near-flat surfaces retain a body band instead of receiving fake painted shapes. Region colors are baked into ordinary glTF material slots, not a required custom shader.

The existing procedural texture library was already cel-processed, so another global posterization/outline pass is intentionally avoided. The main difference is how existing values map to colored ink, shadow, body, light and accent roles, plus material grouping on the meshes.

## Verification

Run `tools/vfx_pipeline/restyle_existing_assets.py` to reproduce the variants from existing GLBs and index existing textures. Run `bake_existing_texture_style.py` to bake the approved palette per source frame, then `package_baked_restyle.py` to package and verify the archive. Run `tests/test_existing_asset_restyle.py` and `tests/test_baked_existing_textures.py` for eight checks covering source/geometry preservation, full coverage, original alpha/layout, palette values and soft falloff. Run Node's syntax check on `review.mjs`.

All four checks pass for this pass. Source hashes include the 131 original assets, current asset IDs and production signature selection/rendering files. Original artwork and production rendering are unchanged. The approved connected fireball and prior Soul study are separate and untouched.

Browser checks inspected the Soul wisp, Soul skull, Fire flame flipbook, Fire core and Water crown. Palette/identity selection, source/revised frame lock, pause/scrub, mesh orbit, the existing ink hull and variant links work. The console error/warning log was empty. This is representative visual review, not art acceptance of every asset.

## Before production

The baked local variants are ready to inspect. No artwork was uploaded and no live asset IDs were reassigned. Exact multi-color texture lookup cannot be reproduced by multiplying a grayscale Roblox particle texture by one tint. This bake supplies colored images; verify their behavior in the existing renderer with the appropriate white/neutral base tint before replacing anything.

The GLB material pass does not establish that Roblox's FBX import preserves these face material slots. Test one representative existing mesh in Studio, compare it against the gallery, and use a verified material/texture bake if needed. Do not assume browser or glTF shading transfers automatically. Keep the current gameplay and fallback recipes until parity is shown. New/changed uploaded bytes require the artwork-upload authorization already established for this project; no extra upload has been performed here.

The Surface Pro's earlier loaded empty-scene result is not attributed to the effects. This gallery makes no Roblox performance claim.
