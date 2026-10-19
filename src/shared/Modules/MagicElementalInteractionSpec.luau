--!strict

-- Data-driven effects for elemental marks (MagicLab.ElementalInteractions):
-- starter effects that apply whenever a mark lands, and reactions that fire
-- once when a mark (or a Force hit) lands on a target already in a state.
local MagicLab = require(script.Parent.Parent.Configuration.MagicLab)
local Spec = {}

local function copyEffects(effects: { any }, markDuration: number?): { any }
	local copies = {}
	for _, configuredEffect in ipairs(effects) do
		local effect = {}
		for key, value in pairs(configuredEffect) do
			effect[key] = value
		end
		if effect.Duration == "Mark" then
			effect.Duration = markDuration
		end
		table.insert(copies, effect)
	end
	return copies
end

local function incomingMatches(entry: any, incoming: string): boolean
	if type(entry.Incoming) == "table" then
		return table.find(entry.Incoming, incoming) ~= nil
	end
	return entry.Incoming == incoming
end

-- Starter effects for a mark of `element` (entries without Existing).
function Spec.effectsFor(element: string, markDuration: number?, interactions: { any }?): { any }
	local effects = {}
	for _, entry in ipairs(interactions or MagicLab.ElementalInteractions) do
		if entry.Existing == nil and incomingMatches(entry, element) then
			for _, effect in copyEffects(entry.Effects, markDuration) do
				table.insert(effects, effect)
			end
		end
	end
	return effects
end

-- The first reaction whose Existing state the target has, for this incoming
-- element (or "Force"). `has(state)` answers for element marks and "Frozen".
function Spec.findReaction(incoming: string, has: (string) -> boolean, interactions: { any }?): any?
	for _, entry in ipairs(interactions or MagicLab.ElementalInteractions) do
		if entry.Existing ~= nil and incomingMatches(entry, incoming) and has(entry.Existing) then
			return entry
		end
	end
	return nil
end

function Spec.reactionEffects(reaction: any, markDuration: number?): { any }
	return copyEffects(reaction.Effects or {}, markDuration)
end

-- Every reaction name, for conditions and tests.
function Spec.reactionNames(interactions: { any }?): { string }
	local names = {}
	for _, entry in ipairs(interactions or MagicLab.ElementalInteractions) do
		if entry.Name then
			table.insert(names, entry.Name)
		end
	end
	return names
end

-- SpellId given to effects a reaction applies; Frozen = an active Stun from Freeze.
function Spec.spellId(reaction: any): string
	return "Reaction:" .. tostring(reaction.Name)
end

return Spec
