--!strict

-- Development-only keyboard harness for the controlled generated registry.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.Sandbox).DevelopmentSpellStress
local Generated = require(Shared.Configuration.GeneratedSpellStress)
local GeneratedController = {}

function GeneratedController.start(magic: any, debug: any)
	local selected = 1
	local function announce()
		if not Config.Enabled or #Generated.Order == 0 then
			return
		end
		local id = Generated.Order[selected]
		debug.Generated(string.format("Generated %d/%d | %s", selected, #Generated.Order, Generated.Descriptions[id]))
	end
	announce()
	return {
		Cycle = function()
			if not Config.Enabled or #Generated.Order == 0 then
				return
			end
			selected = selected % #Generated.Order + 1
			announce()
		end,
		Begin = function()
			if not Config.Enabled or #Generated.Order == 0 then
				return
			end
			local id = Generated.Order[selected]
			magic.Cast(id, Generated.Definitions[id].Casting.Mode == "Charged")
		end,
		Release = function()
			magic.Release()
		end,
	}
end

return GeneratedController
