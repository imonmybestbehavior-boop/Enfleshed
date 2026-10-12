--!strict
-- Shared admission/scheduling, independent from population ownership.
local Physics = game:GetService("PhysicsService")
local Run = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.Sandbox)
local Enemy = require(script.Parent.EnemyService)
local Runtime = { Group = "SandboxStressEnemies" }
local handles: { Enemy.Handle } = {}
local started, inFlight, cursor, nextPath = false, 0, 0, 0

function Runtime.start()
	if started then
		return
	end
	started = true
	local visual, query = Config.Enemy.VisualCollisionGroup, Config.Combat.OverlapCollisionGroup
	for _, group in { Runtime.Group, visual, query } do
		if not Physics:IsCollisionGroupRegistered(group) then
			Physics:RegisterCollisionGroup(group)
		end
	end
	Physics:CollisionGroupSetCollidable(Runtime.Group, Runtime.Group, Config.StressTest.EnemyCollisions)
	Physics:CollisionGroupSetCollidable(Runtime.Group, "Default", true)
	Physics:CollisionGroupSetCollidable(visual, "Default", false)
	Physics:CollisionGroupSetCollidable(visual, Runtime.Group, false)
	Physics:CollisionGroupSetCollidable(visual, visual, false)
	Physics:CollisionGroupSetCollidable(query, visual, true)
	Physics:CollisionGroupSetCollidable(query, "Default", true)
	Physics:CollisionGroupSetCollidable(query, Runtime.Group, false)
	Run.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #handles, 1, -1 do
			local handle = handles[i]
			if not handle.Model.Parent or not handle.IsAlive() then
				table.remove(handles, i)
			else
				handle.Update(now)
			end
		end
		if #handles == 0 or now < nextPath or inFlight >= Config.StressTest.MaxPathsInFlight then
			return
		end
		for _ = 1, #handles do
			cursor = cursor % #handles + 1
			local job = handles[cursor].TakePathJob()
			if job then
				inFlight += 1
				nextPath = now + 1 / Config.StressTest.PathStartsPerSecond
				task.spawn(function()
					local ok, err = pcall(job)
					inFlight -= 1
					if not ok then
						warn(err)
					end
				end)
				break
			end
		end
	end)
end

function Runtime.create(position: Vector3, folder: Folder): Enemy.Handle
	Runtime.start()
	local handle =
		Enemy.create(position, folder, Runtime.Group, (#handles % 10) * 0.01, 1 / Config.StressTest.HitQueryRate)
	table.insert(handles, handle)
	return handle
end

return Runtime
