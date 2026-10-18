--!strict
-- NPC wall guards for Defend the Walls. Spearmen hold the ground in front of their
-- gate; crossbowmen shoot from the walkway. They never respawn during a round and
-- fall back to the next wall when theirs is breached. Movement is plain MoveTo
-- (no pathfinding) and one shared Heartbeat thinks for a slice of guards per
-- frame, so a full squad stays cheap next to a three-lane wave.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.DefendTheWalls)
local Damage = require(script.Parent.DamageService)

local Guards = {}

type Guard = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Kind: string,
	Level: number,
	Post: CFrame,
	NextThink: number,
	NextAttack: number,
	Retreat: { Rally: Vector3, Until: number }?,
}

export type Squad = {
	spawn: (roundId: string) -> (),
	retreat: (fromLevel: number, toLevel: number) -> (),
	clear: () -> (),
	alive: () -> number,
	total: () -> number,
}

local tones = {
	Spearman = { Body = Color3.fromRGB(74, 82, 96), Trim = Color3.fromRGB(150, 140, 110) },
	Crossbowman = { Body = Color3.fromRGB(70, 60, 52), Trim = Color3.fromRGB(120, 40, 36) },
}

local function weld(root: BasePart, part: BasePart)
	part.Anchored, part.CanCollide, part.Massless = false, false, true
	part.CanQuery = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, part
	w.Parent = part
end

