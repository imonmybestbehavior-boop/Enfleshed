-- Server-owned versioned persistence for static world Constructs.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.MagicLab)
local Spec = require(Shared.Modules.MagicPersistentConstructSpec)

local Store = {}
local dataStore
local loaded = false
local writable = false
local profile = Spec.emptyProfile()
-- Remaining health waiting to be saved (id -> health), written by flushHealth.
local pendingHealth = {}
local key = string.format("place:%s:%s", tostring(game.GameId), tostring(game.PlaceId))

local function decode(raw)
	return Spec.decode(raw)
end

function Store.start(restore)
	if loaded then
		if writable then
			return true
		end
		return false, "Persistent Construct storage is unavailable"
	end
	local storeOk, store = pcall(function()
		return DataStoreService:GetDataStore(Config.PersistentConstructDataStoreName)
	end)
	if not storeOk then
		loaded = true
		return false, "Persistent Construct DataStore could not be opened"
	end
	dataStore = store
	local readOk, raw = pcall(function()
		return dataStore:GetAsync(key)
	end)
	if not readOk then
		loaded = true
		return false, "Persistent Construct world data could not be loaded; no saved data was changed"
	end
	local clean, valid, reason = decode(raw)
	if not valid then
		loaded = true
		return false, reason or "Persistent Construct world data failed validation"
	end
	profile, loaded, writable = clean, true, true
	for _, record in ipairs(profile.Records) do
		local ok, err = pcall(restore, record)
		if not ok then
			warn("Persistent Construct restore failed: " .. tostring(err))
		end
	end
	return true
end

function Store.add(record)
	if not loaded or not writable or not dataStore then
		return nil, "Persistent Construct storage is unavailable"
	end
	local candidate = {}
	for field, value in pairs(record) do
		candidate[field] = value
	end
	candidate.Id = HttpService:GenerateGUID(false)
	candidate.CreatedAt = os.time()
	local valid, validationReason = Spec.validateRecord(candidate)
	if not valid then
		return nil, validationReason
	end
	local rejected
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(key, function(raw)
			rejected = nil
			local current, safe, reason = decode(raw)
			if not safe then
				rejected = reason or "Existing persistent world data failed validation"
				return nil
			end
			if #current.Records >= Spec.MaxRecords then
				rejected = "Persistent Construct world is at its configured record limit"
				return nil
			end
			local owned = 0
			for _, existing in ipairs(current.Records) do
				if existing.OwnerUserId == candidate.OwnerUserId then
					owned = owned + 1
				end
			end
			if owned >= Spec.MaxPerOwner then
				rejected = "You reached the persistent Construct limit for this place"
				return nil
			end
			table.insert(current.Records, candidate)
			return current
		end)
	end)
	if not ok then
		return nil, "Persistent Construct save failed; the cast was not created"
	end
	if rejected or result == nil then
		return nil, rejected or "Persistent Construct save was not committed"
	end
	local updated, safe, reason = decode(result)
	if not safe then
		writable = false
		return nil, reason or "Saved Persistent Construct world data failed validation"
	end
	profile = updated
	return candidate.Id
end

function Store.remove(id)
	pendingHealth[id] = nil
	if not loaded or not writable or not dataStore then
		return false, "Persistent Construct storage is unavailable"
	end
	local rejected
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(key, function(raw)
			rejected = nil
			local current, safe, reason = decode(raw)
			if not safe then
				rejected = reason or "Existing persistent world data failed validation"
				return nil
			end
			for index = #current.Records, 1, -1 do
				if current.Records[index].Id == id then
					table.remove(current.Records, index)
				end
			end
			return current
		end)
	end)
	if not ok or rejected or result == nil then
		return false, rejected or "Persistent Construct removal could not be saved"
	end
	local updated, safe, reason = decode(result)
	if not safe then
		writable = false
		return false, reason or "Saved Persistent Construct world data failed validation"
	end
	profile = updated
	return true
end

-- Remaining health of a damaged persistent Construct; saved on the next flush.
function Store.updateHealth(id, health)
	if loaded and writable then
		pendingHealth[id] = health
	end
end

-- One UpdateAsync for every pending health change (MagicService calls this
-- every PersistentHealthSaveInterval seconds and on shutdown).
function Store.flushHealth()
	if next(pendingHealth) == nil or not loaded or not writable or not dataStore then
		return true
	end
	local updates = pendingHealth
	pendingHealth = {}
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(key, function(raw)
			local current, safe = decode(raw)
			if not safe or Spec.applyHealth(current, updates) == 0 then
				return nil
			end
			return current
		end)
	end)
	if not ok then
		for id, health in pairs(updates) do
			if pendingHealth[id] == nil then
				pendingHealth[id] = health
			end
		end
		return false, "Persistent Construct health could not be saved"
	end
	local updated, safe = decode(result)
	if safe then
		profile = updated
	end
	return true
end

function Store.status()
	return loaded, writable, #profile.Records
end

return Store
