# Phase 0 — Studio & Published-Place Test Checklist

Covers 0.1–0.6 from [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Tick each box; note failures with the Output text.

## Setup

- [ ] `scripts/check.sh` passes on the commit you are testing.
- [ ] Build a fresh place: `rojo build default.project.json -o Enfleshed-Defend-The-Walls.rbxlx` (Studio closed), or use `rojo serve` + the Rojo plugin with Studio open. The checked-in place does **not** auto-sync from `src`.
- [ ] **Game Settings → Security → Enable Studio Access to API Services = ON** (DataStore tests need it; the place must be published to a test experience, never production).
- [ ] Note: `Configuration/DevelopmentSandbox.Enabled = true` makes Studio "unrestricted" (all spells allowed, Studio-only casts). Persistence and progression tests below behave like live only in a **published** server; Studio results for those are indicative.
- [ ] Multi-player tests: **Test → Clients and Servers → Local Server, 2 players**. Server-side commands go in the **server** Command Bar (switch the view to Server).

Useful server Command Bar snippets (replace names):
```lua
local P = game:GetService("Players")
local a, b = P.Player1, P.Player2
-- open-PvP zone for both
a:SetAttribute("PvPZone", "Open"); b:SetAttribute("PvPZone", "Open")
-- clear zone
a:SetAttribute("PvPZone", nil); b:SetAttribute("PvPZone", nil)
-- mutual duel
a:SetAttribute("DuelOpponentUserId", b.UserId); b:SetAttribute("DuelOpponentUserId", a.UserId)
```

---

## 0.1 Central damage & hostile-effect policy

Two players, default state (no PvP attributes):
- [ ] Player 1 melee (light, heavy, combo finisher) on Player 2 → **no damage, no damage number**, swing still plays.
- [ ] Damage spell (projectile, beam, field/aura AoE) through Player 2 → no damage; enemies/dummies in the same AoE **are** damaged.
- [ ] Damage-over-time (e.g. Fire mark DoT) → no ticks on Player 2.
- [ ] Hostile non-damage effects on Player 2 → none apply: Slow, Bind, Force/knockback, Displacement, Control, Reveal, size Transformation, Time dilation < 1, negative attribute change, Elemental marks.
- [ ] Player 1's **summon** never attacks Player 2 or Player 2's summon; it never damages Player 1.
- [ ] Supportive effects still work on Player 2: **Heal, Shield, Restoration, buffs** (positive attribute, time > 1).
- [ ] Enemies still damage both players; players still damage enemies, training dummies; enemies still damage the gate; players cannot damage the gate.

PvP rules (via Command Bar):
- [ ] Only Player 1 in `PvPZone = "Open"` → still no damage.
- [ ] Both `"Open"` → melee, spells, DoT and hostile effects work both ways; summons can hit the other player.
- [ ] Clear zones; set **one-sided** duel → no damage. Make it **mutual** → damage works. Set Player 2's opponent to another UserId → no damage.
- [ ] Player 1 leaves while their summon is alive → summon cannot hurt Player 2.
- [ ] Output shows no errors from `DamageService`, `MagicPayloadExecutors`, `CombatPolicy`.

## 0.2 Session-locked player profile (published place)

Single server:
- [ ] **Existing player with legacy data** (has `EnfleshedInventory_v1` / `EnfleshedMissionProgress_v1` saves): first join shows the same items, XP, Marks, unlocks and spell ranks as before. No "[Profile] migration failed" warning.
- [ ] **Brand-new player**: starter kit (Recruit melee weapon + Magic Focus + 3 Field Dressings); XP/Marks 0.
- [ ] Pick up loot, move/split items, use a consumable, buy an unlock → leave → rejoin: all changes kept.
- [ ] Win a mission → XP/Marks appear immediately in Grimoire Upgrades; rejoin → still there.
- [ ] Wait > 60 s with a change, then force-close the client (not leave cleanly) → rejoin: change kept (autosave).

Locking / duplication race (needs two servers; use **Server list → join a different server**, or two test accounts and `TeleportService` to a new server):
- [ ] Drop an item for a friend (they pick it up), immediately join a **different** server → item is **not** in your inventory; friend still has it (no duplication).
- [ ] Join server B within seconds of leaving server A → profile loads (may take up to ~40 s if A is still saving); no data reverted.
- [ ] Output never shows "[Profile] lost session" during normal play. (It is expected only if a server is forcibly taken over.)

Failure handling:
- [ ] Studio with API access **OFF** → game still plays; inventory works for the session; warning "[Profile] DataStore unavailable" or "temporary inventory"; nothing errors.

## 0.3 Discovery / Locus persistence removed

- [ ] Server starts with no errors mentioning `MagicDiscoveryService`, `Discovery`, `LocusProgression`, `locusStore`.
- [ ] HUD mana/strain bars work; casting spends mana, strain rises and recovers.
- [ ] Die and respawn → mana/strain carry over within the session (no reset to full on death).
- [ ] Leave and rejoin → mana starts at the starting value (not persisted anymore — expected).
- [ ] Special resource (Focus pool, if any spell uses it) still spends and recovers.
- [ ] Magic Focus weapon: **E** switches to it; equipped slot spells cast normally.

## 0.4 Spell names

In the Grimoire / Spell Forge:
- [ ] Typing in the Forge name box stops at **32 characters**; emoji/accents are not cut mid-character.
- [ ] Leading/trailing spaces and line breaks are cleaned on focus loss; an all-spaces name reverts to the previous name.
- [ ] Save New / Update / Equip with a 32-character name succeeds.
- [ ] Library **Rename** with > 32 characters is rejected with "Use a spell name of 1–32 characters…".
- [ ] **Duplicate** of a 30-character name produces "<shortened> (copy)" ≤ 32 characters.
- [ ] **Legacy data:** a library saved with a 33–48-character name loads without "could not be validated", the name shows trimmed to 32, and saving works afterwards (published place, or edit the DataStore entry in a test experience).
- [ ] `TextFilterService` is not used by any screen yet — nothing to test in UI. Optional server Command Bar smoke test (published place only):
  ```lua
  local F = require(game.ServerScriptService.Server.Services.TextFilterService)
  print(F.forBroadcast("Fire Bolt", game.Players.Player1.UserId))
  ```
  prints the filtered text (or `nil` in Studio without filtering — expected).

## 0.5 Tooling

- [ ] `scripts/check.sh` → "All checks passed."
- [ ] `place-backups/` holds the old place files; the Studio test place still opens.

## 0.6 Shutdown during an active mission (published place)

- [ ] Start **Defend the Walls**, play ≥ 2 minutes, then shut the server down (**Creator Dashboard → Servers → Shut down**, or Studio: stop a Local Server test while ACTIVE).
- [ ] Rejoin: XP and Marks increased by roughly the **defeat reward scaled by time played**; **Played +1, Won and Lost unchanged**.
- [ ] Shut down during **PREPARING** (countdown) → no reward (expected).
- [ ] Shut down **after** victory/defeat results → reward granted only once (no double XP).
- [ ] Output during shutdown shows no "[Profile] shutdown hook failed".
- [ ] Mission folder attribute `RunsInterrupted` increments (Workspace mission folder, visible in a Studio server view).

## Regression smoke test (any Studio Play)

- [ ] Full mission start → win and → lose (use `Config.Studio.Accelerated = true` for a 2-minute run; it uses mock progression and never writes DataStores).
- [ ] Practice gate → sandbox; training dummies take damage.
- [ ] Grimoire opens with **P**; create, save, equip, cast a spell with **1–9**.
- [ ] Inventory (**I**), quick slots (**Y/U**), loot pickup (**T**), melee block/parry.

## Report back

For each failure: the step, which player/server, and the Output lines (server and client). Those map directly to the fix list for Phase 0.
