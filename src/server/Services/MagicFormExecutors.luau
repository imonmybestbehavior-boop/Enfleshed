--!strict

-- V2 form dispatch. Each executor operates entirely through its supplied
-- context, which keeps this registry independent of individual spell IDs.
local Forms = {}

Forms.Executors = {
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
