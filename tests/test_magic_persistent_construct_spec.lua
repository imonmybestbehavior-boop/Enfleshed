local spec = assert(loadfile("src/shared/Modules/MagicPersistentConstructSpec.luau"))()

local record = {
	Id = "construct-0001",
	OwnerUserId = 123,
	CreatedAt = 1700000000,
	Position = { 12, -4, 30 },
	RotationDegrees = { 0, 90, 0 },
	Components = {
		{
			Shape = "Block",
			Size = { 4, 3, 1 },
			Offset = { 0, 0, 0 },
			RotationDegrees = { 0, 0, 0 },
		},
	},
	Visual = {
		Color = { 0.7, 0.8, 0.9 },
		MaterialAppearance = "Slate",
		Opacity = 0.85,
		Emission = 0.5,
		ParticleStyle = "None",
	},
}

local profile, ok = spec.decode({ Version = spec.Version, Records = { record } })
assert(ok and #profile.Records == 1, "valid persistent Construct profiles should decode")
profile.Records[1].Position[1] = 999
assert(record.Position[1] == 12, "decoded persistent records should not alias DataStore input")

local invalid = {
	{ field = "Version", value = 2 },
	{ field = "Id", value = "x" },
	{ field = "OwnerUserId", value = -1 },
	{ field = "Position", value = { 0, 0, math.huge } },
	{ field = "RotationDegrees", value = { 0, 181, 0 } },
	{ field = "Components", value = {} },
	{ field = "Visual", value = { Color = { 2, 0, 0 } } },
}
for _, test in ipairs(invalid) do
	local candidate = {}
	for key, value in pairs(record) do
		candidate[key] = value
	end
	candidate[test.field] = test.value
	if test.field == "Version" then
		local _, valid = spec.decode({ Version = test.value, Records = { record } })
		assert(not valid, "invalid profile versions should fail closed")
	else
		assert(not spec.validateRecord(candidate), "invalid record field should be rejected: " .. test.field)
	end
end

local duplicate, duplicateOk = spec.decode({ Version = spec.Version, Records = { record, record } })
assert(not duplicateOk and #duplicate.Records == 0, "duplicate persistent IDs should reject the profile")

local ownerLimited = {}
for index = 1, spec.MaxPerOwner + 1 do
	local item = {}
	for key, value in pairs(record) do
		item[key] = value
	end
	item.Id = "construct-" .. string.format("%04d", index)
	ownerLimited[index] = item
end
local limited, limitedOk = spec.decode({ Version = spec.Version, Records = ownerLimited })
assert(not limitedOk and #limited.Records == 0, "per-owner world limits should reject unsafe saved data")

print("Magic persistent Construct spec: safe versioned profile decoding passed")

local savedProfile
local generation = 0
local memoryStore = {
	GetAsync = function()
		return savedProfile
	end,
	UpdateAsync = function(_, _, transform)
		local nextProfile = transform(savedProfile)
		if nextProfile ~= nil then
			savedProfile = nextProfile
		end
		return savedProfile
	end,
}
local dataStoreService = {
	GetDataStore = function()
		return memoryStore
	end,
}
local httpService = {
	GenerateGUID = function()
		generation = generation + 1
		return "persistent-construct-guid-" .. generation
	end,
}
local replicatedStorage = {
	WaitForChild = function(_, name)
		assert(name == "Shared")
		return {
			Configuration = { MagicLab = "magicLab" },
			Modules = { MagicPersistentConstructSpec = "persistentSpec" },
		}
	end,
}
local services = {
	DataStoreService = dataStoreService,
	HttpService = httpService,
	ReplicatedStorage = replicatedStorage,
}
local mockGame = setmetatable({ GameId = 22, PlaceId = 33 }, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return services[name]
			end
		end
	end,
})
local mockEnvironment = setmetatable({
	game = mockGame,
	require = function(reference)
		if reference == "magicLab" then
			return { PersistentConstructDataStoreName = "test-world" }
		elseif reference == "persistentSpec" then
			return spec
		end
		error("unexpected require: " .. tostring(reference))
	end,
}, { __index = _G })
local function loadStore()
	return assert(loadfile("src/server/Services/MagicPersistentConstructStore.luau", "t", mockEnvironment))()
end

local store = loadStore()
local restored = {}
local ready = store.start(function(saved)
	table.insert(restored, saved)
end)
assert(ready, "valid, available world storage should start writable")
local initialId, addReason = store.add(record)
assert(initialId and addReason == nil, "valid persistent Constructs should be saved")
assert(#savedProfile.Records == 1, "adding a Construct should commit the new world profile")
local removed, removeReason = store.remove(initialId)
assert(
	removed and removeReason == nil and #savedProfile.Records == 0,
	"destroying a Construct should remove its record"
)

for _ = 1, spec.MaxPerOwner do
	local id = store.add(record)
	assert(id, "records below the per-owner limit should save")
end
local overLimit, limitReason = store.add(record)
assert(not overLimit and limitReason, "the per-owner persistent Construct limit should fail closed")

local nextServerStore = loadStore()
local restoredIds = {}
local restoredOk = nextServerStore.start(function(saved)
	table.insert(restoredIds, saved.Id)
end)
assert(restoredOk and #restoredIds == spec.MaxPerOwner, "a new server should restore saved world Constructs")

print("Magic persistent Construct store: save, remove, limits, and startup restoration passed")
