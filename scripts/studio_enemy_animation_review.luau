-- Studio SERVER-only presentation fixture. Run manually, never from bootstrap.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local Http = game:GetService("HttpService")
local Runtime = require(game.ServerScriptService.Server.Services.EnemyRuntime)
local Enemy = require(game.ServerScriptService.Server.Services.EnemyService)
local Collection = game:GetService("CollectionService")
assert(not workspace:FindFirstChild("EnemyAnimationReview"), "Clean the preceding review first")
local folder = Instance.new("Folder")
folder.Name = "EnemyAnimationReview"
folder.Parent = workspace
local result = Instance.new("StringValue")
result.Name = "Result"
result.Value = "Running"
result.Parent = folder
local origin = Vector3.new(2000, 100, 2000)
local floor = Instance.new("Part")
floor.Size = Vector3.new(220, 2, 180)
floor.CFrame = CFrame.new(origin + Vector3.new(80, -1, 0))
floor.Anchored = true
floor.Color = Color3.fromRGB(110, 115, 120)
floor.Parent = folder
local ledge = Instance.new("Part")
ledge.Size = Vector3.new(150, 4, 180)
ledge.CFrame = CFrame.new(origin + Vector3.new(115, 2, 0))
ledge.Anchored = true
ledge.Parent = folder
for _, x in { 0, 80, 150 } do
	local lamp = Instance.new("Part")
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.Transparency = 1
	lamp.Position = origin + Vector3.new(x, 35, 0)
	lamp.Parent = folder
	local light = Instance.new("PointLight")
	light.Range = 100
	light.Brightness = 8
	light.Parent = lamp
end
local kinds =
	{ { "Basic", 1, 160, 18 }, { "Swift", 1, 115, 22 }, { "Brute", 1.25, 260, 13 }, { "Elite", 1.5, 440, 13 } }
local handles, targets = {}, {}
local report = { Status = "Running", Actors = {}, Hits = {}, Phases = {} }
local started = os.clock()
local connection = require(game.ServerScriptService.Server.Services.DamageService).Applied:Connect(
	function(attacker, victim, amount)
		if attacker:IsDescendantOf(folder) then
			local packet = Http:JSONDecode(attacker:GetAttribute("EnemyPose"))
			table.insert(report.Hits, {
				Kind = attacker:GetAttribute("VisualKind"),
				Amount = amount,
				At = workspace:GetServerTimeNow(),
				State = packet.State,
				Start = packet.Start,
				Finish = packet.Finish,
				Step = packet.Step,
			})
		end
	end
)
for i, k in kinds do
	local z = (i - 2.5) * 30
	local target = Instance.new("Model")
	target.Name = "Citizen" .. k[1]
	target.Parent = folder
	local tr = Instance.new("Part")
	tr.Name = "HumanoidRootPart"
	tr.Size = Vector3.new(2, 6, 2)
	tr.CFrame = CFrame.new(origin + Vector3.new(145, 8, z))
	tr.Anchored = true
	tr.Parent = target
	local hp = Instance.new("Humanoid")
	hp.MaxHealth = 10000
	hp.Health = 10000
	hp.Parent = target
	target.PrimaryPart = tr
	target:SetAttribute("SandboxAlignment", "Human")
	local e = Runtime.create(origin + Vector3.new(0, 4 * k[2], z), folder, k[1])
	e.Model.Name = "Review" .. k[1]
	e.Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local h = e.Model:FindFirstChildOfClass("Humanoid")
	h.MaxHealth = k[3]
	h.Health = k[3]
	h.WalkSpeed = k[4]
	if k[2] ~= 1 then
		e.Model:ScaleTo(k[2])
	end
	handles[i] = e
	targets[i] = target
	report.Actors[k[1]] = { Scale = k[2], States = {}, Grounded = false }
end
task.spawn(function()
	local ok, err = xpcall(function()
		while os.clock() - started < 40 do
			local elapsed = os.clock() - started
			for i, e in handles do
				local h = e.Model:FindFirstChildOfClass("Humanoid")
				if elapsed >= 4 and not e.Model:FindFirstChild("ObjectiveTarget") then
					local order = Instance.new("ObjectValue")
					order.Name = "ObjectiveTarget"
					order.Value = targets[i]
					order.Parent = e.Model
					Collection:AddTag(targets[i], "CityHuman")
				end
				local a = report.Actors[kinds[i][1]]
				a.States[e.Model:GetAttribute("SandboxState") or "Unset"] = true
				a.Grounded = a.Grounded or h.FloorMaterial ~= Enum.Material.Air
			end

			if elapsed >= 1.5 and not report.Phases.Jump then
				report.Phases.Jump = elapsed
				for _, e in handles do
					e.Model:FindFirstChildOfClass("Humanoid").Jump = true
				end
			end
			for i, e in handles do
				local a = report.Actors[kinds[i][1]]
				local raw = e.Model:GetAttribute("EnemyPose")
				if elapsed >= 15 and not a.MissProbe and raw then
					local packet = Http:JSONDecode(raw)
					if
						packet.State == "Telegraph"
						and packet.Attack == "PredatoryLunge"
						and packet.Finish - workspace:GetServerTimeNow() < 0.08
					then
						a.MissProbe = true
						targets[i].HumanoidRootPart.CFrame += Vector3.new(0, 0, 14)
					end
				end
			end
			if elapsed >= 25 and not report.Phases.Major then
				report.Phases.Major = elapsed
				for _, e in handles do
					Enemy.onHit(e.Model:FindFirstChildOfClass("Humanoid"), "Major")
				end
			end
			if elapsed >= 29 and not report.Phases.Significant then
				report.Phases.Significant = elapsed
				for _, e in handles do
					Enemy.onHit(e.Model:FindFirstChildOfClass("Humanoid"), "Significant")
				end
			end
			if elapsed >= 32 and not report.Phases.Desperate then
				report.Phases.Desperate = elapsed
				for _, e in handles do
					local h = e.Model:FindFirstChildOfClass("Humanoid")
					h.Health = h.MaxHealth * 0.1
				end
			end
			task.wait(0.05)
		end
		for _, e in handles do
			e.Model:FindFirstChildOfClass("Humanoid").Health = 0
			e.Destroy()
		end
		task.wait(1.5)
	end, debug.traceback)
	connection:Disconnect()
	for _, target in targets do
		Collection:RemoveTag(target, "CityHuman")
	end
	for _, e in handles do
		if e.Model.Parent then
			e.Destroy()
		end
	end
	report.Status = if ok then "Finished" else "Error"
	report.Error = if not ok then err else nil
	result.Value = Http:JSONEncode(report)
end)
return "Enemy animation review started: 4s idle, travel/jump/combat, reactions at 25/29s, death at 40s"
