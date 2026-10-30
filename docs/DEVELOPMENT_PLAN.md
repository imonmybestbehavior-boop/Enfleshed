# Enfleshed — Development Plan

Source: [GAME_STATUS_AUDIT.md](GAME_STATUS_AUDIT.md) (2026-10-14) plus the developer decisions in its section 11.
Ordering rule: **safety and data integrity → foundations other work depends on → the first-hour experience → content breadth → PvP → monetization → live ops.** Within each phase, items are listed in the order to build them. Sizes: S ≈ days, M ≈ 1–2 weeks, L ≈ 3–4 weeks, XL ≈ 5+ weeks (one developer).

---

## Phase 0 — Stop the bleeding (1–2 weeks)
_Progress 2026-10-14: 0.1 done (`CombatPolicy`, gates damage and hostile payloads); 0.2 done (`PlayerProfileService` + `ProfileSession`, migrates legacy Inventory/MissionProgress stores). 0.3 done (discovery system, Locus persistence and Locus practice progression removed; the per-session Locus mana/strain pool and the Magic Focus weapon stay because casting runs on them). 0.4 done (32-character UTF-8 spell names enforced in SpellSpec, old names repaired on load, `TextFilterService` ready for cross-player display). 0.5 done (`scripts/check.sh` runs everything; all suites green, 67 previously unrun Lua tests now run; backups in `place-backups/`). 0.6 done (interrupted missions pay a defeat-tier participation reward before the profile flush; counted as played, not lost). **Phase 0 code complete**; all items need a Studio/published play-test._

Ship nothing else until these land; each one gets cheaper the earlier it's fixed.

| # | Task | Size | Why first |
|---|---|---|---|
| 0.1 ✅ | **Central damage policy** in `DamageService.apply`: player→player damage is blocked unless both are in a PvP zone or an accepted duel. Melee (`CombatService`) and every spell path go through it | S | Griefing in co-op today. It also becomes the hook for the PvP arena later |
| 0.2 ✅ | **One player profile with session locking** (ProfileStore or a hand-rolled UpdateAsync lock). Merge Inventory + MissionProgression (+ a future cosmetics/titles section) into one document; keep the spell library as its own store with a size cap | M | Fixes the item-duplication race; every later system (unlocks, cosmetics, entitlements) saves here |
| 0.3 ✅ | **Remove discovery/Locus/foci** systems and DataStores (`MagicDiscoveryService`, `MagicLab.ProgressionEnabled`, Locus persistence) | S | Dropped by design; removes dead surface before refactors |
| 0.4 ✅ | **Spell text limits**: name ≤32 chars, tags already capped; TextService filtering helper ready for cross-player display | S | Required before sharing; prevents DataStore bloat now |
| 0.5 ✅ | **CI + green tests**: fix `test_grimoire_workflow_wiring.py` and `test_place_references.py`; script running rojo build + StyLua + all Luau runners; move `.rbxlx` backups out of the repo root | S | Safety net for the large refactors in Phase 1 |
| 0.6 ✅ | **Shutdown handling**: `BindToClose` grants participation rewards for an active mission | S | Prevents reward loss on server updates |

**Exit:** no known High-severity exploit; one profile per player with a lock; CI green.

---

## Phase 1 — Foundations (4–6 weeks)
_Progress: 1.1 done 2026-10-14 (`FeatureFlagService`, see [FEATURE_FLAGS.md](FEATURE_FLAGS.md)); needs a published-place test of a live override. 1.2 done (`TelemetryService`, see [ANALYTICS.md](ANALYTICS.md)); events only appear from live servers. 1.3 done (`ModeRunner`, see [GAME_MODES.md](GAME_MODES.md)); Defend the Walls needs a Studio regression play-through. 1.4 done (cost-weighted, frame-time-aware load budget; see [PERFORMANCE_BUDGET.md](PERFORMANCE_BUDGET.md)); tune `MaxLoad` from profiling scenario 3. 1.5 done (PvE/PvPOpen/PvPRanked caps on every payload and damage hit; see [PVP_STAT_CAPS.md](PVP_STAT_CAPS.md)). 1.6 foundation done (UI kit + gamepad bindings/navigation, see [CONTROLS.md](CONTROLS.md)); full controller-first layout of the Grimoire and existing HUDs moves to the Phase 2 screen work; needs a gamepad test in Studio. 1.7 first pass done: five stateless modules extracted (`MagicWorldQuery`, `MagicConstructBuilder`, `GrimoireGeometryPreview`, `GrimoireConditionTreeEditor`, `ForgePreviewPanel`), ~1,500 lines out of the three files. The remaining large blocks share heavy mutable state and should be split during their Phase 2 rework with Studio testing: `MagicService` heartbeat loop (~1,000 lines) and `execute` (~760), `MagicLabController.rebuild` (~2,800, replaced by the Spell Forge redesign), `GuidedSpellForge` inspector (~400)._
Systems that every later feature plugs into. Building content before these means rebuilding it.

