--!strict
-- Cosmetic copies only. Never register with EnemyRuntime, damage or targeting.
local Collection = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Corpses = {}
local live: { Model } = {}
function Corpses.show(source: Model)
	-- Preserve immediate gameplay cleanup; retain only a bounded visual copy.
	for i = #live, 1, -1 do
		if not live[i].Parent then
			table.remove(live, i)
		end
	end
	if #live >= 24 then
		live[1]:Destroy()
		table.remove(live, 1)
	end
	local copy = source:Clone()
	copy.Name = "EnemyVisualCorpse"
	local pose = source:GetAttribute("EnemyPose")
	local kind = source:GetAttribute("VisualKind")
	for _, object in copy:GetDescendants() do
		for _, tag in Collection:GetTags(object) do
			Collection:RemoveTag(object, tag)
		end
		if object:IsA("BasePart") then
			object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
			object.Anchored = object.Name == "HumanoidRootPart"
		elseif not object:IsA("Motor6D") and not object:IsA("WeldConstraint") then
			object:Destroy()
		end
	end
	for _, tag in Collection:GetTags(copy) do
		Collection:RemoveTag(copy, tag)
	end
	for name in copy:GetAttributes() do
		copy:SetAttribute(name, nil)
	end
	local hull = copy:FindFirstChild("CollisionHull")
	if hull then
		hull:Destroy()
	end
	copy:SetAttribute("EnemyPose", pose)
	copy:SetAttribute("VisualKind", kind)
	local folder = workspace:FindFirstChild("EnemyAnimationCorpses")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EnemyAnimationCorpses"
		folder.Parent = workspace
	end
	copy.Parent = folder
	Collection:AddTag(copy, "EnemyAnimatedCorpse")
	table.insert(live, copy)
	Debris:AddItem(copy, 1.1)
end
return Corpses
