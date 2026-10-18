--!nonstrict
-- Studio-only spell VFX showcase (toggle with F8). Purely local and cosmetic: it builds anchors the
-- same way the server presentation does (Analyzer.stamp), so the real SpellVFXController, composer
-- and signature renderer draw them. Nothing is sent to the server; no damage or hits occur.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Showcase = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

function Showcase.start()
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	if not (RunService:IsStudio() and require(Shared.Configuration.DevelopmentSandbox).Enabled) then
		return nil
	end
	local System = Shared:WaitForChild("SpellVFXSystem")
	local Analyzer = require(System.Core.SpellVFXAnalyzer)
	local Renderer = require(System.Signature.SignatureRenderer)
	local Assets = require(System.Assets.VFXAssets)
	local Manifest = require(System.Assets.VFXAssetManifest)
	local Spells = require(Shared.Configuration.Spells)
	local player = Players.LocalPlayer

	-- Showcase variables. Each maps onto real spell fields, then the analyzer re-derives features.
	local SCHOOLS = {
		{ "Fire", { Principle = "Energy", Expression = "Fire" }, nil },
		{ "Ice", { Principle = "Matter", Expression = "Water" }, "Ice" },
		{ "Lightning", { Principle = "Energy", Expression = "Lightning" }, nil },
		{ "Water", { Principle = "Matter", Expression = "Water" }, nil },
		{ "Earth", { Principle = "Matter", Expression = "Earth" }, nil },
		{ "Wind", { Principle = "Energy", Expression = "Force" }, "Wind" },
		{ "Poison", { Principle = "Body", Expression = "BodyEnhancement" }, "Poison" },
		{ "Arcane", { Principle = "Energy", Expression = "Unawakened" }, nil },
		{ "Force", { Principle = "Energy", Expression = "Force" }, nil },
		{ "Body", { Principle = "Body", Expression = "BodyEnhancement" }, nil },
		{ "Spirit", { Principle = "Soul", Expression = "Spirit" }, nil },
		{ "Space", { Principle = "Space", Expression = "SpatialFold" }, nil },
		{ "Time", { Principle = "Time", Expression = "TemporalShift" }, nil },
	}
	local FORMS = { "Projectile", "Beam", "Wave", "Field", "Aura", "SelfEnhancement", "Construct", "Manipulation" }
	local vars = {
		School = 1,
		Form = 1,
		Radius = 1.1,
		Damage = 10,
		Speed = 72,
		Charge = 0,
		Explode = 7,
		Homing = 0,
		Force = 54,
		Range = 10,
		Count = 1,
		Repeat = false,
		Dark = false,
		SlowMotion = false,
	}
	local function schoolName()
		return SCHOOLS[vars.School][1]
	end
	local function formName()
		return FORMS[vars.Form]
	end

	-- A complete spell of the chosen school and form; the curated Fireball / Body Burst are used
	-- as-is for their own school+form so their tuned definitions are what you see.
	local function buildSpell()
		local school, form = SCHOOLS[vars.School], formName()
		local spell
		if school[1] == "Fire" and form == "Projectile" then
			spell = deepCopy(Spells.Fireball)
		elseif school[1] == "Body" and form == "Wave" then
			spell = deepCopy(Spells.BodyBurst)
		else
			spell = {
				Form = form,
				Targeting = "AimDirection",
				Geometry = "Sphere",
				Motion = "Linear",
				Source = table.clone(school[2]),
				Element = school[3],
				Casting = { Mode = "Instant", Cooldown = 0.5 },
				Lifetime = { Mode = "FixedDuration", Duration = 3 },
				Visual = {},
				Triggers = {},
			}
			local hit = { { Kind = "Damage", Amount = vars.Damage }, { Kind = "Force", Magnitude = vars.Force } }
			if form == "Projectile" then
				spell.Projectile = { Speed = vars.Speed, Radius = vars.Radius }
				spell.Triggers.OnImpact = {
					{ Payloads = { { Kind = "Damage", Amount = vars.Damage } } },
					{ Behavior = "Explode", Radius = vars.Explode, Payloads = {} },
				}
			elseif form == "Beam" then
				spell.Beam = { Width = vars.Radius, Range = vars.Range * 2.4, Payloads = hit }
			elseif form == "Wave" then
				spell.Geometry = "Cone"
				spell.Wave = { Range = vars.Range, Dot = 0.35, Payloads = hit }
			elseif form == "Field" then
				spell.Geometry = "Cylinder"
				spell.Field = {
					Radius = vars.Range * 0.6,
					Height = 4,
					Payloads = { { Kind = "DamageOverTime", Amount = vars.Damage * 0.3, Interval = 0.5, Duration = 3 } },
				}
			elseif form == "Aura" then
				spell.Aura = { Radius = 5, Payloads = hit }
			elseif form == "Construct" or form == "Manipulation" then
				spell.Construct = { Width = 8, Height = 5, Depth = 1.5 }
			end
		end
		if spell.Projectile then
			spell.Projectile.Radius = vars.Radius
			spell.Projectile.Speed = vars.Speed
			if spell.Triggers.OnImpact and spell.Triggers.OnImpact[1].Payloads[1] then
				spell.Triggers.OnImpact[1].Payloads[1].Amount = vars.Damage
			end
			if spell.Triggers.OnImpact and spell.Triggers.OnImpact[2] then
				spell.Triggers.OnImpact[2].Radius = vars.Explode
			end
			if vars.Homing > 0 then
				spell.Projectile.Behaviors = { { Kind = "Homing", SearchRadius = 30, TurnRate = vars.Homing } }
			end
		elseif spell.Wave and spell.Wave.Payloads[2] then
			spell.Wave.Range = vars.Range
			spell.Wave.Payloads[1].Amount = vars.Damage
			spell.Wave.Payloads[2].Magnitude = vars.Force
		end
		if vars.Charge > 0 then
			spell.Casting = { Mode = "Charged", MinimumCharge = 0.1, MaximumCharge = vars.Charge, Cooldown = 0.5 }
		end
		return spell
	end

	-- Local stage: a dark enclosed room far from the map, or in front of the player.
	local stage
	local function darkRoom()
		if stage then
			return stage
		end
		local model = Instance.new("Model")
		model.Name = "SpellVFXShowcaseRoom"
		local function slab(size, cframe, color)
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
			p.Size, p.CFrame, p.Color = size, cframe, color
			p.Material = Enum.Material.Concrete
			p.Parent = model
			return p
		end
		local origin = CFrame.new(0, 900, 0)
		slab(Vector3.new(160, 1, 160), origin, Color3.fromRGB(22, 20, 22))
		slab(Vector3.new(160, 60, 1), origin * CFrame.new(0, 30, -60), Color3.fromRGB(12, 11, 13))
		slab(Vector3.new(1, 60, 160), origin * CFrame.new(-60, 30, 0), Color3.fromRGB(14, 12, 14))
		slab(Vector3.new(1, 60, 160), origin * CFrame.new(60, 30, 0), Color3.fromRGB(14, 12, 14))
		slab(Vector3.new(160, 60, 1), origin * CFrame.new(0, 30, 80), Color3.fromRGB(12, 11, 13))
		model.Parent = workspace
		stage = { Model = model, Origin = origin * CFrame.new(0, 3.5, 25) }
		return stage
	end

	local function casterFrame(index)
		local spread = (index - (vars.Count + 1) / 2) * 7
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local base = if root then root.CFrame else CFrame.new(0, 5, 0)
		-- The caster is you: cast cues sit at your hands exactly as in a real cast.
		return base * CFrame.new(spread, 0, 0)
	end

	local function anchor(name, cframe, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Transparency = 1
		p.Size = size or Vector3.one
		p.CFrame = cframe
		p.Parent = workspace
		return p
	end

	local timeScale = function()
		return if vars.SlowMotion then 0.25 else 1
	end

	local function wait(seconds)
		task.wait(seconds / timeScale())
	end

	-- Mirrors MagicPresentation.gather/release/projectile/impact/wave/finish for one cast.
	local function castOnce(index, onlyPhase)
		local spell = buildSpell()
		local frame = casterFrame(index)
		-- "Charge" always shows a charge-up: with Charge at 0 it borrows 1.5 s.
		local chargeTime = if onlyPhase == "Charge" and vars.Charge <= 0 then 1.5 else vars.Charge
		if onlyPhase == "Charge" and vars.Charge <= 0 then
			spell.Casting = { Mode = "Charged", MinimumCharge = 0.1, MaximumCharge = chargeTime, Cooldown = 0.5 }
		end
		if (onlyPhase == nil or onlyPhase == "Charge") and chargeTime > 0 then
			local gather = anchor("SpellGatherComposition", frame, Vector3.one)
			Analyzer.stamp(gather, spell, Vector3.new(3, 4, 3), "Gather")
			wait(chargeTime)
			gather:Destroy()
			if onlyPhase == "Charge" then
				return
			end
		end
		if onlyPhase == nil or onlyPhase == "Release" then
			local release = anchor("SpellReleaseComposition", frame)
			Analyzer.stamp(release, spell, Vector3.new(5, 6, 5), "Release")
			task.delay(0.6, function()
				release:Destroy()
			end)
			if onlyPhase == "Release" then
				return
			end
		end
		local form = formName()
		local function hold(part, seconds)
			wait(seconds)
			if part.Parent then
				part:SetAttribute("VFXPhase", "End")
				task.delay(0.7, function()
					part:Destroy()
				end)
			end
		end
		if form == "Wave" then
			local wave = anchor("MagicWaveComposition", frame * CFrame.new(0, 0, -1))
			Analyzer.stamp(wave, spell, Vector3.new(spell.Wave.Range * 2, 5, spell.Wave.Range), "Release")
			task.delay(0.65, function()
				wave:Destroy()
			end)
			return
		elseif form == "Beam" then
			-- Mirrors Presentation.beam: anchor at the origin looking down the beam, size (w, w, length).
			local origin = frame * CFrame.new(0, 0.5, -1.5)
			local width, length = spell.Beam.Width, spell.Beam.Range
			local path = anchor("MagicBeamPath", origin, Vector3.one * 0.1)
			Analyzer.stamp(path, spell, Vector3.new(width, width, 0.5), "Sustain")
			local start = os.clock()
			local grow
			grow = RunService.Heartbeat:Connect(function()
				local k = math.min(1, (os.clock() - start) * timeScale() / 0.2)
				path:SetAttribute("VFXSize", Vector3.new(width, width, math.max(0.5, length * k)))
				if k >= 1 or not path.Parent then
					grow:Disconnect()
				end
			end)
			local impact = anchor(
				"MagicElementImpact",
				CFrame.new((origin * CFrame.new(0, 0, -length)).Position),
				Vector3.one * 0.1
			)
			Analyzer.stamp(impact, spell, Vector3.one * 5, "Impact")
			task.delay(0.8, function()
				impact:Destroy()
			end)
			hold(path, 2.4)
			return
		elseif form == "Field" then
			local d = spell.Field.Radius * 2
			local area = anchor("MagicAreaMarker", frame * CFrame.new(0, -1, -(d * 0.5 + 4)), Vector3.new(d, 4, d))
			Analyzer.stamp(area, spell, area.Size, "Sustain")
			hold(area, 3.5)
			return
		elseif form == "Aura" or form == "SelfEnhancement" then
			local size = if form == "Aura" then Vector3.new(10, 6, 10) else Vector3.new(5, 6, 5)
			local aura = anchor("SpellSustainedComposition", frame, size)
			Analyzer.stamp(aura, spell, size, "Sustain")
			hold(aura, 3.5)
			return
		elseif form == "Construct" or form == "Manipulation" then
			-- A visible stand-in object; constructs are real parts the composition dresses.
			local wall = anchor("MagicConstruct", frame * CFrame.new(0, -0.5, -12), Vector3.new(8, 0.4, 1.5))
			wall.Transparency = 0
			wall.Material = if form == "Construct" then Enum.Material.Slate else Enum.Material.WoodPlanks
			wall.Color = Color3.fromRGB(60, 54, 58)
			Analyzer.stamp(wall, spell, wall.Size, "Sustain")
			local base = wall.CFrame
			for step = 1, 12 do
				local h = 0.4 + 4.6 * step / 12
				wall.Size = Vector3.new(8, h, 1.5)
				wall.CFrame = base * CFrame.new(0, h * 0.5, 0)
				wait(0.025)
			end
			hold(wall, 3)
			return
		end
		local impactAt
		if onlyPhase ~= "Impact" then
			local radius = spell.Projectile.Radius
			local projectile = anchor("MagicProjectile", frame * CFrame.new(0, 0.5, -2), Vector3.one * radius * 2)
			Analyzer.stamp(projectile, spell, projectile.Size)
			local position = projectile.Position
			local heading = frame.LookVector
			local travelled, maxDistance = 0, 70
			local target = (frame * CFrame.new(18, 0, -55)).Position
			while travelled < maxDistance and projectile.Parent do
				local dt = RunService.Heartbeat:Wait() * timeScale()
				if vars.Homing > 0 then
					local desired = (target - position).Unit
					local turn = math.rad(vars.Homing) * dt
					local angle = math.acos(math.clamp(heading:Dot(desired), -1, 1))
					if angle > 1e-3 then
						heading = heading:Lerp(desired, math.min(1, turn / angle)).Unit
					end
				end
				local stepDistance = spell.Projectile.Speed * dt
				position += heading * stepDistance
				travelled += stepDistance
				projectile.CFrame = CFrame.lookAt(position, position + heading)
				if vars.Homing > 0 and (target - position).Magnitude < 2 then
					break
				end
			end
			impactAt = position
			projectile:SetAttribute("VFXPhase", "End")
			task.delay(0.7, function()
				projectile:Destroy()
			end)
		else
			impactAt = (frame * CFrame.new(0, -1.5, -20)).Position
		end
		local impact = anchor("MagicElementImpact", CFrame.new(impactAt), Vector3.one * 0.1)
		Analyzer.stamp(impact, spell, Vector3.one * 5, "Impact")
		task.delay(0.8, function()
			impact:Destroy()
		end)
	end

	local function play(onlyPhase)
		for index = 1, vars.Count do
			task.spawn(castOnce, index, onlyPhase)
		end
	end

	-- UI -------------------------------------------------------------------------------------
	local PHASES = {
		{ nil, "Full cast", "charge (if Charge > 0), release, then the spell itself" },
		{ "Charge", "Charge-up only", "the gather/charge effect at your hands" },
		{ "Release", "Release only", "the cast flash at your hands" },
		{ "Impact", "Spell + hit only", "skips the cast cue; projectiles jump to the hit" },
	}
	local QUALITIES = { "Auto", "Low", "Medium", "High" }
	local diagnose
	local ui = { Phase = 1, Quality = 1, LastPlayed = "nothing yet" }

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpellVFXShowcase"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(360, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Position = UDim2.new(1, -372, 0, 12)
	panel.BackgroundColor3 = Color3.fromRGB(16, 14, 16)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = panel
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function label(text, height, size, color, font)
		local l = Instance.new("TextLabel")
		l.LayoutOrder = nextOrder()
		l.Size = UDim2.new(1, 0, 0, height or 18)
		l.BackgroundTransparency = 1
		l.TextColor3 = color or Color3.fromRGB(225, 215, 200)
		l.Font = font or Enum.Font.Gotham
		l.TextSize = size or 13
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.TextWrapped = true
		l.Text = text
		l.Parent = panel
		return l
	end
	local function row(height)
		local r = Instance.new("Frame")
		r.LayoutOrder = nextOrder()
		r.Size = UDim2.new(1, 0, 0, height or 28)
		r.BackgroundTransparency = 1
		r.Parent = panel
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, 4)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.Parent = r
		return r
	end
	local function button(parent, text, width, callback, color)
		local b = Instance.new("TextButton")
		b.Size = if width then UDim2.new(0, width, 1, 0) else UDim2.fromScale(1, 1)
		b.BackgroundColor3 = color or Color3.fromRGB(58, 40, 34)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.Text = text
		b.AutoButtonColor = true
		b.Parent = parent
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = b
		b.Activated:Connect(callback)
		return b
	end
	local function valueBox(parent, width)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0, width, 1, 0)
		l.BackgroundColor3 = Color3.fromRGB(30, 26, 30)
		l.TextColor3 = Color3.fromRGB(255, 236, 200)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 14
		l.Parent = parent
		return l
	end

	-- One Output line per PLAY that checks each stage of the pipeline, so a silent failure is visible.
	local CollectionService = game:GetService("CollectionService")
	local Composer = require(System.Core.SpellVFXComposer)
	local Planner = require(System.Signature.SignaturePlanner)
	diagnose = function()
		local tagged = #CollectionService:GetTagged("ComposedSpellVFX")
		local spell = buildSpell()
		local okPlan, planResult = pcall(function()
			local resolved = Planner.plan(Analyzer.resolve(spell), "Sustain")
			return if resolved then (resolved.Signature .. " " .. #resolved.Layers .. " layers") else "no signature"
		end)
		local probe = anchor("SpellVFXTesterProbe", casterFrame(1) * CFrame.new(0, 3, -6), Vector3.one * 2)
		Analyzer.stamp(probe, spell, probe.Size)
		-- Untag so the live controller ignores it; this attach is the tester's own direct test.
		CollectionService:RemoveTag(probe, "ComposedSpellVFX")
		local okAttach, attachResult = pcall(function()
			local session = Renderer.attach(probe, Analyzer.read(probe), {})
			if session then
				local n = #session.Entries
				session:Stop()
				return n .. " entries built"
			end
			return "attach returned nil (disabled or budget)"
		end)
		probe:Destroy()
		local stats = Renderer.stats()
		print(
			string.format(
				"[SpellVFX Tester] diag: tagged anchors=%d | renderer hooked=%s enabled=%s | plan=%s | direct attach=%s | live sessions=%d emitters=%d meshes=%d",
				tagged,
				tostring(Composer.Signatures ~= nil),
				tostring(Renderer.Enabled),
				if okPlan then planResult else ("ERROR " .. tostring(planResult)),
				if okAttach then attachResult else ("ERROR " .. tostring(attachResult)),
				stats.Sessions,
				stats.Emitters,
				stats.Meshes
			)
		)
	end

	local refreshers = {}
	local function refresh()
		for _, fn in refreshers do
			fn()
		end
	end
	-- "< value >" selector.
	local function selector(title, getText, step)
		local r = row()
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0, 64, 1, 0)
		t.BackgroundTransparency = 1
		t.TextColor3 = Color3.fromRGB(200, 190, 180)
		t.Font = Enum.Font.Gotham
		t.TextSize = 13
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = title
		t.Parent = r
		button(r, "<", 34, function()
			step(-1)
			refresh()
		end)
		local box = valueBox(r, 178)
		button(r, ">", 34, function()
			step(1)
			refresh()
		end)
		table.insert(refreshers, function()
			box.Text = getText()
		end)
	end
	local function toggle(parent, name, get, set)
		local b
		b = button(parent, "", 83, function()
			set(not get())
			refresh()
		end)
		table.insert(refreshers, function()
			b.Text = name .. (if get() then ": ON" else ": OFF")
			b.BackgroundColor3 = if get() then Color3.fromRGB(150, 70, 40) else Color3.fromRGB(58, 40, 34)
		end)
	end

	label("SPELL VFX TESTER", 22, 17, Color3.fromRGB(255, 220, 170), Enum.Font.GothamBold)
	label(
		"Pick a school and a form, then press PLAY. Effects appear just in front of you (or in the Dark room). F8 hides this panel.",
		34,
		12,
		Color3.fromRGB(180, 170, 160)
	)
	selector("School", function()
		return schoolName()
	end, function(d)
		vars.School = (vars.School - 1 + d) % #SCHOOLS + 1
	end)
	selector("Form", function()
		return formName()
	end, function(d)
		vars.Form = (vars.Form - 1 + d) % #FORMS + 1
	end)
	selector("Shows", function()
		return PHASES[ui.Phase][2]
	end, function(d)
		ui.Phase = (ui.Phase - 1 + d) % #PHASES + 1
	end)
	local phaseHint = label("", 16, 11, Color3.fromRGB(160, 150, 140))
	table.insert(refreshers, function()
		phaseHint.Text = "  " .. PHASES[ui.Phase][3]
	end)
	local playRow = row(40)
	button(playRow, "PLAY", nil, function()
		ui.LastPlayed = schoolName() .. " " .. formName() .. " (" .. PHASES[ui.Phase][2] .. ")"
		print("[SpellVFX Tester] playing " .. ui.LastPlayed)
		play(PHASES[ui.Phase][1])
		task.delay(0.35, diagnose)
		refresh()
	end, Color3.fromRGB(170, 70, 30))

	local r = row()
	toggle(r, "Repeat", function()
		return vars.Repeat
	end, function(v)
		vars.Repeat = v
	end)
	toggle(r, "Slow-mo", function()
		return vars.SlowMotion
	end, function(v)
		vars.SlowMotion = v
	end)
	toggle(r, "5 casters", function()
		return vars.Count > 1
	end, function(v)
		vars.Count = if v then 5 else 1
	end)
	toggle(r, "Dark room", function()
		return vars.Dark
	end, function(v)
		-- The game's camera controller owns the camera every frame, so the dark room moves you
		-- instead: your character stands in an enclosed black room facing its far wall.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if v then
			ui.ReturnTo = root.CFrame
			root.AssemblyLinearVelocity = Vector3.zero
			player.Character:PivotTo(darkRoom().Origin)
		elseif ui.ReturnTo then
			root.AssemblyLinearVelocity = Vector3.zero
			player.Character:PivotTo(ui.ReturnTo)
		end
		vars.Dark = v
	end)
	selector("Quality", function()
		return QUALITIES[ui.Quality]
	end, function(d)
		ui.Quality = (ui.Quality - 1 + d) % #QUALITIES + 1
		player:SetAttribute("SpellVFXQuality", if ui.Quality == 1 then nil else QUALITIES[ui.Quality])
	end)
	selector("Art", function()
		return if Assets.UseCustom then "Custom assets" else "Built-in fallback"
	end, function()
		Assets.UseCustom = not Assets.UseCustom
	end)

	label(
		"SPELL VARIABLES  (change the spell, so the look follows)",
		20,
		12,
		Color3.fromRGB(255, 220, 170),
		Enum.Font.GothamBold
	)
	local function stepper(name, key, step, minimum, maximum, fmt)
		local rr = row(24)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0, 196, 1, 0)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(205, 195, 185)
		l.Font = Enum.Font.Gotham
		l.TextSize = 12
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = rr
		button(rr, "-", 70, function()
			vars[key] = math.clamp(vars[key] - step, minimum, maximum)
			refresh()
		end)
		button(rr, "+", 70, function()
			vars[key] = math.clamp(vars[key] + step, minimum, maximum)
			refresh()
		end)
		table.insert(refreshers, function()
			l.Text = string.format("%s: " .. (fmt or "%d"), name, vars[key])
		end)
	end
	stepper("Size (hit radius)", "Radius", 0.4, 0.3, 4, "%.1f")
	stepper("Potency (damage)", "Damage", 10, 0, 120)
	stepper("Projectile speed", "Speed", 20, 20, 200)
	stepper("Charge time (s)", "Charge", 0.5, 0, 3, "%.1f")
	stepper("Explode radius", "Explode", 3, 0, 20)
	stepper("Homing (deg/s)", "Homing", 90, 0, 540)
	stepper("Push force", "Force", 15, 0, 100)
	stepper("Range / area", "Range", 3, 4, 30)

	local status = label("", 46, 11, Color3.fromRGB(160, 150, 140), Enum.Font.Code)
	table.insert(refreshers, function()
		local custom = 0
		for name in pairs(Manifest.Meshes) do
			custom += if Assets.hasCustomMesh(name) then 1 else 0
		end
		local stats = Renderer.stats()
		status.Text = string.format(
			"Last played: %s\nLive: %d effects, %d emitters, %d meshes, %d lights | meshes loaded %d",
			ui.LastPlayed,
			stats.Sessions,
			stats.Emitters,
			stats.Meshes,
			stats.Lights,
			custom
		)
	end)
	refresh()

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F8 then
			gui.Enabled = not gui.Enabled
			refresh()
		end
	end)
	task.spawn(function()
		while gui.Parent do
			if gui.Enabled then
				refresh()
				if vars.Repeat then
					play(PHASES[ui.Phase][1])
					task.wait(2.5 + vars.Charge)
				else
					task.wait(0.5)
				end
			else
				task.wait(0.5)
			end
		end
	end)
	return Showcase
end

return Showcase
