-- Pure: validated SpellSpec -> normalized mechanical visual features.
-- Reads gameplay data only; never mutates it. No spell name/ID is consulted.
local Curves = require(script.Parent.VisualCurves)
local Extractor = {}

-- Normalization references. These mirror Configuration/MagicLab safety limits
-- (a test asserts they stay in sync) so a maximum-legal value saturates at 1.
Extractor.Reference = {
	Damage = 120,
	DotTick = 25,
	TickRate = 10, -- 1 / MagicLab.MinInterval
	Duration = 15, -- MagicLab.MaxDuration
	DotTotal = 250,
	Heal = 150,
	Shield = 150, -- MagicLab.MaxShieldPerTarget
	MaxSlow = 0.75, -- 1 - MagicLab.MinSlowMultiplier
	Bind = 4, -- MagicLab.MaxBindDuration
	Force = 100, -- MagicLab.MaxForce
	Speed = 200, -- MagicLab.MaxSpeed
	ProjectileRadius = 4,
	Range = 200, -- MagicLab.MaxRange
	Radius = 20, -- MagicLab.MaxRadius
	BeamWidth = 10,
	TurnRate = 540, -- MagicLab.MaxHomingTurnRate
	Construct = 20,
	Cast = 5,
	Lifetime = 30,
	Payloads = 8,
	MarkStacks = 5, -- MagicLab.MaxElementalMarkStacks
	Summon = 6,
	Aerial = 48, -- MagicLab.MaxAerialSpeed
	Reveal = 15,
	MaxCount = 8,
}

-- Canonical feature order: encoding, fingerprinting and tests depend on it.
Extractor.Order = {
	"Direct",
	"DotTick",
	"DotRate",
	"DotDuration",
	"DotTotal",
	"Heal",
	"Shield",
	"Duration",
	"Slow",
	"Bind",
	"Force",
	"Speed",
	"Size",
	"Range",
	"Radius",
	"Width",
	"Homing",
	"Linger",
	"Construct",
	"Growth",
	"Cast",
	"Lifetime",
	"Payloads",
	"Mark",
	"TimeDilation",
	"Reveal",
	"Summon",
	"Aerial",
	"Repeat",
	"Pierces",
	"Bounces",
	"Splits",
	"Chains",
}
-- Integer counts (0..MaxCount); everything else is normalized 0..1.
Extractor.Counts = { Pierces = true, Bounces = true, Splits = true, Chains = true }

local PRIMARY = {
	OnCast = true,
	OnImpact = true,
	OnEnter = true,
	OnSpawn = true,
	OnTick = true,
	OnProximity = true,
}

local function num(v)
	return if type(v) == "number" and v == v and v > -math.huge and v < math.huge then v else 0
end

local function sortedEvents(triggers)
	local events = {}
	if type(triggers) ~= "table" then
		return events
	end
	for event in pairs(triggers) do
		if type(event) == "string" then
			table.insert(events, event)
		end
	end
	table.sort(events)
	return events
end

