--!strict
-- Bottom-centre hotbar: [melee combo] [spell slots 1–6] [spellbook] [consumable].
-- Slots show glyph, keybind, mana cost, cooldown sweep and selection. Grimoire
-- library cards can be dragged onto any unlocked slot to equip them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)
local SpellState = require(script.Parent.SpellState)
local InputMode = require(script.Parent.Parent.Kit.InputMode)

local SpellBar = {}
local Color = Theme.Color
local DragThreshold = 8

local function glyph(name: string): string
	local letters = {}
	for word in string.gmatch(name, "%a+") do
		table.insert(letters, string.upper(string.sub(word, 1, 1)))
		if #letters == 2 then
			break
		end
	end
	return if #letters > 0 then table.concat(letters) else "◆"
end

type Slot = {
	Button: TextButton,
	Glyph: TextLabel,
	Key: TextLabel,
	Cost: TextLabel,
	Sweep: Frame,
	Seconds: TextLabel,
	Stroke: UIStroke,
	Dim: Frame,
}

function SpellBar.new(gui: ScreenGui, openSpellbook: () -> ())
	local player = Players.LocalPlayer
	local root = C.root(gui)
	local size, gap = Theme.Size.Slot, Theme.Size.SlotGap
	local count = Theme.Size.SlotsShown
	local row = C.new("Frame", {
		Name = "SpellBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(0, size),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, root)
	C.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

	-- Melee combo (3 pips) on the left end.
	local combo = C.panel(row, { Name = "Combo", LayoutOrder = 0, Size = UDim2.fromOffset(62, size) })
	C.text(combo, "COMBO", Theme.TextSize.Tiny, Color.Muted, Theme.Font.Strong, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 12),
	})
	local pips: { Frame } = {}
	for index = 1, 3 do
		local pip = C.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (index - 2) * 17, 0, 30),
			Size = UDim2.fromOffset(11, 11),
			Rotation = 45,
			BackgroundColor3 = Color.Track,
			BorderSizePixel = 0,
		}, combo)
		C.new("UIStroke", { Color = Color.Brass, Transparency = 0.3 }, pip)
		pips[index] = pip
	end
	local dash = C.text(combo, "", Theme.TextSize.Tiny, Color.Bone, Theme.Font.Number, {
		Position = UDim2.new(0, 0, 1, -15),
		Size = UDim2.new(1, 0, 0, 12),
	})

	local slots: { Slot } = {}
	for index = 1, count do
		local button = C.new("TextButton", {
			Name = "Slot" .. index,
			LayoutOrder = index,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Color.Panel,
			BackgroundTransparency = Theme.Transparency.Panel,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Selectable = false,
		}, row)
		C.new("UIAspectRatioConstraint", { AspectRatio = 1 }, button)
		C.new("UICorner", { CornerRadius = UDim.new(0, Theme.Size.Corner) }, button)
		local stroke = C.new("UIStroke", {
			Color = Color.Brass,
			Transparency = Theme.Transparency.Stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, button)
		C.rivets(button)
		C.hover(button)
		local glyphLabel = C.text(button, "+", Theme.TextSize.Title, Color.Faint, Theme.Font.Display, {
			Size = UDim2.fromScale(1, 1),
		})
		local sweep = C.new("Frame", {
			Name = "Cooldown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, button)
		local seconds = C.text(button, "", Theme.TextSize.Label, Color.Text, Theme.Font.Number, {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			TextStrokeTransparency = 0.2,
		})
		local dim = C.new("Frame", {
			Name = "NoMana",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(40, 40, 48),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 2,
		}, button)
		local key = C.text(button, Theme.SlotKeys[index], Theme.TextSize.Tiny, Color.Bone, Theme.Font.Number, {
			Position = UDim2.fromOffset(3, 1),
			Size = UDim2.fromOffset(22, 13),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		})
		local cost = C.text(button, "", Theme.TextSize.Tiny, Color.Mana, Theme.Font.Number, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -1),
			Size = UDim2.fromOffset(30, 13),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 5,
		})
		button.Activated:Connect(function()
			if not SpellState.Slots[index] and index <= SpellState.SlotLimit then
				openSpellbook()
			end
		end)
		slots[index] = {
			Button = button,
			Glyph = glyphLabel,
			Key = key,
			Cost = cost,
			Sweep = sweep,
			Seconds = seconds,
			Stroke = stroke,
			Dim = dim,
		}
	end

	local book = C.button(row, "✦", {
		Name = "Spellbook",
		LayoutOrder = count + 1,
		Size = UDim2.fromOffset(30, size),
		TextSize = Theme.TextSize.Label,
		Font = Theme.Font.Strong,
	})
	book.Activated:Connect(openSpellbook)

	-- Quick consumable slots (Y, U) on the right end.
	type Quick = { Key: TextLabel, Name: TextLabel, Count: TextLabel }
	local quicks: { Quick } = {}
	for index = 1, 2 do
		local quick = C.panel(row, {
			Name = "Consumable" .. index,
			LayoutOrder = count + 1 + index,
			Size = UDim2.fromOffset(size + 34, size),
		})
		quicks[index] = {
			Key = C.text(quick, "", Theme.TextSize.Tiny, Color.Gold, Theme.Font.Number, {
				Position = UDim2.fromOffset(4, 3),
				Size = UDim2.new(1, -8, 0, 13),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Name = C.text(quick, "Empty", Theme.TextSize.Tiny, Color.Faint, Theme.Font.Body, {
				Position = UDim2.fromOffset(4, 17),
				Size = UDim2.new(1, -8, 0, 22),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Count = C.text(quick, "", Theme.TextSize.Small, Color.Bone, Theme.Font.Number, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -2),
				Size = UDim2.fromOffset(40, 15),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}
	end

	-- Active weapon (E switches) on the far left.
	local weapon = C.panel(row, { Name = "Weapon", LayoutOrder = -1, Size = UDim2.fromOffset(size + 46, size) })
	C.text(weapon, "[E] WEAPON", Theme.TextSize.Tiny, Color.Gold, Theme.Font.Number, {
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local weaponName = C.text(weapon, "Unarmed", Theme.TextSize.Tiny, Color.Faint, Theme.Font.Body, {
		Position = UDim2.fromOffset(4, 17),
		Size = UDim2.new(1, -8, 1, -20),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- Drag ghost that follows the pointer while dragging a Grimoire card.
	local ghost = C.panel(gui, {
		Name = "DragGhost",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Visible = false,
		ZIndex = 20,
	})
	local ghostText = C.text(ghost, "", Theme.TextSize.Title, Color.Gold, Theme.Font.Display, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 21,
	})

	local function slotUnder(point: Vector2): number?
		for index, slot in slots do
			local at, extent = slot.Button.AbsolutePosition, slot.Button.AbsoluteSize
			if point.X >= at.X and point.X <= at.X + extent.X and point.Y >= at.Y and point.Y <= at.Y + extent.Y then
				return index
			end
		end
		return nil
	end

	local function refresh()
		local gamepad = InputMode.get() == "Gamepad"
		for index, slot in slots do
			local info = SpellState.Slots[index]
			local locked = index > SpellState.SlotLimit
			local selected = gamepad and SpellState.Selected == index and info ~= nil
			slot.Key.Text = if gamepad then (if selected then Theme.GamepadCastGlyph else "") else Theme.SlotKeys[index]
			if info then
				slot.Glyph.Text = glyph(info.Name)
				slot.Glyph.TextColor3 = info.Color or Color.Gold
				slot.Cost.Text = if info.ManaCost > 0 then tostring(math.floor(info.ManaCost)) else ""
			else
				slot.Glyph.Text = if locked then "✕" else "+"
				slot.Glyph.TextColor3 = Color.Faint
				slot.Cost.Text = ""
			end
			slot.Button.BackgroundTransparency = if locked then 0.6 else Theme.Transparency.Panel
			slot.Stroke.Color = if selected then Color.Gold else Color.Brass
			slot.Stroke.Thickness = if selected then 2 else 1
			slot.Stroke.Transparency = if selected then 0 else Theme.Transparency.Stroke
		end
	end
	SpellState.Changed:Connect(refresh)
	InputMode.Changed:Connect(refresh)
	refresh()

	local releaseConnection = UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local drag = SpellState.Drag
		if not drag then
			return
		end
		if drag.Active then
			local target = slotUnder(UserInputService:GetMouseLocation())
			if target and target <= SpellState.SlotLimit then
				SpellState.equip(drag.Id, target)
			end
		end
		SpellState.endDrag()
	end)

	local visible = true
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local mana = player:GetAttribute("MagicMana")
		local drag = SpellState.Drag
		local pointer = UserInputService:GetMouseLocation()
		if drag and not drag.Active and (pointer - drag.Start).Magnitude >= DragThreshold then
			drag.Active = true
			ghostText.Text = glyph(drag.Name)
			ghostText.TextColor3 = drag.Color or Color.Gold
		end
		local dragging = drag ~= nil and drag.Active
		-- While the Grimoire is open the bar only appears as a drop target.
		row.Visible = visible and (player:GetAttribute("MagicLabOpen") ~= true or dragging)
		ghost.Visible = dragging
		if dragging then
			ghost.Position = UDim2.fromOffset(pointer.X, pointer.Y)
		end
		local hovered = if dragging then slotUnder(pointer) else nil
		for index, slot in slots do
			local info = SpellState.Slots[index]
			local ends = SpellState.CooldownEnds[index]
			local remaining = if ends then ends - now else 0
			local duration = SpellState.CooldownDurations[index] or (info and info.Cooldown) or 0
			if info and remaining > 0 and duration > 0 then
				slot.Sweep.Size = UDim2.fromScale(1, math.clamp(remaining / duration, 0, 1))
				slot.Seconds.Text = if remaining >= 10
					then string.format("%d", math.ceil(remaining))
					else string.format("%.1f", remaining)
			else
				slot.Sweep.Size = UDim2.fromScale(1, 0)
				slot.Seconds.Text = ""
			end
			slot.Dim.Visible = info ~= nil and type(mana) == "number" and mana < info.ManaCost
			if hovered == index then
				slot.Stroke.Color = if index <= SpellState.SlotLimit then Color.Ok else Color.Error
				slot.Stroke.Thickness = 2
			elseif dragging then
				slot.Stroke.Color = Color.Brass
				slot.Stroke.Thickness = 1
			end
		end
	end)

	return {
		Root = root,
		SetVisible = function(value: boolean)
			visible = value
		end,
		UpdateCombo = function(step: number, dashCooldown: number)
			for index, pip in pips do
				pip.BackgroundColor3 = if step > 0 and index <= step then Color.Gold else Color.Track
			end
			dash.Text = if dashCooldown > 0 then string.format("Q %.1f", dashCooldown) else ""
		end,
		SetConsumable = function(index: number, keyText: string, name: string?, amount: number?)
			local quick = quicks[index]
			if not quick then
				return
			end
			quick.Key.Text = "[" .. keyText .. "]"
			quick.Name.Text = name or "Empty"
			quick.Name.TextColor3 = if name then Color.Text else Color.Faint
			quick.Count.Text = if amount and amount > 1 then "×" .. amount else ""
		end,
		SetWeapon = function(name: string?, color: Color3?)
			weaponName.Text = name or "Unarmed"
			weaponName.TextColor3 = if name then color or Color.Text else Color.Faint
		end,
		Destroy = function()
			releaseConnection:Disconnect()
		end,
	}
end

return SpellBar
