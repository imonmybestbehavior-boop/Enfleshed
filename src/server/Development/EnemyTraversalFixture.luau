--!strict
-- Opt-in SERVER Command Bar fixture. Never required by production bootstrap.
-- Uses the real EnemyRuntime and its unchanged global path/hit budgets.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.Sandbox)
local Runtime = require(script.Parent.Parent.Services.EnemyRuntime)
local Fixture = {}

local ORIGIN = Vector3.new(2000, 100, 2000)
local CASES = {
	"Flat",
	"Curb",
	"RaisedEdge",
	"Stairs",
	"Ramp",
	"Slope",
	"Corner",
	"Doorway",
	"LowClearance",
	"BlockedPath",
	"MovingTarget",
}
-- Match current mission overrides; these do not change production configuration.
local KINDS = {
	Basic = { Health = 160, Speed = 18, Scale = 1 },
	Swift = { Health = 115, Speed = 22, Scale = 1 },
	Brute = { Health = 260, Speed = 13, Scale = 1.25 },
	Elite = { Health = 440, Speed = 13, Scale = 1.5 },
}
local KIND_ORDER = { "Basic", "Swift", "Brute", "Elite" }
local root: Folder? = nil
local active = false
local cancelled = false
local report: any = nil
local currentHandles: { any } = {}

local function studioOnly()
	assert(RunService:IsStudio() and RunService:IsServer(), "EnemyTraversalFixture requires a Studio server")
end