-- Accumulates raw mechanical magnitudes from one payload list.
local function scanPayloads(payloads, raw, weight)
	for _, p in ipairs(type(payloads) == "table" and payloads or {}) do
		if type(p) == "table" and type(p.Kind) == "string" then
			raw.payloads += weight
			local kind = p.Kind
			local duration = num(p.Duration)
			if kind == "Damage" then
				raw.direct += num(p.Amount) * weight
			elseif kind == "DamageOverTime" then
				local amount, interval = num(p.Amount), math.max(num(p.Interval), 0.1)
				local ticks = math.max(1, math.floor(duration / interval + 1e-6))
				raw.dotTotal += amount * ticks * weight
				if amount > raw.dotTick then
					raw.dotTick = amount
					raw.dotRate = 1 / interval
				end
				raw.dotDuration = math.max(raw.dotDuration, duration)
			elseif kind == "Heal" then
				raw.heal += num(p.Amount) * weight
			elseif kind == "Restoration" then
				local interval = math.max(num(p.Interval), 0.1)
				raw.heal += num(p.Amount) * math.max(1, math.floor(duration / interval + 1e-6)) * weight
			elseif kind == "Shield" then
				raw.shield += num(p.Amount) * weight
			elseif kind == "ModifyAttribute" and p.Attribute == "MagicArmor" and num(p.Amount) > 0 then
				raw.shield += num(p.Amount) * 0.6 * weight
			elseif kind == "Slow" then
				raw.slow = math.max(raw.slow, 1 - (if p.Multiplier == nil then 1 else num(p.Multiplier)))
			elseif kind == "Bind" or kind == "Stun" then
				-- Stun reads like a bind; it reuses the Bind feature so the
				-- canonical feature order (and encodings) stay unchanged.
				raw.bind = math.max(raw.bind, duration)
			elseif kind == "Silence" then
				raw.bind = math.max(raw.bind, duration * 0.5)
			elseif
				kind == "Taunt"
				or kind == "Fear"
				or kind == "Stealth"
				or kind == "DrainResource"
				or kind == "RestoreResource"
			then
				-- Creature control with no visual feature of its own (keeps the
				-- canonical feature order unchanged).
			elseif kind == "Cleanse" then
				-- Removes effects; no visual weight of its own (still counted in Payloads).
			elseif kind == "Force" then
				raw.force = math.max(raw.force, num(p.Magnitude) + num(p.Upward) * 0.5)
			elseif kind == "Control" then
				raw.force = math.max(raw.force, num(p.Acceleration), num(p.MaxSpeed) * 0.5)
			elseif kind == "Displacement" then
				raw.force = math.max(raw.force, num(p.Distance) * 4)
			elseif kind == "ElementalMark" then
				raw.mark = math.max(raw.mark, math.max(1, num(p.Stacks)))
			elseif kind == "TimeDilation" then
				raw.time = math.max(raw.time, math.abs(1 - (if p.Rate == nil then 1 else num(p.Rate))))
			elseif kind == "Reveal" then
				raw.reveal = math.max(raw.reveal, duration)
			elseif kind == "Summon" then
				raw.summon += math.max(1, num(p.Count))
			elseif kind == "AerialMovement" then
				raw.aerial = math.max(raw.aerial, num(p.Speed))
			elseif kind == "Enhancement" then
				raw.force = math.max(raw.force, num(p.WalkSpeedBonus) * 2)
			end
			if kind ~= "DamageOverTime" and kind ~= "Damage" then
				raw.duration = math.max(raw.duration, duration)
			end
		end
	end
end

-- Accumulates raw mechanical magnitudes from every payload and trigger behavior.
local function scanTriggers(spell, raw)
	-- Forms that deliver their own payloads (a wave's push, a beam's burn) count as primary events.
	for _, key in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura" }) do
		local form = spell[key]
		if type(form) == "table" and type(form.Payloads) == "table" then
			scanPayloads(form.Payloads, raw, 1)
		end
	end
	for _, event in ipairs(sortedEvents(spell.Triggers)) do
		local weight = if PRIMARY[event] then 1 else 0.5
		if event == "OnTick" then
			raw.repeats = true
		end
		local steps = spell.Triggers[event]
		for _, step in ipairs(type(steps) == "table" and steps or {}) do
			if type(step) == "table" then
				if step.Behavior == "Explode" then
					raw.direct += num(step.Radius) * 1.5 * weight
				end
				scanPayloads(step.Payloads, raw, weight)
			end
		end
	end
end

