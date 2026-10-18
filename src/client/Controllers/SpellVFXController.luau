--!strict
-- Plays allowlisted cosmetic definitions received from the server and owns their lifecycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Rojo maps src/shared beneath ReplicatedStorage.Shared.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local System = Shared:WaitForChild("SpellVFXSystem")
local Service = require(System.Core.VFXService)
local Definitions = require(System.Data.VFXDefinitions)
local Analyzer = require(System.Core.SpellVFXAnalyzer)
local Composer = require(System.Core.SpellVFXComposer)
local Signatures = require(System.Signature.SignatureRenderer)
local CollectionService = game:GetService("CollectionService")
local Controller = {}
local started = false

-- Visual quality: "SpellVFXQuality" player attribute (Low/Medium/High) wins; otherwise touch
-- devices and low graphics levels start lower. Gameplay-critical layers render at every tier.
local QUALITY = { Low = true, Medium = true, High = true }
local function applyQuality()
	local player = game:GetService("Players").LocalPlayer
	local chosen = player and player:GetAttribute("SpellVFXQuality")
	local quality = if type(chosen) == "string" and QUALITY[chosen] then chosen else nil
	if not quality then
		local level = 10
		pcall(function()
			local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
			if saved ~= Enum.SavedQualitySetting.Automatic then
				level = saved.Value
			end
		end)
		local touch = game:GetService("UserInputService").TouchEnabled
		quality = if level <= 3 then "Low" elseif level <= 6 or touch then "Medium" else "High"
	end
	Composer.Quality = quality
	Signatures.Quality = quality
end
Controller.applyQuality = applyQuality

function Controller.start(remotes: Instance)
	if started then
		return
	end
	started = true
	-- Generated asset layers (Fire, Body...) join the procedural composer for every anchor and preview.
	Composer.Signatures = Signatures
	Signatures.start()
	applyQuality()
	local localPlayer = game:GetService("Players").LocalPlayer
	localPlayer:GetAttributeChangedSignal("SpellVFXQuality"):Connect(applyQuality)
	local active = {}
	local composed = {}
	local function reconcile()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local candidates = {}
		for _, part in CollectionService:GetTagged("ComposedSpellVFX") do
			if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
				local distance = (camera.CFrame.Position - part.Position).Magnitude
				if distance < 180 and part:GetAttribute("VFXPhase") ~= "End" then
					table.insert(candidates, { Part = part, Distance = distance })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Distance < b.Distance
		end)
		local selected = {}
		for index = 1, math.min(28, #candidates) do
			selected[candidates[index].Part] = true
		end
		for part, session in pairs(composed) do
			if not selected[part] then
				session:Finish()
				composed[part] = nil
			end
		end
		for part in pairs(selected) do
			if not composed[part] then
				composed[part] = Composer.attach(part, Analyzer.read(part))
			end
		end
	end
	CollectionService:GetInstanceAddedSignal("ComposedSpellVFX"):Connect(reconcile)
	CollectionService:GetInstanceRemovedSignal("ComposedSpellVFX"):Connect(function(part)
		if composed[part] then
			composed[part]:Finish()
			composed[part] = nil
		end
	end)
	local elapsed = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			reconcile()
		end
	end)
	reconcile()
	remotes:WaitForChild("SpellVFX").OnClientEvent:Connect(function(id, target, context)
		if type(id) ~= "string" or not Definitions[id] then
			return
		end
		if typeof(target) ~= "Vector3" and typeof(target) ~= "Instance" then
			return
		end
		local visualContext = type(context) == "table" and table.clone(context) or {}
		local session = Service:Play(Definitions[id], target, visualContext)
		table.insert(active, session)
		local duration = if id == "FireBurst" then 1.5 elseif id == "FrostCharge" then 1.8 else 3
		task.delay(duration, function()
			session:Stop()
			local index = table.find(active, session)
			if index then
				table.remove(active, index)
			end
		end)
	end)
	game:GetService("Players").LocalPlayer.CharacterRemoving:Connect(function()
		for _, session in active do
			session:Stop()
		end
		table.clear(active)
	end)
end

return Controller
