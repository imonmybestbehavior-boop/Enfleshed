--!nonstrict
-- App shell and Home screen for the spell UI, in the Spell Forge design.
-- Presentation only: the controller owns spell data, slots, and persistence.
local K = require(script.Parent.SpellForgeComponents)
local C = K.C
local new, corner, stroke, pad, text, pill, list, fmt = K.new, K.corner, K.stroke, K.pad, K.text, K.pill, K.list, K.fmt

local Hub = {}

local Tabs = {
	{ Id = "Home", Label = "HOME", Mobile = "HOME" },
	{ Id = "Library", Label = "LIBRARY", Mobile = "LIBRARY" },
	{ Id = "Forge", Label = "SPELL FORGE", Mobile = "FORGE" },
	{ Id = "Training", Label = "TRAINING", Mobile = "TRAIN" },
}
Hub.TabForPage = {
	Slots = "Home",
	Library = "Library",
	LibraryDetail = "Library",
	Editor = "Forge",
	Training = "Training",
	Help = "Help",
}

-- Restyles the controller's panel into the app shell. `ui` holds the existing
-- panel children (scroll, title, summary, status, navigation, close, home)
-- so controller code that writes to them keeps working.
function Hub.mountShell(panel, ui, onTab)
	panel.BackgroundColor3 = C.Backdrop
	panel.BorderSizePixel = 0
	corner(panel, 14)
	stroke(panel, C.PanelEdge, 1)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(28, 20, 26), Color3.fromRGB(10, 9, 12)),
		Rotation = 90,
	}, panel)
	local toolbar = new("Frame", {
		Name = "HubToolbar",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, panel)
	corner(toolbar, 12)
	stroke(toolbar, C.PanelEdge)
	local brand = text(toolbar, "◆  SPELLCRAFT", 15, C.Gold, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.fromOffset(170, 52),
		TextWrapped = false,
		ZIndex = 3,
	})
	local tabButtons = {}
	for _, tab in Tabs do
		local item = pill(toolbar, tab.Label, function()
			onTab(tab.Id)
		end)
		item.Name = "Tab_" .. tab.Id
		item.ZIndex = 3
		tabButtons[tab.Id] = item
	end
	local help = pill(toolbar, "?", function()
		onTab("Help")
	end)
	help.Name = "Tab_Help"
	help.ZIndex = 3
	tabButtons.Help = help
	local close = ui.closeButton
	close.Parent = toolbar
	close.Text = "×"
	close.TextSize = 20
	close.Font = Enum.Font.GothamBold
	close.BackgroundColor3 = C.Card
	close.TextColor3 = C.Ink
	close.AutoButtonColor = true
	close.ZIndex = 3
	corner(close, 8)
	stroke(close, C.PanelEdge)
	ui.homeButton.Visible = false
	ui.navigation.Visible = false

	local content = new("Frame", {
		Name = "HubContent",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, panel)
	corner(content, 12)
	stroke(content, C.PanelEdge)
	local title, summary, status, scroll = ui.title, ui.summary, ui.status, ui.scroll
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = C.Ink
	title.ZIndex = 3
	summary.Font = Enum.Font.Gotham
	summary.TextSize = 12
	summary.TextColor3 = C.Muted
	summary.ZIndex = 3
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 3
	scroll.ZIndex = 3
	scroll.ScrollBarImageColor3 = C.Rail
	scroll.BorderSizePixel = 0

	local active = "Home"
	local function layout(page)
		active = Hub.TabForPage[page] or active
		local width = panel.AbsoluteSize.X
		local mobile = width < 760
		local m = 10
		local barH = if mobile then 100 else 52
		toolbar.Position, toolbar.Size = UDim2.fromOffset(m, m), UDim2.new(1, -m * 2, 0, barH)
		brand.Visible = true
		brand.Position = UDim2.fromOffset(16, 0)
		brand.Size = UDim2.fromOffset(170, 52)
		close.Position, close.Size = UDim2.new(1, -48, 0, 8), UDim2.fromOffset(38, 36)
		help.Position, help.Size = UDim2.new(1, -94, 0, 8), UDim2.fromOffset(38, 36)
		local x, y = if mobile then 8 else 196, if mobile then 56 else 8
		local tabWidth = if mobile then (width - m * 2 - 16 - 6 * 3) / 4 else 128
		for _, tab in Tabs do
			local item = tabButtons[tab.Id]
			item.Text = if mobile then tab.Mobile else tab.Label
			item.Position = UDim2.fromOffset(x, y)
			item.Size = UDim2.fromOffset(tabWidth, 36)
			x += tabWidth + 6
		end
		for id, item in tabButtons do
			local on = id == active
			item.BackgroundColor3 = if on then C.Gold else C.Card
			item.TextColor3 = if on then C.Backdrop else C.Ink
		end
		local top = m + barH + 10
		title.Position, title.Size = UDim2.fromOffset(m + 8, top), UDim2.new(1, -m * 2 - 16, 0, 26)
		summary.Position, summary.Size = UDim2.fromOffset(m + 8, top + 26), UDim2.new(1, -m * 2 - 16, 0, 18)
		local contentTop = top + (if summary.Visible and summary.Text ~= "" then 50 else 34)
		content.Position = UDim2.fromOffset(m, contentTop)
		content.Size = UDim2.new(1, -m * 2, 1, -contentTop - m - (if status.Visible then 36 else 0))
		scroll.Position = UDim2.fromOffset(m + 12, contentTop + 12)
		scroll.Size = UDim2.new(1, -m * 2 - 24, 1, -contentTop - m - 24 - (if status.Visible then 36 else 0))
		status.Position, status.Size = UDim2.new(0, m + 8, 1, -m - 30), UDim2.new(1, -m * 2 - 16, 0, 28)
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layout(nil)
	end)
	layout("Slots")
	return layout