| # | Task | Size | Unblocks |
|---|---|---|---|
| 1.1 ✅ | **Remote config / feature flags**: server-read flags (DataStore + MemoryStore cache) with per-feature `{enabled, earlyAccessOnly, publicReleaseAt}` and kill switches for individual spell forms/payloads | M | Early access, hotfixing balance, staged rollouts |
| 1.2 ✅ | **Analytics**: AnalyticsService funnel (join → tutorial steps → first mission → first unlock), economy events (Marks earned/spent), spell usage (form/payload counts), mission outcomes | M | Every tuning decision after this |
| 1.3 ✅ | **Mode framework**: extract the round state machine, participants, rewards, and results UI from `DefendTheWallsService` into a reusable mode base; Defend the Walls becomes mode #1 | L | 3–5 modes, PvP arena, endless/difficulty variants |
| 1.4 ✅ | **Server magic budget**: per-server caps on live projectiles/summons/constructs/status effects; reject casts when saturated | M | Safe multiplayer, PvP, stress targets |
| 1.5 ✅ | **Spell stat-cap profiles**: one clamp layer at cast/payload execution in `MagicService` (damage, CC duration, counts, mana/complexity) with named profiles: `PvE`, `PvPOpen`, `PvPRanked` | M | PvP balance; also a PvE hotfix tool |
| 1.6 ✅ (foundation) | **UI foundation**: shared component library + theme (extend `SpellForgeComponents`/`SpellForgeTheme`), responsive layout + UIScale + safe areas, **gamepad navigation** (selection groups, focus handling), input-glyph switching (keyboard/gamepad/touch), localization-ready string tables | L | Console requirement; every new screen is built once, correctly |
| 1.7 ✅ (first pass) | **Split god files**: break up `MagicService` (5.2k), `MagicLabController` (5.5k), `GuidedSpellForge` (2.7k) along the seams the new UI/cap layers need | L | Velocity for everything after |

**Exit:** a flag can disable any spell form live; funnel data visible; Defend the Walls runs on the mode framework; the Grimoire is fully usable with a controller.

---

## Phase 2 — Vertical slice: the first hour (6–8 weeks)
The player's first session, polished end to end. This is the build to playtest with strangers.

| # | Task | Size |
|---|---|---|
| 2.1 | **Progressive Forge unlocks** (replaces the 4 buckets in `SpellProgressionRules`): a sequence of ~20–30 small unlocks (first projectile → damage → element → trigger → second form …), each with a short guided lesson in the Forge. This *is* the spell-creation tutorial | L |
| 2.2 | **Combat tutorial / safe first fight**: movement, melee, block/parry, casting the first spell, against training dummies | M |
| 2.3 | **Front-end flow**: loading screen, main menu/hub UI, pause, confirmation dialogs, toasts/notifications | M |
| 2.4 | **Settings** (persisted in the profile): audio sliders, sensitivity/camera, keybind + gamepad remap, graphics quality, reduced screen shake, text size | M |
| 2.5 | **Audio pass**: music (hub, combat, victory/defeat), ambience, UI sounds, melee hit and impact SFX, enemy barks | M (content) |
| 2.6 | **Game feel**: melee hitstop, hit flash, camera shake tied to the reduced-motion setting, damage numbers batched per frame (also fixes perf P3) | S |
| 2.7 | **Results → upgrade in-flow**: the results screen shows XP/Marks and the next unlock with a direct button | S |
| 2.8 | **Network trims**: mission snapshot sends the profile only on change; timer on an unreliable remote (perf P2) | S |
| 2.9 | **Downed / revive** in co-op | M |

**Exit:** 5/5 unaided playtesters reach their first self-made spell and first mission win in under 30 minutes; 60 FPS on a mid PC, 30 FPS on a console dev kit; tutorial funnel drop-off measured.

