-- One camera-facing painted body, driven by the session clock and live travel frame.
-- View changes use the same frame index. No independent particle starts or image warping.
local Sprite = {}
Sprite.__index = Sprite

function Sprite.selectView(views, angle, previous)
	local best = views[1]
	for _, view in views do
		if math.abs(view.Angle-angle) < math.abs(best.Angle-angle) then best = view end
	end
	-- A small deadband avoids rapid switching at a view boundary.
	if previous and math.abs(previous.Angle-angle) <= math.abs(best.Angle-angle)+4 then
		return previous
	end
	return best
end

function Sprite.new(host, parent, definition, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DirectionalBody"
	gui.Adornee = host
	gui.Size = UDim2.fromScale(size, size)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 180
	gui.ClipsDescendants = false
	local image = Instance.new("ImageLabel")
	image.Name = "PaintedBody"
	image.AnchorPoint = Vector2.new(.5,.5)
	image.Position = UDim2.fromScale(.5,.5)
	image.Size = UDim2.fromScale(1,1)
	image.BackgroundTransparency = 1
	image.ImageColor3 = Color3.new(1,1,1)
	image.ImageRectSize = Vector2.one * definition.CellSize
	image.Image = definition.Views[1].Image
	image.Parent = gui
	gui.Parent = parent
	return setmetatable({Gui=gui, Image=image, Definition=definition}, Sprite)
end

function Sprite:Update(frame, camera, clock, shown, opacity)
	local definition = self.Definition
	local image = self.Image
	local index = math.floor(clock * definition.Framerate) % definition.Frames
	image.ImageRectOffset = Vector2.new(index % definition.Columns, math.floor(index / definition.Columns)) * definition.CellSize
	if camera then
		local delta = camera.CFrame.Position-frame.Position
		local direction = frame.LookVector
		local angle = if delta.Magnitude > .001 then math.deg(math.acos(math.clamp(direction:Dot(delta.Unit),-1,1))) else 0
		local view = Sprite.selectView(definition.Views, angle, self.View)
		if view ~= self.View then
			self.View = view
			image.Image = view.Image
		end
		local projected = camera.CFrame:VectorToObjectSpace(direction)
		-- Source heads point right. Rotate the whole card to projected travel, without stretching.
		image.Rotation = if projected.X^2+projected.Y^2 > .0025 then math.deg(math.atan2(-projected.Y,projected.X)) else 0
		self.Gui:SetAttribute("View", view.Name)
		self.Gui:SetAttribute("Angle", angle)
	end
	self.Gui.Enabled = shown
	image.ImageTransparency = 1-math.clamp(opacity,0,1)
	self.Gui:SetAttribute("Frame", index+1)
end

return Sprite
