--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Types = require(Shared.Types.CombatTypes)
local Magic = {}

function Magic.start(send: (string, Types.ActionOptions?) -> number, aim: () -> (Vector3, Vector3))
	local activeSpell: string? = nil
	local function cast(spellId: string, charged: boolean?)
		local direction, point = aim()
		activeSpell = if charged then spellId else nil
		send(Protocol.MagicStart, { SpellId = spellId, AimDirection = direction, WorldPoint = point })
	end
	return {
		Cast = cast,
		Release = function()
			if not activeSpell then
				return
			end
			local direction, point = aim()
			send(Protocol.MagicRelease, { SpellId = activeSpell, AimDirection = direction, WorldPoint = point })
			activeSpell = nil
		end,
		WeaponAction = function(action: string)
			local direction, point = aim()
			send(Protocol.EquipmentUse, { EquipmentAction = action, AimDirection = direction, WorldPoint = point })
		end,
		Reset = function()
			activeSpell = nil
		end,
	}
end

return Magic
