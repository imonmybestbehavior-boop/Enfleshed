# Two-handed melee key tables (Greatsword, Spear)

Starter clips built in the place as `<Archetype>_TwoHand_<Move>` in
`ServerStorage.RBX_ANIMSAVES.MeleeAnimDummy_<Archetype>`, next to the retimed
Sword-based starters. Same conventions as the Melee Impact Package: 60 fps, degrees
relative to rest, easing set on a key shapes the move to the next key, priority
Action, looped off. Frames come from MeleeProfiles (Startup / Active / Recovery).

How these were authored: the body columns (Waist, Neck, hips and root) and the lead
hand / blade direction are the design. Both arms are solved from them with two-bone
IK (right hand on the grip point, left hand on the grip at 0.55 studs below the lead
hand for the Greatsword, 0.95 studs ahead of it for the Spear), and the WeaponGrip key
turns the weapon to the blade direction, with its roll chosen to keep wrist turns
small. Lead hand is in HumanoidRootPart space (x right, y up, -z forward). Superseded in the place on 2026-10-17: the clips are now rebuilt by
`ServerStorage.DevTools.TwoHandBuilder` (collision-aware placement, baked every 1-2
frames, knees bending the right way) and verified by `ServerStorage.DevTools.ClipChecker`,
so the solved angles below are the first pass, not the current clips.

Known tune points: the left hand misses the grip by up to 0.3 studs at the
Greatsword heavy's floor keys (f27-f41) and the Spear's full extension; the Spear L2
coil folds the right elbow to 160 degrees. Block, parry and dash reuse the Sword clips.

## Greatsword_TwoHand_L1
Diagonal cut, high right to low left. Clip 38 f, S 8 / A 7 / R 14 f; markers TrailOn f6, Hit f8, TrailOff f15, Settle f29.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Y -20 | Y 15 | LowerTorso pos (0, -0.15, 0); RightHip X -10; LeftHip X 10 | (0.25, -0.1, -1) | (0.05, 0.75, -0.65) | X 33, Y 35, Z -49 | X 62 | X 12, Y -45, Z 38 | X 62 | X 27, Y -3, Z -1 | Quad Out |
| 6 | coil | X -5, Y -40 | Y 30 | LowerTorso pos (0, -0.2, 0); LowerTorso Y -10; RightHip X -12; LeftHip X 12 | (0.9, 1.3, -0.3) | (0.35, 0.75, 0.55) | X 71, Y 47, Z -30 | X 118 | X 71, Y -39, Z 72 | X 96 | X 30, Y -36, Z -18 | Cubic In |
| 8 | contact | Y -25 | Y 20 | Hold | (0.7, 1.1, -1) | (0.56, 0.56, -0.61) | X 75, Y 19, Z -56 | X 70 | X 62, Y -54, Z 65 | X 111 | X -15, Y -27, Z -50 | Linear |
| 12 | centre | X 10, Y 5 | 0 | LowerTorso pos (0, -0.3, 0); LowerTorso Y -10; RightHip X -20; LeftHip X 15 | (0.1, 0.4, -1.4) | (-0.45, -0.25, -0.86) | X 46, Y -29, Z -56 | X 14 | X 56, Y -19, Z 62 | X 54 | X -34, Y 3, Z -53 | Linear |
| 15 | exit | X 15, Y 35 | X -5, Y -15 | LowerTorso pos (0, -0.35, 0); LowerTorso Y 10 | (-0.5, -0.2, -1.1) | (-0.81, -0.51, -0.3) | X 19, Y 23, Z -25 | X 62 | X 5, Y 25, Z 83 | 0 | X -46, Y 16, Z -49 | Quart Out |
| 20 | overshoot | X 18, Y 42 | X -5, Y -10 | LowerTorso pos (0, -0.38, 0); LowerTorso Y 12 | (-0.5, -0.3, -0.8) | (-0.62, -0.72, 0.31) | X 2, Y 37, Z -17 | X 78 | X 4, Y 25, Z 84 | 0 | X -67, Y 38, Z -34 | Sine InOut |
| 29 | settle | X 8, Y 25 | Y -5 | LowerTorso pos (0, -0.25, 0); LowerTorso Y 12 | (-0.25, -0.1, -1.05) | (-0.3, 0.3, -0.9) | X 5, Y 39, Z -17 | X 87 | X 28, Y -48, Z 58 | X 63 | X -3, Y -37, Z -39 | Sine InOut |
| 38 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

