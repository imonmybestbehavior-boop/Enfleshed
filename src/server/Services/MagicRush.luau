--!strict

-- World queries for the Rush Form. The rules live in MagicRushSpec; this
-- module only turns them into raycasts and positions. Checks mirror
-- displaceTarget (MagicPayloadExecutors): a wall ray at root height, a ground
-- ray from 8 studs above down 24, a walkable normal, a step limit, clearance.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Limits = require(Shared.Configuration.MagicLab)
local RushSpec = require(Shared.Modules.MagicRushSpec)

local Rush = {}

export type Path = {
	Origin: Vector3, -- root position at the start
	Direction: Vector3, -- horizontal unit
	Distance: number, -- travelled distance (after safety checks)
	RootOffset: number, -- root height above the floor
	Waypoints: { RushSpec.Waypoint },
	Destination: Vector3, -- root position at the end
}

local settings: RushSpec.Settings = {
	SampleStep = Limits.RushSampleStep,
	WallPadding = Limits.RushWallPadding,
	MaxStepHeight = Limits.RushMaxStepHeight,
	MinGroundNormalY = Limits.RushMinGroundNormalY,
	MinDistance = Limits.RushMinDistance,
}

local function horizontal(direction: Vector3): Vector3?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	return if flat.Magnitude > 0.001 then flat.Unit else nil
end

-- Parts of other characters do not block the path (a Dash passes through
-- them); scenery does.
local function blocksStanding(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return not (model and model:FindFirstChildOfClass("Humanoid"))
end

function Rush.plan(character: Model, humanoid: Humanoid, root: BasePart, aim: Vector3, distance: number): Path?
	local direction = horizontal(aim)
	if not direction or distance <= 0 then
		return nil
	end
	local origin = root.Position
	local rootOffset = humanoid.HipHeight + root.Size.Y * 0.5
	-- Characters never count as walls or floor: casts skip past them.
	local ignored: { Instance } = { character }
	local function cast(from: Vector3, delta: Vector3): RaycastResult?
		for _ = 1, 6 do
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignored
			params.RespectCanCollide = true
			local hit = workspace:Raycast(from, delta, params)
			if not hit or blocksStanding(hit.Instance :: BasePart) then
				return hit
			end
			table.insert(ignored, (hit.Instance :: Instance):FindFirstAncestorOfClass("Model") :: Instance)
		end
		return nil
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	local _, extents = character:GetBoundingBox()
	local clearanceSize =
		Vector3.new(math.clamp(extents.X, 2, 8), math.clamp(extents.Y, 4, 12), math.clamp(extents.Z, 2, 8))
	local function pointAt(t: number): Vector3
		return origin + direction * t
	end
	local probes = {
		wall = function(length: number): number?
			local hit = cast(origin, direction * length)
			return if hit then hit.Distance else nil
		end,
		floor = function(t: number): (number?, number?)
			local hit = cast(pointAt(t) + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0))
			if not hit then
				return nil, nil
			end
			return hit.Position.Y, hit.Normal.Y
		end,
		clear = function(t: number, floorY: number): boolean
			local at = pointAt(t)
			local center = Vector3.new(at.X, floorY + rootOffset, at.Z)
			for _, part in workspace:GetPartBoundsInBox(CFrame.new(center), clearanceSize, overlap) do
				if blocksStanding(part) then
					return false
				end
			end
			return true
		end,
	}
	local startFloor = origin.Y - rootOffset
	local travelled, floorY, waypoints = RushSpec.plan(distance, startFloor, probes, settings)
	if not travelled or not floorY or not waypoints then
		return nil
	end
	local finish = pointAt(travelled)
	return {
		Origin = origin,
		Direction = direction,
		Distance = travelled,
		RootOffset = rootOffset,
		Waypoints = waypoints,
		Destination = Vector3.new(finish.X, floorY + rootOffset, finish.Z),
	}
end

-- Root position after travelling t studs along the path (follows the floor).
function Rush.positionAt(path: Path, t: number): Vector3
	local clamped = math.clamp(t, 0, path.Distance)
	local at = path.Origin + path.Direction * clamped
	return Vector3.new(at.X, RushSpec.floorAt(path.Waypoints, clamped) + path.RootOffset, at.Z)
end

-- Sphere centers that cover the segment for a capsule sweep of `radius`.
function Rush.sweepCenters(from: Vector3, to: Vector3, radius: number): { Vector3 }
	local delta = to - from
	local length = delta.Magnitude
	local count = math.max(1, math.ceil(length / math.max(0.5, radius)))
	local centers = {}
	for index = 1, count do
		table.insert(centers, from + delta * (index / count))
	end
	return centers
end

-- Moves the root to `position`, facing along the rush, keeping vertical speed.
function Rush.place(root: BasePart, position: Vector3, direction: Vector3, speed: number)
	root.CFrame = CFrame.lookAt(position, position + direction)
	local vertical = root.AssemblyLinearVelocity.Y
	root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, math.min(0, vertical), direction.Z * speed)
end

return Rush
