--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Configuration.Sandbox)
local Debug = {}

function Debug.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SandboxDebug"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cityConfig = require(game:GetService("ReplicatedStorage").Shared.Configuration.CityLife)
	gui.Enabled = game:GetService("RunService"):IsStudio()
		and (cityConfig.DevelopmentSpells or Config.StressTest.Enabled)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(760, 216)
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
	local summonText = ""
	local summonUntil = 0
	local generatedText = ""
	local function waveText(): string
		if not Config.StressTest.Enabled then
			return ""
		end
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
	local function locusTestText(): string
		return "Locus stats fixed for unrestricted testing"
	end
	local function companionSpellText(): string
		local summons = workspace:FindFirstChild("MagicSummons")
		if not summons then
			return ""
		end
		local owned = {}
		for _, model in summons:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("MagicSummonOwnerUserId") == Players.LocalPlayer.UserId then
				table.insert(owned, {
					Id = model:GetAttribute("MagicSummonId") or 0,
					Slot = model:GetAttribute("MagicSummonSpellSlot") or 0,
					Status = model:GetAttribute("MagicSummonSpellStatus") or "SEARCHING",
					Reason = model:GetAttribute("MagicSummonSpellReason") or "",
					Target = model:GetAttribute("MagicSummonSpellTarget") or "",
				})
			end
		end
		if #owned == 0 then
			return ""
		end
		local selectedId = Players.LocalPlayer:GetAttribute("MagicSelectedSummonId")
		table.sort(owned, function(first, second)
			if (first.Id == selectedId) ~= (second.Id == selectedId) then
				return first.Id == selectedId
			end
			return first.Id < second.Id
		end)
		local rows = {}
		for index = 1, math.min(#owned, 3) do
			local companion = owned[index]
			local detail = if companion.Target ~= "" then " → " .. companion.Target else ""
			if companion.Reason ~= "" then
				detail ..= " · " .. companion.Reason
			end
			table.insert(
				rows,
				string.format(
					"%s#%s slot %s: %s%s",
					if companion.Id == selectedId then "▶ " else "",
					companion.Id,
					companion.Slot,
					companion.Status,
					detail
				)
			)
		end
		return "Companion spells | " .. table.concat(rows, "   |   ")
	end
	local numberSequence = 0
	local function showNumber(kind: string, amount: number, target: Model?)
		if not target or not target:IsDescendantOf(workspace) or amount <= 0 then
			return
		end
		local anchor = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
		if not anchor or not anchor:IsA("BasePart") then
			return
		end
		numberSequence += 1
		local number = Instance.new("BillboardGui")
		number.Name = "SandboxCombatNumber" .. numberSequence
		number.Adornee = anchor
		number.Size = UDim2.fromOffset(150, 36)
		number.StudsOffset = Vector3.new((numberSequence % 3 - 1) * 0.4, 3.5, 0)
		number.AlwaysOnTop = true
		number.MaxDistance = 140
		number.Parent = target
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 25
		text.TextStrokeTransparency = 0.15
		text.TextTransparency = 0
		text.Text = if kind == "Damage"
			then string.format("-%g", amount)
			elseif kind == "Transformation" then string.format("×%.2f SIZE", amount)
			elseif kind == "TimeDilation" then string.format("×%.2f TIME", amount)
			elseif kind == "Displacement" then string.format("%g STUDS", amount)
			elseif kind == "Shield" then string.format("+%g SHIELD", amount)
			elseif kind == "Control" then string.format("%g CONTROL", amount)
			else string.format("+%g", amount)
		text.TextColor3 = if kind == "Heal"
			then Color3.fromRGB(111, 255, 153)
			elseif kind == "Transformation" then Color3.fromRGB(232, 174, 255)
			elseif kind == "TimeDilation" then Color3.fromRGB(176, 155, 255)
			elseif kind == "Displacement" then Color3.fromRGB(212, 180, 255)
			elseif kind == "Shield" then Color3.fromRGB(112, 222, 255)
			elseif kind == "Control" then Color3.fromRGB(206, 146, 255)
			elseif kind == "Damage" then Color3.fromRGB(255, 119, 96)
			else Color3.fromRGB(255, 240, 140)
		text.Parent = number
		TweenService:Create(number, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = number.StudsOffset + Vector3.new(0, 1.15, 0),
		}):Play()
		TweenService
			:Create(text, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.15), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			:Play()
		Debris:AddItem(number, 1.1)
	end
	return {
		Hit = function(damage: number, target: Model?)
			local name = if target then (target:GetAttribute("SandboxLabel") or target.Name) else "Target"
			hitText = string.format("HIT %s  -%g HP", name, damage)
			hitUntil = os.clock() + Config.Debug.HitDuration
			if not target or not target:IsDescendantOf(workspace) then
				return
			end
			-- The highlight is local; floating numbers arrive through replicated server feedback.
			for _, effectName in { "SandboxConfirmedHit" } do
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
		end,
		Reset = function()
			hitUntil = 0
		end,
		Magic = function(message: any)
			magicText = string.format(
				"Magic %s %s | mana %s/%s (cost %s) | strain %s/%s | complexity %s/%s%s%s%s",
				tostring(message.Name or ""),
				tostring(message.Result or ""),
				tostring(message.Mana or "-"),
				tostring(message.Capacity or "-"),
				tostring(message.ManaDemand or "-"),
				tostring(message.Strain or "-"),
				tostring(message.StrainTolerance or "-"),
				tostring(message.Complexity or "-"),
				tostring(message.ComplexityCapacity or "-"),
				if message.Damage then " | damage " .. tostring(message.Damage) else "",
				if message.Reason then " | " .. tostring(message.Reason) else "",
				if message.Effect
					then " | " .. tostring(message.Effect) .. " " .. tostring(message.Amount or "")
					else ""
			)
			magicUntil = os.clock() + 2.5
		end,
		SummonCommand = function(message: any)
			summonText = if message.Accepted
				then "Summons: " .. tostring(message.Reason or message.Mode or "Order set")
				else "Summons: " .. tostring(message.Reason or "Command rejected")
			summonUntil = os.clock() + 3
		end,
		Number = showNumber,
		Generated = function(text: string)
			generatedText = text
		end,
		Update = function(combo: number, cooldown: number)
			label.Text = string.format(
				"Combo %d/3  |  Dash %.1fs\n%s\n%s\n%s\n%s\n%s\n%s\n%s\nV2: 4 Lance | 5 Ground | 6 Reinforcement | 7 Raise\nSummons: N Select | Z Follow | X Protect | C Attack | B Move | J Patrol | H Hold | G Support | V Dismiss",
				combo,
				cooldown,
				if os.clock() < hitUntil then hitText else "",
				if os.clock() < magicUntil then magicText else "",
				if os.clock() < summonUntil then summonText else "",
				companionSpellText(),
				generatedText,
				waveText(),
				locusTestText()
			)
		end,
	}
end

export type Controller = typeof(Debug.start())
return Debug
