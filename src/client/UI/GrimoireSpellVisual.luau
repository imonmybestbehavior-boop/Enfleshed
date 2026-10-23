--!strict
-- Lightweight procedural spell art, derived from an existing SpellSpec.
-- It previews form and element without claiming to simulate combat geometry.
-- Spell art draws light marks on a dark plate in the Spell Forge palette.
local Forge = require(script.Parent.SpellForgeTheme).C
local Theme = {
	Binding = Color3.fromRGB(16, 13, 19),
	Page = Forge.Ink,
	Gold = Forge.Gold,
	PageEdge = Forge.PanelEdge,
}
local Shared = game:GetService("ReplicatedStorage").Shared
local VisualSpec = require(Shared.Modules.MagicVisualSpec)
local ElementColors = require(Shared.Configuration.MagicElements)
local Analyzer = require(Shared.SpellVFXSystem.Core.SpellVFXAnalyzer)
local Visual = {}
local elementSecondaries = {
	Neutral = Color3.fromRGB(235, 225, 190),
	Fire = Color3.fromRGB(255, 210, 92),
	Water = Color3.fromRGB(174, 239, 235),
	Ice = Color3.fromRGB(235, 255, 255),
	Lightning = Color3.fromRGB(255, 246, 155),
	Earth = Color3.fromRGB(198, 190, 131),
	Wind = Color3.fromRGB(229, 255, 238),
	Poison = Color3.fromRGB(211, 245, 103),
}
local effectLabels = {
	Damage = "DMG",
	DamageOverTime = "DOT",
	Heal = "HEAL",
	Restoration = "HEAL",
	Shield = "WARD",
	Slow = "SLOW",
	Bind = "BIND",
	Reveal = "SEEK",
	Summon = "ALLY",
	Enhancement = "BOOST",
	AerialMovement = "FLIGHT",
	Displacement = "PUSH",
	Manipulation = "MOVE",
	TimeDilation = "TIME",
	ElementalMark = "MARK",
	ConsumeElementalMark = "BURST",
	Stun = "STUN",
	Silence = "HUSH",
	Cleanse = "PURGE",
	Taunt = "TAUNT",
	Fear = "FEAR",
	Stealth = "HIDE",
	DrainResource = "DRAIN",
	RestoreResource = "MANA",
}
local effectOrder = {
	Damage = 1,
	DamageOverTime = 2,
	Heal = 3,
	Restoration = 4,
	Shield = 5,
	Bind = 6,
	Slow = 7,
	Displacement = 8,
	Manipulation = 9,
	Summon = 10,
	Enhancement = 11,
	AerialMovement = 12,
	Reveal = 13,
	TimeDilation = 14,
	ElementalMark = 15,
	ConsumeElementalMark = 16,
	Stun = 17,
	Silence = 18,
	Cleanse = 19,
	Taunt = 20,
	Fear = 21,
	Stealth = 22,
	DrainResource = 23,
	RestoreResource = 24,
}
local behaviorLabels = {
	Homing = "HOME",
	Chain = "CHAIN",
	Bounce = "BOUNCE",
	Split = "SPLIT",
	Pierce = "PIERCE",
	Orbit = "ORBIT",
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
local function outline(parent, size, position, color, transparency, rounded, rotation)
	local frame = shape(parent, size, position, color, rounded, 1, rotation)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = transparency or 0
	stroke.Parent = frame
	return frame
end
local function drawElementMotif(parent, element, color, accent)
	-- Small, repeatable marks make the element legible even when several spells
	-- share a Form. They are vector UI parts, so cards and live previews match.
	if element == "Fire" then
		shape(parent, UDim2.fromScale(0.045, 0.15), UDim2.fromScale(0.2, 0.28), accent, false, 0.02, 28)
		shape(parent, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.82, 0.55), color, false, 0.08, -32)
		shape(parent, UDim2.fromScale(0.035, 0.1), UDim2.fromScale(0.32, 0.77), accent, false, 0.16, 24)
	elseif element == "Water" then
		outline(parent, UDim2.fromScale(0.1, 0.14), UDim2.fromScale(0.18, 0.29), accent, 0.08, true)
		outline(parent, UDim2.fromScale(0.07, 0.1), UDim2.fromScale(0.84, 0.27), color, 0.12, true)
		shape(parent, UDim2.fromScale(0.2, 0.025), UDim2.fromScale(0.2, 0.68), accent, true, 0.08, -12)
	elseif element == "Ice" then
		shape(parent, UDim2.fromScale(0.075, 0.16), UDim2.fromScale(0.18, 0.29), accent, false, 0.02, 45)
		shape(parent, UDim2.fromScale(0.065, 0.14), UDim2.fromScale(0.83, 0.28), color, false, 0.05, 45)
		shape(parent, UDim2.fromScale(0.06, 0.14), UDim2.fromScale(0.82, 0.67), accent, false, 0.16, 45)
	elseif element == "Lightning" then
		for index = 1, 3 do
			local x = 0.15 + index * 0.075
			shape(
				parent,
				UDim2.fromScale(0.035, 0.12),
				UDim2.fromScale(x, 0.24 + index * 0.04),
				accent,
				false,
				0.02,
				28
			)
			shape(
				parent,
				UDim2.fromScale(0.035, 0.12),
				UDim2.fromScale(x + 0.045, 0.32 + index * 0.04),
				color,
				false,
				0.06,
				-28
			)
		end
	elseif element == "Earth" then
		shape(parent, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.18, 0.31), color, false, 0.04, 12)
		shape(parent, UDim2.fromScale(0.08, 0.09), UDim2.fromScale(0.83, 0.28), accent, false, 0.08, 35)
		shape(parent, UDim2.fromScale(0.12, 0.08), UDim2.fromScale(0.82, 0.67), color, false, 0.14, -18)
	elseif element == "Wind" then
		outline(parent, UDim2.fromScale(0.2, 0.065), UDim2.fromScale(0.2, 0.27), accent, 0.04, true, -18)
		outline(parent, UDim2.fromScale(0.16, 0.05), UDim2.fromScale(0.82, 0.66), color, 0.12, true, -18)
		shape(parent, UDim2.fromScale(0.1, 0.035), UDim2.fromScale(0.19, 0.72), accent, true, 0.12, 12)
	elseif element == "Poison" then
		outline(parent, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.18, 0.29), accent, 0.06, true)
		outline(parent, UDim2.fromScale(0.07, 0.07), UDim2.fromScale(0.83, 0.28), color, 0.1, true)
		shape(parent, UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.83, 0.68), color, true, 0.36)
	else
		ring(parent, 0.14, color, 0.2)
		shape(parent, UDim2.fromScale(0.045, 0.045), UDim2.fromScale(0.82, 0.28), accent, false, 0.04, 45)
	end
