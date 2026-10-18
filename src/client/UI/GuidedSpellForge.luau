--!nonstrict
-- Spell Forge: the default player-facing spell creator.
--
-- The spell is shown as what it does: the cast creates a Form, the Form's
-- triggers ("When it hits") fire actions, and actions can open their own
-- branches (blasts, spawned effects). Every card is a live view of the
-- canonical SpellSpec draft; nothing here keeps a second spell model, so the
-- Advanced workshop, saving, and server validation all see the same table.
--
-- Responsibilities inside this module:
--   Toolbar          name, undo/redo, Guided/Advanced, library, keep, save
--   ActionTree       cards, trigger blocks, connector rails, attach buttons
--   ActionPicker     "What do you want to happen?" (schema-derived choices)
--   Inspector        only the selected node's fields
--   Preview          data-driven schematic + real server Test Spell
--   ValidationBar    SpellSpec.validate / SpellSpec.estimate results
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProjectileBehaviorSpec = require(Shared.Modules.ProjectileBehaviorSpec)
local SpellIdentitySpec = require(Shared.Modules.MagicSpellIdentitySpec)
local SpellVisual = require(script.Parent.GrimoireSpellVisual)
local PreviewPanel = require(script.Parent.ForgePreviewPanel)

local Forge = {}
-- Guided and Advanced are one forge: Advanced shows every field, adds the
-- spell-wide setting cards, and hosts the controller's full section editors.

local C = require(script.Parent.SpellForgeTheme).C

local K = require(script.Parent.SpellForgeComponents)
local CategoryColor = K.CategoryColor
local ElementColor = K.ElementColor
local FormIcon = K.FormIcon
local FormVerb = K.FormVerb
local PayloadIcon = K.PayloadIcon
local PayloadVerb = K.PayloadVerb
local EventPhrase = K.EventPhrase

-- Player-intent groups for the action picker. Members are resolved from the
-- live schema each time, so a group only lists what the engine can run here.
local Intents = {
	{
		Id = "Target",
		Icon = "×",
		Title = "Affect a target",
		Blurb = "Harm, heal, shield, mark, or reveal whoever this reaches.",
		Categories = { Impact = true, Support = true, Detection = true },
		Color = C.Ember,
	},
	{
		Id = "Move",
		Icon = "←",
		Title = "Move or hold something",
		Blurb = "Push, slow, bind, displace, control, or bend time.",
		Categories = { Control = true, Movement = true, Temporal = true },
		Color = C.Arcane,
	},
	{
		Id = "Area",
		Icon = "*",
		Title = "Affect an area",
		Blurb = "Burst at this spot and apply effects to everything inside.",
		Behaviors = { Explode = true },
		Color = C.Warn,
	},
	{
		Id = "Create",
		Icon = "◆",
		Title = "Create something",
		Blurb = "Launch a new projectile, open a field, summon, or shape matter.",
		Behaviors = { SpawnEffect = true },
		Categories = { Summoning = true, ["World interaction"] = true },
		Color = C.Gold,
	},
	{
		Id = "Trigger",
		Icon = "◆",
		Title = "Trigger another action",
		Blurb = "Add a different moment, like when it ends or every pulse.",
		Trigger = true,
		Color = C.Frost,
	},
}

local states = setmetatable({}, { __mode = "k" })

local fmt = K.fmt
local new = K.new
local corner = K.corner
local stroke = K.stroke
local pad = K.pad
local text = K.text
local hover = K.hover
local pill = K.pill
local list = K.list
local clearChildren = K.clearChildren

-- Walks the canonical draft so selections that no longer exist (after undo,
-- removals, or a Form change) fall back to the spell root instead of erroring.
local function collect(container, live)
	live[container] = true
	local projectile = container.Projectile
	if projectile and projectile.Behaviors then
		for _, behavior in projectile.Behaviors do
			live[behavior] = true
		end
	end
	for _, steps in pairs(container.Triggers or {}) do
		for _, step in steps do
			live[step] = true
			for _, payload in step.Payloads or {} do
				live[payload] = true
			end
			if type(step.Effect) == "table" then
				collect(step.Effect, live)
			end
		end
	end
end

