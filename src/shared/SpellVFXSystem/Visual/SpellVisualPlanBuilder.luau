-- Pure: (base plan + features + seed) x asset library -> bounded, deterministic render plan.
-- No Roblox instances are created here; the composer instantiates the result.
local Curves = require(script.Parent.VisualCurves)
local Library = require(script.Parent.SpellVisualAssetLibrary)
local Fingerprint = require(script.Parent.SpellVisualFingerprint)
local Extractor = require(script.Parent.SpellVisualFeatureExtractor)
local Builder = {}

local tau = math.pi * 2

local function featureValue(features, name)
	local value = features[name] or 0
	if Extractor.Counts[name] then
		return math.clamp(value / Library.CountScale, 0, 1)
	end
	return Curves.clamp01(value)
end

local function evaluate(definition, features)
	local params = {}
	for key, value in pairs(definition.Params) do
		params[key] = value
	end
	for _, driver in ipairs(definition.Drivers or {}) do
		local param, feature, weight, shape = driver[1], driver[2], driver[3], driver[4]
		params[param] = (params[param] or 0) + weight * Curves.shape(shape, featureValue(features, feature))
	end
	if definition.CountFrom then
		params.Count = math.max(params.Count or 1, features[definition.CountFrom] or 0)
	end
	for key, limit in pairs(definition.Limits or {}) do
		if params[key] ~= nil then
			params[key] = math.clamp(params[key], limit[1], limit[2])
		end
	end
	if params.Count then
		params.Count = math.max(0, math.floor(params.Count + 0.5))
	end
	return params
end

local function requiresMet(definition, features)
	local requirement = definition.Requires
	if not requirement then
		return true
	end
	return (features[requirement[1]] or 0) >= requirement[2]
end

local function rankOf(definition, features)
	local rank = featureValue(features, definition.Rank)
	for _, extra in ipairs(definition.AlsoRanks or {}) do
		rank = math.max(rank, featureValue(features, extra))
	end
	return rank
end

local function layer(definition, features, seed, form, motifs)
	local arrangement = definition.Arrangement
	if arrangement == "Form" then
		arrangement = Library.FormArrangement[form] or "Comet"
	end
	return {
		Id = definition.Id,
		Kind = definition.Kind,
		Arrangement = arrangement,
		Motif = definition.Motif or Fingerprint.pick(seed, definition.Id .. ":motif", motifs) or "Sphere",
		Texture = definition.Texture,
		Priority = definition.Priority,
		Phase = Curves.quantize(Fingerprint.unit(seed, definition.Id .. ":phase")) * tau,
		Tilt = (Curves.quantize(Fingerprint.unit(seed, definition.Id .. ":tilt")) - 0.5) * 0.8,
		Curve = (Curves.quantize(Fingerprint.unit(seed, definition.Id .. ":curve")) - 0.5) * 2,
		Params = evaluate(definition, features),
		Limits = definition.Limits,
	}
end