local function part(parent: Instance, name: string, size: Vector3, frame: CFrame, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.Material = Enum.Material.Concrete
	p.Color = Color3.fromRGB(115, 125, 135)
	p.Parent = parent
	return p
end

local function geometry(name: string, index: number): any
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = root
	local origin = ORIGIN + Vector3.new(0, 0, (index - 1) * 128)
	local function block(label: string, size: Vector3, offset: Vector3): Part
		return part(folder, label, size, CFrame.new(origin + offset))
	end
	block("Floor", Vector3.new(180, 2, 80), Vector3.new(80, -1, 0))
	local goalY, goalZ = 0, 0
	local blocker: Part? = nil
	if name == "Curb" then
		block("HalfStudCurb", Vector3.new(20, 0.5, 48), Vector3.new(35, 0.25, 0))
		block("OneStudCurb", Vector3.new(20, 1, 48), Vector3.new(80, 0.5, 0))
	elseif name == "RaisedEdge" then
		goalY = 4
		block("FourStudRise", Vector3.new(130, 4, 80), Vector3.new(105, 2, 0))
	elseif name == "Stairs" then
		for step = 1, 6 do
			block("Step" .. step, Vector3.new(8, step, 80), Vector3.new(28 + step * 8, step / 2, 0))
		end
		goalY = 6
		block("Landing", Vector3.new(90, 6, 80), Vector3.new(125, 3, 0))
	elseif name == "Ramp" or name == "Slope" then
		local rise = if name == "Ramp" then 6 else 12
		local run = 40
		local angle = math.atan2(rise, run)
		part(
			folder,
			name,
			Vector3.new(math.sqrt(run * run + rise * rise), 1, 80),
			CFrame.new(origin + Vector3.new(50, rise / 2 - math.cos(angle) / 2, 0)) * CFrame.Angles(0, 0, angle)
		)
		goalY = rise
		block("Landing", Vector3.new(100, rise, 80), Vector3.new(120, rise / 2, 0))
	elseif name == "Corner" then
		block("CornerA", Vector3.new(6, 20, 50), Vector3.new(55, 10, -15))
		block("CornerB", Vector3.new(30, 20, 6), Vector3.new(67, 10, 10))
		goalZ = 24
	elseif name == "Doorway" then
		block("DoorLeft", Vector3.new(6, 24, 34), Vector3.new(65, 12, -23))
		block("DoorRight", Vector3.new(6, 24, 34), Vector3.new(65, 12, 23))
		block("Lintel", Vector3.new(6, 6, 12), Vector3.new(65, 21, 0))
	elseif name == "LowClearance" then
		-- 9.5-stud central passage fits the Basic hull but not scaled bodies.
		-- There is a wider, open route at either side; not an impossible course.
		block("LowLintel", Vector3.new(16, 8, 36), Vector3.new(65, 13.5, 0))
	elseif name == "BlockedPath" then
		blocker = block("TemporaryBlocker", Vector3.new(6, 20, 56), Vector3.new(65, 10, 0))
		blocker.CanCollide = false
	end
	local goal = origin + Vector3.new(120, goalY, goalZ)
	part(folder, "Finish", Vector3.new(1, 0.1, 32), CFrame.new(goal + Vector3.new(0, 0.1, 0)), false).Color =
		Color3.fromRGB(65, 200, 100)
	return { Folder = folder, Origin = origin, Goal = goal, Blocker = blocker }
end

local function serializable(value: any): any
	if typeof(value) == "Vector3" then
		return { X = value.X, Y = value.Y, Z = value.Z }
	elseif type(value) == "table" then
		local copy = {}
		for k, v in value do
			copy[k] = serializable(v)
		end
		return copy
	end
	return value
end

local function disposeActors()
	-- Teardown only, after recording success/failure. Never used as recovery.
	for _, handle in currentHandles do
		handle.Destroy()
	end
	table.clear(currentHandles)
end

local function trial(course: any, kinds: { string }, seconds: number): any
	local actors = Instance.new("Folder")
	actors.Name = "TrialActors"
	actors.Parent = course.Folder
	local target = Instance.new("Model")
	target.Name = "NavigationGoal"
	local targetPoint = course.Goal + Vector3.new(30, 3, 0)
	local targetRoot = part(target, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(targetPoint), false)
	local targetHealth = Instance.new("Humanoid")
	targetHealth.RequiresNeck = false
	targetHealth.Parent = target
	-- No CityHuman tag: this is a navigation objective, not a combat victim.
	target.Parent = actors
	local entry: any = { Case = course.Folder.Name, Actors = {}, Samples = {}, Passed = false }
	local started = os.clock()
	for i, kind in kinds do
		local tuning = KINDS[kind]
		local offset = Vector3.new(-((i - 1) % 2) * 8, 3 * tuning.Scale + 0.2, (math.floor((i - 1) / 2) % 4 - 1.5) * 6)
		local handle = Runtime.create(course.Origin + offset, actors, kind)
		local health = handle.Model:FindFirstChildOfClass("Humanoid") :: Humanoid
		health.MaxHealth, health.Health, health.WalkSpeed = tuning.Health, tuning.Health, tuning.Speed
		if tuning.Scale ~= 1 then
			handle.Model:ScaleTo(tuning.Scale)
		end
		local order = Instance.new("ObjectValue")
		order.Name, order.Value, order.Parent = "ObjectiveTarget", target, handle.Model
		table.insert(currentHandles, handle)
		table.insert(entry.Actors, { Kind = kind, Reached = false, Died = false, GroundedSeen = false })
	end
	while not cancelled and os.clock() - started < seconds do
		local elapsed = os.clock() - started
		if course.Blocker then
			course.Blocker.CanCollide = elapsed >= 1 and elapsed < 6
		end
		if course.Folder.Name == "MovingTarget" then
			targetRoot.CFrame =
				CFrame.new(targetPoint + Vector3.new(0, 0, if math.floor(elapsed / 4) % 2 == 0 then 12 else -12))
		end
		local completed = 0
		for i, handle in currentHandles do
			local actor = entry.Actors[i]
			local sample = handle.GetNavigationDiagnostics()
			actor.GroundedSeen = actor.GroundedSeen or sample.FloorMaterial ~= "Air"
			local reached = sample.Root.X >= course.Goal.X
				and math.abs(sample.Root.Z - course.Goal.Z) <= 32
				and math.abs(sample.Ground.Y - course.Goal.Y) <= Config.Enemy.Navigation.WaypointTolerance
			if reached and not actor.Reached then
				actor.Reached, actor.ReachedAt = true, elapsed
			end
			actor.Died = actor.Died or not handle.IsAlive()
			if actor.Reached and not actor.Died and actor.GroundedSeen then
				completed += 1
			end
			table.insert(entry.Samples, {
				Elapsed = elapsed,
				Actor = i,
				BlockerClosed = course.Blocker ~= nil and course.Blocker.CanCollide,
				Navigation = serializable(sample),
			})
		end
		if completed == #currentHandles then
			entry.Passed = true
			break
		end
		task.wait(0.25)
	end
	entry.Elapsed, entry.Cancelled = os.clock() - started, cancelled
	for _, actor in entry.Actors do
		if not actor.Reached or actor.Died or not actor.GroundedSeen then
			entry.Passed = false
		end
	end
	if course.Blocker then
		course.Blocker.CanCollide = false
	end
	-- A timeout/death remains a failure in the report before actors are removed.
	disposeActors()
	actors:Destroy()
	return entry
end

function Fixture.run(options: any?): any
	studioOnly()
	assert(not active, "A traversal run is already active")
	assert(not root, "Call Fixture.clear() before starting a new report")
	options = options or {}
	local cases = options.Cases or CASES
	local kinds = options.Kinds or KIND_ORDER
	local seconds = options.Seconds or 30
	assert(type(seconds) == "number" and seconds >= 10 and seconds <= 60, "Seconds must be 10–60 per trial")
	assert(#cases > 0 and #cases <= #CASES and #kinds > 0 and #kinds <= 4, "Choose 1–11 cases and 1–4 kinds")
	for _, name in cases do
		assert(table.find(CASES, name), "Unknown traversal case: " .. tostring(name))
	end
	for _, kind in kinds do
		assert(KINDS[kind], "Unknown enemy kind: " .. tostring(kind))
	end
	active, cancelled = true, false
	root = Instance.new("Folder")
	root.Name = "EnemyTraversalFixture"
	root.Parent = workspace
	report = {
		Id = HttpService:GenerateGUID(false),
		FixtureVersion = 2,
		Status = "Running",
		Evidence = "Studio server runtime; completion is geometry-based, not stuck cleanup",
		PathStartsPerSecond = Config.StressTest.PathStartsPerSecond,
		MaxPathsInFlight = Config.StressTest.MaxPathsInFlight,
		Trials = {},
	}
	task.spawn(function()
		local ok, err = xpcall(function()
			for index, name in cases do
				if cancelled then
					break
				end
				local course = geometry(name, index)
				local groups = {}
				for _, kind in kinds do
					table.insert(groups, { kind })
				end
				if options.Crowd ~= false then
					local crowd = {}
					for _, kind in kinds do
						table.insert(crowd, kind)
						table.insert(crowd, kind)
					end
					table.insert(groups, crowd)
				end
				for _, group in groups do
					if cancelled then
						break
					end
					local result = trial(course, group, seconds)
					table.insert(report.Trials, result)
					print(
						string.format(
							"[Traversal] %s actors=%d %s %.1fs",
							name,
							#group,
							if result.Passed then "PASS" else "FAIL",
							result.Elapsed
						)
					)
				end
			end
		end, debug.traceback)
		disposeActors()
		if not ok then
			report.Error = tostring(err)
			warn(err)
		end
		report.Status = if not ok then "Error" elseif cancelled then "Cancelled" else "Finished"
		active = false
		print("[Traversal] " .. Fixture.summary())
	end)
	return { Id = report.Id, Origin = ORIGIN, Status = report.Status }
end

function Fixture.summary(): string
	studioOnly()
	if not report then
		return "No run"
	end
	local passed = 0
	for _, entry in report.Trials do
		if entry.Passed then
			passed += 1
		end
	end
	return string.format("%s: %d/%d trials passed (%s)", report.Id, passed, #report.Trials, report.Status)
end

function Fixture.report(): any
	studioOnly()
	return report
end

function Fixture.cancel()
	studioOnly()
	cancelled = true
end

function Fixture.clear()
	studioOnly()
	assert(not active, "Cancel and wait for the run to finish before clearing")
	if root then
		root:Destroy()
		root = nil
	end
	report = nil
end

return Fixture
