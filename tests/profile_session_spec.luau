local Session = require("../src/shared/Modules/ProfileSession")

-- New player: a fresh locked record is created.
local record, status = Session.claim(nil, "A", 100)
assert(status == "Created" and record and record.Lock.JobId == "A", "new profiles are created locked")

-- Same server can re-claim; another server is blocked while the lock is fresh.
local again, s2 = Session.claim(record, "A", 110)
assert(s2 == "Claimed" and again, "owner re-claims its own lock")
local blocked, s3 = Session.claim(record, "B", 120)
assert(blocked == nil and s3 == "Locked", "fresh lock blocks other servers")

-- Stale or forced takeover.
local stale, s4 = Session.claim({ Version = 1, Lock = { JobId = "A", At = 0 }, Data = { X = 1 } }, "B", 1000)
assert(s4 == "Claimed" and stale.Lock.JobId == "B" and stale.Data.X == 1, "stale lock can be taken over, data kept")
local forced, s5 = Session.claim({ Version = 1, Lock = { JobId = "A", At = 999 }, Data = {} }, "B", 1000, true)
assert(s5 == "Claimed" and forced.Lock.JobId == "B", "force takes over a fresh lock")

-- Released profile is claimable immediately.
local released = Session.write({ Version = 1, Lock = { JobId = "A", At = 5 }, Data = {} }, "A", { Y = 2 }, 6, true)
assert(released and released.Lock == nil and released.Data.Y == 2, "release writes data and clears the lock")
local _, s6 = Session.claim(released, "B", 7)
assert(s6 == "Claimed", "released profile claimable by another server")

-- Writes require ownership: the duplication race is rejected.
local lost, s7 = Session.write(
	{ Version = 1, Lock = { JobId = "B", At = 50 }, Data = { Items = "new" } },
	"A",
	{ Items = "old" },
	51
)
assert(lost == nil and s7 == "LockLost", "a server that lost the lock cannot overwrite newer data")
local saved, s8 = Session.write({ Version = 1, Lock = { JobId = "A", At = 50 }, Data = {} }, "A", { Z = 3 }, 60)
assert(s8 == "Saved" and saved.Lock.At == 60 and saved.Data.Z == 3, "owner saves and refreshes its lock")

-- Corrupt data is never overwritten.
assert(select(2, Session.claim("garbage", "A", 1)) == "Corrupt", "corrupt claim rejected")
assert(select(2, Session.write({ Lock = { JobId = "A", At = 1 } }, "A", {}, 2)) == "Corrupt", "corrupt write rejected")

print("Profile session: create, lock, stale/forced takeover, release, lock-lost and corrupt cases passed")
