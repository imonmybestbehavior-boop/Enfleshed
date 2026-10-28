--!strict

-- Spell vs Spell, kept free of Roblox services so the audit harness can drive
-- it with doubles. MagicService describes live spells as entries and does the
-- world changes through `deps`; the rules live in MagicSpellTargetSpec,
-- MagicDispelSpec and MagicSpellLensSpec.
--
-- Entry: {
--   Record,             -- the active record (or a persistent Construct model)
--   Kind,               -- "Field" | "Aura" | "Construct" | "Tether"
--   Owner: Model?,      -- the spell's caster
--   OwnerUserId: number?,
--   Center, Radius?,    -- Field / Aura centre and outer radius
--   HalfExtent?,        -- Construct bounds
--   Model: Instance?,   -- Construct model (a hit part inside it counts)
--   A?, B?,             -- Tether anchor positions
--   Attached: boolean?, -- follows a character or part (Force cannot move it)
--   Persistent: boolean?,
--   Complexity: number?,
-- }
local Shared = game:GetService("ReplicatedStorage").Shared
local TargetSpec = require(Shared.Modules.MagicSpellTargetSpec)
local DispelSpec = require(Shared.Modules.MagicDispelSpec)
local LensSpec = require(Shared.Modules.MagicSpellLensSpec)
local Limits = require(Shared.Configuration.MagicLab)

local Spells = {}

local function touches(entry: any, point: any, reach: number, hitPart: Instance?): boolean
	if entry.Kind == "Construct" then
		if hitPart and entry.Model and hitPart:IsDescendantOf(entry.Model) then
			return true
		end
		return TargetSpec.boundsHit(point, entry.Center, entry.HalfExtent or 0, reach)
	elseif entry.Kind == "Tether" then
		return TargetSpec.tetherHit(point, entry.A, entry.B, Limits.TetherDispelWidth, reach)
	end
	return TargetSpec.areaHit(point, entry.Center, entry.Radius or 0, reach)
end

-- The live spells a Spell step touches at `point` (within `reach`, or the
-- part it hit), filtered by the owner's relationship to the caster.
-- `relationship(owner)` returns "Self", "Hostile", "Ally" or "Neutral".
function Spells.resolve(
	entries: { any },
	filter: string?,
	point: any,
	reach: number,
	hitPart: Instance?,
	relationship: (Model?) -> string
): { any }
	local found = {}
	for _, entry in entries do
		local relation = relationship(entry.Owner)
		if relation == "Ally" then
			relation = "Allied"
		end
		if TargetSpec.relationshipAllowed(filter, relation) and touches(entry, point, reach, hitPart) then
			table.insert(found, entry)
		end
	end
	return found
end

export type DispelDeps = {
	CasterUserId: number?,
	Complexity: number, -- the dispel spell's own estimated complexity
	Touched: { [any]: boolean }, -- once per spell target per root cast
	Remaining: (any) -> number?, -- nil for untimed spells
	SetRemaining: (any, number) -> (),
	End: (any) -> (), -- OnDispelled / snap, then removal
}

-- Applies a Dispel payload to `entries`. Returns how many it ended.
function Spells.dispel(payload: any, entries: { any }, deps: DispelDeps): number
	local ended = 0
	for _, entry in entries do
		if not TargetSpec.claim(deps.Touched, entry.Record) then
			continue
		end
		if entry.Persistent then
			-- Saved Constructs: only their owner, and only by ending them.
			if DispelSpec.persistentAllowed(deps.CasterUserId, entry.OwnerUserId) and payload.Mode == "End" then
				deps.End(entry)
				ended += 1
			end
			continue
		end
		local action, remaining = DispelSpec.resolve(
			payload.Mode,
			payload.Seconds,
			deps.Remaining(entry),
			entry.Complexity or 0,
			deps.Complexity
		)
		if action == "End" then
			deps.End(entry)
			ended += 1
		elseif action == "Shorten" then
			deps.SetRemaining(entry, remaining :: number)
		end
	end
	return ended
end

export type ForceDeps = {
	Touched: { [any]: boolean },
	Cap: number?, -- PvP MaxSpellForceDistance
	Move: (any, number) -> boolean, -- moves the entry along the push, wall-checked
}

-- Force on spells: unattached Field/Aura centres and non-persistent,
-- unattached Constructs. Tethers do not move. Returns how many moved.
function Spells.force(payload: any, entries: { any }, deps: ForceDeps): number
	local distance = TargetSpec.forceDistance(payload.Magnitude or 0, deps.Cap, Limits.MaxSpellForceDistance)
	local moved = 0
	for _, entry in entries do
		if
			entry.Kind ~= "Tether"
			and not entry.Attached
			and not entry.Persistent
			and distance > 0
			and TargetSpec.claim(deps.Touched, entry.Record)
			and deps.Move(entry, distance)
		then
			moved += 1
		end
	end
	return moved
end

-- Field lens: applies to each projectile once per field. `floorsFor(projectile)`
-- returns the PvP floors when it belongs to a hostile player. Changes the
-- projectile record in place (PotencyMultiplier, Velocity, BaseSpeed,
-- LensMarks) and returns how many changed.
function Spells.lens(field: any, lens: any, projectiles: { any }, floorsFor: (any) -> any?): number
	local changed = 0
	for _, projectile in projectiles do
		local change = LensSpec.apply(projectile, field, lens, floorsFor(projectile))
		if change then
			changed += 1
			projectile.PotencyMultiplier = (projectile.PotencyMultiplier or 1) * change.Potency
			if change.Speed ~= 1 then
				projectile.Velocity = projectile.Velocity * change.Speed
				projectile.BaseSpeed = (projectile.BaseSpeed or 0) * change.Speed
			end
			if change.Mark then
				projectile.LensMarks = projectile.LensMarks or {}
				table.insert(projectile.LensMarks, change.Mark)
			end
		end
	end
	return changed
end

return Spells
