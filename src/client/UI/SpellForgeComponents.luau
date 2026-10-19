--!strict
-- Shared building blocks for every spell UI screen (forge, home, library,
-- training, dialogs). Colors come from SpellForgeTheme; glyphs are limited to
-- ones the Gotham font renders.
local C = require(script.Parent.SpellForgeTheme).C
local K = { C = C }

local CategoryColor = {
	Impact = C.Ember,
	Support = C.Verdant,
	Control = C.Arcane,
	Detection = C.Frost,
	Movement = C.Frost,
	Temporal = C.Arcane,
	["World interaction"] = C.Gold,
	Summoning = C.Blood,
}

local ElementColor = {
	Fire = Color3.fromRGB(240, 120, 60),
	Water = Color3.fromRGB(80, 150, 230),
	Ice = Color3.fromRGB(160, 220, 245),
	Frost = Color3.fromRGB(160, 220, 245),
	Lightning = Color3.fromRGB(245, 225, 110),
	Earth = Color3.fromRGB(170, 130, 80),
	Wind = Color3.fromRGB(170, 230, 190),
	Air = Color3.fromRGB(170, 230, 190),
	Light = Color3.fromRGB(255, 236, 170),
	Dark = Color3.fromRGB(150, 90, 200),
	Shadow = Color3.fromRGB(150, 90, 200),
	Blood = Color3.fromRGB(200, 40, 60),
	Nature = Color3.fromRGB(120, 200, 110),
	Poison = Color3.fromRGB(150, 210, 80),
}

local FormIcon = {
	Projectile = "→",
	Beam = "—",
	Wave = "~",
	Field = "○",
	Aura = "*",
	SelfEnhancement = "▲",
	Construct = "■",
	Manipulation = "◇",
}
local FormVerb = {
	Projectile = "Launch a projectile",
	Beam = "Fire a beam",
	Wave = "Send out a wave",
	Field = "Create a field",
	Aura = "Surround yourself with an aura",
	SelfEnhancement = "Empower yourself",
	Construct = "Build a construct",
	Manipulation = "Manipulate the world",
}

local PayloadIcon = {
	Damage = "×",
	DamageOverTime = "~",
	Force = "→",
	Heal = "+",
	Restoration = "↑",
	Shield = "■",
	ModifyAttribute = "±",
	Transformation = "◇",
	Slow = "▼",
	Bind = "□",
	Reveal = "○",
	Control = "◆",
	Displacement = "←",
	TimeDilation = "◀",
	Enhancement = "▲",
	AerialMovement = "↑",
	Manipulation = "◇",
	Summon = "●",
	ElementalMark = "*",
	ConsumeElementalMark = "!",
}
local PayloadVerb = {
	Damage = "Deal damage",
	DamageOverTime = "Damage over time",
	Force = "Push or pull targets",
	Heal = "Heal",
	Restoration = "Restore resources",
	Shield = "Grant a shield",
	ModifyAttribute = "Change an attribute",
	Transformation = "Transform the target",
	Slow = "Slow targets",
	Bind = "Bind in place",
	Reveal = "Reveal targets",
	Control = "Take control",
	Displacement = "Displace targets",
	TimeDilation = "Bend time",
	Enhancement = "Empower the caster",
	AerialMovement = "Take flight",
	Manipulation = "Manipulate matter",
	Summon = "Summon a companion",
	ElementalMark = "Mark with an element",
	ConsumeElementalMark = "Detonate a mark",
}

local EventPhrase = {
	OnCast = "As it is cast",
	OnSpawn = "When it appears",
	OnImpact = "When it hits",
	OnProximity = "When a target comes close",
	OnDamageDealt = "After it deals damage",
	OnDamageTaken = "When you take damage",
	OnMeleeHit = "When your melee hit lands",
	OnHolderDealtDamage = "When the holder deals spell damage",
	OnThreshold = "When a target's health drops past a threshold",
	OnBreak = "When the shield breaks",
	OnTargetDeath = "When a target dies",
	OnCasterDeath = "When you die",
	OnCommand = "When you give a command",
	OnEnter = "When a target enters",
	OnExit = "When a target leaves",
	OnInterval = "Every interval",
	OnTick = "Every pulse",
	OnExpire = "When it ends",
}

local function fmt(value)
	if type(value) ~= "number" then
		return tostring(value)
	end
	if math.abs(value - math.round(value)) < 1e-4 then
		return tostring(math.round(value))
	end
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	return (string.gsub(text, "%.$", ""))
end

