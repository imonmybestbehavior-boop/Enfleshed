--!strict

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Configuration.Sandbox)
local Debug = {}

function Debug.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SandboxDebug"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(360, 64)
	label.Position = UDim2.fromOffset(12, 12)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 17
	label.Font = Enum.Font.Code
	label.Parent = gui
	local hitUntil = 0
	local hitText = ""
	return {
		Hit = function(damage: number)
			hitText = string.format("HIT  -%g HP", damage)
			hitUntil = os.clock() + Config.Debug.HitDuration
		end,
		Reset = function()
			hitUntil = 0
		end,
		Update = function(combo: number, cooldown: number)
			label.Text = string.format(
				"Combo %d/3  |  Dash %.1fs\n%s",
				combo,
				cooldown,
				if os.clock() < hitUntil then hitText else ""
			)
		end,
	}
end

export type Controller = typeof(Debug.start())
return Debug
