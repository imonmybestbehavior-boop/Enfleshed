# HUD redesign and Begin Mission fix

## Module layout (`src/client`)
- `Controllers/UIController.luau`: starts every HUD screen, routes `MissionRemote` messages and owns the cursor/modal rule.
- `UI/HUD/Theme.luau`: all colors, fonts, sizes and motion values.
- `UI/HUD/Components.luau`: panel, bar (eased with a ghost chip), button (hover scale) and root (UIScale with a 10-foot boost).
- `UI/HUD/CombatHUD.luau`: level badge, Health/Mana bars, 10-pip Strain meter (pulses red at 80% or more), hit edge flash.
- `UI/HUD/SpellBar.luau`: combo pips, 6 slots (glyph, key, mana cost, cooldown sweep, no-mana dim, RB highlight on gamepad), Grimoire button, consumable slot, and drag-and-drop targets.
- `UI/HUD/SpellState.luau`: client mirror of the equipped slots and cooldowns, plus the drag hand-off from Grimoire library cards.
- `UI/HUD/MissionTracker.luau`: top-centre banner (mode, wave, timer, Gateway HP, defender and enemy counts) and the bottom XP bar.
- `UI/HUD/Lobby.luau`: centred mode cards and the results card. Gamepad navigation goes through `GamepadNav`. M or D-pad up reopens it.
- `UI/HUD/WorldUI.luau`: themed custom ProximityPrompts and the target health bars.

Removed: `HUDController.luau`, `MissionController.luau` and the Grimoire's gamepad slot label.
Unchanged by request: the Grimoire, Spell Forge and the Spells·P launcher. The launcher only gained `Open()`.
Drag a spell card from the Grimoire library onto any unlocked bar slot to equip it there (it sends `Library/Equip`).

## Begin Mission bug: root cause
In `MissionController`, the `start.Activated` handler did three things in order:
1. `player:SetAttribute("CursorFreed", false)`. On the next frame CameraController re-locked the mouse, which is why the camera went back to cursor-lock.
2. `Camera:SetGameplayMouseLookEnabled(true)`. `Camera` (capital C) was never defined; the parameter was `camera`. Indexing nil threw an error, so the rest of the handler never ran.
3. `awaitServer()` / `request(action)` therefore never ran. The button never showed "STARTING…" and no remote was fired.

The `hub` handler had the same typo. `replay` and the results handler called `camera:Set…` with a colon on a table of plain functions, which passed the table as `value` (always truthy).

Fix: the new Lobby never touches the camera. While the lobby or results are open, `UIModalOpen` makes CameraController keep `MouseBehavior = Default`, and a `Modal` TextButton keeps the cursor free. Buttons use `Activated`. The click shows "Starting…" at once. The server now replies with `{Kind="Ack", Ok, Text}`. Rejections (rate limit, full, wrong state) also get an Ack instead of being dropped silently, and a 5-second client timeout reports a missing reply.

Studio logging (Studio only): `[Mission/client] Begin button activated` → `click → FireServer` → `[Mission/server] request` → `[Mission/server] … → true (Mission starting)` → `server ack`.

## World labels
Approach signs and landmark labels now use `AlwaysOnTop = false` with `MaxDistance` set to 90 or 140 studs, so they no longer stack across the map.

## Verification status
`scripts/check.sh` passes in full. **Not yet verified in Studio**: the Studio MCP was not connected during this session.
To check: play, click Begin Mission in free-cursor mode, watch the Output log chain above, then drag a Grimoire card onto an empty slot.