local function scanProjectile(spell, raw)
	local p = spell.Projectile
	if type(p) ~= "table" then
		return
	end
	raw.speed = math.max(raw.speed, num(p.Speed))
	raw.size = math.max(raw.size, num(p.Radius))
	raw.range = math.max(raw.range, num(p.MaxDistance))
	for _, b in ipairs(type(p.Behaviors) == "table" and p.Behaviors or {}) do
		if type(b) == "table" then
			local kind = b.Kind
			if kind == "Pierce" then
				raw.pierces += math.max(1, num(b.MaxPierces))
			elseif kind == "Bounce" then
				raw.bounces += math.max(1, num(b.MaxBounces))
			elseif kind == "Return" then
				raw.bounces += 1
			elseif kind == "Split" then
				raw.splits += math.max(2, num(b.ChildCount))
			elseif kind == "Spread" then
				raw.splits += math.max(1, num(b.SidePairs)) * 2
			elseif kind == "Chain" then
				raw.chains += math.max(1, num(b.MaxJumps))
			elseif kind == "Propagate" then
				raw.chains += math.max(1, num(b.MaxTargets))
			elseif kind == "Homing" then
				raw.homing = math.max(raw.homing, num(b.TurnRate))
			elseif kind == "Linger" then
				raw.linger = math.max(raw.linger, num(b.Duration))
				raw.repeats = true
				raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(b.Interval), 0.1))
			elseif kind == "Pulse" or kind == "Proximity" then
				raw.repeats = true
				raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(b.Interval), 0.1))
			end
		end
	end
	if num(p.ChannelInterval) > 0 and raw.repeats then
		raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(p.ChannelInterval), 0.1))
	end
end

local function areaRadius(config)
	return math.max(
		num(config.Radius),
		num(config.OuterRadius),
		num(config.Range) * 0.5,
		num(config.Width) * 0.5,
		num(config.Depth) * 0.5
	)
end

local function scanForms(spell, raw)
	local beam = spell.Beam
	if type(beam) == "table" then
		raw.range = math.max(raw.range, num(beam.Range))
		raw.width = math.max(raw.width, num(beam.Width))
		if beam.Pattern == "Cascade" then
			raw.chains += math.max(1, num(beam.StrikeCount))
			raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(beam.StrikeInterval), 0.1))
			raw.repeats = true
		end
		if num(beam.Interval) > 0 and spell.Casting and spell.Casting.Mode == "Channeled" then
			raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(beam.Interval), 0.1))
		end
		raw.growth = math.max(raw.growth, num(beam.GrowthDuration))
	end
	local wave = spell.Wave
	if type(wave) == "table" then
		raw.range = math.max(raw.range, num(wave.Range))
		raw.radius = math.max(raw.radius, num(wave.Range))
		raw.growth = math.max(raw.growth, num(wave.GrowthDuration))
		if raw.repeats and num(wave.Interval) > 0 then
			raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(wave.Interval), 0.1))
		end
	end
	for _, key in ipairs({ "Field", "Aura" }) do
		local area = spell[key]
		if type(area) == "table" then
			raw.radius = math.max(raw.radius, areaRadius(area))
			raw.growth = math.max(raw.growth, num(area.GrowthDuration))
			if raw.repeats and num(area.Interval) > 0 then
				raw.repeatRate = math.max(raw.repeatRate, 1 / math.max(num(area.Interval), 0.1))
			end
		end
	end
	local construct = spell.Construct
	if type(construct) == "table" then
		local volume = math.max(num(construct.Width), 0.1)
			* math.max(num(construct.Height), 0.1)
			* math.max(num(construct.Depth), 0.1)
		raw.construct = math.max(raw.construct, volume ^ (1 / 3))
		raw.growth = math.max(raw.growth, num(construct.GrowthDuration))
	end
	local casting = spell.Casting
	if type(casting) == "table" then
		raw.cast = num(casting.CastTime) + num(casting.MaximumCharge)
		if casting.Mode == "Channeled" then
			raw.repeats = true
		end
	end
	if type(spell.Lifetime) == "table" then
		raw.lifetime = num(spell.Lifetime.Duration)
	end
end

function Extractor.raw(spell)
	local raw = {
		direct = 0,
		dotTick = 0,
		dotRate = 0,
		dotDuration = 0,
		dotTotal = 0,
		heal = 0,
		shield = 0,
		duration = 0,
		slow = 0,
		bind = 0,
		force = 0,
		speed = 0,
		size = 0,
		range = 0,
		radius = 0,
		width = 0,
		homing = 0,
		linger = 0,
		construct = 0,
		growth = 0,
		cast = 0,
		lifetime = 0,
		payloads = 0,
		mark = 0,
		time = 0,
		reveal = 0,
		summon = 0,
		aerial = 0,
		repeats = false,
		repeatRate = 0,
		pierces = 0,
		bounces = 0,
		splits = 0,
		chains = 0,
	}
	if type(spell) ~= "table" then
		return raw
	end
	scanTriggers(spell, raw)
	scanProjectile(spell, raw)
	scanForms(spell, raw)
	if raw.aerial > 0 then
		raw.speed = math.max(raw.speed, raw.aerial * 2)
	end
	return raw
