local Navigation = assert(loadfile("src/shared/Modules/EnemyNavigation.luau"))()
local function point(x, y, z)
	return { X = x, Y = y, Z = z }
end

-- Regression: the old horizontal-only predicate accepted this upper floor.
local ground, elevated = point(0, 0, 0), point(0, 4, 0)
assert((elevated.X - ground.X) ^ 2 + (elevated.Z - ground.Z) ^ 2 <= 2 ^ 2)
assert(not Navigation.waypointReached(ground, elevated, 2), "an upper floor is not reached from below")
assert(not Navigation.waypointReached(point(0, 8, 0), elevated, 2), "a lower floor is not reached from above")
assert(Navigation.waypointReached(point(0, 4, 0), elevated, 2))
assert(Navigation.waypointReached(point(1, 0.5, 1), ground, 2), "small floor/position error is tolerated")
assert(not Navigation.waypointReached(point(2, 0, 2), ground, 2), "tolerance is radial, not a square")

local route = {
	{ Position = point(0, 0, 0), Action = "Walk" },
	{ Position = point(0, 0, 0), Action = "Jump" },
	{ Position = point(0, 4, 0), Action = "Walk" },
	{ Position = point(6, 4, 0), Action = "Walk" },
}
assert(Navigation.nextWaypoint(route, 1, ground, 2, "Jump", 0) == 2, "do not skip unissued jump")
assert(Navigation.nextWaypoint(route, 2, ground, 2, "Jump", 2) == 3, "advance after issuing takeoff action")
assert(Navigation.nextWaypoint(route, 2, point(0, 4, 0), 2, "Jump", 2) == 4, "takeoff must not strand rising actor")
assert(Navigation.nextWaypoint(route, 3, ground, 2, "Jump", 2) == 3, "do not consume elevated landing")
assert(Navigation.nextWaypoint(route, 3, point(0, 4, 0), 2, "Jump", 2) == 4)
assert(Navigation.nextWaypoint(route, 4, point(6, 4, 0), 2, "Jump", 2) == 5)
assert(Navigation.nextWaypoint({}, 2, ground, 2, "Jump", 0) == 2, "empty/cleared path is safe")

-- Live slope regression: grounded Brute at Y=112, baked point at Y=108.566.
local lower = { { Position = point(0, 108.566, 0), Action = "Walk" } }
assert(Navigation.nextWaypoint(lower, 1, point(0, 112, 0), 2, "Jump", 0) == 1)
assert(Navigation.nextWaypoint(lower, 1, point(0, 112, 0), 2, "Jump", 0, function()
	return point(0, 112, 0)
end) == 2, "observed physical support reconciles a lower baked point")
assert(Navigation.nextWaypoint(lower, 1, point(0, 112, 0), 2, "Jump", 0, function()
	return point(0, 108.566, 0)
end) == 1, "an actual lower floor still requires descent")
assert(Navigation.nextWaypoint(lower, 1, point(5, 112, 0), 2, "Jump", 0, function()
	error("cannot project a distant point")
end) == 1)
assert(Navigation.nextWaypoint(route, 3, ground, 2, "Jump", 2, function()
	return point(0, 4, 0)
end) == 3)
assert(Navigation.nextWaypoint({ { Position = point(0, 4, 0), Action = "Jump" } }, 1, ground, 2, "Jump", 0, function()
	error("cannot project a jump action")
end) == 1)

-- Use measured hull sizes after mission ScaleTo, not fixed Basic dimensions.
for _, case in
	{
		{ Name = "Basic", Scale = 1, Radius = 2, Height = 10 },
		{ Name = "Swift", Scale = 1, Radius = 2, Height = 10 },
		{ Name = "Brute", Scale = 1.25, Radius = 3, Height = 13 },
		{ Name = "Elite", Scale = 1.5, Radius = 3, Height = 15 },
	}
do
	local offset = Navigation.r6GroundOffset(3 * case.Scale, 2 * case.Scale, 0)
	local occupiedHeight = offset + 1.5 * case.Scale + 4.5 * case.Scale
	local radius, height = Navigation.agentDimensions(2, 9, case.Scale, occupiedHeight, 2.8 * case.Scale)
	assert(radius == case.Radius and height == case.Height, case.Name .. " has body-sized integer clearance")
	assert(radius * 2 >= 2.8 * case.Scale and height >= 9 * case.Scale)
