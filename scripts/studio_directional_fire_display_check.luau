-- Temporary Studio image load probe. Does not change saved runtime objects.
local entries = {
	{"front", "rbxassetid://81011468551955"},
	{"three_quarter", "rbxassetid://81316819745490"},
	{"side", "rbxassetid://97561699384624"},
	{"rear", "rbxassetid://92127109486544"},
}
local gui = Instance.new("ScreenGui")
gui.Name = "DirectionalFireLoadProbe"
gui.Parent = game:GetService("CoreGui")
local images = {}
for index, entry in entries do
	local image = Instance.new("ImageLabel")
	image.Name = entry[1]
	image.Size = UDim2.fromOffset(180, 180)
	image.Position = UDim2.fromOffset(20 + (index-1)*185, 60)
	image.BackgroundColor3 = Color3.fromRGB(30,30,30)
	image.Image = entry[2]
	image.ImageRectSize = Vector2.new(256,256)
	image.Parent = gui
	table.insert(images, image)
end
task.wait(10)
local result = {}
for _, image in images do
	table.insert(result, {Name=image.Name, IsLoaded=image.IsLoaded, Image=image.Image})
end
gui:Destroy()
return game:GetService("HttpService"):JSONEncode(result)
