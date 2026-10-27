--!strict

-- Hidden Field traps (MagicTrapSpec): the server keeps their marker out of
-- Workspace and sends its description only to players who cannot fight the
-- caster. This draws a local copy carrying the same VFX stamp attributes, so
-- the usual client VFX render it, and removes it when the server says so.
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))

local Controller = {}
local started = false

function Controller.start()
	if started then
		return
	end
	started = true
	local remotes = Shared:WaitForChild(Protocol.Folder, 15)
	local remote = remotes and remotes:WaitForChild("MagicHiddenMarkers", 15)
	if not remote or not remote:IsA("RemoteEvent") then
		warn("Hidden trap markers are unavailable: remote did not start")
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MagicHiddenMarkersLocal"
	folder.Parent = workspace
	local markers: { [string]: BasePart } = {}
	remote.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" or type(message.Id) ~= "string" then
			return
		end
		local existing = markers[message.Id]
		if message.Kind == "Hide" then
			if existing then
				markers[message.Id] = nil
				existing:SetAttribute("VFXPhase", "End")
				Debris:AddItem(existing, 0.6)
			end
			return
		end
		if
			message.Kind ~= "Show"
			or existing
			or typeof(message.CFrame) ~= "CFrame"
			or typeof(message.Size) ~= "Vector3"
		then
			return
		end
		local part = Instance.new("Part")
		part.Name = if type(message.Name) == "string" then message.Name else "MagicFieldDebug"
		local found, shape = pcall(function()
			return (Enum.PartType :: any)[message.Shape]
		end)
		part.Shape = if found and shape then shape else Enum.PartType.Block
		part.Size = message.Size
		part.CFrame = message.CFrame
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Transparency = 1
		if type(message.Attributes) == "table" then
			for name, value in message.Attributes do
				if type(name) == "string" then
					pcall(part.SetAttribute, part, name, value)
				end
			end
		end
		part.Parent = folder
		markers[message.Id] = part
	end)
end

return Controller