## Greatsword_TwoHand_L2
Rising finisher, low left to high right. Clip 44 f, S 10 / A 7 / R 18 f; markers TrailOn f8, Hit f10, TrailOff f17, Settle f35.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Quad Out |
| 8 | coil | X 10, Y 45 | Y -20 | LowerTorso pos (0, -0.35, 0); LowerTorso Y 12; RightHip X -15; LeftHip X 15 | (-0.7, -0.3, -0.5) | (-0.61, -0.56, 0.56) | X 16, Y 45, Z -33 | X 76 | X 33, Y -4, Z 72 | X 25 | X -68, Y 13, Z 4 | Cubic In |
| 10 | contact | X 5, Y 30 | Y -12 | Hold | (-0.55, 0, -1.15) | (-0.66, -0.36, -0.66) | X 25, Y 32, Z -27 | X 80 | X 50, Y -36, Z 72 | X 65 | X -66, Y -26, Z -29 | Linear |
| 14 | centre | X -5 | 0 | LowerTorso pos (0, -0.2, 0); RightHip X -25; LeftHip X 18 | (0.1, 0.7, -1.45) | (0.2, 0.25, -0.95) | X 63, Y 26, Z -47 | X 74 | X 54, Y -55, Z 62 | X 106 | X -43, Y -49, Z -33 | Linear |
| 17 | exit | X -12, Y -35 | X 5, Y 15 | LowerTorso pos (0, -0.1, 0); LowerTorso Y -10 | (0.7, 1.3, -0.95) | (0.71, 0.61, -0.35) | X 87, Y 27, Z -64 | X 92 | X 92, Y -55, Z 100 | X 125 | X -22, Y -52, Z -26 | Quart Out |
| 23 | overshoot | X -15, Y -42 | X 5, Y 12 | LowerTorso Y -12 | (0.8, 1.5, -0.6) | (0.46, 0.81, 0.36) | X 93, Y 41, Z -44 | X 112 | X 86, Y -41, Z 88 | X 110 | X 11, Y -56, Z -8 | Sine InOut |
| 35 | settle | X -5, Y -25 | Y 10 | LowerTorso pos (0, -0.15, 0) | (0.45, 0.6, -1) | (0.25, 0.76, -0.6) | X 60, Y 38, Z -66 | X 82 | X 6, Y -72, Z 27 | X 115 | X 2, Y -17, Z -5 | Sine InOut |
| 44 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

## Greatsword_TwoHand_Heavy
Overhead cleave driven into the floor, one-frame hold at the peak. Clip 71 f, S 23 / A 10 / R 27 f; markers Whoosh f18, TrailOn f20, Hit f23, TrailOff f33, Settle f60.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Quad Out |
| 7 | gather | X -5, Y -25 | Y 20 | LowerTorso pos (0, -0.25, 0); RightHip X 15; LeftHip X -5 | (0.55, 0.5, -0.7) | (0.25, 0.9, -0.35) | X 33, Y 66, Z -41 | X 125 | X 37, Y -64, Z 62 | X 93 | X 12, Y -9, Z -6 | Sine InOut |
| 21 | peak | X -20, Y -20 | X 15, Y 10 | LowerTorso pos (0, 0.05, 0); RightHip X 20; LeftHip X -10 | (0.25, 2, 0.15) | (0.05, 0.35, 0.94) | X 97, Y 22, Z 137 | X 101 | X 56, Y -22, Z 150 | X 66 | X -106, Y 11, Z -84 | Quad Out |
| 22 | hold | X -22, Y -20 | Same | Same | (0.25, 2.05, 0.2) | (0.05, 0.3, 0.95) | X 100, Y 26, Z 133 | X 94 | X 45, Y -26, Z 152 | X 54 | X -103, Y 6, Z -85 | Cubic In |
| 23 | contact | X 5, Y -8 | X 5 | LowerTorso pos (0, -0.1, 0); RightHip X -20; LeftHip X 10 | (0.15, 1.8, -0.95) | (0, 0.95, -0.3) | X 95, Y -6, Z -58 | X 44 | X 75, Y -31, Z 63 | X 88 | X -6, Y -9, Z -21 | Linear |
| 27 | centre | X 30 | X -10 | LowerTorso pos (0, -0.5, -0.3); RightHip X -45; LeftHip X 30; RightKnee X 45; LeftKnee X 20 | (0.05, 0.5, -1.45) | (0, -0.3, -0.95) | X 35, Y -50, Z -58 | 0 | X 55, Y -14, Z 52 | X 50 | X -26, Y -34, Z -47 | Linear |
| 33 | exit (Ground) | X 45, Y 5 | X -20 | LowerTorso pos (0, -0.7, -0.3) | (0.05, -0.3, -1.35) | (0, -0.76, -0.65) | X 22, Y -44, Z -45 | 0 | X 21, Y 42, Z 63 | 0 | X -54, Y -31, Z -73 | Quart Out |
| 41 | overshoot | X 50, Y 5 | X -22 | LowerTorso pos (0, -0.75, -0.3) | (0.05, -0.38, -1.3) | (0, -0.78, -0.62) | X 21, Y -42, Z -44 | 0 | X 19, Y 42, Z 61 | 0 | X -59, Y -28, Z -77 | Sine InOut |
| 60 | recover | X 22, Y 5 | X -5 | LowerTorso pos (0, -0.35, -0.3); RightHip X -20; LeftHip X 15; RightKnee X 20; LeftKnee X 10 | (0.2, 0, -1.25) | (0.05, 0.2, -0.98) | X 23, Y 31, Z -30 | X 65 | X 31, Y -51, Z 55 | X 71 | X -25, Y -31, Z -44 | Sine InOut |
| 71 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

