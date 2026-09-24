-- Run from the repository root with: lua tests/test_equipment_definitions.lua
-- Data-only registry check; Studio covers character welds and input behavior.
local frame = {}
setmetatable(frame, {
	__mul = function()
		return frame
	end,
})
local items = assert(loadfile("src/shared/Configuration/Items.luau", "t", {
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
assert(items.Items.RecruitMagicWeapon.MagicProfile == "RecruitGeneric")
assert(items.Items.RecruitMeleeWeapon.WeaponType == "Melee")
assert(items.MagicProfiles.RecruitGeneric.PrimarySpellId == "RecruitMagicBolt")
assert(items.MagicProfiles.RecruitGeneric.AreaSpellId == "RecruitMagicDischarge")
print("PASS: recruit equipment maps items to generic Magic Runtime spell profiles")
