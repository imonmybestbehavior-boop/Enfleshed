--!strict

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local player = game:GetService("Players").LocalPlayer
local SummonConfig = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicSummons)
local Input = {}
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local studioSandbox = RunService:IsStudio() and require(Shared.Configuration.DevelopmentSandbox).Enabled
local development = studioSandbox

local function uiOpen(player: Player): boolean
	return player:GetAttribute("MagicLabOpen") == true
		or player:GetAttribute("InventoryOpen") == true
		or player:GetAttribute("UIModalOpen") == true
end

local function canControl(player: Player): boolean
	return studioSandbox or player:GetAttribute("CharacterReady") == true
end

function Input.start(
	sprint: (boolean) -> (),
	dash: () -> (),
	magicStart: (string, boolean?) -> (),
	magicRelease: () -> (),
	useEquipment: (string, string?) -> (),
	switchEquipment: () -> (),
	cycleGenerated: () -> (),
	startGenerated: () -> (),
	releaseGenerated: () -> (),
	cycleSummonSelection: () -> (),
	summonCommand: (string) -> ()
)
	ContextActionService:BindAction("SandboxSprint", function(_, state)
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			sprint(false)
		elseif state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			sprint(true)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("SandboxDash", function(_, state)
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			dash()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("SandboxPrimaryAttack", function(_, state)
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			-- Releases always pass through so a held heavy or block never sticks.
			useEquipment("Primary", "End")
			return Enum.ContextActionResult.Pass
		end
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			useEquipment("Primary", "Begin")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("SandboxHeavyAttack", function(_, state)
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			useEquipment("Heavy", "Begin")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	for mode, keyName in pairs(SummonConfig.CommandKeys) do
		local key = Enum.KeyCode[keyName]
		ContextActionService:BindAction("SandboxSummon" .. mode, function(_, state)
			if not canControl(player) or uiOpen(player) then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
				summonCommand(mode)
			end
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	ContextActionService:BindAction("SandboxEquipmentArea", function(_, state)
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			-- Releases always pass through so a held heavy or block never sticks.
			useEquipment("Area", "End")
			return Enum.ContextActionResult.Pass
		end
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			useEquipment("Area", "Begin")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("SandboxSummonSelect", function(_, state)
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			cycleSummonSelection()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode[SummonConfig.SelectionKey])
	ContextActionService:BindAction("SandboxEquipmentSwitch", function(_, state)
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			switchEquipment()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("SandboxSprint", "SPRINT")
	ContextActionService:SetTitle("SandboxDash", "DASH")
	ContextActionService:SetTitle("SandboxPrimaryAttack", "ATTACK")
	ContextActionService:SetTitle("SandboxHeavyAttack", "HEAVY")
	ContextActionService:SetTitle("SandboxEquipmentArea", "AREA/BLOCK")
	ContextActionService:SetTitle("SandboxEquipmentSwitch", "SWITCH")
	ContextActionService:SetPosition("SandboxSprint", UDim2.new(1, -240, 1, -230))
	ContextActionService:SetPosition("SandboxDash", UDim2.new(1, -165, 1, -230))
	ContextActionService:SetPosition("SandboxPrimaryAttack", UDim2.new(1, -90, 1, -170))
	ContextActionService:SetPosition("SandboxHeavyAttack", UDim2.new(1, -90, 1, -245))
	ContextActionService:SetPosition("SandboxEquipmentArea", UDim2.new(1, -165, 1, -150))
	ContextActionService:SetPosition("SandboxEquipmentSwitch", UDim2.new(1, -240, 1, -150))
	for spellId, key in
		{
			Fireball = Enum.KeyCode.One,
			BodyBurst = Enum.KeyCode.Two,
			StoneShot = Enum.KeyCode.Three,
			LightningLance = Enum.KeyCode.Four,
			BurningGround = Enum.KeyCode.Five,
			BodyReinforcement = Enum.KeyCode.Six,
			StoneRaise = Enum.KeyCode.Seven,
		}
	do
		ContextActionService:BindAction("Sandbox" .. spellId, function(_, state)
			if not development then
				return Enum.ContextActionResult.Pass
			end
			if not canControl(player) or uiOpen(player) then
				return Enum.ContextActionResult.Pass
			end
			if UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Sink
			end
			if state == Enum.UserInputState.Begin then
				magicStart(spellId, spellId == "StoneShot")
			elseif
				spellId == "StoneShot" and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel)
			then
				magicRelease()
			end
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	ContextActionService:BindAction("SandboxGeneratedCycle", function(_, state)
		if not development then
			return Enum.ContextActionResult.Pass
		end
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			cycleGenerated()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F)
	ContextActionService:BindAction("SandboxGeneratedCast", function(_, state)
		-- R is the melee heavy attack, so the Studio cast key only takes it while the Magic Focus is out.
		if not development or (player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon") ~= "PrimaryWeapon" then
			return Enum.ContextActionResult.Pass
		end
		if not canControl(player) or uiOpen(player) then
			return Enum.ContextActionResult.Pass
		end
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Sink
		end
		if state == Enum.UserInputState.Begin then
			startGenerated()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			releaseGenerated()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R)
	UserInputService.WindowFocusReleased:Connect(function()
		sprint(false)
	end)
	UserInputService.TextBoxFocused:Connect(function()
		sprint(false)
	end)
end

return Input
