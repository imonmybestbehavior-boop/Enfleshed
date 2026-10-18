--!strict
-- Spell Forge preview panel: the schematic arena, sigil and sequence readout,
-- redrawn from the draft and animated every frame. Extracted from GuidedSpellForge
-- (Phase 1.7); owns only its own widgets inside `previewPanel`.
local SpellVisual = require(script.Parent.GrimoireSpellVisual)
local C = require(script.Parent.SpellForgeTheme).C
local K = require(script.Parent.SpellForgeComponents)
local CategoryColor = K.CategoryColor
local ElementColor = K.ElementColor
local FormIcon = K.FormIcon
local FormVerb = K.FormVerb
local PayloadVerb = K.PayloadVerb
local EventPhrase = K.EventPhrase
local fmt = K.fmt
local new = K.new
local corner = K.corner
local stroke = K.stroke
local text = K.text
local list = K.list
local PreviewPanel = {}

-- Returns { render = redraw from the draft, step = per-frame animation }.
function PreviewPanel.mount(previewPanel: Frame, draft: any, schema: any, payloadSummary: (any) -> string)
	local arena, previewInfo, sigilFrame, anim
	do
		local headerFrame = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, previewPanel)
		text(headerFrame, "PREVIEW", 13, C.Gold, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.new(1, -32, 0, 18),
		})
		text(
			headerFrame,
			"Schematic drawn from your spell's data · Test Spell casts it for real",
			12,
			C.Faint,
			Enum.Font.Gotham,
			{
				Position = UDim2.fromOffset(16, 23),
				Size = UDim2.new(1, -32, 0, 16),
				TextTruncate = Enum.TextTruncate.AtEnd,
			}
		)
		arena = new("Frame", {
			Name = "Arena",
			Position = UDim2.fromOffset(12, 50),
			Size = UDim2.new(1, -24, 0.62, -104),
			BackgroundColor3 = Color3.fromRGB(13, 11, 16),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, previewPanel)
		corner(arena, 10)
		stroke(arena, C.PanelEdge)
		new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(40, 26, 34), Color3.fromRGB(10, 9, 12)),
			Rotation = 90,
		}, arena)
		sigilFrame = new("Frame", {
			Size = UDim2.fromOffset(84, 84),
			Position = UDim2.new(1, -94, 0, 10),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, arena)
		previewInfo = new("ScrollingFrame", {
			Name = "Sequence",
			Position = UDim2.new(0, 12, 0.62, 8),
			Size = UDim2.new(1, -24, 0.38, -20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, previewPanel)
		list(previewInfo, 6)
	end

	local function arenaShape(name, size, color, round, z)
		local item = new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = size,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 2,
		}, arena)
		if round then
			corner(item, 999)
		end
		return item
	end

	local function mainEvent(scope)
		local form = schema.Forms[scope.Form] or {}
		local preferred = form.DefaultEvent
		if preferred and scope.Triggers and scope.Triggers[preferred] and #scope.Triggers[preferred] > 0 then
			return preferred
		end
		for _, eventName in schema.EventOrder do
			if scope.Triggers and scope.Triggers[eventName] and #scope.Triggers[eventName] > 0 then
				return eventName
			end
		end
		return nil
	end

	local function renderPreview()
		for _, child in arena:GetChildren() do
			if child:IsA("GuiObject") and child ~= sigilFrame then
				child:Destroy()
			end
		end
		for _, child in sigilFrame:GetChildren() do
			child:Destroy()
		end
		pcall(SpellVisual.render, sigilFrame, draft, true)
		local color = ElementColor[draft.Element] or C.Arcane
		local ground = arenaShape("Ground", UDim2.new(1, 0, 0, 2), C.Rail, false, 1)
		ground.Position = UDim2.fromScale(0.5, 0.78)
		local caster = text(arena, "●", 34, C.Ink, Enum.Font.GothamBold, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.14, 0.78),
			Size = UDim2.fromOffset(40, 44),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
		local dummy = text(arena, "■", 34, C.Blood, Enum.Font.GothamBold, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.82, 0.78),
			Size = UDim2.fromOffset(40, 44),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
		text(arena, "YOU", 10, C.Faint, Enum.Font.GothamBlack, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.14, 0.8),
			Size = UDim2.fromOffset(60, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		text(arena, "TARGET", 10, C.Faint, Enum.Font.GothamBlack, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.82, 0.8),
			Size = UDim2.fromOffset(60, 14),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local event = mainEvent(draft)
		local pops = {}
		local explodeRadius, spawnForm
		for _, step in (event and draft.Triggers[event]) or {} do
			if step.Behavior == "Explode" then
				explodeRadius = step.Radius or 7
			elseif step.Behavior == "SpawnEffect" and step.Effect then
				spawnForm = step.Effect.Form
			end
			for _, payload in step.Payloads or {} do
				if #pops < 4 then
					local label = if payload.Kind == "Damage"
						then "−" .. fmt(payload.Amount or 0)
						else string.upper(PayloadVerb[payload.Kind] or payload.Kind)
					local definition = schema.Payloads[payload.Kind] or {}
					table.insert(pops, { Text = label, Color = CategoryColor[definition.Category] or C.Ink })
				end
			end
		end
		local popLabels = {}
		for index, pop in pops do
			popLabels[index] = text(arena, pop.Text, 13, pop.Color, Enum.Font.GothamBlack, {
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.fromOffset(160, 18),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				TextStrokeColor3 = C.Backdrop,
				ZIndex = 6,
			})
		end
		local mechanics = draft[draft.Form] or {}
		local orb = arenaShape("Orb", UDim2.fromOffset(16, 16), color, true, 5)
		local glow = arenaShape("Glow", UDim2.fromOffset(34, 34), color, true, 4)
		glow.BackgroundTransparency = 0.7
		local ring = arenaShape("Burst", UDim2.fromOffset(10, 10), color, true, 3)
		ring.BackgroundTransparency = 1
		local ringStroke = stroke(ring, color, 3)
		local area = arenaShape("Area", UDim2.fromOffset(10, 10), color, true, 2)
		area.BackgroundTransparency = 0.85
		local areaStroke = stroke(area, color, 2, 0.3)
		local beam = arenaShape("Beam", UDim2.fromOffset(10, 6), color, false, 4)
		local spawned = arenaShape("Spawned", UDim2.fromOffset(10, 10), C.Gold, true, 2)
		spawned.BackgroundTransparency = 0.85
		stroke(spawned, C.Gold, 2, 0.3)
		local speed = mechanics.Speed or 80
		anim = {
			Form = draft.Form,
			Travel = math.clamp(70 / math.max(speed, 1), 0.25, 1.8),
			Size = math.clamp((mechanics.Radius or 1) * 8 + 8, 8, 40),
			AreaSize = math.clamp((mechanics.Radius or 10) / 30, 0.15, 0.6),
			Explode = explodeRadius and math.clamp(explodeRadius / 25, 0.12, 0.7) or nil,
			Spawn = spawnForm,
			Event = event,
			Orb = orb,
			Glow = glow,
			Ring = ring,
			RingStroke = ringStroke,
			Area = area,
			AreaStroke = areaStroke,
			Beam = beam,
			Spawned = spawned,
			Pops = popLabels,
			Dummy = dummy,
			Caster = caster,
			Start = os.clock(),
		}
		-- Sequence readout: the same chain as the tree, in reading order.
		for _, child in previewInfo:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local lineOrder = 0
		local function line(value, colorValue, font, indent)
			lineOrder += 1
			text(previewInfo, value, 13, colorValue, font or Enum.Font.GothamMedium, {
				Size = UDim2.new(1, -(indent or 0), 0, 0),
				Position = UDim2.fromOffset(indent or 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = lineOrder,
			})
		end
		line("SEQUENCE", C.Faint, Enum.Font.GothamBlack)
		local function describe(scope, prefix)
			line(
				prefix .. (FormIcon[scope.Form] or "◆") .. "  " .. (FormVerb[scope.Form] or scope.Form),
				C.Ink,
				Enum.Font.GothamBold
			)
			for _, eventName in schema.EventOrder do
				local steps = scope.Triggers and scope.Triggers[eventName]
				if steps and #steps > 0 then
					line(prefix .. "   ◆ " .. (EventPhrase[eventName] or eventName), C.Gold)
					for _, step in steps do
						if step.Behavior == "SpawnEffect" and type(step.Effect) == "table" then
							describe(step.Effect, prefix .. "      ")
						elseif step.Behavior then
							line(
								prefix .. "      * " .. ((schema.Behaviors[step.Behavior] or {}).Label or step.Behavior),
								C.Warn
							)
						end
						if step.Behavior ~= "SpawnEffect" then
							for _, payload in step.Payloads or {} do
								line(
									prefix
										.. (if step.Behavior then "         " else "      ")
										.. "→ "
										.. (PayloadVerb[payload.Kind] or payload.Kind)
										.. " · "
										.. payloadSummary(payload),
									C.Muted
								)
							end
						end
					end
				end
			end
		end
		describe(draft, "")
	end

	local function stepAnimation()
		if not anim or not arena.Parent or not arena.Visible then
			return
		end
		local width, height = arena.AbsoluteSize.X, arena.AbsoluteSize.Y
		if width < 10 then
			return
		end
		local t = os.clock() - anim.Start
		local form = anim.Form
		local cx, cy = 0.14, 0.62
		local tx, ty = 0.82, 0.62
		local travel = if form == "Projectile" then anim.Travel elseif form == "Beam" then 0.15 else 0.6
		local period = travel + 1.6
		local phase = t % period
		local hit = phase >= travel
		local after = math.max(0, phase - travel)
		local orb, glow, ring, area, beam, spawned = anim.Orb, anim.Glow, anim.Ring, anim.Area, anim.Beam, anim.Spawned
		orb.Visible, glow.Visible, beam.Visible = false, false, false
		ring.Visible, area.Visible, spawned.Visible = false, false, false
		if form == "Projectile" then
			local alpha = math.clamp(phase / travel, 0, 1)
			local x = cx + (tx - cx) * alpha
			orb.Visible, glow.Visible = not hit, not hit
			orb.Size = UDim2.fromOffset(anim.Size, anim.Size)
			glow.Size = UDim2.fromOffset(anim.Size * 2.2, anim.Size * 2.2)
			orb.Position = UDim2.fromScale(x, cy)
			glow.Position = orb.Position
		elseif form == "Beam" then
			beam.Visible = phase < travel + 0.35
			beam.Position = UDim2.fromScale((cx + tx) / 2, cy)
			beam.Size = UDim2.new(tx - cx, 0, 0, 6)
			beam.BackgroundTransparency = math.clamp((phase - travel) / 0.35, 0, 1)
		elseif form == "Wave" then
			local alpha = math.clamp(phase / (travel + 0.5), 0, 1)
			ring.Visible = true
			ring.Position = UDim2.fromScale(cx, cy)
			local d = alpha * width * 1.6
			ring.Size = UDim2.fromOffset(d, d)
			anim.RingStroke.Transparency = alpha
		elseif form == "Field" or form == "Aura" or form == "Construct" or form == "SelfEnhancement" then
			local centerX = if form == "Field" then tx else cx
			area.Visible = true
			area.Position = UDim2.fromScale(centerX, cy)
			local d = anim.AreaSize * height * 2 * (1 + 0.06 * math.sin(t * 4))
			area.Size = UDim2.fromOffset(d, d)
			hit = form == "Field" or form == "Aura"
			after = (t % 1.2)
		else
			orb.Visible = true
			orb.Position = UDim2.fromScale(tx, cy)
		end
		if hit and form ~= "Wave" then
			if anim.Explode then
				ring.Visible = true
				ring.Position = UDim2.fromScale(tx, cy)
				local grow = math.clamp(after / 0.5, 0, 1)
				local d = grow * anim.Explode * height * 2
				ring.Size = UDim2.fromOffset(d, d)
				anim.RingStroke.Transparency = grow * 0.8
			end
			if anim.Spawn then
				spawned.Visible = true
				spawned.Position = UDim2.fromScale(tx, cy)
				local d = math.clamp(after / 0.3, 0, 1) * height * 0.5
				spawned.Size = UDim2.fromOffset(d, d)
			end
			anim.Dummy.TextColor3 = if after < 0.2 then C.Ink else C.Blood
		else
			anim.Dummy.TextColor3 = C.Blood
		end
		for index, pop in anim.Pops do
			local local_t = after - (index - 1) * 0.12
			local visible = hit and local_t > 0
			local fade = math.clamp(local_t / 1.2, 0, 1)
			pop.TextTransparency = if visible then fade else 1
			pop.TextStrokeTransparency = if visible then 0.3 + fade * 0.7 else 1
			pop.Position = UDim2.new(tx, 0, cy - 0.16 - fade * 0.12, -(index - 1) * 18)
		end
	end
	return { render = renderPreview, step = stepAnimation }
end

return PreviewPanel
