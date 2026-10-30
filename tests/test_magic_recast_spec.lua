-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicRecastSpec.luau"))()

local step = { { Payloads = {} } }

-- Allowed recasts.
assert(Spec.allowed({ Triggers = {} }) == 0, "no OnRecast steps: no recast")
assert(Spec.allowed({ Triggers = { OnRecast = step }, Casting = {} }) == 1, "default 1")
assert(Spec.allowed({ Triggers = { OnRecast = step }, Casting = { MaxRecasts = 3 } }) == 3)
assert(Spec.allowed({ Triggers = { OnRecast = {} }, Casting = { MaxRecasts = 3 } }) == 0, "empty steps")

-- canRecast: count, interval, ended.
local record = { RecastsUsed = 0 }
assert(Spec.canRecast(record, 2, 10, 0.2))
assert(Spec.use(record, 10) == 1)
local ok, reason = Spec.canRecast(record, 2, 10.1, 0.2)
assert(not ok and reason == "Recast too soon")
assert(Spec.canRecast(record, 2, 10.3, 0.2))
assert(Spec.use(record, 10.3) == 2, "stage 2")
ok, reason = Spec.canRecast(record, 2, 11, 0.2)
assert(not ok and reason == "No recasts left")
assert(not Spec.canRecast({ Finished = true }, 3, 0, 0.2), "ended effects take no recast")

-- pick: newest eligible record of this player's spell; channels excluded.
local player, other = {}, {}
local old = { Player = player, SpellId = "a", StartedAt = 1 }
local new = { Player = player, SpellId = "a", StartedAt = 2 }
local spent = { Player = player, SpellId = "a", StartedAt = 3, RecastsUsed = 1 }
local channel = { Player = player, SpellId = "a", StartedAt = 4, IsChannel = true }
local records = {
	old,
	new,
	spent,
	channel,
	{ Player = other, SpellId = "a", StartedAt = 9 },
	{ Player = player, SpellId = "b", StartedAt = 9 },
}
assert(Spec.pick(records, player, "a", 1, 5, 0.2) == new, "newest record with a recast left")
assert(Spec.pick(records, player, "c", 1, 5, 0.2) == nil, "no active effect: cast normally")
local runtime = { Player = player, Definition = { SpellId = "d" }, StartedAt = 1 }
local child = { Player = player, Definition = { SpellId = "dSpawned" }, StartedAt = 2 }
assert(Spec.pick({ runtime, child }, player, "d", 1, 5, 0.2) == runtime, "runtime records: Definition.SpellId")
print("Magic recast spec: allowed count, interval, ended effects and newest-record pick passed")
