local Profile = assert(loadfile("src/shared/Modules/MagicLibraryProfile.luau"))()
local Slots = assert(loadfile("src/shared/Modules/MagicSlots.luau"))()

local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = clone(item)
	end
	return result
end

local function validate(definition)
	return type(definition) == "table" and type(definition.Name) == "string" and definition.Valid == true
end

local function hydrate(definition, slot, id)
	definition.SpellId = id
	definition.Development = true
	return definition
end

local function dehydrate(definition, slot, id)
	definition.SpellId = id
	definition.Development = nil
	return definition
end

local definitions, safe = Profile.decode(nil, Slots.Count, Slots.id, validate, clone, hydrate)
assert(safe and next(definitions) == nil, "A missing profile should produce an empty writable library")

local summonDefinition = {
	Name = "Respawning Party",
	Valid = true,
	Triggers = {
		OnCast = {
			{
				Payloads = {
					{
						Kind = "Summon",
						Archetype = "Wisp",
						Role = "Guardian",
						Count = 2,
						LifetimeMode = "UntilCommanded",
						RespawnPolicy = "PersistUntilDismissed",
						SpellSlot = "4",
					},
				},
			},
		},
	},
}
local profile = {
	Version = Profile.Version,
	Slots = {
		["1"] = { Name = "Ember", Valid = true },
		["9"] = summonDefinition,
	},
}
definitions, safe = Profile.decode(profile, Slots.Count, Slots.id, validate, clone, hydrate)
assert(safe and definitions[1].SpellId == Slots.id(1) and definitions[9].Development == true)
local savedSummon = definitions[9].Triggers.OnCast[1].Payloads[1]
assert(savedSummon.RespawnPolicy == "PersistUntilDismissed" and savedSummon.SpellSlot == "4")

local encoded = assert(Profile.encode(definitions, Slots.Count, Slots.id, validate, clone, dehydrate))
assert(encoded.Version == Profile.Version and encoded.Slots["1"].Development == nil)
assert(encoded.Slots["9"].SpellId == Slots.id(9))
assert(encoded.Slots["9"].Triggers.OnCast[1].Payloads[1].RespawnPolicy == "PersistUntilDismissed")

for _, invalid in ipairs({
	{ Version = 2, Slots = {} },
	{ Version = Profile.Version, Slots = {}, FutureField = true },
	{ Version = Profile.Version, Slots = { ["10"] = { Name = "Overflow", Valid = true } } },
	{ Version = Profile.Version, Slots = { ["2"] = { Name = "Broken", Valid = false } } },
}) do
	local _, accepted = Profile.decode(invalid, Slots.Count, Slots.id, validate, clone, hydrate)
	assert(not accepted, "Unsafe profiles must not be accepted for writes")
end

print("Magic library profile: versioning, stable slots, hydration, and unsafe-profile protection passed")