end
local function drawAreaGeometry(parent, geometry, color, secondary)
	if geometry == "Ring" then
		ring(parent, 0.78, color, 0.08)
		ring(parent, 0.38, secondary, 0.02)
	elseif geometry == "Capsule" then
		outline(parent, UDim2.fromScale(0.36, 0.68), UDim2.fromScale(0.5, 0.43), color, 0.05, true)
		shape(parent, UDim2.fromScale(0.12, 0.48), UDim2.fromScale(0.5, 0.43), secondary, true, 0.12)
	elseif geometry == "Cylinder" then
		outline(parent, UDim2.fromScale(0.46, 0.58), UDim2.fromScale(0.5, 0.43), color, 0.08, false)
		outline(parent, UDim2.fromScale(0.46, 0.19), UDim2.fromScale(0.5, 0.16), secondary, 0.04, true)
		outline(parent, UDim2.fromScale(0.46, 0.19), UDim2.fromScale(0.5, 0.70), color, 0.2, true)
	elseif geometry == "Cone" then
		for index = 1, 5 do
			local width = 0.12 + index * 0.105
			local band = shape(
				parent,
				UDim2.fromScale(width, 0.035),
				UDim2.fromScale(0.5, 0.18 + index * 0.105),
				if index == 5 then secondary else color,
				true,
				0.12 + index * 0.08
			)
			band.Rotation = 0
		end
	elseif geometry == "Plane" then
		outline(parent, UDim2.fromScale(0.72, 0.24), UDim2.fromScale(0.5, 0.43), color, 0.05, false)
		shape(parent, UDim2.fromScale(0.62, 0.04), UDim2.fromScale(0.5, 0.43), secondary, true, 0.08)
	elseif geometry == "Line" then
		outline(parent, UDim2.fromScale(0.18, 0.72), UDim2.fromScale(0.5, 0.43), color, 0.02, true, -25)
		shape(parent, UDim2.fromScale(0.08, 0.62), UDim2.fromScale(0.5, 0.43), secondary, true, 0.08, -25)
	elseif geometry == "Box" then
		outline(parent, UDim2.fromScale(0.64, 0.48), UDim2.fromScale(0.5, 0.43), color, 0.04, false)
		shape(parent, UDim2.fromScale(0.5, 0.04), UDim2.fromScale(0.5, 0.43), secondary, true, 0.05)
	else
		ring(parent, 0.72, color, 0.08)
		ring(parent, 0.44, secondary, 0.12)
	end