end
local radius, height = Navigation.agentDimensions(2, 9, 1, 11, 6)
assert(radius == 3 and height == 11, "actual hull is the lower bound even if scale metadata disagrees")
assert(Navigation.r6GroundOffset(3, 2, 0) == 4)
assert(Navigation.r6GroundOffset(4.5, 3, 0) == 6)
assert(Navigation.r6GroundOffset(3, 2, 0.5) == 4.5)
-- Live regression: an Elite on a one-stud curb had root Y=107 at fixture
-- ground Y=100, but its floating hull bottom was 102.5. That proxy rejected
-- the neighboring lower-floor point; the actual R6 standing reference does not.
assert(not Navigation.waypointReached(point(0, 102.5, 0), point(0, 100, 0), 2))
assert(Navigation.waypointReached(point(0, 107 - Navigation.r6GroundOffset(4.5, 3, 0), 0), point(0, 100, 0), 2))

assert(Navigation.canMoveDirectly(0, 2, false, false, false), "retain flat direct movement")
assert(Navigation.canMoveDirectly(-1.5, 2, false, false, false), "ordinary root-height differences fit")
assert(not Navigation.canMoveDirectly(4, 2, false, false, false), "clear sweep cannot bypass elevated path")
assert(not Navigation.canMoveDirectly(-4, 2, false, false, false), "descending floors also use paths")
assert(not Navigation.canMoveDirectly(0, 2, true, false, false))
assert(not Navigation.canMoveDirectly(0, 2, false, true, false))
assert(not Navigation.canMoveDirectly(0, 2, false, false, true), "direct shortcut must not cancel jump action")

-- Exercise the actual production chase closure with controlled geometry results.
-- This covers its wiring without claiming to simulate Roblox physics/path baking.
local Vector = {}
local vectorMeta = {}
function Vector.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
function vectorMeta.__sub(a, b)
	return Vector.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vectorMeta.__add(a, b)
	return Vector.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function vectorMeta.__mul(a, scalar)
	return Vector.new(a.X * scalar, a.Y * scalar, a.Z * scalar)
