--!strict

-- Small overhead icon on every character holding Enchantments. The server
-- replicates a summary ("Boon:2|Bane:1") in the MagicEnchantments attribute and
-- tags the model MagicEnchanted, the same path MagicRevealController reads.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EnchantmentSpec = require(Shared.Modules.MagicEnchantmentSpec)

local Controller = {}
local TAG = "MagicEnchanted"
local REFRESH_INTERVAL = 0.25
local STYLE = {
	Boon = { Glyph = "▲", Color = Color3.fromRGB(120, 220, 140) },
	Bane = { Glyph = "▼", Color = Color3.fromRGB(235, 95, 95) },
	Neutral = { Glyph = "◆", Color = Color3.fromRGB(200, 190, 230) },
}
local started = false

function Controller.start()
	if started then
		return
	end
	started = true
	local icons: { [Model]: BillboardGui } = setmetatable({}, { __mode = "k" }) :: any
	local elapsed = 0

	local function remove(model: Model)
		local icon = icons[model]
		if icon then
			icon:Destroy()
			icons[model] = nil
		end
	end

	local function render(model: Model, counts: { [string]: number })
		local icon = icons[model]
		local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
		if not head or not head:IsA("BasePart") then
			remove(model)
			return
		end
		if not icon then
			icon = Instance.new("BillboardGui")
			icon.Name = "MagicEnchantmentIcon"
			icon.Size = UDim2.fromOffset(72, 18)
			icon.StudsOffset = Vector3.new(0, 2.6, 0)
			icon.AlwaysOnTop = true
			icon.MaxDistance = 90
			icon.ResetOnSpawn = false
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.Padding = UDim.new(0, 4)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = icon
			icon.Parent = model
			icons[model] = icon
		end
		icon.Adornee = head
		for index, kind in EnchantmentSpec.Types do
			local label = icon:FindFirstChild(kind) :: TextLabel?
			local count = counts[kind] or 0
			if count <= 0 then
				if label then
					label:Destroy()
				end
				continue
			end
			if not label then
				local created = Instance.new("TextLabel")
				created.Name = kind
				created.BackgroundTransparency = 1
				created.Size = UDim2.fromOffset(22, 18)
				created.Font = Enum.Font.GothamBold
				created.TextSize = 13
				created.TextStrokeTransparency = 0.4
				created.TextColor3 = STYLE[kind].Color
				created.LayoutOrder = index
				created.Parent = icon
				label = created
			end
			(label :: TextLabel).Text = if count > 1 then STYLE[kind].Glyph .. count else STYLE[kind].Glyph
		end
	end

	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < REFRESH_INTERVAL then
			return
		end
		elapsed = 0
		local current: { [Model]: boolean } = {}
		for _, instance in CollectionService:GetTagged(TAG) do
			if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
				continue
			end
			local counts = EnchantmentSpec.decode(instance:GetAttribute("MagicEnchantments"))
			if next(counts) == nil then
				continue
			end
			current[instance] = true
			render(instance, counts)
		end
		for model in icons do
			if not current[model] then
				remove(model)
			end
		end
	end)
end

return Controller
