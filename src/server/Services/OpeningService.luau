--!strict
-- Session identity only; no persistent class or progression state.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Configuration.CityLife)
local Plan = require(Shared.Configuration.PhaseATopology)
local Equipment = require(script.Parent.EquipmentService)
local Spawn = require(script.Parent.WorldSpawnService)
local Arena = require(script.Parent.CombatSandboxService)
local Opening = {}
local sessions = {}

local function dress(character, preset)
	for _, item in character:GetChildren() do
		if
			item:IsA("Accessory")
			or item:IsA("Shirt")
			or item:IsA("Pants")
			or item:IsA("ShirtGraphic")
			or item.Name == "LowerLayerClothing"
		then
			item:Destroy()
		end
	end
	local clothes = Instance.new("Folder")
	clothes.Name = "LowerLayerClothing"
	clothes.Parent = character
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "SandboxEquippedWeapon" then
			local clothed = part.Name ~= "Head" and not string.find(part.Name, "Hand")
			part.Color = if clothed then preset.Cloth else preset.Skin
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			if clothed and (string.find(part.Name, "Torso") or string.find(part.Name, "Leg")) then
				local cover = Instance.new("Part")
				cover.Name = "Cloth"
				cover.Size = part.Size + Vector3.new(0.04, 0.02, 0.04)
				cover.CFrame = part.CFrame
				cover.Color = preset.Cloth
				cover.Material = Enum.Material.Fabric
				cover.CanCollide, cover.CanTouch, cover.CanQuery, cover.Massless = false, false, false, true
				cover.Parent = clothes
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = part, cover, cover
			end
		end
	end
end

function Opening.bind(player)
	local session = { Preset = 1, Complete = Arena.enabled(), LastRequest = -math.huge }
	sessions[player] = session
	player:SetAttribute("OpeningComplete", session.Complete)
	session.Connection = player.CharacterAppearanceLoaded:Connect(function(character)
		-- The combat sandbox uses the player's normal avatar appearance. The
		-- lower-layer clothing overlay is only for the story/city opening.
		if not Arena.enabled() and player.Character == character then
			dress(character, Config.Presets[session.Preset])
		end
	end)
end

function Opening.prepareCharacter(player, character)
	if Arena.enabled() then
		character:PivotTo(CFrame.new(require(Shared.Configuration.DevelopmentSandbox).Spawn))
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	dress(character, Config.Presets[session.Preset])
	if not session.Complete then
		local position = Spawn.ground(Plan.Nodes[Config.Opening.Node] + Config.Opening.Offset, 5, 3)
		if position then
			character:PivotTo(CFrame.new(position))
		end
		character.HumanoidRootPart.Anchored = true
	end
end

function Opening.start(folder, feedback)
	local choice = Instance.new("RemoteEvent")
	choice.Name, choice.Parent = "OpeningChoice", folder
	choice.OnServerEvent:Connect(function(player, preset, path)
		local session = sessions[player]
		if not session or session.Complete or os.clock() - session.LastRequest < 0.5 then
			return
		end
		session.LastRequest = os.clock()
		if typeof(preset) ~= "number" or preset % 1 ~= 0 or not Config.Presets[preset] then
			return
		end
		if path ~= "Melee" and path ~= "Magic" then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player:GetAttribute("CharacterReady") or not humanoid or humanoid.Health <= 0 then
			return
		end
		if not Equipment.chooseStarter(player, path, feedback) then
			return
		end
		session.Preset, session.Complete = preset, true
		character.HumanoidRootPart.Anchored = false
		character.HumanoidRootPart:SetNetworkOwner(player)
		dress(character, Config.Presets[preset])
		player:SetAttribute("AppearancePreset", preset)
		player:SetAttribute("OpeningComplete", true)
	end)
end
function Opening.remove(player)
	local session = sessions[player]
	if session then
		session.Connection:Disconnect()
	end
	sessions[player] = nil
end
return Opening