end

function Extractor.extract(spell)
	local r, R = Extractor.raw(spell), Extractor.Reference
	local f = {
		Direct = Curves.log(r.direct, R.Damage),
		DotTick = Curves.log(r.dotTick, R.DotTick),
		DotRate = if r.dotTick > 0 then Curves.log(r.dotRate, R.TickRate) else 0,
		DotDuration = if r.dotTick > 0 then Curves.sqrt(r.dotDuration, R.Duration) else 0,
		DotTotal = Curves.log(r.dotTotal, R.DotTotal),
		Heal = Curves.log(r.heal, R.Heal),
		Shield = Curves.log(r.shield, R.Shield),
		Duration = Curves.sqrt(r.duration, R.Duration),
		Slow = Curves.smoothstep(r.slow, 0, R.MaxSlow),
		Bind = Curves.sqrt(r.bind, R.Bind),
		Force = Curves.log(r.force, R.Force),
		Speed = Curves.log(r.speed, R.Speed),
		Size = Curves.sqrt(r.size, R.ProjectileRadius),
		Range = Curves.log(r.range, R.Range),
		Radius = Curves.sqrt(r.radius, R.Radius),
		Width = Curves.sqrt(r.width, R.BeamWidth),
		Homing = Curves.sqrt(r.homing, R.TurnRate),
		Linger = Curves.sqrt(r.linger, R.Duration),
		Construct = Curves.sqrt(r.construct, R.Construct),
		Growth = Curves.sqrt(r.growth, R.Duration),
		Cast = Curves.sqrt(r.cast, R.Cast),
		Lifetime = Curves.sqrt(r.lifetime, R.Lifetime),
		Payloads = Curves.saturate(r.payloads, R.Payloads / 3),
		Mark = Curves.linear(r.mark, R.MarkStacks),
		TimeDilation = Curves.linear(r.time, 1),
		Reveal = Curves.sqrt(r.reveal, R.Reveal),
		Summon = Curves.linear(r.summon, R.Summon),
		Aerial = Curves.linear(r.aerial, R.Aerial),
		Repeat = if r.repeats then math.max(0.15, Curves.log(r.repeatRate, R.TickRate)) else 0,
		Pierces = Curves.int(r.pierces, R.MaxCount),
		Bounces = Curves.int(r.bounces, R.MaxCount),
		Splits = Curves.int(r.splits, R.MaxCount),
		Chains = Curves.int(r.chains, R.MaxCount),
	}
	for _, key in ipairs(Extractor.Order) do
		if not Extractor.Counts[key] then
			f[key] = Curves.quantize(f[key])
		end
	end
	return f
end

-- Compact, deterministic replication form: one string attribute instead of 33.
function Extractor.encode(features)
	local parts = {}
	for index, key in ipairs(Extractor.Order) do
		local value = features[key] or 0
		parts[index] = if Extractor.Counts[key]
			then tostring(math.floor(value))
			else tostring(math.floor(value * 1000 + 0.5))
	end
	return table.concat(parts, ",")
end

function Extractor.decode(encoded)
	local features = {}
	for _, key in ipairs(Extractor.Order) do
		features[key] = 0
	end
	if type(encoded) ~= "string" then
		return features
	end
	local index = 0
	for token in string.gmatch(encoded, "[^,]+") do
		index += 1
		local key = Extractor.Order[index]
		if not key then
			break
		end
		local value = tonumber(token) or 0
		features[key] = if Extractor.Counts[key]
			then math.clamp(math.floor(value), 0, Extractor.Reference.MaxCount)
			else math.clamp(value / 1000, 0, 1)
	end
	return features
end

return Extractor
