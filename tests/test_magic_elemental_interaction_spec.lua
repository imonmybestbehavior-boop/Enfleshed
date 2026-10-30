-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local limits = assert(loadfile("src/shared/Configuration/MagicLab.luau"))()
local Spec = assert(loadfile(
	"src/shared/Modules/MagicElementalInteractionSpec.luau",
	"t",
	setmetatable({
		script = { Parent = { Parent = { Configuration = { MagicLab = "limits" } } } },
		require = function()
			return limits
		end,
	}, { __index = getfenv() })
))()

local function canonical(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, tostring(key) .. "=" .. canonical(value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- Starter effects are exactly the pre-Phase-7 per-element arrays.
local before = {
	Fire = {
		{ Kind = "DamageOverTime", Amount = 2, Interval = 1, Duration = 4, RequiresElementalMark = "Fire" },
		{ Kind = "Slow", Multiplier = 0.9, Duration = 4, RequiresElementalMark = "Fire" },
		{
			Kind = "ModifyAttribute",
			Attribute = "MagicStrength",
			Amount = -20,
			Duration = 4,
			RequiresElementalMark = "Fire",
		},
	},
	Water = {
		{ Kind = "ConsumeElementalMark", Element = "Fire", Stacks = 5 },
		{ Kind = "Slow", Multiplier = 0.95, Duration = 4, RequiresElementalMark = "Water" },
	},
	Ice = { { Kind = "Slow", Multiplier = 0.8, Duration = 4, RequiresElementalMark = "Ice" } },
	Lightning = {
		{ Kind = "DamageOverTime", Amount = 1, Interval = 0.5, Duration = 4, RequiresElementalMark = "Lightning" },
		{ Kind = "Slow", Multiplier = 0.9, Duration = 4, RequiresElementalMark = "Lightning" },
	},
	Earth = { { Kind = "Slow", Multiplier = 0.85, Duration = 4, RequiresElementalMark = "Earth" } },
	Wind = { { Kind = "Force", Magnitude = 8, Upward = 0 } },
	Poison = {
		{ Kind = "DamageOverTime", Amount = 1.5, Interval = 1, Duration = 4, RequiresElementalMark = "Poison" },
		{ Kind = "Slow", Multiplier = 0.95, Duration = 4, RequiresElementalMark = "Poison" },
	},
}
for element, effects in pairs(before) do
	assert(canonical(Spec.effectsFor(element, 4)) == canonical(effects), element .. " starter effects unchanged")
end
assert(#Spec.effectsFor("Neutral", 4) == 0, "Neutral has no starter")
local copy = Spec.effectsFor("Fire", 4)
copy[1].Amount = 999
assert(Spec.effectsFor("Fire", 4)[1].Amount == 2, "copies, never the shared config")

-- Reactions: Existing state on the target + Incoming element (or Force).
local function on(...)
	local states = {}
	for _, name in ipairs({ ... }) do
		states[name] = true
	end
	return function(name)
		return states[name] == true
	end
end
local function reaction(incoming, has)
	local found = Spec.findReaction(incoming, has)
	return found and found.Name
end
assert(reaction("Lightning", on("Water")) == "Conduct")
assert(reaction("Wind", on("Fire")) == "Firestorm")
assert(reaction("Ice", on("Water")) == "Freeze")
assert(reaction("Earth", on("Frozen")) == "Shatter")
assert(reaction("Force", on("Frozen")) == "Shatter", "a Force hit shatters too")
assert(reaction("Poison", on("Fire")) == "ToxicSmoke")
assert(reaction("Water", on("Earth")) == "Mire")
assert(reaction("Lightning", on()) == nil, "nothing to react with")
assert(reaction("Water", on("Fire")) == nil, "Water on Burning is the starter (douse), not a reaction")
assert(reaction("Force", on("Water")) == nil, "Force only reacts with Frozen")
assert(reaction("Earth", on("Frozen", "Water")) == "Shatter", "first match in list order")
for _, name in ipairs({ "Conduct", "Firestorm", "Freeze", "Shatter", "ToxicSmoke", "Mire" }) do
	assert(table.find(Spec.reactionNames(), name), name .. " is configured")
end
local freeze = Spec.findReaction("Ice", on("Water"))
assert(Spec.spellId(freeze) == "Reaction:Freeze", "Frozen is recognised by this SpellId")
local effects = Spec.reactionEffects(freeze, 4)
assert(effects[1].Kind == "Stun" and effects[1].Duration == 1)
effects[1].Duration = 99
assert(Spec.reactionEffects(freeze, 4)[1].Duration == 1, "reaction effects are copies")

-- Status.Reaction condition: the name only within ReactionMemory seconds.
assert(limits.ReactionMemory == 5)
assert(Spec.recentReaction("Freeze", 100, 103) == "Freeze")
assert(Spec.recentReaction("Freeze", 100, 105) == "Freeze", "inclusive edge")
assert(Spec.recentReaction("Freeze", 100, 105.1) == "", "forgotten after 5 s")
assert(Spec.recentReaction(nil, 100, 101) == "")
assert(Spec.recentReaction("Freeze", nil, 101) == "")
assert(Spec.recentReaction("Freeze", 100, 99) == "", "a timestamp from the future is ignored")
print("Magic elemental interaction spec: starters unchanged, reaction matching and memory passed")
