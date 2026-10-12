--!strict
-- Lightweight procedural spell art, derived from an existing SpellSpec.
-- It previews form and element without claiming to simulate combat geometry.
local Theme = require(script.Parent.GrimoireTheme)
local VisualSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicVisualSpec)
local Visual = {}
local elementColors = {
	Neutral = Color3.fromRGB(221, 211, 177), Fire = Color3.fromRGB(239, 124, 67),
	Water = Color3.fromRGB(88, 172, 215), Ice = Color3.fromRGB(151, 220, 232),
	Lightning = Color3.fromRGB(235, 202, 89), Earth = Color3.fromRGB(174, 147, 97),
	Air = Color3.fromRGB(179, 213, 204), Light = Color3.fromRGB(248, 222, 163),
	Dark = Color3.fromRGB(158, 139, 199),
}
local effectMarks = {
	Damage = "✦", DamageOverTime = "✦", Heal = "+", Restoration = "+",
	Shield = "◇", Slow = "≈", Bind = "×", Reveal = "◉", Summon = "◆",
	Enhancement = "↑", AerialMovement = "↑", Displacement = "↗",
	Manipulation = "▰", TimeDilation = "◷", ElementalMark = "✧",
	ConsumeElementalMark = "✧",
}
local function shape(parent, size, position, color, round, transparency, rotation)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
	return frame
