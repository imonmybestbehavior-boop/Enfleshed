--!strict

-- Composable, spell-neutral behaviors for the Projectile Form. Definitions are
-- validated data; this registry owns steering and impact continuation rules.
local Behaviors = {}

local executors: { [string]: any } = {}

executors.Proximity = {
	Spawn = function(projectile, behavior, context)
		projectile.NextProximityCheckAt = context.Now + behavior.Interval
		projectile.ProximityTargets = {}
		projectile.ProximityTargetCount = 0
	end,
	Update = function(projectile, behavior, _delta, context)
		if
			context.Now < (projectile.NextProximityCheckAt or math.huge)
			or (projectile.ProximityTargetCount or 0) >= behavior.MaxTargets
		then
			return
		end
		projectile.NextProximityCheckAt = context.Now + behavior.Interval
		local remaining = behavior.MaxTargets - (projectile.ProximityTargetCount or 0)
		local targets = context.FindProximityTargets(projectile, behavior.Radius, remaining)
		for _, humanoid in ipairs(targets) do
			if not projectile.ProximityTargets[humanoid] then
				projectile.ProximityTargets[humanoid] = true
				projectile.ProximityTargetCount += 1
				projectile.CurrentPhase = "Proximity"
				context.OnProximity(projectile, humanoid)
				projectile.CurrentPhase = "Traveling"
			end
		end
	end,
}

executors.Absorb = {
	Update = function(projectile, behavior, _delta, context)
		local now = context.Now
		if now < (projectile.NextAbsorbCheckAt or 0) or (projectile.AbsorbCount or 0) >= behavior.MaxAbsorbed then
			return
		end
		projectile.NextAbsorbCheckAt = now + behavior.CheckInterval
		local incoming = context.FindIncomingProjectile(projectile, behavior.Radius)
		if not incoming then
			return
		end
		incoming.AbsorbedBy = projectile
		projectile.AbsorbCount = (projectile.AbsorbCount or 0) + 1
		projectile.AbsorbedEnergy = (projectile.AbsorbedEnergy or 0) + 1
		projectile.PotencyMultiplier =
			math.min(behavior.MaxPotencyMultiplier, (projectile.PotencyMultiplier or 1) + behavior.PowerPerAbsorption)
		context.ShowAbsorption(projectile, incoming)
	end,
}

executors.Reflect = {
	Update = function(projectile, behavior, _delta, context)
		local now = context.Now
		if now < (projectile.NextReflectCheckAt or 0) or (projectile.ReflectCount or 0) >= behavior.MaxReflections then
			return
		end
		projectile.NextReflectCheckAt = now + behavior.CheckInterval
		local incoming = context.FindIncomingProjectile(projectile, behavior.Radius, behavior.MaxHopsPerProjectile)
		if not incoming or not context.ReflectProjectile(projectile, incoming) then
			return
		end
		projectile.ReflectCount = (projectile.ReflectCount or 0) + 1
		context.ShowReflection(projectile, incoming)
	end,
}

executors.Pulse = {
	Spawn = function(projectile, behavior, context)
		projectile.NextPulseAt = context.Now + behavior.Interval
	end,
	Update = function(projectile, behavior, _delta, context)
		if context.Now < (projectile.NextPulseAt or math.huge) then
			return
		end
		projectile.NextPulseAt = context.Now + behavior.Interval
		context.Pulse(projectile, behavior)
	end,
}

executors.Homing = {
	Update = function(projectile, behavior, delta, context)
		local target = projectile.HomingTarget
		local humanoid = target and target.Parent and target.Parent:FindFirstChildOfClass("Humanoid")
		local hitTargets = projectile.HitHumanoids or {}
		if not humanoid or humanoid.Health <= 0 or hitTargets[humanoid] then
			target = nil
			projectile.HomingTarget = nil
		end
		local now = os.clock()
		if not target and not projectile.FixedTarget and now >= (projectile.NextHomingScan or 0) then
			projectile.NextHomingScan = now + 0.15
			projectile.HomingTarget = context.FindTarget(projectile, behavior.SearchRadius)
			target = projectile.HomingTarget
		end
		local root = target and target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local offset = root.Position - projectile.Position
		if offset.Magnitude < 0.001 then
			return
		end
		local current = projectile.Velocity.Unit
		local desired = offset.Unit
		local dot = math.clamp(current:Dot(desired), -1, 1)
		local angle = math.acos(dot)
		if angle < 0.001 then
			projectile.Direction = desired
			return
		end
		local axis = current:Cross(desired)
		if axis.Magnitude < 0.001 then
			axis = current:Cross(Vector3.yAxis)
			if axis.Magnitude < 0.001 then
				axis = current:Cross(Vector3.xAxis)
			end
		end
		local turn = math.min(angle, math.rad(behavior.TurnRate) * math.min(delta, 0.1))
		local direction = CFrame.fromAxisAngle(axis.Unit, turn):VectorToWorldSpace(current).Unit
		local speed = projectile.Velocity.Magnitude
		projectile.Direction = direction
		projectile.Velocity = direction * speed
	end,
}

