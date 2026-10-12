local config = assert(loadfile("src/shared/Configuration/WorldEvents.luau"))()
local rules = assert(loadfile("src/server/Services/WorldEventRules.luau"))()
local vector = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
local plan = assert(
	loadfile("src/shared/Configuration/PhaseATopology.luau", "t", setmetatable({ Vector3 = vector }, { __index = _G }))
)()
local city = assert(loadfile(
	"src/shared/Configuration/CityLife.luau",
	"t",
	setmetatable(
		{ Vector3 = vector, Color3 = {
			fromRGB = function(...)
				return { ... }
			end,
		} },
		{ __index = _G }
	)
))()
assert(#city.Presets == 3 and city.NPCs.MaxPopulation >= #city.NPCs.Roster)
assert(city.NPCs.PathStartsPerSecond > 0 and city.NPCs.RepathSeconds >= 1)
assert(plan.Nodes[city.Opening.Node])
for _, npc in ipairs(city.NPCs.Roster) do
	for _, node in ipairs(npc.Nodes) do
		assert(plan.Nodes[node], node)
	end
end
for _, node in pairs(config.Anchors) do
	assert(plan.Nodes[node], node)
end
local expected = { LocalAttack = true, TravelIncident = true, Breach = true, RampartAssault = true }
for kind, definition in pairs(config.Definitions) do
	assert(expected[kind], kind)
	expected[kind] = nil
	assert(definition.CountRange[1] > 0 and definition.CountRange[1] <= definition.CountRange[2])
	assert(definition.CountRange[2] <= config.EnemyCap and definition.Reward > 0 and definition.Duration > 0)
	for _, node in ipairs(definition.Route or {}) do
		assert(plan.Nodes[node], node)
	end
end
assert(next(expected) == nil)
assert(not config.Development.Enabled and not city.DevelopmentSpells)
assert(config.GlobalCooldown >= 120 and config.LocationCooldown >= config.GlobalCooldown)
assert(rules.available(10, 10, 0, 2, 3, 3, 6))
assert(not rules.available(9, 10, 0, 2, 0, 1, 6), "cooldown")
assert(not rules.available(10, 10, 2, 2, 0, 1, 6), "event cap")
assert(not rules.available(10, 10, 0, 2, 4, 3, 6), "reserved enemy cap")
local ledger = {}
assert(not rules.claim(ledger, 1, true, config), "bystanders receive no reward")
rules.credit(ledger, 1, config.ContributionDamage - 1, 0, 0)
assert(not rules.claim(ledger, 1, true, config), "subthreshold damage")
rules.credit(ledger, 1, 1, 0, 0)
assert(not rules.claim(ledger, 1, false, config), "failed events never pay")
assert(rules.claim(ledger, 1, true, config))
assert(not rules.claim(ledger, 1, true, config), "exactly once")
rules.credit(ledger, 2, 0, config.EscortSeconds, 0)
assert(not rules.claim(ledger, 2, true, config), "stationary escort proximity is insufficient")
rules.credit(ledger, 2, 0, 0, config.EscortDistance)
assert(rules.claim(ledger, 2, true, config))
assert(not rules.claim({}, 1, true, config), "credit does not leak across event instances")
assert(rules.outcome(1, true, false, false, false) == nil)
assert(rules.outcome(0, true, false, false, false) == "Completed")
assert(rules.outcome(0, false, true, true, false) == "Failed", "protected death wins")
assert(rules.outcome(0, true, false, true, false) == nil, "escort must arrive")
assert(rules.outcome(1, true, true, true, false) == nil, "escort threats must be defeated")
assert(rules.outcome(0, true, true, true, false) == "Completed")
assert(rules.outcome(1, true, false, false, true) == "Failed", "timeout")
print(
	"PASS: world event caps/cooldowns, contribution isolation, exactly-once rewards, escort outcomes and semantic references"
)

local seconds, distance = rules.escortStep(10, 8, true, true, 1)
assert(seconds == 1 and distance == 8)
assert(rules.escortStep(10, 0, true, true, 1) == 0, "stationary player")
assert(rules.escortStep(0, 10, true, true, 1) == 0, "stationary carrier")
assert(rules.escortStep(10, 80, true, true, 1) == 0, "teleport")
assert(rules.escortStep(10, 10, false, true, 1) == 0, "must follow across samples")
