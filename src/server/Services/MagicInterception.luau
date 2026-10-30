--!strict

-- Interception (OnBeforeDamageTaken). DamageService calls `resolve` for every
-- eligible hit before mitigation; MagicService supplies the spells the target
-- holds as candidates. Rules live in MagicInterceptionSpec; this module only
-- picks the interceptor, runs its event, applies the action and routes
-- redirected damage. Kept free of Roblox services so the audit harness can
-- drive it with doubles.
local Shared = game:GetService("ReplicatedStorage").Shared
local Spec = require(Shared.Modules.MagicInterceptionSpec)
local Limits = require(Shared.Configuration.MagicLab)

local Interception = {}

export type Hooks = {
	IncomingHit: any,
	matched: () -> (),
	intercept: (any) -> (),
}

export type Candidate = {
	Record: any, -- the spell's runtime record; interception state is kept on it
	Definition: any,
	AppliedAt: number,
	Owner: Humanoid?, -- the spell's caster, for Redirect To = "Owner"
	Run: (Hooks) -> (), -- runs this spell's OnBeforeDamageTaken steps
	End: () -> (), -- ends the spell (Interception.EndWhenSpent)
}

export type Hit = { Attacker: Model, Target: Humanoid, Amount: number, Context: any?, Melee: boolean }

export type Deps = {
	Candidates: (Hit) -> { Candidate },
	Now: () -> number,
	Profile: (Model, Humanoid) -> any?,
	AttackerIsPlayer: (Model) -> boolean,
	CanDamage: (Model, Humanoid) -> boolean,
	Deal: (Model, Humanoid, number, any?) -> (),
}

-- Returns the damage that still lands on the target.
function Interception.resolve(hit: Hit, deps: Deps): number
	if not Spec.eligible(hit.Context) or hit.Amount <= 0 then
		return hit.Amount
	end
	local candidates = deps.Candidates(hit)
	if #candidates == 0 then
		return hit.Amount
	end
	local now = deps.Now()
	local attackerIsPlayer = deps.AttackerIsPlayer(hit.Attacker)
	local incoming = {
		Damage = hit.Amount,
		Element = (hit.Context and hit.Context.Element) or "Neutral",
		AttackerIsPlayer = attackerIsPlayer,
		IsMelee = hit.Melee == true,
	}
	for _, candidate in Spec.order(candidates) do
		local settings = candidate.Definition.Interception
		if not settings then
			continue
		end
		local record = candidate.Record
		record.InterceptionState = record.InterceptionState or Spec.newState(settings.Charges)
		local state = record.InterceptionState
		if not Spec.ready(state, now, Limits.MinInterceptionInterval) then
			continue
		end
		local matched, chosen = false, nil
		candidate.Run({
			IncomingHit = incoming,
			matched = function()
				matched = true
			end,
			intercept = function(intercept)
				if chosen == nil then
					chosen = intercept
				end
			end,
		})
		if not matched then
			continue
		end
		-- This spell is the one interceptor for this hit.
		local result = Spec.resolve(hit.Amount, chosen, deps.Profile(hit.Attacker, hit.Target), attackerIsPlayer, state)
		if not result.Applied then
			return hit.Amount -- PvP negate limit reached: no charge used
		end
		local kept = result.Kept
		local spent = Spec.use(state, now, result.Negated == true and attackerIsPlayer)
		local redirect = result.Redirect
		if redirect and redirect.Amount > 0 then
			local recipient, source
			if redirect.To == "Owner" then
				recipient, source = candidate.Owner, hit.Attacker
			else
				recipient, source = hit.Attacker:FindFirstChildOfClass("Humanoid"), hit.Target.Parent :: Model
			end
			if recipient and recipient ~= hit.Target and deps.CanDamage(source, recipient) then
				deps.Deal(source, recipient, redirect.Amount, hit.Context)
			else
				-- Undeliverable share returns to the holder.
				kept += redirect.Amount
			end
		end
		if spent and settings.EndWhenSpent then
			candidate.End()
		end
		return kept
	end
	return hit.Amount
end

return Interception
