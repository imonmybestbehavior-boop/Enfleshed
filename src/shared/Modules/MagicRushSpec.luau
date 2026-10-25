--!strict
-- Pure rules for the Rush Form (Dash / Blink): how far the caster may go and
-- where the path stops being safe. All world queries are injected, measured
-- as a distance `t` along the caster's horizontal aim.
--
--   probes.wall(distance) -> distance to the first solid obstacle, or nil
--   probes.floor(t)       -> floor height and its normal Y at t, or nil (a drop)
--   probes.clear(t, floorY) -> true when the caster fits standing there
--
-- The checks mirror displaceTarget: walls block, the floor must be walkable
-- (normal Y >= limit), each step changes height by at most the step limit, and
-- the destination needs clearance. Unlike displaceTarget, an unsafe stretch
-- shortens the rush to the last safe sample instead of cancelling it.
local Spec = {}

export type Settings = {
	SampleStep: number,
	WallPadding: number,
	MaxStepHeight: number,
	MinGroundNormalY: number,
	MinDistance: number,
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Authored distance x potency, clamped to the PvP cap and the hard limit.
function Spec.distance(authored: number, potency: number?, cap: number?, limit: number): number
	local base = if finite(authored) then math.max(0, authored) else 0
	local scaled = base * (if finite(potency) then math.max(0, potency :: number) else 1)
	local ceiling = if finite(cap) then math.min(cap :: number, limit) else limit
	return math.clamp(scaled, 0, math.max(0, ceiling))
end

-- Distances to test along the path: every SampleStep studs, ending exactly at `limit`.
function Spec.samples(limit: number, step: number): { number }
	local result = {}
	if not finite(limit) or limit <= 0 then
		return result
	end
	local stride = if finite(step) and step > 0 then step else limit
	local t = stride
	while t < limit - 1e-6 do
		table.insert(result, t)
		t += stride
	end
	table.insert(result, limit)
	return result
end

export type Waypoint = { T: number, Floor: number }

-- Returns (travelled distance, floor height there, waypoints) for the furthest
-- safe point, or nil when the caster cannot move at least MinDistance. The
-- waypoints start at t = 0 and let a Dash follow the floor.
function Spec.plan(
	distance: number,
	startFloorY: number,
	probes: any,
	settings: Settings
): (number?, number?, { Waypoint }?)
	if not finite(distance) or distance <= 0 or not finite(startFloorY) then
		return nil, nil, nil
	end
	local limit = distance
	local wall = probes.wall(distance)
	if finite(wall) then
		limit = math.min(limit, math.max(0, wall - settings.WallPadding))
	end
	local previous = startFloorY
	local best, bestFloor = nil, nil
	local waypoints: { Waypoint } = { { T = 0, Floor = startFloorY } }
	for _, t in Spec.samples(limit, settings.SampleStep) do
		local floorY, normalY = probes.floor(t)
		if
			not finite(floorY)
			or not finite(normalY)
			or normalY < settings.MinGroundNormalY
			or math.abs(floorY - previous) > settings.MaxStepHeight
		then
			break
		end
		if not probes.clear(t, floorY) then
			break
		end
		best, bestFloor = t, floorY
		previous = floorY
		table.insert(waypoints, { T = t, Floor = floorY })
	end
	if not best or best < settings.MinDistance then
		return nil, nil, nil
	end
	return best, bestFloor, waypoints
end

-- Floor height at distance t along the waypoints (linear between samples).
function Spec.floorAt(waypoints: { Waypoint }, t: number): number
	local previous = waypoints[1]
	for index = 2, #waypoints do
		local point = waypoints[index]
		if t <= point.T then
			local span = point.T - previous.T
			local alpha = if span > 0 then math.clamp((t - previous.T) / span, 0, 1) else 1
			return previous.Floor + (point.Floor - previous.Floor) * alpha
		end
		previous = point
	end
	return previous.Floor
end

-- Dash travel: how long it takes, and the next travelled distance after dt.
function Spec.duration(distance: number, speed: number): number
	if not finite(distance) or distance <= 0 or not finite(speed) or speed <= 0 then
		return 0
	end
	return distance / speed
end

function Spec.advance(travelled: number, total: number, speed: number, dt: number): (number, boolean)
	local nextDistance = math.min(total, travelled + math.max(0, speed) * math.max(0, dt))
	return nextDistance, nextDistance >= total - 1e-6
end

-- From the targets a sweep segment touched, the ones that should fire OnImpact
-- now: each target once per rush, only the first when StopOnHit. Returns the
-- new hits and whether the dash should stop.
function Spec.impacts(candidates: { any }, alreadyHit: { [any]: boolean }, stopOnHit: boolean?): ({ any }, boolean)
	local hits = {}
	for _, target in candidates do
		if not alreadyHit[target] then
			alreadyHit[target] = true
			table.insert(hits, target)
			if stopOnHit then
				return hits, true
			end
		end
	end
	return hits, false
end

return Spec
