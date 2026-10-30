-- Studio CLIENT-only observer. Temporary camera/UI changes are restored.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local player = game.Players.LocalPlayer
local folder = workspace:WaitForChild("EnemyAnimationReview", 10)
player:RequestStreamAroundAsync(Vector3.new(2080, 105, 2000))
local gui = {}
for _, g in player.PlayerGui:GetChildren() do
	if g:IsA("ScreenGui") then
		gui[g] = g.Enabled
		g.Enabled = false
	end
end
local camera = workspace.CurrentCamera
local oldType, oldFrame, oldFocus = camera.CameraType, camera.CFrame, camera.Focus
local output = Instance.new("StringValue")
output.Name = "EnemyAnimationClientReport"
output.Value = "Running"
output.Parent = workspace
local report = { Status = "Running", Actors = {}, Corpses = {}, Samples = 0 }
local elapsed = 0
Run:BindToRenderStep("EnemyAnimationReviewCamera", Enum.RenderPriority.Last.Value, function(dt)
	elapsed += dt
	report.Samples += 1
	local center, count = Vector3.zero, 0
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m.Name:sub(1, 6) == "Review" then
			local root = m:FindFirstChild("HumanoidRootPart")
			local h = m:FindFirstChildOfClass("Humanoid")
			if root and h then
				center += root.Position
				count += 1
				local kind = m:GetAttribute("VisualKind")
				local a = report.Actors[kind]
					or {
						States = {},
						Airborne = false,
						JointMoved = false,
						LegMoved = false,
						Desperate = false,
						Packets = 0,
					}
				report.Actors[kind] = a
				local raw = m:GetAttribute("EnemyPose")
				if raw then
					local packet = Http:JSONDecode(raw)
					a.States[packet.State] = true
					a.Desperate = a.Desperate or packet.Desperate
					a.Packets += if a.Last ~= raw then 1 else 0
					a.Last = raw
				end
				local state = h:GetState()
				a.Airborne = a.Airborne
					or state == Enum.HumanoidStateType.Freefall
					or state == Enum.HumanoidStateType.Jumping
				for _, j in m:GetDescendants() do
					if j:IsA("Motor6D") then
						local _, angle = j.Transform:ToAxisAngle()
						a.JointMoved = a.JointMoved or math.abs(angle) > 0.05
						if j.Name == "Left Hip" then
							a.LegMoved = a.LegMoved or math.abs(angle) > 0.1
						end
					end
				end
			end
		end
	end
	if count > 0 then
		center /= count
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(center + Vector3.new(25, 32, 95), center + Vector3.new(0, 1, 0))
		camera.Focus = CFrame.new(center)
	end
	for _, m in game:GetService("CollectionService"):GetTagged("EnemyAnimatedCorpse") do
		local kind = m:GetAttribute("VisualKind")
		local a = report.Corpses[kind] or { Seen = false, Moved = false, Safe = true }
		report.Corpses[kind] = a
		a.Seen = true
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				a.Safe = a.Safe and not p.CanCollide and not p.CanQuery and not p.CanTouch
			end
			if p:IsA("Motor6D") and p.Name == "RootJoint" then
				local _, angle = p.Transform:ToAxisAngle()
				a.Moved = a.Moved or math.abs(angle) > 0.2
			end
		end
	end
end)
task.delay(44, function()
	Run:UnbindFromRenderStep("EnemyAnimationReviewCamera")
	camera.CameraType, camera.CFrame, camera.Focus = oldType, oldFrame, oldFocus
	for g, enabled in gui do
		if g.Parent then
			g.Enabled = enabled
		end
	end
	for _, a in report.Actors do
		a.Last = nil
	end
	report.Status = "Finished"
	report.BootstrapEnabled = player.PlayerScripts.Client.EnemyAnimation.Enabled
	report.CorpsesRemaining = #game:GetService("CollectionService"):GetTagged("EnemyAnimatedCorpse")
	output.Value = Http:JSONEncode(report)
end)
return "Client observer and camera started; automatic restore after 44 seconds"
