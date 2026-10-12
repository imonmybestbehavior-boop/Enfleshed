--!strict

-- Keep server simulation active while one or more magic physics effects own a
-- root. Tokens let short impulses and maintained controls coexist safely.
local Players = game:GetService("Players")
local Ownership = {}
local states = setmetatable({}, { __mode = "k" })

function Ownership.claim(root: BasePart, token: any): boolean
	if root.Anchored or not root:IsDescendantOf(workspace) then
		return false
	end
	local state = states[root]
	if not state then
		if not root:CanSetNetworkOwnership() then
			return false
		end
		state = {
			Owner = root:GetNetworkOwner(),
			Automatic = root:GetNetworkOwnershipAuto(),
			Tokens = {},
		}
		states[root] = state
		local ok = pcall(function()
			root:SetNetworkOwner(nil)
		end)
		if not ok then
			states[root] = nil
			return false
		end
	end
	state.Tokens[token] = true
	return true
end

function Ownership.release(root: BasePart, token: any)
	local state = states[root]
	if not state then
		return
	end
	state.Tokens[token] = nil
	if next(state.Tokens) ~= nil then
		return
	end
	states[root] = nil
	if not root:IsDescendantOf(workspace) or not root:CanSetNetworkOwnership() then
		return
	end
	pcall(function()
		if state.Automatic or not state.Owner or state.Owner.Parent ~= Players then
			root:SetNetworkOwnershipAuto()
		else
			root:SetNetworkOwner(state.Owner)
		end
	end)
end

return Ownership
