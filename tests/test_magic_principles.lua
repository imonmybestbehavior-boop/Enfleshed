-- Run from the repository root with: lua tests/test_magic_principles.lua
local principles = assert(loadfile("src/shared/Modules/MagicPrincipleSpec.luau"))()

assert(#principles.Order == 6, "All canonical Principles must exist in the shared registry")
for _, id in ipairs({ "Matter", "Energy", "Body", "Soul", "Space", "Time" }) do
	assert(principles.Definitions[id], id .. " must be represented")
end

assert(principles.expressionMatches("Matter", "Earth"))
assert(principles.expressionMatches("Matter", "Water"))
assert(principles.expressionMatches("Energy", "Fire"))
assert(principles.expressionMatches("Energy", "Lightning"))
assert(principles.expressionMatches("Energy", "Force"), "Force is a canonical Energy expression")
assert(principles.expressionMatches("Energy", "Unawakened"), "Legacy Energy expression remains loadable")
assert(principles.expressionMatches("Body", "BodyEnhancement"))
assert(principles.expressionMatches("Space", "SpatialFold"))
assert(principles.expressionMatches("Soul", "Spirit"))
assert(principles.expressionMatches("Time", "TemporalShift"))
assert(not principles.expressionMatches("Matter", "Fire"), "Expressions cannot cross Principle families")
assert(not principles.expressionMatches("Soul", "Earth"), "Unsupported Principles cannot borrow expressions")
assert(not principles.expressionMatches("Time", "Spirit"), "Expressions cannot cross Principle families")

assert(principles.supportsForm("Matter", "Manipulation"))
assert(not principles.supportsForm("Energy", "Manipulation"))
for _, form in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement" }) do
	assert(principles.supportsForm("Body", form), "Body should support the existing humanoid-target Form " .. form)
end
assert(not principles.supportsForm("Body", "Manipulation"), "Body should not expose world-material Manipulation")
assert(principles.supportsForm("Space", "Projectile"))
for _, form in ipairs({ "Construct", "SelfEnhancement" }) do
	assert(principles.supportsForm("Space", form), "Space proximity effects should work through " .. form)
end
assert(principles.Definitions.Space.Status == "PARTIAL")
assert(principles.supportsForm("Soul", "Projectile"))
for _, form in ipairs({ "Construct", "SelfEnhancement" }) do
	assert(principles.supportsForm("Soul", form), "Soul proximity effects should work through " .. form)
end
assert(principles.Definitions.Soul.Status == "PARTIAL")
assert(principles.supportsForm("Time", "Projectile"))
for _, form in ipairs({ "Construct", "SelfEnhancement" }) do
	assert(principles.supportsForm("Time", form), "Time dilation should work through " .. form)
end
assert(principles.Definitions.Time.Status == "PARTIAL")

print("PASS: six-Principle registry, expression ownership, and implemented/unsupported Form compatibility")
