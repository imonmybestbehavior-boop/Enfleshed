--!strict
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Configuration.DefendTheWalls)
local SpellConfig = require(Shared.Configuration.SpellProgression)
local Profiles = require(script.Parent.PlayerProfileService)
local Progression = {}
-- Progress lives in the session-locked player profile (`Data.Progress`).
-- Studio acceleration keeps an in-memory mock that never touches DataStores.
local mock: { [number]: any } = {}

local function blank()
	return {
		Version = 2,
		XP = 0,
		Marks = 0,
		Played = 0,
		Won = 0,
		Lost = 0,
		Kills = 0,
		Repairs = 0,
		Best = 0,
		Receipts = {},
		Unlocks = {},
		SpellRanks = {},
	}
end

local function clean(raw: any)
	local result = blank()
	if type(raw) ~= "table" then
		return result
	end
	for _, key in { "XP", "Marks", "Played", "Won", "Lost", "Kills", "Repairs", "Best" } do
		local value = raw[key]
		if type(value) == "number" and value == value then
			result[key] = math.floor(math.clamp(value, 0, 1000000000))
		end
	end
	if type(raw.Receipts) == "table" then
		for _, id in raw.Receipts do
			if type(id) == "string" and #id <= 100 and #result.Receipts < 40 then
				table.insert(result.Receipts, id)
			end
		end
	end
	if type(raw.Unlocks) == "table" then
		for id in pairs(SpellConfig.Unlocks) do
			if raw.Unlocks[id] == true then
				result.Unlocks[id] = true
			end
		end
	end
	if type(raw.SpellRanks) == "table" then
		local count = 0
		for id, rank in pairs(raw.SpellRanks) do
			if
				type(id) == "string"
				and #id <= 20
				and id:match("^%d+$")
				and type(rank) == "number"
				and rank % 1 == 0
				and rank >= 1
				and rank <= #SpellConfig.RankPrices
				and count < 200
			then
				result.SpellRanks[id] = rank
				count += 1
			end
		end
	end
	return result
end

local function key(userId: number): string
	return "p_" .. tostring(userId)
end

function Progression.level(xp: number): (number, number, number)
	local level = 1
	local remaining = xp
	while level < 100 and remaining >= 100 + (level - 1) * 50 do
		remaining -= 100 + (level - 1) * 50
		level += 1
	end
	return level, remaining, 100 + (level - 1) * 50
end

local function mocked(): boolean
	return RunService:IsStudio() and Config.Studio.Accelerated and Config.Studio.MockProgression
end

function Progression.load(userId: number): (any, boolean)
	if mocked() then
		mock[userId] = mock[userId] or blank()
		return clean(mock[userId]), true
	end
	local session = Profiles.get(userId)
	if not session then
		return blank(), false
	end
	session.Data.Progress = clean(session.Data.Progress)
	return clean(session.Data.Progress), session.Writable
end

-- Applies `change` to the profile's progress and saves it durably.
-- On a failed save the in-memory progress is restored, so nothing is spent or granted.
local function mutate(userId: number, change: (any) -> any?, deferSave: boolean?): (any?, boolean)
	if mocked() then
		local updated = change(clean(mock[userId]))
		if not updated then
			return clean(mock[userId]), false
		end
		mock[userId] = updated
		return clean(updated), true
	end
	local session = Profiles.get(userId)
	if not session or not session.Writable then
		return nil, false
	end
	local previous = clean(session.Data.Progress)
	local updated = change(clean(previous))
	if not updated then
		return previous, false
	end
	session.Data.Progress = updated
	if deferSave then
		-- The caller guarantees a profile flush follows (server shutdown).
		return clean(updated), true
	end
	local saved = false
	for attempt = 1, 3 do
		saved = Profiles.save(userId)
		if saved or not session.Writable then
			break
		end
		task.wait(attempt * 2)
	end
	if not saved then
		if session.Data.Progress == updated then
			session.Data.Progress = previous
		end
		return nil, false
	end
	return clean(updated), true
end

-- `deferSave` only updates the in-memory profile; use it when a profile flush
-- is guaranteed to follow (PlayerProfileService.beforeShutdown).
function Progression.commit(userId: number, missionId: string, reward: any, deferSave: boolean?): (any?, boolean)
	local function apply(raw: any)
		local record = clean(raw)
		if table.find(record.Receipts, missionId) then
			return record
		end
		record.XP += reward.XP
		record.Marks += reward.Marks
		record.Played += 1
		if reward.Victory then
			record.Won += 1
		elseif not reward.Interrupted then
			record.Lost += 1
		end
		record.Kills += reward.Kills
		record.Repairs += reward.Repairs
		record.Best = math.max(record.Best, reward.Score)
		table.insert(record.Receipts, missionId)
		while #record.Receipts > 40 do
			table.remove(record.Receipts, 1)
		end
		return record
	end
	return mutate(userId, apply, deferSave)
end

function Progression.purchase(
	userId: number,
	action: string,
	id: string,
	expectedRank: number?
): (any?, boolean, string)
	local rejection = "Purchase could not be completed"
	local function apply(raw: any)
		local record = clean(raw)
		if action == "Unlock" then
			local offer = SpellConfig.Unlocks[id]
			if not offer then
				rejection = "Unknown unlock"
				return nil
			end
			if record.Unlocks[id] then
				rejection = "Already unlocked"
				return nil
			end
			if record.XP < offer.XP or record.Marks < offer.Marks then
				rejection = "More XP or Marks are required"
				return nil
			end
			record.Marks -= offer.Marks
			record.Unlocks[id] = true
		elseif action == "Rank" then
			if not id:match("^%d+$") or #id > 20 then
				rejection = "Invalid spell record"
				return nil
			end
			local current = record.SpellRanks[id] or 0
			if current ~= expectedRank or current >= #SpellConfig.RankPrices then
				rejection = "Spell rank changed; reopen the upgrade view"
				return nil
			end
			local nextRank = current + 1
			if record.XP < SpellConfig.RankXP[nextRank] or record.Marks < SpellConfig.RankPrices[nextRank] then
				rejection = "More XP or Marks are required"
				return nil
			end
			record.Marks -= SpellConfig.RankPrices[nextRank]
			record.SpellRanks[id] = nextRank
		else
			rejection = "Unknown purchase"
			return nil
		end
		return record
	end
	local updated, ok = mutate(userId, apply)
	if ok then
		return updated, true, "Purchase complete"
	elseif updated then
		return updated, false, rejection
	end
	return nil, false, "Progress could not be saved; no Marks were spent"
end

function Progression.release(_userId: number)
	-- The profile service releases sessions; kept for existing callers.
end

function Progression.cached(userId: number)
	if mocked() then
		return if mock[userId] then clean(mock[userId]) else nil
	end
	local session = Profiles.peek(userId)
	return if session and session.Data.Progress then clean(session.Data.Progress) else nil
end

return Progression