-- Ordered candidates: form silhouette, element body/detail, light, ranked mechanic accents.
function Builder.candidates(plan, features, seed)
	local form = plan.Form
	local element = Library.Elements[plan.Element] or Library.Elements.Neutral
	local list = {}
	local formLayers = if plan.CastingCue then Library.Forms.Cue else (Library.Forms[form] or Library.Forms.Projectile)
	for _, definition in ipairs(formLayers) do
		table.insert(list, layer(definition, features, seed, form, element.Motifs))
	end
	local elementForm = if plan.CastingCue then "Projectile" else form
	for _, definition in ipairs(element.Layers) do
		local allowed = definition.Forms == nil or definition.Forms[elementForm] == true
		if
			allowed
			and not (plan.CastingCue and definition.Arrangement == "Core")
			and requiresMet(definition, features)
		then
			table.insert(list, layer(definition, features, seed, elementForm, element.Motifs))
		end
	end
	table.insert(list, layer(Library.Light, features, seed, form, element.Motifs))
	local mechanics = {}
	for _, definition in ipairs(Library.Mechanics) do
		if requiresMet(definition, features) then
			table.insert(mechanics, { Definition = definition, Rank = rankOf(definition, features) })
		end
	end
	table.sort(mechanics, function(a, b)
		if a.Rank ~= b.Rank then
			return a.Rank > b.Rank
		end
		return a.Definition.Id < b.Definition.Id
	end)
	for index = 1, math.min(#mechanics, Library.Budget.PerSpell.MaxAccents) do
		table.insert(list, layer(mechanics[index].Definition, features, seed, elementForm, element.Motifs))
	end
	return list
end

-- Applies per-spell caps and quality scaling in priority order; priority 1 is always kept.
function Builder.build(plan, options)
	options = options or {}
	local features = plan.Features or Extractor.decode(plan.FeatureVector)
	local seed = plan.Seed or Fingerprint.seed(plan.Element, plan.Form, plan.Geometry, Extractor.encode(features))
	local caps = Library.Budget.PerSpell
	local quality = Library.Budget.Quality[options.Quality or "High"] or Library.Budget.Quality.High
	local candidates = Builder.candidates(plan, features, seed)
	-- Stable priority sort keeps the authored order inside each priority band.
	for index, entry in ipairs(candidates) do
		entry.Order = index
	end
	table.sort(candidates, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority < b.Priority
		end
		return a.Order < b.Order
	end)
	local totals =
		{ Layers = 0, Accents = 0, Parts = 0, Links = 0, Trails = 0, Emitters = 0, Rate = 0, Fire = 0, Lights = 0 }
	local maxEmitters = math.min(caps.MaxEmitters, quality.MaxEmitters)
	local maxFire = math.min(caps.MaxFire, quality.MaxFire)
	local layers = {}
	for _, entry in ipairs(candidates) do
		entry.Order = nil
		local keep = totals.Layers < caps.MaxLayers and (entry.Priority <= quality.MaxPriority or entry.Priority == 1)
		local p = entry.Params
		if keep and entry.Kind == "Nodes" then
			local count =
				math.max(1, math.floor((p.Count or 1) * (if entry.Priority == 1 then 1 else quality.Count) + 0.5))
			local ceiling = caps.MaxParts - (if entry.Priority == 2 then caps.AccentReserve else 0)
			count = math.min(count, ceiling - totals.Parts)
			if entry.Priority == 1 then
				count = math.max(count, 1)
			end
			if count <= 0 then
				keep = false
			else
				p.Count = count
				totals.Parts += count
				if p.Links == 1 then
					local links = math.min(count, caps.MaxLinks - totals.Links)
					p.LinkCount = math.max(0, links)
					totals.Links += p.LinkCount
				end
			end
		elseif keep and entry.Kind == "Emitter" then
			local rate = math.min(p.Rate * quality.Rate, caps.MaxEmitterRate, caps.MaxSpellRate - totals.Rate)
			if totals.Emitters >= maxEmitters or rate < 0.5 then
				keep = false
			else
				p.Rate = math.floor(rate * 10 + 0.5) / 10
				totals.Emitters += 1
				totals.Rate += p.Rate
			end
		elseif keep and entry.Kind == "Trail" then
			local count = math.min(p.Count or 1, caps.MaxTrails - totals.Trails)
			if count <= 0 then
				keep = false
			else
				p.Count = count
				totals.Trails += count
			end
		elseif keep and entry.Kind == "Fire" then
			local count = math.min(math.max(1, math.floor((p.Count or 1) * quality.Count + 0.5)), maxFire - totals.Fire)
			if count <= 0 then
				keep = false
			else
				p.Count = count
				totals.Fire += count
			end
		elseif keep and entry.Kind == "Light" then
			if totals.Lights >= caps.MaxLights then
				keep = false
			else
				totals.Lights += 1
			end
		end
		if keep then
			totals.Layers += 1
			if entry.Priority == 3 then
				totals.Accents += 1
			end
			table.insert(layers, entry)
		end
	end
	local element = Library.Elements[plan.Element] or Library.Elements.Neutral
	return {
		Element = plan.Element,
		Form = plan.Form,
		Geometry = plan.Geometry,
		Seed = seed,
		Quality = options.Quality or "High",
		ElementSpeed = element.Speed,
		-- Slow and time dilation read as heavier, slower animation; never below half speed.
		TimeScale = math.clamp(1 - 0.4 * (features.Slow or 0) - 0.3 * (features.TimeDilation or 0), 0.5, 1),
		MotionRate = 0.8 + 1.4 * (features.Speed or 0),
		Layers = layers,
		Totals = totals,
	}
end

function Builder.find(renderPlan, id)
	for _, entry in ipairs(renderPlan.Layers) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

return Builder
