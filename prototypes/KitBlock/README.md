# Enfleshed — Playable Kit Block

Open **`Enfleshed_KitBlock.rbxlx`** from the repository root. This is a separate place, not the existing city. The entire block is present in Edit mode; pressing Play spawns directly into its street.

On this machine's Windows-style Studio file dialog, paste:

```text
Z:\home\deck\Projects\Enfleshed\Enfleshed_KitBlock.rbxlx
```

Do not connect the main `default.project.json` Rojo session to this place. For live editing use `rojo serve prototypes/KitBlock/review.project.json`.

## What is being tested

- Six distinct ground-level frontages from the approved frontage kit: narrow shop, recessed shop, barred shop, service entrance, residential entrance, and through-building passage.
- The approved circulation kit's divided rooms, branching passages, service-core loop, dogleg dead end, two-flight stair, gallery, bridge, court, and upper room.
- A ground loop: spawn street → through-building passage → left interior branch → rear residential exit → rear lane → west lane → spawn street.
- A second shortcut: the recessed shop connects the spawn street to the west lane through its rear doorway. The other small shops intentionally end in bounded rooms.
- An upper loop: main interior junction → right branch around the service core → two stair flights → upper gallery → bridge → covered court → upper room. From the upper room, its new side doorway leads through an inhabited bridge room and covered gallery to a second stair pair, returning to the rear lane.
- Existing Enfleshed camera, sprint, dash, melee, damage, death/respawn and optional Nascent pursuit.

The test uses **2,083 static Parts**, including native visual components, explicit collision, lighting fixtures, supports and enclosure. The server adds a small chase switch and up to three enemies on demand. The main usable block is approximately 157 × 133 studs including the stair assembly and storefront depths. The outer ancient enclosure is 198 × 188 studs including wall thickness; its roof underside is 60 studs above the main walking floor. The upper route is at +18 studs. The catch surface is below the block at −12 studs and is not an intended route.

## Important visual distinction

This immediately playable place uses **native Roblox Part reconstructions extracted from the approved Blender kit components**. It preserves kit dimensions, wall divisions, openings, stair geometry and colour families, with separate collision boxes. It does not upload or reference external meshes.

Blender bevels, cylindrical detail cross-sections and the baked PBR atlas are not reproduced by these box components. This is a circulation/scale/chase test, not approval of final imported mesh shading. The original `.blend`, GLB, FBX and textures remain unchanged for a later exact-mesh import. `street_preview.png` is an offline render of these native dimensions, not a Studio screenshot or a lighting match guarantee.

## Controls and chase switch

- **WASD / Space:** move / jump.
- **Mouse:** existing third-person mouse-look camera.
- **Left Shift:** sprint.
- **Q:** dash.
- **Left click:** current recruit melee combo.
- **F** while near the brass switch beside spawn: start one Nascent → replace with three → clear them. Hold briefly as shown by the prompt.

The switch affects the shared test session. It uses the existing server-owned EnemyRuntime and pathfinding budget. No automatic waves, population, quests or event systems start. Nearby occupied enemy spawn points are skipped, so there can be fewer than the requested number. Killed enemies are removed after approximately two seconds (plus up to 0.2 seconds for the cleanup tick) and do not automatically respawn. Clearing the test also removes pending corpses. Restart Play for a clean test.

## Focused Studio test

1. Open the specific KitBlock place above and press **Play**, not Run. Confirm the small KIT BLOCK instructions appear, and that you spawn beside the chase switch without the city opening screen.
2. With no enemies, enter the wide through-passage near spawn. Follow the offset vestibule to the junction. Turn left, pass through the divided room and rear residential entrance, then follow the rear/west lane back to spawn.
3. Enter the recessed shop on the same side of the spawn street. Its rear passage should join the lane. Test both directions and compare it with the intentionally shallow stores.
4. At the interior junction, turn right. Walk both sides of the structural core, then take the stairs to +18. Follow the gallery, bridge, court and upper room. Take its new side doorway through the inhabited bridge room and covered gallery, descend the new stair pair, and rejoin the rear lane. Then test the entire loop in reverse. The upper room's forward doorway leads into a small residential entry alcove with a closed apartment door. Explore the deliberate dogleg and alcove branches.
5. Repeat thresholds, corners and stair transitions while sprinting/dashing. Look for camera clipping, character snagging, apparent holes, low headroom, or an unexpected view of sky.
6. Return to the switch and start one Nascent. Approach it on the spawn street, then lead it through the shop shortcut, interior loop and stair route. Observe corner decisions and hesitation; this pass intentionally preserves current AI rather than hiding navigation problems.
7. Repeat with three enemies. Use melee, test body-blocking in narrow doors, die/reset, and confirm the character respawns at the same street. Use the switch to clear enemies.
8. Start a two-player server test. Confirm shared enemy ownership, damage and switch state; both clients should spawn in the test block. Inspect Output for errors.

