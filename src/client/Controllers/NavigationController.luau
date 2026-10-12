--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Topology = require(Shared.Configuration.PhaseATopology)
local Locations = require(Shared.Configuration.AssignmentLocations)
local Navigation = require(Shared.Configuration.Navigation)

local Controller = {}
function Controller.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DistrictNavigation"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local compass = Instance.new("TextLabel")
	compass.Size = UDim2.fromOffset(300, 28)
	compass.Position = UDim2.new(0.5, -150, 0, 92)
	compass.BackgroundTransparency = 0.35
	compass.TextColor3 = Color3.new(1, 1, 1)
	compass.Font = Enum.Font.GothamBold
	compass.Parent = gui
	local map = Instance.new("Frame")
	map.Size = UDim2.fromOffset(520, 520)
	map.Position = UDim2.new(0.5, -260, 0.5, -260)
	map.BackgroundColor3 = Color3.fromRGB(15, 18, 21)
	map.Visible = false
	map.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromOffset(520, 28)
	title.BackgroundTransparency = 1
	title.Text = "LOWER LAYER — PHASE A  |  M to close"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = map
	local minX, maxX, minZ, maxZ = -700, 700, 300, 1800
	local function point(position: Vector3, color: Color3, size: number)
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(size, size)
		p.BackgroundColor3 = color
		p.BorderSizePixel = 0
		p.Position = UDim2.fromScale((position.X - minX) / (maxX - minX), (position.Z - minZ) / (maxZ - minZ))
		p.Parent = map
		return p
	end
	local function route(points)
		for i = 2, #points do
			local a, b = points[i - 1], points[i]
			if a and b and a.Y >= 0 and b.Y >= 0 then
				local dx, dz = (b.X - a.X) * 520 / (maxX - minX), (b.Z - a.Z) * 520 / (maxZ - minZ)
				local line = point((a + b) / 2, Navigation.Map.SurfaceColor, 2)
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.Size = UDim2.fromOffset(math.max(2, math.sqrt(dx * dx + dz * dz)), 2)
				line.Rotation = math.deg(math.atan2(dz, dx))
			end
		end
	end
	for _, edge in ipairs(Topology.Edges) do
		route(edge.Points or { Topology.Nodes[edge[1]], Topology.Nodes[edge[2]] })
	end
	for _, branch in ipairs(Topology.Hive.Branches) do
		local points = {}
		for _, p in ipairs(branch) do
			table.insert(points, Vector3.new(p[1], p[2], p[3]))
		end
		route(points)
	end
	for _, location in Locations do
		local marker = point(location.Position, Color3.fromRGB(255, 220, 100), 8)
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromOffset(100, 16)
		text.Position = UDim2.fromOffset(5, -4)
		text.BackgroundTransparency = 1
		text.Text = location.Name
		text.TextSize = 10
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = marker
	end
	local playerDot = point(Vector3.zero, Color3.fromRGB(100, 220, 255), 10)
	local objectiveDot = point(Vector3.zero, Color3.fromRGB(255, 100, 80), 10)
	objectiveDot.Visible = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			map.Visible = not map.Visible
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not camera or not root or not root:IsA("BasePart") then
			return
		end
		local look = camera.CFrame.LookVector
		local heading = math.atan2(-look.X, -look.Z)
		local labels = { "N", "E", "S", "W" }
		local index = (math.floor((heading + math.pi / 4) / (math.pi / 2)) % 4) + 1
		local objective = if player:GetAttribute("AssignmentId") and player:GetAttribute("AssignmentId") ~= ""
			then Locations[player:GetAttribute("AssignmentLocation") or ""]
			else nil
		local suffix = ""
		objectiveDot.Visible = objective ~= nil
		if objective then
			local delta = objective.Position - root.Position
			suffix = string.format("  •  %ds", delta.Magnitude)
			if math.abs(delta.Y) > Navigation.Compass.ObjectiveVerticalThreshold then
				suffix ..= (if delta.Y > 0 then " ↑" else " ↓")
			end
			objectiveDot.Position = UDim2.fromScale(
				(objective.Position.X - minX) / (maxX - minX),
				(objective.Position.Z - minZ) / (maxZ - minZ)
			)
		end
		compass.Text = string.format(
			"%s   %s   %s   %s%s",
			labels[index],
			labels[index % 4 + 1],
			labels[(index + 1) % 4 + 1],
			labels[(index + 2) % 4 + 1],
			suffix
		)
		playerDot.Position =
			UDim2.fromScale((root.Position.X - minX) / (maxX - minX), (root.Position.Z - minZ) / (maxZ - minZ))
	end)
end
return Controller
