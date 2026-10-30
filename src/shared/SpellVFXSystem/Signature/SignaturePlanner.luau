-- Pure: (analyzer plan, anchor phase/role, quality) -> resolved signature layers.
-- Gameplay numbers only reach this module as the analyzer's normalized features, so visual scale
-- never feeds back into hit size. No instances, no services, no randomness.
local Library = require(script.Parent.SignatureLibrary)
local Styled = require(script.Parent.Parent.Assets.StyledVFXManifest)
local Planner = {}

local function clamp01(x)
	if type(x) ~= "number" or x ~= x then
		return 0
	end
	return math.clamp(x, 0, 1)
end

-- Visual scalars (0..1) derived from the spell's mechanical features.
--   Size     body of the spell (projectile hit radius, area radius or beam width)
--   Potency  direct damage or damage-over-time total: instability and impact detail, not scale
--   Speed    projectile/aerial speed: stretch and trail behaviour
--   Charge   cast + maximum charge time: how much visibly accumulates before release
--   Range, Homing, Force, Lifetime  as named
--   Area     impact area (explode radius) or area radius
function Planner.scalars(plan)
	local f = plan.Features or {}
	local impactRadius = tonumber(plan.ImpactRadius) or 0
	local area = if impactRadius > 0 then math.sqrt(math.min(impactRadius, 20) / 20) else f.Radius or 0
	return {
		Size = clamp01(math.max(f.Size or 0, (f.Radius or 0) * 0.8, f.Width or 0)),
		Potency = clamp01(math.max(f.Direct or 0, (f.DotTotal or 0) * 0.85)),
		Speed = clamp01(f.Speed),
		Charge = clamp01(f.Cast),
		Range = clamp01(f.Range),
		Homing = clamp01(f.Homing),
		Force = clamp01(f.Force),
		Lifetime = clamp01(math.max(f.Lifetime or 0, f.Linger or 0)),
		Area = clamp01(area),
	}
end

function Planner.match(plan)
	local match = Library.Match
	local name = match.Element[plan.Element or ""]
		or match.Expression[plan.Expression or ""]
		or match.Principle[plan.Principle or ""]
		or match.Fallback
	return if name then Library.Signatures[name] else nil
end

-- Which component drives an anchor: the caster cue, a hit, or the spell's gameplay form.
function Planner.role(plan, phase, castingCue)
	if castingCue then
		return "Cast"
	elseif phase == "Impact" then
		return "Impact"
	end
	return if Library.Components[plan.Form or ""] then plan.Form else "Projectile"
end

local function slotsFor(role, phase)
	local component = Library.Components[role]
	if not component then
		return {}
	end
	return component[phase] or component.Sustain or component.Release or component.Gather or {}
end

-- Pure HSV boost (no Color3:ToHSV, so it also runs under the plain Luau test harness).
local function boost(color, saturation, value)
	local r, g, b = color.R, color.G, color.B
	local maxc, minc = math.max(r, g, b), math.min(r, g, b)
	local v = maxc
	local s = if maxc > 0 then (maxc - minc) / maxc else 0
	if maxc == minc then
		local grey = math.min(1, v * value)
		return Color3.new(grey, grey, grey)
	end
	local h
	if maxc == r then
		h = ((g - b) / (maxc - minc)) % 6
	elseif maxc == g then
		h = (b - r) / (maxc - minc) + 2
	else
		h = (r - g) / (maxc - minc) + 4
	end
	h /= 6
	s, v = math.min(1, s * saturation), math.min(1, v * value)
	local i = math.floor(h * 6) % 6
	local f = h * 6 - math.floor(h * 6)
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local rr, gg, bb
	if i == 0 then
		rr, gg, bb = v, t, p
	elseif i == 1 then
		rr, gg, bb = q, v, p
	elseif i == 2 then
		rr, gg, bb = p, v, t
	elseif i == 3 then
		rr, gg, bb = p, q, v
	elseif i == 4 then
		rr, gg, bb = t, p, v
	else
		rr, gg, bb = v, p, q
	end
	return Color3.new(rr, gg, bb)
end
Planner.boost = boost

