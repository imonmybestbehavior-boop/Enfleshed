-- Defend the Walls review views. Paste into Studio's CLIENT Command Bar during Play.
-- Flies the camera through the review shots (6 s each) so you can screenshot each one,
-- then gives the camera back. Streaming is on, so it asks the server to stream each
-- spot in first. Set ONLY to a view name (e.g. "Crossing") to hold a single shot for 30 s.
local ONLY = nil
local views = {
	{ "Village", Vector3.new(-40, 38, 600), Vector3.new(0, 4, 760) },
	{ "Crossing", Vector3.new(70, 42, 930), Vector3.new(0, 0, 990) },
	{ "Wall1_Palisade", Vector3.new(30, 18, 1050), Vector3.new(0, 8, 1110) },
	{ "Wall2_Curtain", Vector3.new(-70, 30, 1120), Vector3.new(0, 12, 1165) },
	{ "Wall3_Bastion", Vector3.new(40, 34, 1180), Vector3.new(0, 18, 1228) },
	{ "FinalDoors", Vector3.new(0, 12, 1250), Vector3.new(0, 18, 1300) },
	{ "Overview", Vector3.new(0, 260, 760), Vector3.new(0, 0, 1000) },
}
local player = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera
local previousType = camera.CameraType
camera.CameraType = Enum.CameraType.Scriptable
local ok, err = pcall(function()
	for _, view in views do
		if ONLY == nil or ONLY == view[1] then
			pcall(player.RequestStreamAroundAsync, player, view[3], 10)
			camera.CFrame = CFrame.lookAt(view[2], view[3])
			print("[DTW views] " .. view[1] .. " — screenshot now")
			task.wait(if ONLY then 30 else 6)
		end
	end
end)
camera.CameraType = previousType
if not ok then
	warn(err)
end
