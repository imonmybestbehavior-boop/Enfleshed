# Enfleshed enemy visuals

These GLB files are the source meshes for the Defend the Walls enemies. The server selects `Basic`, `Swift`, `Brute`, or `Elite` when it spawns an enemy. It builds the Humanoid, collision hull, hit detection, and animation joints; the imported MeshParts provide the visible body.

## One-time Roblox Studio import

1. Open the game place in Roblox Studio. Use **File > Import 3D** to import each `Enfleshed_<Kind>.glb` in this directory. Keep the six MeshParts and their embedded appearance assets. Do not import the FBX or Blender files as well.
2. Create `ServerStorage/EnfleshedModels` as a Folder. Put each imported model inside it and name the models exactly `Basic`, `Swift`, `Brute`, and `Elite`.
3. Check each model has MeshParts named exactly `Torso`, `Head`, `Left Arm`, `Right Arm`, `Left Leg`, and `Right Leg`. They may be nested in the model. Remove any imported animation or extra rig if the importer creates one; the game supplies its own Humanoid and joints.
4. Save or publish the place so those mesh assets and templates are available to the running server. Run Defend the Walls and inspect the `ImportedVisual` attribute on an enemy Model. It should be `true`. A missing or incomplete template logs a warning and uses the existing placeholder body.

The manifest JSON files record each part's center and size in studs. `src/shared/Configuration/EnemyVisuals.luau` contains the matching runtime placement and joint pivots. The source GLBs are not loaded directly by Luau or Rojo; Studio must import them to create Roblox MeshParts.
