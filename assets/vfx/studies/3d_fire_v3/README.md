# Curls following the body

Responds to the user's correction that the tongues should curve without flaring outward.

The curved stroke now rolls around the projectile's travel axis rather than adding an outward radial bulge. Its distance from the axis decreases toward its tip. Width controls follow the local shell. The palette, birth-to-wake progression, rigid-rail skinning and playback timing are retained.

The preview includes fixed-camera, orbit and isolated-tongue loops, with the previous outward-curl version available for comparison. The earlier v2 geometry and previews are preserved; `../3d_fire_v2/generator_snapshot.py` records its generator before this change.

`validation.json` checks source deformation, skin influences, rigid bone matrices, loop closure and the minimal FBX roundtrip. It also checks the sampled tongue centerlines do not increase their radius beyond their starting radius. That is a path check, not a guarantee about every point on the visible mesh.

This revision is a Blender study, not a newly imported Roblox asset or finished production fireball. Full-body overlap, repeated shapes, gaps and final dissipation remain visual review items. The source is `hooked_flame_study.blend`; `single_hooked_tongue.fbx` is the corrected-scale single-tongue export. No new upload has been performed.
