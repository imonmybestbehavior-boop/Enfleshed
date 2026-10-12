local Spec = assert(loadfile("src/shared/Modules/MagicSpellIdentitySpec.luau"))()

local tags, reason = Spec.parse("  summon, support; summon, marked  ")
assert(tags and #tags == 3 and tags[1] == "summon" and tags[2] == "support" and tags[3] == "marked")
assert(Spec.validateTags(tags))
assert(Spec.encode({ "Summon", "Support" }) == "|summon|support|")

local valid, invalidReason = Spec.validateTags({ "alpha", "ALPHA" })
assert(not valid and string.find(invalidReason, "unique"))
valid, invalidReason = Spec.validateTags({ string.rep("x", Spec.MaxTagLength + 1) })
assert(not valid and string.find(invalidReason, "characters"))
valid, invalidReason = Spec.validateTags({ "control\ncharacter" })
assert(not valid and string.find(invalidReason, "characters"))
local tooMany = {}
for index = 1, Spec.MaxTags + 1 do
	tooMany[index] = "tag" .. index
end
valid, invalidReason = Spec.validateTags(tooMany)
assert(not valid and string.find(invalidReason, "at most"))

print("PASS: spell identity tags normalize and validate within bounded unique labels")
