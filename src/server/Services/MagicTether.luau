--!strict

-- Tether runtime decisions, kept free of Roblox services so the audit harness
-- can drive them with doubles. MagicService owns the records and supplies the
-- world through `deps`; the rules live in MagicTetherSpec.
local Shared = game:GetService("ReplicatedStorage").Shared
local Spec = require(Shared.Modules.MagicTetherSpec)
local Limits = require(Shared.Configuration.MagicLab)

local Tether = {}

export type UpdateDeps = {
	Alive: (any) -> boolean, -- both anchors alive and present
	Distance: (any) -> number,
	LineOfSight: (any) -> boolean,
	Emit: (any, string) -> (), -- run an event on the tether (targets: both ends)
	Pull: (any, number) -> (), -- draw the ends together at this speed
	Finish: (any, string) -> (), -- "Snap" (no OnExpire), "Expire" or "Lost" (OnExpire)
}

-- Settings a record keeps after cast (MagicService fills Length after caps).
function Tether.settings(definition: any, length: number): Spec.Settings
	local authored = definition.Tether
	return {
		MaxLength = length,
		BreakOnLineOfSight = authored.BreakOnLineOfSight ~= false,
		Grace = Limits.TetherLineOfSightGrace,
		Pull = authored.Pull == true,
		PullStart = Limits.TetherPullStart,
	}
end

-- One Heartbeat step. Returns nil while the link holds, else how it ended.
function Tether.update(record: any, dt: number, now: number, deps: UpdateDeps): string?
	if not deps.Alive(record) then
		deps.Finish(record, "Lost")
		return "Lost"
	end
	local distance = deps.Distance(record)
	local result = Spec.step(record.TetherState, distance, deps.LineOfSight(record), dt, record.Settings)
	if result == "Snap" then
		deps.Emit(record, "OnBreak")
		deps.Finish(record, "Snap")
		return "Snap"
	end
	if result == "Pull" then
		deps.Pull(
			record,
			Spec.pullSpeed(distance, record.Settings.MaxLength, record.Settings.PullStart, Limits.TetherPullSpeed)
		)
	end
	if now >= (record.NextPulse or 0) then
		record.NextPulse = now + record.Definition.Tether.Interval
		deps.Emit(record, "OnTick")
	end
	if record.RemainingLifetime <= 0 then
		deps.Finish(record, "Expire")
		return "Expire"
	end
	return nil
end

export type Link = {
	Record: any,
	Percent: number, -- ShareDamage
	Other: Humanoid, -- the anchor that receives the share
	StartedAt: number,
}

export type ShareDeps = {
	Links: (Humanoid) -> { Link }, -- soul links on the hit character
	ShareCap: (Model, Humanoid) -> number?, -- PvP cap when the receiver is a player
	CanDamage: (Model, Humanoid) -> boolean,
	Deal: (Model, Humanoid, number, any?) -> (),
}

-- Soul link: the oldest link on the target moves its share of the hit to the
-- other anchor as Shared damage, which is never shared again. Returns the
-- damage that stays on the target.
function Tether.share(attacker: Model, target: Humanoid, amount: number, eventContext: any?, deps: ShareDeps): number
	if amount <= 0 or not Spec.shareable(eventContext) then
		return amount
	end
	local links = deps.Links(target)
	if #links == 0 then
		return amount
	end
	table.sort(links, function(a, b)
		return a.StartedAt < b.StartedAt
	end)
	local link = links[1]
	if link.Other == target or not deps.CanDamage(attacker, link.Other) then
		return amount -- the share stays on the target
	end
	local moved, kept = Spec.share(amount, link.Percent, deps.ShareCap(attacker, link.Other))
	if moved > 0 then
		deps.Deal(attacker, link.Other, moved, eventContext)
	end
	return kept
end

return Tether
