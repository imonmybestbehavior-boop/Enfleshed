--!strict

-- Shared structural gate for the subset Magic Runtime V1 actually executes.
-- It deliberately rejects future schema components until their handlers exist.
local Validator = {}
local PrincipleSpec = require(script.Parent.MagicPrincipleSpec)

local function positive(value)
	return typeof(value) == "number" and value == value and value > 0
end

local function payloadsValid(payloads)
	if typeof(payloads) ~= "table" or #payloads == 0 then
		return false
	end
	for _, payload in ipairs(payloads) do
		if payload.Kind == "Damage" then
			if not positive(payload.Amount) then
				return false
			end
		elseif payload.Kind == "Force" then
			if not positive(payload.Magnitude) or (payload.Upward ~= nil and typeof(payload.Upward) ~= "number") then
				return false
			end
		elseif payload.Kind == "Enhancement" then
			if
				typeof(payload.WalkSpeedBonus) ~= "number"
				and typeof(payload.JumpPowerBonus) ~= "number"
				and not positive(payload.SpeedMultiplier)
			then
				return false
			end
			if payload.SpeedMultiplier ~= nil and not positive(payload.SpeedMultiplier) then
				return false
			end
		elseif payload.Kind == "Manipulation" then
			if payload.Operation ~= "Raise" or not positive(payload.Distance) then
				return false
			end
		else
			return false
		end
	end
	return true
end

local function instantaneous(definition)
	return definition.Lifetime and definition.Lifetime.Mode == "Instantaneous"
end

local function castingValid(casting, form)
	if typeof(casting) ~= "table" or not positive(casting.Cooldown) then
		return false
	end
	if casting.StrainPerSecond ~= nil then
		return false
	end
	if casting.Mode == "Instant" then
		return casting.ManaUpkeepPerSecond == nil
	end
	if casting.Mode == "Charged" or casting.Mode == "HoldAndRelease" then
		return casting.ManaUpkeepPerSecond == nil
			and positive(casting.MinimumCharge)
			and positive(casting.MaximumCharge)
			and casting.MinimumCharge <= casting.MaximumCharge
	end
	if casting.Mode == "CommandCast" then
		return casting.ManaUpkeepPerSecond == nil
			and (form == "Projectile" or form == "Beam" or form == "Wave" or form == "Field" or form == "Aura")
	end
	if casting.Mode == "Sustained" then
		return form == "Construct" and positive(casting.ManaUpkeepPerSecond) and casting.ManaUpkeepPerSecond <= 100
	end
	return casting.Mode == "Channeled" and positive(casting.ManaUpkeepPerSecond) and casting.ManaUpkeepPerSecond <= 100
end

