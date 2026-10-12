--!strict

-- Shared authoring metadata for reusable projectile behavior components.
-- Runtime code has a separate server-only executor registry.
local Limits = require(script.Parent.Parent.Configuration.MagicLab)

local Definitions: { [string]: any } = {
	Proximity = {
		Label = "Proximity trigger",
		Description = "Runs On target approaches once for each valid target entering this moving projectile's radius.",
		Defaults = { Kind = "Proximity", Radius = 6, Interval = 0.2, MaxTargets = 4 },
		Fields = {
			{ Key = "Radius", Label = "Proximity radius", Min = 1, Max = Limits.MaxRadius },
			{ Key = "Interval", Label = "Proximity check interval", Min = Limits.MinInterval, Max = 1 },
			{
				Key = "MaxTargets",
				Label = "Maximum targets triggered",
				Min = 1,
				Max = Limits.MaxTargets,
				Integer = true,
			},
		},
	},
	Absorb = {
		Label = "Absorb hostile projectiles",
		Description = "Intercepts nearby hostile magical projectiles and converts each into a bounded potency increase.",
		Defaults = {
			Kind = "Absorb",
			Radius = 7,
			CheckInterval = 0.15,
			MaxAbsorbed = 3,
			PowerPerAbsorption = 0.35,
			MaxPotencyMultiplier = 2.5,
		},
		Fields = {
			{ Key = "Radius", Label = "Interception radius", Min = 1, Max = Limits.MaxRadius },
			{ Key = "CheckInterval", Label = "Intercept check interval", Min = Limits.MinInterval, Max = 1 },
			{
				Key = "MaxAbsorbed",
				Label = "Maximum projectiles absorbed",
				Min = 1,
				Max = Limits.MaxAbsorbedProjectiles,
				Integer = true,
			},
			{
				Key = "PowerPerAbsorption",
				Label = "Potency gained per absorption",
				Min = 0.1,
				Max = Limits.MaxAbsorbPowerGain,
			},
			{
				Key = "MaxPotencyMultiplier",
				Label = "Maximum potency multiplier",
				Min = 1,
				Max = Limits.MaxAbsorbPotencyMultiplier,
			},
		},
	},
	Reflect = {
		Label = "Reflect hostile projectiles",
		Description = "Redirects nearby hostile magical projectiles toward their original caster and transfers their authority to you.",
		Defaults = {
			Kind = "Reflect",
			Radius = 7,
			CheckInterval = 0.15,
			MaxReflections = 3,
			MaxHopsPerProjectile = 1,
		},
		Fields = {
			{ Key = "Radius", Label = "Interception radius", Min = 1, Max = Limits.MaxRadius },
			{ Key = "CheckInterval", Label = "Intercept check interval", Min = Limits.MinInterval, Max = 1 },
			{
				Key = "MaxReflections",
				Label = "Maximum projectiles redirected",
				Min = 1,
				Max = Limits.MaxProjectileReflections,
				Integer = true,
			},
			{
				Key = "MaxHopsPerProjectile",
				Label = "Maximum reflections per projectile",
				Min = 1,
				Max = Limits.MaxProjectileReflectionHops,
				Integer = true,
			},
		},
	},
	Pulse = {
		Label = "Pulse while traveling",
		Description = "Emits a bounded area pulse around the moving projectile at a fixed interval. Effects use On each pulse.",
		Defaults = { Kind = "Pulse", Radius = 5, Interval = 0.6 },
		Fields = {
			{ Key = "Radius", Label = "Pulse radius", Min = 0.5, Max = Limits.MaxRadius },
			{ Key = "Interval", Label = "Pulse interval", Min = Limits.MinInterval, Max = 5 },
		},
	},
	Homing = {
		Label = "Homing",
		Description = "Turns a moving projectile toward nearby valid targets.",
		Defaults = { Kind = "Homing", SearchRadius = 24, TurnRate = 180 },
		Fields = {
			{ Key = "SearchRadius", Label = "Seek radius", Min = 4, Max = Limits.MaxHomingSearchRadius },
			{ Key = "TurnRate", Label = "Turn rate (degrees / second)", Min = 30, Max = Limits.MaxHomingTurnRate },
		},
	},
	Pierce = {
		Label = "Pierce",
		Description = "Allows a projectile to continue through additional targets.",
		Defaults = { Kind = "Pierce", MaxPierces = 1 },
		Fields = {
			{
				Key = "MaxPierces",
				Label = "Additional targets pierced",
				Min = 1,
				Max = Limits.MaxPierces,
				Integer = true,
			},
		},
	},
	Chain = {
		Label = "Chain",
		Description = "Repeats the projectile payload on nearby targets after impact.",
		Defaults = { Kind = "Chain", Radius = 10, MaxJumps = 3, DamageFalloff = 0.7 },
		Fields = {
			{ Key = "Radius", Label = "Jump radius", Min = 2, Max = Limits.MaxRadius },
			{ Key = "MaxJumps", Label = "Maximum chained jumps", Min = 1, Max = Limits.MaxChainJumps, Integer = true },
			{ Key = "DamageFalloff", Label = "Payload falloff per jump", Min = 0.1, Max = 1 },
		},
	},
	Bounce = {
		Label = "Bounce",
		Description = "Reflects from solid world geometry a limited number of times; characters still receive normal impact effects.",
		Defaults = { Kind = "Bounce", MaxBounces = 2, Restitution = 0.8 },
		Fields = {
			{ Key = "MaxBounces", Label = "Maximum bounces", Min = 1, Max = Limits.MaxBounces, Integer = true },
			{ Key = "Restitution", Label = "Speed retained per bounce", Min = 0.2, Max = 1 },
		},
	},
	Split = {
		Label = "Split",
		Description = "Creates a bounded fan of weaker child projectiles on impact.",
		Defaults = { Kind = "Split", ChildCount = 3, SpreadAngle = 24, DamageFalloff = 0.65 },
		Fields = {
			{ Key = "ChildCount", Label = "Child projectiles", Min = 2, Max = Limits.MaxSplitChildren, Integer = true },
			{ Key = "SpreadAngle", Label = "Fan angle (degrees)", Min = 5, Max = Limits.MaxSplitAngle },
			{ Key = "DamageFalloff", Label = "Payload strength per child", Min = 0.1, Max = 1 },
		},
	},
	Spread = {
		Label = "Spread",
		Description = "Adds symmetric side projectiles to each cast while retaining the aimed center projectile.",
		Defaults = { Kind = "Spread", SidePairs = 1, SpreadAngle = 16, DamageFalloff = 0.7 },
		Fields = {
			{ Key = "SidePairs", Label = "Symmetric side pairs", Min = 1, Max = Limits.MaxSpreadPairs, Integer = true },
			{ Key = "SpreadAngle", Label = "Angle per side pair (degrees)", Min = 5, Max = Limits.MaxSpreadAngle },
			{ Key = "DamageFalloff", Label = "Payload strength per pair", Min = 0.1, Max = 1 },
		},
	},
	Propagate = {
		Label = "Propagate impact",
		Description = "Fans the impact payload out to several nearby valid targets at once. Unlike Chain, it does not hop or draw links.",
		Defaults = { Kind = "Propagate", Radius = 12, MaxTargets = 4, PayloadFalloff = 0.7 },
		Fields = {
			{ Key = "Radius", Label = "Propagation radius", Min = 2, Max = Limits.MaxRadius },
			{
				Key = "MaxTargets",
				Label = "Additional targets",
				Min = 1,
				Max = Limits.MaxPropagationTargets,
				Integer = true,
			},
			{ Key = "PayloadFalloff", Label = "Payload falloff per target", Min = 0.1, Max = 1 },
		},
	},
	Linger = {
		Label = "Linger after impact",
		Description = "Turns the impact point into a bounded pulsing hazard for a short duration.",
		Defaults = { Kind = "Linger", Duration = 4, Radius = 6, Interval = 0.5 },
		Fields = {
			{ Key = "Duration", Label = "Linger duration", Min = 0.2, Max = Limits.MaxDuration },
			{ Key = "Radius", Label = "Hazard radius", Min = 0.5, Max = Limits.MaxRadius },
			{ Key = "Interval", Label = "Pulse interval", Min = Limits.MinInterval, Max = 5 },
		},
	},
	Return = {
		Label = "Return to caster",
		Description = "Turns back toward the living caster after the configured outbound distance, then ends when caught or when its spell lifetime expires.",
		Defaults = { Kind = "Return", ReturnAtDistance = 35, CatchRadius = 2, TurnRate = 360 },
		Fields = {
			{ Key = "ReturnAtDistance", Label = "Turn back after distance", Min = 1, Max = Limits.MaxRange },
			{ Key = "CatchRadius", Label = "Catch distance", Min = 0.5, Max = Limits.MaxRadius },
			{
				Key = "TurnRate",
				Label = "Return turn rate (degrees / second)",
				Min = 30,
				Max = Limits.MaxHomingTurnRate,
			},
		},
	},
}