If a route fails, record the module/model name from Explorer. No live Studio traversal or multiplayer result is claimed by the offline checks.

## Source files

- `extract_components.py`: reads all three kit libraries in Blender and records their disconnected visual components as local bounds and palette colours; never saves the source libraries.
- `components.json`: reproducible native geometry input, including original collision boxes.
- `build.py`: explicit sample placements, street loop, enclosure, lighting, and separate Rojo mappings.
- `Block.rbxmx`: generated edit-mode geometry; no gameplay scripts inside it.
- `assembly.json`: placements and native Part dimensions used by validation and rendering.
- `review.project.json`: isolated place entry point. Maps the working gameplay modules without running city startup.
- `OpeningService.luau`: test-only adapter that skips the city opening and grants the existing recruit melee starter. The original OpeningService is untouched.
- `Server.server.luau`: starts the existing action router and bounded optional enemy test.
- `Client.client.luau`: test bootstrap for the existing controls/camera, with a small instruction label and no city HUD.
- `surface_cleanup.py`: separates competing native-box visual faces while preserving exact collision geometry.
- `surface_validation.json`: overlap counts and collision-preservation results.
- `test_cleanup.py`: runs the actual cleanup callbacks with Lua engine doubles to check death retirement, delayed removal scheduling, and manual clearing.
- `test_block.py`: collision-envelope probes, connected ground-space flood fill, kit connection tests, compiled module-reference and isolation checks.
- `render_preview.py`: offline native-geometry preview.
- `validation.json`: results; explicitly records `studio_verified: false`.

## Rebuild

From the repository root:

```sh
# Only needed when the source Blender libraries change:
blender --background --python-exit-code 1 --python prototypes/KitBlock/extract_components.py
python3 prototypes/KitBlock/build.py
stylua --check prototypes/KitBlock/*.luau
rojo build prototypes/KitBlock/review.project.json -o Enfleshed_KitBlock.rbxlx
python3 prototypes/KitBlock/test_block.py
python3 prototypes/KitBlock/test_cleanup.py
git diff --check
```

On this machine Blender is run through its installed Flatpak. Rojo 7.7.0 is retained. The main place, city layouts, population, gameplay implementations, and source kits are not edited. Streaming is disabled only for this small separate test place so traversal problems cannot be confused with missing streamed geometry.

## First playtest fixes

The harness now owns corpse removal, as EnemyService expects. A bounded cleanup tick removes dead handles and schedules their models for destruction; clearing a test removes both living enemies and pending corpses.

The native-box conversion contained 1,317 overlapping same-facing coplanar surface pairs. The assembly builder now gives smaller details priority and slightly insets competing backing faces. The compiled place is checked for these overlaps. Maximum dimension reduction is under 0.1 stud; original collision boxes are retained exactly, and ground connectivity and upper routes are unchanged. This targets geometric z-fighting; confirm the result while moving the camera in Studio.

## Upper habitation pass

The six street frontages now have framed apartment-window tiers at +18 and +36. Roof additions, parapets, partial cross-spans and structural ties add human occupation beneath the ancient enclosure. The former continuous low street soffit has been replaced by a few overhead spans so these tiers can be seen. The main street widths and floors are unchanged.

The new upper return runs through a bridge apartment, offset covered gallery, mirrored landing and two existing stair modules. It meets the rear lane through one new portal at the existing lane's eastern end. This is the only ground boundary opening added. The existing chase switch, combat code and corpse cleanup are unchanged.

- `upper_layout.py` defines the bounded additions.
- `ground_baseline.json` protects all 4,546 previously reachable ground test points and the three gameplay bootstrap files.
- The expanded tests check socket alignment, portal clearance, the independent upper return, preserved ground access and absence of coplanar overlap in the compiled place.
- `upper_preview.png` shows the new gallery in an offline render; it is not a Studio screenshot.

For this playtest, focus on completing the new upper loop in both directions, leading one and then three Nascent through both stair pairs, checking the added ceilings with the camera, and confirming that the earlier flickering and corpse cleanup fixes remain intact. The rooftop background dwellings are deliberately closed; their doors do not promise more playable interiors.
