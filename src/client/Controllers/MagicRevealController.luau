--!strict

-- Renders server-authored reveal expiries locally for the owning caster only.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Controller = {}
local TAG = "MagicRevealedTarget"
local REFRESH_INTERVAL = 0.2
local started = false

function Controller.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local userId = tostring(player.UserId)
	local untilAttribute = "MagicRevealUntil_" .. userId
	local colorAttribute = "MagicRevealColor_" .. userId
	local highlights: { [Model]: Highlight } = setmetatable({}, { __mode = "k" }) :: any
	local elapsed = 0

	local function remove(model: Model)
		local highlight = highlights[model]
		if highlight then
			highlight:Destroy()
			highlights[model] = nil
		end
	end

	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < REFRESH_INTERVAL then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		local tagged = CollectionService:GetTagged(TAG)
		local current: { [Model]: boolean } = {}
		for _, instance in tagged do
			if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
				continue
			end
			local expiresAt = instance:GetAttribute(untilAttribute)
			if type(expiresAt) ~= "number" or expiresAt <= now then
				remove(instance)
				continue
			end
			current[instance] = true
			local highlight = highlights[instance]
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "MagicReveal_" .. userId
				highlight.Adornee = instance
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.FillTransparency = 0.92
				highlight.OutlineTransparency = 0.05
				highlight.Parent = instance
				highlights[instance] = highlight
			end
			local color = instance:GetAttribute(colorAttribute)
			if typeof(color) ~= "Color3" then
				color = Color3.fromRGB(255, 194, 90)
			end
			highlight.FillColor = color
			highlight.OutlineColor = color
		end
		for model in highlights do
			if not current[model] or not CollectionService:HasTag(model, TAG) then
				remove(model)
			end
		end
	end)
end

return Controller
