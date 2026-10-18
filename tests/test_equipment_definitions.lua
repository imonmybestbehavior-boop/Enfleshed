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
assert(items.Items.RecruitMagicWeapon.HandsOccupied == 1)
-- The Focus names its own spells; there is no profile picker.
assert(items.Items.RecruitMagicWeapon.PrimarySpellId == "RecruitMagicBolt")
assert(items.Items.RecruitMagicWeapon.AreaSpellId == "RecruitMagicDischarge")
assert(items.MagicProfiles == nil, "Magic Focus profiles were removed")
assert(items.Items.RecruitMagicWeapon.Visual.MuzzleOffset)
assert(items.Items.RecruitMeleeWeapon.WeaponType == "Melee")
assert(items.Items.RecruitMeleeWeapon.HandsOccupied == 1)
print("PASS: recruit equipment maps the Magic Focus to its own registered spells")