Greatsword guard: Waist Y -20, Neck Y 15, LowerTorso pos (0, -0.15, 0), RightHip X -10, LeftHip X 10; lead hand (0.25, -0.1, -1), blade (0.05, 0.75, -0.65); RightShoulder X 33, Y 35, Z -49; RightElbow X 62; LeftShoulder X 12, Y -45, Z 38; LeftElbow X 62; WeaponGrip X 27, Y -3, Z -1.

## Spear_TwoHand_L1
Mid thrust. Clip 29 f, S 5 / A 5 / R 10 f; markers TrailOn f3, Hit f5, TrailOff f10, Settle f20.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Quad Out |
| 3 | coil | Y -38 | Y 32 | LowerTorso pos (0, -0.22, 0.1); RightHip X -12; LeftHip X 18 | (0.65, -0.1, 0.1) | (-0.1, 0.18, -0.98) | X -83, Y 57, Z 41 | X 133 | X 27, Y -44, Z 37 | X 86 | X -15, Y -7, Z -3 | Cubic In |
| 5 | contact | X 5, Y -25 | Y 20 | LowerTorso pos (0, -0.25, -0.1) | (0.45, 0.05, -0.65) | (-0.08, 0.12, -0.99) | X 5, Y 62, Z -27 | X 105 | X 46, Y -8, Z 37 | X 46 | X -35, Y -24, Z -19 | Linear |
| 8 | centre | X 10, Y -20 | X -5, Y 15 | LowerTorso pos (0, -0.3, -0.25); RightHip X -25; LeftHip X 25; RightKnee X 15 | (0.3, 0.15, -1) | (-0.04, 0.08, -1) | X 33, Y 47, Z -46 | X 83 | X 46, Y 54, Z 44 | 0 | X -43, Y -29, Z -25 | Linear |
| 10 | exit | X 12, Y -18 | Same | LowerTorso pos (0, -0.32, -0.3) | (0.28, 0.15, -1.05) | (-0.03, 0.07, -1) | X 33, Y 45, Z -46 | X 82 | X 43, Y 55, Z 46 | 0 | X -45, Y -31, Z -26 | Quart Out |
| 14 | overshoot | X 12, Y -17 | Same | Same | (0.27, 0.15, -1.07) | (-0.03, 0.06, -1) | X 34, Y 45, Z -45 | X 81 | X 44, Y 54, Z 46 | 0 | X -45, Y -30, Z -29 | Sine InOut |
| 20 | settle | X 5, Y -25 | Y 20 | LowerTorso pos (0, -0.25, -0.1); RightHip X -18; LeftHip X 18; RightKnee X 5 | (0.5, -0.02, -0.55) | (-0.1, 0.18, -0.98) | X -14, Y 64, Z -11 | X 111 | X 43, Y -16, Z 38 | X 52 | X -28, Y -22, Z -14 | Sine InOut |
| 29 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

