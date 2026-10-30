--!strict
-- Live feature flags and spell kill switches. Defaults live in
-- Configuration/FeatureFlags; an override document in the DataStore is merged
-- over them and re-read every RefreshSeconds, so ops changes reach running
-- servers within about a minute without publishing. The merged flags are
-- replicated to clients as a JSON attribute for UI (the server stays authoritative).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defaults = require(Shared.Configuration.FeatureFlags)
local Spec = require(Shared.Modules.FeatureFlagSpec)

local Flags = {}
Flags.StoreName = "EnfleshedFeatureFlags_v1"
Flags.Key = "live"
Flags.ReplicatedAttribute = "FeatureFlags"

local changed = Instance.new("BindableEvent")
Flags.Changed = changed.Event

local current: Spec.Flags = Spec.merge(Defaults :: any, nil)
local started = false
local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(Flags.StoreName)
end)
local store: DataStore? = if storeOk then storeResult else nil

local function replicate()
	local holder = Shared:FindFirstChild("FeatureFlags")
	if not holder then
		holder = Instance.new("Configuration")
		holder.Name = "FeatureFlags"
		holder.Parent = Shared
	end
	(holder :: Instance):SetAttribute(Flags.ReplicatedAttribute, HttpService:JSONEncode(current))
end

local function refresh()
	if not store then
		return
	end
	local ok, value = pcall(function()
		return (store :: DataStore):GetAsync(Flags.Key)
	end)
	if not ok then
		warn("[FeatureFlags] refresh failed; keeping current flags: " .. tostring(value))
		return
	end
	local merged = Spec.merge(Defaults :: any, value)
	if HttpService:JSONEncode(merged) ~= HttpService:JSONEncode(current) then
		current = merged
		replicate()
		changed:Fire()
	end
end

function Flags.current(): Spec.Flags
	return current
end

function Flags.enabled(feature: string, player: Player?): boolean
	local early = player ~= nil and player:GetAttribute(Spec.EarlyAccessAttribute) == true
	return Spec.enabled(current, feature, os.time(), early)
end

function Flags.spellAllowed(definition: any): (boolean, string?)
	return Spec.spellAllowed(current, definition)
end

-- Ops helper (server Command Bar in Studio with API access, against the target
-- experience). Writes the override document; running servers pick it up on refresh.
--   require(game.ServerScriptService.Server.Services.FeatureFlagService).publish({
--       DisabledPayloads = { "Control" },
--       Features = { DefendTheWalls = { Enabled = true } },
--   })
function Flags.publish(override: any): boolean
	if not store then
		warn("[FeatureFlags] DataStore unavailable")
		return false
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(Flags.Key, override)
	end)
	if not ok then
		warn("[FeatureFlags] publish failed: " .. tostring(err))
		return false
	end
	refresh()
	return true
end

function Flags.start()
	if started then
		return
	end
	started = true
	replicate()
	task.spawn(function()
		refresh() -- never block server startup on the DataStore
		while true do
			task.wait(math.max(15, current.RefreshSeconds))
			refresh()
		end
	end)
end

return Flags
