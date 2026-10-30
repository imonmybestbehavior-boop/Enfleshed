--!strict
-- Pure rules for Stun, Silence and Cleanse.
--
-- Stun: binds the target and blocks its attacks and casts. Diminishing returns
-- per target: within an 8 s window (from the first stun) the second stun lasts
-- 50%, the third is not applied and the target becomes immune for 8 s.
-- Silence: blocks spell casts and channel starts, and cancels active channels.
-- Players only; monster/Nascent attacks are not spells and are never silenced.
-- Cleanse: removes up to Count Banes or Boons, longest-remaining first.
local Spec = {}

Spec.StunWindow = 8
Spec.SecondStunFactor = 0.5
Spec.StunImmunity = 8

export type StunHistory = { WindowStart: number, Count: number, ImmuneUntil: number }

function Spec.newHistory(): StunHistory
	return { WindowStart = -math.huge, Count = 0, ImmuneUntil = -math.huge }
end

-- Returns the stun duration to apply (0 = immune / not applied) and updates `history`.
function Spec.applyStun(history: StunHistory, now: number, duration: number): number
	if now < history.ImmuneUntil then
		return 0
	end
	if now - history.WindowStart > Spec.StunWindow then
		history.WindowStart = now
		history.Count = 0
	end
	history.Count += 1
	if history.Count == 1 then
		return duration
	elseif history.Count == 2 then
		return duration * Spec.SecondStunFactor
	end
	-- Third stun inside the window: not applied, and immune for a while.
	history.ImmuneUntil = now + Spec.StunImmunity
	history.WindowStart = -math.huge
	history.Count = 0
	return 0
end

-- Player request -> gating category (Protocol action names).
Spec.ActionCategories = {
	Light = "Attack",
	Heavy = "Attack",
	BlockStart = "Attack",
	Dash = "Move",
	MagicStart = "Cast",
	MagicRelease = "Cast",
	EquipmentUse = "Cast",
}

-- Action gating. Categories: "Attack" (melee, block), "Move" (dash), "Cast"
-- (spell start, release, equipment magic). Polymorph blocks attacks and casts
-- but not movement. Returns blocked, reason.
function Spec.blocks(category: string, stunned: boolean, silenced: boolean, polymorphed: boolean?): (boolean, string?)
	if stunned and (category == "Attack" or category == "Move" or category == "Cast") then
		return true, "Stunned"
	end
	if polymorphed and (category == "Attack" or category == "Cast") then
		return true, "Polymorphed"
	end
	if silenced and category == "Cast" then
		return true, "Silenced"
	end
	return false, nil
end

-- Cleanse candidates come from three places (timed statuses, periodic effects,
-- enchantments); each is { Polarity, Element?, Remaining, AppliedAt }.
function Spec.matches(candidate: any, remove: string, element: string?): boolean
	local polarity = if remove == "Banes" then "Bane" elseif remove == "Boons" then "Boon" else nil
	if not polarity or candidate.Polarity ~= polarity then
		return false
	end
	return element == nil or candidate.Element == element
end

-- Order to remove in: longest remaining first (ongoing enchantments count as
-- unending), then the most recently applied.
function Spec.cleanseOrder(candidates: { any }): { any }
	local ordered = table.clone(candidates)
	table.sort(ordered, function(a, b)
		local ra, rb = a.Remaining or 0, b.Remaining or 0
		if ra ~= rb then
			return ra > rb
		end
		return (a.AppliedAt or 0) > (b.AppliedAt or 0)
	end)
	return ordered
end

-- The candidates a Cleanse removes: matching ones, in cleanseOrder, at most Count.
function Spec.select(candidates: { any }, remove: string, count: number, element: string?): { any }
	local matching = {}
	for _, candidate in ipairs(candidates) do
		if Spec.matches(candidate, remove, element) then
			table.insert(matching, candidate)
		end
	end
	local selected = {}
	for index, candidate in ipairs(Spec.cleanseOrder(matching)) do
		if index > count then
			break
		end
		table.insert(selected, candidate)
	end
	return selected
end

return Spec