end

-- Spell card used on Home: form glyph, name, form · element, cost, sequence.
function Hub.spellCard(parent, definition, opts)
	local schema, spec = opts.Schema, opts.Spec
	local locked = opts.Locked
	local base = if locked then Color3.fromRGB(24, 21, 26) else C.Card
	local card = new("TextButton", {
		Name = opts.Name or "SpellCard",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = base,
		BorderSizePixel = 0,
		LayoutOrder = opts.Order or 0,
	}, parent)
	corner(card, 12)
	local edge = stroke(card, if opts.Selected then C.Gold else C.PanelEdge, if opts.Selected then 2 else 1)
	if not locked then
		K.hover(card, base, C.CardHover)
	end
	card.Activated:Connect(opts.OnClick)
	local accent = if definition then K.ElementColor[definition.Element] or C.Gold else C.Faint
	new("Frame", {
		Size = UDim2.new(0, 4, 1, -20),
		Position = UDim2.fromOffset(0, 10),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, card)
	local glyph = text(
		card,
		if definition then K.FormIcon[definition.Form] or "◆" elseif locked then "■" else "+",
		24,
		accent,
		Enum.Font.GothamBold,
		{
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(48, 48),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Input,
		}
	)
	corner(glyph, 24)
	stroke(glyph, accent, 1, 0.5)
	if opts.Number then
		local number = text(card, tostring(opts.Number), 11, C.Backdrop, Enum.Font.GothamBlack, {
			Name = "SlotNumber",
			Position = UDim2.fromOffset(48, 10),
			Size = UDim2.fromOffset(20, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Gold,
		})
		corner(number, 10)
	end
	local title = if definition then definition.Name elseif locked then "LOCKED SLOT" else "EMPTY SLOT"
	text(card, title, 15, if locked then C.Faint else C.Ink, Enum.Font.GothamBold, {
		Name = "SpellName",
		Position = UDim2.fromOffset(74, 12),
		Size = UDim2.new(1, -84 - (if opts.Badge then 64 else 0), 0, 20),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if opts.Badge then
		local badge = text(card, opts.Badge, 10, opts.BadgeColor or C.Gold, Enum.Font.GothamBlack, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 14),
			Size = UDim2.fromOffset(60, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Input,
		})
		corner(badge, 4)
	end
	local detail, cost, sequence
	if definition then
		local form = schema.Forms[definition.Form]
		detail = (form and form.Label or tostring(definition.Form)) .. "  ·  " .. tostring(definition.Element)
		local ok, estimate = pcall(spec.estimate, definition)
		cost = if ok and estimate
			then fmt(estimate.ManaDemand or 0) .. " mana  ·  " .. fmt(estimate.Strain or 0) .. " strain"
			else ""
		sequence = K.sequence(definition, schema)
	else
		detail = if locked then "Unlocks with more mission XP" else "Choose a spell from your library"
		cost, sequence = "", ""
	end
	text(card, detail, 12, C.Muted, Enum.Font.GothamMedium, {
		Position = UDim2.fromOffset(74, 33),
		Size = UDim2.new(1, -84, 0, 16),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	text(card, cost, 11, Color3.fromRGB(120, 170, 255), Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(74, 50),
		Size = UDim2.new(1, -84, 0, 14),
		TextWrapped = false,
	})
	text(card, sequence, 11, C.Faint, Enum.Font.Gotham, {
		Name = "Sequence",
		Position = UDim2.fromOffset(14, 72),
		Size = UDim2.new(1, -28, 1, -78),
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	return card, edge
end

-- Home: quick actions plus the nine equipped slots.
-- data = { Slots = {{Number, Spell, Locked, Draft, Selected}}, ResumeDraft = bool }
-- actions = { create, library, training, openSlot(number) }
function Hub.home(scroll, data, actions, schema, spec)
	local root = new("Frame", {
		Name = "HubHome",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, scroll)
	list(root, 14)
	local quick = new("Frame", {
		Name = "QuickActions",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, root)
	local quickGrid = new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, quick)
	local function action(order, icon, color, title, blurb, callback, name)
		local item = new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.Card,
			LayoutOrder = order,
		}, quick)
		corner(item, 12)
		stroke(item, if order == 1 then C.Gold else C.PanelEdge, 1, if order == 1 then 0.3 else 0)
		K.hover(item, C.Card, C.CardHover)
		item.Activated:Connect(callback)
		local glyph = text(item, icon, 22, color, Enum.Font.GothamBold, {
			Position = UDim2.new(0, 14, 0.5, -22),
			Size = UDim2.fromOffset(44, 44),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Input,
		})
		corner(glyph, 22)
		stroke(glyph, color, 1, 0.5)
		text(item, title, 15, C.Ink, Enum.Font.GothamBold, {
			Position = UDim2.fromOffset(70, 14),
			Size = UDim2.new(1, -80, 0, 20),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		text(item, blurb, 12, C.Muted, Enum.Font.Gotham, {
			Position = UDim2.fromOffset(70, 36),
			Size = UDim2.new(1, -80, 1, -42),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	action(
		1,
		"+",
		C.Ember,
		"NEW SPELL",
		"Open the Spell Forge with a starter projectile.",
		actions.create,
		"CreateNewSpell"
	)
	if data.ResumeDraft then
		action(
			4,
			"»",
			C.Warn,
			"RESUME DRAFT",
			"Pick up the unsaved spell you were forging.",
			actions.resume,
			"ResumeDraft"
		)
	end
	action(
		2,
		"■",
		C.Gold,
		"SPELL LIBRARY",
		"Browse, edit, duplicate, and equip saved spells.",
		actions.library,
		"OpenLibrary"
	)
	action(
		3,
		"●",
		C.Frost,
		"TRAINING & TARGETS",
		"Spawn dummies, reset resources, and sandbox controls.",
		actions.training,
		"OpenTrainingTargets"
	)
	text(root, "EQUIPPED SPELLS  ·  PRESS 1-9 TO CAST", 11, C.Faint, Enum.Font.GothamBlack, {
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
	})
	local slots = new("Frame", {
		Name = "NineEquippedSlots",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, root)
	local slotGrid = new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slots)
	for _, slot in data.Slots do
		Hub.spellCard(slots, slot.Spell, {
			Name = "EquippedSlot_" .. slot.Number,
			Number = slot.Number,
			Order = slot.Number,
			Locked = slot.Locked,
			Selected = slot.Selected,
			Badge = if slot.Locked then "LOCKED" elseif slot.Draft then "DRAFT" else nil,
			BadgeColor = if slot.Locked then C.Faint else C.Gold,
			Schema = schema,
			Spec = spec,
			OnClick = function()
				actions.openSlot(slot.Number)
			end,
		})
	end
	local function relayout()
		local width = root.AbsoluteSize.X
		local columns = if width >= 860 then 3 elseif width >= 520 then 2 else 1
		quickGrid.CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, 84)
		slotGrid.CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, 118)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
	return root
end

return Hub
