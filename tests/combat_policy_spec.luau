local Policy = require("../src/shared/Modules/CombatPolicy")

local function model(attributes)
	return {
		GetAttribute = function(_, name)
			return attributes[name]
		end,
	}
end

local function player(userId, attributes)
	local p = model(attributes)
	p.UserId = userId
	return p
end

local alice, bob = player(1, {}), player(2, {})
local aliceChar, bobChar = model({}), model({})
local enemy = model({})
local aliceSummon = model({ MagicSummonOwnerUserId = 1 })
local bobSummon = model({ MagicSummonOwnerUserId = 2 })
local orphanSummon = model({ MagicSummonOwnerUserId = 99 })
local byChar = { [aliceChar] = alice, [bobChar] = bob }
local byId = { [1] = alice, [2] = bob }
local players = {
	GetPlayerFromCharacter = function(_, m)
		return byChar[m]
	end,
	GetPlayerByUserId = function(_, id)
		return byId[id]
	end,
}
local function can(a, t)
	return Policy.canDamage(a, t, players)
end

-- Default (co-op / hub): no player-owned damage between players.
assert(can(aliceChar, enemy), "players damage enemies")
assert(can(enemy, aliceChar), "enemies damage players")
assert(can(aliceSummon, enemy), "summons damage enemies")
assert(not can(aliceChar, bobChar), "no friendly fire by default")
assert(not can(aliceSummon, bobChar), "summons cannot hit other players")
assert(not can(aliceChar, bobSummon), "players cannot hit other players' summons")
assert(not can(aliceSummon, aliceChar), "summons never hit their owner")
assert(not can(orphanSummon, bobChar), "summons of departed players stay non-hostile")
assert(can(nil, aliceChar) and can(aliceChar, nil), "missing models are not player-owned")

-- Open PvP zone: both players must be inside.
local function set(p, attributes)
	p.GetAttribute = function(_, name)
		return attributes[name]
	end
end
set(alice, { PvPZone = "Open" })
assert(not can(aliceChar, bobChar), "one player in the zone is not enough")
set(bob, { PvPZone = "Open" })
assert(can(aliceChar, bobChar) and can(bobSummon, aliceChar), "both in open zone allows PvP")

-- Ranked zones: both players must be in the same zone kind.
set(alice, { PvPZone = "Ranked" })
set(bob, { PvPZone = "Ranked" })
assert(can(aliceChar, bobChar), "both in a ranked zone allows PvP")
set(bob, { PvPZone = "Open" })
assert(not can(aliceChar, bobChar), "ranked and open zones do not mix")

-- Duels: must be mutual.
set(alice, { DuelOpponentUserId = 2 })
set(bob, {})
assert(not can(aliceChar, bobChar), "one-sided duel is rejected")
set(bob, { DuelOpponentUserId = 1 })
assert(can(aliceChar, bobChar) and can(bobChar, aliceSummon), "accepted duel allows damage")
set(bob, { DuelOpponentUserId = 3 })
assert(not can(aliceChar, bobChar), "duel with someone else does not count")

print("Combat policy: co-op safety, open PvP zones and mutual duels passed")

-- Hostile non-damage payload classification.
local hostile = Policy.isHostilePayload
for _, kind in
	{
		"Slow",
		"Bind",
		"Control",
		"Force",
		"Displacement",
		"Reveal",
		"Transformation",
		"DamageOverTime",
		"ElementalMark",
		"ConsumeElementalMark",
	}
do
	assert(hostile({ Kind = kind }), kind .. " is hostile")
end
for _, kind in { "Heal", "Shield", "Restoration", "Enhancement", "Summon", "Damage" } do
	assert(not hostile({ Kind = kind }), kind .. " is not gated as a hostile effect")
end
assert(hostile({ Kind = "ModifyAttribute", Amount = -20 }), "negative attribute change is hostile")
assert(not hostile({ Kind = "ModifyAttribute", Amount = 15 }), "buffs are not hostile")
assert(hostile({ Kind = "TimeDilation", Rate = 0.5 }), "slowing time is hostile")
assert(not hostile({ Kind = "TimeDilation", Rate = 1.5 }), "hastening time is not hostile")
assert(not hostile(nil), "malformed payloads are not classified")

print("Combat policy: hostile payload classification passed")
