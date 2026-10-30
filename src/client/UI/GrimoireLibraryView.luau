--!strict
-- The library owns presentation state only. The server owns every saved record and equip.
local Shared = game:GetService("ReplicatedStorage").Shared
local Library = require(Shared.Modules.GrimoireLibrary)
local Summary = require(Shared.Modules.GrimoireSummary)
local Starters = require(Shared.Modules.GrimoireStarters)
local Theme = require(script.Parent.SpellForgeTheme).Book
local K = require(script.Parent.SpellForgeComponents)
local SpellVisual = require(script.Parent.GrimoireSpellVisual)
local LibraryLayout = require(script.Parent.GrimoireLibraryLayout)
local ProgressionConfig = require(Shared.Configuration.SpellProgression)
local ProgressionRules = require(Shared.Modules.SpellProgressionRules)

local View = {}

local function label(parent, value, size, color, position, dimensions, font)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = value
	item.TextColor3 = color
	item.TextSize = size
	item.Font = font or Enum.Font.Gotham
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.Position = position
	item.Size = dimensions
	item.Parent = parent
	return item
end

local function outline(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

function View.new(ctx)
	local descriptions = {}
	for _, build in ipairs({ Starters.buildShowcase, Starters.buildShowcaseExpansion, Starters.buildFeatureShowcase }) do
		for _, template in ipairs(build()) do
			descriptions[template.Definition.Name] = template.Description
		end
	end
	local self = {
		Catalog = Library.empty(),
		Query = { Search = "", Sort = "Name", Status = "Active", Collection = "All", Form = "All", Element = "All" },
		Selected = nil,
		DetailTab = "Overview",
		Slot = 1,
		Busy = false,
		Page = 1,
		ChoosingSlot = nil,
		ProgressionPage = false,
		-- "Mine" = spells the player made; "Curated" = seeded starter/showcase spells.
		Shelf = "Mine",
	}
	function self.slotLimit(): number
		if self.Catalog.Unrestricted then
			return 9
		end
		return ProgressionRules.slots(self.Catalog.Progression or { XP = 0 })
	end
	function self.chooseForSlot(slot)
		self.ChoosingSlot = slot
		self.Slot = slot
		self.Selected = nil
		self.Page = 1
		self.Query =
			{ Search = "", Sort = "Name", Status = "Active", Collection = "All", Form = "All", Element = "All" }
	end
	local function command(action, extra)
		if self.Busy then
			ctx.message("Waiting for the library update…", false)
			return
		end
		local data = extra or {}
		data.Action = action
		data.Id = data.Id or self.Selected
		self.Busy = true
		ctx.request:FireServer("Library", data)
	end
	local function purchase(action, id, expectedRank)
		if self.Busy then
			return
		end
		self.Busy = true
		ctx.request:FireServer("Progression", { Action = action, Id = id, ExpectedRank = expectedRank })
	end
	function self.receive(ok, message, catalog)
		self.Busy = false
		self.Catalog = catalog
		if self.Selected and not catalog.Records[self.Selected] then
			self.Selected = nil
		end
		ctx.message(message, ok)
	end
	local function action(description, caption, callback)
		return ctx.button(ctx.row(description), caption, callback)
	end
	local function field(description, value, change)
		local frame = ctx.row(description)
		local title = frame:FindFirstChildOfClass("TextLabel")
		if title then
			title.Size = UDim2.new(0.42, 0, 1, 0)
		end
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.55, 0, 1, 0)
		box.Position = UDim2.fromScale(0.44, 0)
		box.BackgroundColor3 = K.C.Input
		box.TextColor3 = Theme.Ink
		box.BorderColor3 = Theme.Border
		box.BorderSizePixel = 1
		box.Font = Enum.Font.GothamMedium
		box.Text = value
		box.TextSize = 13
		box.ClearTextOnFocus = false
		box.Parent = frame
		box.Focused:Connect(function()
			box.BorderColor3, box.BorderSizePixel = Theme.Gold, 2
		end)
		box.FocusLost:Connect(function()
			box.BorderColor3, box.BorderSizePixel = Theme.Border, 1
			change(box.Text)
		end)
	end
	local function cycle(label, value, options, change)
		ctx.select(label, value, options, change, nil, nil, nil, nil, true)
	end
	local function isCurated(record)
		for _, tag in ipairs(Library.SystemTags) do
			if string.find(record.Tags, tag, 1, true) then
				return true
			end
		end
		return false
	end
	local function openRecord(id)
		self.Selected = id
		self.DetailTab = "Overview"
		ctx.rebuild()
		ctx.top()
	end
	local function card(parent, result, index, columns)
		local item = Instance.new("TextButton")
		item.Name = "SpellCard_" .. result.Id
		item.Size = UDim2.fromOffset(120, 120)
		item.BackgroundColor3 = Theme.Surface
		item.BorderSizePixel = 0
		item.Text = ""
		item.AutoButtonColor = false
		item.Parent = parent
		K.corner(item, 12)
		local edge = outline(item, Theme.Border, 1)
		K.hover(item, Theme.Surface, K.C.CardHover)
		item.SelectionGained:Connect(function()
			edge.Color = Theme.Gold
		end)
		item.SelectionLost:Connect(function()
			edge.Color = Theme.Border
		end)
		local d = result.Record.Definition
		-- Press-and-drag a card onto an open spell bar slot to equip it there.
		item.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				-- Lazy so the library view still loads where the HUD is absent (tests).
				local hud = script.Parent:FindFirstChild("HUD")
				if hud then
					require(hud:WaitForChild("SpellState") :: any).pressCard(result.Id, d)
				end
			end
		end)
		local accent = K.ElementColor[d.Element] or Theme.Gold
		local icon = K.text(item, K.FormIcon[d.Form] or "◆", 22, accent, Enum.Font.GothamBold, {
			Name = "GeneratedSpellIcon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.fromScale(0.4, 0.4),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = K.C.Input,
		})
		K.new("UIAspectRatioConstraint", {}, icon)
		K.corner(icon, 999)
		K.stroke(icon, accent, 1, 0.5)
		local nameLabel = label(
			item,
			d.Name,
			14,
			Theme.Ink,
			UDim2.fromScale(0.06, 0.54),
			UDim2.fromScale(0.88, 0.2),
			Enum.Font.GothamBold
		)
		nameLabel.TextScaled = true
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MinTextSize, nameLimit.MaxTextSize = 9, 16
		nameLimit.Parent = nameLabel
		label(
			item,
			d.Form .. "  ·  " .. d.Element,
			11,
			Theme.MutedInk,
			UDim2.fromScale(0.06, 0.74),
			UDim2.fromScale(0.88, 0.11)
		).TextXAlignment =
			Enum.TextXAlignment.Center
		local ok, estimate = pcall(ctx.spec.estimate, d)
		label(
			item,
			if ok and estimate
				then K.fmt(estimate.ManaDemand or 0) .. " mana · " .. K.fmt(estimate.Strain or 0) .. " strain"
				else "",
			10,
			Color3.fromRGB(120, 170, 255),
			UDim2.fromScale(0.06, 0.86),
			UDim2.fromScale(0.88, 0.1),
			Enum.Font.GothamBold
		).TextXAlignment =
			Enum.TextXAlignment.Center
		item.Activated:Connect(function()
			openRecord(result.Id)
		end)
		return item
	end
	local function tabButton(parent, name, index, columns)
		local item = Instance.new("TextButton")
		local gap = 8
		local cell = if columns == 4 then 104 else 84
		local gridWidth = columns * cell + (columns - 1) * gap
		item.Position = UDim2.new(0.5, -gridWidth / 2 + (index - 1) * (cell + gap), 0, 0)
		item.Size = UDim2.fromOffset(cell, cell)
		item.BackgroundColor3 = if self.DetailTab == name then Theme.Accent else Theme.Surface
		item.TextColor3 = if self.DetailTab == name then Theme.OnAccent else Theme.Ink
		item.BorderSizePixel = 0
		item.Text = name:upper()
		item.TextSize = 13
		item.TextWrapped = true
		item.Font = Enum.Font.GothamBold
		item.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = item
		local edge = outline(item, if self.DetailTab == name then Theme.Gold else Theme.Border, 1)
		item.SelectionGained:Connect(function()
			edge.Color, edge.Thickness = Theme.Gold, 3
		end)
		item.SelectionLost:Connect(function()
			edge.Color, edge.Thickness = if self.DetailTab == name then Theme.Gold else Theme.Border, 1
		end)
		item.Activated:Connect(function()
			self.DetailTab = name
			ctx.rebuild()
		end)
	end
	local function details(record)
		local d = record.Definition
		if self.DetailTab == "Overview" then
			ctx.info(Summary.describe(d, ctx.schema, ctx.spec), 180)
		elseif self.DetailTab == "Effects" then
			local lines = {}
			for _, event in ipairs(ctx.schema.EventOrder) do
				for _, step in ipairs(d.Triggers[event] or {}) do
					local effects = {}
					for _, payload in ipairs(step.Payloads or {}) do
						table.insert(
							effects,
							(ctx.schema.Payloads[payload.Kind] and ctx.schema.Payloads[payload.Kind].Label)
								or payload.Kind
						)
					end
					if step.Behavior then
						table.insert(effects, step.Behavior)
					end
					if #effects > 0 then
						table.insert(
							lines,
							(ctx.schema.EventLabels[event] or event) .. "  →  " .. table.concat(effects, ", ")
						)
					end
				end
			end
			ctx.info(#lines > 0 and table.concat(lines, "\n") or "No effects configured.", 110)
		elseif self.DetailTab == "Requirements" then
			local rules = d.TargetRules or {}
			ctx.info(
				"Target: "
					.. tostring(d.Targeting)
					.. "\nRange: "
					.. tostring(rules.Range or "form default")
					.. "\nRelationship: "
					.. tostring(rules.Relationship or "Any")
					.. "\nLine of sight: "
					.. (rules.RequiresLineOfSight and "required" or "not required")
					.. "\nMaterial: "
					.. (d.Material and tostring(d.Material.Material or "eligible tagged object") or "none"),
				120
			)
		else
			ctx.info(
				"Element: "
					.. tostring(d.Element)
					.. "\nVisual palette: "
					.. tostring((d.Visual or {}).Palette or "custom")
					.. "\nCasting mode: "
					.. tostring((d.Casting or {}).Mode or "Instant")
					.. "\nForm: "
					.. tostring(d.Form),
				110
			)
		end
	end
	local function renderRecord(record)
		local d = record.Definition
		ctx.showPreview(d)
		local sidePreview = ctx.hasSidePreview()
		if self.ChoosingSlot then
			action(
				"Place this premade spell in slot " .. self.ChoosingSlot,
				"EQUIP IN SLOT " .. self.ChoosingSlot,
				function()
					command("Equip", { Slot = self.ChoosingSlot })
				end
			)
		end
		action("Return to the spell collection", "‹ ALL SPELLS", function()
			self.Selected = nil
			ctx.rebuild()
			ctx.top()
		end)
		local hero = ctx.block(if sidePreview then 110 else 164)
		hero.BackgroundColor3 = Theme.Surface
		hero.BackgroundTransparency = 0
		local heroCorner = Instance.new("UICorner")
		heroCorner.CornerRadius = UDim.new(0, 8)
		heroCorner.Parent = hero
		outline(hero, Theme.Border, 1)
		if not sidePreview then
			local icon = Instance.new("Frame")
			icon.Name = "GeneratedSpellPreview"
			icon.Position = UDim2.fromOffset(15, 15)
			icon.Size = UDim2.fromOffset(125, 132)
			icon.Parent = hero
			SpellVisual.render(icon, d, false)
		end
		local textLeft = if sidePreview then 14 else 154
		local textMargin = if sidePreview then 28 else 168
		label(
			hero,
			d.Name,
			26,
			Theme.Ink,
			UDim2.fromOffset(textLeft, 9),
			UDim2.new(1, -textMargin, 0, 42),
			Enum.Font.GothamBold
		)
		label(
			hero,
			(if isCurated(record) then "CURATED SPELL" else "YOUR SPELL") .. "  ·  " .. d.Form .. "  ·  " .. d.Element,
			11,
			Theme.Gold,
			UDim2.fromOffset(textLeft, 50),
			UDim2.new(1, -textMargin, 0, 24),
			Enum.Font.GothamBold
		)
		label(
			hero,
			descriptions[d.Name] or "A saved spell in your library.",
			12,
			Theme.MutedInk,
			UDim2.fromOffset(textLeft, 75),
			UDim2.new(1, -textMargin, 0, if sidePreview then 30 else 70)
		)
		local assigned = {}
		for slot, id in pairs(self.Catalog.Assignments) do
			if id == self.Selected then
				table.insert(assigned, slot)
			end
		end
		table.sort(assigned)
		ctx.info(
			if #assigned > 0
				then "EQUIPPED IN SLOT " .. table.concat(assigned, ", ")
				else "SAVED IN LIBRARY · NOT EQUIPPED",
			34
		)
		if not self.Catalog.Unrestricted and self.Catalog.Progression then
			local profile = self.Catalog.Progression
			local rank = ProgressionRules.rank(profile, self.Selected)
			local priced = ctx.spec.copy(d)
			local values = ProgressionRules.reprice(priced, ctx.spec.estimate, ctx.spec.copy)
			local usable, reason = ProgressionRules.canUse(profile, d, self.Selected, ctx.spec.estimate)
			ctx.info(
				string.format(
					"COMBAT RANK %d / 3 · %d MANA · %d STRAIN · %d COMPLEXITY · %.2fs COOLDOWN\n%s",
					rank,
					values.ManaDemand,
					values.Strain,
					values.Complexity,
					priced.Casting.Cooldown,
					if usable then "READY FOR LIVE COMBAT" else reason
				),
				68
			)
			if rank < #ProgressionConfig.RankPrices then
				local nextRank = rank + 1
				local price = ProgressionConfig.RankPrices[nextRank]
				local xp = ProgressionConfig.RankXP[nextRank]
				action(
					string.format(
						"Rank %d raises this spell's limits to %d mana, %d strain and %d complexity. Edit it to use the added room. Requires %d XP and %d Marks",
						nextRank,
						ProgressionConfig.RankManaLimits[nextRank + 1],
						ProgressionConfig.RankStrainLimits[nextRank + 1],
						ProgressionConfig.RankComplexityLimits[nextRank + 1],
						xp,
						price
					),
					"UPGRADE SPELL",
					function()
						ctx.confirm(
							"Spend " .. price .. " Marks to upgrade “" .. d.Name .. "” to rank " .. nextRank .. "?",
							function()
								purchase("Rank", self.Selected, rank)
							end
						)
					end
				)
			end
		end
		local columns = if ctx.width() >= 470 then 4 else 2
		for row = 1, math.ceil(4 / columns) do
			local tabs = ctx.block((if columns == 4 then 104 else 84) + 4)
			for column = 1, columns do
				local index = (row - 1) * columns + column
				local names = { "Overview", "Effects", "Requirements", "Appearance" }
				if names[index] then
					tabButton(tabs, names[index], column, columns)
				end
			end
		end
		details(record)
		if self.ChoosingSlot then
			return
		end
		ctx.heading("USE THIS SPELL")
		action("Edit as a working copy. Saving updates this library record.", "EDIT SPELL", function()
			ctx.editRecord(self.Selected, record.Definition)
		end)
		action("Make a separate saved copy", "DUPLICATE", function()
			command("Duplicate")
		end)
		if record.Archived then
			action("Return this spell to the active library", "RESTORE", function()
				command("Restore")
			end)
		else
			cycle("Combat destination", self.Slot, { 1, 2, 3, 4, 5, 6, 7, 8, 9 }, function(value)
				self.Slot = value
			end)
			action("Explicitly place this saved spell in a combat slot", "EQUIP & EDIT…", function()
				ctx.confirm(
					"Replace slot "
						.. self.Slot
						.. " with “"
						.. d.Name
						.. "”? Unsaved edits in that slot will be discarded. The library spell remains saved.",
					function()
						ctx.pendingEdit(self.Slot)
						command("Equip", { Slot = self.Slot })
					end
				)
			end)
			for _, slot in ipairs(assigned) do
				action("Equipped in slot " .. slot, "UNEQUIP…", function()
					ctx.confirm("Unequip slot " .. slot .. "? Its saved spell remains in the library.", function()
						command("Unequip", { Slot = tonumber(slot) })
					end)
				end)
			end
		end
		ctx.heading("ORGANIZE")
		field("Name (Enter)", d.Name, function(value)
			if value ~= d.Name then
				command("Rename", { Name = value })
			end
		end)
		field("Labels (Enter)", Library.labels(record), function(value)
			if value ~= Library.labels(record) then
				command("Tags", { Tags = value })
			end
		end)
		cycle("Collection", record.Collection, self.Catalog.Collections, function(value)
			command("Move", { Collection = value })
		end)
		action("Keep this spell close", record.Favorite and "REMOVE BOOKMARK" or "BOOKMARK", function()
			command("Favorite")
		end)
		if record.Archived then
			action("Remove this archived spell forever", "DELETE…", function()
				ctx.confirm("Permanently delete “" .. d.Name .. "”? This cannot be undone.", function()
					command("Delete")
				end)
			end)
		else
			action("Keep this spell in the archive", "ARCHIVE…", function()
				ctx.confirm("Archive “" .. d.Name .. "”? Unequip it first if it is in a combat slot.", function()
					command("Archive")
				end)
			end)
		end
	end
	local function renderCatalog()
		local mine, curated = {}, {}
		for _, result in ipairs(Library.query(self.Catalog, self.Query)) do
			table.insert(if isCurated(result.Record) then curated else mine, result)
		end
		local results = if self.Shelf == "Curated" then curated else mine
		local shelfBar = ctx.block(44)
		shelfBar.Name = "LibraryShelves"
		for index, shelf in ipairs({
			{ Id = "Mine", Label = "MY SPELLS", Count = #mine },
			{ Id = "Curated", Label = "CURATED SPELLS", Count = #curated },
		}) do
			local active = self.Shelf == shelf.Id
			local tab = K.pill(shelfBar, shelf.Label .. "  ·  " .. shelf.Count, function()
				if not active then
					self.Shelf, self.Page = shelf.Id, 1
					ctx.rebuild()
				end
			end)
			tab.Name = "Shelf_" .. shelf.Id
			tab.Size = UDim2.new(0.5, -5, 0, 38)
			tab.Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 5, 0, 2)
			tab.BackgroundColor3 = if active then K.C.Gold else K.C.Card
			tab.TextColor3 = if active then K.C.Backdrop else K.C.Ink
		end
		local columns = if ctx.width() >= 620 then 6 else 3
		local pageSize = columns * 3
		local spellPages = math.max(1, math.ceil(#results / pageSize))
		local function nextValue(value, choices)
			local index = table.find(choices, value) or 0
			return choices[index % #choices + 1]
		end
		local toolOptions = {}
		local function tool(labelText, detailText, symbol, actionCallback, inputValue, onInput)
			table.insert(toolOptions, {
				Label = labelText,
				Detail = detailText,
				Symbol = symbol,
				Action = actionCallback,
				Input = inputValue,
				OnInput = onInput,
			})
		end
		tool("UPGRADES", "Unlock spellcraft and view loadout growth", "✦", function()
			self.ProgressionPage = true
			ctx.rebuild()
		end)
		tool("SEARCH", "Find a spell by name", "⌕", nil, self.Query.Search, function(value)
			self.Query.Search, self.Page = value, 1
			ctx.rebuild()
		end)
		local statuses = { "Active", "Favorites", "Equipped", "Unequipped", "Archived" }
		tool("SHOW", self.Query.Status, "◉", function()
			self.Query.Status, self.Page = nextValue(self.Query.Status, statuses), 1
			ctx.rebuild()
		end)
		local sorts = { "Name", "Recent", "Cost" }
		tool("SORT", self.Query.Sort, "↕", function()
			self.Query.Sort, self.Page = nextValue(self.Query.Sort, sorts), 1
			ctx.rebuild()
		end)
		local collections = { "All" }
		for _, name in ipairs(self.Catalog.Collections) do
			table.insert(collections, name)
		end
		tool("COLLECTION", self.Query.Collection, "▦", function()
			self.Query.Collection, self.Page = nextValue(self.Query.Collection, collections), 1
			ctx.rebuild()
		end)
		local forms = { "All" }
		for _, name in ipairs(ctx.schema.FormOrder) do
			table.insert(forms, name)
		end
		tool("FORM", self.Query.Form, "◇", function()
			self.Query.Form, self.Page = nextValue(self.Query.Form, forms), 1
			ctx.rebuild()
		end)
		local elements = { "All" }
		for _, name in ipairs(ctx.schema.Elements) do
			table.insert(elements, name)
		end
		tool("ELEMENT", self.Query.Element, "✦", function()
			self.Query.Element, self.Page = nextValue(self.Query.Element, elements), 1
			ctx.rebuild()
		end)
		tool("RESET FILTERS", "Show every active spell", "↺", function()
			self.Query =
				{ Search = "", Sort = "Name", Status = "Active", Collection = "All", Form = "All", Element = "All" }
			self.Page = 1
			ctx.rebuild()
		end)
		tool("NEW COLLECTION", "Name a collection", "+", nil, "", function(value)
			if value ~= "" then
				command("Collection", { Name = value })
			end
		end)
		tool("NEW SPELL", "Create without a combat slot", "+", ctx.createNew)
		if ctx.hasWorkingDraft() then
			tool("RESUME DRAFT", "Continue your saved work", "↗", ctx.resumeDraft)
		end
		tool("EQUIPPED", "Return to the nine slots", "◇", ctx.slots)
		tool("HELP", "Read the spell guide", "?", ctx.help)
		tool("SAVE LIBRARY", self.Catalog.SaveState or "Save your collection", "✧", function()
			command("RetrySave")
		end)
		local toolPages = math.ceil(#toolOptions / pageSize)
		local totalPages = spellPages + toolPages
		self.Page = math.clamp(self.Page, 1, totalPages)
		local holder = ctx.block(ctx.height())
		holder.Name = "LibrarySpread"
		holder.Size = UDim2.new(1, -8, 1, -54)
		local tiles = {}
		local showingSpells = self.Page <= spellPages
		if showingSpells then
			for offset = 1, pageSize do
				local result = results[(self.Page - 1) * pageSize + offset]
				if result then
					table.insert(tiles, card(holder, result, offset, columns))
				end
			end
		else
			local toolPage = self.Page - spellPages
			for offset = 1, pageSize do
				local option = toolOptions[(toolPage - 1) * pageSize + offset]
				if option then
					local tile = Instance.new("TextButton")
					tile.Name = "LibraryTool_" .. option.Label
					tile.Size = UDim2.fromOffset(120, 120)
					tile.BackgroundColor3 = Theme.Surface
					tile.BorderSizePixel = 0
					tile.Text = ""
					tile.Parent = holder
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 10)
					corner.Parent = tile
					outline(tile, Theme.Border, 1)
					label(
						tile,
						option.Symbol,
						33,
						Theme.Gold,
						UDim2.fromScale(0.1, 0.08),
						UDim2.fromScale(0.8, 0.32),
						Enum.Font.GothamBold
					).TextXAlignment =
						Enum.TextXAlignment.Center
					label(
						tile,
						option.Label,
						13,
						Theme.Ink,
						UDim2.fromScale(0.05, 0.45),
						UDim2.fromScale(0.9, 0.2),
						Enum.Font.GothamBold
					).TextXAlignment =
						Enum.TextXAlignment.Center
					if option.OnInput then
						local box = Instance.new("TextBox")
						box.Position = UDim2.fromScale(0.08, 0.7)
						box.Size = UDim2.fromScale(0.84, 0.22)
						box.BackgroundColor3 = K.C.Input
						box.TextColor3 = Theme.Ink
						box.BorderColor3 = Theme.TileEdge
						box.TextSize = 12
						box.ClearTextOnFocus = false
						box.PlaceholderText = option.Detail
						box.Text = option.Input or ""
						box.Parent = tile
						box.FocusLost:Connect(function()
							option.OnInput(box.Text)
						end)
					else
						label(
							tile,
							option.Detail,
							11,
							Theme.MutedInk,
							UDim2.fromScale(0.07, 0.7),
							UDim2.fromScale(0.86, 0.2),
							Enum.Font.Gotham
						).TextXAlignment =
							Enum.TextXAlignment.Center
						if option.Action then
							tile.Activated:Connect(option.Action)
						end
					end
					table.insert(tiles, tile)
				end
			end
		end
		local function turn(direction)
			self.Page = math.clamp(self.Page + direction, 1, totalPages)
			ctx.rebuild()
			ctx.top()
		end
		local function arrow(symbol, nextPage)
			local button = Instance.new("TextButton")
			button.Name = if nextPage then "NextLibraryPage" else "PreviousLibraryPage"
			button.Size = UDim2.fromOffset(40, 35)
			button.BackgroundColor3 = Theme.Accent
			button.TextColor3 = Theme.OnAccent
			button.Text = symbol
			button.TextSize = 27
			button.Font = Enum.Font.GothamBold
			button.Parent = holder
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = button
			button.Activated:Connect(function()
				turn(if nextPage then 1 else -1)
			end)
			return button
		end
		local previous = if self.Page > 1 then arrow("‹", false) else nil
		local nextPage = if self.Page < totalPages then arrow("›", true) else nil
		if showingSpells and #results == 0 then
			label(
				holder,
				if self.Shelf == "Curated"
					then "No curated spells match these filters."
					else "You haven't saved any spells yet. Use NEW SPELL, or open a curated spell and duplicate it to make it yours.",
				13,
				Theme.MutedInk,
				UDim2.fromScale(0.1, 0.3),
				UDim2.fromScale(0.8, 0.2),
				Enum.Font.GothamMedium
			).TextXAlignment =
				Enum.TextXAlignment.Center
		end
		local pageLabel = label(
			holder,
			(
				if showingSpells
					then tostring(#results) .. (if self.Shelf == "Curated" then " CURATED" else " OF YOURS")
					else "LIBRARY TOOLS"
			)
				.. "  ·  PAGE "
				.. self.Page
				.. " / "
				.. totalPages,
			11,
			Theme.Ink,
			UDim2.new(),
			UDim2.fromOffset(170, 30),
			Enum.Font.GothamBold
		)
		pageLabel.TextXAlignment = Enum.TextXAlignment.Center
		local function layoutSpread()
			local width, height = holder.AbsoluteSize.X, holder.AbsoluteSize.Y
			local geometry = LibraryLayout.compute(width, height, columns, #tiles)
			for index, tile in ipairs(tiles) do
				local position = geometry.Positions[index]
				tile.Position = UDim2.fromOffset(position.X, position.Y)
				tile.Size = UDim2.fromOffset(geometry.Cell, geometry.Cell)
			end
			if previous then
				previous.Position = UDim2.fromOffset(3, geometry.ArrowY)
			end
			if nextPage then
				nextPage.Position = UDim2.fromOffset(width - 43, geometry.ArrowY)
			end
			pageLabel.Position = UDim2.fromOffset(math.floor((width - 170) / 2), geometry.LabelY)
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSpread)
		layoutSpread()
	end

	function self.render()
		if self.ProgressionPage then
			action("Return to saved spells", "‹ ALL SPELLS", function()
				self.ProgressionPage = false
				ctx.rebuild()
			end)
			local profile = self.Catalog.Progression
			if self.Catalog.Unrestricted then
				ctx.info("Studio test mode: all spell options and slots are available.", 60)
			elseif not profile then
				ctx.info("Combat progression is unavailable. Reopen the spell screen to retry.", 60)
			else
				ctx.heading("COMBAT PROGRESSION")
				ctx.info(
					string.format(
						"%d XP · %d MARKS · %d / 9 LOADOUT SLOTS",
						profile.XP,
						profile.Marks,
						ProgressionRules.slots(profile)
					),
					54
				)
				for _, milestone in ipairs(ProgressionConfig.SlotMilestones) do
					ctx.info(
						string.format(
							"%d slots at %d XP · %s",
							milestone.Slots,
							milestone.XP,
							if profile.XP >= milestone.XP then "UNLOCKED" else "LOCKED"
						),
						38
					)
				end
				ctx.heading("SPELLCRAFT UNLOCKS")
				for _, id in ipairs(ProgressionConfig.UnlockOrder) do
					local offer = ProgressionConfig.Unlocks[id]
					if profile.Unlocks and profile.Unlocks[id] then
						ctx.info(offer.Name .. " · UNLOCKED\n" .. offer.Label, 50)
					else
						action(
							string.format("%s · requires %d XP and %d Marks", offer.Label, offer.XP, offer.Marks),
							"UNLOCK " .. string.upper(offer.Name),
							function()
								ctx.confirm(
									"Spend " .. offer.Marks .. " Marks to unlock " .. offer.Name .. "?",
									function()
										purchase("Unlock", id, nil)
									end
								)
							end
						)
					end
				end
			end
			return
		end
		local record = self.Selected and self.Catalog.Records[self.Selected]
		if self.Busy and record then
			ctx.info("Updating the library…", 34)
		end
		if record then
			renderRecord(record)
		else
			renderCatalog()
		end
	end
	function self.dismissHelp()
		command("DismissHelp")
	end
	return self
end
return View
