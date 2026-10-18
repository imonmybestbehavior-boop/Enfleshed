-- Exercise the actual development Apply branch with an undiscovered player.
-- Roblox transport/storage are mocked; existing spell tests cover schema validation.
local file = assert(io.open("src/server/Services/MagicLabService.luau"))
local source = file:read("*a")
file:close()
local branch = assert(source:match('if action == "Apply" then(.-)elseif action == "Cast" then'))
local player = {} -- Deliberately no unlock attributes or discovery service.
local replies, saves, equipped, cleared = {}, 0, nil, 0
local env = setmetatable({
	player = player,
	action = "Apply",
	slot = 1,
	slotIdValue = "LabSlot1",
	state = {},
	loaded = { [player] = true },
	definitions = {},
	dirty = {},
	catalogs = {},
	LabCost = assert(loadfile("src/shared/Modules/MagicLabCost.luau"))(),
	writable = {},
	Library = assert(loadfile(
		"src/shared/Modules/GrimoireLibrary.luau",
		"t",
		setmetatable({
			script = { Parent = { MagicSpellIdentitySpec = "identitySpec" } },
			require = function()
				return assert(loadfile("src/shared/Modules/MagicSpellIdentitySpec.luau"))()
			end,
		}, { __index = getfenv() })
	))(),
	Slots = assert(loadfile("src/shared/Modules/MagicSlots.luau"))(),
	publish = function() end,
	-- Progression gate; the unrestricted Studio sandbox always allows (see usable()).
	usable = function()
		return true, ""
	end,
	unrestricted = function()
		return true
	end,
	-- Server-side repricing: cost always comes from the server estimate.
	reprice = function(definition)
		definition.Cost = { ManaDemand = 12 }
	end,
	syncCompanion = function(_, _, definition)
		equipped = definition
	end,
	getState = function()
		return {}
	end,
	Spec = {
		validate = function(data)
			return data.valid, "Invalid spell"
		end,
		copy = function(data)
			local copy = {}
			for k, v in pairs(data) do
				copy[k] = v
			end
			return copy
		end,
		estimate = function()
			return { ManaDemand = 12 }
		end,
	},
	Magic = {
		clearTemporary = function()
			cleared = cleared + 1
		end,
		setCompanionSpell = function(_, _, spell)
			equipped = spell
		end,
	},
	reply = function(_, _, ok, text)
		replies[#replies + 1] = { ok = ok, text = text }
	end,
	scheduleSave = function()
		saves = saves + 1
	end,
}, { __index = _G })
local apply = assert(load(branch, "MagicLab Apply", "t", env))
for _, expression in ipairs({ "Water", "Lightning", "Force", "Unawakened" }) do
	env.data = {
		valid = true,
		Source = { Expression = expression },
		Visual = {
			Palette = "TestPalette",
			CoreShape = "TestShape",
		},
	}
	apply()
	assert(replies[#replies].ok, "Progression must not reject valid test spells")
	assert(equipped.Source.Expression == expression and equipped.Development == true)
	assert(equipped.SpellId == "LabSlot1" and equipped.Cost.ManaDemand == 12)
	assert(env.definitions[player][1] == equipped and env.dirty[player])
	assert(env.data.Development == nil, "Client input must not be mutated")
end
assert(saves == 4 and cleared == 4)
env.data = { valid = false }
apply()
assert(not replies[#replies].ok and saves == 4 and cleared == 4, "Invalid spells still rejected")
env.loaded[player] = nil
env.data = { valid = true }
apply()
assert(not replies[#replies].ok and saves == 4, "Library must still load before Apply")
assert(source:find("if not allowed%(%) then"), "Development access guard must remain")
print("Magic Lab access: ungated testing, schema rejection, load requirement, and save/equip path passed")