executors.Pierce = {
	Impact = function(projectile, behavior, hit, context)
		local humanoid, model = context.TargetFromHit(hit)
		if not humanoid or not model then
			return false
		end
		local pierced = projectile.PierceCount or 0
		if pierced >= behavior.MaxPierces then
			return false
		end
		projectile.PierceCount = pierced + 1
		projectile.IgnoredTargetModels = projectile.IgnoredTargetModels or {}
		table.insert(projectile.IgnoredTargetModels, model)
		return true
	end,
}

executors.Chain = {
	Impact = function(projectile, behavior, hit, context)
		local humanoid = context.TargetFromHit(hit)
		if not humanoid then
			return false
		end
		projectile.HitHumanoids = projectile.HitHumanoids or {}
		projectile.HitHumanoids[humanoid] = true
		local from = hit.Position
		for jump = 1, behavior.MaxJumps do
			local nextTarget = context.FindTargetAt(projectile, from, behavior.Radius)
			if not nextTarget then
				break
			end
			local model = nextTarget.Parent
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if not model or not root or not root:IsA("BasePart") then
				break
			end
			projectile.HitHumanoids[nextTarget] = true
			projectile.IgnoredTargetModels = projectile.IgnoredTargetModels or {}
			table.insert(projectile.IgnoredTargetModels, model)
			local endpoint = root.Position + Vector3.new(0, 1, 0)
			context.Link(from, endpoint)
			context.ApplyImpact(projectile, nextTarget, endpoint, behavior.DamageFalloff ^ jump)
			from = endpoint
		end
		return false
	end,
}

executors.Propagate = {
	Impact = function(projectile, behavior, hit, context)
		local primaryTarget = context.TargetFromHit(hit)
		projectile.HitHumanoids = projectile.HitHumanoids or {}
		if primaryTarget then
			projectile.HitHumanoids[primaryTarget] = true
		end
		local targets = context.FindTargetsAt(projectile, hit.Position, behavior.Radius, behavior.MaxTargets)
		for index, humanoid in ipairs(targets) do
			projectile.HitHumanoids[humanoid] = true
			local model = humanoid.Parent
			if model then
				projectile.IgnoredTargetModels = projectile.IgnoredTargetModels or {}
				table.insert(projectile.IgnoredTargetModels, model)
			end
			local root = model and model:FindFirstChild("HumanoidRootPart")
			local position = if root and root:IsA("BasePart") then root.Position else hit.Position
			context.ApplyImpact(projectile, humanoid, position, behavior.PayloadFalloff ^ index)
		end
		return false
	end,
}

executors.Bounce = {
	Impact = function(projectile, behavior, hit, context)
		local humanoid = context.TargetFromHit(hit)
		local normal = hit.Normal
		if humanoid or typeof(normal) ~= "Vector3" or normal.Magnitude < 0.001 then
			return false
		end

		local bounceCount = projectile.BounceCount or 0
		if bounceCount >= behavior.MaxBounces then
			return false
		end
		local velocity = projectile.Velocity
		if velocity.Magnitude < 0.001 then
			return false
		end

		local normalUnit = normal.Unit
		local reflected = velocity - 2 * velocity:Dot(normalUnit) * normalUnit
		if reflected.Magnitude < 0.001 then
			return false
		end
		projectile.BounceCount = bounceCount + 1
		projectile.Velocity = reflected.Unit * velocity.Magnitude * behavior.Restitution
		projectile.Direction = projectile.Velocity.Unit
		return true
	end,
}

executors.Split = {
	Impact = function(projectile, behavior, hit, context)
		if (projectile.SplitDepth or 0) > 0 then
			return false
		end
		local normal = hit.Normal
		if typeof(normal) ~= "Vector3" or normal.Magnitude < 0.001 then
			return false
		end

		local forward = projectile.Direction.Unit
		local rotationAxis = Vector3.yAxis
		if math.abs(forward:Dot(rotationAxis)) > 0.95 then
			rotationAxis = Vector3.xAxis
		end
		local _, hitModel = context.TargetFromHit(hit)
		local ignoredTargets = table.clone(projectile.IgnoredTargetModels or {})
		if hitModel and not table.find(ignoredTargets, hitModel) then
			table.insert(ignoredTargets, hitModel)
		end
		local directions = {}
		local halfAngle = math.rad(behavior.SpreadAngle) / 2
		for index = 1, behavior.ChildCount do
			local alpha = (index - 1) / (behavior.ChildCount - 1) * 2 - 1
			local angle = alpha * halfAngle
			local direction = CFrame.fromAxisAngle(rotationAxis, angle):VectorToWorldSpace(forward).Unit
			table.insert(directions, direction)
		end

		if context.SpawnSplit(projectile, hit, behavior, directions, ignoredTargets) then
			projectile.TerminateAfterImpact = true
		end
		return false
	end,
}

