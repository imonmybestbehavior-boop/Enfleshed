-- Run from the repository root with: lua tests/test_equipment_definitions.lua
-- Data-only registry check; Studio covers character welds and input behavior.
local frame = {}
setmetatable(frame, {
	__mul = function()
		return frame
	end,
})
local profiles = assert(loadfile("src/shared/Configuration/MagicProfiles.luau", "t", {
	table = setmetatable({
		freeze = function(value)
			return value
		end,
	}, { __index = table }),
}))()
local items = assert(loadfile("src/shared/Configuration/Items.luau", "t", {
	script = { Parent = { MagicProfiles = "profiles" } },
	require = function(reference)
		assert(reference == "profiles")
		return profiles
	end,
	table = setmetatable({
		freeze = function(value)
			return value
		end,
	}, { __index = table }),
	Vector3 = {
		new = function()
			return {}
		end,
	},
	Color3 = {
		fromRGB = function()
			return {}
		end,
	},
	CFrame = {
		new = function()
			return frame
		end,
		Angles = function()
			return frame
		end,
	},
	Enum = { Material = { Neon = "Neon", Metal = "Metal" } },
	math = math,
}))()

assert(items.Items.RecruitMagicWeapon.ItemType == "Weapon")
assert(items.Items.RecruitMagicWeapon.HandsOccupied == 1)
assert(items.Items.RecruitMagicWeapon.MagicProfile == "RecruitGeneric")
assert(items.Items.RecruitMagicWeapon.Visual.MuzzleOffset)
assert(items.Items.RecruitMeleeWeapon.WeaponType == "Melee")
assert(items.Items.RecruitMeleeWeapon.HandsOccupied == 1)
assert(items.MagicProfiles.RecruitGeneric.PrimarySpellId == "RecruitMagicBolt")
assert(items.MagicProfiles.RecruitGeneric.AreaSpellId == "RecruitMagicDischarge")
assert(
	items.MagicProfiles.Fire.PrimarySpellId == "Fireball" and items.MagicProfiles.Fire.AreaSpellId == "BurningGround"
)
assert(
	items.MagicProfiles.Earth.PrimarySpellId == "StoneShot" and items.MagicProfiles.Earth.AreaSpellId == "StoneRaise"
)
assert(items.MagicProfiles.BodyEnhancement.PrimarySpellId == "BodyBurst")
assert(items.MagicProfiles.BodyEnhancement.AreaSpellId == "BodyReinforcement")
for id, profile in pairs(items.MagicProfiles) do
	assert(profile.ProfileId == id, "profile key and ProfileId must match")
	if id ~= "RecruitGeneric" then
		local requirements = profile.Unlock and profile.Unlock.Requirements
		assert(
			type(requirements) == "table" and #requirements > 0,
			"awakened profiles should declare discovery requirements"
		)
		for _, requirement in ipairs(requirements) do
			assert(
				requirement.Counter == "Expression" and type(requirement.Key) == "string" and requirement.Count == 5,
				"awakened profiles should use bounded expression-cast requirements"
			)
		end
	end
end
print("PASS: recruit equipment maps items to generic Magic Runtime spell profiles")
