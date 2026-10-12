local specialResourceSpec = assert(loadfile("src/shared/Modules/MagicSpecialResourceSpec.luau"))()
local profileEnvironment = setmetatable({
	script = { Parent = { MagicSpecialResourceSpec = "specialResourceSpec" } },
	require = function(reference)
		assert(reference == "specialResourceSpec")
		return specialResourceSpec
	end,
}, { __index = _G })
local Profile = assert(loadfile("src/shared/Modules/MagicLocusProfile.luau", "t", profileEnvironment))()
local fallback = 180
local capacity = 300
local maxStrain = 1000000
local specialDefinitions = {
	Focus = { Label = "Focus", Capacity = 100, Starting = 100, RecoveryPerSecond = 4, Attribute = "MagicFocus" },
}

local resources, safe = Profile.decode(nil, fallback, capacity, maxStrain, specialDefinitions)
assert(safe and resources.Mana == fallback and resources.Strain == 0 and resources.SpecialResources.Focus == 100)

resources, safe =
	Profile.decode({ Version = 1, Mana = 72.5, Strain = 36 }, fallback, capacity, maxStrain, specialDefinitions)
assert(safe and resources.Mana == 72.5 and resources.Strain == 36)
assert(
	resources.SpecialResources.Focus == 100,
	"Legacy Mana/Strain profiles should gain the configured special defaults"
)
local state = {
	Capacity = capacity,
	Mana = resources.Mana,
	Strain = resources.Strain,
	SpecialResources = { Focus = 34 },
}
local encoded = assert(Profile.encode(state, maxStrain, specialDefinitions))
assert(encoded.Version == 2 and encoded.Mana == 72.5 and encoded.Strain == 36 and encoded.SpecialResources.Focus == 34)
resources = Profile.decode(encoded, fallback, capacity, maxStrain, specialDefinitions)
assert(resources.Mana == 72.5 and resources.Strain == 36, "Encoded resources should decode without drift")
assert(resources.SpecialResources.Focus == 34, "Named resource values should persist")
local expandedDefinitions = {
	Focus = specialDefinitions.Focus,
	Soul = { Label = "Soul", Capacity = 50, Starting = 25, RecoveryPerSecond = 0, Attribute = "MagicSoul" },
}
resources, safe = Profile.decode(encoded, fallback, capacity, maxStrain, expandedDefinitions)
assert(
	safe and resources.SpecialResources.Focus == 34 and resources.SpecialResources.Soul == 25,
	"Newly configured pools should merge their defaults into existing version-2 profiles"
)

local invalidProfiles = {
	{ Version = 3, Mana = 100, Strain = 0 },
	{ Version = 1, Mana = -1, Strain = 0 },
	{ Version = 1, Mana = capacity + 1, Strain = 0 },
	{ Version = 1, Mana = 100, Strain = -1 },
	{ Version = 1, Mana = 100, Strain = maxStrain + 1 },
	{ Version = 1, Mana = 100, Strain = 0, FutureValue = true },
	{ Version = 2, Mana = 100, Strain = 0 },
	{ Version = 2, Mana = 100, Strain = 0, SpecialResources = { Focus = 101 } },
	{ Version = 2, Mana = 100, Strain = 0, SpecialResources = { Unknown = 10 } },
}
for _, invalid in ipairs(invalidProfiles) do
	local loaded, accepted = Profile.decode(invalid, fallback, capacity, maxStrain, specialDefinitions)
	assert(
		not accepted and loaded.Mana == fallback,
		"Invalid profiles must use fallback resources and remain unwritable"
	)
end

assert(
	not Profile.encode(
		{ Capacity = capacity, Mana = capacity + 1, Strain = 0, SpecialResources = { Focus = 100 } },
		maxStrain,
		specialDefinitions
	)
)
print("Locus profile: canonical fallback, resource round-trip, and unsafe-profile protection passed")
