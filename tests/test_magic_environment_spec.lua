-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicEnvironmentSpec.luau"))()

local function at(x)
	return { X = x, Y = 0, Z = 0 }
end

-- Wet: a Water mark, swimming, or standing in water.
assert(Spec.isWet({ Marked = true }) and Spec.isWet({ Swimming = true }) and Spec.isWet({ InWater = true }))
assert(not Spec.isWet({}) and not Spec.isWet(nil))

-- Chain: nearest Wet allowed character from the last one struck, 50% of the hit each.
local origin = { Id = "A", Position = at(0) }
local candidates = {
	{ Id = "B", Position = at(6), Wet = true, Allowed = true },
	{ Id = "C", Position = at(12), Wet = true, Allowed = true }, -- 6 from B, 12 from A
	{ Id = "Dry", Position = at(3), Wet = false, Allowed = true },
	{ Id = "Far", Position = at(40), Wet = true, Allowed = true },
}
local opts = { Hit = 40, Radius = 8, Fraction = 0.5, Jumps = 3 }
local hops = Spec.chain(origin, candidates, opts)
assert(#hops == 2, "two Wet targets in reach")
assert(hops[1].Target.Id == "B" and hops[2].Target.Id == "C", "hops from the last one struck")
assert(hops[1].Amount == 20 and hops[2].Amount == 20, "50% of the original hit, not compounding")

-- Nobody is hit twice; the origin is never a hop; at most Jumps hops.
local ring = {}
for i = 1, 6 do
	table.insert(ring, { Id = i, Position = at(i * 2), Wet = true, Allowed = true })
end
hops = Spec.chain(origin, ring, opts)
assert(#hops == 3, "at most 3 jumps")
local seen = {}
for _, hop in hops do
	assert(not seen[hop.Target.Id] and hop.Target.Id ~= "A", "each character once per chain")
	seen[hop.Target.Id] = true
end

-- Not allowed (ally, player outside PvP): skipped.
hops = Spec.chain(origin, { { Id = "Ally", Position = at(2), Wet = true, Allowed = false } }, opts)
assert(#hops == 0, "no hop onto characters the caster may not damage")

-- PvP caps: at most MaxJumps hops onto players and MaxFraction of the hit.
local pvp = { MaxJumps = 1, MaxFraction = 0.3 }
hops = Spec.chain(origin, {
	{ Id = "P1", Position = at(2), Wet = true, Allowed = true, PvP = pvp },
	{ Id = "P2", Position = at(4), Wet = true, Allowed = true, PvP = pvp },
	{ Id = "Npc", Position = at(6), Wet = true, Allowed = true },
}, opts)
assert(#hops == 2 and hops[1].Target.Id == "P1" and hops[2].Target.Id == "Npc", "one player hop in ranked")
assert(hops[1].Amount == 12 and hops[2].Amount == 20, "players take at most 30%")

-- World reactions.
assert(Spec.reactionFor("Fire", { Flammable = true }) == "Burn")
assert(Spec.reactionFor("Ice", { Water = true }) == "Freeze")
assert(Spec.reactionFor("Fire", { Water = true }) == nil and Spec.reactionFor("Lightning", { Flammable = true }) == nil)

-- Ignite cooldown.
assert(Spec.igniteAllowed(nil, 10, 3) and Spec.igniteAllowed(7, 10, 3) and not Spec.igniteAllowed(8, 10, 3))

-- Per-caster limits: the oldest goes first.
local fires = {}
for i = 1, 6 do
	assert(Spec.admit(fires, i, 6) == nil)
end
assert(Spec.admit(fires, 7, 6) == 1 and #fires == 6 and fires[1] == 2, "the 7th fire ends the oldest")
Spec.forget(fires, 4)
assert(#fires == 5 and not table.find(fires, 4))

-- Editor preview line.
assert(Spec.previewLine("Lightning") == "Chains through wet targets")
assert(Spec.previewLine("Fire") == "Sets Flammable things alight")
assert(Spec.previewLine("Ice") == "Freezes water into platforms")
assert(Spec.previewLine("Ice", true) == "Ignores the world" and Spec.previewLine("Wind") == nil)

print("Magic environment spec: wet, chain hops and PvP caps, reactions, ignite cooldown and per-caster limits passed")
