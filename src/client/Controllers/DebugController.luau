--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Configuration.Sandbox)
local Debug = {}

function Debug.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SandboxDebug"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(760, 156)
	label.Position = UDim2.fromOffset(12, 12)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 17
	label.Font = Enum.Font.Code
	label.Parent = gui
	local hitUntil = 0
	local hitText = ""
	local stress: Instance? = nil
	local magicText = ""
	local magicUntil = 0
	local generatedText = ""
	local function waveText(): string
		if not stress or not stress.Parent then
			stress = workspace:FindFirstChild("SandboxStressTest")
		end
		if not stress then
			return "Stress test starting..."
		end
		local phase = stress:GetAttribute("Status")
		if phase == "Complete" then
			return "Stress test complete | Living 0"
		end
		if phase == "Blocked" then
			return "Waiting for a clear enemy spawn area"
		end
		local wave = stress:GetAttribute("Wave") or 0
		local total = stress:GetAttribute("TotalWaves") or 0
		local living = stress:GetAttribute("LivingEnemies") or 0
		if phase == "Waiting" then
			local seconds =
				math.max(0, math.ceil((stress:GetAttribute("NextWaveAt") or 0) - workspace:GetServerTimeNow()))
			return string.format("Wave %d/%d | Living %d | Next in %ds", wave, total, living, seconds)
		end
		return string.format("Wave %d/%d | Living %d", wave, total, living)
	end
	return {
		Hit = function(damage: number, target: Model?)
			local name = if target then (target:GetAttribute("SandboxLabel") or target.Name) else "Target"
			hitText = string.format("HIT %s  -%g HP", name, damage)
			hitUntil = os.clock() + Config.Debug.HitDuration
			if not target or not target:IsDescendantOf(workspace) then
				return
			end
			-- Client-only, confirmed-hit debug feedback. One flash/number per target.
			for _, effectName in { "SandboxConfirmedHit", "SandboxDamageNumber" } do
				local previous = target:FindFirstChild(effectName)
				if previous then
					previous:Destroy()
				end
			end
			local flash = Instance.new("Highlight")
			flash.Name = "SandboxConfirmedHit"
			flash.Adornee = target
			flash.FillTransparency = 0.6
			flash.FillColor = Color3.fromRGB(255, 255, 255)
			flash.OutlineColor = Color3.fromRGB(255, 255, 255)
			flash.OutlineTransparency = 0
			flash.DepthMode = Enum.HighlightDepthMode.Occluded
			flash.Parent = target
			Debris:AddItem(flash, Config.Debug.TargetFlashDuration)
			local anchor = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
			if not anchor or not anchor:IsA("BasePart") then
				return
			end
			local number = Instance.new("BillboardGui")
			number.Name = "SandboxDamageNumber"
			number.Adornee = anchor
			number.Size = UDim2.fromOffset(130, 32)
			number.StudsOffset = Vector3.new(0, 3.5, 0)
			number.AlwaysOnTop = true
			number.Parent = target
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBold
			text.TextSize = 24
			text.TextColor3 = Color3.fromRGB(255, 240, 140)
			text.TextStrokeTransparency = 0
			text.Text = string.format("-%g", damage)
			text.Parent = number
			Debris:AddItem(number, Config.Debug.HitDuration)
		end,
		Reset = function()
			hitUntil = 0
		end,
		Magic = function(message: any)
			magicText = string.format(
				"Magic %s %s | mana %s | strain %s | complexity %s%s%s",
				tostring(message.Name or ""),
				tostring(message.Result or ""),
				tostring(message.Mana or "-"),
				tostring(message.Strain or "-"),
				tostring(message.Complexity or "-"),
				if message.Damage then " | damage " .. tostring(message.Damage) else "",
				if message.Reason then " | " .. tostring(message.Reason) else ""
			)
			magicUntil = os.clock() + 2.5
		end,
		Generated = function(text: string)
			generatedText = text
		end,
		Update = function(combo: number, cooldown: number)
			label.Text = string.format(
				"Combo %d/3  |  Dash %.1fs\n%s\n%s\n%s\n%s\nV2: 4 Lance | 5 Ground | 6 Reinforcement | 7 Raise",
				combo,
				cooldown,
				if os.clock() < hitUntil then hitText else "",
				if os.clock() < magicUntil then magicText else "",
				generatedText,
				waveText()
			)
		end,
	}
end

export type Controller = typeof(Debug.start())
return Debug
