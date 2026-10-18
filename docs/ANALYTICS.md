# Analytics Events

All events go through `src/server/Services/TelemetryService.luau` (Roblox **AnalyticsService**); every call is pcall-guarded and never affects gameplay. View them in **Creator Dashboard → Analytics** (Onboarding Funnel, Progression/Funnels, Economy, Custom Events). Data appears only from **published, live servers**, not Studio.

Keep names stable — renaming an event or field splits the dashboard history.

## Onboarding funnel (once per player)
| # | Step | Fired from |
|---|---|---|
| 1 | Joined | TelemetryService (PlayerAdded) |
| 2 | Spawned | ActionRouter (character ready) |
| 3 | OpenedGrimoire | MagicLabService `Load` |
| 4 | CastSpell | MagicService successful cast |
| 5 | SavedSpell | MagicLabService `SaveNew` success |
| 6 | EnteredMission | DefendTheWallsService `enter` |
| 7 | FinishedMission | DefendTheWallsService `finish` |
| 8 | BoughtUnlock | MagicLabService unlock purchase |

Drop-off between steps is the first-session retention signal (Phase 2 exit criteria).

## Progression (missions)
Path `DefendTheWalls`, level = difficulty tier (currently always 1).
- **Start** when the run goes ACTIVE (or on late join).
- **Complete** on victory; **Fail** on defeat or `Interrupted` (server shutdown). Custom fields: outcome, `PhaseN` reached.

## Economy
| Currency | Flow | Transaction | SKU |
|---|---|---|---|
| Marks, XP | Source | Gameplay | `DefendTheWalls` (mission rewards, incl. interrupted) |
| Marks | Sink | Gameplay | `Unlock:<Id>` or `Rank:RankN` |
Ending balance is the saved profile value after the change.

## Custom events
| Event | Value | Field 1 | Field 2 | Field 3 |
|---|---|---|---|---|
| `SpellUsage` | casts this session | Form | Element | first effect Kind |
| `SessionEnd` | session seconds | `Left` / `Shutdown` | `Mission` / `Hub` | — |

`SpellUsage` is aggregated per player session (≤ 20 shapes, overflow under `Other`) and sent on leave/shutdown to stay within Roblox's event limits.

## Adding an event
Add a function to `TelemetryService` (inside `safe(...)`), call it from the gameplay service, document it here; `tests/test_telemetry_wiring.py` enforces that no other file calls AnalyticsService directly.
