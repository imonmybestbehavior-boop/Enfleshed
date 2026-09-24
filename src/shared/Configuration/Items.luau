--!strict

-- Small equipment data registry. Profiles intentionally resolve magical actions
-- to registered Magic Runtime spell IDs rather than embedding execution logic.
return table.freeze({
	MagicProfiles = {
		RecruitGeneric = {
			ProfileId = "RecruitGeneric",
			PrimarySpellId = "RecruitMagicBolt",
			AreaSpellId = "RecruitMagicDischarge",
		},
	},
	Items = {
		RecruitMagicWeapon = {
			ItemId = "RecruitMagicWeapon",
			ItemType = "Weapon",
			WeaponType = "MagicFocus",
			MagicProfile = "RecruitGeneric",
			Visual = {
				Name = "Recruit Magic Focus",
				Size = Vector3.new(0.55, 0.55, 3),
				Color = Color3.fromRGB(135, 220, 255),
				Material = Enum.Material.Neon,
				Offset = CFrame.new(0, -0.65, -1.2) * CFrame.Angles(math.rad(90), 0, 0),
			},
		},
		RecruitMeleeWeapon = {
			ItemId = "RecruitMeleeWeapon",
			ItemType = "Weapon",
			WeaponType = "Melee",
			Visual = {
				Name = "Recruit Melee Trainer",
				Size = Vector3.new(0.3, 0.45, 3.2),
				Color = Color3.fromRGB(185, 185, 190),
				Material = Enum.Material.Metal,
				Offset = CFrame.new(0, -0.75, -1.3) * CFrame.Angles(math.rad(90), 0, 0),
			},
		},
	},
})
