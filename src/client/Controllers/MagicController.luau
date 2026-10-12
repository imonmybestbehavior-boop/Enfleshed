--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Types = require(Shared.Types.CombatTypes)
local Magic = {}
local function handOrigin()
	local character = game:GetService("Players").LocalPlayer.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	return if hand and hand:IsA("BasePart")
		then hand.Position - hand.CFrame.UpVector * hand.Size.Y * 0.35 + Vector3.yAxis * 0.9
		else nil
end

function Magic.start(send: (string, Types.ActionOptions?) -> number, aim: () -> (Vector3, Vector3, Model?, Instance?))
	require(script.Parent.MagicPresentationController).start()
	require(script.Parent.MagicLabController).start(send, aim)
	local activeSpell: string? = nil
	local function cast(spellId: string, charged: boolean?)
		local direction, point, target, targetInstance = aim()
		activeSpell = if charged then spellId else nil
		send(Protocol.MagicStart, {
			SpellId = spellId,
			AimDirection = direction,
			WorldPoint = point,
			TargetModel = target,
			TargetInstance = targetInstance,
			CastOrigin = handOrigin(),
		})
	end
	return {
		Cast = cast,
		Release = function()
			if not activeSpell then
				return
			end
			local direction, point, target, targetInstance = aim()
			send(Protocol.MagicRelease, {
				SpellId = activeSpell,
				AimDirection = direction,
				WorldPoint = point,
				TargetModel = target,
				TargetInstance = targetInstance,
				CastOrigin = handOrigin(),
			})
			activeSpell = nil
		end,
		WeaponAction = function(action: string)
			local direction, point, target, targetInstance = aim()
			send(Protocol.EquipmentUse, {
				EquipmentAction = action,
				AimDirection = direction,
				WorldPoint = point,
				TargetModel = target,
				TargetInstance = targetInstance,
			})
		end,
		Reset = function()
			activeSpell = nil
		end,
	}
end

return Magic
