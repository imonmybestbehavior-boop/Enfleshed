--!strict
-- One session-locked profile document per player (inventory + mission progression).
-- The spell library stays in its own store. Other services read and mutate
-- `session.Data` in memory; this service owns all DataStore traffic for it.
-- First load migrates the legacy per-system stores, which are left untouched.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Session = require(game:GetService("ReplicatedStorage").Shared.Modules.ProfileSession)

local Profiles = {}

Profiles.StoreName = "EnfleshedProfile_v1"
Profiles.AutosaveInterval = 60
Profiles.ClaimAttempts = 8 -- with ClaimRetryDelay, ~40s waiting for the previous server to release
Profiles.ClaimRetryDelay = 5
local LEGACY = { Inventory = "EnfleshedInventory_v1", Progress = "EnfleshedMissionProgress_v1" }

export type ProfileSession = {
	UserId: number,
	Data: { [string]: any },
	Writable: boolean, -- false: data is a temporary copy that will never be saved
	Released: boolean,
}

local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(Profiles.StoreName)
end)
local store: DataStore? = if storeOk then storeResult else nil
if not storeOk then
	warn("[Profile] DataStore unavailable; profiles will not persist: " .. tostring(storeResult))
end

local sessions: { [number]: ProfileSession } = {}
local loading: { [number]: { thread } } = {}
local inflight = 0
local started = false
local shutdownHooks: { () -> () } = {}

-- Runs during BindToClose before profiles are flushed and released, so other
-- services can make final in-memory changes (e.g. interrupted-mission rewards).
-- Hooks must not yield long; anything they write to session data is saved.
function Profiles.beforeShutdown(callback: () -> ())
	table.insert(shutdownHooks, callback)
end

local function key(userId: number): string
	return "p_" .. tostring(userId)
end

local function now(): number
	return os.time()
end

local function retry<T>(attempts: number, callback: () -> T): (boolean, T | string)
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt)
	end
	return false, tostring(lastError)
end

local function readLegacy(userId: number): { [string]: any }
	local data = {}
	for field, storeName in LEGACY do
		local ok, value = retry(3, function()
			return DataStoreService:GetDataStore(storeName):GetAsync(key(userId))
		end)
		if ok and value ~= nil then
			data[field] = value
		elseif not ok then
			error("legacy " .. field .. " read failed: " .. tostring(value))
		end
	end
	return data
end

local function open(userId: number): ProfileSession
	local session: ProfileSession = { UserId = userId, Data = {}, Writable = false, Released = false }
	if not store then
		return session
	end
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	for attempt = 1, Profiles.ClaimAttempts do
		local status = "Failed"
		local force = attempt == Profiles.ClaimAttempts
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key(userId), function(stored)
				local record, claimStatus = Session.claim(stored, jobId, now(), force)
				status = claimStatus
				return record
			end)
		end)
		if ok and (status == "Claimed" or status == "Created") and type(result) == "table" then
			session.Data = result.Data
			if session.Data.Migrated == nil then
				-- First load (or an earlier migration failed): import the legacy stores.
				local migrated, legacy = pcall(readLegacy, userId)
				if not migrated then
					warn("[Profile] migration failed for " .. userId .. ": " .. tostring(legacy))
					return session
				end
				session.Data = legacy
				session.Data.Migrated = now()
			end
			session.Writable = true
			return session
		elseif ok and status == "Corrupt" then
			warn("[Profile] stored profile for " .. userId .. " is unreadable; using a temporary copy")
			return session
		end
		if not ok then
			warn("[Profile] claim failed for " .. userId .. ": " .. tostring(result))
		end
		task.wait(Profiles.ClaimRetryDelay)
	end
	return session
end

-- Writes the in-memory data. Returns true when the stored copy now matches it.
function Profiles.save(userId: number, release: boolean?): boolean
	local session = sessions[userId]
	if not session or not session.Writable or not store then
		return false
	end
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	local status = "Failed"
	inflight += 1
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(userId), function(stored)
			local record, writeStatus = Session.write(stored, jobId, session.Data, now(), release)
			status = writeStatus
			return record
		end)
	end)
	inflight -= 1
	if not ok then
		warn("[Profile] save failed for " .. userId .. ": " .. tostring(err))
		return false
	end
	if status == "LockLost" or status == "Corrupt" then
		-- Another server owns this profile now; never write over it again.
		warn("[Profile] lost session for " .. userId .. " (" .. status .. "); changes here will not be saved")
		session.Writable = false
		return false
	end
	if release then
		session.Released = true
	end
	return true
end

-- Yields until the player's profile is open. Returns nil if the player left first.
function Profiles.get(userId: number): ProfileSession?
	local existing = sessions[userId]
	if existing and not existing.Released then
		return existing
	end
	local waiting = loading[userId]
	if waiting then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
		return sessions[userId]
	end
	if not Players:GetPlayerByUserId(userId) then
		return nil
	end
	loading[userId] = {}
	local session = open(userId)
	local waiters = loading[userId]
	loading[userId] = nil
	if Players:GetPlayerByUserId(userId) then
		sessions[userId] = session
	elseif session.Writable then
		-- Player left during the load: release the claim immediately.
		sessions[userId] = session
		Profiles.save(userId, true)
		sessions[userId] = nil
	end
	for _, thread in waiters or {} do
		task.spawn(thread)
	end
	return sessions[userId]
end

function Profiles.peek(userId: number): ProfileSession?
	return sessions[userId]
end

local function close(userId: number)
	-- Defer so other PlayerRemoving handlers write their final state first.
	task.defer(function()
		local session = sessions[userId]
		if not session or Players:GetPlayerByUserId(userId) then
			return -- rejoined this server already; keep the session
		end
		Profiles.save(userId, true)
		if sessions[userId] == session then
			sessions[userId] = nil
		end
	end)
end

function Profiles.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(function(player)
		Profiles.get(player.UserId)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Profiles.get, player.UserId)
	end
	Players.PlayerRemoving:Connect(function(player)
		close(player.UserId)
	end)
	task.spawn(function()
		while true do
			task.wait(Profiles.AutosaveInterval)
			for userId in sessions do
				task.spawn(Profiles.save, userId)
			end
		end
	end)
	game:BindToClose(function()
		for _, hook in shutdownHooks do
			local ok, err = pcall(hook)
			if not ok then
				warn("[Profile] shutdown hook failed: " .. tostring(err))
			end
		end
		task.wait() -- let deferred PlayerRemoving closes and service flushes run
		for userId in sessions do
			inflight += 1
			task.spawn(function()
				Profiles.save(userId, true)
				inflight -= 1
			end)
		end
		local deadline = os.clock() + 25
		repeat
			task.wait(0.1)
		until inflight <= 0 or os.clock() > deadline
	end)
end

return Profiles
