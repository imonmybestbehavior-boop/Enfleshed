# Controls & UI Kit

## Bindings
| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / camera | WASD / mouse | Left stick / right stick |
| Jump | Space | A |
| Sprint | Left Shift | L3 |
| Dash | Q | B |
| Light attack | Left click | RT |
| Heavy attack | R | X |
| Block / parry | Right click (hold; slows you and stops sprint) | LT |
| Switch melee ↔ Magic Focus | E | Y |
| Cast spell slot | 1–9 (hold for held spells) | RB casts the selected slot (hold for held spells) |
| Choose spell slot | — | D-pad ← / → (cycles equipped slots; shown above the HUD) |
| Grimoire | P | View / Select |
| Inventory | I | D-pad ↓ |
| Inventory item actions | Drag; right-click menu | Select slot, A opens the item menu |
| Close a menu | Esc / close button | B |
| Navigate menus | Mouse | D-pad / left stick, A to press |

Glyph text shown in prompts comes from `InputMode.Glyphs` and switches automatically with the last device used.

Known gamepad gaps (Phase 2 UI pass): no drag between bag slots (use the item menu), Spell Forge text fields need the on-screen keyboard, the Grimoire layout is mouse-first, quick-slot consumables (Y/U) have no gamepad binding yet, summon command keys are keyboard-only.

## UI kit (`src/client/UI/Kit`)
| Module | Use |
|---|---|
| `Tokens` | colors (Spell Forge palette), fonts, text sizes, spacing, radius, minimum target size, reference resolution |
| `Responsive.attach(gui, root)` | UIScale from viewport vs 1280×720 (0.6–1.4), device safe area, respects Player attribute `UIScaleSetting` |
| `InputMode` | current device (`Keyboard`/`Gamepad`/`Touch`), `Changed` signal, `glyph(action, mode)` |
| `GamepadNav.open(root, onClose)` / `.close(root)` | makes a panel's buttons selectable, keeps selection inside it, selects the first item, B closes; panels stack and selection is restored after rebuilds |

New screens: build with Tokens, call `Responsive.attach` on the root frame, and register every menu with `GamepadNav`. Existing screens (HUD, Mission HUD, Grimoire, Inventory) still use their own layout code; migrate them as they are redesigned in Phase 2.