executors.Spread = {
	Spawn = function(projectile, behavior, context)
		for pair = 1, behavior.SidePairs do
			local angle = behavior.SpreadAngle * pair
			if not context.SpawnSpread(projectile, behavior, pair, -angle) then
				return
			end
			if not context.SpawnSpread(projectile, behavior, pair, angle) then
				return
			end
		end
	end,
}

executors.Linger = {
	Impact = function(projectile, behavior, hit, context)
		if projectile.Kind ~= "Projectile" then
			return false
		end
		projectile.Kind = "ProjectileLinger"
		projectile.CurrentPhase = "Lingering"
		projectile.Position = projectile.Position
		projectile.Velocity = Vector3.zero
		projectile.LingerRadius = behavior.Radius
		projectile.LingerInterval = behavior.Interval
		projectile.RemainingLifetime = behavior.Duration
		projectile.NextInterval = context.Now + behavior.Interval
		if projectile.MotionPhaseMode == "Attached" and hit.Instance:IsA("BasePart") then
			projectile.AttachedPart = hit.Instance
			projectile.AttachedOffset = hit.Instance.CFrame:PointToObjectSpace(projectile.Position)
		end
		return false
	end,
}

executors.Return = {
	Update = function(projectile, behavior, delta, context)
		if not projectile.Returning and projectile.Distance >= behavior.ReturnAtDistance then
			projectile.Returning = true
			projectile.CurrentPhase = "Returning"
		end
		if not projectile.Returning then
			return
		end

		local target = context.ReturnTargetPosition(projectile)
		if not target then
			projectile.ReturnEnded = true
			return
		end
		local offset = target - projectile.Position
		if offset.Magnitude <= behavior.CatchRadius then
			projectile.ReturnEnded = true
			return
		end
		if projectile.Velocity.Magnitude < 0.001 then
			projectile.Velocity = offset.Unit * projectile.BaseSpeed
			projectile.Direction = offset.Unit
			return
		end

		local current = projectile.Velocity.Unit
		local desired = offset.Unit
		local dot = math.clamp(current:Dot(desired), -1, 1)
		local angle = math.acos(dot)
		if angle < 0.001 then
			projectile.Direction = desired
			return
		end
		local axis = current:Cross(desired)
		if axis.Magnitude < 0.001 then
			axis = current:Cross(Vector3.yAxis)
			if axis.Magnitude < 0.001 then
				axis = current:Cross(Vector3.xAxis)
			end
		end
		local turn = math.min(angle, math.rad(behavior.TurnRate) * math.min(delta, 0.1))
		local direction = CFrame.fromAxisAngle(axis.Unit, turn):VectorToWorldSpace(current).Unit
		projectile.Direction = direction
		projectile.Velocity = direction * math.max(projectile.Velocity.Magnitude, projectile.BaseSpeed)
	end,
}

function Behaviors.update(projectile, delta, context)
	for _, behavior in ipairs(projectile.Definition.Projectile.Behaviors or {}) do
		local executor = executors[behavior.Kind]
		if executor and executor.Update then
			executor.Update(projectile, behavior, delta, context)
		end
	end
end

function Behaviors.spawn(projectile, context)
	for _, behavior in ipairs(projectile.Definition.Projectile.Behaviors or {}) do
		local executor = executors[behavior.Kind]
		if executor and executor.Spawn then
			executor.Spawn(projectile, behavior, context)
		end
	end
end

function Behaviors.impact(projectile, hit, context): boolean
	local continue = false
	for _, behavior in ipairs(projectile.Definition.Projectile.Behaviors or {}) do
		if behavior.Kind == "Linger" then
			continue
		end
		local executor = executors[behavior.Kind]
		if executor and executor.Impact and executor.Impact(projectile, behavior, hit, context) then
			continue = true
		end
	end
	if projectile.TerminateAfterImpact then
		return false
	end
	for _, behavior in ipairs(projectile.Definition.Projectile.Behaviors or {}) do
		if behavior.Kind == "Linger" then
			executors.Linger.Impact(projectile, behavior, hit, context)
			return false
		end
	end
	return continue and not projectile.TerminateAfterImpact
end

return Behaviors
