--!strict
-- Nearby text only. No global markers, acceptance button or client outcome requests.
local HUD = {}
function HUD.start()
	local player = game:GetService("Players").LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "NearbyWorldEvent", false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint, label.Position = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.88)
	label.Size, label.BackgroundTransparency = UDim2.fromOffset(410, 66), 0.25
	label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(26, 25, 23), Color3.fromRGB(229, 217, 191)
	label.TextWrapped, label.TextSize, label.Font = true, 16, Enum.Font.Gotham
	label.Parent = gui
	local notice, untilTime = "", 0
	local function update()
		local event = player:GetAttribute("NearbyWorldEvent") or ""
		label.Text = if os.clock() < untilTime then notice else event
		gui.Enabled = player:GetAttribute("OpeningComplete") == true and label.Text ~= ""
	end
	for _, attribute in { "NearbyWorldEvent", "OpeningComplete" } do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	for _, attribute in { "EventRewardNotice", "CityRemark" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			notice = player:GetAttribute(attribute) or ""
			untilTime = os.clock() + 5
			update()
			task.delay(5, update)
		end)
	end
	update()
end
return HUD
