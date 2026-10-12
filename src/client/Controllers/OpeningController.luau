--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.CityLife)
local Opening = {}
function Opening.start(remotes)
	if game:GetService("RunService"):IsStudio() and require(Shared.Configuration.DevelopmentSandbox).Enabled then
		return
	end
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "LowerLayerOpening", false, 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.AnchorPoint, frame.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	frame.Size, frame.BackgroundColor3 = UDim2.fromScale(0.8, 0.65), Color3.fromRGB(26, 25, 23)
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(580, 400), frame
	local text = Instance.new("TextLabel")
	text.Size, text.Position = UDim2.fromScale(0.9, 0.53), UDim2.fromScale(0.05, 0.03)
	text.BackgroundTransparency, text.TextWrapped = 1, true
	text.TextColor3, text.TextSize, text.Font = Color3.fromRGB(226, 216, 196), 19, Enum.Font.Gotham
	text.Text =
		"You wake without a name.\n\nBeyond the room, workers and watchmen pass beneath stone no human laid. A settlement lives inside this ancient structure. The Enfleshed are a familiar danger here.\n\nA spare weapon waits beside you. Which feels familiar?"
	text.Parent = frame
	local function button(y, caption, callback)
		local b = Instance.new("TextButton")
		b.Position, b.Size = UDim2.fromScale(0.05, y), UDim2.fromScale(0.9, 0.11)
		b.Text, b.TextSize, b.Font = caption, 17, Enum.Font.Gotham
		b.TextColor3, b.BackgroundColor3, b.Modal = text.TextColor3, Color3.fromRGB(65, 60, 50), true
		b.Parent = frame
		b.Activated:Connect(callback)
		return b
	end
	local preset = 1
	local appearance
	appearance = button(0.58, "Appearance: " .. Config.Presets[preset].Name, function()
		preset = preset % #Config.Presets + 1
		appearance.Text = "Appearance: " .. Config.Presets[preset].Name
	end)
	local remote = remotes:WaitForChild("OpeningChoice")
	local function choose(path)
		if player:GetAttribute("CharacterReady") then
			remote:FireServer(preset, path)
		end
	end
	button(0.72, "Take the melee weapon", function()
		choose("Melee")
	end)
	button(0.85, "Take the recruit magic weapon", function()
		choose("Magic")
	end)
	local function refresh()
		gui.Enabled = player:GetAttribute("OpeningComplete") ~= true
	end
	player:GetAttributeChangedSignal("OpeningComplete"):Connect(refresh)
	refresh()
end
return Opening