end
local function drawConstructGeometry(parent, geometry, color, secondary)
	if geometry == "Arch" then
		shape(parent, UDim2.fromScale(0.13, 0.52), UDim2.fromScale(0.30, 0.47), color, false, 0.04)
		shape(parent, UDim2.fromScale(0.13, 0.52), UDim2.fromScale(0.70, 0.47), color, false, 0.04)
		shape(parent, UDim2.fromScale(0.53, 0.13), UDim2.fromScale(0.5, 0.20), secondary, false, 0.05)
	elseif geometry == "Pillar" then
		shape(parent, UDim2.fromScale(0.48, 0.12), UDim2.fromScale(0.5, 0.19), secondary, false, 0.03)
		shape(parent, UDim2.fromScale(0.32, 0.52), UDim2.fromScale(0.5, 0.46), color, false, 0.05)
		shape(parent, UDim2.fromScale(0.52, 0.12), UDim2.fromScale(0.5, 0.73), secondary, false, 0.03)
	elseif geometry == "Stairs" then
		for index = 1, 4 do
			shape(
				parent,
				UDim2.fromScale(0.25 + index * 0.1, 0.08),
				UDim2.fromScale(0.5, 0.70 - index * 0.12),
				if index % 2 == 0 then secondary else color,
				false,
				0.03
			)
		end
	elseif geometry == "Bridge" then
		shape(parent, UDim2.fromScale(0.72, 0.16), UDim2.fromScale(0.5, 0.53), color, false, 0.04)
		shape(parent, UDim2.fromScale(0.72, 0.06), UDim2.fromScale(0.5, 0.34), secondary, false, 0.04)
		shape(parent, UDim2.fromScale(0.06, 0.22), UDim2.fromScale(0.19, 0.43), color, false, 0.04)
		shape(parent, UDim2.fromScale(0.06, 0.22), UDim2.fromScale(0.81, 0.43), color, false, 0.04)
	else
		local round = geometry == "Sphere" or geometry == "Cylinder"
		local rotation = if geometry == "Wedge" then 45 else 0
		shape(parent, UDim2.fromScale(0.52, 0.42), UDim2.fromScale(0.5, 0.43), color, round, 0.08, rotation)
		shape(parent, UDim2.fromScale(0.25, 0.2), UDim2.fromScale(0.5, 0.43), secondary, round, 0.08, rotation)
	end
end
local function effects(spell)
	local kinds = {}
	for _, steps in pairs(spell.Triggers or {}) do
		for _, step in ipairs(steps) do
			for _, payload in ipairs(step.Payloads or {}) do
				if payload.Kind and not table.find(kinds, payload.Kind) then
					table.insert(kinds, payload.Kind)
				end
			end
		end
	end
	table.sort(kinds, function(first, second)
		local firstOrder, secondOrder = effectOrder[first] or math.huge, effectOrder[second] or math.huge
		return if firstOrder == secondOrder then first < second else firstOrder < secondOrder
	end)
	return kinds
end
local function features(spell, effectNames)
	local result = {}
	for _, name in ipairs(effectNames) do
		local label = effectLabels[name]
		if label and not table.find(result, label) then
			table.insert(result, label)
		end
	end
	for _, behavior in ipairs((spell.Projectile and spell.Projectile.Behaviors) or {}) do
		local label = behaviorLabels[behavior.Kind]
		if label and not table.find(result, label) then
			table.insert(result, label)
		end
	end
	return result
