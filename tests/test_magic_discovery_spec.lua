local env = {}
setmetatable(env, { __index = _G })
env.Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255, _color = true }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b, _color = true }
	end,
}
local spec = assert(loadfile("src/shared/Modules/MagicDiscoverySpec.luau", "t", env))()
local testConfig = assert(loadfile("src/shared/Configuration/MagicLab.luau"))()
assert(testConfig.ProgressionEnabled == false, "test place must disable discovery progression")
local magicProfiles = assert(loadfile("src/shared/Configuration/MagicProfiles.luau", "t", {
	table = setmetatable({
		freeze = function(value)
			return value
		end,
	}, { __index = table }),
}))()

local profile, valid = spec.decode(nil)
assert(valid and spec.progress(profile).Palettes.Origin and not spec.progress(profile).Palettes.Ember)
assert(spec.progress(profile).Shapes.Sphere and not spec.progress(profile).Shapes.Block)
local initialExpressions = spec.progress(profile).Expressions
assert(initialExpressions.Earth and initialExpressions.Fire and initialExpressions.BodyEnhancement)
assert(not initialExpressions.Water and not initialExpressions.Lightning and not initialExpressions.Force)
assert(
	not initialExpressions.Unawakened,
	"legacy expressions should be preserved on prior slots, not offered to new ones"
)
local unrestricted = spec.progress(profile, testConfig.ProgressionEnabled)
assert(unrestricted.TotalCasts == 0, "test mode should not expose saved cast progression")
for _, unlocked in pairs(unrestricted.Palettes) do
	assert(unlocked, "test mode should make every visual palette available")
end
for _, unlocked in pairs(unrestricted.Shapes) do
	assert(unlocked, "test mode should make every projectile shape available")
end
for _, unlocked in pairs(unrestricted.Expressions) do
	assert(unlocked, "test mode should make every source expression available")
end
for _, count in pairs(unrestricted.Principles) do
	assert(count == 0, "test mode should not expose progression counters")
end

for _ = 1, 9 do
	profile = spec.recordCast(profile, "Energy", "Manipulation")
end
for _ = 1, 4 do
	profile = spec.recordCast(profile, "Matter", "Projectile")
end
local progress = spec.progress(profile)
assert(not progress.Palettes.Ember and not progress.Shapes.Crystal, "milestones should not unlock early")
profile = spec.recordCast(profile, "Matter", "Projectile")
progress = spec.progress(profile)
assert(progress.Shapes.Crystal, "five projectiles should unlock Crystal")
profile = spec.recordCast(profile, "Energy", "Manipulation")
progress = spec.progress(profile)
assert(progress.Palettes.Ember and progress.TotalCasts == 15, "ten casts of a Principle should unlock its palette")

for _ = 1, 3 do
	profile = spec.recordCast(profile, "Matter", "Construct")
end
assert(spec.progress(profile).Shapes.Block, "three Constructs should unlock Block")
for _ = 1, 5 do
	profile = spec.recordCast(profile, "Energy", "Wave")
end
assert(spec.progress(profile).Shapes.Wedge, "five Waves should unlock Wedge")

local expressionProfile = spec.decode(nil)
for _ = 1, 4 do
	expressionProfile = spec.recordCast(expressionProfile, "Energy", "Projectile", "Fire")
end
assert(
	not spec.progress(expressionProfile).Expressions.Lightning,
	"Lightning should remain locked before five Fire casts"
)
expressionProfile = spec.recordCast(expressionProfile, "Energy", "Projectile", "Fire")
assert(spec.progress(expressionProfile).Expressions.Lightning, "five Fire casts should unlock Lightning")
assert(not spec.progress(expressionProfile).Expressions.Force, "Force should require Lightning casts")
for _ = 1, 5 do
	expressionProfile = spec.recordCast(expressionProfile, "Energy", "Projectile", "Lightning")
end
assert(spec.progress(expressionProfile).Expressions.Force, "five Lightning casts should unlock Force")
for _ = 1, 5 do
	expressionProfile = spec.recordCast(expressionProfile, "Matter", "Projectile", "Earth")
end
assert(spec.progress(expressionProfile).Expressions.Water, "five Earth casts should unlock Water")
expressionProfile = spec.recordCast(expressionProfile, "Matter", "Projectile", "Fire")
assert(
	expressionProfile.Expressions.Fire == 5,
	"expression casts with a mismatched Principle must not advance expression discovery"
)

local legacy, migrated = spec.decode({
	Version = 1,
	TotalCasts = 7,
	Principles = { Energy = 7, Matter = 4 },
	Forms = { Projectile = 7 },
})
assert(migrated and legacy.Version == spec.Version, "V1 profiles should migrate to the current version")
assert(
	legacy.Expressions.Fire == 7 and legacy.Expressions.Earth == 4,
	"V1 casts should map to their default expressions"
)
assert(spec.progress(legacy).Expressions.Lightning, "migrated default-expression progress should unlock descendants")
assert(not spec.progress(legacy).Expressions.Water, "migration should not invent untracked expression casts")

local awakening = spec.decode(nil)
for _ = 1, 5 do
	awakening = spec.recordCast(awakening, "Energy", "Projectile", "Fire")
	awakening = spec.recordCast(awakening, "Matter", "Projectile", "Earth")
end
for profileId in pairs(magicProfiles) do
	assert(
		spec.awakeningProfileUnlocked(awakening, profileId, magicProfiles),
		"Active test Focus profiles must not carry cast-count unlock requirements"
	)
