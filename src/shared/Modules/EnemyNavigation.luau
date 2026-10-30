--!strict
-- Geometry and waypoint decisions only. No combat tuning or Roblox services.
local Navigation = {}

export type Point = { X: number, Y: number, Z: number } | Vector3

function Navigation.r6GroundOffset(legHeight: number, rootHeight: number, hipHeight: number): number
	-- R6 standing height, not the bottom of a separately welded collision hull.
	return legHeight + rootHeight / 2 + hipHeight
end

function Navigation.agentDimensions(
	radius: number,
	height: number,
	scale: number,
	occupiedHeight: number,
	hullDiameter: number
): (number, number)
	-- CreatePath's dimensions are integer clearances. Keep the original margin,
	-- scale it with the body, and never describe an agent smaller than its hull.
	return math.ceil(math.max(radius * scale, hullDiameter / 2)), math.ceil(math.max(height * scale, occupiedHeight))
end

function Navigation.waypointReached(ground: Point, waypoint: Point, tolerance: number): boolean
	local x, z = waypoint.X - ground.X, waypoint.Z - ground.Z
	return x * x + z * z <= tolerance * tolerance and math.abs(waypoint.Y - ground.Y) <= tolerance
end

function Navigation.nextWaypoint(
	waypoints: { any },
	index: number,
	ground: Point,
	tolerance: number,
	jumpAction: any,
	issuedJumpIndex: number,
	supportAt: ((Point) -> Point?)?
): number
	while waypoints[index] do
		local waypoint = waypoints[index]
		local jump = waypoint.Action == jumpAction
		-- Jump is an action at the waypoint, not permission to skip it because
		-- its X/Z is already close. Issue it at least once before advancing.
		if jump and issuedJumpIndex ~= index then
			break
		end
		-- An issued takeoff action can be consumed while rising above its
		-- original floor. The following landing/walk point still checks height.
		local atPoint = if jump
			then Navigation.waypointReached(
				{ X = ground.X, Y = waypoint.Position.Y, Z = ground.Z },
				waypoint.Position,
				tolerance
			)
			else Navigation.waypointReached(ground, waypoint.Position, tolerance)
		-- Baked walk points can differ from physical ramp/landing surfaces.
		-- Reconcile only at their X/Z against observed support; an actual upper
		-- floor still fails the height check. Never project jump actions.
		if
			not atPoint
			and not jump
			and supportAt
			and Navigation.waypointReached(
				ground,
				{ X = waypoint.Position.X, Y = ground.Y, Z = waypoint.Position.Z },
				tolerance
			)
		then
			local support = supportAt(waypoint.Position)
			atPoint = support ~= nil and Navigation.waypointReached(ground, support, tolerance)
		end
		if not atPoint then
			break
		end
		index += 1
	end
	return index
end

function Navigation.canMoveDirectly(
	heightDelta: number,
	tolerance: number,
	blocked: boolean,
	stuck: boolean,
	jumpPending: boolean
): boolean
	-- A clear body sweep is not proof that an elevated destination can be
	-- walked to. Let the existing path/jump handling resolve that case.
	return not blocked and not stuck and not jumpPending and math.abs(heightDelta) <= tolerance
end

return Navigation