---

## Phase 3 — PvE content and economy (alpha, 8–12 weeks)

| # | Task | Size |
|---|---|---|
| 3.1 | **Economy design**: model XP/Marks faucets and sinks for a 20–50 h curve (spreadsheet/sim), replace the placeholder costs, attach rewards to levels | M |
| 3.2 | **Enemies**: 6–8 new archetypes (ranged, shielded, healer, summoner, burrower, flyer…) using the existing telegraph state machine | XL |
| 3.3 | **Bosses**: first 2 bosses with phases and telegraphed mechanics | L |
| 3.4 | **Defend the Walls variants**: 3 difficulty tiers + endless; a 2nd map | L |
| 3.5 | **Mode #2** on the mode framework (design TBD — e.g. escort, survival arena, or extraction) | XL |
| 3.6 | **Gear expansion**: 12 → ~40 items using the existing affix/rarity system | M |
| 3.7 | **Achievements + dailies/weeklies** | M |
| 3.8 | **Leaderboards** (best score, endless wave reached) | S |

**Exit:** 20+ hours of goals in the economy model; 4-player stress test within budget (server < 8 ms/frame).

---

## Phase 4 — Social and PvP (beta, 8–10 weeks)

| # | Task | Size |
|---|---|---|
| 4.1 | **Spell sharing**: publish/copy spells between players; filtered names; server re-validation + re-pricing on import; report button + moderation queue | L |
| 4.2 | **PvP arena place/area**: open-PvP zones and duel zones using the Phase 0 damage policy + duel request/accept UI | L |
| 4.3 | **PvP stat caps** tuned using the Phase 1.5 profiles; spell-usage analytics in PvP | M |
| 4.4 | **Cosmetics & titles inventory**: separate from gear; nameplate title display from a fixed list; equip UI | M |
| 4.5 | **PvP rewards**: titles and unique cosmetics; anti-farming (no repeat-opponent duel rewards) | S |
| 4.6 | **Party/invite + friends join** | M |
| 4.7 | **Mode #3** | XL |

**Exit:** duels and open zones live in a closed test; no exploit reports for spell sharing; caps hold under top-damage spell builds.

---

## Phase 5 — Monetization and soft launch (4–6 weeks)

| # | Task | Size |
|---|---|---|
| 5.1 | **ProcessReceipt** with an idempotent receipt ledger in the profile; GamePass checks | M |
| 5.2 | **Early-access program**: purchase grants testing access to flagged features before `publicReleaseAt` (Phase 1.1); excluded from ranked; in-game feedback form | M |
| 5.3 | **Cosmetic store**: spell VFX palettes, Grimoire covers, weapon skins, extra library slots, private servers | L |
| 5.4 | **Release pipeline**: staging place, version tag + changelog, rollback procedure, server-shutdown messaging | S |
| 5.5 | **Platform compliance**: experience questionnaire, thumbnails/icon/description, voice/chat settings | S |
| 5.6 | **Mobile pass** (touch layouts for every screen, low-end memory/FPS) | L |

**Exit:** D1 ≥ 25%, D7 ≥ 8%, purchase flow verified with zero duplicate grants, data-error rate < 0.1%.

---

## Phase 6 — Launch and live ops (ongoing)
- **Ranked PvP**: matchmaking (MemoryStore queues, reserved servers), ratings, seasons, seasonal titles/cosmetics.
- Modes #4–5, more bosses, seasonal events.
- An economy dashboard built from the Phase 1.2 analytics; balance hotfixes through Phase 1.1 flags.

---

## Dependency summary
```
0.1 damage policy ─────────────┬─> 4.2 PvP arena ──> 6 ranked
0.2 profile + lock ─┬─> 2.4 settings, 3.7 achievements, 4.4 cosmetics, 5.1 receipts
1.1 flags ──────────┴─> 5.2 early access, live hotfixes
1.3 mode framework ───> 3.4 variants, 3.5/4.7 modes, 4.2 arena
1.5 stat caps ────────> 4.3 PvP caps
1.6 UI foundation ────> every Phase 2+ screen, console support
2.1 progressive unlocks ─> 3.1 economy (unlock costs)
```

## Decisions still needed (don't block Phases 0–2)
- Design of modes #2–#5.
- Economy targets (session length, hours to unlock everything) for 3.1.
- Whether ranked uses separate stat-cap tiers per rank band.
