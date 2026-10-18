local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("DirectionalFirePlaybackReview")
assert(gui, "Playback review is missing")
local first = gui:GetAttributes()
task.wait(2.25)
local second = gui:GetAttributes()
local images = {}
for _, instance in gui:GetDescendants() do
	if instance:IsA("ImageLabel") then
		table.insert(images, {Name=instance.Name, Image=instance.Image, IsLoaded=instance.IsLoaded,
			Offset={instance.ImageRectOffset.X,instance.ImageRectOffset.Y}})
	end
end
return game:GetService("HttpService"):JSONEncode({Before=first,After=second,Images=images,
	IsClient=game:GetService("RunService"):IsClient(),PlaceId=game.PlaceId})
