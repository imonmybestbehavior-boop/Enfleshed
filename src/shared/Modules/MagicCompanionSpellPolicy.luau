--!strict

-- Companion casting accepts bounded target spells whose payloads imply one
-- unambiguous target relationship. Charged spells auto-release at full charge.
local Policy = {}
local forms = { Projectile = true, Beam = true, Wave = true, Field = true, Aura = true, Construct = true }
local offensive = {
	Damage = true,
	DamageOverTime = true,
	ElementalMark = true,
	Slow = true,
	Bind = true,
	Reveal = true,
	Control = true,
	Force = true,
	Displacement = true,
}
local supportive = { Heal = true, Restoration = true, Shield = true }
local auxiliary = { ElementalMark = true, ConsumeElementalMark = true }
local control = { Slow = true, Bind = true, Control = true, Displacement = true, ElementalMark = true }

function Policy.executionDefinition(definition, spellId)
	local execution = {}
	for key, value in pairs(definition) do
		execution[key] = value
	end
	execution.SpellId = spellId
	-- Magic Lab drafts may bypass sandbox costs for direct tests, but a companion
	-- cast is an owner-authorized cast and must use the ordinary Locus resource path.
	execution.Development = nil
	return execution
end

function Policy.castLockDuration(definition, gather, release)
	local charge = 0
	if definition.Casting.Mode == "Charged" or definition.Casting.Mode == "HoldAndRelease" then
		charge = definition.Casting.MaximumCharge or 0
	end
	local activeDuration = 0
	if definition.Casting.Mode == "Channeled" and definition.Lifetime then
		activeDuration = definition.Lifetime.Duration or 0
	end
	return charge + (definition.Casting.CastTime or 0) + gather + release + activeDuration
end

function Policy.autoReleasesAtFullCharge(definition, companionCast)
	return definition.Casting.Mode == "Charged"
		or (companionCast == true and definition.Casting.Mode == "HoldAndRelease")
end

function Policy.requiresCommandSlot(definition)
	return definition.Casting.Mode == "CommandCast" or definition.Casting.Mode == "Channeled"
end

function Policy.classify(definition)
	if
		not definition
		or (
			definition.Casting.Mode ~= "Instant"
			and definition.Casting.Mode ~= "Charged"
			and definition.Casting.Mode ~= "HoldAndRelease"
			and definition.Casting.Mode ~= "CommandCast"
			and definition.Casting.Mode ~= "Channeled"
		)
	then
		return nil, "Companions support Instant, charged, bounded Channeled, or CommandCast spells"
	end
	if not forms[definition.Form] then
		return nil, "This Form is not supported by companion casting"
	end
	if definition.Targeting == "MaterialTarget" or definition.Targeting == "ObjectTarget" then
		return nil, "Companions cannot select material or object targets yet"
	end
	local hasOffense, hasSupport, hasDamage, hasHeal, hasShield, hasArmorModifier, hasTimeDilation, hasControl, shieldAmount, armorAmount, timeRate =
		false, false, false, false, false, false, false, false, 0, 0, nil
	for _, steps in pairs(definition.Triggers or {}) do
		for _, step in ipairs(steps) do
			for _, payload in ipairs(step.Payloads or {}) do
				if payload.Kind == "ElementalMark" and definition.Element == "Neutral" then
					return nil, "Elemental marks require a non-neutral selected Element"
				elseif payload.Kind == "ModifyAttribute" then
					if
						(payload.Attribute == "MagicArmor" or payload.Attribute == "MagicStrength")
						and payload.Amount < 0
					then
						hasOffense = true
					else
						hasSupport = true
						hasArmorModifier = payload.Attribute == "MagicArmor"
						armorAmount = math.max(armorAmount, payload.Amount or 0)
					end
				elseif payload.Kind == "TimeDilation" then
					if type(payload.Rate) ~= "number" or payload.Rate ~= payload.Rate then
						return nil, "Time dilation needs a finite rate"
					end
					hasTimeDilation = true
					timeRate = payload.Rate
					if payload.Rate < 1 then
						hasOffense = true
					else
						hasSupport = true
					end
				elseif offensive[payload.Kind] then
					hasOffense = true
					hasDamage = hasDamage or payload.Kind == "Damage" or payload.Kind == "DamageOverTime"
					hasControl = hasControl or control[payload.Kind] == true
				elseif supportive[payload.Kind] then
					hasSupport = true
					hasHeal = hasHeal or payload.Kind == "Heal" or payload.Kind == "Restoration"
					hasShield = hasShield or payload.Kind == "Shield"
					if payload.Kind == "Shield" then
						shieldAmount = math.max(shieldAmount, payload.Amount or 0)
					end
				elseif not auxiliary[payload.Kind] then
					return nil, "This payload is not supported by companion casting"
				end
			end
		end
	end
	if not hasOffense and not hasSupport then
		return nil, "Companion spell needs a combat or support payload"
	end
	local relationship = definition.TargetRules.Relationship
	local mode
	if hasOffense and hasSupport then
		if relationship == "Hostile" then
			mode = "Hostile"
		elseif relationship == "Ally" then
			mode = "Ally"
		else
			return nil, "Mixed attack and support spells need an explicit Hostile or Ally target rule"
		end
	elseif hasOffense then
		if relationship ~= "Any" and relationship ~= "Hostile" then
			return nil, "Attack spells need an Any or Hostile target rule"
		end
		mode = "Hostile"
	else
		if relationship ~= "Ally" then
			return nil, "Support spells need an Ally target rule to prevent healing hostiles"
		end
		mode = "Ally"
	end
	return {
		Mode = mode,
		RequiresCommand = definition.Casting.Mode == "CommandCast",
		AutoReleasesAtFullCharge = Policy.autoReleasesAtFullCharge(definition, true),
		AutoChannelsToLifetime = definition.Casting.Mode == "Channeled",
		CanDamage = hasDamage,
		CanControl = hasControl,
		CanHeal = hasHeal,
		CanShield = hasShield,
		ShieldAmount = shieldAmount,
		CanModifyAttribute = hasArmorModifier,
		CanTimeDilation = hasTimeDilation,
		TimeRate = timeRate,
		ArmorAmount = armorAmount,
		Range = definition.TargetRules.Range,
	},
		nil
end

return Policy
