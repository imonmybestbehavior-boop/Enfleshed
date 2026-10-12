local Summary = assert(loadfile("src/shared/Modules/GrimoireSummary.luau"))()
local schema = {
	Forms = { Beam = { Label = "Beam" } },
	TargetingModes = { AimDirection = { Label = "Aim forward" } },
	EventLabels = { OnCast = "On cast" },
	Payloads = { Damage = { Label = "Damage", Fields = { { Key = "Amount", Label = "Damage amount" } } } },
}
local d = {
	Name = "My beam",
	Form = "Beam",
	Source = { Principle = "Energy", Expression = "Fire" },
	Element = "Fire",
	Casting = { Mode = "Instant", Cooldown = 0.6, CastTime = 0.2 },
	Lifetime = { Mode = "Instantaneous" },
	Targeting = "AimDirection",
	TargetRules = { Range = 90, MaxTargets = 2, RequiresLineOfSight = true },
	Triggers = { OnCast = { { Payloads = { { Kind = "Damage", Amount = 20 } } } } },
	Cost = {},
	Conditions = {},
	LocusRequirements = {},
	EnvironmentRequirements = {},
}
local called = 0
local spec = {
	estimate = function(value)
		assert(value == d)
		called = called + 1
		return { ManaDemand = 17, Strain = 7, Complexity = 3 }
	end,
	validate = function()
		return true
	end,
}
local text, ok = Summary.describe(d, schema, spec)
assert(
	ok
		and called == 1
		and text:find("Damage amount 20", 1, true)
		and text:find("17 mana", 1, true)
		and text:find("cooldown 0.6s", 1, true)
)
assert(not text:find("Principle", 1, true) and not text:find("Expression", 1, true))
assert(text:find("Walls can block", 1, true) and d.Triggers.OnCast[1].Payloads[1].Amount == 20)
d.Triggers = {}
spec.validate = function()
	return false, "Choose an effect"
end
text, ok = Summary.describe(d, schema, spec)
assert(not ok and text:find("No effects yet", 1, true) and text:find("Choose an effect", 1, true))
print("Grimoire summary: authoritative estimates, numerical effects, timing, targeting and incomplete guidance passed")
