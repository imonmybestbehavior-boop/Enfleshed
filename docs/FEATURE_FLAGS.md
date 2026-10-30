# Feature Flags & Kill Switches

Server: `src/server/Services/FeatureFlagService.luau` · rules: `src/shared/Modules/FeatureFlagSpec.luau` · defaults: `src/shared/Configuration/FeatureFlags.luau`.

## How it works
- Defaults ship in code. A live **override document** in DataStore `EnfleshedFeatureFlags_v1`, key `live`, is merged over them.
- Every server re-reads the override every 60 s (`RefreshSeconds`), so a change is live everywhere within ~1 minute, no publish.
- Invalid entries in the override are ignored; unknown feature names are **off**. A bad override can only fall back to defaults.
- Merged flags are replicated to clients as JSON on `ReplicatedStorage.Shared.FeatureFlags` (attribute `FeatureFlags`) for UI. The server stays authoritative.

## Features (each one is enforced in code)
| Flag | Enforced in | Off means |
|---|---|---|
| `DefendTheWalls` | `DefendTheWallsService` (Start/Join/Replay) | new runs refused with a notice; a run in progress finishes |
| `LootDrops` | `InventoryService.dropLoot` | enemies drop nothing |

`PublicReleaseAt` (unix seconds): before that time only players with the server-owned `EarlyAccess` attribute get the feature (Phase 5 grants it). `Enabled = false` beats early access.

## Spell kill switches
`DisabledForms`, `DisabledPayloads`, `DisabledBehaviors` (names as in `MagicSchema`, e.g. `"Construct"`, `"Control"`, `"Homing"`, `"Explode"`).
Checked when a spell is **cast** (players and summons) and when it is **equipped**; players see "… is temporarily disabled". Saved spells are untouched and work again when the switch is removed.

## Changing flags (ops)
In Studio, open a place in the **target experience** with API Services enabled; in the **server** Command Bar:
```lua
local Flags = require(game.ServerScriptService.Server.Services.FeatureFlagService)
Flags.publish({
	Features = { DefendTheWalls = { Enabled = true }, NewMode = { Enabled = true, PublicReleaseAt = 1767225600 } },
	DisabledPayloads = { "Control" },
})
```
`publish` replaces the whole override document: include everything you want overridden. `Flags.publish({})` restores defaults.
Adding a new flag: add it to `FeatureFlags.luau` **and** add the `Flags.enabled("Name", player)` check in the same change.
