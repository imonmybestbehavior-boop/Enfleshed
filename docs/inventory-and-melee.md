# Inventory, loot and melee

## Controls

| Input | Action |
| --- | --- |
| **Left click** | Light attack, on press. The chain length depends on the weapon. |
| **R** | Heavy attack. Ends the light chain and staggers harder. |
| **Right click (hold)** | Block while melee is active. Blocking halves walk speed and stops sprint, and can cancel a swing's recovery (not its wind-up or hit). Block reduces any frontal damage, spells included. The first moment of a block is a **parry** against melee hits only: it negates the hit, staggers the attacker, and your next swing within 2 s deals 1.5x damage. |
| **E** | Switch between the Main Hand weapon and the Magic Focus. |
| **I** | Open or close the inventory (Kit & Pack). |
| **Y / U** | Use quick slot 1 / 2 (consumables). |
| **T** | Pick up a nearby loot drop. |

In the inventory you can drag items between slots, right-click for Equip, Unequip, Use, Split and Drop, shift-click to split a stack, and drag an item outside the panel to drop it.

## Data

- `src/shared/Configuration/Items.luau`: item definitions (Weapon, Armor, Consumable, Material).
- `src/shared/Configuration/MeleeProfiles.luau`: archetype timing, hitboxes, block and parry values (Sword, Greatsword, Dagger, Spear), the parry bonus, and placeholder feel (swing/hit sounds, hitstop, hit flash, optional swing animation IDs per archetype).
- `src/shared/Configuration/Loot.luau`: rarities (Common, Uncommon, Rare, Relic), affixes, and drop tables keyed by enemy `MissionRole`.
- `src/shared/Modules/ItemRules.luau`: rolling, stat resolution, tooltips, and save cleaning (pure functions).
- `src/shared/Modules/InventoryModel.luau`: bag/equip/quick container rules (pure functions).

## Authority

`InventoryService` owns every inventory on the server and persists it to the `EnfleshedInventory_v1` DataStore. If a saved inventory cannot be read, the session uses a temporary inventory and never overwrites the save. Clients send move, split, use and drop requests over `InventoryRemote` and receive full snapshots back. `EquipmentService` reads the equipped items. `CombatService` resolves the active weapon's loadout for every light, heavy and block request. `MeleeDefenseService` applies block and parry inside `DamageService`, followed by armour reduction.

Every killed Enfleshed rolls its role's drop table. Drops are reserved for the killer for 20 seconds and despawn after 120 seconds. In the Studio sandbox, new profiles also receive one rolled copy of each melee weapon for testing.

## Tests

```bash
python3 scripts/run_luau_inventory_tests.py /path/to/luau
```
