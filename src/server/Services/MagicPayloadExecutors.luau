--!strict

-- Small registry for payload kinds the runtime currently supports. Context is
-- supplied by MagicService so executors remain neutral about spell identities.
local Damage = require(script.Parent.DamageService)

local Payloads = {}

Payloads.Executors = {
	Damage = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local dealt = Damage.apply(context.Caster, humanoid, payload.Amount * context.Potency)
			if dealt > 0 then
				context.HitFeedback(humanoid, dealt)
			end
		end
	end,
	Force = function(payload: any, context: any)
		for _, humanoid in context.Targets or {} do
			local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.AssemblyLinearVelocity += context.Direction * payload.Magnitude + Vector3.new(
					0,
					payload.Upward or 0,
					0
				)
			end
		end
	end,
	Enhancement = function(payload: any, context: any)
		context.ApplyEnhancement(payload)
	end,
	Manipulation = function(payload: any, context: any)
		context.ApplyManipulation(payload)
	end,
}

function Payloads.execute(payloads: { any }, context: any)
	for _, payload in payloads do
		local executor = Payloads.Executors[payload.Kind]
		if executor then
			executor(payload, context)
		end
	end
end

return Payloads