end
function Visual.render(parent, spell, compact)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
	parent.BackgroundColor3 = Theme.Binding
	parent.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = parent
	local composition = Analyzer.resolve(spell)
	local color = ElementColors[composition.Element] or ElementColors.Neutral
	local secondary = elementSecondaries[spell.Element] or Color3.fromRGB(255, 244, 212)
	local accent = secondary
	local visual = spell.Visual
	if visual then
		local useElementDefaults = visual.Palette == "Origin" and visual.Color == VisualSpec.Defaults.Color
		local palette = VisualSpec.PaletteDefinitions[visual.Palette]
		if palette then
			color, secondary, accent = palette.Colors[1], palette.Colors[2], palette.Colors[3]
		end
		-- Untouched Origin defaults mean "use this spell's element". Explicit
		-- palette and custom color choices remain authoritative.
		if useElementDefaults then
			color = ElementColors[spell.Element] or ElementColors.Neutral
			secondary = elementSecondaries[spell.Element] or secondary
			accent = secondary
		end
		if typeof(visual.Color) == "Color3" and not useElementDefaults then
			color = visual.Color
		end
		if typeof(visual.SecondaryColor) == "Color3" and not useElementDefaults then
			secondary = visual.SecondaryColor
		end
		if typeof(visual.AccentColor) == "Color3" and not useElementDefaults then
			accent = visual.AccentColor
		end
	end
	local vignette = Instance.new("UIGradient")
	vignette.Rotation = 90
	vignette.Color = ColorSequence.new(Theme.Binding, Color3.fromRGB(10, 9, 12))
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
	drawElementMotif(parent, composition.Element, color, accent)
	if not visual or visual.ParticleStyle ~= "None" then
		for i = 1, 4 do
			shape(
				parent,
				UDim2.fromOffset(
					if visual and visual.ParticleStyle == "Smoke" then 5 else 2,
					if visual and visual.ParticleStyle == "Smoke" then 5 else 2
				),
				UDim2.fromScale(0.13 + i * 0.18, 0.16 + (i % 2) * 0.52),
				if visual and visual.ParticleStyle == "Embers" then color else Theme.Page,
				true,
				0.55
			)
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
		shape(parent, UDim2.fromScale(0.11, 0.11), UDim2.fromScale(0.58, 0.43), accent, round, 0.12, rotation)
	elseif form == "Beam" then
		shape(parent, UDim2.fromScale(0.77, 0.14), UDim2.fromScale(0.5, 0.43), color, true, 0.32, -24)
		shape(parent, UDim2.fromScale(0.77, 0.045), UDim2.fromScale(0.5, 0.43), Theme.Page, true, 0.1, -24)
	elseif form == "Wave" then
		for i = 1, 3 do
			ring(parent, 0.25 + i * 0.16, if i == 3 then secondary else color, 0.1 + i * 0.18)
		end
		if spell.Geometry == "Sphere" then
			drawAreaGeometry(parent, "Sphere", color, secondary)
		else
			shape(parent, UDim2.fromScale(0.11, 0.11), UDim2.fromScale(0.5, 0.43), accent, true)
		end
	elseif form == "Field" then
		drawAreaGeometry(parent, spell.Geometry or "Sphere", color, secondary)
	elseif form == "Aura" then
		drawAreaGeometry(parent, spell.Geometry or "Sphere", color, secondary)
		shape(parent, UDim2.fromScale(0.16, 0.16), UDim2.fromScale(0.5, 0.43), accent, true)
	elseif form == "SelfEnhancement" then
		shape(parent, UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.5, 0.43), color, false, 0.18, 45)
		shape(parent, UDim2.fromScale(0.17, 0.17), UDim2.fromScale(0.5, 0.43), Theme.Page, false, 0, 45)
		ring(parent, 0.66, color, 0.28)
	elseif form == "Construct" then
		drawConstructGeometry(parent, spell.Geometry or "Box", color, secondary)
	elseif form == "Manipulation" then
		for i = 1, 3 do
			shape(
				parent,
				UDim2.fromScale(0.5 - i * 0.07, 0.065),
				UDim2.fromScale(0.5, 0.25 + i * 0.15),
				color,
				false,
				0.1 + i * 0.13
			)
		end
	else
		ring(parent, 0.55, color, 0)
	end
	local names = effects(spell)
	local featureLabels = features(spell, names)
	for index = 1, math.min(#featureLabels, 2) do
		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(if index == 1 then 0.72 else 0.28, 0.78)
		badge.Size = UDim2.fromScale(0.38, 0.13)
		badge.BackgroundColor3 = Theme.Gold
		badge.BorderSizePixel = 0
		badge.TextColor3 = Theme.Page
		badge.Text = featureLabels[index]
		badge.TextScaled = true
		badge.Font = Enum.Font.GothamBold
		badge.ZIndex = 3
		badge.Parent = parent
		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = Theme.PageEdge
		badgeStroke.Thickness = 1
		badgeStroke.Parent = badge
	end
	if not compact then
		local caption = Instance.new("TextLabel")
		caption.BackgroundTransparency = 1
		caption.Position = UDim2.fromScale(0.04, 0.78)
		caption.Size = UDim2.fromScale(0.92, 0.18)
		caption.Text = tostring(form)
			.. "  ·  "
			.. tostring(spell.Element)
			.. (names[1] and "  ·  " .. table.concat(names, " + ") or "")
			.. (
				visual
					and "\n" .. tostring(spell.Geometry or visual.CoreShape or "Sphere") .. " · " .. tostring(
						visual.ParticleStyle or "Sparks"
					) .. " · " .. tostring(visual.TrailStyle or "Ribbon")
				or ""
			)
		caption.TextColor3 = Theme.Page
		caption.TextSize = 11
		caption.Font = Enum.Font.GothamSemibold
		caption.TextWrapped = true
		caption.Parent = window
	end
end
return Visual