## Spear_TwoHand_L2
High thrust angled down over a guard. Clip 29 f, S 5 / A 5 / R 10 f; markers TrailOn f3, Hit f5, TrailOff f10, Settle f20.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Quad Out |
| 3 | coil | X -5, Y -38 | Y 32 | LowerTorso pos (0, -0.2, 0.1); RightHip X -12; LeftHip X 18 | (0.7, 0.75, 0.1) | (-0.1, -0.12, -0.99) | X -156, Y 79, Z 147 | X 160 | X 57, Y -43, Z 55 | X 94 | X -79, Y -30, Z -62 | Cubic In |
| 5 | contact | Y -25 | Y 20 | LowerTorso pos (0, -0.22, -0.1) | (0.45, 1.1, -0.6) | (-0.08, -0.18, -0.98) | X 80, Y 49, Z -70 | X 118 | X 68, Y -19, Z 40 | X 68 | X -98, Y -16, Z -78 | Linear |
| 8 | centre | X 6, Y -20 | X -5, Y 15 | LowerTorso pos (0, -0.28, -0.25); RightHip X -25; LeftHip X 25; RightKnee X 15 | (0.32, 1.05, -0.85) | (-0.05, -0.22, -0.97) | X 74, Y 38, Z -66 | X 99 | X 68, Y -3, Z 40 | X 43 | X -95, Y -17, Z -75 | Linear |
| 10 | exit | X 8, Y -18 | Same | LowerTorso pos (0, -0.3, -0.3) | (0.3, 1.03, -0.9) | (-0.05, -0.23, -0.97) | X 72, Y 37, Z -63 | X 95 | X 68, Y 7, Z 42 | X 33 | X -96, Y -16, Z -72 | Quart Out |
| 14 | overshoot | X 8, Y -17 | Same | Same | (0.3, 1.02, -0.92) | (-0.05, -0.24, -0.97) | X 71, Y 37, Z -62 | X 95 | X 67, Y 15, Z 44 | X 26 | X -96, Y -16, Z -73 | Sine InOut |
| 20 | settle | X 3, Y -25 | Y 20 | LowerTorso pos (0, -0.22, -0.1); RightHip X -18; LeftHip X 18; RightKnee X 5 | (0.5, 0, -0.55) | (-0.1, 0.15, -0.98) | X -18, Y 65, Z -8 | X 113 | X 43, Y -19, Z 38 | X 55 | X -27, Y -20, Z -17 | Sine InOut |
| 29 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

## Spear_TwoHand_L3
Sweeping cut with the head, right to left (wide hitbox finisher). Clip 35 f, S 7 / A 6 / R 13 f; markers TrailOn f5, Hit f7, TrailOff f13, Settle f26.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Quad Out |
| 5 | coil | Y -45 | Y 35 | LowerTorso pos (0, -0.22, 0); RightHip X -12; LeftHip X 15 | (0.6, 0.15, -0.3) | (0.75, 0.1, -0.65) | X -13, Y 71, Z -11 | X 120 | X 26, Y 45, Z 75 | 0 | X -19, Y -54, Z -28 | Cubic In |
| 7 | contact | Y -30 | Y 25 | Hold | (0.5, 0.2, -0.55) | (0.45, 0.05, -0.89) | X 8, Y 67, Z -27 | X 113 | X 32, Y 48, Z 68 | 0 | X -33, Y -46, Z -38 | Linear |
| 10 | centre | X 5, Y -5 | Y 5 | LowerTorso pos (0, -0.28, 0); RightHip X -20; LeftHip X 20 | (0.25, 0.2, -0.75) | (0, 0.02, -1) | X 16, Y 59, Z -31 | X 106 | X 32, Y 50, Z 65 | 0 | X -45, Y -40, Z -44 | Linear |
| 13 | exit | X 8, Y 20 | Y -15 | LowerTorso Y 8 | (0, 0.15, -0.7) | (-0.6, 0, -0.8) | X -20, Y 62, Z -3 | X 121 | X 26, Y 46, Z 68 | 0 | X -43, Y -35, Z -41 | Quart Out |
| 18 | overshoot | X 8, Y 28 | Y -18 | LowerTorso Y 10 | (-0.05, 0.1, -0.65) | (-0.8, -0.05, -0.6) | X -40, Y 63, Z 13 | X 126 | X 24, Y 45, Z 66 | 0 | X -42, Y -32, Z -35 | Sine InOut |
| 26 | settle | X 3, Y -10 | Y 10 | LowerTorso pos (0, -0.22, 0); LowerTorso Y 0 | (0.45, 0, -0.5) | (-0.2, 0.15, -0.97) | X -37, Y 64, Z 8 | X 121 | X 47, Y 1, Z 50 | X 33 | X -22, Y -27, Z -18 | Sine InOut |
| 35 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

