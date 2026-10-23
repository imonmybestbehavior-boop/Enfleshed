-- Run by scripts/run_luau_unit_tests.py (loadfile shim): MagicStealthSpec requires MagicRevealSpec.
local RevealSpec = assert(loadfile("src/shared/Modules/MagicRevealSpec.luau"))()
local Spec = assert(loadfile(
	"src/shared/Modules/MagicStealthSpec.luau",
	"t",
	setmetatable({
		script = { Parent = { MagicRevealSpec = "reveal" } },
		require = function()
			return RevealSpec
		end,
	}, { __index = getfenv() })
))()
local Profiles = assert(loadfile("src/shared/Configuration/SpellStatCaps.luau"))()

-- Monsters always skip stealthed characters.
assert(Spec.hiddenFromMonsters(true))
assert(not Spec.hiddenFromMonsters(false) and not Spec.hiddenFromMonsters(nil))

-- Players: off by default (monsters only for now).
assert(Profiles.PvPOpen.StealthHidesFromPlayers == false and Profiles.PvPRanked.StealthHidesFromPlayers == false)
assert(Spec.hidesFromPlayers(Profiles) == false, "the setting is off in every PvP profile")
assert(Spec.hidesFromPlayers({ PvE = {}, PvPOpen = { StealthHidesFromPlayers = true } }), "one profile turns it on")

local untilName = RevealSpec.attributeNames(42)
local function target(attrs)
	return function(name)
		return attrs[name]
	end
end
local stealthed = target({ MagicStealthed = true })
assert(not Spec.hiddenFrom(42, stealthed, false, true, false, 10), "setting off: players still see them")
assert(Spec.hiddenFrom(42, stealthed, false, true, true, 10), "setting on: hidden from an opponent")
assert(not Spec.hiddenFrom(42, stealthed, true, true, true, 10), "never hidden from yourself")
assert(not Spec.hiddenFrom(42, stealthed, false, false, true, 10), "teammates (can't fight) still see you")
assert(not Spec.hiddenFrom(42, target({}), false, true, true, 10), "not stealthed: visible")
assert(
	not Spec.hiddenFrom(42, target({ MagicStealthed = true, [untilName] = 12 }), false, true, true, 10),
	"revealed to this viewer: visible"
)
assert(
	Spec.hiddenFrom(42, target({ MagicStealthed = true, [untilName] = 9 }), false, true, true, 10),
	"an expired reveal no longer shows them"
)
assert(
	Spec.hiddenFrom(7, target({ MagicStealthed = true, [untilName] = 12 }), false, true, true, 10),
	"someone else's reveal does not show them to this viewer"
)
print("Magic stealth spec: monsters skip, player path off by default, reveal per viewer passed")
