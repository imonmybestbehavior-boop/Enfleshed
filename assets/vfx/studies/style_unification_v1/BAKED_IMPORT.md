> Installed after user authorization. Use [STUDIO_INTEGRATION.md](STUDIO_INTEGRATION.md) and `baked/studio_uploads/uploaded.json` for current status; the original bake metadata below is retained as provenance.

# Approved existing-art style — baked package

The user approved the existing-asset comparison and requested the bake on 2026-10-18. This package contains **91 unique colored atlases from 71 original texture designs**, plus the **60 existing mesh material variants**. Shared textures have separate identity palettes; repeated references within one identity are deduplicated. No new effect silhouette, mesh geometry, symbol or animation frame is authored.

## Files

- `textures/IDENTITY/IDENTITY__asset.png`: baked 8-bit RGBA atlases. The RGB contains the approved palette. Alpha is copied byte-for-byte from the corresponding source.
- `manifest.json`: identity/name mapping, original and output hashes, dimensions, atlas layout, frame count, tiling and verification metadata. `uploaded_id` is null because these bytes have not been uploaded.
- `meshes/*.glb`: the existing geometry with flat face material regions and colored ink. Original positions, normals, UVs and all oriented triangles are preserved.
- `mesh_manifest.json`: identity, hash, source reference ID where available and unchanged triangle count for each material variant. Source IDs are references to old assets, not IDs for the changed files.
- `style_profile.json`: the approved palette and review controls used by this bake.
- `baked_contact_sheet.png`: one representative existing frame per source design, in its primary identity. Shared identity variants remain in the manifest.

## What is already checked

The source files and production asset IDs remain unchanged. Automated checks cover all source textures and identity variants, exact source alpha at every pixel, size/layout/frame count, approved palette membership, retained soft falloff for utility effects, all original mesh triangles/UVs, and archive integrity. Source hashes and output hashes are in the manifests.

The gallery's revised texture view now loads these actual PNG files directly. It no longer depends on a live color lookup. Both source and revised views share the same existing frame. Playback speed in the gallery remains a review setting, not a gameplay timing change.

## Representative Studio check before activation

Begin with a face-bearing Soul wisp and a Fire flame atlas, plus one existing mesh with clearly separated material regions. Do not replace the complete production library merely because these files bake correctly.

Colored PNGs already contain the palette: start the test with white particle/beam/trail color, restrained emission and the original flipbook layout/rate. Applying the previous saturated color sequence over the colored image will multiply its colors and can obscure the approved bands. Retain the existing lifecycle, transparency envelope, quality selection and feature-driven timing. Player tint needs deliberate handling rather than a second full palette tint.

The GLBs use ordinary face materials with unlit color intent for local interchange. This does not prove that the existing Roblox import route preserves all material slots or supports the same unlit treatment. Verify the imported appearance against the gallery before choosing a material/texture representation. No Blender/browser shader behavior is assumed to transfer.

No artwork upload or place publication is included in the bake. The project's requirement to authorize artwork uploads still applies to these changed image/mesh bytes. Runtime performance, material transfer, published-place permissions and full-effect scene-lighting parity remain separate checks.