local function new(class, props, parent)
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function corner(gui, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, gui)
end

local function stroke(gui, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, gui)
end

local function pad(gui, x, y)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
	}, gui)
end

local function text(parent, value, size, color, font, props)
	local item = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size or 14,
		TextColor3 = color or C.Ink,
		Font = font or Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
	for key, v in props or {} do
		item[key] = v
	end
	return item
end

local function hover(buttonGui, base, over)
	buttonGui.MouseEnter:Connect(function()
		buttonGui.BackgroundColor3 = over
	end)
	buttonGui.MouseLeave:Connect(function()
		buttonGui.BackgroundColor3 = base
	end)
end

local function pill(parent, label, callback, style)
	local accent = style == "accent"
	local danger = style == "danger"
	local base = if accent then C.Ember elseif danger then Color3.fromRGB(60, 26, 30) else C.Card
	local item = new("TextButton", {
		Text = label,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = if accent then Color3.fromRGB(255, 244, 230) elseif danger then C.Error else C.Ink,
		BackgroundColor3 = base,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, parent)
	corner(item, 8)
	stroke(item, if accent then C.Gold elseif danger then C.Blood else C.PanelEdge, 1, if accent then 0.3 else 0)
	hover(
		item,
		base,
		if accent then Color3.fromRGB(232, 116, 74) elseif danger then Color3.fromRGB(84, 32, 38) else C.CardHover
	)
	item.Activated:Connect(callback)
	return item
end

local function list(parent, padding, horizontal)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
	}, parent)
end

local function clearChildren(frame, keepClass)
	for _, child in frame:GetChildren() do
		if not (keepClass and child:IsA(keepClass)) and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

K.CategoryColor = CategoryColor
K.ElementColor = ElementColor
K.FormIcon = FormIcon
K.FormVerb = FormVerb
K.PayloadIcon = PayloadIcon
K.PayloadVerb = PayloadVerb
K.EventPhrase = EventPhrase
K.fmt = fmt
K.new = new
K.corner = corner
K.stroke = stroke
K.pad = pad
K.text = text
K.hover = hover
K.pill = pill
K.list = list
K.clearChildren = clearChildren

-- Toggle styled as a pill switch.
function K.switch(parent, on, callback)
	local item = pill(parent, if on then "ON" else "OFF", function()
		callback(not on)
	end)
	item.BackgroundColor3 = if on then C.Ember else C.Input
	item.TextColor3 = if on then Color3.fromRGB(255, 244, 230) else C.Muted
	return item
end

-- Wrapping chip row; the active value is gold. `labeler` formats values.
function K.chips(parent, values, current, onPick, labeler, available)
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, parent)
	local layout = list(holder, 6, true)
	layout.Wraps = true
	for index, value in values do
		local active = value == current
		local enabled = available == nil or available(value)
		local chip = new("TextButton", {
			Text = if labeler then labeler(value) else tostring(value),
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextColor3 = if active then C.Backdrop elseif enabled then C.Ink else C.Faint,
			BackgroundColor3 = if active then C.Gold else C.Input,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			LayoutOrder = index,
		}, holder)
		corner(chip, 16)
		stroke(chip, if active then C.Gold else C.PanelEdge)
		pad(chip, 12, 0)
		if not active and enabled then
			hover(chip, C.Input, C.CardHover)
			chip.Activated:Connect(function()
				onPick(value)
			end)
		end
	end
	return holder
end

-- One-line description of what a spell does, e.g. "On impact: Deal damage, Explode".
function K.sequence(definition, schema)
	local parts = {}
	for _, eventName in schema.EventOrder do
		local steps = definition.Triggers and definition.Triggers[eventName]
		if steps and #steps > 0 then
			local actions = {}
			for _, step in steps do
				if step.Behavior == "SpawnEffect" then
					table.insert(actions, "spawn " .. tostring(step.Effect and step.Effect.Form or "effect"))
				elseif step.Behavior then
					table.insert(actions, "explode")
				end
				for _, payload in step.Payloads or {} do
					if step.Behavior ~= "SpawnEffect" then
						table.insert(actions, string.lower(PayloadVerb[payload.Kind] or payload.Kind))
					end
				end
			end
			table.insert(parts, (EventPhrase[eventName] or eventName) .. ": " .. table.concat(actions, ", "))
		end
	end
	return if #parts > 0 then table.concat(parts, " · ") else "No effects yet"
end

return K
