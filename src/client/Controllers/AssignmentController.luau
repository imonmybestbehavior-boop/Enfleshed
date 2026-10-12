--!strict

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Configuration.Assignments)

local Assignment = {}

function Assignment.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "AssignmentHUD", false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size, label.Position = UDim2.fromOffset(420, 74), UDim2.new(0.5, -210, 0, 12)
	label.BackgroundTransparency, label.TextColor3, label.TextStrokeTransparency = 0.28, Color3.new(1, 1, 1), 0
	label.BackgroundColor3, label.Font, label.TextSize = Color3.fromRGB(18, 18, 18), Enum.Font.Gotham, 16
	label.Parent = gui
	game:GetService("RunService").RenderStepped:Connect(function()
		local id, status = player:GetAttribute("AssignmentId"), player:GetAttribute("AssignmentState")
		gui.Enabled = id ~= nil and id ~= "" and player:GetAttribute("OpeningComplete") == true
		if not gui.Enabled then
			return
		end
		local definition = Definitions[id]
		label.Text = string.format(
			"%s  |  %s\n%s  |  Scrip: %d",
			definition and definition.Name or id,
			status or "",
			player:GetAttribute("AssignmentLocation") or "",
			player:GetAttribute("MilitaryScrip") or 0
		)
	end)
end

return Assignment