local function body(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, root.CFrame * offset, color
	p.Material = material or Enum.Material.Fabric
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	weld(root, p)
	return p
end

local function makeGuard(kind: string, post: CFrame, parent: Instance, roundId: string): (Model, BasePart, Humanoid)
	local tune = Config.Guards[kind]
	local tone = tones[kind]
	local model = Instance.new("Model")
	model.Name = "Guard_" .. kind
	local root = Instance.new("Part")
	root.Name, root.Size, root.CFrame = "HumanoidRootPart", Vector3.new(2, 2, 1), post
	root.Transparency, root.CanCollide = 1, true
	root.Parent = model
	body(model, root, "Torso", Vector3.new(2, 2, 1), CFrame.new(), tone.Body, Enum.Material.Metal)
	body(model, root, "Tabard", Vector3.new(1.4, 2.4, 1.1), CFrame.new(0, -0.3, 0), tone.Trim)
	body(model, root, "Legs", Vector3.new(1.8, 2, 0.9), CFrame.new(0, -2, 0), Color3.fromRGB(40, 36, 34))
	body(
		model,
		root,
		"Head",
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(0, 1.6, 0),
		Color3.fromRGB(176, 150, 128),
		Enum.Material.SmoothPlastic
	)
	body(
		model,
		root,
		"Helm",
		Vector3.new(1.4, 0.8, 1.4),
		CFrame.new(0, 2.05, 0),
		Color3.fromRGB(90, 94, 100),
		Enum.Material.Metal
	)
	if kind == "Spearman" then
		body(
			model,
			root,
			"Spear",
			Vector3.new(0.25, 0.25, 9),
			CFrame.new(1.2, 0.2, -2.5),
			Color3.fromRGB(70, 52, 36),
			Enum.Material.Wood
		)
		body(
			model,
			root,
			"Shield",
			Vector3.new(0.3, 2.6, 2),
			CFrame.new(-1.2, 0, -0.3) * CFrame.Angles(0, math.pi / 2, 0),
			tone.Trim,
			Enum.Material.Wood
		)
	else
		body(
			model,
			root,
			"Crossbow",
			Vector3.new(2.4, 0.3, 2),
			CFrame.new(0, 0.3, -1.3),
			Color3.fromRGB(70, 52, 36),
			Enum.Material.Wood
		)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.MaxHealth, humanoid.Health = tune.Health, tune.Health
	humanoid.WalkSpeed = tune.WalkSpeed
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	-- Same tags/attributes as allied dummies and summons: spells treat them as
	-- allies, target bars colour them friendly, and enemies hunt them like defenders.
	model:SetAttribute("SandboxAlignment", "Human")
	model:SetAttribute("SandboxLabel", kind .. " Guard")
	model:SetAttribute("MissionGuard", true)
	model:SetAttribute("MissionId", roundId)
	model:SetAttribute("GuardKind", kind)
	CollectionService:AddTag(model, "MagicAllyTarget")
	CollectionService:AddTag(model, "CityHuman")
	model.Parent = parent
	root:SetNetworkOwner(nil)
	return model, root, humanoid
end

local function bolt(from: Vector3, to: Vector3)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Color = Enum.Material.Neon, Color3.fromRGB(255, 214, 150)
	p.Size = Vector3.new(0.15, 0.15, (to - from).Magnitude)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = workspace
	task.delay(0.12, p.Destroy, p)
end

-- levels: map handles from DefendTheWallsMap; enemies(): live enemy models.
function Guards.new(folder: Instance, levels: { any }, enemies: () -> { Model }): Squad
	local list: { Guard } = {}
	local spawnedTotal = 0
	local heartbeat: RBXScriptConnection? = nil
	local container = Instance.new("Folder")
	container.Name, container.Parent = "MissionGuards", folder
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function nearestEnemy(from: Vector3, radius: number): (Humanoid?, BasePart?)
		local best, bestHumanoid, bestRoot = radius, nil, nil
		for _, model in enemies() do
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local d = (root.Position - from).Magnitude
				if d < best then
					best, bestHumanoid, bestRoot = d, humanoid, root
				end
			end
		end
		return bestHumanoid, bestRoot
	end

	local function think(guard: Guard, now: number)
		local tune = Config.Guards[guard.Kind]
		local here = guard.Root.Position
		local retreat = guard.Retreat
		if retreat then
			local flat = Vector3.new(retreat.Rally.X - here.X, 0, retreat.Rally.Z - here.Z)
			if flat.Magnitude < 6 or now > retreat.Until then
				guard.Retreat = nil
				guard.Model:PivotTo(guard.Post)
			else
				guard.Humanoid:MoveTo(retreat.Rally)
			end
			return
		end
		local post = guard.Post.Position
		local reach = if guard.Kind == "Spearman" then tune.Leash + tune.Range else tune.Range
		local target, targetRoot = nearestEnemy(if guard.Kind == "Spearman" then post else here, reach)
		if not target or not targetRoot then
			if guard.Kind == "Spearman" and (here - post).Magnitude > 3 then
				guard.Humanoid:MoveTo(post)
			end
			return
		end
		local distance = (targetRoot.Position - here).Magnitude
		if guard.Kind == "Spearman" and distance > tune.Range then
			guard.Humanoid:MoveTo(targetRoot.Position)
			return
		end
		if now < guard.NextAttack then
			return
		end
		if guard.Kind == "Crossbowman" then
			rayParams.FilterDescendantsInstances = { guard.Model, targetRoot.Parent :: Instance, container }
			local eye = here + Vector3.new(0, 1.5, 0)
			if workspace:Raycast(eye, targetRoot.Position - eye, rayParams) then
				return -- no line of sight
			end
			bolt(eye, targetRoot.Position)
		else
			guard.Humanoid:MoveTo(here) -- plant feet for the thrust
		end
		guard.NextAttack = now + tune.Cooldown
		if guard.Kind == "Crossbowman" then
			Damage.apply(guard.Model, target, tune.Damage)
		else
			Damage.applyMelee(guard.Model, target, tune.Damage)
		end
	end

	local cursor = 0
	local function step()
		local now = os.clock()
		-- Think for at most a quarter of the squad per frame.
		local budget = math.max(1, math.ceil(#list / 4))
		for _ = 1, math.min(budget, #list) do
			cursor = cursor % #list + 1
			local guard = list[cursor]
			if guard.Humanoid.Health > 0 and now >= guard.NextThink then
				guard.NextThink = now + Config.Guards.ThinkInterval
				think(guard, now)
			end
		end
	end

	local squad = {} :: Squad
	function squad.clear()
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
		for _, guard in list do
			guard.Model:Destroy()
		end
		table.clear(list)
		spawnedTotal = 0
	end
	function squad.spawn(roundId: string)
		squad.clear()
		for level, counts in Config.Guards.PerWall do
			local handles = levels[level]
			for _, kind in { "Spearman", "Crossbowman" } do
				local posts = if kind == "Spearman" then handles.SpearPosts else handles.BowPosts
				for i = 1, math.min(counts[kind] or 0, #posts) do
					if spawnedTotal >= Config.Guards.MaxTotal then
						break
					end
					local model, root, humanoid = makeGuard(kind, posts[i], container, roundId)
					local guard: Guard = {
						Model = model,
						Root = root,
						Humanoid = humanoid,
						Kind = kind,
						Level = level,
						Post = posts[i],
						NextThink = os.clock() + spawnedTotal * 0.05,
						NextAttack = 0,
						Retreat = nil,
					}
					humanoid.Died:Connect(function()
						task.delay(4, function()
							if model.Parent then
								model:Destroy()
							end
						end)
					end)
					table.insert(list, guard)
					spawnedTotal += 1
				end
			end
		end
		heartbeat = RunService.Heartbeat:Connect(step)
	end
	function squad.retreat(fromLevel: number, toLevel: number)
		local target = levels[toLevel]
		local used: { [string]: number } = { Spearman = 0, Crossbowman = 0 }
		for _, guard in list do
			if guard.Level == toLevel then
				used[guard.Kind] += 1
			end
		end
		for _, guard in list do
			if guard.Level == fromLevel and guard.Humanoid.Health > 0 then
				if not target then
					-- Doors are next: everyone falls back to the staging courtyard.
					guard.Level = toLevel
					local rally = levels[#levels].Fallback -- behind the breached bastion
					guard.Post = CFrame.new(rally + Vector3.new((#list % 7 - 3) * 4, 0, 6))
					guard.Retreat = { Rally = rally, Until = os.clock() + Config.Guards.RetreatTimeout }
				else
					local posts = if guard.Kind == "Spearman" then target.SpearPosts else target.BowPosts
					used[guard.Kind] += 1
					local slot = (used[guard.Kind] - 1) % #posts + 1
					guard.Level = toLevel
					-- Overflow guards double up behind the post rather than stacking on it.
					guard.Post = posts[slot] * CFrame.new(0, 0, if used[guard.Kind] > #posts then -3 else 0)
					if guard.Kind == "Crossbowman" then
						-- Drop down the front of the fallen wall first.
						guard.Model:PivotTo(CFrame.new(levels[fromLevel].Rally))
					end
					guard.Retreat = { Rally = target.Rally, Until = os.clock() + Config.Guards.RetreatTimeout }
				end
			end
		end
	end
	function squad.alive(): number
		local n = 0
		for _, guard in list do
			if guard.Humanoid.Health > 0 and guard.Model.Parent then
				n += 1
			end
		end
		return n
	end
	function squad.total(): number
		return spawnedTotal
	end
	return squad
end

return Guards
