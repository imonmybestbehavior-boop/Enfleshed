--!strict

-- Inventory panel (bag grid, equipment column, tooltip, context menu, drag and
-- drop) plus an always-visible kit strip showing the active weapon and quick slots.
local Players = game:GetService("Players")
local GamepadNav = require(script.Parent.Kit.GamepadNav)
local InputMode = require(script.Parent.Kit.InputMode)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Modules.ItemRules)
local Model = require(Shared.Modules.InventoryModel)
local Theme = require(script.Parent.GrimoireTheme)

local View = {}

local CELL = 64
local GAP = 6
local COLUMNS = 6
local SLOT_HEIGHT = 46
local EQUIP_WIDTH = 200
local PAD = 18

local equipLabels = {
	{ Location = "Equip:MainHand", Label = "Main Hand" },
	{ Location = "Equip:MagicFocus", Label = "Focus" },
	{ Location = "Equip:Head", Label = "Head" },
	{ Location = "Equip:Body", Label = "Body" },
	{ Location = "Equip:Legs", Label = "Legs" },
	{ Location = "Quick:1", Label = "Quick (Y)" },
	{ Location = "Quick:2", Label = "Quick (U)" },
}

local function make(className: string, properties: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className) :: any
	for key, value in properties do
		object[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return make(
		"UIStroke",
		{ Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		parent
	)
end

local function text(parent: Instance, properties: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Ink,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in properties do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

function View.new(controller: any)
	local player = Players.LocalPlayer
	local gui = make("ScreenGui", {
		Name = "EnfleshedInventory",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local bagRows = math.ceil(Model.BagSize / COLUMNS)
	local gridWidth = COLUMNS * CELL + (COLUMNS - 1) * GAP
	local gridHeight = bagRows * CELL + (bagRows - 1) * GAP
	local equipHeight = #equipLabels * (SLOT_HEIGHT + GAP) - GAP
	local bodyHeight = math.max(gridHeight, equipHeight)
	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PAD * 3 + EQUIP_WIDTH + gridWidth, 56 + bodyHeight + 44),
		BackgroundColor3 = Theme.Page,
		Visible = false,
	}, gui)
	corner(panel, 10)
	stroke(panel, Theme.PageEdge, 3)
	make("UISizeConstraint", { MinSize = Vector2.new(300, 300) }, panel)
	-- Shrink to fit small screens while keeping pixel layout math simple.
	local scale = make("UIScale", {}, panel)
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			local size = panel.Size
			scale.Scale = math.min(1, (viewport.X - 32) / size.X.Offset, (viewport.Y - 32) / size.Y.Offset)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	text(panel, {
		Text = "Kit & Pack",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Position = UDim2.fromOffset(PAD, 12),
		Size = UDim2.new(1, -PAD * 2 - 40, 0, 30),
	})
	local close = make("TextButton", {
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Theme.Ink,
		BackgroundColor3 = Theme.Surface,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 12),
		Size = UDim2.fromOffset(30, 30),
		AutoButtonColor = true,
	}, panel)
	corner(close, 6)
	text(panel, {
		Text = "Drag to move · Right-click for actions · Shift-click splits a stack · Drag outside to drop · [I] close",
		TextColor3 = Theme.MutedInk,
		TextSize = 12,
		Position = UDim2.new(0, PAD, 1, -36),
		Size = UDim2.new(1, -PAD * 2, 0, 28),
	})

	local cells: { [string]: any } = {}
	local function makeCell(location: string, parent: Instance, position: UDim2, size: UDim2, label: string?)
		local button = make("TextButton", {
			Name = location,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Surface,
			Position = position,
			Size = size,
		}, parent)
		button:SetAttribute("InvLocation", location)
		corner(button, 6)
		local border = stroke(button, Theme.Border, 1.5)
		local iconSize = if label then SLOT_HEIGHT - 10 else CELL - 14
		local icon = make("Frame", {
			Position = UDim2.fromOffset(5, 5),
			Size = if label then UDim2.fromOffset(iconSize, iconSize) else UDim2.new(1, -10, 1, -10),
			BackgroundColor3 = Theme.SurfaceMuted,
			BackgroundTransparency = 1,
		}, button)
		corner(icon, 4)
		local glyph = text(icon, {
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBlack,
			TextSize = if label then 12 else 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Ink,
			Text = "",
		})
		local count = text(button, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -2),
			Size = UDim2.fromOffset(40, 16),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = "",
		})
		local caption = nil
		if label then
			caption = text(button, {
				Position = UDim2.fromOffset(iconSize + 12, 4),
				Size = UDim2.new(1, -iconSize - 16, 1, -8),
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = label,
			})
		end
		cells[location] = {
			Button = button,
			Border = border,
			Icon = icon,
			Glyph = glyph,
			Count = count,
			Caption = caption,
			Label = label,
		}
		return button
	end

	local equipColumn = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, 56),
		Size = UDim2.fromOffset(EQUIP_WIDTH, bodyHeight),
	}, panel)
	for index, slot in equipLabels do
		makeCell(
			slot.Location,
			equipColumn,
			UDim2.fromOffset(0, (index - 1) * (SLOT_HEIGHT + GAP)),
			UDim2.fromOffset(EQUIP_WIDTH, SLOT_HEIGHT),
			slot.Label
		)
	end
	local grid = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD * 2 + EQUIP_WIDTH, 56),
		Size = UDim2.fromOffset(gridWidth, gridHeight),
	}, panel)
	for index = 1, Model.BagSize do
		local column = (index - 1) % COLUMNS
		local row = math.floor((index - 1) / COLUMNS)
		makeCell(
			"Bag:" .. index,
			grid,
			UDim2.fromOffset(column * (CELL + GAP), row * (CELL + GAP)),
			UDim2.fromOffset(CELL, CELL),
			nil
		)
	end

	-- Tooltip
	local tooltip = make("Frame", {
		Name = "Tooltip",
		BackgroundColor3 = Theme.Binding,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(250, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 50,
	}, gui)
	corner(tooltip, 6)
	local tooltipStroke = stroke(tooltip, Theme.BindingEdge, 2)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, tooltip)
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, tooltip)
	local function tooltipLine(order: number, size: number, font: Enum.Font): TextLabel
		return text(tooltip, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = size,
			Font = font,
			TextColor3 = Theme.PageHighlight,
			ZIndex = 51,
		})
	end
	local tipTitle = tooltipLine(1, 16, Enum.Font.GothamBold)
	local tipSubtitle = tooltipLine(2, 12, Enum.Font.GothamMedium)
	local tipLines = tooltipLine(3, 13, Enum.Font.Gotham)
	local tipCompare = tooltipLine(4, 12, Enum.Font.GothamMedium)
	local tipDescription = tooltipLine(5, 12, Enum.Font.Gotham)
	tipSubtitle.TextColor3 = Theme.AccentSoft
	tipDescription.TextColor3 = Theme.PageShade

	-- Context menu
	local menu = make("Frame", {
		Name = "Menu",
		BackgroundColor3 = Theme.Surface,
		Size = UDim2.fromOffset(130, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 60,
	}, gui)
	corner(menu, 6)
	stroke(menu, Theme.Border, 1.5)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, menu)

	-- Drag ghost and notices
	local ghost = make("Frame", {
		Size = UDim2.fromOffset(CELL - 12, CELL - 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.2,
		Visible = false,
		ZIndex = 70,
	}, gui)
	corner(ghost, 4)
	local ghostText = text(ghost, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 71,
	})
	local notice = text(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(420, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Theme.PageHighlight,
		TextStrokeTransparency = 0.4,
		Text = "",
		Visible = false,
		ZIndex = 80,
	})
	local noticeSerial = 0
	controller.Notice:Connect(function(message: string)
		noticeSerial += 1
		local serial = noticeSerial
		notice.Text = message
		notice.Visible = true
		task.delay(2.2, function()
			if serial == noticeSerial then
				notice.Visible = false
			end
		end)
	end)

	-- Kit strip (always visible while the panel is closed)
	local strip = make("Frame", {
		Name = "KitStrip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(360, 40),
		BackgroundColor3 = Theme.Binding,
		BackgroundTransparency = 0.25,
	}, gui)
	strip.Visible = false
	corner(strip, 8)
	stroke(strip, Theme.BindingEdge, 1.5)
	local stripWeapon = text(strip, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.55, -12, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextColor3 = Theme.PageHighlight,
	})
	local stripQuick = text(strip, {
		Position = UDim2.new(0.55, 0, 0, 0),
		Size = UDim2.new(0.45, -12, 1, 0),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextColor3 = Theme.PageShade,
	})

	local open = false
	local dragFrom: string? = nil
	local hovered: string? = nil

	local function itemAt(location: string): Rules.Instance?
		local parsed = Model.parse(location)
		return if parsed then Model.get(controller.Get(), parsed) else nil
	end

	local function compareText(instance: Rules.Instance): string
		local definition = Rules.definition(instance.ItemId)
		local equipped = controller.Get().Equip.MainHand
		if not definition or definition.WeaponType ~= "Melee" or not equipped or equipped.Uid == instance.Uid then
			return ""
		end
		local mine, theirs = Rules.meleeLoadout(instance), Rules.meleeLoadout(equipped)
		if not mine or not theirs then
			return ""
		end
		local function total(loadout: any): number
			local sum = 0
			for _, attack in loadout.Lights do
				sum += attack.Damage
			end
			return sum
		end
		local function signed(value: number): string
			return if value >= 0 then "+" .. tostring(value) else tostring(value)
		end
		return string.format(
			"vs equipped: combo %s · heavy %s · reach %s",
			signed(total(mine) - total(theirs)),
			signed(mine.Heavy.Damage - theirs.Heavy.Damage),
			string.format("%+.1f", mine.Lights[1].Reach - theirs.Lights[1].Reach)
		)
	end

	local function showTooltip(location: string?)
		local instance = if location and not dragFrom and not menu.Visible then itemAt(location) else nil
		if not instance then
			tooltip.Visible = false
			return
		end
		local info = Rules.describe(instance)
		tipTitle.Text = info.Title
		tipTitle.TextColor3 = info.Color
		tooltipStroke.Color = info.Color
		tipSubtitle.Text = info.Subtitle
		tipLines.Text = table.concat(info.Lines, "\n")
		tipLines.Visible = #info.Lines > 0
		local compare = compareText(instance)
		tipCompare.Text = compare
		tipCompare.Visible = compare ~= ""
		tipDescription.Text = info.Description
		tipDescription.Visible = info.Description ~= ""
		tooltip.Visible = true
	end

	local function render()
		local inventory = controller.Get()
		for location, cell in cells do
			local instance = itemAt(location)
			local definition = if instance then Rules.definition(instance.ItemId) else nil
			if instance and definition then
				local rarity = Rules.rarity(instance.Rarity)
				cell.Border.Color = rarity.Color
				cell.Border.Thickness = if rarity.Affixes > 0 then 2.5 else 1.5
				cell.Icon.BackgroundTransparency = 0
				cell.Icon.BackgroundColor3 = if definition.Icon then definition.Icon.Color else Theme.SurfaceMuted
				cell.Glyph.Text = if definition.Icon then definition.Icon.Text else string.sub(instance.ItemId, 1, 3)
				local luminance = cell.Icon.BackgroundColor3.R * 0.3
					+ cell.Icon.BackgroundColor3.G * 0.59
					+ cell.Icon.BackgroundColor3.B * 0.11
				cell.Glyph.TextColor3 = if luminance > 0.5 then Theme.Ink else Theme.PageHighlight
				cell.Count.Text = if instance.Count > 1 then tostring(instance.Count) else ""
				if cell.Caption then
					cell.Caption.Text = cell.Label .. "\n" .. Rules.displayName(instance)
					cell.Caption.TextColor3 = Theme.Ink
				end
			else
				cell.Border.Color = Theme.Border
				cell.Border.Thickness = 1.5
				cell.Icon.BackgroundTransparency = 1
				cell.Glyph.Text = ""
				cell.Count.Text = ""
				if cell.Caption then
					cell.Caption.Text = cell.Label .. "\n—"
					cell.Caption.TextColor3 = Theme.SubtleInk
				end
			end
			cell.Button.BackgroundColor3 = if location == dragFrom then Theme.SurfaceDisabled else Theme.Surface
		end
		local activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
		local active = if activeSlot == "PrimaryWeapon" then inventory.Equip.MagicFocus else inventory.Equip.MainHand
		if active then
			stripWeapon.Text = "[E] " .. Rules.displayName(active)
			stripWeapon.TextColor3 = Rules.rarity(active.Rarity).Color
		else
			stripWeapon.Text = "[E] Unarmed"
			stripWeapon.TextColor3 = Theme.PageShade
		end
		local quick = {}
		for index = 1, Model.QuickSize do
			local instance = inventory.Quick[index]
			local key = controller.Keys.Quick[index]
			local keyName = if key then key.Name else tostring(index)
			table.insert(
				quick,
				string.format(
					"[%s] %s",
					keyName,
					if instance then string.format("%s ×%d", Rules.displayName(instance), instance.Count) else "—"
				)
			)
		end
		stripQuick.Text = table.concat(quick, "   ")
		showTooltip(hovered)
	end

	local function closeMenu()
		menu.Visible = false
		for _, child in menu:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	local function firstEmptyBag(): string?
		local index = Model.firstEmptyBag(controller.Get())
		return if index then "Bag:" .. index else nil
	end

	local function equipTarget(instance: Rules.Instance): string?
		local definition = Rules.definition(instance.ItemId)
		if not definition then
			return nil
		end
		if definition.EquipSlot then
			return "Equip:" .. definition.EquipSlot
		elseif definition.Category == "Consumable" then
			local inventory = controller.Get()
			for index = 1, Model.QuickSize do
				local existing = inventory.Quick[index]
				if not existing or Rules.canStack(existing, instance) then
					return "Quick:" .. index
				end
			end
			return "Quick:1"
		end
		return nil
	end

	local function openMenu(location: string, position: Vector2)
		closeMenu()
		local instance = itemAt(location)
		local definition = if instance then Rules.definition(instance.ItemId) else nil
		if not instance or not definition then
			return
		end
		local options = {}
		local inBag = string.sub(location, 1, 4) == "Bag:"
		if inBag then
			local target = equipTarget(instance)
			if target then
				table.insert(options, {
					Label = if definition.Category == "Consumable" then "To quick slot" else "Equip",
					Run = function()
						controller.Request({ Op = "Move", From = location, To = target })
					end,
				})
			end
		else
			table.insert(options, {
				Label = "Unequip",
				Run = function()
					local target = firstEmptyBag()
					if target then
						controller.Request({ Op = "Move", From = location, To = target })
					end
				end,
			})
		end
		if definition.Category == "Consumable" then
			table.insert(options, {
				Label = "Use",
				Run = function()
					controller.Request({ Op = "Use", From = location })
				end,
			})
		end
		if instance.Count > 1 then
			table.insert(options, {
				Label = "Split half",
				Run = function()
					controller.Request({ Op = "Split", From = location, Amount = math.floor(instance.Count / 2) })
				end,
			})
		end
		if definition.Droppable ~= false then
			table.insert(options, {
				Label = "Drop",
				Run = function()
					controller.Request({ Op = "Drop", From = location })
				end,
			})
		end
		for order, option in options do
			local button = make("TextButton", {
				LayoutOrder = order,
				Text = "  " .. option.Label,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				TextColor3 = Theme.Ink,
				BackgroundColor3 = Theme.Surface,
				BackgroundTransparency = 0,
				AutoButtonColor = true,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 61,
			}, menu)
			button.Activated:Connect(function()
				closeMenu()
				option.Run()
			end)
		end
		menu.Position = UDim2.fromOffset(position.X + 4, position.Y + 4)
		menu.Visible = #options > 0
		tooltip.Visible = false
	end

	local function locationUnder(position: Vector2): string?
		for _, object in player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
			local location = object:GetAttribute("InvLocation")
			if type(location) == "string" then
				return location
			end
		end
		return nil
	end

	local function insidePanel(position: Vector2): boolean
		local topLeft, size = panel.AbsolutePosition, panel.AbsoluteSize
		return position.X >= topLeft.X
			and position.Y >= topLeft.Y
			and position.X <= topLeft.X + size.X
			and position.Y <= topLeft.Y + size.Y
	end

	local function guiMouse(): Vector2
		-- GetMouseLocation includes the top bar inset; GUI objects here do not.
		local inset = game:GetService("GuiService"):GetGuiInset()
		return UserInputService:GetMouseLocation() - inset
	end

	for location, cell in cells do
		local button = cell.Button
		button.MouseEnter:Connect(function()
			hovered = location
			showTooltip(location)
		end)
		button.MouseLeave:Connect(function()
			if hovered == location then
				hovered = nil
				showTooltip(nil)
			end
		end)
		-- Gamepad: A on a focused slot opens the same context menu as right-click.
		button.Activated:Connect(function()
			if open and InputMode.get() == "Gamepad" and itemAt(location) then
				openMenu(location, button.AbsolutePosition + button.AbsoluteSize / 2)
				if menu.Visible then
					game:GetService("GuiService").SelectedObject = GamepadNav.firstSelectable(menu)
				end
			end
		end)
		button.InputBegan:Connect(function(input)
			if not open then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				closeMenu()
				local instance = itemAt(location)
				if not instance then
					return
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and instance.Count > 1 then
					controller.Request({ Op = "Split", From = location, Amount = math.floor(instance.Count / 2) })
					return
				end
				dragFrom = location
				local definition = Rules.definition(instance.ItemId)
				ghost.BackgroundColor3 = if definition and definition.Icon
					then definition.Icon.Color
					else Theme.SurfaceMuted
				ghostText.Text = if definition and definition.Icon then definition.Icon.Text else ""
				ghost.Visible = true
				tooltip.Visible = false
				render()
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				openMenu(location, guiMouse())
			end
		end)
	end

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not dragFrom then
			return
		end
		local from = dragFrom
		dragFrom = nil
		ghost.Visible = false
		local position = guiMouse()
		local target = locationUnder(position)
		if target and target ~= from then
			controller.Request({ Op = "Move", From = from, To = target })
		elseif not target and not insidePanel(position) then
			local instance = itemAt(from)
			local definition = if instance then Rules.definition(instance.ItemId) else nil
			if definition and definition.Droppable ~= false then
				controller.Request({ Op = "Drop", From = from })
			end
		end
		render()
	end)
	UserInputService.InputBegan:Connect(function(input)
		if menu.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Defer so menu buttons receive their Activated first.
			task.defer(function()
				if menu.Visible then
					local position = guiMouse()
					local topLeft, size = menu.AbsolutePosition, menu.AbsoluteSize
					if
						position.X < topLeft.X
						or position.Y < topLeft.Y
						or position.X > topLeft.X + size.X
						or position.Y > topLeft.Y + size.Y
					then
						closeMenu()
					end
				end
			end)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not open then
			return
		end
		local position = guiMouse()
		if dragFrom then
			ghost.Position = UDim2.fromOffset(position.X, position.Y)
		end
		if tooltip.Visible then
			local viewport = gui.AbsoluteSize
			local size = tooltip.AbsoluteSize
			local x = if position.X + 18 + size.X > viewport.X then position.X - size.X - 12 else position.X + 18
			local y = math.clamp(position.Y + 12, 0, math.max(0, viewport.Y - size.Y))
			tooltip.Position = UDim2.fromOffset(x, y)
		end
	end)

	local view = {}
	function view.IsOpen(): boolean
		return open
	end
	function view.SetOpen(value: boolean)
		open = value
		panel.Visible = value
		if value then
			GamepadNav.open(panel, function()
				view.SetOpen(false)
			end)
		else
			GamepadNav.close(panel)
		end
		-- The HUD spell bar now shows the active weapon and quick slots.
		strip.Visible = false
		player:SetAttribute("InventoryOpen", value or nil)
		if not value then
			dragFrom = nil
			hovered = nil
			ghost.Visible = false
			tooltip.Visible = false
			closeMenu()
		end
		render()
	end
	close.Activated:Connect(function()
		view.SetOpen(false)
	end)
	controller.Changed:Connect(render)
	render()
	return view
end

return View
