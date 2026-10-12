local spec = assert(loadfile("src/shared/Modules/MagicElementalMarkSpec.luau"))()

local casterA = {}
local casterB = {}
local effects = {}
local first = {
	Kind = "ElementalMark",
	Element = "Fire",
	Stacks = 2,
	Caster = casterA,
	SpellId = "fire-a",
	ExpiresAt = 5,
	Remaining = 5,
	LastUpdateAt = 0,
}
assert(spec.apply(effects, first, 5, 0, 8), "first mark should apply")
local second = {
	Kind = "ElementalMark",
	Element = "Fire",
	Stacks = 2,
	Caster = casterB,
	SpellId = "fire-b",
	ExpiresAt = 8,
	Remaining = 8,
	LastUpdateAt = 0,
}
assert(spec.apply(effects, second, 5, 0, 8), "a second source can add marks before the cap")
assert(spec.stackCount(effects, "Fire", 0) == 4)
local refresh = {
	Kind = "ElementalMark",
	Element = "Fire",
	Stacks = 4,
	Caster = casterA,
	SpellId = "fire-a",
	ExpiresAt = 12,
	Remaining = 12,
	LastUpdateAt = 0,
}
assert(spec.apply(effects, refresh, 5, 0, 8), "reapplication should refresh an existing source")
assert(first.Stacks == 3, "mark stacks should cap across all sources")
assert(first.ExpiresAt == 12 and first.Remaining == 12, "reapplication should refresh duration")
assert(spec.stackCount(effects, "Fire", 0) == 5)
assert(spec.encode(effects, 0) == "|fire|")

local ice = {
	Kind = "ElementalMark",
	Element = "Ice",
	Stacks = 1,
	Caster = casterA,
	SpellId = "ice-a",
	ExpiresAt = 9,
	Remaining = 9,
	LastUpdateAt = 0,
}
assert(spec.apply(effects, ice, 5, 0, 8))
assert(spec.encode(effects, 0) == "|fire|ice|", "encoded tags should be normalized and sorted")
assert(spec.encode(effects, 10) == "|fire|", "expired marks should not appear in status queries")

assert(spec.consume(effects, "Fire", 2, 0) == 2)
assert(spec.stackCount(effects, "Fire", 0) == 3, "consumption should remove soonest-expiring stacks first")
assert(spec.consume(effects, "Fire", 9, 0) == 3, "consumption should not exceed available stacks")
assert(spec.encode(effects, 0) == "|ice|")

local full = {}
for key, value in pairs(ice) do
	full[1] = full[1] or {}
	full[1][key] = value
end
local overflow = {
	Kind = "ElementalMark",
	Element = "Ice",
	Stacks = 1,
	Caster = casterB,
	SpellId = "ice-b",
	ExpiresAt = 9,
	Remaining = 9,
	LastUpdateAt = 0,
}
assert(not spec.apply(full, overflow, 1, 0, 8), "marks should reject additions above the per-element cap")

print("Magic elemental marks: cap, refresh, exact tag encoding, expiry, and consumption passed")

local config = assert(loadfile("src/shared/Configuration/MagicLab.luau"))()
local environment = setmetatable({
	script = { Parent = { Parent = { Configuration = { MagicLab = "limits" } } } },
}, { __index = _G })
environment.require = function(reference)
	assert(reference == "limits")
	return config
end
local interactions = assert(loadfile("src/shared/Modules/MagicElementalInteractionSpec.luau", "t", environment))()
local damageRules = assert(loadfile("src/shared/Modules/MagicDamageRules.luau"))()
for _, element in ipairs(damageRules.Elements) do
	if element ~= "Neutral" then
		assert(#interactions.effectsFor(element, 4) > 0, element .. " needs a configured starter interaction")
	end
end
assert(#interactions.effectsFor("Neutral", 4) == 0, "Neutral should not imply a gameplay effect")
local fireEffects = interactions.effectsFor("Fire", 4)
assert(fireEffects[1].Duration == 4, "mark-bound interactions should use the authored mark duration")
assert(fireEffects[1].RequiresElementalMark == "Fire", "Burn damage should stop if the Fire mark is removed")
fireEffects[1].Duration = 99
assert(interactions.effectsFor("Fire", 4)[1].Duration == 4, "profile reads should not mutate the shared definitions")
local waterEffects = interactions.effectsFor("Water", 4)
assert(waterEffects[1].Element == "Fire", "Water should be able to extinguish Fire marks")
print("Magic elemental interactions: every selectable element has a profile; Neutral stays inert")
