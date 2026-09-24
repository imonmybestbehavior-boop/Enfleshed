--!strict

-- V1 behavior registry. Each handler receives runtime context supplied by
-- MagicService, keeping behaviors independent from spell identities.
local Behaviors = {}

type Context = {
	ApplySpherePayloads: (radius: number, payloads: { any }) -> (),
}

local executors: { [string]: (Context, any) -> () } = {
	Explode = function(context, behavior)
		context.ApplySpherePayloads(behavior.Radius, behavior.Payloads)
	end,
}

function Behaviors.execute(name: string, context: Context, behavior: any): boolean
	local executor = executors[name]
	if not executor then
		return false
	end
	executor(context, behavior)
	return true
end

return Behaviors
