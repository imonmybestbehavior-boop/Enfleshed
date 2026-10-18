--!strict
local Config = require(script.Parent.Parent.Configuration.SpellProgression)
local CastingSpec = require(script.Parent.MagicCastingSpec)
local Rules = {}

function Rules.slots(profile): number
	local count = Config.StartingSlots
	for _, milestone in ipairs(Config.SlotMilestones) do
		if (profile.XP or 0) >= milestone.XP then
			count = milestone.Slots
		end
	end
	return count
end

function Rules.rank(profile, recordId: string): number
	local ranks = profile.SpellRanks or {}
	return math.clamp(ranks[recordId] or 0, 0, #Config.RankPrices)
end

function Rules.requirements(definition): { string }
	local needed = {}
	if table.find({ "Field", "Aura", "Wave", "Construct" }, definition.Form) then
		table.insert(needed, "AdvancedForms")
	end
	if definition.Projectile and #(definition.Projectile.Behaviors or {}) > 0 then
		table.insert(needed, "AdvancedBehaviors")
	end
	if
		definition.Visual
		and (
			(definition.Visual.Palette ~= nil and definition.Visual.Palette ~= "Origin")
			or (definition.Visual.VFXDefinition ~= nil and definition.Visual.VFXDefinition ~= "None")
		)
	then
		table.insert(needed, "VisualCraft")
	end
	local triggers = definition.Triggers or {}
	for event, steps in pairs(triggers) do
		if event ~= "OnCast" and event ~= "OnImpact" then
			if not table.find(needed, "AdvancedBehaviors") then
				table.insert(needed, "AdvancedBehaviors")
			end
		end
		for _, step in ipairs(steps) do
			if step.Behavior and not table.find(needed, "AdvancedBehaviors") then
				table.insert(needed, "AdvancedBehaviors")
			end
			for _, payload in ipairs(step.Payloads or {}) do
				if
					not table.find(
						{ "Damage", "Heal", "Shield", "DamageOverTime", "Restoration", "Slow" },
						payload.Kind
					) and not table.find(needed, "AdvancedEffects")
				then
					table.insert(needed, "AdvancedEffects")
				end
			end
		end
	end
	return needed
end

function Rules.canUse(profile, definition, recordId: string, estimate): (boolean, string)
	for _, id in ipairs(Rules.requirements(definition)) do
		if not (profile.Unlocks and profile.Unlocks[id]) then
			return false, "Unlock " .. Config.Unlocks[id].Name .. " to use this spell in combat"
		end
	end
	local rank = Rules.rank(profile, recordId)
	local values = estimate(definition)
	if
		values.ManaDemand > Config.RankManaLimits[rank + 1]
		or values.Strain > Config.RankStrainLimits[rank + 1]
		or values.Complexity > Config.RankComplexityLimits[rank + 1]
	then
		return false, "Upgrade this spell to use its current power in combat"
	end
	return true, ""
end

function Rules.reprice(definition, estimate, clone)
	local values = estimate(definition)
	local special = if type(definition.Cost) == "table" then definition.Cost.SpecialResources else nil
	definition.Cost = {
		ManaDemand = values.ManaDemand,
		Strain = values.Strain,
		Complexity = values.Complexity,
		SpecialResources = clone(special or {}),
	}
	definition.Casting.Cooldown = math.max(
		definition.Casting.Cooldown or 0,
		math.ceil((values.ManaDemand * 0.012 + values.Strain * 0.009) * 20) / 20
	)
	if CastingSpec.isHeldMode(definition.Casting.Mode) then
		definition.Casting.ManaUpkeepPerSecond =
			math.max(definition.Casting.ManaUpkeepPerSecond or 0, math.ceil(values.ManaDemand * 0.25))
		definition.Casting.StrainPerSecond =
			math.max(definition.Casting.StrainPerSecond or 0, math.ceil(values.Strain * 0.2))
	end
	return values
end

return Rules
