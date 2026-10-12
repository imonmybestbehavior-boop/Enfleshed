local zoneSpec = assert(loadfile("src/shared/Modules/MagicEnvironmentZoneSpec.luau"))()
local environment = {
	script = { Parent = { MagicEnvironmentZoneSpec = "MagicEnvironmentZoneSpec" } },
	require = function(moduleName)
		assert(moduleName == "MagicEnvironmentZoneSpec")
		return zoneSpec
	end,
}
setmetatable(environment, { __index = _G })
local chunk = assert(loadfile("src/shared/Modules/MagicEnvironmentRequirementSpec.luau", "t", environment))
local spec = chunk()

local daytime = {
	RequireGrounded = true,
	ClockTime = { Start = 6, End = 18 },
	ZoneTags = { Required = { "market", "indoors" }, Forbidden = { "combat" } },
}
assert(spec.validate(daytime))
assert(spec.check(daytime, { OnGround = true, ClockTime = 12, ZoneTags = "|market|indoors|" }))
local grounded, groundReason = spec.check(daytime, { OnGround = false, ClockTime = 12, ZoneTags = "|market|indoors|" })
assert(not grounded and groundReason:find("solid ground", 1, true))
local night, timeReason = spec.check(daytime, { OnGround = true, ClockTime = 23, ZoneTags = "|market|indoors|" })
assert(not night and timeReason:find("between", 1, true))
local missingTag = spec.check(daytime, { OnGround = true, ClockTime = 12, ZoneTags = "|market|" })
assert(not missingTag)
local forbiddenTag = spec.check(daytime, { OnGround = true, ClockTime = 12, ZoneTags = "|market|indoors|combat|" })
assert(not forbiddenTag)

local overnight = { ClockTime = { Start = 20, End = 4 } }
assert(spec.check(overnight, { ClockTime = 23, ZoneTags = "||", OnGround = true }))
assert(spec.check(overnight, { ClockTime = 2, ZoneTags = "||", OnGround = true }))
assert(not spec.check(overnight, { ClockTime = 12, ZoneTags = "||", OnGround = true }))
assert(spec.check(nil, nil), "spells without environment requirements should not need an environment snapshot")

assert(not spec.validate({ ClockTime = { Start = 25, End = 2 } }))
assert(not spec.validate({ ClockTime = { Start = 5 } }))
assert(not spec.validate({ ZoneTags = { Required = { "combat" }, Forbidden = { "combat" } } }))
assert(not spec.validate({ ZoneTags = { Required = { "contains spaces" } } }))
assert(not spec.validate({ Unknown = true }))

print("Magic environment requirements: server inputs, time windows, tags, and validation passed")
