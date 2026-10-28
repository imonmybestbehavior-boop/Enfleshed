--!strict
-- Pure rules for Interception (OnBeforeDamageTaken). A spell the hit character
-- holds (Aura, Enchantment, attached Construct) may change an incoming hit
-- before mitigation:
--   Negate   - the hit is cancelled.
--   Reduce   - the hit is cut by Percent (1-90).
--   Redirect - Percent (10-100) of the hit goes to the spell's Owner (its
--              caster) or back to the Attacker.
-- One interceptor per hit (oldest applied first), one charge per
-- interception, a minimum interval per spell, and no recursion: DoT ticks and
-- redirected damage are never intercepted.
local Spec = {}

Spec.Actions = { "Negate", "Reduce", "Redirect" }
Spec.RedirectTargets = { "Owner", "Attacker" }
Spec.ReduceRange = { 1, 90 }
Spec.RedirectRange = { 10, 100 }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Whether a hit may be intercepted at all.
function Spec.eligible(eventContext: any?): boolean
	return not (eventContext and (eventContext.Periodic == true or eventContext.Redirected == true))
end

-- Candidates oldest applied first (stable for equal times).
function Spec.order(candidates: { any }): { any }
	local ordered = table.clone(candidates)
	local index = {}
	for position, candidate in ordered do
		index[candidate] = position
	end
	table.sort(ordered, function(left, right)
		local a, b = left.AppliedAt or 0, right.AppliedAt or 0
		if a ~= b then
			return a < b
		end
		return index[left] < index[right]
	end)
	return ordered
end

function Spec.newState(charges: number): any
	return { ChargesLeft = math.max(0, math.floor(charges)), LastAt = nil, PlayerNegates = 0 }
end

-- Whether this spell can intercept now: charges left and the interval passed.
function Spec.ready(state: any, now: number, minInterval: number): boolean
	return state.ChargesLeft > 0 and (state.LastAt == nil or now - state.LastAt >= minInterval)
end

-- The effect of one Intercept action on `amount`. Returns a table:
--   Applied  - false when the action is not allowed (PvP negate limit reached)
--   Kept     - damage that still lands on the holder
--   Redirect - { To = "Owner" | "Attacker", Amount } or nil
--   Negated  - true for a Negate
-- `profile` is the PvP cap profile between attacker and holder (nil/empty = PvE).
function Spec.resolve(amount: number, intercept: any, profile: any?, attackerIsPlayer: boolean, state: any): any
	local hit = if finite(amount) then math.max(0, amount) else 0
	local caps = profile or {}
	local action = intercept and intercept.Action
	if action == "Negate" then
		local limit = caps.MaxInterceptNegateChargesVsPlayer
		if attackerIsPlayer and finite(limit) and (state.PlayerNegates or 0) >= limit then
			return { Applied = false, Kept = hit }
		end
		return { Applied = true, Kept = 0, Negated = true }
	elseif action == "Reduce" then
		local percent = math.clamp(intercept.Percent or 0, Spec.ReduceRange[1], Spec.ReduceRange[2])
		if finite(caps.MaxInterceptReducePercent) then
			percent = math.min(percent, caps.MaxInterceptReducePercent)
		end
		return { Applied = true, Kept = hit * (1 - percent / 100) }
	elseif action == "Redirect" then
		local percent = math.clamp(intercept.Percent or 0, Spec.RedirectRange[1], Spec.RedirectRange[2])
		if intercept.To == "Attacker" and finite(caps.MaxInterceptRedirectToAttackerPercent) then
			percent = math.min(percent, caps.MaxInterceptRedirectToAttackerPercent)
		end
		local share = hit * percent / 100
		return { Applied = true, Kept = hit - share, Redirect = { To = intercept.To, Amount = share } }
	end
	-- Normal steps only (no action): the hit is unchanged.
	return { Applied = true, Kept = hit }
end

-- Records one interception. Returns true when the charges are spent.
function Spec.use(state: any, now: number, negatedPlayerHit: boolean?): boolean
	state.ChargesLeft = math.max(0, state.ChargesLeft - 1)
	state.LastAt = now
	if negatedPlayerHit then
		state.PlayerNegates = (state.PlayerNegates or 0) + 1
	end
	return state.ChargesLeft <= 0
end

-- Cost weight of one Intercept action per charge: Negate highest.
function Spec.costWeight(intercept: any): number
	local action = intercept and intercept.Action
	local percent = (intercept and intercept.Percent or 0) / 100
	-- Control weight in SpellSpec.estimate (provisional).
	if action == "Negate" then
		return 30
	elseif action == "Redirect" then
		return 6 + 14 * percent
	elseif action == "Reduce" then
		return 18 * percent
	end
	return 0
end

return Spec
