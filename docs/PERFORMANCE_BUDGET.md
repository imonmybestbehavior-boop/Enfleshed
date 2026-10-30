# Server Magic Budget & Profiling

## Layers (all server-side)
| Limit | Value | Where |
|---|---|---|
| Active spells per player / server | 8 / 64 | `MagicLab.MaxActivePerPlayer/Global`, `MagicService.hasCapacity` |
| **Cost-weighted load** | 120 units, shrinking to 60 when slow | `Modules/MagicLoadBudget.luau`, checked in `MagicService.execute` |
| Summons per player / server | 3 / 24 | `Configuration/MagicSummons.luau` |
| Periodic effects per caster / server | 32 / 256 | `MagicLab.MaxPeriodicEffects*` |
| Status/control targets | 256 | `MagicLab.MaxEffectTargets` |
| Operations per event cascade | 256 | `MagicLab.MaxOperationsPerCascade` |
| Persistent constructs per owner / world | 8 / 128 | `MagicPersistentConstructSpec` |

**Load budget:** each active spell weighs `1 + Complexity/10` (simple ≈ 1, rank-3 maximum ≈ 3.6). A new player cast is refused with "Too much magic is active here" when it would exceed the budget. The budget is the full 120 while the smoothed server frame time is ≤ 25 ms, falling linearly to 60 at ≥ 50 ms. Effects already in flight (splits, chains, summons' own attacks) are never cut off; they remain bounded by the count caps above. Tune in `MagicLoadBudget.luau`; individual spell parts can also be disabled live with the kill switches in [FEATURE_FLAGS.md](FEATURE_FLAGS.md).

## Live counters
`MagicService` writes these Workspace attributes 4×/s (read them in a Studio **server** view, or Developer Console → Server):
`MagicLoad`, `MagicLoadLimit`, `MagicActiveCount`, `ServerFrameMs`.

## Profiling plan
Run each with the MicroProfiler (Ctrl+F6, server view) and Developer Console → Memory/Network; record `ServerFrameMs`, peak `MagicLoad`, server memory, and network receive per client.
1. Idle hub, 4 players.
2. Defend the Walls phase 5 (`LAST STAND`), 4 players, starter spells only.
3. Same, every player spamming the heaviest `GeneratedSpellStress` spell they can equip.
4. Soak: 3 consecutive missions + Grimoire use (~35 min); watch memory and instance count for growth.
5. Mobile emulator (low-end profile) with the Grimoire open.

Targets: `ServerFrameMs` ≤ 20 average / ≤ 33 peak in scenario 3; client 60 FPS mid PC, 30 FPS low-end mobile; client memory < 700 MB on mobile. If scenario 3 regularly pins `MagicLoad` at the limit with a healthy frame time, raise `MaxLoad`; if frame time is unhealthy before the limit, lower it.