local Spec = {
	Definitions = Definitions,
	Order = {
		"Proximity",
		"Absorb",
		"Reflect",
		"Pulse",
		"Homing",
		"Pierce",
		"Chain",
		"Bounce",
		"Split",
		"Spread",
		"Propagate",
		"Linger",
		"Return",
	},
}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Spec.get(kind: string)
	return Definitions[kind]
end

function Spec.copyDefaults(kind: string)
	local definition = Definitions[kind]
	if not definition then
		return nil
	end
	local result = {}
	for key, value in pairs(definition.Defaults) do
		result[key] = value
	end
	return result
end

function Spec.validate(behavior: any): (boolean, string?)
	if type(behavior) ~= "table" or type(behavior.Kind) ~= "string" then
		return false, "Invalid projectile behavior"
	end
	local definition = Definitions[behavior.Kind]
	if not definition then
		return false, "Unsupported projectile behavior: " .. behavior.Kind
	end
	local allowed = { Kind = true }
	for _, field in ipairs(definition.Fields) do
		allowed[field.Key] = true
		local value = behavior[field.Key]
		if not finite(value) or value < field.Min or value > field.Max or (field.Integer and value % 1 ~= 0) then
			return false, "Invalid " .. behavior.Kind .. " setting: " .. field.Key
		end
	end
	for key in pairs(behavior) do
		if not allowed[key] then
			return false, "Unknown " .. behavior.Kind .. " setting: " .. tostring(key)
		end
	end
	return true
end

return Spec
