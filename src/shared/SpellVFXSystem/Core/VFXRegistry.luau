--!strict
-- Name-to-module registry. Custom effect modules can be registered at runtime.
local Registry = {}
local modules: { [string]: any } = {}

function Registry:Register(name: string, module: any)
	assert(type(name) == "string" and name ~= "", "effect name must be a non-empty string")
	assert(type(module) == "table" and type(module.Run) == "function", "effect module must expose Run")
	modules[name] = module
end

function Registry:Get(name: string): any?
	return modules[name]
end

function Registry:Names(): { string }
	local names = {}
	for name in modules do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return Registry
