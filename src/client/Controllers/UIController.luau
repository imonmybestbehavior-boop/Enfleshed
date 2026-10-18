--!strict
-- Owns the in-game HUD (UI/HUD/*): combat vitals, spell bar, mission tracker,
-- lobby/results and world prompts. Gameplay hooks (remotes, attributes) are
-- unchanged; this is presentation only.
--
-- Cursor rule: while any HUD modal (lobby, results) is open the player
-- attribute "UIModalOpen" is true. CameraController then never locks the mouse,
-- and a Modal GuiButton keeps the Roblox cursor free, so clicks cannot re-lock it.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SpellProgression = require(Shared.Configuration.SpellProgression)
local Config = require(Shared.Configuration.DefendTheWalls)
local HUD = script.Parent.Parent.UI.HUD
local C = require(HUD.Components)

local UIController = {}
local verbose = RunService:IsStudio()

local function nextUnlockText(message: any): string
	if not message.Saved then
		return "SAVE FAILED: REWARDS NOT CONFIRMED"
	end
	local profile = message.Profile
	if type(profile) ~= "table" then
		return "PROGRESS SAVED"
	end
	local nextName, nextXP = nil, math.huge
	for _, milestone in ipairs(SpellProgression.SlotMilestones) do
		if profile.XP < milestone.XP and milestone.XP < nextXP then
			nextName, nextXP = tostring(milestone.Slots) .. " SLOTS", milestone.XP
		end
	end
	for _, id in ipairs(SpellProgression.UnlockOrder) do
		local offer = SpellProgression.Unlocks[id]
		if not (profile.Unlocks and profile.Unlocks[id]) and profile.XP < offer.XP and offer.XP < nextXP then
			nextName, nextXP = offer.Name, offer.XP
		end
	end
	return if nextName
		then string.format("SAVED · NEXT %s AT %d XP", string.upper(nextName), nextXP)
		else "PROGRESS SAVED · CHECK GRIMOIRE UPGRADES"
end

function UIController.start(launcher: any?)
	local player = Players.LocalPlayer
	local remotes = Shared:WaitForChild("SandboxRemotes")
	local remote = remotes:WaitForChild("MissionRemote") :: RemoteEvent

	-- Modal bookkeeping and the cursor guarantee.
	local modals: { [string]: boolean } = {}
	local modalGui = C.screen("UIModalCursor", 300)
	local modalButton = C.new("TextButton", {
		Name = "ModalCursor",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Visible = false,
		Selectable = false,
	}, modalGui)
	local function setModal(name: string, open: boolean)
		modals[name] = if open then true else nil
		local any = next(modals) ~= nil
		modalButton.Visible = any
		if player:GetAttribute("UIModalOpen") ~= any then
			player:SetAttribute("UIModalOpen", any)
		end
		if any then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end

	local SpellState = require(HUD.SpellState)
	task.spawn(SpellState.start)
	local combat = require(HUD.CombatHUD).new(C.screen("CombatHUD", 10))
	local function openSpellbook()
		if launcher and launcher.Open then
			launcher:Open()
		end
	end
	-- Above the Grimoire (DisplayOrder 80) so its cards can be dropped on the bar.
	local bar = require(HUD.SpellBar).new(C.screen("SpellBarHUD", 90), openSpellbook)
	local tracker = require(HUD.MissionTracker).new(C.screen("MissionHUD", 12))
	local lobby = require(HUD.Lobby).new(C.screen("LobbyUI", 60), {
		Request = function(action: string)
			remote:FireServer(action)
		end,
		SetModal = setModal,
	})
	require(HUD.WorldUI).start(C.screen("WorldPrompts", 20))

	local currentId, previousIntegrity, previousWall = "", 1, 1
	remote.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then
			return
		end
		if message.Kind == "Notice" and type(message.Text) == "string" then
			if verbose then
				print("[Mission/client] server notice:", message.Text)
			end
			lobby.Notice(message.Text)
		elseif message.Kind == "Ack" then
			lobby.Ack(message)
		elseif message.Kind == "MissionResult" then
			lobby.Result(message, nextUnlockText(message))
		elseif message.Kind == "MissionState" then
			if message.Id ~= currentId then
				currentId, previousIntegrity, previousWall = message.Id, 1, 1
			end
			local ratio = (message.Gateway or 0) / math.max(1, message.GatewayMax or 1)
			if message.State == "ACTIVE" then
				for _, threshold in Config.GatewayWarnings do
					if previousIntegrity > threshold and ratio <= threshold then
						tracker.Warn(string.format("GATEWAY CRITICAL: %d%%", math.floor(ratio * 100)))
					end
				end
			end
			previousIntegrity = ratio
			local wallLevel = message.WallLevel or 1
			if message.State == "ACTIVE" and wallLevel > previousWall then
				local count = message.WallCount or 3
				tracker.Warn(
					if wallLevel > count
						then "THE INNER BASTION HAS FALLEN — HOLD THE GATE"
						else string.format("WALL %d BREACHED — FALL BACK TO WALL %d", wallLevel - 1, wallLevel),
					5
				)
			end
			previousWall = wallLevel
			local level = tracker.Update(message)
			if level then
				combat.SetLevel(level)
			end
			lobby.State(message)
		end
	end)
	remote:FireServer("State")

	-- M / D-pad up reopens the mission lobby after "Explore".
	ContextActionService:BindAction("HUDLobbyToggle", function(_, state)
		if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if player:GetAttribute("MagicLabOpen") == true then
			return Enum.ContextActionResult.Pass
		end
		lobby.Toggle()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.DPadUp)

	local inventoryLinks: { RBXScriptConnection } = {}
	local hud = {}
	function hud.UpdateCombat(step: number, dashCooldown: number)
		bar.UpdateCombo(step, dashCooldown)
	end
	function hud.Reset()
		bar.UpdateCombo(0, 0)
	end
	-- Weapon and quick slots on the bar mirror the inventory.
	function hud.BindInventory(inventory: any)
		for _, link in inventoryLinks do
			link:Disconnect()
		end
		local Rules = require(Shared.Modules.ItemRules)
		local function update()
			local data = inventory.Get()
			for index = 1, 2 do
				local item = data.Quick[index]
				local key = inventory.Keys.Quick[index]
				local keyText = if key then key.Name else tostring(index)
				bar.SetConsumable(
					index,
					keyText,
					if item then Rules.displayName(item) else nil,
					if item then item.Count else nil
				)
			end
			local slot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
			local active = if slot == "PrimaryWeapon" then data.Equip.MagicFocus else data.Equip.MainHand
			bar.SetWeapon(
				if active then Rules.displayName(active) else nil,
				if active then Rules.rarity(active.Rarity).Color else nil
			)
		end
		table.insert(inventoryLinks, inventory.Changed:Connect(update))
		update()
	end
	return hud
end

return UIController
