--!strict
-- Pure rules for steps that target spells (TargetKind = "Spell"): which live
-- Fields, Auras, Constructs and Tethers a step touches, the relationship
-- filter, and how far Force may move a spell. Points are anything with X/Y/Z
-- (Vector3 in Roblox, plain tables in tests).
local Spec = {}

Spec.Kinds = { Field = true, Aura = true, Construct = true, Tether = true }
Spec.Relationships = { "Hostile", "Allied", "Any" }

local function distance(a: any, b: any): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Whether the target spell's owner relationship passes the step's filter.
-- `relationship` is "Hostile", "Allied", "Neutral" or "Self".
function Spec.relationshipAllowed(wanted: string?, relationship: string): boolean
	local filter = wanted or "Hostile"
	if filter == "Any" then
		return true
	elseif filter == "Allied" then
		return relationship == "Allied" or relationship == "Self"
	end
	return relationship == "Hostile"
end

-- Field / Aura: a circle (sphere) of the area's outer radius around its centre.
function Spec.areaHit(point: any, center: any, radius: number, reach: number): boolean
	return distance(point, center) <= radius + reach
end

-- Construct: inside its bounding sphere (or its part was hit, checked by the caller).
function Spec.boundsHit(point: any, center: any, halfExtent: number, reach: number): boolean
	return distance(point, center) <= halfExtent + reach
end

-- Tether: within half its width of the segment between the anchors.
function Spec.tetherHit(point: any, a: any, b: any, width: number, reach: number): boolean
	local abx, aby, abz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
	local apx, apy, apz = point.X - a.X, point.Y - a.Y, point.Z - a.Z
	local lengthSq = abx * abx + aby * aby + abz * abz
	local t = if lengthSq > 0 then math.clamp((apx * abx + apy * aby + apz * abz) / lengthSq, 0, 1) else 0
	local cx, cy, cz = a.X + abx * t, a.Y + aby * t, a.Z + abz * t
	local dx, dy, dz = point.X - cx, point.Y - cy, point.Z - cz
	return math.sqrt(dx * dx + dy * dy + dz * dz) <= width / 2 + reach
end

-- Force on a spell: authored distance within the hard limit and the PvP cap.
function Spec.forceDistance(authored: number, cap: number?, limit: number): number
	local ceiling = if type(cap) == "number" then math.min(cap, limit) else limit
	local value = if authored == authored then authored else 0
	return math.clamp(value, 0, math.max(0, ceiling))
end

-- How far a pushed spell travels: the full distance, or up to `padding`
-- short of a wall `wallDistance` away; 0 when that is under `minimum`.
function Spec.pushTravel(distance: number, wallDistance: number?, padding: number, minimum: number): number
	local travel = if type(wallDistance) == "number"
		then math.min(distance, math.max(0, wallDistance - padding))
		else distance
	return if travel < minimum then 0 else travel
end

-- Whether an authored step can act on spells: "Required" when it holds a
-- Dispel, "Optional" when every payload can act on spells (Force), nil when
-- it cannot (other payloads, a behavior other than Explode, or a Condition).
function Spec.stepMode(step: any, spellPayloads: { [string]: boolean }): string?
	local payloads = step.Payloads or {}
	if #payloads == 0 or (step.Behavior ~= nil and step.Behavior ~= "Explode") or step.Condition ~= nil then
		return nil
	end
	local required = false
	for _, payload in payloads do
		if not spellPayloads[payload.Kind] then
			return nil
		end
		required = required or payload.Kind == "Dispel"
	end
	return if required then "Required" else "Optional"
end

-- Keeps a step's TargetKind consistent with `stepMode` after an editor change.
function Spec.syncStep(step: any, spellPayloads: { [string]: boolean })
	local mode = Spec.stepMode(step, spellPayloads)
	if mode == "Required" then
		step.TargetKind = "Spell"
	elseif mode == nil then
		step.TargetKind = nil
		step.SpellRelationship = nil
	end
end

-- One Dispel or Force per spell target per root cast: `touched` lives on the
-- cascade (its operation budget). Returns true the first time only.
function Spec.claim(touched: { [any]: boolean }, record: any): boolean
	if touched[record] then
		return false
	end
	touched[record] = true
	return true
end

return Spec
