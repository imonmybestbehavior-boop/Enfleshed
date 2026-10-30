-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicRushSpec.luau"))()

local settings = {
	SampleStep = 2,
	WallPadding = 1.5,
	MaxStepHeight = 4,
	MinGroundNormalY = 0.55,
	MinDistance = 1,
}

-- A world described along the path: optional wall distance, floor(t), blocked spots.
local function world(options)
	return {
		wall = function()
			return options.wall
		end,
		floor = function(t)
			if options.dropAt and t >= options.dropAt then
				return nil
			end
			if options.steepAt and t >= options.steepAt then
				return 0, 0.3
			end
			return options.floor and options.floor(t) or 0, 1
		end,
		clear = function(t)
			return not (options.blockedAt and t >= options.blockedAt)
		end,
	}
end

-- Distance resolution.
assert(Spec.distance(20, 1, nil, 30) == 20)
assert(Spec.distance(20, 2, nil, 30) == 30, "hard limit")
assert(Spec.distance(20, 1, 18, 30) == 18, "PvP cap")
assert(Spec.distance(0 / 0, 1, nil, 30) == 0, "NaN distance")

-- Samples end exactly at the limit.
local samples = Spec.samples(5, 2)
assert(#samples == 3 and samples[1] == 2 and samples[2] == 4 and samples[3] == 5)
assert(#Spec.samples(0, 2) == 0)

-- Open flat ground: the full distance.
local travelled, floorY = Spec.plan(20, 0, world({}), settings)
assert(travelled == 20 and floorY == 0, "open ground travels the full distance")

-- A wall stops the rush short, with padding.
travelled = Spec.plan(20, 0, world({ wall = 10 }), settings)
assert(travelled == 8.5, "wall at 10 stops at 8.5, got " .. tostring(travelled))

-- A ledge (no floor past 7): stop at the last grounded sample.
travelled = Spec.plan(20, 0, world({ dropAt = 7 }), settings)
assert(travelled == 6, "drop past 7 stops at 6, got " .. tostring(travelled))

-- Too steep, too tall a step, no clearance: stop before them.
assert(Spec.plan(20, 0, world({ steepAt = 5 }), settings) == 4, "steep slope")
assert(Spec.plan(
	20,
	0,
	world({
		floor = function(t)
			return if t >= 9 then 6 else 0
		end,
	}),
	settings
) == 8, "a 6-stud step is a wall")
assert(Spec.plan(
	20,
	0,
	world({
		floor = function(t)
			return t * 0.5
		end,
	}),
	settings
) == 20, "a gentle ramp (1 stud per sample) is walkable")
assert(Spec.plan(20, 0, world({ blockedAt = 3 }), settings) == 2, "no clearance")

-- Nowhere to go: nil (the cast does nothing).
assert(Spec.plan(20, 0, world({ wall = 2 }), settings) == nil, "wall in your face")
assert(Spec.plan(20, 0, world({ dropAt = 1 }), settings) == nil, "standing at a ledge")
assert(Spec.plan(0, 0, world({}), settings) == nil)

-- Waypoints follow the floor for the Dash.
local _, endFloor, waypoints = Spec.plan(
	6,
	0,
	world({
		floor = function(t)
			return t * 0.5
		end,
	}),
	settings
)
assert(endFloor == 3 and #waypoints == 4 and waypoints[1].T == 0 and waypoints[4].T == 6)
assert(Spec.floorAt(waypoints, 3) == 1.5, "between samples")
assert(Spec.floorAt(waypoints, 99) == 3, "past the end")

-- Dash timing.
assert(Spec.duration(30, 60) == 0.5)
assert(Spec.duration(30, 0) == 0)
local d, done = Spec.advance(0, 10, 60, 0.1)
assert(d == 6 and not done)
d, done = Spec.advance(d, 10, 60, 0.1)
assert(d == 10 and done, "never overshoots")

-- Impacts: each target once, StopOnHit stops at the first.
local hit = {}
local hits, stop = Spec.impacts({ "a", "b" }, hit, false)
assert(#hits == 2 and not stop)
hits = Spec.impacts({ "a", "c" }, hit, false)
assert(#hits == 1 and hits[1] == "c", "already-hit targets are skipped")
hits, stop = Spec.impacts({ "x", "y" }, {}, true)
assert(#hits == 1 and hits[1] == "x" and stop, "StopOnHit")
print("Magic rush spec: distance, path plan (walls, ledges, slopes, steps, clearance), timing and impacts passed")
