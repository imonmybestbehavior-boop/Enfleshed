--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Plan = require(Shared.Configuration.PhaseATopology)
local Config = require(Shared.Configuration.Sandbox)
local World = require(Shared.Configuration.LowerLayerGraybox)
local Locations = require(Shared.Configuration.AssignmentLocations)
local Spawn = {}

function Spawn.safe(point: Vector3, radius: number): boolean
	return (point - World.PhaseA.RecruitSpawn).Magnitude >= radius
		and (point - Locations.Barracks_Main.Position).Magnitude >= radius
		and (point - Plan.Nodes.B1).Magnitude >= radius
end

function Spawn.ground(point: Vector3, height: number?, width: number?): Vector3?
	local geometry = workspace:FindFirstChild("LowerLayerGraybox")
	if not geometry then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { geometry }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(point + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), params)
	if not hit or hit.Normal.Y < 0.9 then
		return nil
	end
	local h = height or Config.Enemy.CollisionHull.Height
	local w = width or Config.Enemy.CollisionHull.Diameter
	local overlap = OverlapParams.new()
	overlap.RespectCanCollide = true
	local center = hit.Position + Vector3.new(0, h / 2 + 0.15, 0)
	if #workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(w, h - 0.1, w), overlap) > 0 then
		return nil
	end
	return hit.Position + Vector3.new(0, 3.1, 0)
end

function Spawn.players(): { BasePart }
	local roots = {}
	for _, player in game:GetService("Players"):GetPlayers() do
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("OpeningComplete") and h and h.Health > 0 and r and r:IsA("BasePart") then
			table.insert(roots, r)
		end
	end
	return roots
end

function Spawn.find(
	center: Vector3,
	radius: number,
	minimum: number,
	safeRadius: number,
	reserved: { Vector3 }
): Vector3?
	local roots = Spawn.players()
	local fallback = nil
	for _, candidate in Plan.SpawnCandidates do
		local point = (candidate.Position or Plan.Nodes[candidate.Node]) + candidate.Offset
		if (point - center).Magnitude > radius or not Spawn.safe(point, safeRadius) then
			continue
		end
		local valid, hidden = true, true
		for _, p in reserved do
			if (point - p).Magnitude < 8 then
				valid = false
			end
		end
		for _, root in roots do
			if (root.Position - point).Magnitude < minimum then
				valid = false
			end
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { root.Parent }
			params.RespectCanCollide = true
			if
				not workspace:Raycast(
					root.Position + Vector3.new(0, 2, 0),
					point + Vector3.new(0, 3, 0) - (root.Position + Vector3.new(0, 2, 0)),
					params
				)
			then
				hidden = false
			end
		end
		if valid then
			local grounded = Spawn.ground(point)
			if grounded then
				if hidden then
					return grounded
				end
				fallback = fallback or grounded
			end
		end
	end
	return fallback
end
return Spawn
