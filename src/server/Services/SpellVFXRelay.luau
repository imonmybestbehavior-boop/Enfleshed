--!strict
-- Optional transport for cosmetic VFX requests. Accepts registered IDs only; no gameplay authority.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.SpellVFXSystem.Data.VFXDefinitions)
local Relay = {}
local remote: RemoteEvent?

local function validValue(value, depth, budget)
	if depth > 4 then
		return false
	end
	local kind = typeof(value)
	if
		kind == "nil"
		or kind == "boolean"
		or kind == "string"
		or kind == "number"
		or kind == "Vector3"
		or kind == "Color3"
		or kind == "CFrame"
		or kind == "Instance"
	then
		return kind ~= "number" or (value == value and math.abs(value) < math.huge)
	end
	if type(value) ~= "table" then
		return false
	end
	for key, child in value do
		budget.Count += 1
		if
			budget.Count > 64
			or (type(key) ~= "string" and type(key) ~= "number")
			or not validValue(child, depth + 1, budget)
		then
			return false
		end
	end
	return true
end

local function validRequest(id, target, context)
	if type(id) ~= "string" or not Definitions[id] then
		return false
	end
	if typeof(target) ~= "Vector3" and typeof(target) ~= "Instance" then
		return false
	end
	return type(context) == "table" and validValue(context, 0, { Count = 0 })
end

function Relay.start(folder: Instance)
	local existing = folder:FindFirstChild("SpellVFX")
	local event = if existing and existing:IsA("RemoteEvent") then existing else Instance.new("RemoteEvent")
	event.Name = "SpellVFX"
	event.Parent = folder
	remote = event
end

function Relay.PlayAll(id: string, target: any, context: any?)
	if not remote or not validRequest(id, target, context or {}) then
		return false
	end
	remote:FireAllClients(id, target, context or {})
	return true
end

function Relay.PlayTo(player: Player, id: string, target: any, context: any?)
	if not remote or not validRequest(id, target, context or {}) then
		return false
	end
	remote:FireClient(player, id, target, context or {})
	return true
end

return Relay