end
local selected, accepted = spec.selectAwakeningProfile(awakening, "Fire", magicProfiles)
assert(accepted and selected.AwakeningProfileId == "Fire", "Every active test profile should be selectable")
selected, accepted = spec.selectAwakeningProfile(selected, "Earth", magicProfiles)
assert(
	accepted and selected.AwakeningProfileId == "Earth",
	"Players should be able to switch to another unlocked profile"
)
selected, accepted = spec.selectAwakeningProfile(selected, "Fire", magicProfiles)
assert(accepted and selected.AwakeningProfileId == "Fire", "Players should be able to switch back after awakening")
local selectedRoundTrip = assert(spec.encode(selected))
local savedSelection = assert(spec.decode(selectedRoundTrip))
assert(savedSelection.AwakeningProfileId == "Fire", "The latest profile choice should persist through encoding")
local lockedProfiles = {
	LockedForSpecTest = {
		Unlock = {
			Requirements = {
				{ Counter = "Expression", Key = "BodyEnhancement", Count = 6, Description = "Six Body spells" },
			},
		},
	},
}
local unchanged, locked = spec.selectAwakeningProfile(selected, "LockedForSpecTest", lockedProfiles)
assert(
	not locked and unchanged.AwakeningProfileId == "Fire",
	"The dormant unlock evaluator should still reject unmet test fixtures"
)
local testSelected, testAccepted = spec.selectAwakeningProfile(spec.decode(nil), "Fire", magicProfiles, false)
assert(
	testAccepted and testSelected.AwakeningProfileId == "Fire",
	"Test mode should allow profile selection immediately"
)
for profileId in pairs(magicProfiles) do
	local available, accepted = spec.selectAwakeningProfile(spec.decode(nil), profileId, magicProfiles, false)
	assert(
		accepted and available.AwakeningProfileId == profileId,
		"Every test Focus profile should be immediately selectable"
	)
end
local _, unknown = spec.selectAwakeningProfile(selected, "UnknownProfile", magicProfiles)
assert(not unknown, "Unknown profiles must be rejected")

local compoundProfiles = {
	Compound = {
		Unlock = {
			Requirements = {
				{ Counter = "Expression", Key = "Fire", Count = 2, Description = "Cast 2 Fire spells" },
				{ Counter = "Form", Key = "Field", Count = 1, Description = "Cast a Field spell" },
				{ Counter = "Principle", Key = "Matter", Count = 1, Description = "Cast a Matter spell" },
				{ Counter = "TotalCasts", Count = 4, Description = "Cast 4 spells total" },
			},
		},
	},
}
local compound = spec.decode(nil)
compound = spec.recordCast(compound, "Energy", "Projectile", "Fire")
compound = spec.recordCast(compound, "Energy", "Projectile", "Fire")
compound = spec.recordCast(compound, "Energy", "Aura", "Fire")
local compoundUnlocked, compoundReason = spec.awakeningProfileUnlockStatus(compound, "Compound", compoundProfiles)
assert(not compoundUnlocked and compoundReason:find("Field", 1, true), "Every unlock requirement must be met")
compound = spec.recordCast(compound, "Matter", "Field", "Earth")
compoundUnlocked = spec.awakeningProfileUnlocked(compound, "Compound", compoundProfiles)
assert(compoundUnlocked, "Expression, Form, Principle, and total-cast requirements should compose")
local malformedProfiles = {
	Malformed = { Unlock = { Requirements = { { Counter = "SpellId", Key = "Fireball", Count = 1 } } } },
}
assert(
	not spec.awakeningProfileUnlocked(compound, "Malformed", malformedProfiles),
	"Unknown unlock counter families must fail closed"
)
local legacyUnlock = {
	Legacy = { Unlock = { Expression = "Earth", Count = 1 } },
}
assert(spec.awakeningProfileUnlocked(compound, "Legacy", legacyUnlock), "Legacy single-expression unlocks remain valid")

local encodedLegacy = assert(spec.encode(legacy))
assert(encodedLegacy.Version == spec.Version, "encoding a V1 profile should write the migrated schema")
assert(
	encodedLegacy.AwakeningProfileId == "RecruitGeneric",
	"legacy progress should migrate to the default focus profile"
)
local versionTwo, migratedTwo = spec.decode({
	Version = 2,
	TotalCasts = 1,
	Principles = { Energy = 1 },
	Forms = { Projectile = 1 },
	Expressions = { Fire = 1 },
})
assert(
	migratedTwo and versionTwo.AwakeningProfileId == "RecruitGeneric",
	"V2 profiles should migrate to the default focus profile"
)
local _, unknownExpression = spec.decode({
	Version = spec.Version,
	TotalCasts = 0,
	Principles = {},
	Forms = {},
	Expressions = { NotAnExpression = 1 },
	AwakeningProfileId = "RecruitGeneric",
})
assert(not unknownExpression, "unknown expression counters must be rejected")

local _, malformed = spec.decode({
	Version = spec.Version,
	TotalCasts = -1,
	Principles = {},
	Forms = {},
	Expressions = {},
	AwakeningProfileId = "RecruitGeneric",
})
assert(not malformed, "negative counters should be rejected")
local _, unknown = spec.decode({
	Version = spec.Version,
	TotalCasts = 0,
	Principles = {},
	Forms = {},
	Expressions = {},
	AwakeningProfileId = "RecruitGeneric",
	Extra = true,
})
assert(not unknown, "unknown profile data should be rejected")
local _, invalidAwakening = spec.decode({
	Version = spec.Version,
	TotalCasts = 0,
	Principles = {},
	Forms = {},
	Expressions = {},
	AwakeningProfileId = "../unsafe",
})
assert(not invalidAwakening, "invalid awakening selection data should be rejected")

print("Magic discovery spec checks passed")
