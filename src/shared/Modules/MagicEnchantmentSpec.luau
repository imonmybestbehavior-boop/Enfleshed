--!strict
-- Pure rules for Enchantments (the SelfEnhancement Form) that can sit on a
-- character other than their caster.
--
--   owner  = the caster: pays costs, owns the cascade budget, gets feedback,
--            is credited with the enchantment's damage.
--   holder = the character the enchantment is on (the owner for self casts).
--
-- MagicService keeps the live records; this module decides keys, caps, when an
-- enchantment ends and which events that fires, so the audit harness can run
-- the same rules without Roblox.
local Spec = {}

Spec.Types = { "Boon", "Bane", "Neutral" }

-- An enchantment's type comes from its payloads: any Bane makes it a Bane,
-- otherwise any Boon makes it a Boon, otherwise Neutral.
function Spec.typeOf(definition: any, polarityOf: (string) -> string?): string
	local hasBoon = false
	for _, steps in pairs(definition.Triggers or {}) do
		for _, step in ipairs(steps) do
			for _, payload in ipairs(step.Payloads or {}) do
				local polarity = polarityOf(payload.Kind)
				if polarity == "Bane" then
					return "Bane"
				elseif polarity == "Boon" then
					hasBoon = true
				end
			end
		end
	end
	return if hasBoon then "Boon" else "Neutral"
end

-- One enchantment per spell per holder. Self casts keep the plain SpellId key.
function Spec.key(spellId: string, holderId: string, isSelf: boolean): string
	return if isSelf then spellId else spellId .. "@" .. holderId
end

-- Keys that do not change what an Enchantment does, so two casters' copies of
-- the same spell count as the same Enchantment.
local cosmetic = {
	SpellId = true,
	Name = true,
	Description = true,
	Visual = true,
	Audio = true,
	Tags = true,
	Development = true,
	Cost = true,
	EstimatedCost = true,
}

local function canonical(value: any, depth: number): string
	local kind = type(value)
	if kind == "number" then
		return string.format("%.6g", value)
	elseif kind == "string" then
		return string.format("%q", value)
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind ~= "table" or depth > 12 then
		return "_"
	end
	local keys = {}
	for key in pairs(value) do
		if type(key) == "number" or (type(key) == "string" and not cosmetic[key] and string.sub(key, 1, 1) ~= "_") then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, tostring(key) .. "=" .. canonical(value[key], depth + 1))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- Identity of an Enchantment: its gameplay content, independent of whose
-- library slot it came from.
function Spec.identity(definition: any): string
	return canonical(definition, 0)
end

-- `existing` lists the enchantments already on this holder as
-- { Owner, Key, Identity }. A recast of the same Enchantment by the same owner
-- refreshes it (refreshKey is that owner's record to replace). Different owners
-- may stack the same Enchantment at most `perSpell` times. Different
-- Enchantments never limit each other.
function Spec.canAdd(existing: { any }, owner: string, identity: string, perSpell: number): (boolean, string?, string?)
	local others = 0
	for _, record in ipairs(existing) do
		if record.Identity == identity then
			if record.Owner == owner then
				return true, nil, record.Key
			end
			others += 1
		end
	end
	if others >= perSpell then
		return false, "This Enchantment is already on them " .. perSpell .. " times", nil
	end
	return true, nil, nil
end

-- Why an enchantment should end now, or nil. Facts are sampled each frame.
-- Order matters: a holder that died reports HolderDeath even if time also ran
-- out, and a holder that left (or a self-caster who respawned) is HolderGone,
-- which fires only OnExpire.
function Spec.endReason(
	record: any,
	facts: {
		Now: number,
		HolderAlive: boolean,
		HolderPresent: boolean,
		OwnerAlive: boolean,
		OwnerPresent: boolean,
	}
): string?
	if not facts.HolderAlive then
		return "HolderDeath"
	end
	if not facts.HolderPresent then
		return "HolderGone"
	end
	if not facts.OwnerAlive or not facts.OwnerPresent then
		return "OwnerDeath"
	end
	if facts.Now >= record.ExpiresAt then
		return "Duration"
	end
	return nil
end

-- Lifecycle events to fire, in order, when an enchantment ends.
-- Holder death on someone else tells the owner via OnTargetDeath; on yourself
-- it is your own death (OnCasterDeath). Owner death also fires OnCasterDeath.
function Spec.endEvents(reason: string, isSelf: boolean): { string }
	if reason == "HolderDeath" then
		return if isSelf then { "OnCasterDeath", "OnExpire" } else { "OnTargetDeath", "OnExpire" }
	elseif reason == "OwnerDeath" then
		return { "OnCasterDeath", "OnExpire" }
	end
	return { "OnExpire" }
end

-- Movement payloads on another character: Swiftness only for player holders,
-- Aerial movement only on yourself (it steers from the holder's own input).
function Spec.movement(isSelf: boolean, holderIsPlayer: boolean): { Swiftness: boolean, Aerial: boolean }
	return { Swiftness = isSelf or holderIsPlayer, Aerial = isSelf }
end

-- Replicated overhead summary, e.g. "Boon:2|Bane:1". Empty string: none.
function Spec.encode(types: { string }): string
	local counts = {}
	for _, kind in ipairs(types) do
		counts[kind] = (counts[kind] or 0) + 1
	end
	local parts = {}
	for _, kind in ipairs(Spec.Types) do
		if counts[kind] then
			table.insert(parts, kind .. ":" .. counts[kind])
		end
	end
	return table.concat(parts, "|")
end

function Spec.decode(encoded: any): { [string]: number }
	local counts = {}
	if type(encoded) ~= "string" then
		return counts
	end
	for kind, count in string.gmatch(encoded, "(%a+):(%d+)") do
		counts[kind] = tonumber(count) or 0
	end
	return counts
end

return Spec