## Spear_TwoHand_Heavy
Lunging power thrust, one-frame hold at full coil. Clip 57 f, S 17 / A 7 / R 22 f; markers Whoosh f12, TrailOn f14, Hit f17, TrailOff f24, Settle f46.

| Frame | Key | Waist | Neck | Hips and root | Lead hand | Blade dir | RightShoulder | RightElbow | LeftShoulder | LeftElbow | WeaponGrip | Easing to next |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Quad Out |
| 5 | gather | X -5, Y -50 | Y 40 | LowerTorso pos (0, -0.3, 0.3); RightHip X -5; LeftHip X 25; LeftKnee X 15 | (0.75, -0.1, 0.3) | (-0.08, 0.15, -0.99) | X -67, Y 57, Z 30 | X 133 | X 24, Y -48, Z 31 | X 96 | X -25, Y 4 | Sine InOut |
| 15 | peak | X -6, Y -52 | Y 42 | LowerTorso pos (0, -0.32, 0.35) | (0.78, -0.1, 0.38) | (-0.08, 0.15, -0.99) | X -66, Y 56, Z 28 | X 135 | X 26, Y -49, Z 33 | X 96 | X -27, Y 7, Z 1 | Quad Out |
| 16 | hold | X -7, Y -52 | Same | Same | (0.79, -0.1, 0.4) | (-0.08, 0.15, -0.99) | X -70, Y 54, Z 31 | X 137 | X 28, Y -48, Z 37 | X 96 | X -25, Y 9, Z 2 | Cubic In |
| 17 | contact | X 5, Y -30 | Y 25 | LowerTorso pos (0, -0.35, -0.1) | (0.5, 0.05, -0.6) | (-0.06, 0.1, -0.99) | X 10, Y 64, Z -28 | X 109 | X 44, Y -18, Z 33 | X 57 | X -42, Y -23, Z -21 | Linear |
| 20 | centre | X 15, Y -22 | X -8, Y 18 | LowerTorso pos (0, -0.55, -0.6); RightHip X -45; LeftHip X 35; RightKnee X 40; LeftKnee X 5 | (0.3, 0.15, -1) | (-0.04, 0.07, -1) | X 37, Y 61, Z -51 | X 105 | X 49, Y -6, Z 36 | X 46 | X -62, Y -31, Z -43 | Linear |
| 24 | exit | X 16, Y -20 | Same | LowerTorso pos (0, -0.6, -0.65) | (0.28, 0.15, -1.05) | (-0.03, 0.06, -1) | X 39, Y 59, Z -53 | X 104 | X 52, Y -1, Z 38 | X 37 | X -66, Y -32, Z -46 | Quart Out |
| 31 | overshoot | X 16, Y -19 | Same | LowerTorso pos (0, -0.62, -0.68) | (0.27, 0.14, -1.07) | (-0.03, 0.05, -1) | X 39, Y 59, Z -53 | X 105 | X 52, Y 1, Z 40 | X 37 | X -68, Y -34, Z -48 | Sine InOut |
| 46 | recover | X 5, Y -25 | Y 20 | LowerTorso pos (0, -0.3, -0.2); RightHip X -20; LeftHip X 20; RightKnee X 10; LeftKnee X 0 | (0.5, -0.02, -0.55) | (-0.1, 0.18, -0.98) | X -31, Y 69, Z 3 | X 120 | X 41, Y -25, Z 38 | X 63 | X -28, Y -23, Z -16 | Sine InOut |
| 57 | guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | Guard | End |

Spear guard: Waist Y -30, Neck Y 25, LowerTorso pos (0, -0.2, 0), RightHip X -15, LeftHip X 15; lead hand (0.55, -0.05, -0.45), blade (-0.12, 0.2, -0.97); RightShoulder X -20, Y 64, Z -5; RightElbow X 111; LeftShoulder X 37, Y -26, Z 34; LeftElbow X 69; WeaponGrip X -21, Y -15, Z -10.