end
local function ring(parent, diameter, color, transparency)
	local circle = shape(parent, UDim2.fromScale(diameter, diameter), UDim2.fromScale(0.5, 0.43), color, true, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = transparency or 0
	stroke.Parent = circle
end
local function effects(spell)
	local kinds = {}
	for _, steps in pairs(spell.Triggers or {}) do
		for _, step in ipairs(steps) do
			for _, payload in ipairs(step.Payloads or {}) do
				if payload.Kind and not table.find(kinds, payload.Kind) then table.insert(kinds, payload.Kind) end
			end
		end
	end
	table.sort(kinds)
	return kinds
end
function Visual.render(parent, spell, compact)
	for _, child in ipairs(parent:GetChildren()) do child:Destroy() end
	parent.BackgroundColor3 = Theme.Binding
	parent.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = parent
	local color = elementColors[spell.Element] or elementColors.Neutral
	local visual = spell.Visual
	if visual then
		local palette = VisualSpec.PaletteDefinitions[visual.Palette]
		if palette then color = palette.Colors[1] end
		if typeof(visual.Color) == "Color3" then
			color = visual.Color
		end
	end
	local vignette = Instance.new("UIGradient")
	vignette.Rotation = 90
	vignette.Color = ColorSequence.new(Theme.Binding, Color3.fromRGB(20, 37, 34))
	vignette.Parent = parent
	local window = parent
	local art = Instance.new("Frame")
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, if compact then 0.5 else 0.43)
	art.Size = UDim2.fromScale(0.9, if compact then 0.9 else 0.74)
	art.BackgroundTransparency = 1
	art.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = art
	parent = art
	if not visual or visual.ParticleStyle ~= "None" then
		for i = 1, 4 do
			shape(parent, UDim2.fromOffset(if visual and visual.ParticleStyle == "Smoke" then 5 else 2,
				if visual and visual.ParticleStyle == "Smoke" then 5 else 2),
				UDim2.fromScale(0.13 + i * 0.18, 0.16 + (i % 2) * 0.52),
				if visual and visual.ParticleStyle == "Embers" then color else Theme.Page, true, 0.55)
		end
	end
	local form = spell.Form
	if form == "Projectile" then
		if not visual or visual.TrailStyle ~= "None" then
			shape(parent, UDim2.fromScale(0.5, 0.025), UDim2.fromScale(0.44, 0.49), color, true, 0.42, -15)
		end
		ring(parent, 0.44, color, 0.57)
		local coreShape = visual and visual.CoreShape or "Sphere"
		local round = coreShape == "Sphere" or coreShape == "Cylinder"
		local rotation = if coreShape == "Crystal" or coreShape == "Wedge" then 45 else 0
		shape(parent, UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.58, 0.43), color, round, 0, rotation)
		shape(parent, UDim2.fromScale(0.11, 0.11), UDim2.fromScale(0.58, 0.43), Theme.Page, round, 0.12, rotation)
	elseif form == "Beam" then
		shape(parent, UDim2.fromScale(0.77, 0.14), UDim2.fromScale(0.5, 0.43), color, true, 0.32, -24)
		shape(parent, UDim2.fromScale(0.77, 0.045), UDim2.fromScale(0.5, 0.43), Theme.Page, true, 0.1, -24)
	elseif form == "Wave" then
		for i = 1, 3 do ring(parent, 0.25 + i * 0.16, color, 0.1 + i * 0.18) end
		shape(parent, UDim2.fromScale(0.11, 0.11), UDim2.fromScale(0.5, 0.43), Theme.Page, true)
	elseif form == "Field" then
		for i = 1, 3 do
			local square = shape(parent, UDim2.fromScale(0.2 + i * 0.14, 0.2 + i * 0.14),
				UDim2.fromScale(0.5, 0.43), color, false, 1, 25)
			local stroke = Instance.new("UIStroke")
			stroke.Color, stroke.Thickness, stroke.Transparency = color, 2, i * 0.17
			stroke.Parent = square
		end
	elseif form == "Aura" then
		ring(parent, 0.62, color, 0.05)
		ring(parent, 0.39, Theme.Page, 0.15)
		shape(parent, UDim2.fromScale(0.17, 0.17), UDim2.fromScale(0.5, 0.43), color, true)
	elseif form == "SelfEnhancement" then
		shape(parent, UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.5, 0.43), color, false, 0.18, 45)
		shape(parent, UDim2.fromScale(0.17, 0.17), UDim2.fromScale(0.5, 0.43), Theme.Page, false, 0, 45)
		ring(parent, 0.66, color, 0.28)
	elseif form == "Construct" then
		for i = 1, 3 do
			shape(parent, UDim2.fromScale(0.48 - i * 0.09, 0.38 - i * 0.06),
				UDim2.fromScale(0.5, 0.32 + i * 0.07), color, false, 0.24 + i * 0.12, 45)
		end
	elseif form == "Manipulation" then
		for i = 1, 3 do
			shape(parent, UDim2.fromScale(0.5 - i * 0.07, 0.065),
				UDim2.fromScale(0.5, 0.25 + i * 0.15), color, false, 0.1 + i * 0.13)
		end
	else
		ring(parent, 0.55, color, 0)
	end
	local names = effects(spell)
	if names[1] then
		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.76, 0.73)
		badge.Size = UDim2.fromScale(0.24, 0.24)
		badge.BackgroundColor3 = Theme.Gold
		badge.TextColor3 = Theme.Page
		badge.Text = effectMarks[names[1]] or "✧"
		badge.TextScaled = true
		badge.Font = Enum.Font.GothamBold
		badge.Parent = parent
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent = badge
	end
	if not compact then
		local caption = Instance.new("TextLabel")
		caption.BackgroundTransparency = 1
		caption.Position = UDim2.fromScale(0.04, 0.78)
		caption.Size = UDim2.fromScale(0.92, 0.18)
		caption.Text = tostring(form) .. "  ·  " .. tostring(spell.Element)
			.. (names[1] and "  ·  " .. table.concat(names, " + ") or "")
			.. (visual and "\n" .. tostring(visual.CoreShape or "Sphere") .. " · "
				.. tostring(visual.ParticleStyle or "Sparks") .. " · " .. tostring(visual.TrailStyle or "Ribbon") or "")
		caption.TextColor3 = Theme.Page
		caption.TextSize = 11
		caption.Font = Enum.Font.GothamSemibold
		caption.TextWrapped = true
		caption.Parent = window
	end
end
return Visual
