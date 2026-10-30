--!strict
-- Safe escape hatch: only functions explicitly registered in ScriptLibrary can run.
local ScriptLibrary = require(script.Parent.Parent.Data.ScriptLibrary)
return {
	Run = function(session, config, target, context)
		local callback = ScriptLibrary[config.Key]
		if type(callback) == "function" and session.Active then
			callback(session, config.Params or {}, target, context)
		end
	end,
}
