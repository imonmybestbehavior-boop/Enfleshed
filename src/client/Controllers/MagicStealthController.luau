--!strict

-- Player-side Stealth rendering. Inactive while every PvP profile has
-- StealthHidesFromPlayers = false (today: Stealth hides from monsters only).
-- With the setting on, stealthed opponents are drawn invisible for this player
-- unless this player has Revealed them (MagicStealthSpec, MagicRevealSpec).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StealthSpec = require(Shared.Modules.MagicStealthSpec)
local CombatPolicy = require(Shared.Modules.CombatPolicy)
local CapProfiles = require(Shared.Configuration.SpellStatCaps)

local Controller = {}
local REFRESH_INTERVAL = 0.2
local started = false

local function setHidden(character: Model, hidden: boolean)
	local modifier = if hidden then 1 else 0
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			if part.LocalTransparencyModifier ~= modifier then
				part.LocalTransparencyModifier = modifier
			end
		end
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	if not StealthSpec.hidesFromPlayers(CapProfiles) then
		return -- monsters only for now
	end
	local localPlayer = Players.LocalPlayer
	local hiddenCharacters: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < REFRESH_INTERVAL then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		local viewer = CombatPolicy.owner(localPlayer.Character, Players)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local hidden = StealthSpec.hiddenFrom(
					localPlayer.UserId,
					function(name)
						return character:GetAttribute(name)
					end,
					player == localPlayer,
					CombatPolicy.allows(viewer, CombatPolicy.owner(character, Players)),
					true,
					now
				)
				if hidden or hiddenCharacters[character] then
					setHidden(character, hidden)
					hiddenCharacters[character] = if hidden then true else nil
				end
			end
		end
	end)
end

return Controller
