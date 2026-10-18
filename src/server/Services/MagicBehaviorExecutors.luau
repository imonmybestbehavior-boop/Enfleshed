--!strict

-- V1 behavior registry. Each handler receives runtime context supplied by
-- MagicService, keeping behaviors independent from spell identities.
local Behaviors = {}

type Context = {
	ApplySpherePayloads: (radius: number, payloads: { any }) -> (),
	SpawnEffect: (step: any, eventTargets: { any }?) -> (),
	Targets: { any }?,
}

local executors: { [string]: (Context, any) -> () } = {
	Explode = function(context, behavior)
		context.ApplySpherePayloads(behavior.Radius, behavior.Payloads)
	end,
	-- Starts step.Effect (a validated child effect) at the event. Targets are
	-- the event targets left after the step's condition filter.
	SpawnEffect = function(context, behavior)
		context.SpawnEffect(behavior, context.Targets)
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