function Forge.mount(parent, draft, schema, spec, callbacks)
	local old = parent:FindFirstChild("GuidedSpellForge")
	if old then
		old:Destroy()
	end
	local state = states[draft]
	if not state then
		state = { Selection = { Kind = "Form", Scope = draft }, Undo = {}, Redo = {}, Tab = "Build", More = {} }
		states[draft] = state
	end
	local function principle()
		return draft.Source and draft.Source.Principle
	end
	local function castingMode(scope)
		return if scope == draft then draft.Casting and draft.Casting.Mode else nil
	end
	local function supportedEvents(scope)
		return schema.eventsForEffects(scope.Form, castingMode(scope), if scope == draft then draft.Targeting else nil)
	end
	local function eventSupported(scope, eventName)
		return table.find(supportedEvents(scope), eventName) ~= nil
	end
	local function stepFits(scope, eventName, step)
		if step.Behavior then
			return schema.supportsBehavior(step.Behavior, scope.Form, eventName)
		end
		for _, payload in step.Payloads or {} do
			if not schema.supportsPayload(payload.Kind, scope.Form, eventName, principle()) then
				return false
			end
		end
		return true
	end
	-- The moment a shape naturally acts: its default event when it can run effects there.
	local function homeEvent(scope)
		local events = supportedEvents(scope)
		local preferred = (schema.Forms[scope.Form] or {}).DefaultEvent
		return if preferred and table.find(events, preferred) then preferred else events[1]
	end
	-- After a shape or principle change, effects on moments the new shape never
	-- reaches (a Wave never "hits") move to its natural moment when they fit
	-- there. Anything that cannot move stays put and is flagged on its card.
	local function relocate(scope, onlyEvent)
		local target = homeEvent(scope)
		if not target or not scope.Triggers then
			return
		end
		for _, eventName in schema.EventOrder do
			local steps = scope.Triggers[eventName]
			if
				steps
				and eventName ~= target
				and (eventName == onlyEvent or (onlyEvent == nil and not eventSupported(scope, eventName)))
			then
				local keep = {}
				for _, step in steps do
					if stepFits(scope, target, step) then
						scope.Triggers[target] = scope.Triggers[target] or {}
						table.insert(scope.Triggers[target], step)
					else
						table.insert(keep, step)
					end
				end
				scope.Triggers[eventName] = if #keep > 0 then keep else nil
			end
		end
	end

	local root = new("Frame", {
		Name = "GuidedSpellForge",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Backdrop,
		BorderSizePixel = 0,
		-- Above the Grimoire book chrome (ZIndex 10), which stays parented to the panel.
		ZIndex = 50,
		ClipsDescendants = true,
	}, parent)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(28, 20, 26), Color3.fromRGB(10, 9, 12)),
		Rotation = 90,
	}, root)

	local advanced = callbacks.mode == "Expert"
	local render
	local function deepEqual(a, b)
		if a == b then
			return true
		end
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		for key, value in a do
			if not deepEqual(value, b[key]) then
				return false
			end
		end
		for key in b do
			if a[key] == nil then
				return false
			end
		end
		return true
	end
	-- Undo history is recorded by comparing against the last rendered draft,
	-- so edits made in hosted Advanced editors are undoable like forge edits.
	local function track()
		if state.Last ~= nil and not deepEqual(state.Last, draft) then
			table.insert(state.Undo, state.Last)
			if #state.Undo > 60 then
				table.remove(state.Undo, 1)
			end
			table.clear(state.Redo)
		end
		state.Last = spec.copy(draft)
	end
	local function changed()
		callbacks.change()
		render()
	end
	local function commit(mutator)
		mutator()
		changed()
	end
	local function restore(from, to)
		if #from == 0 then
			return
		end
		table.insert(to, spec.copy(draft))
		local snap = table.remove(from)
		table.clear(draft)
		for key, value in spec.copy(snap) do
			draft[key] = value
		end
		state.Last = spec.copy(draft)
		state.Selection = { Kind = "Form", Scope = draft }
		state.Picker = nil
		changed()
	end
	local function select(selection)
		state.Selection = selection
		state.Picker = nil
		state.InspectorScroll = nil
		if state.Mobile then
			state.Tab = "Inspect"
		end
		render()
	end

	------------------------------------------------------------------ toolbar
	local toolbar = new("Frame", {
		Name = "SpellToolbar",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, root)
	stroke(toolbar, C.PanelEdge)
	corner(toolbar, 12)
	local back = pill(toolbar, "‹  BACK", callbacks.back)
	local sigil = text(toolbar, "◆", 22, C.Gold, Enum.Font.GothamBold, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local nameBox = new("TextBox", {
		Name = "SpellName",
		Text = draft.Name,
		PlaceholderText = "Name this spell",
		ClearTextOnFocus = false,
		TextSize = 22,
		Font = Enum.Font.Garamond,
		TextColor3 = C.Ink,
		PlaceholderColor3 = C.Faint,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = C.Input,
		BorderSizePixel = 0,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, toolbar)
	corner(nameBox, 8)
	stroke(nameBox, C.PanelEdge)
	pad(nameBox, 10, 0)
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		local length = utf8.len(nameBox.Text)
		if length and length > SpellIdentitySpec.MaxNameLength then
			nameBox.Text = string.sub(
				nameBox.Text,
				1,
				(utf8.offset(nameBox.Text, SpellIdentitySpec.MaxNameLength + 1) :: number) - 1
			)
		end
	end)
	nameBox.FocusLost:Connect(function()
		local value = SpellIdentitySpec.normalizeName(nameBox.Text)
		if value and value ~= draft.Name then
			commit(function()
				draft.Name = value
			end)
		else
			nameBox.Text = draft.Name
		end
	end)
	local undoButton = pill(toolbar, "UNDO", function()
		restore(state.Undo, state.Redo)
	end)
	local redoButton = pill(toolbar, "REDO", function()
		restore(state.Redo, state.Undo)
	end)
	undoButton.TextSize, redoButton.TextSize = 12, 12
	local modeSwitch = new("Frame", { BackgroundColor3 = C.Input, BorderSizePixel = 0 }, toolbar)
	corner(modeSwitch, 8)
	stroke(modeSwitch, C.PanelEdge)
	local guidedTab = new("TextButton", {
		Text = "GUIDED",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = if advanced then C.Muted else C.Backdrop,
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = if advanced then 1 else 0,
		AutoButtonColor = false,
		Size = UDim2.new(0.5, -3, 1, -6),
		Position = UDim2.fromOffset(3, 3),
	}, modeSwitch)
	corner(guidedTab, 6)
	local advancedTab = new("TextButton", {
		Text = "ADVANCED",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = if advanced then C.Backdrop else C.Muted,
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = if advanced then 0 else 1,
		AutoButtonColor = false,
		Size = UDim2.new(0.5, -3, 1, -6),
		Position = UDim2.new(0.5, 0, 0, 3),
	}, modeSwitch)
	corner(advancedTab, 6)
	advancedTab.Activated:Connect(function()
		if not advanced then
			callbacks.advanced()
		end
	end)
	guidedTab.Activated:Connect(function()
		if advanced then
			callbacks.advanced()
		end
	end)
	local loadButton = pill(toolbar, "LOAD", callbacks.load)
	local keepButton = pill(toolbar, "KEEP DRAFT", callbacks.keep)
	local saveButton = pill(toolbar, "SAVE SPELL", callbacks.save, "accent")
	local closeButton = if callbacks.close then pill(toolbar, "×", callbacks.close) else nil
	if closeButton then
		closeButton.Name = "CloseSpells"
		closeButton.TextSize = 20
	end
	-- Slot drafts can be equipped directly; library spells equip from the Library.
	local equipButton = if callbacks.equip then pill(toolbar, callbacks.equipLabel or "EQUIP", callbacks.equip) else nil

	------------------------------------------------------------------ regions
	local function region(name, title, subtitle)
		local frame = new("Frame", { Name = name, BackgroundColor3 = C.Panel, BorderSizePixel = 0 }, root)
		corner(frame, 12)
		stroke(frame, C.PanelEdge)
		local header = new("Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
		}, frame)
		text(header, title, 13, C.Gold, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.new(1, -32, 0, 18),
		})
		local sub = text(header, subtitle, 12, C.Faint, Enum.Font.Gotham, {
			Position = UDim2.fromOffset(16, 23),
			Size = UDim2.new(1, -32, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		new("Frame", {
			Size = UDim2.new(1, -24, 0, 1),
			Position = UDim2.new(0, 12, 1, -1),
			BackgroundColor3 = C.PanelEdge,
			BorderSizePixel = 0,
		}, header)
		local body = new("ScrollingFrame", {
			Name = "Body",
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 1, -46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = C.Rail,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, frame)
		return frame, body, sub
	end
	local treePanel, tree = region("SpellConstruction", "SPELL CONSTRUCTION", "What happens, when, and what follows")
	pad(tree, 12, 10)
	list(tree, 0)
	local previewPanel = new("Frame", {
		Name = "SpellPreview",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, root)
	corner(previewPanel, 12)
	stroke(previewPanel, C.PanelEdge)
	local inspectPanel, inspector, inspectSub = region("ContextualInspector", "PROPERTIES", "Select a card to shape it")
	pad(inspector, 14, 10)
	list(inspector, 10)

	local tabs = new("Frame", { Name = "MobileTabs", BackgroundTransparency = 1, Visible = false }, root)
	local tabButtons = {}
	for index, info in { { "Build", "SPELL" }, { "Preview", "PREVIEW" }, { "Inspect", "PROPERTIES" } } do
		local tab = pill(tabs, info[2], function()
			state.Tab = info[1]
			render()
		end)
		tab.Size = UDim2.new(1 / 3, -6, 1, 0)
		tab.Position = UDim2.new((index - 1) / 3, 3, 0, 0)
		tabButtons[info[1]] = tab
	end

	------------------------------------------------------------------ bottom bar
	local bottom = new("Frame", {
		Name = "ValidationPanel",
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, root)
	corner(bottom, 12)
	stroke(bottom, C.PanelEdge)
	local testButton = pill(bottom, "▶  TEST SPELL", callbacks.test, "accent")
	testButton.TextSize = 15
	local statusIcon = text(bottom, "●", 18, C.Ok, Enum.Font.GothamBold, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local statusText = text(bottom, "", 13, C.Ink, Enum.Font.GothamMedium, {
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
	})
	local statsHolder = new("Frame", { BackgroundTransparency = 1 }, bottom)
	local statsLayout = list(statsHolder, 8, true)
	statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local function stat(label, color)
		local holder = new("Frame", {
			BackgroundColor3 = C.Input,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 40),
		}, statsHolder)
		corner(holder, 8)
		pad(holder, 10, 2)
		list(holder, 0)
		local value = text(holder, "0", 17, color, Enum.Font.GothamBlack, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			TextWrapped = false,
		})
		text(holder, label, 10, C.Faint, Enum.Font.GothamBold, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			TextWrapped = false,
		})
		return value, holder
	end
	local manaValue = stat("MANA", Color3.fromRGB(120, 170, 255))
	local strainValue = stat("STRAIN", C.Ember)
	local complexityValue = stat("COMPLEXITY", C.Arcane)
	local upkeepValue, upkeepHolder = stat("UPKEEP / S", C.Warn)

	------------------------------------------------------------------ layout
	local function layout()
		local width = root.AbsoluteSize.X
		local mobile = width < 760
		state.Mobile = mobile
		local m = 10
		local barH = if mobile then 104 else 60
		toolbar.Position = UDim2.fromOffset(m, m)
		toolbar.Size = UDim2.new(1, -m * 2, 0, barH)
		if mobile then
			back.Text, keepButton.Text, saveButton.Text = "‹", "KEEP", "SAVE"
			back.Position, back.Size = UDim2.fromOffset(8, 8), UDim2.fromOffset(40, 40)
			sigil.Visible = false
			nameBox.Position, nameBox.Size =
				UDim2.fromOffset(54, 8), UDim2.new(1, -(if closeButton then 108 else 62), 0, 40)
			if closeButton then
				closeButton.Position, closeButton.Size = UDim2.new(1, -48, 0, 8), UDim2.fromOffset(40, 40)
			end
			local row = { undoButton, redoButton, modeSwitch, loadButton, keepButton, saveButton }
			local weights = { 0.1, 0.1, 0.3, 0.14, 0.16, 0.2 }
			if equipButton then
				row = { undoButton, redoButton, modeSwitch, keepButton, saveButton, equipButton }
				weights = { 0.1, 0.1, 0.26, 0.15, 0.19, 0.2 }
				loadButton.Visible = false
				equipButton.Text = "EQUIP"
			end
			local x = 0
			for index, control in row do
				control.Position = UDim2.new(x, 8, 0, 56)
				control.Size = UDim2.new(weights[index], -8, 0, 40)
				x += weights[index]
			end
			guidedTab.Text, advancedTab.Text = "GUIDED", "ADV"
		else
			back.Text, keepButton.Text, saveButton.Text = "‹  BACK", "KEEP DRAFT", "SAVE SPELL"
			sigil.Visible = true
			back.Position, back.Size = UDim2.fromOffset(10, 10), UDim2.fromOffset(112, 40)
			sigil.Position, sigil.Size = UDim2.fromOffset(128, 10), UDim2.fromOffset(28, 40)
			loadButton.Visible = true
			local equipWidth = (if equipButton then 132 + 8 else 0) + (if closeButton then 48 else 0)
			if equipButton then
				equipButton.Text = callbacks.equipLabel or "EQUIP"
			end
			local rightWidth = 64 + 64 + 196 + 84 + 112 + 124 + 6 * 8 + 10 + equipWidth
			nameBox.Position = UDim2.fromOffset(160, 10)
			nameBox.Size = UDim2.new(1, -160 - rightWidth, 0, 40)
			local x = -10
			if closeButton then
				x -= 40
				closeButton.Position = UDim2.new(1, x, 0, 10)
				closeButton.Size = UDim2.fromOffset(40, 40)
				x -= 8
			end
			if equipButton then
				x -= 132
				equipButton.Position = UDim2.new(1, x, 0, 10)
				equipButton.Size = UDim2.fromOffset(132, 40)
				x -= 8
			end
			for _, entry in
				{
					{ saveButton, 124 },
					{ keepButton, 112 },
					{ loadButton, 84 },
					{ modeSwitch, 196 },
					{ redoButton, 44 },
					{ undoButton, 44 },
				}
			do
				x -= entry[2]
				entry[1].Position = UDim2.new(1, x, 0, 10)
				entry[1].Size = UDim2.fromOffset(entry[2], 40)
				x -= 8
			end
			guidedTab.Text, advancedTab.Text = "GUIDED", "ADVANCED"
		end
		local bottomH = if mobile then 112 else 66
		bottom.Position = UDim2.new(0, m, 1, -m - bottomH)
		bottom.Size = UDim2.new(1, -m * 2, 0, bottomH)
		if mobile then
			testButton.Position, testButton.Size = UDim2.fromOffset(8, 8), UDim2.new(0.42, -8, 0, 44)
			statsHolder.Position, statsHolder.Size = UDim2.new(0.42, 8, 0, 8), UDim2.new(0.58, -16, 0, 44)
			statusIcon.Position, statusIcon.Size = UDim2.fromOffset(8, 60), UDim2.fromOffset(24, 44)
			statusText.Position, statusText.Size = UDim2.fromOffset(34, 60), UDim2.new(1, -42, 0, 44)
			statusText.TextWrapped = true
		else
			testButton.Position, testButton.Size = UDim2.fromOffset(10, 10), UDim2.fromOffset(170, 46)
			statusIcon.Position, statusIcon.Size = UDim2.fromOffset(190, 10), UDim2.fromOffset(24, 46)
			statusText.Position, statusText.Size = UDim2.fromOffset(216, 10), UDim2.new(1, -216 - 420, 0, 46)
			statusText.TextWrapped = true
			statsHolder.Position, statsHolder.Size = UDim2.new(1, -414, 0, 10), UDim2.fromOffset(404, 46)
		end
		local top = m + barH + m
		local bodyH = -(top + bottomH + m * 2)
		tabs.Visible = mobile
		if mobile then
			tabs.Position, tabs.Size = UDim2.fromOffset(m - 3, top), UDim2.new(1, -m * 2 + 6, 0, 40)
			for name, tab in tabButtons do
				local active = state.Tab == name
				tab.BackgroundColor3 = if active then C.Gold else C.Card
				tab.TextColor3 = if active then C.Backdrop else C.Ink
			end
			local y = top + 48
			for _, entry in { { treePanel, "Build" }, { previewPanel, "Preview" }, { inspectPanel, "Inspect" } } do
				entry[1].Position = UDim2.fromOffset(m, y)
				entry[1].Size = UDim2.new(1, -m * 2, 1, bodyH - 48)
				entry[1].Visible = state.Tab == entry[2]
			end
		else
			local leftW = if width < 1100 then 0.38 else 0.34
			local rightW = if width < 1100 then 0.3 else 0.27
			treePanel.Visible, previewPanel.Visible, inspectPanel.Visible = true, true, true
			treePanel.Position = UDim2.fromOffset(m, top)
			treePanel.Size = UDim2.new(leftW, -m * 1.5, 1, bodyH)
			previewPanel.Position = UDim2.new(leftW, m * 0.5, 0, top)
			previewPanel.Size = UDim2.new(1 - leftW - rightW, -m, 1, bodyH)
			inspectPanel.Position = UDim2.new(1 - rightW, m * 0.5, 0, top)
			inspectPanel.Size = UDim2.new(rightW, -m * 1.5, 1, bodyH)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local wasMobile = state.Mobile
		layout()
		if wasMobile ~= state.Mobile then
			render()
		end
	end)

	------------------------------------------------------------------ summaries
	local function payloadSummary(payload)
		local definition = schema.Payloads[payload.Kind]
		if payload.Kind == "Damage" then
			local channel = payload.DamageChannel or "Elemental"
			local element = if channel == "Elemental" then tostring(draft.Element) else channel
			return fmt(payload.Amount or 0) .. " " .. element .. " damage"
		end
		local parts = {}
		for _, field in (definition and definition.Fields) or {} do
			local value = payload[field.Key]
			if value ~= nil and type(value) ~= "table" and (field.Required or #parts == 0) then
				table.insert(parts, field.Label .. " " .. fmt(value))
			end
			if #parts >= 2 then
				break
			end
		end
		return if #parts > 0 then table.concat(parts, " · ") else (definition and definition.Description or "")
	end
	local function formSummary(scope)
		local form = schema.Forms[scope.Form]
		local parts = {}
		if scope == draft then
			table.insert(parts, tostring(principle()))
			table.insert(parts, tostring(draft.Element))
		end
		local mechanics = scope[scope.Form]
		for _, field in (form and form.Mechanics) or {} do
			if field.Object == scope.Form and mechanics and type(mechanics[field.Key]) == "number" then
				local short = string.gsub(field.Label, "^Maximum ", "Max ")
				table.insert(parts, short .. " " .. fmt(mechanics[field.Key]))
			end
			if #parts >= 4 then
				break
			end
		end
		return table.concat(parts, " · ")
	end
	local function eventTitle(eventName)
		return string.upper(EventPhrase[eventName] or schema.EventLabels[eventName] or eventName)
	end

	------------------------------------------------------------------ tree
	local INDENT = 26
	local order = 0
	local function row(depth, height, rails)
		order += 1
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		}, tree)
		for level = 1, depth do
			if rails == nil or rails[level] ~= false then
				new("Frame", {
					Size = UDim2.new(0, 2, 1, 0),
					Position = UDim2.fromOffset(level * INDENT - 15, 0),
					BackgroundColor3 = C.Rail,
					BorderSizePixel = 0,
				}, frame)
			end
		end
		if depth > 0 then
			new("Frame", {
				Size = UDim2.fromOffset(13, 2),
				Position = UDim2.new(0, depth * INDENT - 15, 0.5, -1),
				BackgroundColor3 = C.Rail,
				BorderSizePixel = 0,
			}, frame)
		end
		return frame
	end

	local function actionCard(opts)
		local height = opts.Height or 66
		local frame = row(opts.Depth, height + 8)
		local x = opts.Depth * INDENT
		local base = if opts.Selected then C.CardSelected else C.Card
		local cardButton = new("TextButton", {
			Name = "SpellActionCard",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = base,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 4),
			Size = UDim2.new(1, -x, 0, height),
		}, frame)
		corner(cardButton, 10)
		stroke(cardButton, if opts.Selected then C.Gold else C.PanelEdge, if opts.Selected then 2 else 1)
		hover(cardButton, base, if opts.Selected then base else C.CardHover)
		cardButton.Activated:Connect(opts.OnSelect)
		new("Frame", {
			Size = UDim2.new(0, 4, 1, -16),
			Position = UDim2.fromOffset(0, 8),
			BackgroundColor3 = opts.Color,
			BorderSizePixel = 0,
		}, cardButton)
		local iconSize = height - 22
		local icon = text(cardButton, opts.Icon, math.floor(iconSize * 0.55), opts.Color, Enum.Font.GothamBold, {
			Position = UDim2.new(0, 12, 0.5, -iconSize / 2),
			Size = UDim2.fromOffset(iconSize, iconSize),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Input,
		})
		corner(icon, iconSize // 2)
		stroke(icon, opts.Color, 1, 0.55)
		local textX = 12 + iconSize + 10
		local rightPad = if opts.OnAdd then 46 else 10
		local title = text(cardButton, opts.Title, 14, C.Ink, Enum.Font.GothamBold, {
			Position = UDim2.fromOffset(textX, 9),
			Size = UDim2.new(1, -textX - rightPad, 0, 18),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if opts.Tag then
			local tag = text(cardButton, opts.Tag, 10, opts.TagColor or C.Faint, Enum.Font.GothamBlack, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 16),
				Position = UDim2.new(1, -rightPad, 0, 10),
				AnchorPoint = Vector2.new(1, 0),
				TextWrapped = false,
				BackgroundTransparency = 0,
				BackgroundColor3 = C.Input,
			})
			pad(tag, 6, 0)
			corner(tag, 4)
			title.Size = UDim2.new(1, -textX - rightPad - 70, 0, 18)
		end
		text(cardButton, opts.Summary or "", 12, C.Muted, Enum.Font.Gotham, {
			Position = UDim2.fromOffset(textX, 28),
			Size = UDim2.new(1, -textX - rightPad, 1, -34),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if opts.OnAdd then
			local add = new("TextButton", {
				Name = "Attach",
				Text = "+",
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				TextColor3 = C.Gold,
				BackgroundColor3 = C.Input,
				AutoButtonColor = false,
				Size = UDim2.fromOffset(32, 32),
				Position = UDim2.new(1, -40, 0.5, -16),
			}, cardButton)
			corner(add, 16)
			stroke(add, C.GoldDeep)
			hover(add, C.Input, C.CardHover)
			add.Activated:Connect(opts.OnAdd)
		end
		return cardButton
	end

	local function triggerBlock(depth, eventName, selected, onSelect, onAdd, unsupportedBy)
		local frame = row(depth, 40)
		local x = depth * INDENT
		local base = if selected then C.CardSelected else Color3.fromRGB(26, 22, 28)
		local tone = if unsupportedBy then C.Error else C.Gold
		local block = new("TextButton", {
			Name = "TriggerBlock",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = base,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 4),
			Size = UDim2.new(1, -x, 0, 32),
		}, frame)
		corner(block, 16)
		stroke(
			block,
			if selected then C.Gold elseif unsupportedBy then C.Error else C.GoldDeep,
			if selected then 2 else 1
		)
		hover(block, base, C.CardHover)
		block.Activated:Connect(onSelect)
		text(block, if unsupportedBy then "!" else "◆", 14, tone, Enum.Font.GothamBold, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(18, 32),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		text(
			block,
			eventTitle(eventName)
				.. (if unsupportedBy then "  ·  A " .. string.upper(unsupportedBy) .. " CAN'T DO THIS" else ""),
			12,
			tone,
			Enum.Font.GothamBlack,
			{
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.new(1, -110, 1, 0),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}
		)
		local add = new("TextButton", {
			Text = "+ ADD",
			TextSize = 11,
			Font = Enum.Font.GothamBlack,
			TextColor3 = C.Gold,
			BackgroundColor3 = C.Input,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(62, 24),
			Position = UDim2.new(1, -68, 0.5, -12),
		}, block)
		corner(add, 12)
		hover(add, C.Input, C.CardHover)
		add.Activated:Connect(onAdd)
	end

	local function ghost(depth, label, callback)
		local frame = row(depth, 38)
		local x = depth * INDENT
		local item = new("TextButton", {
			Name = "AddAction",
			Text = label,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextColor3 = C.Faint,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = C.Panel,
			AutoButtonColor = false,
			Position = UDim2.fromOffset(x, 4),
			Size = UDim2.new(1, -x, 0, 30),
		}, frame)
		corner(item, 8)
		stroke(item, C.Rail, 1, 0.2)
		pad(item, 12, 0)
		item.MouseEnter:Connect(function()
			item.TextColor3 = C.Gold
		end)
		item.MouseLeave:Connect(function()
			item.TextColor3 = C.Faint
		end)
		item.Activated:Connect(callback)
	end

	local function isSel(kind, a, b)
		local s = state.Selection
		if s.Kind ~= kind then
			return false
		end
		if kind == "Form" then
			return s.Scope == a
		elseif kind == "Trigger" then
			return s.Scope == a and s.Event == b
		elseif kind == "Payload" then
			return s.Payload == a
		elseif kind == "Behavior" then
			return s.Step == a
		elseif kind == "Motion" then
			return s.Motion == a
		end
		return false
	end

	local function openPicker(picker)
		picker.Stage = picker.Stage or "Intent"
		state.Picker = picker
		render()
	end

	local renderScope
	renderScope = function(scope, depth, parentStep)
		local form = schema.Forms[scope.Form]
		local isRoot = scope == draft
		local formTitle = string.upper(
			if isRoot
				then "Create " .. (form and form.Label or tostring(scope.Form))
				else "Spawn " .. (form and form.Label or tostring(scope.Form))
		)
		actionCard({
			Depth = depth,
			Icon = FormIcon[scope.Form] or "◆",
			Color = ElementColor[draft.Element] or C.Gold,
			Title = formTitle,
			Summary = formSummary(scope)
				.. (if parentStep and (parentStep.Count or 1) > 1 then " · ×" .. fmt(parentStep.Count) else ""),
			Tag = if isRoot then "CREATES" else "NEW EFFECT",
			TagColor = C.Gold,
			Selected = isSel("Form", scope),
			Height = 72,
			OnSelect = function()
				select({ Kind = "Form", Scope = scope, Step = parentStep })
			end,
			OnAdd = function()
				openPicker({ Mode = "Trigger", Scope = scope })
			end,
		})
		local projectile = scope.Projectile
		if scope.Form == "Projectile" and projectile then
			if #(projectile.Behaviors or {}) == 0 then
				local frame = row(depth + 1, 26)
				text(frame, "→  Travels forward along your aim", 12, C.Faint, Enum.Font.GothamMedium, {
					Position = UDim2.fromOffset((depth + 1) * INDENT, 0),
					Size = UDim2.new(1, -(depth + 1) * INDENT, 1, 0),
				})
			end
			for _, behavior in projectile.Behaviors or {} do
				local definition = ProjectileBehaviorSpec.get(behavior.Kind)
				local parts = {}
				for _, field in (definition and definition.Fields) or {} do
					if behavior[field.Key] ~= nil and #parts < 2 then
						table.insert(parts, field.Label .. " " .. fmt(behavior[field.Key]))
					end
				end
				actionCard({
					Depth = depth + 1,
					Icon = "»",
					Color = C.Frost,
					Title = string.upper(definition and definition.Label or behavior.Kind),
					Summary = table.concat(parts, " · "),
					Tag = "WHILE TRAVELING",
					TagColor = C.Frost,
					Height = 58,
					Selected = isSel("Motion", behavior),
					OnSelect = function()
						select({ Kind = "Motion", Scope = scope, Motion = behavior })
					end,
				})
			end
		end
		local anyTrigger = false
		for _, eventName in schema.EventOrder do
			local steps = scope.Triggers and scope.Triggers[eventName]
			if steps and #steps > 0 then
				anyTrigger = true
				local eventOk = eventSupported(scope, eventName)
				local formLabel = (schema.Forms[scope.Form] or {}).Label or scope.Form
				triggerBlock(depth + 1, eventName, isSel("Trigger", scope, eventName), function()
					select({ Kind = "Trigger", Scope = scope, Event = eventName })
				end, function()
					openPicker({ Mode = "Action", Scope = scope, Event = eventName })
				end, if eventOk then nil else formLabel)
				local count = 0
				for _, step in steps do
					count += #(step.Payloads or {}) + (if step.Behavior then 1 else 0)
				end
				local index = 0
				local function relation()
					index += 1
					if count <= 1 then
						return "THEN", C.Faint
					end
					return if index == 1 then "TOGETHER" else "+ AT ONCE", C.Faint
				end
				for _, step in steps do
					local conditional = step.Condition ~= nil
					if step.Behavior then
						local behavior = schema.Behaviors[step.Behavior]
						local tag, tagColor = relation()
						if conditional then
							tag, tagColor = "IF", C.Arcane
						end
						local isSpawn = step.Behavior == "SpawnEffect"
						actionCard({
							Depth = depth + 2,
							Icon = if isSpawn then "◆" else "*",
							Color = if isSpawn then C.Gold else C.Warn,
							Title = string.upper(
								if isSpawn
									then "Start a new effect here"
									else (behavior and behavior.Label or step.Behavior)
							),
							Summary = if isSpawn
								then "Spawns a "
									.. tostring(step.Effect and step.Effect.Form or "?")
									.. " with its own triggers"
								else "Radius " .. fmt(step.Radius or 0) .. " · applies the effects below to all inside",
							Tag = tag,
							TagColor = tagColor,
							Selected = isSel("Behavior", step),
							OnSelect = function()
								select({ Kind = "Behavior", Scope = scope, Event = eventName, Step = step })
							end,
							OnAdd = if isSpawn
								then nil
								else function()
									openPicker({ Mode = "Action", Scope = scope, Event = eventName, Step = step })
								end,
						})
						if isSpawn and type(step.Effect) == "table" then
							renderScope(step.Effect, depth + 3, step)
						else
							for _, payload in step.Payloads or {} do
								local definition = schema.Payloads[payload.Kind]
								actionCard({
									Depth = depth + 3,
									Icon = PayloadIcon[payload.Kind] or "▲",
									Color = CategoryColor[definition and definition.Category] or C.Muted,
									Title = string.upper(
										PayloadVerb[payload.Kind] or (definition and definition.Label) or payload.Kind
									),
									Summary = payloadSummary(payload),
									Tag = "INSIDE",
									Height = 58,
									Selected = isSel("Payload", payload),
									OnSelect = function()
										select({
											Kind = "Payload",
											Scope = scope,
											Event = eventName,
											Step = step,
											Payload = payload,
										})
									end,
								})
							end
						end
					else
						for _, payload in step.Payloads or {} do
							local definition = schema.Payloads[payload.Kind]
							local tag, tagColor = relation()
							if conditional then
								tag, tagColor = "IF", C.Arcane
							end
							if
								not eventOk
								or not schema.supportsPayload(payload.Kind, scope.Form, eventName, principle())
							then
								tag, tagColor = "UNSUPPORTED", C.Error
							end
							actionCard({
								Depth = depth + 2,
								Icon = PayloadIcon[payload.Kind] or "▲",
								Color = CategoryColor[definition and definition.Category] or C.Muted,
								Title = string.upper(
									PayloadVerb[payload.Kind] or (definition and definition.Label) or payload.Kind
								),
								Summary = payloadSummary(payload),
								Tag = tag,
								TagColor = tagColor,
								Selected = isSel("Payload", payload),
								OnSelect = function()
									select({
										Kind = "Payload",
										Scope = scope,
										Event = eventName,
										Step = step,
										Payload = payload,
									})
								end,
							})
						end
					end
				end
				ghost(depth + 2, "+  Add another effect at this moment", function()
					openPicker({ Mode = "Action", Scope = scope, Event = eventName })
				end)
			end
		end
		ghost(
			depth + 1,
			if anyTrigger then "◆  Add another trigger" else "◆  Choose when something happens",
			function()
				openPicker({ Mode = "Trigger", Scope = scope })
			end
		)
	end

	local function renderTree()
		clearChildren(tree, "UIListLayout")
		order = 0
		local head = row(0, 44)
		local castChip = text(head, "▶  ON CAST", 13, C.Ink, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.fromOffset(120, 32),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Blood,
		})
		corner(castChip, 16)
		local casting = draft.Casting or {}
		text(
			head,
			string.format(
				"%s cast · cooldown %ss%s",
				tostring(casting.Mode or "Instant"),
				fmt(casting.Cooldown or 0),
				if (casting.CastTime or 0) > 0 then " · " .. fmt(casting.CastTime) .. "s wind-up" else ""
			),
			12,
			C.Faint,
			Enum.Font.Gotham,
			{ Position = UDim2.fromOffset(132, 6), Size = UDim2.new(1, -132, 0, 32) }
		)
		if advanced then
			for _, entry in Forge.settingsCards(draft, schema) do
				actionCard({
					Depth = 1,
					Icon = entry.Icon,
					Color = entry.Color,
					Title = entry.Title,
					Summary = entry.Summary,
					Tag = entry.Tag,
					TagColor = entry.TagColor,
					Height = 58,
					Selected = state.Selection.Kind == "Section" and state.Selection.Id == entry.Id,
					OnSelect = function()
						select({ Kind = "Section", Scope = draft, Id = entry.Id })
					end,
				})
			end
		end
		renderScope(draft, 1, nil)
		local legend = row(0, 56)
		text(
			legend,
			"◆ trigger · cards below a trigger run together when it fires · IF cards run only when their condition passes",
			11,
			C.Faint,
			Enum.Font.Gotham,
			{ Size = UDim2.new(1, 0, 1, -8), Position = UDim2.fromOffset(0, 8) }
		)
	end

	------------------------------------------------------------------ picker
	local function payloadKinds()
		local kinds = table.clone(schema.PayloadOrder)
		local extra = {}
		for kind in schema.Payloads do
			if not table.find(kinds, kind) then
				table.insert(extra, kind)
			end
		end
		table.sort(extra)
		for _, kind in extra do
			table.insert(kinds, kind)
		end
		return kinds
	end

	-- Every option is checked against the schema for this Form, moment, and
	-- Principle. Capability matches blocked only by Principle stay visible but
	-- disabled so players learn why, instead of the choice silently vanishing.
	local function optionsFor(picker, intent)
		local scope, eventName = picker.Scope, picker.Event
		local formName = scope.Form
		local options = {}
		if picker.Step then
			local behavior = schema.Behaviors[picker.Step.Behavior]
			for _, kind in (behavior and behavior.PayloadKinds) or {} do
				local definition = schema.Payloads[kind]
				if definition and (definition.Principle == nil or definition.Principle == principle()) then
					table.insert(options, { Kind = "Payload", Id = kind, Enabled = true })
				end
			end
			return options
		end
		for _, kind in payloadKinds() do
			local definition = schema.Payloads[kind]
			if intent.Categories and intent.Categories[definition.Category] then
				if schema.supportsPayload(kind, formName, eventName, principle()) then
					table.insert(options, { Kind = "Payload", Id = kind, Enabled = true })
				elseif schema.supportsPayloadCapability(kind, formName, eventName) then
					table.insert(options, {
						Kind = "Payload",
						Id = kind,
						Enabled = false,
						Reason = "Needs the " .. tostring(definition.Principle) .. " principle",
					})
				end
			end
		end
		for kind in intent.Behaviors or {} do
			if schema.supportsBehavior(kind, formName, eventName) then
				if kind == "SpawnEffect" then
					for _, spawnForm in spec.SpawnForms do
						-- Offer only spawned effects the validator would accept as created.
						local supported, reason = false, tostring(principle()) .. " cannot create this"
						local effect = schema.supportsPrincipleForm(principle(), spawnForm)
							and spec.defaultSpawnEffect(spawnForm, principle())
						local child = effect and spec.expandSpawnEffect(draft, effect)
						if child then
							local lifetime = child.Lifetime and child.Lifetime.Mode
							if lifetime ~= "FixedDuration" and lifetime ~= "Instantaneous" then
								reason = "Spawned effects need a limited lifetime"
							else
								local valid, why = spec.validate(child, 1)
								supported, reason = valid, if valid then nil else tostring(why)
							end
						end
						table.insert(options, {
							Kind = "Spawn",
							Id = spawnForm,
							Enabled = supported,
							Reason = reason,
						})
					end
				else
					table.insert(options, { Kind = "Behavior", Id = kind, Enabled = true })
				end
			end
		end
		return options
	end

	local function addOption(picker, option)
		local scope, eventName = picker.Scope, picker.Event
		commit(function()
			scope.Triggers = scope.Triggers or {}
			local steps = scope.Triggers[eventName] or {}
			scope.Triggers[eventName] = steps
			if option.Kind == "Payload" then
				local payload = spec.copy(schema.Payloads[option.Id].Defaults or {})
				payload.Kind = option.Id
				if picker.Step then
					picker.Step.Payloads = picker.Step.Payloads or {}
					table.insert(picker.Step.Payloads, payload)
					state.Selection =
						{ Kind = "Payload", Scope = scope, Event = eventName, Step = picker.Step, Payload = payload }
				else
					local step = { Payloads = { payload } }
					table.insert(steps, step)
					state.Selection =
						{ Kind = "Payload", Scope = scope, Event = eventName, Step = step, Payload = payload }
				end
			elseif option.Kind == "Behavior" then
				local definition = schema.Behaviors[option.Id]
				local step = spec.copy(definition.Defaults or {})
				step.Behavior = option.Id
				step.Payloads = {}
				for _, kind in definition.DefaultPayloadKinds or {} do
					local payloadDefinition = schema.Payloads[kind]
					if payloadDefinition then
						local payload = spec.copy(payloadDefinition.Defaults or {})
						payload.Kind = kind
						table.insert(step.Payloads, payload)
					end
				end
				table.insert(steps, step)
				state.Selection = { Kind = "Behavior", Scope = scope, Event = eventName, Step = step }
			elseif option.Kind == "Spawn" then
				local definition = schema.Behaviors.SpawnEffect
				local step = spec.copy(definition.Defaults or {})
				step.Behavior = "SpawnEffect"
				step.Payloads = {}
				step.Effect = spec.defaultSpawnEffect(option.Id, principle())
				table.insert(steps, step)
				state.Selection = { Kind = "Form", Scope = step.Effect, Step = step }
			end
			state.Picker = nil
			if state.Mobile then
				state.Tab = "Inspect"
			end
		end)
	end

	local function renderPicker()
		local existing = root:FindFirstChild("ActionPicker")
		if existing then
			existing:Destroy()
		end
		local picker = state.Picker
		if not picker then
			return
		end
		local shade = new("TextButton", {
			Name = "ActionPicker",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 40,
		}, root)
		shade.Activated:Connect(function()
			state.Picker = nil
			render()
		end)
		local sheet = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(if state.Mobile then 1 else 0.62, -20, if state.Mobile then 0.9 else 0.78, 0),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			Active = true,
		}, shade)
		new("UISizeConstraint", { MaxSize = Vector2.new(860, 720) }, sheet)
		corner(sheet, 14)
		stroke(sheet, C.Gold, 1, 0.4)
		local sheetScale = new("UIScale", { Scale = 0.96 }, sheet)
		TweenService:Create(sheetScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		local formLabel = (schema.Forms[picker.Scope.Form] or {}).Label or picker.Scope.Form
		local heading, subheading
		if picker.Mode == "Trigger" then
			heading = "When should something happen?"
			subheading = "Moments your " .. formLabel .. " can react to"
		elseif picker.Mode == "Motion" then
			heading = "How should it travel?"
			subheading = "Movement behaviors supported for projectiles"
		elseif picker.Step then
			heading = "What happens inside the blast?"
			subheading = eventTitle(picker.Event) .. "  ·  applies to everything in the radius"
		elseif picker.Stage == "Intent" then
			heading = "What do you want to happen?"
			subheading = eventTitle(picker.Event) .. "  ·  " .. formLabel
		else
			heading = picker.Intent.Title
			subheading = eventTitle(picker.Event) .. "  ·  " .. formLabel
		end
		text(sheet, heading, 26, C.Ink, Enum.Font.Garamond, {
			Position = UDim2.fromOffset(22, 14),
			Size = UDim2.new(1, -120, 0, 34),
		})
		text(sheet, subheading, 12, C.Gold, Enum.Font.GothamBold, {
			Position = UDim2.fromOffset(22, 48),
			Size = UDim2.new(1, -120, 0, 18),
		})
		local close = pill(sheet, "×", function()
			state.Picker = nil
			render()
		end)
		close.Position, close.Size = UDim2.new(1, -52, 0, 16), UDim2.fromOffset(36, 36)
		if picker.Mode == "Action" and picker.Stage == "Options" and not picker.Step then
			local backButton = pill(sheet, "‹ BACK", function()
				picker.Stage = "Intent"
				render()
			end)
			backButton.Position, backButton.Size = UDim2.new(1, -140, 0, 16), UDim2.fromOffset(80, 36)
		end
		local body = new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 78),
			Size = UDim2.new(1, 0, 1, -86),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = C.Rail,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, sheet)
		pad(body, 18, 6)
		local grid = new("UIGridLayout", {
			CellPadding = UDim2.fromOffset(12, 12),
			CellSize = UDim2.new(if state.Mobile then 1 else 0.5, -8, 0, 84),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, body)
		local tileParent = body
		local function tile(icon, color, title, blurb, enabled, callback, badge)
			local base = if enabled then C.Card else Color3.fromRGB(24, 21, 26)
			local item = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = base,
				BorderSizePixel = 0,
			}, tileParent)
			corner(item, 12)
			stroke(item, if enabled then C.PanelEdge else C.Panel)
			if enabled then
				hover(item, base, C.CardHover)
				item.Activated:Connect(callback)
			end
			local glyph = text(item, icon, 26, if enabled then color else C.Faint, Enum.Font.GothamBold, {
				Position = UDim2.fromOffset(12, 14),
				Size = UDim2.fromOffset(54, 54),
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = C.Input,
			})
			corner(glyph, 27)
			stroke(glyph, color, 1, if enabled then 0.5 else 0.85)
			text(item, title, 15, if enabled then C.Ink else C.Faint, Enum.Font.GothamBold, {
				Position = UDim2.fromOffset(78, 12),
				Size = UDim2.new(1, -90, 0, 20),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			text(item, blurb, 12, if enabled then C.Muted else C.Faint, Enum.Font.Gotham, {
				Position = UDim2.fromOffset(78, 34),
				Size = UDim2.new(1, -90, 0, 42),
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			if badge then
				text(item, badge, 10, if enabled then C.Gold else C.Faint, Enum.Font.GothamBlack, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, 12),
					Size = UDim2.fromOffset(120, 14),
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
			return item
		end
		if picker.Mode == "Trigger" then
			local scope = picker.Scope
			local events =
				schema.eventsForEffects(scope.Form, castingMode(scope), if scope == draft then draft.Targeting else nil)
			for _, eventName in events do
				local used = scope.Triggers and scope.Triggers[eventName] and #scope.Triggers[eventName] > 0
				tile(
					"◆",
					C.Gold,
					EventPhrase[eventName] or schema.EventLabels[eventName] or eventName,
					schema.EventDescriptions[eventName] or "",
					true,
					function()
						openPicker({ Mode = "Action", Scope = scope, Event = eventName })
					end,
					if used then "IN SPELL" else nil
				)
			end
			if #events == 0 then
				tile("—", C.Faint, "No triggers available", "This form has no supported moments for effects.", false)
			end
			if scope.Form == "Projectile" and scope.Projectile then
				tile(
					"»",
					C.Frost,
					"Change how it travels",
					"Homing, piercing, bouncing, splitting and more.",
					true,
					function()
						openPicker({ Mode = "Motion", Scope = scope, Stage = "Options" })
					end
				)
			end
		elseif picker.Mode == "Motion" then
			local behaviors = picker.Scope.Projectile.Behaviors or {}
			for _, kind in ProjectileBehaviorSpec.Order do
				local definition = ProjectileBehaviorSpec.get(kind)
				local present = false
				for _, existingBehavior in behaviors do
					if existingBehavior.Kind == kind then
						present = true
					end
				end
				tile("»", C.Frost, definition.Label, definition.Description, not present, function()
					commit(function()
						picker.Scope.Projectile.Behaviors = picker.Scope.Projectile.Behaviors or {}
						local behavior = ProjectileBehaviorSpec.copyDefaults(kind)
						table.insert(picker.Scope.Projectile.Behaviors, behavior)
						state.Selection = { Kind = "Motion", Scope = picker.Scope, Motion = behavior }
						state.Picker = nil
					end)
				end, if present then "ALREADY ADDED" else nil)
			end
		elseif picker.Stage == "Intent" and not picker.Step then
			for _, intent in Intents do
				if intent.Trigger then
					tile(intent.Icon, intent.Color, intent.Title, intent.Blurb, true, function()
						openPicker({ Mode = "Trigger", Scope = picker.Scope })
					end)
				else
					local options = optionsFor(picker, intent)
					local available = 0
					for _, option in options do
						if option.Enabled then
							available += 1
						end
					end
					tile(
						intent.Icon,
						intent.Color,
						intent.Title,
						if available > 0
							then intent.Blurb
							else "Not supported at this moment for a " .. formLabel .. ".",
						available > 0,
						function()
							picker.Stage, picker.Intent = "Options", intent
							render()
						end,
						if available > 0 then available .. " AVAILABLE" else "UNAVAILABLE"
					)
				end
			end
		else
			local options = optionsFor(picker, picker.Intent or {})
			-- Group by Polarity (Boons, Banes, Other); each tile keeps its Category as a sub-label.
			-- Behaviors and spawned effects are not payloads, so they sit under Other.
			local groups = {}
			for _, option in options do
				local definition = option.Kind == "Payload" and schema.Payloads[option.Id]
				local polarity = definition and definition.Polarity or "Neutral"
				groups[polarity] = groups[polarity] or {}
				table.insert(groups[polarity], option)
			end
			if #options > 0 then
				grid:Destroy()
				grid = nil
				new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
			end
			for groupIndex, polarity in schema.PolarityOrder do
				local groupOptions = groups[polarity]
				if groupOptions then
					text(body, string.upper(schema.PolarityLabels[polarity]), 12, C.Gold, Enum.Font.GothamBlack, {
						Name = "PickerGroupHeading",
						Size = UDim2.new(1, 0, 0, 22),
						TextYAlignment = Enum.TextYAlignment.Bottom,
						LayoutOrder = groupIndex * 2 - 1,
					})
					local section = new("Frame", {
						Name = "PickerGroup",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = groupIndex * 2,
					}, body)
					new("UIGridLayout", {
						CellPadding = UDim2.fromOffset(12, 12),
						CellSize = UDim2.new(if state.Mobile then 1 else 0.5, -8, 0, 84),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}, section)
					tileParent = section
					for _, option in groupOptions do
						local icon, color, title, blurb, category
						if option.Kind == "Payload" then
							local definition = schema.Payloads[option.Id]
							icon = PayloadIcon[option.Id] or "▲"
							color = CategoryColor[definition.Category] or C.Muted
							title = PayloadVerb[option.Id] or definition.Label
							blurb = definition.Description
							category = definition.Category
						elseif option.Kind == "Spawn" then
							local definition = schema.Forms[option.Id]
							icon, color = FormIcon[option.Id] or "◆", C.Gold
							title = FormVerb[option.Id] or ("Create " .. definition.Label)
							blurb = "Starts a separate "
								.. definition.Label
								.. " here. It gets its own triggers and effects."
						else
							local definition = schema.Behaviors[option.Id]
							icon, color, title, blurb = "*", C.Warn, definition.Label, definition.Description
						end
						tile(
							icon,
							color,
							title,
							if option.Enabled then blurb else option.Reason,
							option.Enabled,
							function()
								addOption(picker, option)
							end,
							if not option.Enabled then "UNAVAILABLE" elseif category then string.upper(category) else nil
						)
					end
					tileParent = body
				end
			end
			if #options == 0 then
				tile("—", C.Faint, "Nothing available", "The engine has no supported actions for this moment.", false)
			end
		end
		if grid then
			grid.Parent = body
		end
	end

	------------------------------------------------------------------ inspector
	local inspectOrder = 0
	local function nextOrder()
		inspectOrder += 1
		return inspectOrder
	end
	local function section(title)
		local label = text(inspector, title, 11, C.Faint, Enum.Font.GothamBlack, {
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = nextOrder(),
			TextYAlignment = Enum.TextYAlignment.Bottom,
		})
		return label
	end
	local function note(value, color)
		return text(inspector, value, 12, color or C.Muted, Enum.Font.Gotham, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end
	local function header(icon, color, title, description)
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.Card,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
		}, inspector)
		corner(frame, 10)
		stroke(frame, color, 1, 0.5)
		pad(frame, 12, 12)
		local glyph = text(frame, icon, 24, color, Enum.Font.GothamBold, {
			Size = UDim2.fromOffset(46, 46),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Input,
		})
		corner(glyph, 23)
		text(frame, title, 20, C.Ink, Enum.Font.Garamond, {
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -58, 0, 24),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		text(frame, description or "", 12, C.Muted, Enum.Font.Gotham, {
			Position = UDim2.fromOffset(58, 26),
			Size = UDim2.new(1, -58, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end
	local function chips(parent, values, current, onPick, labeler)
		local holder = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, parent)
		local layout = list(holder, 6, true)
		layout.Wraps = true
		for index, value in values do
			local active = value == current
			local chip = new("TextButton", {
				Text = if labeler then labeler(value) else tostring(value),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextColor3 = if active then C.Backdrop else C.Ink,
				BackgroundColor3 = if active then C.Gold else C.Input,
				AutoButtonColor = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 32),
				LayoutOrder = index,
			}, holder)
			corner(chip, 16)
			stroke(chip, if active then C.Gold else C.PanelEdge)
			pad(chip, 12, 0)
			if not active then
				hover(chip, C.Input, C.CardHover)
				chip.Activated:Connect(function()
					onPick(value)
				end)
			end
		end
		return holder
	end
	local function fieldBox(label, help)
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, inspector)
		list(frame, 6)
		text(frame, label, 13, C.Ink, Enum.Font.GothamBold, {
			Size = UDim2.new(1, 0, 0, 18),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		})
		if help and help ~= "" then
			text(frame, help, 11, C.Faint, Enum.Font.Gotham, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			})
		end
		return frame
	end
	local function choiceField(label, help, values, current, onPick, labeler)
		local frame = fieldBox(label, help)
		chips(frame, values, current, function(value)
			commit(function()
				onPick(value)
			end)
		end, labeler).LayoutOrder =
			3
	end
	local function numberField(target, field)
		local frame = fieldBox(field.Label, field.Help)
		local lo = field.Min or 0
		local hi = field.Max or math.max(lo + 1, (target[field.Key] or 0) * 2, 10)
		local current = target[field.Key]
		local controls = new("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, frame)
		local track = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, -92, 0, 8),
			Position = UDim2.new(0, 0, 0.5, -4),
			BackgroundColor3 = C.Input,
			BorderSizePixel = 0,
		}, controls)
		corner(track, 4)
		local fill = new("Frame", { BackgroundColor3 = C.Ember, BorderSizePixel = 0 }, track)
		corner(fill, 4)
		local knob = new("Frame", {
			Size = UDim2.fromOffset(18, 18),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Gold,
			BorderSizePixel = 0,
		}, track)
		corner(knob, 9)
		stroke(knob, C.Backdrop, 2)
		local box = new("TextBox", {
			Text = if current == nil then "" else fmt(current),
			PlaceholderText = "default",
			PlaceholderColor3 = C.Faint,
			ClearTextOnFocus = false,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextColor3 = C.Ink,
			BackgroundColor3 = C.Input,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(80, 34),
			Position = UDim2.new(1, -80, 0, 0),
		}, controls)
		corner(box, 8)
		stroke(box, C.PanelEdge)
		local function normalize(value)
			value = math.clamp(value, lo, hi)
			if field.Integer then
				value = math.round(value)
			elseif hi - lo > 20 then
				value = math.round(value * 10) / 10
			else
				value = math.round(value * 100) / 100
			end
			return value
		end
		local function show(value)
			local alpha = if hi > lo then ((value or lo) - lo) / (hi - lo) else 0
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
			knob.Position = UDim2.fromScale(math.clamp(alpha, 0, 1), 0.5)
			box.Text = if value == nil then "" else fmt(value)
		end
		show(current)
		box.FocusLost:Connect(function()
			local value = tonumber(box.Text)
			if value and normalize(value) ~= target[field.Key] then
				commit(function()
					target[field.Key] = normalize(value)
				end)
			else
				show(target[field.Key])
			end
		end)
		local dragging = nil
		local function fromInput(position)
			local alpha = (position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
			return normalize(lo + math.clamp(alpha, 0, 1) * (hi - lo))
		end
		track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = input
				target[field.Key] = fromInput(input.Position)
				show(target[field.Key])
			end
		end)
		local moved = UIS.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				target[field.Key] = fromInput(input.Position)
				show(target[field.Key])
			end
		end)
		local ended = UIS.InputEnded:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragging = nil
				task.defer(changed)
			end
		end)
		frame.Destroying:Connect(function()
			moved:Disconnect()
			ended:Disconnect()
		end)
	end
	local function genericField(target, field)
		field = schema.resolveField(target, field)
		local value = target[field.Key]
		if field.Options then
			choiceField(field.Label, field.Help, field.Options, value, function(choice)
				target[field.Key] = choice
				schema.normalizePayload(target)
			end)
		elseif type(value) == "boolean" then
			choiceField(field.Label, field.Help, { true, false }, value, function(choice)
				target[field.Key] = choice
			end, function(choice)
				return if choice then "ON" else "OFF"
			end)
		elseif field.Min ~= nil or field.Max ~= nil or type(value) == "number" then
			numberField(target, field)
		elseif type(value) == "string" or value == nil then
			local frame = fieldBox(field.Label, field.Help)
			local box = new("TextBox", {
				Text = value or "",
				ClearTextOnFocus = false,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextColor3 = C.Ink,
				BackgroundColor3 = C.Input,
				Size = UDim2.new(1, 0, 0, 34),
				LayoutOrder = 3,
			}, frame)
			corner(box, 8)
			box.FocusLost:Connect(function()
				if box.Text ~= (value or "") then
					commit(function()
						target[field.Key] = if box.Text == "" then nil else box.Text
					end)
				end
			end)
		end
	end
	local function matches(label)
		local query = string.lower(state.Search or "")
		return query == "" or string.find(string.lower(tostring(label)), query, 1, true) ~= nil
	end
	local function fieldGroup(target, fields, key)
		fields = fields or {}
		local primary, extra = {}, {}
		for _, field in fields or {} do
			if not matches(field.Label) or not schema.fieldVisible(target, field) then
				continue
			end
			if field.Required == false and #fields > 3 and not advanced then
				table.insert(extra, field)
			else
				table.insert(primary, field)
			end
		end
		for _, field in primary do
			genericField(target, field)
		end
		if #extra > 0 then
			local open = state.More[key] == true
			local toggle = pill(
				inspector,
				(if open then "▼  Fewer options" else "▶  More options") .. "  (" .. #extra .. ")",
				function()
					state.More[key] = not open
					render()
				end
			)
			toggle.Size = UDim2.new(1, 0, 0, 34)
			toggle.LayoutOrder = nextOrder()
			if open then
				for _, field in extra do
					genericField(target, field)
				end
			end
		end
	end
	local function removeButton(label, callback)
		local item = pill(inspector, label, function()
			commit(callback)
		end, "danger")
		item.Size = UDim2.new(1, 0, 0, 38)
		item.LayoutOrder = nextOrder()
	end
	local function actionButton(label, callback)
		local item = pill(inspector, label, callback)
		item.Size = UDim2.new(1, 0, 0, 40)
		item.LayoutOrder = nextOrder()
		item.TextColor3 = C.Gold
		return item
	end
	local function pruneStep(scope, eventName, step)
		local steps = scope.Triggers[eventName]
		if step and #(step.Payloads or {}) == 0 and not step.Behavior then
			local index = table.find(steps, step)
			if index then
				table.remove(steps, index)
			end
		end
		if steps and #steps == 0 then
			scope.Triggers[eventName] = nil
		end
	end

	local function renderInspector()
		clearChildren(inspector, "UIListLayout")
		inspectOrder = 0
		if state.Mobile then
			local backToSpell = pill(inspector, "‹  Back to spell", function()
				state.Tab = "Build"
				render()
			end)
			backToSpell.Size = UDim2.new(1, 0, 0, 40)
			backToSpell.LayoutOrder = nextOrder()
		end
		if advanced then
			local search = new("TextBox", {
				Name = "FieldSearch",
				Text = state.Search or "",
				PlaceholderText = "Search every setting on this card",
				PlaceholderColor3 = C.Faint,
				ClearTextOnFocus = false,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextColor3 = C.Ink,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = C.Input,
				Size = UDim2.new(1, 0, 0, 36),
				LayoutOrder = nextOrder(),
			}, inspector)
			corner(search, 8)
			stroke(search, C.PanelEdge)
			pad(search, 12, 0)
			search.FocusLost:Connect(function()
				if search.Text ~= (state.Search or "") then
					state.Search = search.Text
					render()
				end
			end)
		end
		local s = state.Selection
		-- Advanced: below the card's own fields, host the controller's full
		-- section editor for that part of the spell (every remaining setting).
		local function hosted(sections, eventName)
			if not advanced or not callbacks.renderSections then
				return
			end
			for _, sectionId in sections do
				local finalOrder =
					callbacks.renderSections(inspector, { sectionId }, eventName, state.Search, inspectOrder + 1)
				inspectOrder = math.max(inspectOrder + 1, (finalOrder or inspectOrder) + 1)
			end
		end
		local function rootEvent(target)
			for _, eventName in schema.EventOrder do
				for _, step in (draft.Triggers and draft.Triggers[eventName]) or {} do
					local live = {}
					collect({ Triggers = { [eventName] = { step } } }, live)
					if live[target] then
						return eventName
					end
				end
			end
			local form = schema.Forms[draft.Form] or {}
			return form.DefaultEvent
		end
		if s.Kind == "Section" then
			local entry = Forge.settingsCard(draft, schema, s.Id)
			inspectSub.Text = "Spell-wide settings"
			header(entry.Icon, entry.Color, entry.Label, entry.Description)
			hosted(entry.Sections)
		elseif s.Kind == "Form" then
			local scope = s.Scope
			local form = schema.Forms[scope.Form] or {}
			local isRoot = scope == draft
			inspectSub.Text = if isRoot then "What this spell creates" else "The effect this action starts"
			header(
				FormIcon[scope.Form] or "◆",
				ElementColor[draft.Element] or C.Gold,
				form.Label or scope.Form,
				form.Description
			)
			if isRoot then
				section("WHAT DOES THIS SPELL CREATE?")
				local compatible = {}
				for _, formName in schema.FormOrder or {} do
					if schema.supportsPrincipleForm(principle(), formName) then
						table.insert(compatible, formName)
					end
				end
				local frame =
					fieldBox("Shape", "Changing the shape keeps your effects; any the new shape can't run are flagged.")
				chips(frame, compatible, draft.Form, function(value)
					callbacks.changeForm(value, principle())
					relocate(draft)
					state.Selection = { Kind = "Form", Scope = draft }
					changed()
				end, function(value)
					return (FormIcon[value] or "") .. "  " .. schema.Forms[value].Label
				end).LayoutOrder =
					3
				section("MAGIC")
				local principles = {}
				for _, candidate in schema.Principles do
					if schema.supportsPrincipleForm(candidate, draft.Form) then
						table.insert(principles, candidate)
					end
				end
				local principleBox =
					fieldBox("Magical principle", (schema.PrincipleDefinitions[principle()] or {}).Description)
				chips(principleBox, principles, principle(), function(value)
					callbacks.changeForm(draft.Form, value)
					relocate(draft)
					changed()
				end).LayoutOrder =
					3
				choiceField("Element", nil, schema.Elements, draft.Element, function(value)
					draft.Element = value
				end)
				local targeting = {}
				for _, mode in schema.TargetingModeOrder do
					if form.Targeting and form.Targeting[mode] then
						table.insert(targeting, mode)
					end
				end
				if #targeting > 1 then
					choiceField(
						"Targeting",
						(schema.TargetingModes[draft.Targeting] or {}).Description,
						targeting,
						draft.Targeting,
						function(value)
							draft.Targeting = value
						end,
						function(value)
							return schema.TargetingModes[value].Label
						end
					)
				end
				if draft.TargetRules then
					choiceField(
						"Who it affects",
						schema.TargetRelationships[draft.TargetRules.Relationship],
						schema.TargetRelationshipOrder,
						draft.TargetRules.Relationship,
						function(value)
							draft.TargetRules.Relationship = value
						end
					)
				end
			else
				section("WHAT DOES IT START?")
				local spawnForms = {}
				for _, formName in spec.SpawnForms do
					if schema.supportsPrincipleForm(principle(), formName) then
						table.insert(spawnForms, formName)
					end
				end
				local frame = fieldBox("Shape", "Changing this resets the new effect's own triggers.")
				chips(frame, spawnForms, scope.Form, function(value)
					commit(function()
						local fresh = spec.defaultSpawnEffect(value, principle())
						if fresh and s.Step then
							s.Step.Effect = fresh
							state.Selection = { Kind = "Form", Scope = fresh, Step = s.Step }
						end
					end)
				end, function(value)
					return (FormIcon[value] or "") .. "  " .. schema.Forms[value].Label
				end).LayoutOrder =
					3
				if s.Step then
					fieldGroup(s.Step, (schema.Behaviors.SpawnEffect or {}).Fields, "spawn")
				end
			end
			local mechanics = scope[scope.Form]
			if mechanics then
				section("SHAPE & MOVEMENT")
				local fields = {}
				for _, field in form.Mechanics or {} do
					if field.Object == scope.Form and (isRoot or mechanics[field.Key] ~= nil) then
						table.insert(fields, field)
					end
				end
				fieldGroup(mechanics, fields, "mech:" .. tostring(scope.Form))
			end
			if scope.Lifetime and scope.Lifetime.Mode == "FixedDuration" then
				numberField(scope.Lifetime, {
					Key = "Duration",
					Label = "Lasts for (seconds)",
					Min = 0.1,
					Max = 60,
					Help = "How long it remains before it ends.",
				})
			end
			if scope.Form == "Projectile" and scope.Projectile then
				section("MOVEMENT BEHAVIOR")
				if #(scope.Projectile.Behaviors or {}) == 0 then
					note("Travels straight along your aim.")
				end
				for _, behavior in scope.Projectile.Behaviors or {} do
					local definition = ProjectileBehaviorSpec.get(behavior.Kind)
					local item = pill(
						inspector,
						"»  " .. (definition and definition.Label or behavior.Kind),
						function()
							select({ Kind = "Motion", Scope = scope, Motion = behavior })
						end
					)
					item.Size, item.LayoutOrder = UDim2.new(1, 0, 0, 36), nextOrder()
					item.TextXAlignment = Enum.TextXAlignment.Left
					pad(item, 12, 0)
				end
				actionButton("+  Change how it travels", function()
					openPicker({ Mode = "Motion", Scope = scope, Stage = "Options" })
				end)
			end
			section("WHAT HAPPENS NEXT")
			actionButton("◆  Add a trigger", function()
				openPicker({ Mode = "Trigger", Scope = scope })
			end)
			if not isRoot and s.Step then
				removeButton("Remove this effect", function()
					-- Locate the owning trigger list anywhere in the draft.
					local function strip(container)
						for eventName, steps in pairs(container.Triggers or {}) do
							local index = table.find(steps, s.Step)
							if index then
								table.remove(steps, index)
								if #steps == 0 then
									container.Triggers[eventName] = nil
								end
								return true
							end
							for _, step in steps do
								if type(step.Effect) == "table" and strip(step.Effect) then
									return true
								end
							end
						end
						return false
					end
					strip(draft)
					state.Selection = { Kind = "Form", Scope = draft }
				end)
			end
			if s.Scope == draft then
				hosted({ "Setup" })
			else
				hosted({ "ConfigureEffects" }, rootEvent(s.Step))
			end
		elseif s.Kind == "Trigger" then
			inspectSub.Text = "A moment this spell reacts to"
			header("◆", C.Gold, EventPhrase[s.Event] or s.Event, schema.EventDescriptions[s.Event])
			local steps = s.Scope.Triggers[s.Event] or {}
			if not eventSupported(s.Scope, s.Event) then
				local formLabel = (schema.Forms[s.Scope.Form] or {}).Label or s.Scope.Form
				note(
					"A "
						.. formLabel
						.. " never reaches this moment, so the spell can't be tested or saved until these effects move or are removed.",
					C.Error
				)
				local target = homeEvent(s.Scope)
				if target then
					actionButton("Move effects to: " .. (EventPhrase[target] or target), function()
						commit(function()
							relocate(s.Scope, s.Event)
							state.Selection = { Kind = "Trigger", Scope = s.Scope, Event = target }
						end)
					end)
				end
			end
			section("RUNS " .. (if #steps > 1 then "THESE TOGETHER" else "THIS"))
			for _, step in steps do
				for _, payload in step.Payloads or {} do
					if not step.Behavior then
						local item = pill(
							inspector,
							(PayloadIcon[payload.Kind] or "▲") .. "  " .. (PayloadVerb[payload.Kind] or payload.Kind),
							function()
								select({
									Kind = "Payload",
									Scope = s.Scope,
									Event = s.Event,
									Step = step,
									Payload = payload,
								})
							end
						)
						item.Size, item.LayoutOrder = UDim2.new(1, 0, 0, 36), nextOrder()
						item.TextXAlignment = Enum.TextXAlignment.Left
						pad(item, 12, 0)
					end
				end
				if step.Behavior then
					local item = pill(
						inspector,
						"*  " .. ((schema.Behaviors[step.Behavior] or {}).Label or step.Behavior),
						function()
							select({ Kind = "Behavior", Scope = s.Scope, Event = s.Event, Step = step })
						end
					)
					item.Size, item.LayoutOrder = UDim2.new(1, 0, 0, 36), nextOrder()
					item.TextXAlignment = Enum.TextXAlignment.Left
					pad(item, 12, 0)
				end
			end
			actionButton("+  Add an effect at this moment", function()
				openPicker({ Mode = "Action", Scope = s.Scope, Event = s.Event })
			end)
			removeButton("Remove this trigger and its effects", function()
				s.Scope.Triggers[s.Event] = nil
				state.Selection = { Kind = "Form", Scope = s.Scope }
			end)
			hosted({ "ConfigureEffects" }, if s.Scope == draft then s.Event else rootEvent(s.Scope))
		elseif s.Kind == "Payload" then
			local payload = s.Payload
			local definition = schema.Payloads[payload.Kind] or {}
			inspectSub.Text = eventTitle(s.Event)
			header(
				PayloadIcon[payload.Kind] or "▲",
				CategoryColor[definition.Category] or C.Muted,
				PayloadVerb[payload.Kind] or definition.Label or payload.Kind,
				definition.Description
			)
			if s.Step.Condition then
				note(
					"IF · This effect only runs when its condition passes. Edit the condition in Advanced view; Guided keeps it intact.",
					C.Arcane
				)
			end
			if payload.Kind == "Damage" and (payload.DamageChannel or "Elemental") == "Elemental" then
				note("Elemental damage uses the spell's element: " .. tostring(draft.Element) .. ".")
			end
			section("PROPERTIES")
			fieldGroup(payload, definition.Fields, "payload:" .. payload.Kind)
			section("")
			removeButton("Remove this effect", function()
				local index = table.find(s.Step.Payloads, payload)
				if index then
					table.remove(s.Step.Payloads, index)
				end
				pruneStep(s.Scope, s.Event, s.Step)
				state.Selection = { Kind = "Form", Scope = s.Scope }
			end)
			hosted({ "ConfigureEffects" }, rootEvent(s.Step))
		elseif s.Kind == "Behavior" then
			local step = s.Step
			local definition = schema.Behaviors[step.Behavior] or {}
			inspectSub.Text = eventTitle(s.Event)
			header("*", C.Warn, definition.Label or step.Behavior, definition.Description)
			if step.Condition then
				note("IF · Runs only when its condition passes. Edit the condition in Advanced view.", C.Arcane)
			end
			section("PROPERTIES")
			fieldGroup(step, definition.Fields, "behavior:" .. tostring(step.Behavior))
			section("AFFECTS EVERYTHING INSIDE WITH")
			if #(step.Payloads or {}) == 0 then
				note("Nothing yet — a blast needs at least one effect.", C.Warn)
			end
			for _, payload in step.Payloads or {} do
				local item = pill(
					inspector,
					(PayloadIcon[payload.Kind] or "▲") .. "  " .. (PayloadVerb[payload.Kind] or payload.Kind),
					function()
						select({ Kind = "Payload", Scope = s.Scope, Event = s.Event, Step = step, Payload = payload })
					end
				)
				item.Size, item.LayoutOrder = UDim2.new(1, 0, 0, 36), nextOrder()
				item.TextXAlignment = Enum.TextXAlignment.Left
				pad(item, 12, 0)
			end
			actionButton("+  Add an effect inside", function()
				openPicker({ Mode = "Action", Scope = s.Scope, Event = s.Event, Step = step, Stage = "Options" })
			end)
			removeButton("Remove this blast", function()
				local index = table.find(s.Scope.Triggers[s.Event], step)
				if index then
					table.remove(s.Scope.Triggers[s.Event], index)
				end
				pruneStep(s.Scope, s.Event, nil)
				state.Selection = { Kind = "Form", Scope = s.Scope }
			end)
			hosted({ "ConfigureEffects" }, rootEvent(s.Step))
		elseif s.Kind == "Motion" then
			local behavior = s.Motion
			local definition = ProjectileBehaviorSpec.get(behavior.Kind) or {}
			inspectSub.Text = "While the projectile travels"
			header("»", C.Frost, definition.Label or behavior.Kind, definition.Description)
			section("PROPERTIES")
			fieldGroup(behavior, definition.Fields, "motion:" .. tostring(behavior.Kind))
			removeButton("Remove this movement", function()
				local index = table.find(s.Scope.Projectile.Behaviors, behavior)
				if index then
					table.remove(s.Scope.Projectile.Behaviors, index)
				end
				state.Selection = { Kind = "Form", Scope = s.Scope }
			end)
			hosted({ "ConfigureEffects" }, rootEvent(s.Scope))
		end
	end

	------------------------------------------------------------------ preview
	local previewView = PreviewPanel.mount(previewPanel, draft, schema, payloadSummary)
	local renderPreview, stepAnimation = previewView.render, previewView.step
	local heartbeat = RunService.Heartbeat:Connect(stepAnimation)
	root.Destroying:Connect(function()
		heartbeat:Disconnect()
	end)

	local spawnButton
	do
		local controls = new("Frame", {
			Position = UDim2.new(0, 12, 0.62, -46),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, previewPanel)
		local cast = pill(controls, "▶  Test cast", callbacks.test, "accent")
		cast.Size = UDim2.new(0.5, -4, 1, 0)
		cast.ZIndex = 6
		if callbacks.spawnTarget then
			spawnButton = pill(controls, "■  Spawn target dummy", callbacks.spawnTarget)
		else
			spawnButton = pill(controls, "Target dummies: Studio only", function() end)
			spawnButton.TextColor3 = C.Faint
		end
		spawnButton.Size = UDim2.new(0.5, -4, 1, 0)
		spawnButton.Position = UDim2.new(0.5, 4, 0, 0)
		spawnButton.ZIndex = 6
	end

	------------------------------------------------------------------ status
	local function renderStatus()
		local ok, reason = spec.validate(draft)
		local cost = spec.estimate(draft)
		statusIcon.Text = if ok then "●" else "!"
		statusIcon.TextColor3 = if ok then C.Ok else C.Warn
		statusText.Text = if ok
			then "Ready to test. Every action here is supported by the spell engine."
			else "Needs attention: " .. tostring(reason)
		statusText.TextColor3 = if ok then C.Ok else C.Warn
		manaValue.Text = fmt(cost.ManaDemand or 0)
		strainValue.Text = fmt(cost.Strain or 0)
		complexityValue.Text = fmt(cost.Complexity or 0)
		upkeepValue.Text = fmt(cost.ManaUpkeepPerSecond or 0)
		upkeepHolder.Visible = (cost.ManaUpkeepPerSecond or 0) > 0
		testButton.BackgroundColor3 = if ok then C.Ember else C.Card
		undoButton.TextColor3 = if #state.Undo > 0 then C.Ink else C.Faint
		redoButton.TextColor3 = if #state.Redo > 0 then C.Ink else C.Faint
		if not nameBox:IsFocused() then
			nameBox.Text = draft.Name
		end
	end

	render = function()
		track()
		local live = {}
		collect(draft, live)
		local s = state.Selection
		if
			not live[s.Scope]
			or (s.Step and not live[s.Step])
			or (s.Payload and not live[s.Payload])
			or (s.Motion and not live[s.Motion])
			or (s.Kind == "Trigger" and not (s.Scope.Triggers and s.Scope.Triggers[s.Event]))
		then
			state.Selection = { Kind = "Form", Scope = draft }
		end
		if state.Picker and not live[state.Picker.Scope] then
			state.Picker = nil
		end
		layout()
		renderTree()
		renderInspector()
		local keep = state.InspectorScroll
		if keep then
			task.defer(function()
				inspector.CanvasPosition = keep
			end)
		end
		renderPreview()
		renderStatus()
		renderPicker()
	end

	inspector:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		state.InspectorScroll = inspector.CanvasPosition
	end)
	render()
	return root,
		{
			-- Called by the controller after edits made in hosted editors.
			refresh = function()
				if root.Parent then
					track()
					renderTree()
					renderPreview()
					renderStatus()
				end
			end,
		}
end

-- Spell-wide cards shown only in Advanced. Each hosts controller sections.
local SettingsCards = {
	{
		Id = "Casting",
		Icon = "■",
		Label = "Casting & costs",
		Description = "How the cast starts, channels, interrupts, recovers, and what it costs.",
		Sections = { "Casting", "Cost", "Test" },
	},
	{
		Id = "Targeting",
		Icon = "○",
		Label = "Targeting",
		Description = "Where it aims, who it may affect, range, limits, and proximity.",
		Sections = { "Targeting" },
	},
	{
		Id = "Conditions",
		Icon = "◇",
		Label = "Cast conditions",
		Description = "The full rule tree that decides whether this spell may be cast.",
		Sections = { "Conditions" },
	},
	{
		Id = "Appearance",
		Icon = "▲",
		Label = "Appearance & sound",
		Description = "Colors, materials, particles, trails, impacts, presentation, and audio.",
		Sections = { "Presentation" },
	},
}

function Forge.settingsCard(_draft, _schema, id)
	for _, entry in SettingsCards do
		if entry.Id == id then
			return entry
		end
	end
	return SettingsCards[1]
end

function Forge.settingsCards(draft, schema)
	local casting = draft.Casting or {}
	local rules = draft.TargetRules or {}
	local conditionCount = 0
	if type(draft.Conditions) == "table" then
		for _ in draft.Conditions do
			conditionCount += 1
		end
	end
	local visual = draft.Visual or {}
	local summaries = {
		Casting = string.format(
			"%s · cooldown %ss · cast %ss",
			tostring(casting.Mode or "Instant"),
			tostring(casting.Cooldown or 0),
			tostring(casting.CastTime or 0)
		),
		Targeting = string.format(
			"%s · %s · range %s",
			tostring((schema.TargetingModes[draft.Targeting] or {}).Label or draft.Targeting),
			tostring(rules.Relationship or "Any"),
			tostring(rules.Range or "-")
		),
		Conditions = if conditionCount > 0
			then conditionCount .. " rule" .. (if conditionCount == 1 then "" else "s") .. " guard this cast"
			else "Always castable",
		Appearance = string.format(
			"%s · %s",
			tostring(visual.Palette or visual.Material or "Default look"),
			tostring(draft.Element or "Neutral")
		),
	}
	local cards = {}
	for _, entry in SettingsCards do
		table.insert(cards, {
			Id = entry.Id,
			Icon = entry.Icon,
			Color = if entry.Id == "Conditions" then C.Arcane else C.Gold,
			Title = string.upper(entry.Label),
			Summary = summaries[entry.Id],
			Tag = if entry.Id == "Conditions" and conditionCount > 0 then "IF" else "SPELL",
			TagColor = if entry.Id == "Conditions" then C.Arcane else C.Faint,
		})
	end
	return cards
end

return Forge
