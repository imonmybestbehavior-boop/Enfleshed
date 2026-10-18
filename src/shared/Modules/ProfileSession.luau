--!strict
-- Pure session-lock rules for the per-player profile document. The server
-- service runs these inside UpdateAsync callbacks, so every decision is made
-- against the latest stored copy. One server owns a profile at a time; a lock
-- that is not refreshed for StaleAfter seconds may be taken over.
local Session = {}

Session.Version = 1
Session.StaleAfter = 90 -- seconds without a lock refresh before a takeover is allowed

export type Lock = { JobId: string, At: number }
export type Record = { Version: number, Lock: Lock?, Data: { [string]: any } }

local function validLock(lock: any): boolean
	return type(lock) == "table" and type(lock.JobId) == "string" and type(lock.At) == "number"
end

-- Returns (record to write or nil to cancel the write, status).
-- status: "Claimed" | "Created" | "Locked" | "Corrupt"
-- `force` takes over a lock held by another server even if it is fresh.
function Session.claim(stored: any, jobId: string, now: number, force: boolean?): (Record?, string)
	if stored == nil then
		return { Version = Session.Version, Lock = { JobId = jobId, At = now }, Data = {} }, "Created"
	end
	if type(stored) ~= "table" or type(stored.Data) ~= "table" then
		return nil, "Corrupt"
	end
	local lock = stored.Lock
	if validLock(lock) and lock.JobId ~= jobId and now - lock.At < Session.StaleAfter and not force then
		return nil, "Locked"
	end
	stored.Lock = { JobId = jobId, At = now }
	stored.Version = Session.Version
	return stored, "Claimed"
end

-- Writes `data` only while this server still owns the lock.
-- Returns (record to write or nil to cancel, status): "Saved" | "Released" | "LockLost" | "Corrupt"
function Session.write(
	stored: any,
	jobId: string,
	data: { [string]: any },
	now: number,
	release: boolean?
): (Record?, string)
	if type(stored) ~= "table" or type(stored.Data) ~= "table" then
		return nil, "Corrupt"
	end
	local lock = stored.Lock
	if not validLock(lock) or lock.JobId ~= jobId then
		return nil, "LockLost"
	end
	stored.Data = data
	stored.Lock = if release then nil else { JobId = jobId, At = now }
	return stored, if release then "Released" else "Saved"
end

return Session