end
function vectorMeta.__index(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	elseif key == "Unit" then
		local magnitude = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		return Vector.new(a.X / magnitude, a.Y / magnitude, a.Z / magnitude)
	end
	return nil
end

local service = assert(io.open("src/server/Services/EnemyService.luau")):read("*a")
local first = assert(string.find(service, "\tlocal function chase(", 1, true))
local last = assert(string.find(service, "\n\ttable.insert(connections, model:GetAttributeChangedSignal", first, true))
local chaseSource = string.sub(service, first, last - 1) .. "\nreturn chase"
local function simulation(waypoints, otherPosition, blocked)
	local size = Vector.new(9, 2.8, 2.8)
	local env = {
		math = math,
		Vector3 = Vector,
		Navigation = Navigation,
		Enum = { PathWaypointAction = { Jump = "Jump" }, Material = { Air = "Air" } },
		root = { Position = Vector.new(0, 3, 0), CFrame = {} },
		hull = { Size = size },
		lastHullSize = size,
		humanoid = { FloorMaterial = "Concrete" },
		nav = {
			WaypointTolerance = 2,
			WaypointSpacing = 3,
			ProgressDistance = 0.75,
			StuckTime = 1.25,
			TargetMoveThreshold = 5,
		},
		Config = { Turning = { CloseCombatDistance = 8, CloseStandoffDistance = 2.35, PivotTurnRate = 10 } },
		waypoints = waypoints,
		waypointIndex = 2,
		issuedJumpIndex = 0,
		pathGoal = otherPosition,
		progressPosition = Vector.new(0, 3, 0),
		progressAt = 0,
		stuck = false,
		stuckRecoveries = 0,
		jumpRequests = 0,
		requestCount = 0,
		clearCount = 0,
		workspace = {
			Blockcast = function()
				return if blocked then {} else nil
			end,
		},
		rayParams = function()
			return {}
		end,
		turnToward = function() end,
		combatTurnRate = function()
			return 1
		end,
	}
	function env.navigationBody()
		return 2, 9, Vector.new(2.8, 8.5, 2.8), {}, env.root.Position - Vector.new(0, 3, 0)
	end
	function env.workspace.Raycast()
		env.supportQueries = (env.supportQueries or 0) + 1
		return env.supportHit
	end
	function env.humanoid.MoveTo(_, position)
		env.destination = position
	end
	function env.stopMoving()
		env.stopped = true
	end
	function env.clearPath()
		env.clearCount += 1
		env.waypoints, env.pathGoal, env.path, env.pendingPath = {}, nil, nil, nil
		env.waypointIndex, env.issuedJumpIndex = 1, 0
	end
	function env.requestPath()
		if env.pendingPath or env.computing then
			return
		end
		env.requestCount += 1
		env.pendingPath = true
	end
	local fn = assert(loadstring(chaseSource, "production chase regression"))
	setfenv(fn, env)
	return env, fn(), { Position = otherPosition, Parent = {} }
end

local steps = {
	{ Position = Vector.new(0, 0, 0), Action = "Walk" },
	{ Position = Vector.new(0, 4, 0), Action = "Walk" },
	{ Position = Vector.new(20, 4, 0), Action = "Walk" },
}
local env, chase, other = simulation(steps, Vector.new(20, 7, 0), false)
chase(other, 0.1, 0.1)
assert(env.waypointIndex == 2 and env.destination.Y == 4, "production chase retains an unreached upper floor")
assert(env.navigationMode == "Path", "clear elevated target cannot cancel the path")

steps[2] = { Position = Vector.new(0, 0, 0), Action = "Jump" }
env, chase, other = simulation(steps, Vector.new(20, 3, 0), false)
chase(other, 0.1, 0.1)
assert(env.waypointIndex == 2 and env.humanoid.Jump and env.jumpRequests == 1)
env.humanoid.Jump = false
chase(other, 0.2, 0.1)
assert(env.waypointIndex == 3 and not env.humanoid.Jump, "next floor remains unreached; no repeated jump request")

env, chase, other = simulation(steps, Vector.new(20, 3, 0), false)
env.humanoid.FloorMaterial = "Air"
chase(other, 0.1, 0.1)
assert(env.jumpRequests == 0 and env.issuedJumpIndex == 0, "an airborne attempt cannot consume the takeoff action")
env.humanoid.FloorMaterial = "Concrete"
chase(other, 0.2, 0.1)
assert(env.jumpRequests == 1 and env.humanoid.Jump, "issue the pending action after grounding")

steps[2] = { Position = Vector.new(20, 0, 0), Action = "Jump" }
env, chase, other = simulation(steps, Vector.new(40, 3, 0), true)
chase(other, 0.1, 0.1)
assert(not env.humanoid.Jump and env.jumpRequests == 0, "do not jump 20 studs before takeoff")
env.root.Position = Vector.new(17, 3, 0)
chase(other, 0.2, 0.1)
assert(env.humanoid.Jump and env.jumpRequests == 1, "jump when approaching the takeoff")

env, chase, other = simulation({}, Vector.new(20, 3, 0), false)
chase(other, 0.1, 0.1)
assert(env.navigationMode == "Direct" and math.abs(env.destination.X - 17.65) < 0.001)
assert(env.requestCount == 0, "flat direct chase needs no extra path jobs")
env, chase, other = simulation({}, Vector.new(2, 3, 0), false)
chase(other, 0.1, 0.1)
assert(env.stopped and not env.stuck, "preserve close melee standoff")
env, chase, other = simulation({}, Vector.new(20, 3, 0), false)
chase(other, 2, 0.1)
assert(env.stuckRecoveries == 1 and env.requestCount == 1, "stuck movement requests recovery through existing budget")

steps[2] = { Position = Vector.new(0, 108.566, 0), Action = "Walk" }
env, chase, other = simulation(steps, Vector.new(20, 115, 0), true)
env.root.Position = Vector.new(0, 115, 0)
env.supportHit = { Position = Vector.new(0, 112, 0) }
chase(other, 0.1, 0.1)
assert(env.waypointIndex == 3 and env.supportQueries == 1, "physical landing support releases a lower baked point")
env, chase, other = simulation(steps, Vector.new(20, 115, 0), true)
env.root.Position = Vector.new(0, 115, 0)
env.supportHit = { Position = Vector.new(0, 112, 0) }
env.humanoid.FloorMaterial = "Air"
chase(other, 0.1, 0.1)
assert(env.waypointIndex == 2 and not env.supportQueries, "airborne actors cannot reconcile support")

-- Compile opt-in Roblox code; no fixture/physics is executed by the CLI.
assert(loadfile("src/server/Services/EnemyService.luau"))
assert(loadfile("src/server/Development/EnemyTraversalFixture.luau"))
print("PASS: enemy navigation floor-aware waypoints, jump actions, scaled clearance and direct-chase decisions")
