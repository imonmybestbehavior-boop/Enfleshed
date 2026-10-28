--!strict
-- Pure rules for the Tether Form: a link between two anchors (Caster to
-- Target, or Target to Target).
--   - It snaps beyond MaxLength, or when line of sight stays blocked longer
--     than the grace period (BreakOnLineOfSight).
--   - Optional Pull: between PullStart (80%) and 100% of MaxLength the anchors
--     are drawn together; beyond 100% it still snaps.
--   - ShareDamage (soul link) moves a share of one anchor's damage to the
--     other; shared and redirected damage are never shared again.
local Spec = {}

export type Settings = {
	MaxLength: number,
	BreakOnLineOfSight: boolean,
	Grace: number,
	Pull: boolean,
	PullStart: number,
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Authored length within the hard limit and the caster's PvP cap.
function Spec.length(authored: number, cap: number?, limit: number): number
	local ceiling = if finite(cap) then math.min(cap :: number, limit) else limit
	return math.clamp(if finite(authored) then authored else ceiling, 1, math.max(1, ceiling))
end

function Spec.newState(): any
	return { BlockedFor = 0 }
end

-- One check of the link. Returns "Hold", "Pull" or "Snap" and, for a snap,
-- the reason ("Distance" or "LineOfSight").
function Spec.step(
	state: any,
	distance: number,
	hasLineOfSight: boolean,
	dt: number,
	settings: Settings
): (string, string?)
	if not finite(distance) or distance > settings.MaxLength then
		return "Snap", "Distance"
	end
	if settings.BreakOnLineOfSight and not hasLineOfSight then
		state.BlockedFor += math.max(0, dt)
		if state.BlockedFor > settings.Grace then
			return "Snap", "LineOfSight"
		end
	else
		state.BlockedFor = 0
	end
	if settings.Pull and distance > settings.MaxLength * settings.PullStart then
		return "Pull", nil
	end
	return "Hold", nil
end

-- Pull speed for each anchor: 0 at PullStart, full speed at MaxLength.
function Spec.pullSpeed(distance: number, maxLength: number, pullStart: number, speed: number): number
	local from = maxLength * pullStart
	if distance <= from or maxLength <= from then
		return 0
	end
	return speed * math.clamp((distance - from) / (maxLength - from), 0, 1)
end

-- Whether a hit may be shared by a soul link.
function Spec.shareable(eventContext: any?): boolean
	return not (eventContext and (eventContext.Redirected == true or eventContext.Shared == true))
end

-- Returns (share moved to the other anchor, damage kept). `cap` is the PvP
-- limit when the receiving anchor is a player.
function Spec.share(amount: number, percent: number, cap: number?): (number, number)
	local hit = if finite(amount) then math.max(0, amount) else 0
	local share = math.clamp(if finite(percent) then percent else 0, 0, 90)
	if finite(cap) then
		share = math.min(share, cap :: number)
	end
	local moved = hit * share / 100
	return moved, hit - moved
end

-- Which of a caster's live tethers (each with StartedAt) to end so a new one
-- fits under `max`: the oldest first.
function Spec.toEnd(tethers: { any }, max: number): { any }
	local ordered = table.clone(tethers)
	table.sort(ordered, function(a, b)
		return (a.StartedAt or 0) < (b.StartedAt or 0)
	end)
	local result = {}
	for index = 1, math.max(0, #ordered - max + 1) do
		table.insert(result, ordered[index])
	end
	return result
end

-- Whether a character already anchors the maximum number of tethers.
function Spec.anchorFull(count: number, max: number): boolean
	return count >= max
end

return Spec