local function tint(signature, plan)
	local colors = {}
	local bands = Styled.Enabled and Styled.Palettes[signature.Name]
	local bandTokens = { Hi=3, Mid=2, Lo=1, Smoke=1, Ink=5, WhiteHot=4, Hot=3,
		Body=2, Deep=1, Ember=3, Soot=5, Ash=1, Bone=3, Sinew=2, Bruise=1, Grit=1, Air=4 }
	local custom = plan.Color
	local style = Library.Style or {}
	for token, color in pairs(signature.Palette) do
		if bands and bandTokens[token] then
			colors[token] = bands[bandTokens[token]]
			continue
		end
		local amount = signature.Tintable[token]
		local c = if custom and amount then color:Lerp(custom, amount) else color
		-- Cel look: punchier, brighter colours; ink stays ink.
		colors[token] = if token == "Ink" then c else boost(c, style.Saturation or 1, style.Value or 1)
	end
	return colors
end

local function resolveParams(spec, scalars)
	local params = table.clone(spec.Params)
	for _, driver in ipairs(spec.Drivers) do
		local param, scalar, weight = driver[1], driver[2], driver[3]
		params[param] = (params[param] or 0) + weight * (scalars[scalar] or 0)
	end
	for param, range in pairs(spec.Limits) do
		if type(params[param]) == "number" then
			params[param] = math.clamp(params[param], range[1], range[2])
		end
	end
	return params
end

-- Returns nil when no signature covers this spell. Otherwise:
-- { Signature, Role, Slots, Scalars, Replaces, Layers = { { Id, Slot, Kind, Priority, Texture, Mesh,
--   Meshes, Colors = { Color3... }, Params } } }
function Planner.plan(plan, phase, options)
	options = options or {}
	local signature = Planner.match(plan)
	if not signature then
		return nil
	end
	local role = Planner.role(plan, phase, options.CastingCue)
	local slots = slotsFor(role, phase or "Sustain")
	local wanted = {}
	for _, slot in ipairs(slots) do
		wanted[slot] = true
	end
	local quality = Library.Quality[options.Quality or "High"] or Library.Quality.High
	local scalars = Planner.scalars(plan)
	local palette = tint(signature, plan)
	local layers = {}
	local sourceLayers = if role == "Projectile"
			and phase ~= "End"
			and signature.ProjectileLayers
			and options.DirectionalSprites ~= false
		then signature.ProjectileLayers
		else signature.Layers
	for _, slot in ipairs(Library.Slots) do
		if wanted[slot] then
			for _, spec in ipairs(sourceLayers) do
				local formOk = (spec.Forms == nil or spec.Forms[plan.Form or ""] == true)
					and (spec.Roles == nil or spec.Roles[role] == true)
				local kindOk = (spec.Kind ~= "Light" or quality.Lights or spec.Priority==1)
					and ((spec.Kind ~= "Mesh" and spec.Kind ~= "Debris") or quality.Meshes or spec.Priority == 1)
				-- Release cues acknowledge the cast; impact artwork belongs at the destination.
				if role=="Cast" and phase=="Release" and spec.Kind~="Light" then kindOk=false end
				-- Ending/culling a visual is not a hit. New clouds and debris bursts
				-- belong to the explicit Impact anchor, which already owns this slot.
				if spec.Slot=="Dissipate" and spec.Kind=="Burst" and role~="Impact" then kindOk=false end
				if spec.Slot == slot and formOk and kindOk and spec.Priority <= quality.MaxPriority then
					local params = resolveParams(spec, scalars)
					if Styled.Enabled and (spec.Kind == "Mesh" or spec.Kind == "Debris") then
						params.Material = "SmoothPlastic"
					end
					if params.Rate then
						params.Rate *= quality.Rate
					end
					if params.Count then
						params.Count = math.max(1, math.floor(params.Count * quality.Count + 0.5))
					end
					local tokens = if type(spec.Colors) == "table" then spec.Colors else { spec.Colors or "Body" }
					local colors = {}
					for i, token in ipairs(tokens) do
						colors[i] = palette[token] or Color3.new(1, 1, 1)
					end
					table.insert(layers, {
						Id = spec.Id,
						Slot = slot,
						Kind = spec.Kind,
						Priority = spec.Priority,
						Texture = spec.Texture,
						FrameTexture = spec.FrameTexture,
						DirectionalAsset = spec.DirectionalAsset,
						Mesh = spec.Mesh,
						Meshes = spec.Meshes,
						Colors = colors,
						Params = params,
					})
				end
			end
		end
	end
	return {
		Signature = signature.Name,
		Role = role,
		Slots = slots,
		Scalars = scalars,
		Replaces = signature.Replaces[role] or signature.Replaces.Default or {},
		Layers = layers,
	}
end

return Planner
