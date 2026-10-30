--!strict

-- V2 form dispatch. Each executor operates entirely through its supplied
-- context, which keeps this registry independent of individual spell IDs.
local Forms = {}

Forms.Executors = {
	Aura = function(d, context)
		context.CreateAura(d)
	end,
	Construct = function(d, context)
		context.CreateConstruct(d)
	end,
	Projectile = function(definition, context)
		context.CreateProjectile(definition)
	end,
	Wave = function(definition, context)
		context.ExecuteWave(definition)
	end,
	Beam = function(definition: any, context: any)
		context.ExecuteBeam(definition)
	end,
	Field = function(definition: any, context: any)
		context.CreateField(definition)
	end,
	SelfEnhancement = function(definition: any, context: any)
		context.ApplySelf(definition)
	end,
	Manipulation = function(definition: any, context: any)
		context.ApplyManipulation(definition)
	end,
	-- Dash or Blink the caster along the aim (MagicService.ExecuteRush).
	Rush = function(definition: any, context: any)
		context.ExecuteRush(definition)
	end,
	-- Link two characters (MagicService.CreateTether).
	Tether = function(definition: any, context: any)
		context.CreateTether(definition)
	end,
}

function Forms.execute(form: string, definition: any, context: any): boolean
	local executor = Forms.Executors[form]
	if not executor then
		return false
	end
	executor(definition, context)
	return true
end

return Forms
