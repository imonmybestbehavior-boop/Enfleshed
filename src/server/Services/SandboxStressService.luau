--!strict

-- Temporary wave/performance harness. No persistence, rewards, or difficulty scaling.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Topology = require(Shared:WaitForChild("Configuration"):WaitForChild("PhaseATopology"))
local Config = Sandbox.StressTest
local Enemy = require(script.Parent.EnemyService)
local StressTest = {}
local COLLISION_GROUP = "SandboxStressEnemies"

type Entry = { Handle: Enemy.Handle, Alive: boolean, RemoveAt: number }

function StressTest.start()
	assert(not workspace:FindFirstChild("SandboxStressTest"), "Sandbox stress test already running")
	assert(#Config.WaveSizes > 0, "Configure at least one wave")
	assert(Config.PathStartsPerSecond > 0 and Config.MaxPathsInFlight >= 1, "Invalid path budget")
	assert(Config.MaxPathsInFlight % 1 == 0 and Config.HitQueryRate > 0, "Invalid path concurrency/hit rate")
	assert(Config.MinSpawnSpacing > 0 and Config.SpawnCandidateMinimumDistance > 0, "Invalid spawn layout")
	assert(Config.SpawnCandidateMaximumDistance > Config.SpawnCandidateMinimumDistance, "Invalid spawn distance range")
	assert(Config.InterWaveDelay >= 0 and Config.CorpseLifetime >= 0, "Invalid wave timing")
	for _, count in Config.WaveSizes do
		assert(count >= 1 and count % 1 == 0, "Wave sizes must be positive integers")
	end
	if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, Config.EnemyCollisions)
	-- Roblox characters and the baseplate retain Default: body-blocking players is intentional.
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, "Default", true)
	local visuals = Sandbox.Enemy.VisualCollisionGroup
	local query = Sandbox.Combat.OverlapCollisionGroup
	for _, group in { visuals, query } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	-- Only the hull blocks physical movement, even if Humanoid toggles a limb's CanCollide.
	PhysicsService:CollisionGroupSetCollidable(visuals, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(visuals, COLLISION_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(visuals, visuals, false)
	-- Attack overlaps see the normal rig, not the taller anti-climb hull.
	PhysicsService:CollisionGroupSetCollidable(query, "Default", true)
	PhysicsService:CollisionGroupSetCollidable(query, visuals, true)
	PhysicsService:CollisionGroupSetCollidable(query, COLLISION_GROUP, false)

	local folder = Instance.new("Folder")
	folder.Name = "SandboxStressTest"
	local enemies = Instance.new("Folder")
	enemies.Name = "Enemies"
	enemies.Parent = folder
	local entries: { Entry } = {}
	local wave, living = 0, 0
	local phase = "Waiting"
	local nextWaveAt = os.clock()
	local nextPathStart = 0
	local inFlight, startedPaths, pathCursor = 0, 0, 0
	local nextMetrics = 0
	local stopped = false
	local heartbeat: RBXScriptConnection? = nil
	local destroying: RBXScriptConnection? = nil

	local function publish()
		folder:SetAttribute("Wave", wave)
		folder:SetAttribute("TotalWaves", #Config.WaveSizes)
		folder:SetAttribute("LivingEnemies", living)
		folder:SetAttribute("Status", phase)
		folder:SetAttribute("NextWaveAt", workspace:GetServerTimeNow() + math.max(0, nextWaveAt - os.clock()))
	end
	publish()
	folder:SetAttribute("PathsInFlight", 0)
	folder:SetAttribute("PathsStarted", 0)
	folder:SetAttribute("PendingPaths", 0)
	folder.Parent = workspace

	local function clearWave()
		for _, entry in entries do
			entry.Handle.Destroy()
		end
		table.clear(entries)
		pathCursor = 0
	end

	local candidateCursor = 0
	local function positions(count: number): { Vector3 }?
		local protected = { Sandbox.Dummy.Position }
		local spawn = workspace:FindFirstChild("SandboxSpawn")
		if spawn and spawn:IsA("BasePart") then
			table.insert(protected, spawn.Position)
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				table.insert(protected, root.Position)
			end
		end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { folder }
		overlap.RespectCanCollide = true
		local graybox = workspace:FindFirstChild("LowerLayerGraybox")
		local debugFolder = if graybox then graybox:FindFirstChild("Debug") else nil
		local function groundedPosition(candidate: Vector3): Vector3?
			if not graybox then
				return nil
			end
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { folder }
			ray.RespectCanCollide = true
			-- Probe around the authored route height. The old 140-stud probe began
			-- above the surface and therefore hit it before an underground floor.
			local origin = candidate + Vector3.new(0, Config.GroundProbeHeight, 0)
			local hit = workspace:Raycast(origin, Vector3.new(0, -Config.GroundProbeDistance, 0), ray)
			if
				not hit
				or hit.Normal.Y < 0.9
				or not hit.Instance:IsDescendantOf(graybox)
				or (debugFolder and hit.Instance:IsDescendantOf(debugFolder))
			then
				return nil
			end
			local rootHeight = Sandbox.Enemy.CollisionHull.Height / 2 - Sandbox.Enemy.CollisionHull.CenterOffsetY
			return hit.Position + Vector3.new(0, rootHeight + Config.GroundClearance, 0)
		end
		local available: { { Position: Vector3, Score: number } } = {}
		for _, candidate in Topology.SpawnCandidates do
			local source = (candidate.Position or Topology.Nodes[candidate.Node]) + candidate.Offset
			local position = groundedPosition(source)
			if position then
				local closest = math.huge
				for _, point in protected do
					local delta = position - point
					closest = math.min(closest, Vector3.new(delta.X, 0, delta.Z).Magnitude)
				end
				local valid = closest >= math.max(Config.SpawnCandidateMinimumDistance, Config.SpawnClearance)
					and closest <= Config.SpawnCandidateMaximumDistance
				if
					valid
					and #workspace:GetPartBoundsInBox(
							CFrame.new(position + Vector3.new(0, Sandbox.Enemy.CollisionHull.CenterOffsetY, 0)),
							Vector3.new(5, Sandbox.Enemy.CollisionHull.Height - 0.2, 5),
							overlap
						)
						> 0
				then
					valid = false
				end
				if valid then
					table.insert(available, { Position = position, Score = closest })
				end
			end
		end
		table.sort(available, function(left, right)
			return left.Score < right.Score
		end)
		local result: { Vector3 } = {}
		if #available > 0 then
			candidateCursor = candidateCursor % #available
			for offset = 1, #available do
				local candidate = available[(candidateCursor + offset - 1) % #available + 1]
				local spaced = true
				for _, chosen in result do
					if (candidate.Position - chosen).Magnitude < Config.MinSpawnSpacing then
						spaced = false
						break
					end
				end
				if spaced then
					table.insert(result, candidate.Position)
					if #result == count then
						candidateCursor += offset
						return result
					end
				end
			end
		end
		return nil -- Candidates retry later instead of placing enemies inside characters/walls.
	end

	local function startWave(now: number)
		clearWave()
		local locations = positions(Config.WaveSizes[wave + 1])
		if not locations then
			phase = "Blocked"
			nextWaveAt = now + math.max(1, Config.InterWaveDelay)
			publish()
			return
		end
		wave += 1
		for index, position in locations do
			local handle = Enemy.create(
				position,
				enemies,
				COLLISION_GROUP,
				(index - 1) * Sandbox.Enemy.ThinkInterval / #locations,
				1 / Config.HitQueryRate
			)
			handle.Model.Name = string.format("Enfleshed_W%d_%02d", wave, index)
			handle.Model:SetAttribute("SandboxLabel", string.format("Enfleshed %02d", index))
			table.insert(entries, { Handle = handle, Alive = true, RemoveAt = math.huge })
		end
		living = #entries
		phase = "Active"
		publish()
	end

	destroying = folder.Destroying:Connect(function()
		stopped = true
		if heartbeat then
			heartbeat:Disconnect()
		end
		clearWave()
		if destroying then
			destroying:Disconnect()
		end
	end)

	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local changed = false
		for _, entry in entries do
			if entry.Alive then
				entry.Handle.Update(now)
				if not entry.Handle.IsAlive() then
					entry.Alive = false
					entry.RemoveAt = now + Config.CorpseLifetime
					living -= 1
					changed = true
				end
			elseif now >= entry.RemoveAt then
				entry.Handle.Destroy()
				entry.RemoveAt = math.huge
			end
		end
		if phase == "Active" and living == 0 then
			phase = if wave == #Config.WaveSizes then "Complete" else "Waiting"
			nextWaveAt = now + Config.InterWaveDelay
			changed = true
		end
		if changed then
			publish()
		end
		if (phase == "Waiting" or phase == "Blocked") and now >= nextWaveAt then
			startWave(now)
		end

		-- Round-robin admission: no catch-up burst after a slow frame, and no per-enemy coroutines waiting for slots.
		if phase == "Active" and now >= nextPathStart and inFlight < Config.MaxPathsInFlight then
			for _ = 1, #entries do
				pathCursor = pathCursor % #entries + 1
				local entry = entries[pathCursor]
				local job = if entry.Alive then entry.Handle.TakePathJob() else nil
				if job then
					inFlight += 1
					startedPaths += 1
					nextPathStart = now + 1 / Config.PathStartsPerSecond
					task.spawn(function()
						local ok, err = pcall(job)
						inFlight -= 1
						if not ok then
							warn("Sandbox path computation failed: " .. tostring(err))
						end
						if not stopped then
							folder:SetAttribute("PathsInFlight", inFlight)
						end
					end)
					break
				end
			end
		end
		if now >= nextMetrics then
			nextMetrics = now + Sandbox.Enemy.ThinkInterval
			local pending = 0
			for _, entry in entries do
				if entry.Alive and entry.Handle.HasPendingPath() then
					pending += 1
				end
			end
			folder:SetAttribute("PendingPaths", pending)
			folder:SetAttribute("PathsInFlight", inFlight)
			folder:SetAttribute("PathsStarted", startedPaths)
		end
		if phase == "Complete" then
			local corpsesRemain = false
			for _, entry in entries do
				if entry.RemoveAt < math.huge then
					corpsesRemain = true
					break
				end
			end
			if not corpsesRemain then
				clearWave()
				if heartbeat then
					heartbeat:Disconnect()
				end
			end
		end
	end)
end

return StressTest
