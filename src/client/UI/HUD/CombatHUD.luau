--!strict
-- Bottom-centre vitals, stacked just above the spell bar: level badge, Health
-- (widest, with current/max), Mana beneath it, Strain as 10 pips that pulse red
-- near the cap. Also flashes the screen edges when the player takes damage.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local CombatHUD = {}
local Color = Theme.Color

function CombatHUD.new(gui: ScreenGui)
	local player = Players.LocalPlayer
	local root = C.root(gui)
	local health, mana = Theme.Size.HealthBar, Theme.Size.ManaBar
	local cluster = C.new("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0.5, 1),
		-- Sits directly above the spell bar (slot height + bottom margin + gap).
		Position = UDim2.new(0.5, 0, 1, -(16 + Theme.Size.Slot + 8)),
		Size = UDim2.fromOffset(health.X + Theme.Size.LevelBadge + 10, 44),
		BackgroundTransparency = 1,
	}, root)

	local badge = C.panel(cluster, {
		Name = "Level",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(Theme.Size.LevelBadge, Theme.Size.LevelBadge),
		Rotation = 0,
	})
	C.new("UIAspectRatioConstraint", { AspectRatio = 1 }, badge)
	C.text(badge, "LV", Theme.TextSize.Tiny, Color.Muted, Theme.Font.Strong, {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 12),
	})
	local level = C.text(badge, "1", Theme.TextSize.Label + 2, Color.Gold, Theme.Font.Number, {
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, 0, 1, -18),
	})

	local x = Theme.Size.LevelBadge + 10
	local healthBar = C.bar(cluster, health, Color.Health, true)
	healthBar.Frame.Position = UDim2.fromOffset(x, 4)
	local manaBar = C.bar(cluster, mana, Color.Mana, false)
	manaBar.Frame.Position = UDim2.fromOffset(x, 4 + health.Y + 5)
	local manaText = C.text(cluster, "", Theme.TextSize.Tiny, Color.Mana, Theme.Font.Number, {
		Position = UDim2.fromOffset(x + mana.X + 6, 4 + health.Y + 2),
		Size = UDim2.fromOffset(health.X - mana.X - 6, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Strain: segmented meter to the right of the health bar.
	local strain = C.new("Frame", {
		Name = "Strain",
		Position = UDim2.fromOffset(x + health.X + 8, 4),
		Size = UDim2.fromOffset(Theme.Size.StrainPips * 9, health.Y + 16),
		BackgroundTransparency = 1,
	}, cluster)
	local pips: { Frame } = {}
	for index = 1, Theme.Size.StrainPips do
		local pip = C.new("Frame", {
			Position = UDim2.fromOffset((index - 1) * 9, 0),
			Size = UDim2.fromOffset(7, health.Y),
			BackgroundColor3 = Color.Track,
			BackgroundTransparency = Theme.Transparency.Track,
			BorderSizePixel = 0,
		}, strain)
		C.new("UIStroke", { Color = Color.Brass, Transparency = 0.55 }, pip)
		pips[index] = pip
	end
	C.text(strain, "STRAIN", Theme.TextSize.Tiny, Color.Strain, Theme.Font.Strong, {
		Position = UDim2.fromOffset(0, health.Y + 2),
		Size = UDim2.new(1, 0, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Edge flash on hit: four gradients hugging the screen border.
	local flash = C.new("Frame", {
		Name = "HitFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
	}, gui)
	local edges: { Frame } = {}
	for _, side in { 0, 90, 180, 270 } do
		local vertical = side == 0 or side == 180
		local edge = C.new("Frame", {
			AnchorPoint = Vector2.new(if side == 180 then 1 else 0, if side == 270 then 1 else 0),
			Position = UDim2.fromScale(if side == 180 then 1 else 0, if side == 270 then 1 else 0),
			Size = if vertical then UDim2.fromScale(0.12, 1) else UDim2.fromScale(1, 0.14),
			BackgroundColor3 = Color.Health,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, flash)
		C.new("UIGradient", {
			Rotation = side,
			Transparency = NumberSequence.new(0, 1),
		}, edge)
		edges[#edges + 1] = edge
	end
	-- Rotation per side: 0 fades left→right, 180 right→left, 90 top→bottom, 270 bottom→top.
	local function hit(strength: number)
		for _, edge in edges do
			edge.BackgroundTransparency = math.clamp(1 - strength, 0.35, 0.85)
			TweenService:Create(edge, Theme.Motion.Flash, { BackgroundTransparency = 1 }):Play()
		end
	end

	local lastHealth: number? = nil
	local humanoidLinks: { RBXScriptConnection } = {}
	local function watch(character: Model)
		for _, link in humanoidLinks do
			link:Disconnect()
		end
		table.clear(humanoidLinks)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		lastHealth = humanoid.Health
		local function update()
			local value, maximum = humanoid.Health, math.max(1, humanoid.MaxHealth)
			healthBar.Set(value / maximum, string.format("%d / %d", math.ceil(value), math.ceil(maximum)))
			if lastHealth and value < lastHealth - 0.5 then
				hit(math.clamp((lastHealth - value) / maximum * 4, 0.2, 0.65))
			end
			lastHealth = value
		end
		table.insert(humanoidLinks, humanoid.HealthChanged:Connect(update))
		table.insert(humanoidLinks, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update))
		update()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	local function updateMana()
		local value, capacity = player:GetAttribute("MagicMana"), player:GetAttribute("MagicCapacity")
		if type(value) == "number" and type(capacity) == "number" and capacity > 0 then
			manaBar.Set(value / capacity)
			manaText.Text = string.format("%d / %d", math.floor(value), math.floor(capacity))
		else
			manaText.Text = "…"
		end
	end
	local strainRatio = 0
	local function updateStrain()
		local value, tolerance = player:GetAttribute("MagicStrain"), player:GetAttribute("MagicStrainTolerance")
		strainRatio = if type(value) == "number"
				and type(tolerance) == "number"
				and tolerance > 0
			then math.clamp(value / tolerance, 0, 1)
			else 0
		local lit = math.ceil(strainRatio * #pips - 0.001)
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= lit then Color.Strain else Color.Track
		end
	end
	for _, name in { "MagicMana", "MagicCapacity" } do
		player:GetAttributeChangedSignal(name):Connect(updateMana)
	end
	for _, name in { "MagicStrain", "MagicStrainTolerance" } do
		player:GetAttributeChangedSignal(name):Connect(updateStrain)
	end
	updateMana()
	updateStrain()

	local visible = true
	RunService.RenderStepped:Connect(function()
		cluster.Visible = visible and player:GetAttribute("MagicLabOpen") ~= true
		if strainRatio >= Theme.Motion.StrainPulseAt then
			local pulse = (math.sin(os.clock() * 8) + 1) / 2
			local tint = Color.Strain:Lerp(Color.StrainHot, pulse)
			for _, pip in pips do
				if pip.BackgroundColor3 ~= Color.Track then
					pip.BackgroundColor3 = tint
				end
			end
		end
	end)

	return {
		SetLevel = function(value: number)
			level.Text = tostring(value)
		end,
		SetVisible = function(value: boolean)
			visible = value
		end,
	}
end

return CombatHUD
