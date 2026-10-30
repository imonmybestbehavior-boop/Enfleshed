# Enfleshed Combat Sandbox

The active project combines a gateway defense mission with a multiplayer fighter sandbox set in a procedurally generated ruined-castle battlefield. It reuses Enfleshed’s magic runtime and Grimoire for authoring, equipping, and testing spells. The earlier city, narrative, quest, and assignment work is archived under [`Shelved Project`](Shelved%20Project/).

## Build and open

From this folder, build the current Studio place with:

```bash
rojo build default.project.json -o Enfleshed-Defend-The-Walls.rbxlx
```

Open the built place in Roblox Studio and press **Play**. The parchment button at the lower-right opens the Grimoire; **P** also toggles it. The server builds the castle map, combatants, spell material sources, and practice targets at startup. The player spawns in the mission staging area. Use the **Practice gate** prompt to enter the original sandbox.

The cosmetic composition pass was built as `place-backups/Enfleshed-Combat-Sandbox-VFX.rbxlx`. See [VFX grammar and verification](docs/spell-vfx-system.md) and [all 65 recipe coverage results](docs/spell-vfx-coverage.md). All 65 curated recipes now pass gameplay validation; live Studio art review is still pending.

The [spell artwork overhaul audit and Milestone 1](docs/spell-vfx-overhaul-milestone-1.md) adds original vector fire artwork, a Windows generation pipeline, provenance checks, and a placeholder report. Studio preflight found that all seven sampled existing Fire textures fail to fetch; the new artwork is still local and awaits upload and live visual review.

## Defend the Walls mission

The current source also includes a replayable gateway defense mission with persistent XP and Mission Marks. Build `default.project.json` to `Enfleshed-Defend-The-Walls.rbxlx`, open it in Studio, and press **BEGIN MISSION** in the staging area. The staging area's **Practice gate** keeps the original combat sandbox accessible. See [mission build, tuning, and test instructions](docs/defend-the-walls.md).

## Main controls

- **P** opens or closes the Grimoire. Use it to configure spell appearance, triggers, combat behavior, and visual effects.
- **1–9** cast spells equipped in matching slots. Live combat starts with four slots; mission XP unlocks six and then nine.
- **E** switches between the melee weapon and the Magic Focus. With melee active, **tap left click** for light attacks, **hold** for a heavy, and **hold right click** to block (block at the right moment to parry).
- **I** opens the inventory; **Y/U** use quick-slot consumables; **T** picks up loot. See [inventory, loot and melee](docs/inventory-and-melee.md).
- **Left Shift** sprints; **Q** dashes.
- **K** opens the Magic Focus profile panel.

The Grimoire includes a spell library, editor, spell preview, and training controls. Its **Upgrades** page shows XP, Marks, spellcraft unlocks, and loadout growth. Saved spells can be edited while locked, but live equipping and casting require the server-owned unlocks and the spell's power rank. Each rank raises that saved spell's allowed mana and complexity budget; edit its effects to use the new room. Studio's development sandbox remains unrestricted.

The library seeds **65 authored Spellcraft Showcase spells** plus three simple **Combat Starters**. New live profiles equip the starters automatically. The showcase examples remain saved, but advanced ones require their unlocks before live use. Existing saved spells and nine slot assignments remain intact; an assignment beyond the player's current slot limit waits for that slot to unlock.

## Project layout

- `src/client` contains the Grimoire, combat controls, camera, and client spell presentation.
- `src/server` contains combat and magic authority, the battlefield generator, training targets, and spell VFX relay.
- `src/shared` contains spell definitions, Grimoire schemas, configs, and reusable modules.
- `assets/ui` contains the Grimoire notebook artwork used by the UI.
- `docs` contains current Grimoire and VFX design notes.
- `Shelved Project` contains the earlier city project, its assets and place files, and other out-of-scope material.

## Checks

Run every engine-independent check (formatting, Rojo build, Python tests, all Luau suites) with:

```bash
scripts/check.sh
```

It exits non-zero if any step fails and prints the tail of each failing step. Use Studio Play mode to verify actual combat, spell casting, Grimoire editing, target damage, and the generated map.

Older place builds and backups are kept in `place-backups/` (ignored by git).