function Validator.validate(definition)
	if
		typeof(definition) ~= "table"
		or typeof(definition.SpellId) ~= "string"
		or typeof(definition.Name) ~= "string"
	then
		return false, "Missing identity"
	end
	if
		not definition.Source
		or not PrincipleSpec.expressionMatches(definition.Source.Principle, definition.Source.Expression)
	then
		return false, "Unsupported source"
	end
	local principle = PrincipleSpec.Definitions[definition.Source.Principle]
	if not principle.Forms[definition.Form] then
		return false, "UNSUPPORTED " .. definition.Source.Principle .. "/" .. tostring(definition.Form)
	end
	if
		not castingValid(definition.Casting, definition.Form)
		or typeof(definition.Cost) ~= "table"
		or not positive(definition.Cost.ManaDemand)
		or not positive(definition.Cost.Strain)
		or not positive(definition.Cost.Complexity)
	then
		return false, "Invalid casting or cost data"
	end
	if definition.Form == "Projectile" then
		if
			(definition.Targeting ~= "AimDirection" and definition.Targeting ~= "MaterialTarget")
			or definition.Geometry ~= "Sphere"
			or definition.Motion ~= "Linear"
			or not definition.Projectile
			or not positive(definition.Projectile.Speed)
			or not positive(definition.Projectile.Radius)
			or not definition.Visual
			or not definition.Lifetime
			or definition.Lifetime.Mode ~= "FixedDuration"
			or not positive(definition.Lifetime.Duration)
			or typeof(definition.Triggers) ~= "table"
			or typeof(definition.Triggers.OnImpact) ~= "table"
		then
			return false, "Unsupported projectile definition"
		end
		if definition.Targeting == "MaterialTarget" then
			if
				definition.Source.Principle ~= "Matter"
				or definition.Source.Expression ~= "Earth"
				or not definition.Material
				or definition.Material.Material ~= "Earth"
				or not positive(definition.Material.Amount)
				or not positive(definition.Material.SearchRadius)
			then
				return false, "Invalid material requirement"
			end
		end
		for _, trigger in ipairs(definition.Triggers.OnImpact) do
			if trigger.Payloads and not payloadsValid(trigger.Payloads) then
				return false, "Invalid impact payload"
			end
			if
				trigger.Behavior
				and (
					trigger.Behavior ~= "Explode"
					or not positive(trigger.Radius)
					or not payloadsValid(trigger.Payloads)
				)
			then
				return false, "Unsupported behavior"
			end
		end
		return true
	end
	if definition.Form == "Wave" then
		if
			(definition.Targeting ~= "Self" and definition.Targeting ~= "EntityTarget")
			or definition.Geometry ~= "Cone"
			or definition.Motion ~= "Stationary"
			or not definition.Wave
			or not positive(definition.Wave.Range)
			or typeof(definition.Wave.Dot) ~= "number"
			or definition.Wave.Dot < -1
			or definition.Wave.Dot > 1
			or (definition.Wave.Interval ~= nil and not positive(definition.Wave.Interval))
			or not payloadsValid(definition.Wave.Payloads)
			or not definition.Lifetime
			or (definition.Casting.Mode == "Channeled" and definition.Lifetime.Mode ~= "FixedDuration" or definition.Casting.Mode ~= "Channeled" and definition.Lifetime.Mode ~= "Instantaneous")
			or not definition.Triggers
			or not definition.Triggers.OnCast
			or (definition.Casting.Mode == "Channeled" and not payloadsValid(definition.Triggers.OnTick))
		then
			return false, "Unsupported wave definition"
		end
		return true
	end
	if definition.Form == "Beam" then
		if
			definition.Targeting ~= "AimDirection"
			or definition.Geometry ~= "Line"
			or definition.Motion ~= "Instantaneous"
			or (definition.Casting.Mode == "Channeled" and definition.Lifetime.Mode ~= "FixedDuration")
			or (definition.Casting.Mode ~= "Channeled" and not instantaneous(definition))
			or not definition.Beam
			or not positive(definition.Beam.Range)
			or not definition.Triggers
			or not payloadsValid(definition.Triggers.OnCast)
				and not (definition.Casting.Mode == "Channeled" and payloadsValid(definition.Triggers.OnTick))
		then
			return false, "Unsupported beam definition"
		end
		if (definition.Casting.Mode == "Channeled") ~= (definition.Lifetime.Mode == "FixedDuration") then
			return false, "Channeled Beams require a fixed maximum duration; instant Beams are instantaneous"
		end
		return true
	end
	if definition.Form == "Field" then
		if
			definition.Targeting ~= "WorldPoint"
			or definition.Geometry ~= "Sphere"
			or definition.Motion ~= "Stationary"
			or not definition.Field
			or not positive(definition.Field.Radius)
			or not positive(definition.Field.Interval)
			or not definition.Lifetime
			or definition.Lifetime.Mode ~= "FixedDuration"
			or not positive(definition.Lifetime.Duration)
			or not definition.Triggers
			or not payloadsValid(definition.Triggers.OnInterval)
		then
			return false, "Unsupported field definition"
		end
		return true
	end
	if definition.Form == "SelfEnhancement" then
		if
			definition.Targeting ~= "Self"
			or definition.Geometry ~= "Self"
			or definition.Motion ~= "Stationary"
			or not definition.Lifetime
			or not (definition.Lifetime.Mode == "UntilToggledOff" or (definition.Lifetime.Mode == "FixedDuration" and positive(
				definition.Lifetime.Duration
			)))
			or not definition.Triggers
			or not payloadsValid(definition.Triggers.OnCast)
		then
			return false, "Unsupported self enhancement definition"
		end
		return true
	end
	if definition.Form == "Manipulation" then
		if
			definition.Targeting ~= "MaterialTarget"
			or definition.Geometry ~= "Point"
			or definition.Motion ~= "Instantaneous"
			or not instantaneous(definition)
			or not definition.Material
			or definition.Material.Material ~= "Earth"
			or not positive(definition.Material.SearchRadius)
			or not definition.Triggers
			or not payloadsValid(definition.Triggers.OnCast)
		then
			return false, "Unsupported manipulation definition"
		end
		return true
	end
	return false, "Unsupported form"
end

return Validator
