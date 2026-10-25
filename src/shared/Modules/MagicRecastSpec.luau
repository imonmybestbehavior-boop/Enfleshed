--!strict
-- Pure rules for Recast (the OnRecast event). Pressing a spell's slot while one
-- of its effects is still active, when the spell has OnRecast steps, triggers
-- OnRecast on that effect instead of casting again. Each effect allows
-- Casting.MaxRecasts presses (1-3), spaced by a minimum interval. Recasting is
-- free: no mana, Strain or new cooldown. SpellState.TriggerCount on OnRecast is
-- 1, 2, 3... so steps can branch per stage.
local Spec = {}

-- Forms whose cast leaves an active effect that a press can reach.
Spec.Forms = { "Projectile", "Field", "Aura", "Construct", "Rush" }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Recasts this definition allows (0 when it has no OnRecast steps).
function Spec.allowed(definition: any): number
	local steps = definition and definition.Triggers and definition.Triggers.OnRecast
	if type(steps) ~= "table" or #steps == 0 then
		return 0
	end
	local authored = definition.Casting and definition.Casting.MaxRecasts
	return if finite(authored) then math.max(0, math.floor(authored)) else 1
end

-- Whether `record` can take another recast now. Returns (ok, reason).
function Spec.canRecast(record: any, maxRecasts: number, now: number, minInterval: number): (boolean, string?)
	if record.Finished or record.Recalled then
		return false, "Effect has ended"
	end
	if (record.RecastsUsed or 0) >= maxRecasts then
		return false, "No recasts left"
	end
	if record.LastRecastAt and now - record.LastRecastAt < minInterval then
		return false, "Recast too soon"
	end
	return true, nil
end

-- The newest record among `records` that can take a recast now, or nil.
-- Records carry Player, StartedAt and their spell as SpellId or Definition.SpellId
-- (spawned child effects have their own id, so they are never picked).
function Spec.pick(
	records: { any },
	player: any,
	spellId: string,
	maxRecasts: number,
	now: number,
	minInterval: number
): any?
	local best = nil
	for _, record in records do
		if
			record.Player == player
			and (record.SpellId or (record.Definition and record.Definition.SpellId)) == spellId
			and not record.IsChannel
			and Spec.canRecast(record, maxRecasts, now, minInterval)
			and (best == nil or (record.StartedAt or 0) > (best.StartedAt or 0))
		then
			best = record
		end
	end
	return best
end

-- Marks one recast on the record; returns the stage number (1, 2, 3...).
function Spec.use(record: any, now: number): number
	record.RecastsUsed = (record.RecastsUsed or 0) + 1
	record.LastRecastAt = now
	return record.RecastsUsed
end

return Spec
